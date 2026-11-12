"""Tests for the memory staleness scan.

Each rule here is a lesson from validating a real memory directory by hand
(2026-09-11): a naive path check flagged 424 claims, of which about 23 were
real. The tests pin the filters that closed that gap, so a later edit cannot
quietly reopen it.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

import pytest

SKILL = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SKILL))

import scan  # noqa: E402


# --- fixtures ---------------------------------------------------------------


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", *args], cwd=repo, check=True, capture_output=True)


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    """A real git repository with a handful of tracked files."""
    root = tmp_path / "work" / "acme"
    for rel, body in {
        "tools/scripts/src/analyzer/moon_io_analyze.py": "x = 1\n",
        "tools/scripts/src/analyzer/__main__.py": "x = 1\n",
        "tools/scripts/tests/test_clone_db.py": "def test(): pass\n",
        "docs/contributing.rst": "Contributing\n",
        "apps/web/src/main.py": "print()\n",
        "apps/api/src/main.py": "print()\n",
        "README.md": "readme\n",
    }.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(body)
    _git(root, "init", "-q")
    _git(root, "add", "-A")
    _git(root, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", "init")
    return root


def _memory(dir_: Path, name: str, body: str) -> Path:
    dir_.mkdir(parents=True, exist_ok=True)
    path = dir_ / name
    path.write_text(f"---\nname: {name[:-3]}\ndescription: test\n---\n\n{body}\n")
    return path


# --- memory kinds -----------------------------------------------------------


@pytest.mark.parametrize(
    ("filename", "kind"),
    [
        ("feedback_correct_fix.md", "instructional"),
        ("reference_bash_tool_is_zsh.md", "instructional"),
        ("project_adr054_moon.md", "narrative"),
        ("incident_forge_disk_fill_2026-07-07.md", "narrative"),
        ("MEMORY.md", None),
    ],
)
def test_memory_kind_separates_instructions_from_history(filename: str, kind: str | None) -> None:
    """A project file naming a deleted path records what was true then.

    That is correct, not stale. Only a memory telling you to do something can
    send you somewhere that no longer exists. In the hand validation, scoping
    to instructional memories removed 165 of 214 findings, none of them wrong.
    """
    assert scan.memory_kind(filename) == kind


# --- project directory decoding --------------------------------------------


def test_decodes_a_path_whose_directory_names_contain_dashes(tmp_path: Path) -> None:
    """The encoding flattens both separators and real dashes into `-`.

    `-Users-x-handyshed-sunnyfield` could be one directory or two, so the only
    reliable decoding is the one that exists on disk.
    """
    real = tmp_path / "Development" / "handyshed-sunnyfield"
    real.mkdir(parents=True)
    encoded = str(real).replace("/", "-")
    assert scan.decode_project_dir(encoded) == real


def test_decodes_the_double_dash_as_a_dotted_directory(tmp_path: Path) -> None:
    """Worktree memory dirs encode `/.claude` as `--claude`."""
    real = tmp_path / "proj" / ".claude" / "worktrees" / "feature-x"
    real.mkdir(parents=True)
    encoded = str(real).replace("/.", "--").replace("/", "-")
    assert scan.decode_project_dir(encoded) == real


def test_decoding_a_path_that_no_longer_exists_returns_none(tmp_path: Path) -> None:
    assert scan.decode_project_dir(str(tmp_path / "gone" / "worktree").replace("/", "-")) is None


# --- noise that must never be reported --------------------------------------


@pytest.mark.parametrize(
    "token",
    [
        "roles/billing.admin",  # a GCP IAM role
        "origin/main",  # a git ref
        "acme/acme",  # an owner/repo slug
        "GEMINI_API_KEY/versions/6",  # a secret version
        "apps/web/node_modules/**",  # untracked build state
        "apps/web/.venv/bin/python",  # untracked build state
        "apps/<project>/src/main.py",  # a placeholder
        "status:ready",  # a GitHub label, not a task
        "twopane:w-80",  # a CSS class, not a task
        # Found on the first real run, 2026-09-16. Both begin with a directory
        # the repository really has, so the root rule alone admits them.
        "tools/call",  # an MCP method
        "apps/checkout",  # shaped like `actions/checkout`, a GitHub Action
    ],
)
def test_tokens_that_only_look_like_claims_are_not_reported(repo: Path, tmp_path: Path, token: str) -> None:
    """Each of these was a false positive in the hand validation."""
    mem = tmp_path / "memory"
    _memory(mem, "feedback_noise.md", f"Use `{token}` here.")
    assert scan.scan_memory_dir(mem, repo) == []


def test_a_path_git_ignores_is_never_reported(repo: Path, tmp_path: Path) -> None:
    """Git ignoring a path means absence proves nothing, whatever it is called.

    The first real run flagged `.claude/worktrees/`, a runtime directory the
    fixed list of generated names did not know. The repository's own ignore
    rules know every such directory, including ones not invented yet.
    """
    (repo / ".gitignore").write_text(".cache/runs/\n")
    (repo / ".cache").mkdir()
    (repo / ".cache" / "README.md").write_text("cache\n")
    _git(repo, "add", ".gitignore", ".cache/README.md")
    mem = tmp_path / "memory"
    _memory(mem, "reference_runs.md", "The last run is in `.cache/runs/latest.json`.")
    assert scan.scan_memory_dir(mem, repo) == []


@pytest.mark.parametrize("negated", [False, True])
def test_only_the_repositorys_committed_ignore_rules_count(repo: Path, tmp_path: Path, negated: bool) -> None:
    """A clone's private excludes are not the repository's rules.

    The second real run silently dropped `.claude/hooks/pre_tool_use.py`
    because `.git/info/exclude` on that one machine listed it. Honouring that
    makes the same memory stale on one laptop and fine on another. A negated
    `.gitignore` pattern un-ignores, and must not count as ignored either.
    """
    (repo / "docs" / "old").mkdir()
    (repo / "docs" / "old" / "README.md").write_text("old\n")
    _git(repo, "add", "docs/old/README.md")
    info = repo / ".git" / "info"
    info.mkdir(exist_ok=True)
    if negated:
        (repo / ".gitignore").write_text("docs/old/*\n!docs/old/moved.py\n")
        _git(repo, "add", ".gitignore")
    else:
        (info / "exclude").write_text("docs/old/moved.py\n")
    mem = tmp_path / "memory"
    _memory(mem, "reference_moved.md", "It used to be `docs/old/moved.py`.")
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.claim == "docs/old/moved.py"


def _commit_all(repo: Path, message: str) -> None:
    _git(repo, "-c", "user.email=t@t", "-c", "user.name=t", "commit", "-qm", message)


def test_a_deleted_extensionless_file_is_reported(repo: Path, tmp_path: Path) -> None:
    """Git history tells an identifier from a file that used to be here.

    `apps/checkout` and `tools/call` were never files, so they are skipped as
    identifiers. `ops/secrets` was one — network-config really tracks an
    extensionless `orchestra/op-secrets` — and deleting it must not go quiet.
    """
    (repo / "ops").mkdir()
    (repo / "ops" / "secrets").write_text("x\n")
    _git(repo, "add", "ops/secrets")
    _commit_all(repo, "add secrets")
    _git(repo, "rm", "-q", "ops/secrets")
    _commit_all(repo, "drop secrets")
    mem = tmp_path / "memory"
    _memory(mem, "feedback_secrets.md", "Every entry in `ops/secrets` must resolve.")
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.claim == "ops/secrets"


def test_a_live_extensionless_file_is_not_reported(repo: Path, tmp_path: Path) -> None:
    (repo / "ops").mkdir()
    (repo / "ops" / "secrets").write_text("x\n")
    _git(repo, "add", "ops/secrets")
    _commit_all(repo, "add secrets")
    mem = tmp_path / "memory"
    _memory(mem, "feedback_secrets.md", "Every entry in `ops/secrets` must resolve.")
    assert scan.scan_memory_dir(mem, repo) == []


def test_a_memory_about_another_repository_is_not_checked_against_this_one(repo: Path, tmp_path: Path) -> None:
    """Its paths are relative to a different tree, so every miss is expected.

    The first real run reported three paths from a memory that describes itself
    as a pointer to the superagent repository. A memory declares that with
    ``repo:`` in its metadata; left unmarked it would be re-reported every run.
    """
    mem = tmp_path / "memory"
    mem.mkdir()
    (mem / "reference_other_repo.md").write_text(
        "---\nname: other-repo\ndescription: pointer\nmetadata:\n  type: reference\n  repo: superagent\n---\n\n"
        "See `apps/superagent/batch_runner.py`.\n"
    )
    assert scan.scan_memory_dir(mem, repo) == []


def test_a_memory_naming_this_repository_is_still_checked(repo: Path, tmp_path: Path) -> None:
    mem = tmp_path / "memory"
    mem.mkdir()
    (mem / "reference_here.md").write_text(
        f"---\nname: here\ndescription: here\nmetadata:\n  type: reference\n  repo: {repo.name}\n---\n\n"
        "See `apps/gone/batch_runner.py`.\n"
    )
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.claim == "apps/gone/batch_runner.py"


def test_command_reasons_read_as_english(repo: Path, tmp_path: Path) -> None:
    mem = tmp_path / "memory"
    _memory(mem, "feedback_ci.md", "Run `make ci`.")
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.reason == "`make` invoked, but the repository has no Makefile"


# --- real staleness ---------------------------------------------------------


def test_a_path_that_moved_is_reported_with_its_new_home(repo: Path, tmp_path: Path) -> None:
    mem = tmp_path / "memory"
    _memory(mem, "reference_io_trace.md", "Run `tools/moon_io_analyze.py` to check.")
    # The claim is rooted in a real top-level dir but the file is not there.
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.claim == "tools/moon_io_analyze.py"
    assert finding.candidate == "tools/scripts/src/analyzer/moon_io_analyze.py"


def test_a_path_still_present_under_a_subdirectory_is_not_reported(repo: Path, tmp_path: Path) -> None:
    """Memories often name a file relative to the package, not the repo root."""
    mem = tmp_path / "memory"
    _memory(mem, "feedback_ok.md", "See `tests/test_clone_db.py` and `docs/contributing.rst`.")
    assert scan.scan_memory_dir(mem, repo) == []


@pytest.mark.parametrize(
    "claim",
    [
        # Two files share the name, so any pick would be a guess.
        "apps/production/src/main.py",
        # Exactly one file shares the name, and it is still not where this
        # went: a name this common identifies nothing. Uniqueness alone would
        # confidently name it; only the generic-name rule refuses.
        "infra/production/__main__.py",
    ],
)
def test_a_generic_basename_is_never_offered_as_a_new_home(repo: Path, tmp_path: Path, claim: str) -> None:
    """In the hand validation a fuzzy match produced `infra/production/__main__.py`
    -> `apps/functions/.../main.py`, which was confidently wrong."""
    mem = tmp_path / "memory"
    (repo / "infra").mkdir(exist_ok=True)
    (repo / "infra" / "README.md").write_text("infra\n")
    _git(repo, "add", "infra/README.md")
    _memory(mem, "feedback_gone.md", f"Edit `{claim}`.")
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.candidate is None


def test_the_same_dead_path_in_a_narrative_memory_is_not_reported(repo: Path, tmp_path: Path) -> None:
    mem = tmp_path / "memory"
    _memory(mem, "project_history.md", "We deleted `apps/legacy/server.py` in June.")
    assert scan.scan_memory_dir(mem, repo) == []


def test_invoking_make_in_a_repo_with_no_makefile_is_reported(repo: Path, tmp_path: Path) -> None:
    """A command can outlive its tool, and names no path to catch.

    `make` was the most common stale instruction found — 35 memories — and is
    still installed on the machine, so asking "is it on PATH" misses it. What
    it cannot do is run: a repository with no Makefile has no targets.
    """
    mem = tmp_path / "memory"
    _memory(mem, "feedback_ci.md", "Before pushing, run `make -C tools ci`.")
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.kind == "command"
    assert "Makefile" in finding.reason


def test_make_is_not_reported_while_the_repo_still_has_a_makefile(repo: Path, tmp_path: Path) -> None:
    (repo / "Makefile").write_text("ci:\n\ttrue\n")
    _git(repo, "add", "Makefile")
    mem = tmp_path / "memory"
    _memory(mem, "feedback_ci.md", "Before pushing, run `make ci`.")
    assert scan.scan_memory_dir(mem, repo) == []


def test_invoking_overmind_with_no_procfile_is_reported(repo: Path, tmp_path: Path) -> None:
    """The case a path check could not catch: a whole memory built on a dead runner."""
    mem = tmp_path / "memory"
    _memory(mem, "reference_env.md", "`overmind start` loads the env.")
    [finding] = scan.scan_memory_dir(mem, repo)
    assert finding.kind == "command"


def test_a_moon_task_is_checked_only_against_a_real_project(repo: Path, tmp_path: Path) -> None:
    index = scan.RepoIndex(repo, moon_tasks={"web:check", "api:test-unit"})
    mem = tmp_path / "memory"
    _memory(mem, "feedback_tasks.md", "Run `web:check`, then `web:lint`, and label it `status:ready`.")
    findings = scan.scan_memory_dir(mem, repo, index=index)
    assert [f.claim for f in findings] == ["web:lint"]


# --- the CLI end to end -----------------------------------------------------


def test_cli_reports_json_for_a_named_memory_dir(repo: Path, tmp_path: Path) -> None:
    mem = tmp_path / "memory"
    _memory(mem, "feedback_ci.md", "Run `make ci` and read `apps/gone/thing.py`.")
    _memory(mem, "feedback_fine.md", "See `docs/contributing.rst`.")
    result = subprocess.run(
        [sys.executable, str(SKILL / "scan.py"), "--memory", str(mem), "--repo", str(repo), "--json"],
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    report = json.loads(result.stdout)
    assert report["instructional_scanned"] == 2
    assert {f["file"] for f in report["findings"]} == {"feedback_ci.md"}
    assert {f["claim"] for f in report["findings"]} == {"make ci", "apps/gone/thing.py"}
