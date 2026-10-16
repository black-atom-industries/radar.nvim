---
name: repo-changelog
description:
  "Curate the release section of CHANGELOG.md for radar.nvim. Use it when a release is being prepared: it writes the
  Highlights on the release branch and the same section into the release PR description."
argument-hint: "[version; defaults to the release PR's version]"
allowed-tools: Read Edit Bash
---

# Curate the changelog

release-please writes each release section of `CHANGELOG.md` in its release PR: a heading with the version, compare link,
and date, then the Conventional Commits grouped by the configured `changelog-sections`. The curated part is
`### Highlights`, written on the release branch directly below that heading. release-please publishes the release PR
description as the GitHub Release notes, so the description carries the same section and the release page matches the
changelog.

Read [`references/curated-release.md`](references/curated-release.md) for the workflow.

## Format

- Leave the generated heading and commit groups as release-please wrote them. The commit list stays complete, including the
  commits a highlight covers.
- A release section never contains a line that is only `---`. release-please reads the notes from the PR description
  between its first and last `---` line.
- Run the `humanizer` skill in embedded mode on every highlight before handing it over.
