# 🧑‍💻 Instructions for people AND LLMs

## Personal work tracking

When starting or resuming project work, read
`~/.agents/skills/personal-beads/SKILL.md` and apply its project discovery
and local-first capture workflow. This is a personal preference, not permission
to initialise a tracker or change team policy. Repository requirements still apply.

- Before beginning work, use `date` to find the current date


## 💬 Conversation

- Any time you interact with me, you MUST address me as "J-Dog"
- If I user ask a question, only answer the question, do not edit code
- Don't say:
  - "You're right"
  - "I apologize"
  - "I'm sorry"
  - "Let me explain"
  - any other introduction or transition
- Immediately get to the point
- NEVER suggest wrapping up, ending the session, or "picking this up later". Sessions run for days. I will tell you when I'm done. When a task completes, present what's next or ask what I want to do — don't frame it as a stopping point.
- My shell is fish. Any command or script you give me to run in my own terminal must be fish syntax (`set X y`, not `X=y`; `set -x X y`, not `export`; `(cmd)` substitution; no bash heredocs or `[[ ]]`). If something genuinely needs bash, wrap it in `bash -c '…'`.
- When proposing solutions, don't default to "the simplest approach." Present the correct solution. If simplicity and correctness diverge, explain both and let me choose. If the correct solution is clearly better, just do it — don't offer a shortcut that creates tech debt.

## Getting help

- ALWAYS try to follow the official documentation if you're running into issues with an API; its more efficient than reverse engineering in most cases.
- ALWAYS ask for clarification rather than making assumptions.
- If you're having trouble with something, it's ok to stop and ask for help. Especially if it's something your human might be better at.

## Tooling

- Use `mise` (https://mise.jdx.dev/configuration.html) for managing the local shell environment.
- Use `gh` for interacting with GitHub.

## Date and Time Handling

- When working with dates, ALWAYS explicitly calculate and state the day of the week
- When presenting schedules or calendar data:
  - First identify today's date and day of week from the system environment
  - Calculate the day of week for each date mentioned
  - Present dates in format: "Day of Week (Month/Day)" e.g., "Friday (6/20)"
  - Double-check date calculations before presenting them
- Never assume day of week from date patterns - always calculate

## Running Commands


- When running commands that might run indefinitely or need to be observed for a limited time, ALWAYS use `timeout` (`gtimeout` on macOS) to limit execution time
- Example: `timeout 10s python script.py` will run for max 10 seconds
- On macOS, if `gtimeout` is not available, install it first with: `brew install coreutils`
- This is especially important for:
  - Testing scripts that wait for input or events
  - Running servers or daemons for testing
  - Debugging scripts that might hang
  - Any command where you need to see initial output but don't need it to run forever

## When Scripts Are Slow, Go Native

If a script is slow or painful to debug, switch to a native utility immediately. With LLM assistance, writing Swift/Rust/Go costs no more than writing a script—the old tradeoffs (learning curve, memory management, boilerplate) no longer apply.

Don't tolerate slow scripts. There's no reason to anymore.

## Infrastructure & Configuration Management

- NEVER make adhoc fixes to production state on servers unless explicitly instructed
- It's acceptable to run adhoc diagnostic commands to discover what needs fixing
- It's acceptable to run adhoc cleanup of failed/temporary state to prepare for proper deployment
  - Examples: removing broken config directories, stopping failed services, cleaning up test files
  - These cleanup tasks should NOT be added to Ansible (they're one-time fixes, not repeatable state)
- Once you understand the issue, the fix MUST go into Ansible/configuration management
- Apply fixes through the configuration management system (e.g., `ansible-playbook`)
- This ensures:
  - Changes are documented and reproducible
  - Servers can be rebuilt from scratch
  - Configuration drift is prevented
  - Changes are version controlled

## Testing

- Tests MUST cover the functionality being implemented.
- NEVER ignore the output of the system or the tests - Logs and messages often contain CRITICAL information.
- TEST OUTPUT MUST BE PRISTINE TO PASS
- If the logs are supposed to contain errors, capture and test it.
- NO EXCEPTIONS POLICY: Under no circumstances should you mark any test type as "not applicable". Every project, regardless of size or complexity, MUST have unit tests, integration tests, AND end-to-end tests. If you believe a test type doesn't apply, you need the human to say exactly "I AUTHORIZE YOU TO SKIP WRITING TESTS THIS TIME"
- When making changes to tests directly, run them and makes sure they pass before committing - though pre-commit hooks will run them this shortens the feedback loop and is more direct.

## We practice TDD. That means:

- Write tests before writing the implementation code
- Only write enough code to make the failing test pass
- Refactor code continuously while ensuring tests still pass

### TDD Implementation Process

- Write a failing test that defines a desired function or improvement
- Run the test to confirm it fails as expected
- Commit the failing test
- Write minimal code to make the test pass
- Run the test to confirm success
- Commit the passing code
- Refactor code to improve design while keeping tests green
- Commit the refactored code
- Repeat the cycle for each new feature or bugfix

# Specific Technologies

## Python

- Use an isolated virtual environment for each project, managed with mise (https://mise.jdx.dev/mise-cookbook/python.html)
- I prefer to use uv for everything (uv add, uv run, etc)
- Do not use old fashioned methods for package management like poetry, pip or easy_install.
- Make sure that there is a pyproject.toml file in the root directory.
- If there isn't a pyproject.toml file, create one using uv by running uv init.
- Never use a requirements.txt file: always put dependencies in pyproject.toml.
- Do not manage dependencies manually: use uv for dependency management.
- For uv commands and workflows, read `~/.agents/docs/using-uv.md`.

## Source Control

- Let's try and use JJ as much as we can. If JJ isn't configured, or not available then use git.
- Commit messages should be concise and descriptive.
- Commit messages should follow the conventional commit format.
- Commit messages should be written in the imperative mood.
- Commit messages should be written in the present tense.

### Branching Workflow

Before starting work on a feature or set of related changes:

1. Confirm you're on the correct branch (`git branch` or `jj status`)
2. If starting new work, create a branch from an up-to-date main:
   ```bash
   git checkout main && git pull && git checkout -b <branch-name>
   # or with jj:
   jj git fetch && jj new main -m "<description>"
   ```
3. Never commit directly to main for feature work

This prevents accidentally committing to the wrong branch, which requires painful reconciliation when discovered late.

### Atomic Commits

- ALWAYS prefer small, atomic commits that do a single thing.
- Each commit should represent one logical change (one feature, one fix, one refactor).
- If you have multiple unrelated changes, split them into separate commits.
- This makes history easier to read, review, bisect, and revert if needed.

### PR Review Response Workflow

When pushing updates to an existing PR that has received review comments:

1. **Before pushing**, check if the PR has review comments: `gh pr view --json reviews,comments`
2. **If there are unaddressed comments**, respond to them BEFORE pushing:
   - For changes you made: explain what you changed and why
   - For suggestions you're not implementing: provide rationale for the decision
   - For questions: answer them
3. **Post responses via `gh pr comment`** so the reviewer sees your thinking alongside the new commits
4. **Then push** - this triggers CI rebuild and re-review with full context available

**Why this matters**: The push triggers automated review. If your rationale for decisions isn't in the PR comments, the reviewer (human or automated) can't understand your reasoning and may re-raise the same concerns.

This is guidance, not a hard rule - use judgment for trivial updates or when there are no substantive comments to address.
