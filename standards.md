# R/Bioconductor Package Development Standards v1.1

Rules for developing R packages distributed through Bioconductor. Loaded
at session start by a hook in each package. Rationale for each rule:
README.md in the r-bioc-dev-standards repo.

## Precedence
1. Package AGENTS.md "Overrides"
2. This file
3. Skill and plugin defaults (superbrainstorming, Bioconductor, others)

On conflict, follow the higher level and say so.

## Workflow
1. EVALUATE, no edits. Bug: reproduce it, trace the root cause, report it
   before proposing a fix. Feature: brainstorming. Dependency change: read
   upstream NEWS, list affected call sites. Wait for go-ahead.
2. SPEC: what changes, why, and how it is tested. Cover whichever apply:
   code, docs, data, tests, vignettes/articles, NEWS, version bump, checks,
   release port. Small change: in chat. Larger or unsure: a file in
   `dev/plans/`, committed after branching. A brainstorming design is the
   spec. No step-by-step implementation plan. Wait for approval.
3. EXECUTE: fetch the shared repo's `devel`, then branch as `fix/<topic>` or
   `feature/<topic>` before writing code. Never work on `devel` or
   `RELEASE_*`. Implement from the spec and stay within it. Test first with
   testthat: each new test must fail on its assertion, not on a missing
   function. Never weaken, skip, or delete a test to make it pass; if one
   looks wrong, ask. Make small local commits that say what and why.
4. REVIEW: give a fresh subagent the spec to check the diff against, then
   run `/code-review` on the branch. Fix findings, or say why one doesn't
   apply.
5. HAND OFF: stop before anything leaves the machine. Give a summary, list
   anything unverified, say whether results, numbers, or plots change, and
   show `git log devel..HEAD` and `git diff devel...HEAD`. No push, PR, or
   merge until the developer approves.
6. AFTER APPROVAL: push the branch and open a PR with base `devel` (not the
   default branch). Fill in the PR template, but never its "Scientific
   correctness" section; a person verifies that. Put follow-up fixes on the
   same branch; never open a second PR. Merge only after CI is green and a
   person approves on GitHub. No local merges. No history rewrites after a
   push.

Specs go in `dev/plans/`, never `docs/`, including `docs/specs/`.

## Remotes
- Identify remotes by URL (`git remote -v`), not by name.
- Usual names: `origin` = where you push; the GitHub org or owner name =
  shared repo (when working from a fork); `bioc` = git.bioconductor.org.
- Never push to Bioconductor. That is a maintainer action.

## Branches and tags
- `devel`: all development. The PR base for everything except release
  fixes. Mirrors Bioconductor devel.
- `RELEASE_X_Y`: release fixes only. Mirrors the Bioconductor release branch.
- `main`/`master` (stable, the GitHub default): a CI-maintained copy of the
  current release. Never commit to it, branch from it, push it, or open PRs
  against it.
- Never create, move, or push tags. CI tags each release version.

## Commands
- Use only Makefile targets: `test`, `test-one FILTER=<pattern>`, `check`,
  `check-full`, `bioccheck`, `docs`, `lint`, `coverage`, `site-check`,
  `article FILTER=<name>`.
- Extra targets are allowed only if AGENTS.md lists them. Ask before
  running any extra target that AGENTS.md doesn't mark as safe.
- `make test-one FILTER=<pattern>` only: no other targets, variables, or
  flags on that command line.
- While developing: `test-one`. Before hand-off: `test` and `coverage`.
  Before a PR: `check-full` and `bioccheck`.
- If a target is missing, ask. Never substitute raw `R CMD` or `Rscript`,
  even when a skill suggests them.
- Bioconductor skills: build-check-bioccheck to triage check output (write
  its files outside the repo); update-r-news to draft NEWS.

## User-facing code (examples, vignettes, articles)
Audience: R novices who copy code verbatim. The code must run as pasted.
- One operation per line, descriptive object names, a short comment per
  step.
- Use defaults; set only the arguments being demonstrated.
- `library()` plus plain calls; no `pkg::` prefixes.
- Avoid long pipes, nesting, `lapply`/`do.call`, closures, and ad hoc
  helpers.
- Bundled or simulated data only; `set.seed()` before anything random.
- Hide plumbing in `echo = FALSE` chunks or package functions.
- Vignettes: short, small data, end with `sessionInfo()`. Full real-data
  workflows go in `vignettes/articles/`.
- Use `\donttest{}` rather than `\dontrun{}`.
- When behavior changes, update the affected vignettes and articles.

## Package code
- Match the package's existing naming for functions, arguments, and files.
- Keep related functions in one file; accessors and utilities in their own
  files.
- Keep functions small, with no duplicated logic. Prefix internal helpers
  with `.` if the package does.
- Call other packages via `pkg::fun()` or `@importFrom`.
- Validate inputs early; `stop()` messages name the argument and the
  problem.
- `TRUE`/`FALSE`, never `T`/`F`. Test flags with `isTRUE()`.
- Use accessors, never `@`, outside class definitions. Reuse Bioconductor
  classes (SingleCellExperiment, SummarizedExperiment).
- BiocCheck and lintr: at most 80 columns, indent as the package's
  `.lintr` sets, `vapply` over `sapply`, `seq_len`/`seq_along` over `1:n`,
  `message()`/`warning()` rather than `print()`/`cat()`.
- styler on new files only. Never restyle existing code in a functional
  change; lint backlog gets its own PR.

## Docs and data
- Exported functions: roxygen title, description, `@param` for every
  argument (with its default), `@return`, runnable `@examples`. `@export`
  only user-facing functions.
- Never hand-edit generated files (`man/*.Rd`, `NAMESPACE`, `RcppExports`,
  `stanExports_*`, `R/stanmodels.R`, `docs/`). Edit the source, then run
  `make docs`.
- Every `data/` object: a `data-raw/` script with a fixed seed, plus
  `R/data.R` docs with `@format` (and `@source` if external).
- NEWS.md: an entry for every user-facing change, under the upcoming
  version, in the file's existing format.
- pkgdown: add new exports to `_pkgdown.yml`, then run `make site-check`.
  Preview single pages only; never `build_site()` or deploy. Render each
  edited vignette or article with `make article FILTER=<name>`.

## Testing
- Bug fixes start with a failing regression test.
- New functions: test expected results plus error paths
  (`expect_error(..., regexp =)`).
- The whole suite must pass, not just nearby tests.
- Tiny fixtures. Coverage (`make coverage`) must not drop.
- Optional dependencies (for example Python via reticulate): skip cleanly
  when missing.

## Shiny (`inst/shiny`)
- No analysis logic in the app. Server code only calls exported, tested
  functions. Implement a new feature as a function first.
- Test with `shiny::testServer()`. Verify UI changes with a screenshot of
  the running app.

## Bioconductor versions and release fixes
- Versions are x.y.z: odd y in devel, even y in release. Bump z by 1 for
  every change bound for Bioconductor. Never change x or y, except y = 99 in
  devel on the maintainer's request.
- Take the R version for Bioc devel from bioconductor.org/config.yaml. Flag
  a mismatch before running checks.
- Deprecation: `.Deprecated()` in one release, `.Defunct()` in the next,
  then remove.
- Release fix: recommend devel-only or devel plus release during
  evaluation; the developer decides. Port only wrong results, common
  crashes, or install failures. Branch from `RELEASE_X_Y`, cherry-pick the
  fix, bump the release z separately, and use the same hand-off. Never merge
  `devel` into a release branch.

## Checks and releases
- ERROR and WARNING block. Triage each NOTE as a defect, an environment gap,
  or a false positive (NOTEs about `.git` size or dependency count are
  usually fine).
- Record real findings as GitHub issues. One category per fix PR.
- The nightly Bioconductor build report is the source of truth; CI is an
  early warning.
- Releases follow `dev/RELEASE.md`. Always: sync with Bioc devel, clean
  `check-full` and `bioccheck`, tarball under 10 MB, NEWS complete,
  deprecations advanced, `/security-review` on the release diff.

## Scope and safety
- Minimal, on-topic changes. Log unrelated problems as issues.
- Structural changes (file splits, DESCRIPTION dependencies, class redesign)
  need an approved ADR in `dev/adr/` (see its README); propose via an
  issue. If the package uses renv, update the lockfile when dependencies
  change.
- Never edit `.claude/settings.json`, `dev/claude-settings.json`,
  `Makefile`, `dev/hooks/`, `.lintr`, the downloaded copies in
  `~/.cache/r-bioc-dev-standards/`, or this file, or run
  `make claude-setup`. Propose changes instead.
- Never delete files or branches, run `git clean`, or force-push. Ask the
  developer.
- No secrets, tokens, or absolute local paths in commits.
- Flag any effect on related packages named in AGENTS.md.
- Maintainer docs live in `dev/`.
