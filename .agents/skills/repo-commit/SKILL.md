---
name: repo-commit
description:
  "Prepare a commit in the radar.nvim repository. Use this when the user asks to commit, stage, ship, or finish a change.
  Stage selectively, run the CI-parity checks, show the exact Conventional Commit, and wait for explicit approval."
argument-hint: "[message-hint or scope-hint, optional]"
allowed-tools: Bash Read
---

# Commit a change

This skill is the commit workflow for this repository. Its sections 3 to 5 hold the repo's docs list, checks, and commit
grammar; global commit workflows read them from here. To sort several changes into commits, use `nbr-git-commit-buckets`
when it is installed. Do not commit until the user approves the final message.
Keep unrelated work unstaged. Never bypass hooks with `--no-verify`, stage secrets or credentials, or rewrite history without
explicit approval. Keep each commit atomic.

## 1. Survey the tree

Run:

```sh
git status --short
git diff --stat
git diff --cached --stat
git log --oneline -5
```

Classify paths as **in scope**, **held back**, or **stray**. Surface unexpected edits and never hide them with reset,
restore, or clean.

## 2. Stage selectively

Stage named paths only:

```sh
git add path/to/file path/to/another-file
```

Never use `git add .` or `git add -A`. Unstage any held-back file a hook or helper touched.

## 3. Audit docs

When staged changes add or change a config key, command, or domain term, check `README.md`, `AGENTS.md`, and `docs/concept.md` against the diff. Fix and stage the
confirmed docs in this same commit.

## 4. Verify

Run:

```sh
make check
```

`make check` is the CI-parity pass. The pre-commit hook runs `make check` on staged Lua files. If verification fails, fix the cause, restage, and run it again.

A docs-only change may skip `make check`, but say that it was skipped.

## 5. Draft and ask

The message is a [Conventional Commit](https://www.conventionalcommits.org/). release-please derives the next version from it
and lists the subject in the release's `CHANGELOG.md` section:

```text
<type>(<scope>): <imperative summary>
```

End the subject with ` (#<issue>)` when the change closes or belongs to a GitHub issue.

- `feat` for new user-facing behavior, `fix` for a user-facing bug fix. Both trigger a release.
- `docs`, `refactor`, `perf`, `test`, `ci`, `chore` for the rest. Only `docs`, `refactor`, and `perf` count toward a release.
- `docs` is for user-facing documentation. Agent skills, `AGENTS.md`, and maintainer-only docs are `chore`, so they
  never open a release on their own.
- The scope is the area, as in recent history: `ui`, `keys`, `locks`, `recent`, `persistence`, `test`. Omit it when the change spans areas.
- A breaking change adds `!` after the scope and a `BREAKING CHANGE:` footer.

Keep the subject under 70 characters, not counting a suffix, and describe the outcome, not the file list. Add a short bullet body only when the change
has several moving parts. Do not narrate history with phrases such as "instead of" or "no longer".

Show:

1. the final in-scope paths;
2. held-back and stray paths;
3. the exact commit message;
4. the verification result.

Then ask: **Go-ahead to commit?**

## 6. Commit after approval

Use a heredoc so the message stays intact:

```sh
git commit -m "$(cat <<'MSG'
<message>
MSG
)"
```

The pre-commit hook runs its checks. If a hook fails, fix the cause, restage, and make a new commit attempt. Do not amend an
unrelated commit. Confirm the new log entry and final status.
