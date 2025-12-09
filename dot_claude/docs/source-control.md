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
