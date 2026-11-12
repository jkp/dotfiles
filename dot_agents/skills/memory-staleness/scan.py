#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# ///
"""Find memories that tell you to use something the repository no longer has.

Reports; never edits. Whether a stale memory should be corrected or retired is
a judgement about whether its lesson survived, and the candidate new location
for a moved file is a guess that is right only when the file name is distinctive.

Scope is deliberately narrow, from validating a real memory directory by hand:
only instructional memories (``feedback_``, ``reference_``) are checked, because
a ``project_`` or ``incident_`` memory naming a deleted path is recording what
was true at the time.
"""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
import shutil
import subprocess
import sys
from collections import Counter
from dataclasses import asdict, dataclass, field
from itertools import product
from pathlib import Path, PurePosixPath

PROJECTS = Path.home() / ".claude" / "projects"

INSTRUCTIONAL = ("feedback_", "reference_")
NARRATIVE = ("project_", "incident_")

BACKTICK = re.compile(r"`([^`\n]{2,160})`")
PLACEHOLDER = re.compile(r"[<>{}$]")
PATHY = re.compile(r"^[\w.\-*]+(?:/[\w.\-*]+)+/?$")
TASKY = re.compile(r"^([a-z0-9][a-z0-9\-]*)?:([a-z0-9][a-z0-9\-]*)$")

# Directories a checkout generates rather than tracks. Their absence from git
# proves nothing, so a memory naming one is never reported.
GENERATED = {
    "node_modules", ".venv", "venv", ".review", "test-results", "dist", "build",
    "__pycache__", ".pytest_cache", ".mypy_cache", ".ruff_cache", ".next", "coverage",
}
GENERATED_PREFIXES = (".moon/cache",)

# File names too common to identify where a moved file went.
GENERIC_NAMES = {
    "__init__.py", "__main__.py", "main.py", "app.py", "config.py", "utils.py",
    "conftest.py", "setup.py", "stack.py", "index.ts", "index.tsx", "index.js",
    "app.tsx", "README.md", "SKILL.md", "AGENTS.md", "CLAUDE.md", "pyproject.toml",
    "package.json", "moon.yml", "mod.rs", "lib.rs", "Dockerfile",
}

# A command can outlive its tool and name no path at all. These cannot run
# without a file in the repository, so that file's absence is the evidence.
# `make` is still installed on most machines, so asking whether it is on PATH
# misses the most common stale instruction there is.
COMMAND_EVIDENCE = {
    "make": (("Makefile", "GNUmakefile", "makefile"), (".mk",), "Makefile"),
    "overmind": (("Procfile",), (), "Procfile"),
    "hk": (("hk.pkl",), (), "hk.pkl"),
    "just": (("justfile", "Justfile"), (), "justfile"),
}
RUNNER_PREFIXES = {"mise", "uv", "npx", "sudo", "env", "gtimeout", "timeout", "time"}


@dataclass(frozen=True)
class Finding:
    file: str
    claim: str
    kind: str
    reason: str
    candidate: str | None = None


@dataclass
class Stats:
    instructional_scanned: int = 0
    narrative_skipped: int = 0
    other_repo_skipped: int = 0
    checked: Counter = field(default_factory=Counter)


FRONTMATTER = re.compile(r"\A---\n(.*?)\n---", re.S)
REPO_FIELD = re.compile(r"^\s*repo:\s*(\S+)\s*$", re.M)


def declared_repo(text: str) -> str | None:
    """The repository a memory says it describes, if it names one.

    Set ``repo:`` under a memory's metadata when it documents a different
    repository; its paths are relative to that tree and would all read as gone.
    """

    front = FRONTMATTER.match(text)
    found = REPO_FIELD.search(front.group(1)) if front else None
    return found.group(1) if found else None


def memory_kind(filename: str) -> str | None:
    if filename == "MEMORY.md" or not filename.endswith(".md"):
        return None
    if filename.startswith(INSTRUCTIONAL):
        return "instructional"
    if filename.startswith(NARRATIVE):
        return "narrative"
    return None


# --- project directory encoding ---------------------------------------------


def encode_project_dir(path: Path) -> str:
    """How Claude names a project's directory under ``~/.claude/projects``."""
    return re.sub(r"[^A-Za-z0-9]", "-", str(path))


def decode_project_dir(name: str) -> Path | None:
    """Recover the directory an encoded project name refers to.

    The encoding replaces every separator and every non-alphanumeric character
    with ``-``, so ``handyshed-sunnyfield`` and ``handyshed/sunnyfield`` encode
    identically. The filesystem is the only thing that can tell them apart, so
    this walks it and returns the decoding that exists, or ``None``.
    """

    tokens = name.split("-")
    if tokens and tokens[0] == "":
        tokens = tokens[1:]

    def variants(chunk: list[str]) -> list[str]:
        if len(chunk) > 5:
            return []
        return [
            "".join(part + sep for part, sep in zip(chunk, (*seps, ""), strict=True))
            for seps in product("-._", repeat=len(chunk) - 1)
        ]

    def walk(base: Path, i: int) -> Path | None:
        if i == len(tokens):
            return base
        for j in range(min(len(tokens), i + 5), i, -1):
            for component in variants(tokens[i:j]):
                if not component:
                    continue
                candidate = base / component
                if candidate.is_dir():
                    found = walk(candidate, j)
                    if found is not None:
                        return found
        return None

    return walk(Path("/"), 0)


# --- the repository ----------------------------------------------------------


def _git(repo: Path, *args: str) -> str | None:
    result = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, text=True, check=False
    )
    return result.stdout if result.returncode == 0 else None


class RepoIndex:
    """What a repository tracks, answered once so every claim is a lookup."""

    def __init__(self, repo: Path, moon_tasks: set[str] | None = None) -> None:
        self.repo = repo
        self.names = {repo.name}
        remote = _git(repo, "remote", "get-url", "origin")
        if remote:
            self.names.add(remote.strip().rstrip("/").removesuffix(".git").split("/")[-1])
        self.ref, self.ref_date = self._resolve_ref()
        listing = (
            _git(repo, "ls-tree", "-r", "--name-only", self.ref)
            if self.ref != "working tree"
            else _git(repo, "ls-files")
        )
        self.tracked = tuple(line for line in (listing or "").splitlines() if line)
        self.tracked_set = set(self.tracked)
        self.basenames = Counter(PurePosixPath(p).name for p in self.tracked)
        self.suffixes: set[str] = set()
        self.dirs: set[str] = set()
        self.dir_names: set[str] = set()
        for path in self.tracked:
            parts = path.split("/")
            for i in range(len(parts)):
                self.suffixes.add("/".join(parts[i:]))
            for i in range(len(parts) - 1):
                self.dir_names.add(parts[i])
                for j in range(i + 1, len(parts)):
                    self.dirs.add("/".join(parts[i:j]))
        self._ignored: dict[str, bool] = {}
        self.moon_tasks = moon_tasks if moon_tasks is not None else self._load_moon_tasks()
        self.moon_projects = {t.split(":")[0] for t in self.moon_tasks}
        self.moon_names = {t.split(":")[1] for t in self.moon_tasks}

    def _resolve_ref(self) -> tuple[str, str]:
        """Prefer the upstream default branch: memory should match what ships.

        A checkout may sit on any branch; ``origin/main`` is what is true now.
        With no upstream, the working tree is the only truth there is.
        """

        head = _git(self.repo, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
        if head and head.strip():
            ref = head.strip()
            date = (_git(self.repo, "log", "-1", "--format=%cs", ref) or "").strip()
            return ref, date
        return "working tree", ""

    def _load_moon_tasks(self) -> set[str]:
        if not (self.repo / ".moon").is_dir():
            return set()
        for cmd in (["moon", "query", "tasks"], ["mise", "x", "--", "moon", "query", "tasks"]):
            if not shutil.which(cmd[0]):
                continue
            try:
                result = subprocess.run(
                    cmd, cwd=self.repo, capture_output=True, text=True, timeout=120, check=False
                )
            except subprocess.TimeoutExpired:
                continue
            start = result.stdout.find("{")
            if result.returncode != 0 or start < 0:
                continue
            try:
                data = json.loads(result.stdout[start:])
            except json.JSONDecodeError:
                continue
            return {f"{project}:{task}" for project, tasks in data.get("tasks", {}).items() for task in tasks}
        return set()

    def has_path(self, claim: str) -> bool:
        path = claim.rstrip("/")
        if path in self.tracked_set or path in self.suffixes or path in self.dirs:
            return True
        if "*" in path:
            return any(fnmatch.fnmatch(p, path) or fnmatch.fnmatch(p, f"*/{path}") for p in self.tracked)
        return False

    def is_ignored(self, claim: str) -> bool:
        """Whether the repository's own ignore rules cover this path.

        Git answers this for paths that do not exist, which is exactly the case:
        a memory naming runtime state the fixed list of generated names never
        heard of, such as a tool's scratch directory.
        """

        if claim not in self._ignored:
            # Only the repository's committed `.gitignore` files count. A clone's
            # `.git/info/exclude` and the user's global excludes are local, and
            # honouring them makes one memory stale on one machine and fine on
            # the next. `-v` names the rule that decided, so the source can be
            # checked; a `!` rule un-ignores and is not a match.
            result = subprocess.run(
                ["git", "-C", str(self.repo), "-c", "core.excludesFile=/dev/null",
                 "check-ignore", "-v", "--no-index", claim],
                capture_output=True,
                text=True,
                check=False,
            )
            ignored = False
            for line in result.stdout.splitlines():
                rule, _, _ = line.partition("\t")
                source, _, rest = rule.partition(":")
                _, _, pattern = rest.partition(":")
                if PurePosixPath(source).name == ".gitignore" and not pattern.startswith("!"):
                    ignored = True
            self._ignored[claim] = ignored
        return self._ignored[claim]

    def was_ever_tracked(self, claim: str) -> bool:
        """Whether this path was ever a file in any branch of the history."""

        return bool((_git(self.repo, "log", "--all", "--format=%H", "-1", "--", claim) or "").strip())

    def candidate(self, claim: str) -> str | None:
        name = PurePosixPath(claim.rstrip("/")).name
        if not name or "*" in name or name in GENERIC_NAMES or self.basenames.get(name) != 1:
            return None
        return next(p for p in self.tracked if PurePosixPath(p).name == name)

    def has_evidence_for(self, command: str) -> bool:
        names, extensions, _ = COMMAND_EVIDENCE[command]
        return any(
            PurePosixPath(p).name.startswith(names) or PurePosixPath(p).suffix in extensions
            for p in self.tracked
        )


# --- claims ------------------------------------------------------------------


def _command_word(span: str) -> str | None:
    words = span.split()
    if "--" in words and words[0] in RUNNER_PREFIXES:
        words = words[words.index("--") + 1 :]
    return words[0] if words else None


def _is_generated(path: str) -> bool:
    return path.startswith(GENERATED_PREFIXES) or any(part in GENERATED for part in path.split("/"))


def check_span(span: str, index: RepoIndex, stats: Stats) -> tuple[str, str, str | None] | None:
    """Return ``(kind, reason, candidate)`` when a span names something gone."""

    span = span.strip()
    if PLACEHOLDER.search(span):
        return None

    if any(ch.isspace() for ch in span):
        command = _command_word(span)
        if command in COMMAND_EVIDENCE:
            stats.checked["command"] += 1
            if not index.has_evidence_for(command):
                return "command", f"`{command}` invoked, but the repository has no {COMMAND_EVIDENCE[command][2]}", None
        return None

    task = TASKY.match(span)
    if task:
        if not index.moon_tasks:
            return None
        project, name = task.groups()
        if project is None:
            stats.checked["task"] += 1
            return None if name in index.moon_names else ("task", "no moon project has this task", None)
        if project not in index.moon_projects:
            return None  # `status:ready` is a label; `twopane:w-80` is a class
        stats.checked["task"] += 1
        return None if span in index.moon_tasks else ("task", f"moon project `{project}` has no such task", None)

    if PATHY.match(span) and not _is_generated(span):
        parts = span.rstrip("/").split("/")
        if len(parts) == 2 and "." not in parts[1] and not span.endswith("/") and "*" not in span:
            # Two segments with no extension is how identifiers are spelled —
            # `actions/checkout`, `tools/call`, `owner/repo` — and also how some
            # real files are named. History separates them: an identifier was
            # never a file here, a deleted file was.
            if index.has_path(span) or index.is_ignored(span) or not index.was_ever_tracked(span):
                return None
            stats.checked["path"] += 1
            return "path", "not in the repo (it was a file in its history)", index.candidate(span)
        first = parts[0]
        if first not in index.dir_names:
            return None  # `origin/main`, `roles/x.admin`, `owner/repo`: not paths here
        if index.is_ignored(span):
            return None
        stats.checked["path"] += 1
        if not index.has_path(span):
            return "path", "not in the repo", index.candidate(span)
    return None


def scan_memory_dir(
    memory: Path, repo: Path, index: RepoIndex | None = None, stats: Stats | None = None
) -> list[Finding]:
    index = index or RepoIndex(repo)
    stats = stats if stats is not None else Stats()
    findings: list[Finding] = []
    for path in sorted(memory.glob("*.md")):
        kind = memory_kind(path.name)
        if kind == "narrative":
            stats.narrative_skipped += 1
        if kind != "instructional":
            continue
        stats.instructional_scanned += 1
        text = path.read_text(errors="replace")
        declared = declared_repo(text)
        if declared and declared not in index.names:
            stats.other_repo_skipped += 1
            continue
        seen: set[str] = set()
        for span in BACKTICK.findall(text):
            if span in seen:
                continue
            seen.add(span)
            result = check_span(span, index, stats)
            if result:
                kind_, reason, candidate = result
                findings.append(Finding(path.name, span.strip(), kind_, reason, candidate))
    return findings


# --- targets -----------------------------------------------------------------


def repo_for(memory: Path) -> Path | None:
    decoded = decode_project_dir(memory.parent.name)
    if decoded is None:
        return None
    top = _git(decoded, "rev-parse", "--show-toplevel")
    return Path(top.strip()) if top else None


def current_memory_dir() -> Path | None:
    """The memory directory Claude uses for the repository you are in.

    A linked worktree shares its main checkout's memory, so resolve through
    the common git directory rather than the worktree's own top level.
    """

    common = _git(Path.cwd(), "rev-parse", "--path-format=absolute", "--git-common-dir")
    if not common:
        return None
    root = Path(common.strip()).parent
    return PROJECTS / encode_project_dir(root) / "memory"


def all_memory_dirs() -> list[Path]:
    return sorted(p for p in PROJECTS.glob("*/memory") if p.is_dir())


# --- output ------------------------------------------------------------------


def run(memory: Path, repo: Path) -> dict:
    stats = Stats()
    index = RepoIndex(repo)
    findings = scan_memory_dir(memory, repo, index=index, stats=stats)
    return {
        "memory": str(memory),
        "repo": str(repo),
        "ref": index.ref,
        "ref_date": index.ref_date,
        "instructional_scanned": stats.instructional_scanned,
        "narrative_skipped": stats.narrative_skipped,
        "other_repo_skipped": stats.other_repo_skipped,
        "claims_checked": dict(stats.checked),
        "moon_tasks_loaded": len(index.moon_tasks),
        "findings": [asdict(f) for f in findings],
    }


def render(report: dict) -> str:
    findings = report["findings"]
    files = sorted({f["file"] for f in findings})
    ref = f"{report['ref']} ({report['ref_date']})" if report["ref_date"] else report["ref"]
    lines = [
        f"memory  {report['memory']}",
        f"repo    {report['repo']} @ {ref}",
        f"scanned {report['instructional_scanned']} instructional "
        f"(skipped {report['narrative_skipped']} narrative) · "
        f"checked {sum(report['claims_checked'].values())} claims "
        f"{report['claims_checked'] or ''} · moon tasks {report['moon_tasks_loaded']}",
        f"stale   {len(findings)} claims in {len(files)} memories",
    ]
    for name in files:
        lines.append(f"\n{name}")
        for f in (x for x in findings if x["file"] == name):
            lines.append(f"  {f['kind']:<8} {f['claim']}")
            lines.append(f"  {'':<8} {f['reason']}")
            if f["candidate"]:
                lines.append(f"  {'':<8} candidate: {f['candidate']}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--memory", type=Path, help="a memory directory to scan")
    parser.add_argument("--repo", type=Path, help="the repository it describes")
    parser.add_argument("--all", action="store_true", help="every project memory on this machine")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)

    targets: list[tuple[Path, Path | None]]
    if args.all:
        targets = [(m, repo_for(m)) for m in all_memory_dirs()]
    elif args.memory:
        targets = [(args.memory, args.repo or repo_for(args.memory))]
    else:
        memory = current_memory_dir()
        if memory is None:
            parser.error("not in a git repository; pass --memory or --all")
        targets = [(memory, args.repo or repo_for(memory))]

    reports, skipped = [], []
    for memory, repo in targets:
        if repo is None:
            skipped.append({"memory": str(memory), "reason": "no git repository found for it"})
            continue
        reports.append(run(memory, repo))

    if args.json:
        payload = reports[0] if len(reports) == 1 and not args.all else {"reports": reports, "skipped": skipped}
        print(json.dumps(payload, indent=2))
    else:
        print("\n\n".join(render(r) for r in reports))
        for s in skipped:
            print(f"\nskipped {s['memory']}: {s['reason']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
