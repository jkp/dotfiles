#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$root/dot_local/bin/executable_backup-exclusions" <<'PY'
import fcntl
import os
import pathlib
import sqlite3
import subprocess
import sys
import tempfile
import runpy
import time
from unittest.mock import patch

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp).resolve()
    checkout = root / 'checkout with spaces'
    checkout.mkdir()
    (checkout / '.git').touch()
    bin_dir = root / 'bin'
    bin_dir.mkdir()
    for name, body in {
        'launchctl': 'exit 0',
        'gtimeout': 'shift 4; exec \"$@\"',
        'asimov': 'printf "%s\\n" "$*" >> "$XDG_STATE_HOME/calls"\n[ ! -f "$XDG_STATE_HOME/fail" ]',
    }.items():
        tool = bin_dir / name
        tool.write_text('#!/bin/sh\n' + body + '\n')
        tool.chmod(0o755)
    env = dict(os.environ, XDG_STATE_HOME=tmp, PATH=f'{bin_dir}:/usr/bin:/bin')
    def run(*args):
        return subprocess.run([sys.executable, sys.argv[1], *map(str, args)], env=env,
                              capture_output=True, text=True, timeout=30)
    assert run(checkout).returncode == 0
    assert run(checkout).returncode == 0
    db = sqlite3.connect(root / 'backup-exclusions/queue.sqlite3')
    assert db.execute('select count(*) from jobs').fetchone()[0] == 1
    with (root / 'backup-exclusions/worker.lock').open('a') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        assert run('--run').returncode == 0
        assert not (root / 'calls').exists()
    (root / 'fail').touch()
    failed = run('--run')
    assert failed.returncode != 0
    assert db.execute('select count(*) from jobs').fetchone()[0] == 1
    (root / 'fail').unlink()
    assert run('--run').returncode == 0
    assert db.execute('select count(*) from jobs').fetchone()[0] == 0
    assert '--no-cache ' + str(checkout) in (root / 'calls').read_text()
    assert run(checkout).returncode == 0
    (checkout / '.git').unlink()
    before = (root / 'calls').read_text()
    assert run('--run').returncode == 0
    assert (root / 'calls').read_text() == before
    assert db.execute('select count(*) from jobs').fetchone()[0] == 0
    worker = runpy.run_path(sys.argv[1])
    home = root / 'home'
    work = home / 'Work'
    work.mkdir(parents=True)
    with patch.dict(os.environ, env), patch.object(sys, 'argv', ['worker', '--run']), \
         patch.object(pathlib.Path, 'home', return_value=home):
        for hour, expected in [(12, 0), (3, 1), (3, 0)]:
            now = time.mktime((2026, 11, 18, hour, 0, 0, 0, 0, -1))
            before = len((root / 'calls').read_text().splitlines())
            with patch.object(time, 'time', return_value=now):
                assert worker['main']() == 0
            calls = (root / 'calls').read_text().splitlines()[before:]
            assert len(calls) == expected
            if calls:
                assert str(work) in calls[0]
    dependency = checkout / 'node_modules'
    dependency.mkdir()
    venv = checkout / '.venv'
    venv.mkdir()
    assert run(dependency, venv).returncode == 0
    before = (root / 'calls').read_text()
    with patch.dict(os.environ, env), patch.object(sys, 'argv', ['worker', '--run']), \
         patch.dict(worker['main'].__globals__, exclude=lambda path: True):
        assert worker['main']() == 0
    assert db.execute('select count(*) from jobs').fetchone()[0] == 0
    assert (root / 'calls').read_text() == before
    assert run(checkout).returncode != 0
    link = checkout / 'other' / '.venv'
    link.parent.mkdir()
    link.symlink_to(dependency, target_is_directory=True)
    assert run(link).returncode != 0
    warning = f'! {root / "vanished"}: read-only, cannot be excluded — skipping.\n'
    with patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stderr=warning)):
        assert worker['scan'](str(work))
    (root / 'vanished').mkdir()
    with patch.object(subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, stderr=warning)):
        from contextlib import redirect_stderr, redirect_stdout
        from io import StringIO
        with redirect_stderr(StringIO()) as errors, redirect_stdout(StringIO()):
            assert not worker['scan'](str(work))
        assert warning in errors.getvalue()
print('backup-exclusions: PASS (deduplicate, single owner, retry, scoped scan, retired checkout)')
PY
