# Spec: comment on and close issues fixed in devel or a release branch

## Why

GitHub closes an issue from a PR's "Fixes #N" only when the PR merges into
the default branch. In these packages the default branch is the stable
copy of the current release, which a workflow updates twice a year, and
PRs merge into `devel` or `RELEASE_X_Y`. So fixed issues stay open with no
sign that they are fixed or when users will get the fix.

## Behavior

A shared reusable workflow, `.github/workflows/close-fixed-issues.yaml`,
called from a package by `templates/github/workflows/close-fixed-issues.yaml`
(the same pattern as `pr-base-devel`).

- Trigger (caller): `pull_request_target`, `types: [closed]`, branches
  `devel` and `RELEASE_*`. The shared job runs only when the PR was merged.
- Find issue references in the PR description, after removing HTML
  comments (so the PR template's instructions never match): `close`, `closes`,
  `closed`, `fix`, `fixes`, `fixed`, `resolve`, `resolves`, `resolved`,
  any case, optional colon, then `#N`. Only same-repo `#N` counts
  (`owner/repo#N` and URLs are ignored). Duplicates are dropped. There is
  no cap on the number of issues: a maintainer approved the description by
  merging, and a final refactor PR can legitimately list many.
- For each number: skip it if it doesn't exist (HTTP 404 or 410) or is a
  PR; any other lookup error fails the run after the rest are handled. Otherwise
  comment, then close it as completed if it is open. Already-closed issues
  get the comment but stay closed.
- `Package:` and `Version:` come from DESCRIPTION at the merge commit,
  read through the API.
- Comment for a merge into `devel`:

  > Fixed in the development version of {pkg} ({version}) by #{PR}. The
  > fix reaches the release version, and this repository's default branch,
  > at the next Bioconductor release (April or October). To use it sooner,
  > install the development version, which may need R-devel:
  >
  > ```r
  > remotes::install_github("{owner}/{repo}@devel")
  > ```

- Comment for a merge into `RELEASE_X_Y`:

  > Also fixed in the release version of {pkg} ({version}, RELEASE_X_Y) by
  > #{PR}. `BiocManager::install("{pkg}")` gets the fix once the maintainer
  > pushes it to Bioconductor and the build finishes, usually within a few
  > days.

- PRs into `refactor/*` are not handled. The final refactor PR into
  `devel` lists `Fixes #N` for every issue its pieces fixed; piece PRs say
  "Part of #N".

## Security

- `pull_request_target` gives fork PRs a token that can write issues,
  which plain `pull_request` doesn't. It is safe here because the job never
  checks out or runs PR code: no checkout, no actions, only the runner's
  `gh`.
- The PR body reaches the script only through an environment variable,
  never `${{ }}` interpolation. Each extracted number must be all digits.
- Permissions: `issues: write` and `contents: read` in both the caller and
  the shared job.
- The PR description is acted on only after a maintainer merges the PR,
  which is a person's approval of it.
- The file header records this reasoning, as `sync-stable.yaml` does.

## What changes

- New: `.github/workflows/close-fixed-issues.yaml` and
  `templates/github/workflows/close-fixed-issues.yaml`.
- `standards.md`: step 6 says to write `Fixes #N` in the PR description
  for each issue the PR fixes; the refactor entry says the final PR lists
  them all.
- `templates/github/pull_request_template.md`: the "Link the issue"
  comment explains `Fixes #N` and what happens on merge.
- `README.md`: a row in the files table, the templates row names three
  workflows, and an "Issues" paragraph in "Branches, releases, and tags";
  the "Large refactors" list notes `Fixes #N` in the final PR.
- `ADOPTING.md`: step 7 copies the new caller with the others (four
  files). Since December 2025 GitHub reads a `pull_request_target`
  workflow from the default branch, here the stable branch, so the caller
  takes effect only once it is on the release branch and the sync copies
  it over. "Updating" notes that packages adopted earlier copy the new
  caller once, the same way.

## How it is checked

The workflow never runs in this repo. Extract the parsing and filtering
logic and run it locally on sample PR bodies: each keyword, colons, mixed
case, `owner/repo#N` and URLs, duplicates, many issues, and
injection-looking text. Run `actionlint` and `shellcheck` if installed.
The first live run is in a package after `v1` moves, or in a scratch repo
whose caller points at this branch, if the maintainer wants that first.
