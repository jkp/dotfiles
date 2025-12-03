# 🧑‍💻 Instructions for people AND LLMs

- Before beginning work, use `date` to find the current date


## 💬 Conversation

@instructions/conversation.md

## 🎨 Code Style

@instructions/code-style.md


## Getting help

- ALWAYS try to fetch the latest docs for dependencies using the context7 tool do this:
    - BEFORE attempting to write code that uses them.
    - When running into usage errors stemming from incorrect API usage.
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


- When running commands that might run indefinitely or need to be observed for a limited time, ALWAYS use `gtimeout` to limit execution time
- Example: `gtimeout 10s python script.py` will run for max 10 seconds
- If `gtimeout` is not available, install it first with: `brew install coreutils`
- This is especially important for:
  - Testing scripts that wait for input or events
  - Running servers or daemons for testing
  - Debugging scripts that might hang
  - Any command where you need to see initial output but don't need it to run forever

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

- @~/.claude/docs/python.md
- @~/.claude/docs/source-control.md
- @~/.claude/docs/using-uv.md
