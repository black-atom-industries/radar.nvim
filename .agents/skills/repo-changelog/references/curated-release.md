# Curated release

The release section is curated on the release-please branch, after release-please has finished its run for the latest
push to `main`. The most recent curated section is the reference shape.

## Workflow

1. Check out the release PR branch with `gh pr checkout <number>`.
2. Read the generated section and the commits behind it, and rank the outcomes by impact on a user.
3. Write `### Highlights` in impact order (below), directly under the release heading and above the first generated group.
4. Run the `humanizer` skill on the highlights, then ``.
5. Commit the section as `docs: curate the <version> release notes` and push the branch.
6. Write the section into the PR description with `gh pr edit <number> --body-file <file>`. Keep release-please's header
   line, the `---` lines around the notes, and its footer; the notes between them are the section from `CHANGELOG.md`,
   heading included.

The curation is done when a reader who stops after the highlights knows every change worth acting on, and the PR
description's notes match the `CHANGELOG.md` section line for line.

Any push to `main` makes release-please rebuild the branch and the description, which drops the curation. Curate last and
merge right after.

## Highlights

Highlights are the one place where prose addresses the reader. In order:

1. **Feature blocks** (`#### Name`): the largest outcomes first. Promote undersold work hiding in the commit list; a new
   workflow often matters more than a new option. Show config or usage as a code block when the reader will copy it.
2. **Important fixes**: fixes a user would notice or has worked around.
3. **Upgrading from X.Y**: last, one sentence per breaking change and the change as a `diff` block, old line `-`, new line
   `+`.

## Screenshots and clips

A visible feature or fix carries its images directly under its text, one image per line, with the alt text written as the
caption.

- A screenshot is a WebP captured clean at a fixed size. A project with light and dark themes gets a light and a dark
  image.
- Motion a still cannot show, such as a resize, a transition, or a terminal session, is a clip: an animated WebP recorded
  with the `nbr-record-clip` skill. Put a clip first when it shows the feature better than the stills.

Store both under `docs/assets/changelog/<version>-<topic>.webp`. Reference them with an absolute URL pinned to the release
tag, `https://raw.githubusercontent.com/black-atom-industries/radar.nvim/v<version>/...`, so they render in the GitHub Release notes and keep
showing that release after later captures replace the files on `main`.
