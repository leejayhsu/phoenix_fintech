---
description: Commit all uncommitted changes into logical Conventional Commits without pushing.
agent: build
---

Commit all uncommitted changes without pushing to remote.

Inspect `git status`, `git diff`, and `git log --oneline -10` first. Determine whether the changes should be one commit or multiple logically grouped commits.

For each group, stage only the files or hunks that belong in that group, create a Conventional Commit message, and commit it. Include all uncommitted changes across the worktree by the end.

Do not amend existing commits. Do not use destructive git commands.

If there are no uncommitted changes, do not create a commit; report that there was nothing to commit.
