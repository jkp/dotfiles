#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.8"
# ///

import json
import sys
import re
import subprocess
from pathlib import Path

def find_git_root():
    """
    Find the git repository root directory from the current working directory.
    
    Returns:
        Path: The path to the git root directory or current directory if not in a git repo
    """
    try:
        # Run git rev-parse to find the top-level directory of the current repository
        result = subprocess.run(
            ['git', 'rev-parse', '--show-toplevel'],
            capture_output=True,
            text=True,
            check=True
        )
        return Path(result.stdout.strip())
    except (subprocess.SubprocessError, subprocess.CalledProcessError):
        # If not in a git repository or git command fails, return current directory
        return Path.cwd()

def has_no_verify_flag(command):
    """
    Check if a command contains the --no-verify flag.
    
    Args:
        command: The command string to check
        
    Returns:
        bool: True if the command contains --no-verify, False otherwise
    """
    # Normalize command by removing extra spaces
    normalized = ' '.join(command.split())
    
    # Check for --no-verify flag
    if '--no-verify' in normalized:
        return True
    
    return False

def get_current_branch():
    """Get the current git branch name, or None if not in a repo / detached HEAD."""
    try:
        result = subprocess.run(
            ['git', 'rev-parse', '--abbrev-ref', 'HEAD'],
            capture_output=True, text=True, check=True
        )
        return result.stdout.strip()
    except (subprocess.SubprocessError, subprocess.CalledProcessError):
        return None


def is_push_to_protected_branch(command):
    """
    Block any git push that would write to main or master.

    Two-layer check:
    1. Pattern match: explicit "git push ... main/master" in the command
    2. Branch check: if on main/master and no explicit non-protected branch
       target is given (catches bare push, push origin HEAD, etc.)
    """
    # Match "git push" with optional flags/args between git and push (e.g. git -C /path push)
    if not re.search(r'\bgit\b.*\bpush\b', command):
        return False

    # Layer 1: explicit target branch in command
    if re.search(r'\bgit\b.*\bpush\b.*\b(main|master)\b', command):
        return True

    # Layer 2: on a protected branch with no explicit safe target
    branch = get_current_branch()
    if branch in ('main', 'master'):
        # Check if command explicitly names a non-protected branch target.
        # After "git push [flags] <remote>", the next non-flag arg is the refspec/branch.
        # If it looks like a branch name and isn't main/master, allow it.
        parts = command.split('&&')[0].split('||')[0].split(';')[0]  # first command only
        tokens = parts.split()
        # Walk past "git", "push", flags (--*), and remote name
        past_push = False
        remote_seen = False
        for token in tokens:
            if token == 'push':
                past_push = True
                continue
            if not past_push:
                continue
            if token.startswith('-'):
                continue  # skip flags
            if not remote_seen:
                remote_seen = True
                continue  # skip remote name (origin, etc.)
            # This token is the branch/refspec target
            if token not in ('main', 'master', 'HEAD'):
                return False  # explicit non-protected target, allow it
            break
        # No explicit safe target found — block
        return True

    return False


def is_env_file_access(tool_name, tool_input):
    """
    Check if any tool is trying to access .env files containing sensitive data.
    """
    if tool_name in ['Read', 'Edit', 'MultiEdit', 'Write', 'Bash']:
        # Check file paths for file-based tools
        if tool_name in ['Read', 'Edit', 'MultiEdit', 'Write']:
            file_path = tool_input.get('file_path', '')
            if '.env' in file_path and not file_path.endswith('.env.sample'):
                return True
        
        # Check bash commands for .env file access
        elif tool_name == 'Bash':
            command = tool_input.get('command', '')
            # Pattern to detect .env file access (but allow .env.sample)
            env_patterns = [
                r'\b\.env\b(?!\.sample)',  # .env but not .env.sample
                r'cat\s+.*\.env\b(?!\.sample)',  # cat .env
                r'echo\s+.*>\s*\.env\b(?!\.sample)',  # echo > .env
                r'touch\s+.*\.env\b(?!\.sample)',  # touch .env
                r'cp\s+.*\.env\b(?!\.sample)',  # cp .env
                r'mv\s+.*\.env\b(?!\.sample)',  # mv .env
            ]
            
            for pattern in env_patterns:
                if re.search(pattern, command):
                    return True
    
    return False

def main():
    try:
        # Read JSON input from stdin
        input_data = json.load(sys.stdin)
        
        tool_name = input_data.get('tool_name', '')
        tool_input = input_data.get('tool_input', {})
        
        # Block Claude from touching the opt-out marker (human-only)
        marker = '.claude-allow-main-push'
        file_path = tool_input.get('file_path', '')
        command = tool_input.get('command', '') if tool_name == 'Bash' else ''
        if marker in file_path or marker in command:
            print(f"BLOCKED: {marker} is a human-only file. Ask the user to create it.", file=sys.stderr)
            sys.exit(2)

        # Check for .env file access (blocks access to sensitive environment files)
        if is_env_file_access(tool_name, tool_input):
            print("BLOCKED: Access to .env files containing sensitive data is prohibited", file=sys.stderr)
            print("Use .env.sample for template files instead", file=sys.stderr)
            sys.exit(2)  # Exit code 2 blocks tool call and shows error to Claude
        
        # Check for dangerous operations
        if tool_name == 'Bash':
            command = tool_input.get('command', '')

            # Block --no-verify flag
            if has_no_verify_flag(command):
                print("BLOCKED: commiting with --no-verify is not allowed! Fix the real issue", file=sys.stderr)
                sys.exit(2)  # Exit code 2 blocks tool call and shows error to Claude

            # Block pushing to main/master branch (unless repo opts out)
            git_root = find_git_root()
            if not (git_root / '.claude-allow-main-push').exists():
                if is_push_to_protected_branch(command):
                    print("BLOCKED: Pushing to main/master is not allowed! Create a feature branch and PR instead", file=sys.stderr)
                    print("To opt out, create .claude-allow-main-push in the repo root", file=sys.stderr)
                    sys.exit(2)

            # Block manipulation of git hooks
            git_hook_patterns = [
                r'\.git/hooks',  # Any access to .git/hooks directory
                r'mv\s+.*\.git/hooks',  # Move git hooks
                r'rm\s+.*\.git/hooks',  # Remove git hooks
                r'chmod\s+.*\.git/hooks',  # Change permissions on git hooks
                r'cp\s+.*\.git/hooks',  # Copy to/from git hooks
            ]

            for pattern in git_hook_patterns:
                if re.search(pattern, command):
                    print("BLOCKED: Manipulation of git hooks is not allowed! Hooks protect code quality", file=sys.stderr)
                    sys.exit(2)  # Exit code 2 blocks tool call and shows error to Claude
        
        # Ensure log directory exists, relative to git root
        git_root = find_git_root()
        log_dir = git_root / 'logs'
        log_dir.mkdir(parents=True, exist_ok=True)
        log_path = log_dir / 'pre_tool_use.json'
        
        # Read existing log data or initialize empty list
        if log_path.exists():
            with open(log_path, 'r') as f:
                try:
                    log_data = json.load(f)
                except (json.JSONDecodeError, ValueError):
                    log_data = []
        else:
            log_data = []
        
        # Append new data
        log_data.append(input_data)
        
        # Write back to file with formatting
        with open(log_path, 'w') as f:
            json.dump(log_data, f, indent=2)
        
        sys.exit(0)
        
    except json.JSONDecodeError:
        # Gracefully handle JSON decode errors
        sys.exit(0)
    except Exception:
        # Handle any other errors gracefully
        sys.exit(0)

if __name__ == '__main__':
    main()