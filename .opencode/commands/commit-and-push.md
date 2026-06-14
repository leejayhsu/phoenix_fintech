---
description: Commit all uncommitted changes into logical Conventional Commits, then push to remote.
agent: build
---

Commit and push all uncommitted changes.

Inspect `git status`, `git diff`, and `git log --oneline -10` first. Determine whether the changes should be one commit or multiple logically grouped commits.

For each group, stage only the files or hunks that belong in that group, create a Conventional Commit message, and commit it. Include all uncommitted changes across the worktree by the end.

Do not amend existing commits. Do not use destructive git commands.

After committing, push the current branch to its configured remote. If no upstream is configured, set upstream to `origin` for the current branch.

If there are no uncommitted changes, do not create a commit; report that there was nothing to commit.
