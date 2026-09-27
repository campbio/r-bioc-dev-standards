# r-bioc-dev-standards

Development standards for R packages distributed through Bioconductor,
and a process for adding or changing code in them with help from AI coding
agents such as Claude Code. The standards apply to people and agents alike,
and anyone maintaining a Bioconductor package can use or adapt them.

This repo has two versions of the same standards:

- **`standards.md`** is the condensed version that Claude Code loads
  automatically at the start of every session in a package that uses it.
  It's kept short because it takes up space in every session.
- **This README** explains the same rules in full, including why each one
  exists. Read this if you're new to a package that follows these
  standards, or if you want to understand or change a rule.

When you change a rule, update both files so they stay in sync.

## How the standards reach each package

Each package that uses the standards contains a small startup hook,
`dev/hooks/load-standards.sh`, registered in its `.claude/settings.json`.
When a Claude Code session starts, resumes, is cleared, or is compacted,
the hook downloads `standards.md` from this repo and adds it to Claude's
context. If GitHub can't be reached, it uses the last downloaded copy and
tells Claude that copy may be out of date.

A second hook, `dev/hooks/lint-changed.sh`, runs lintr on each R file right
after Claude edits it and passes any lints back to Claude, so style problems
are caught as the code is written rather than in CI. It only reports; it
never rewrites the file.

Each package's own `AGENTS.md` adds what's specific to that package: its
structure, slow tests, related packages, and any exceptions to these
standards. When the two disagree, the package's "Overrides" section wins,
then these standards, then the default behavior of any skill Claude is using.
That order lets a package make a deliberate exception without editing the
shared rules, and it keeps general-purpose skills from overriding the
standards.

To set up a package, follow [ADOPTING.md](ADOPTING.md). To use these
standards for your own packages, fork this repo, point each package's hook at
your fork, and adapt the rules to your project.

## Files in this repo

| File | Purpose |
|---|---|
| `standards.md` | The condensed standards loaded into each session |
| `README.md` | The full explanation of each rule (this file) |
| `ADOPTING.md` | Steps to set up a package |
| `hooks/load-standards.sh` | The startup hook, copied into each package's `dev/hooks/` |
| `hooks/lint-changed.sh` | The after-edit lint hook, copied into each package's `dev/hooks/` |
| `templates/settings.json` | Hook registration and permissions for `.claude/settings.json` |
| `templates/Makefile` | The standard `make` targets |
| `templates/.lintr` | lintr settings: 80 columns, indentation set per package (4 spaces by default) |
| `templates/dev/adr/` | Decision record (ADR) template and index |
| `templates/AGENTS.md`, `templates/CLAUDE.md` | Starting points for package-specific notes |
| `templates/github/workflows/sync-stable.yaml` | Keeps `main`/`master` matching the current release, and tags releases |
| `templates/github/workflows/pr-base-devel.yaml` | Fails PRs aimed at the stable branch |
| `templates/github/pull_request_template.md` | PR template: base-branch reminder, checklist, ADR link, scientific-correctness and generated-content sections |

## What you need on your machine

- **Claude Code.**
- **The Superpowers plugin**, which provides the workflow skills referenced
  throughout (brainstorming, writing plans, test-driven development, code
  review). Install it once, from inside Claude Code:
  `/plugin install superpowers@claude-plugins-official`
- **Two Bioconductor skills**, from Bioconductor's official
  [ai-agent-skills](https://github.com/Bioconductor/ai-agent-skills)
  repository:

  ```bash
  git clone https://github.com/Bioconductor/ai-agent-skills.git ~/src/ai-agent-skills
  mkdir -p ~/.claude/skills
  ln -s ~/src/ai-agent-skills/skills/build-check-bioccheck ~/.claude/skills/
  ln -s ~/src/ai-agent-skills/skills/update-r-news ~/.claude/skills/
  ```

  Run `git pull` in that clone now and then to get updates.

The standards still make sense if a skill is missing: each step also
describes what to do, so the process can be followed by hand.

## The development process

Every change, whether a bug fix, a new feature, or a dependency update,
goes through the same six steps. The point is to catch mistakes when they
are cheapest to fix, and to keep a person in control of everything that
leaves your machine.

### 1. Evaluate before writing anything

The first step changes no files. For a bug, Claude traces the problem to its
root cause and reports it before proposing a fix; a fix aimed at a symptom
often just moves the bug. For a feature, it asks questions until the design
is clear. For a dependency change, such as a new version of an upstream
package, it reads that package's NEWS and lists every place in this
package's code that the change affects. You then decide whether and how to
proceed.

### 2. Plan

Claude writes a step-by-step plan that covers everything the change touches:
code, documentation, example data, tests, vignettes and articles, the NEWS
entry, the version bump, checks, and, for release bugs, the port to the
release branch. Plans are saved in `dev/plans/`. They can't go in `docs/`,
because pkgdown generates that folder and overwrites it.

Review the plan before approving it. Correcting a wrong approach in a plan
takes minutes; correcting it after implementation takes hours.

### 3. Execute on a new branch

Work never happens directly on `devel` or a release branch. First, fetch the
latest `devel` from the shared GitHub repo. Starting from current code
avoids merge conflicts later. Then create a branch named `fix/<topic>` or
`feature/<topic>`.

Code is written test-first. For each piece of behavior, write a testthat
test, confirm it fails, then write the code that makes it pass. A test that
has never failed may not be testing anything.

Claude commits locally as it goes, in small commits whose messages say what
changed and why. Local commits are checkpoints: they make it easy to see how
the change was built, and to back out one step without losing the rest.
Nothing leaves your machine yet.

### 4. Review

Claude reviews its own work against the plan and fixes what it finds before
showing it to you.

### 5. Hand off to the developer

Claude stops before pushing anything. It summarizes the change, lists
anything it couldn't verify, and shows the branch's commits and full diff.
It also says whether the change alters results: numbers, model output, or
what a plot shows. You review the whole branch and either approve it or ask
for changes, which become new or amended local commits.

This is the most important rule in the process. Agents can produce a lot of
plausible-looking code quickly. The hand-off guarantees that a person has
read every change before anyone else sees it.

Reading the code isn't the same as checking the science. Tests confirm that
code does what its author expected, not that the expectation was right. When
a change alters results, a person who knows the method checks that the new
output is scientifically correct, and says who checked and how in the PR.

### 6. Push and open a pull request

Only after your approval does the branch get pushed, followed by a PR
against `devel`. Note that GitHub suggests the default branch (`main` or
`master`) as the base, so change it to `devel`; a check fails any PR aimed
at the stable branch. The PR template asks what changed, why, and how it
was tested, and has a checklist, a link to any ADR, and a note of which
parts an AI agent wrote, so reviewers know where to look hardest. Its
"Scientific correctness" section is for a person only; Claude never fills
it in.

GitHub Actions then runs R CMD check and the linter on the PR. If something
fails, fix it on the same branch and push again. The PR updates
automatically, so there's no need to open a new one. A PR is merged only when
CI passes and a person approves it on GitHub. Merging on GitHub keeps a
record of every change and its review. Pushed history is never rewritten,
because others may already have pulled it.

## Remotes

New contributors usually work from a fork:

1. Fork the package on GitHub to your own account.
2. Clone your fork. That clone's `origin` remote is your fork.
3. Add the shared repo as a second remote, named after the GitHub
   organization or owner:
   `git remote add <org> https://github.com/<org>/<package>.git`
4. Maintainers also add Bioconductor:
   `git remote add bioc git@git.bioconductor.org:packages/<package>.git`

People name remotes differently, and many use `upstream` for the shared repo.
So Claude is told to identify each remote by its URL (from `git remote -v`)
rather than trusting its name. That prevents mistakes like syncing from, or
pushing to, the wrong place.

Only maintainers push to Bioconductor. Every push there triggers an official
build, so Claude never does it.

## Branches, releases, and tags

Each package's GitHub repo has three kinds of branches:

| Branch | Contains | Updated by |
|---|---|---|
| `devel` | The development version. All work lands here by PR. | Merged PRs; mirrors Bioconductor devel |
| `RELEASE_X_Y` | A Bioconductor release, e.g. `RELEASE_3_23` | Bioconductor at release time; approved release fixes |
| `main` or `master` | A copy of the current release | A GitHub Action, never by hand |

The stable branch (`main` or `master`) is the GitHub default. That way,
visitors see the released version of the package on its GitHub page, and
`remotes::install_github("<org>/<package>")` installs the same version as
`BiocManager::install("<package>")`. To try the development version from
GitHub, install from `devel` explicitly, e.g.
`remotes::install_github("<org>/<package>@devel")`, which may require
R-devel.

**How the stable branch stays current.** The `sync-stable.yaml` Action
reads the current release from Bioconductor's `config.yaml`, then makes the
stable branch identical to that `RELEASE_X_Y` branch. It runs on every push
to a release branch, once a day, and on demand. It updates the branch with an
ordinary commit rather than a force-push, so the branch keeps its history and
can be protected against force-pushes and deletion. If someone commits to
it by hand, the next run undoes the change. That's why nobody should.

**Pull requests.** Because the stable branch is the default, GitHub suggests
it as the base for new PRs. The `pr-base-devel.yaml` check fails any PR aimed
at it, with instructions to switch the base to `devel`.

**Tags and GitHub Releases.** Bioconductor doesn't use git tags; it goes by
the version in DESCRIPTION. On GitHub, the same Action tags each version
that appears on the current release branch, e.g. `v1.22.0` at release and
`v1.22.1` after a release fix, and publishes a GitHub Release using the top
section of NEWS.md. Devel versions aren't tagged: every change bumps the
version, and those versions never reach users. Connecting the repo to
Zenodo gives each GitHub Release a citable DOI.

**Keeping GitHub and Bioconductor in sync.** Development happens on GitHub,
and a maintainer pushes `devel` to Bioconductor when a version-bumped change
is ready. Bioconductor's core team also commits to your package, most
visibly the version bumps at each release, so merge `bioc/devel` into
`devel` before each push.

**Release day,** twice a year. Using a package at 1.23.z as an example:

1. Bioconductor creates `RELEASE_3_24` on git.bioconductor.org with the
   package at 1.24.0, and bumps devel to 1.25.0.
2. Fetch from `bioc`, merge `bioc/devel` into `devel`, and push `devel` to
   GitHub.
3. Create `RELEASE_3_24` from `bioc/RELEASE_3_24` and push it to GitHub.
4. The Action updates the stable branch and tags `v1.24.0` once Bioconductor
   updates `config.yaml` to the new release, which can lag release day by a
   little. The daily run catches it; you can also start it by hand from the
   Actions tab.

## Commands

All building, testing, and checking goes through the package's Makefile:

| Target | What it does | When |
|---|---|---|
| `make test-one FILTER=<pattern>` | Runs matching test files | While developing |
| `make test` | Runs the full test suite | Before hand-off |
| `make coverage` | Prints test coverage, overall and per file | Before hand-off |
| `make check` | Quick R CMD check | Any time |
| `make check-full` | Full check: rebuilds vignettes, runs `\donttest` examples, requires all Suggests | Before a PR |
| `make bioccheck` | Runs BiocCheck and prints the tarball size | Before a PR |
| `make docs` | Regenerates `man/*.Rd` and `NAMESPACE` from roxygen | After editing roxygen comments |
| `make lint` | Runs lintr | Any time |
| `make site-check` | Checks the pkgdown reference index lists every export, without building the site | After adding an export |

Using the same commands everywhere means everyone runs checks the same way,
and Claude Code's permission settings can allow exactly these commands
without asking every time. If a needed target doesn't exist, Claude asks
rather than improvising, and it uses these targets even when a skill
suggests raw `R CMD` commands.

A package can add its own targets, such as `build` or `clean` for a package
with compiled code, or `app` to launch a Shiny app. List them in the
package's AGENTS.md, along with whether Claude may run each one without
asking. Claude asks before running any extra target that isn't marked safe
there, and anything that deletes files should stay a target for people
only. Add safe extra targets to the allow-list in `.claude/settings.json` so
Claude isn't prompted for them.

The two check levels reflect a common practice of checking in two rounds.
The quick check catches most problems fast. The full check also rebuilds
vignettes and runs examples wrapped in `\donttest{}`, which nothing else
exercises. `make check` and `make check-full` fail on any ERROR or WARNING.
`make bioccheck` fails on BiocCheck ERRORs only, so read its WARNINGs too.
The full check requires every package in Suggests to be installed, rather
than quietly skipping the tests and examples that need a missing one.
Bioconductor's builders install all Suggests, so this matches what they'll
see.

With the Bioconductor skills installed, **build-check-bioccheck** helps
interpret check output, sorting real problems from environment issues and
known false positives. **update-r-news** drafts NEWS entries from the
branch's commits.

## Writing code for novice users

Many people who use Bioconductor packages are new to R, and they learn by
copying code from package examples, vignettes, and tutorials. That code has
to run exactly as pasted, and it has to be easy to follow:

- One operation per line, with descriptively named intermediate objects and
  a short comment explaining each step. A novice can run it a line at a time
  and see what each step produces.
- Rely on default arguments, and set only the ones being demonstrated.
- Load packages with `library()` and call functions plainly, without `pkg::`
  prefixes, the way users will write their own scripts.
- Avoid long pipe chains, nested calls, `lapply`/`do.call`, closures, and
  small helper functions. They're compact but hard for beginners to read or
  change.
- Use bundled or simulated data, and call `set.seed()` before anything
  random so everyone gets the same results.
- Hide unavoidable setup in non-echoed chunks (`echo = FALSE`) or package
  functions, so readers see only what matters.
- Keep vignettes short and fast with small data. They're rebuilt on every
  Bioconductor build, which has time limits. End them with `sessionInfo()`
  for reproducibility. Full workflows on real data belong in pkgdown articles
  (`vignettes/articles/`).
- Use `\donttest{}` rather than `\dontrun{}` for slow examples.
  `\donttest{}` examples still get run by the full check.
- When a change affects behavior, update the vignettes and articles that use
  it. Articles often catch problems the tests miss.

This applies only to code users read. Internal package code can use normal
R idioms.

## Package code conventions

- **Naming:** follow the package's existing conventions. Bioconductor
  packages often use camelCase, but some use snake_case. Consistency within
  a package matters more than any one style.
- **Files:** keep related functions together, with accessors and utilities
  in their own files, so others can find code quickly.
- **Small functions:** break long functions into small internal helpers, and
  never copy logic into a second place, because duplicated code drifts
  apart when one copy is fixed. Where a package prefixes internal helpers
  with `.`, do the same; it separates internal functions from exported ones
  at a glance.
- **Namespaces:** call other packages' functions as `pkg::fun()` or import
  them with `@importFrom`, so the right function is used even if another
  package has one with the same name.
- **Input checks:** check inputs at the start of exported functions, with
  error messages that name the argument and the problem.
- **Logical values:** use `TRUE` and `FALSE`, never `T` or `F`, which are
  ordinary variables that can be overwritten. Test flags with
  `if (isTRUE(flag))`. `if (1)` runs, while `if (isTRUE(1))` doesn't.
- **Accessors:** never read S4 slots with `@` outside class definitions.
  Slot layouts can change between releases, while accessor functions stay
  stable. Reuse Bioconductor classes such as SingleCellExperiment rather
  than inventing new containers, so the package works with the rest of
  Bioconductor.
- **Style:** follow BiocCheck and each repo's lintr settings: lines of at
  most 80 characters, indentation as the package's `.lintr` sets,
  `vapply` over `sapply`,
  `seq_len()` over `1:n`, and `message()` or `warning()` rather than
  `print()` or `cat()`. Run styler on new files only. Restyling existing
  code in a functional change buries the real change in the diff, so lint
  cleanup gets its own PR.
- **lintr settings:** each package has a `.lintr` file, which `make lint`
  and the after-edit lint hook both read. `templates/.lintr` sets 80
  columns, accepts camelCase or snake_case names, and turns off a few
  linters that are noisy in Bioconductor code. A package that uses only one
  naming style can narrow `object_name_linter` to it.
- **Indentation:** Bioconductor recommends 4 spaces, and BiocCheck raises a
  NOTE (not an error) for other indentation. Many existing packages use 2,
  so the indentation setting in `.lintr` matches the package's existing
  code: the template's 4 spaces for new packages, `indent = 2L` for a
  package written with 2. A lintr setting that fights the existing code
  makes every edit report hundreds of lints and pushes new code out of step
  with the lines around it. Converting a package from 2 to 4 spaces is the
  maintainer's call, done in its own PR, and in a 2-space package the
  BiocCheck indentation NOTE is expected.

## Documentation and data

- **Function docs:** every exported function has a roxygen title,
  description, `@param` for each argument (with its default), `@return`, and
  examples that run. Only functions users should call get `@export`.
- **Generated files:** the `.Rd` files in `man/`, `NAMESPACE`, Rcpp and
  Stan generated code, and the pkgdown site in `docs/` are all generated.
  Hand edits get overwritten, so edit the source and regenerate
  (`make docs`). Other files under `man/` are hand-written and fine to
  edit, such as example scripts pulled in with `@example man/examples/...`
  and README images in `man/figures/`.
- **Example data:** each dataset in `data/` has a script in `data-raw/` that
  recreates it with a fixed seed, so the data can be rebuilt or changed
  later. Datasets are documented in `R/data.R` with `@format`, plus
  `@source` if the data came from elsewhere.
- **NEWS:** add a NEWS.md entry with every user-facing change as you make
  it, rather than reconstructing the list at release time.
- **pkgdown:** new exports go in the `_pkgdown.yml` reference index; check
  with `make site-check`. Preview single pages locally, and leave full site
  builds and deployment to CI.
  Knit edited articles locally, since R CMD check doesn't run them.

## Testing

- Every bug fix starts with a test that reproduces the bug and fails. It
  keeps the bug from coming back.
- New functions get tests for correct results and for their error handling,
  checking that bad input gives the expected error message.
- The whole test suite must pass, not just tests near your change. Changes
  in one place often break code elsewhere.
- Keep test data tiny so the suite stays fast, and don't let test coverage
  go down. `make coverage` prints the overall and per-file percentages, so
  compare its output before and after a change.
- Tests that need optional software, such as Python packages used through
  reticulate, must skip cleanly when it isn't installed.

## Shiny apps

For packages with a Shiny app in `inst/shiny`, the app contains no analysis
logic. Its server code only connects inputs to exported, tested package
functions, and any new feature is written as a package function first. R
CMD check doesn't look inside `inst/`, so logic kept in the app would go
untested. Test the app's reactive logic with `shiny::testServer()`, and
check UI changes by running the app and taking a screenshot. Give the
package an `app` target that launches the app (for example
`Rscript -e 'shiny::runApp(system.file("shiny", package = "<pkg>"))'`), and
list it in AGENTS.md, so Claude has a sanctioned way to start it.

## Bioconductor versions and release fixes

**Version numbers** are x.y.z. The middle number is odd in devel and even in
release: a package at 1.23.z in devel is at 1.22.z in release. Bump the
last number by 1 for every change that goes to Bioconductor, because the
build system ignores changes without a version bump. Never change the first
two numbers yourself. Bioconductor does that at each release, in April and
October. The one exception is setting the middle number to 99 in devel,
when the maintainer decides on a major version bump.

**R versions:** Bioconductor devel is paired with a specific R version, and
the pairing changes during the year. The authoritative source is
<https://bioconductor.org/config.yaml>. Claude checks it and says so if your
local R doesn't match, since a mismatch produces misleading check results.

**Deprecation** takes two release cycles, so users have time to adapt. A
function first gives a warning (`.Deprecated()`), becomes an error in the
next release (`.Defunct()`), and is removed after that.

**Fixing bugs in a release:** most fixes go only to devel and reach users at
the next release. The release branch gets fixes only for serious problems:
wrong results, crashes in common workflows, or installation failures.
Claude recommends one or the other during evaluation, and the developer
decides. A release fix is made on its own branch from `RELEASE_X_Y`, by
cherry-picking only the fix, with its own version bump, and it goes through
the same hand-off. `devel` is never merged into a release branch, since
that would ship unfinished features to release users.

## Checks and releases

Any ERROR or WARNING from R CMD check or BiocCheck blocks a change. Each NOTE
is sorted into one of three kinds: a real defect, a problem with the local
environment, or a known false positive. For example, NOTEs about `.git`
folder size or the number of dependencies are usually fine. Real problems
are recorded as GitHub issues rather than fixed silently, and fixed in
focused PRs, one kind of problem per PR, so each fix is easy to review.

Bioconductor's nightly build report is the final word on whether a package
builds. GitHub Actions only gives an early warning.

Each package has its own release checklist in `dev/RELEASE.md`. Every
release also includes the following:

- Syncing with Bioconductor's devel branch.
- Clean `make check-full` and `make bioccheck` runs.
- A source tarball under 10 MB, with no single file over 5 MB. BiocCheck
  enforces both, and `make bioccheck` prints the tarball's size.
- A complete NEWS.md.
- Advancing deprecations to the next stage.
- A `/security-review` of the release changes.

## Scope and safety

- **Keep changes focused.** Problems noticed along the way become issues
  rather than detours.
- **Structural changes** need a written decision record (ADR) in `dev/adr/`,
  proposed through an issue and approved first. These include splitting
  files, adding or removing dependencies, and redesigning classes. They
  affect everyone working on the package. `templates/dev/adr/` has an ADR
  template and a README explaining when one is needed. If the package uses
  renv, update its lockfile when dependencies change.
- **Guardrails:** Claude doesn't edit its own guardrails: the Claude
  settings, the Makefile, the hooks, `.lintr`, or these standards. It proposes
  changes instead, so rules can't be loosened by the agent they constrain.
- **Destructive commands:** Claude never deletes files, runs `git clean`, or
  force-pushes. Anything destructive is done by a person.
- **Secrets:** never commit tokens, passwords, or paths specific to your
  computer.
- **Related packages:** when packages you maintain depend on each other or
  share code, list them in each package's AGENTS.md. A change that could
  affect a related package is then flagged in
  the plan.
- **Maintainer docs**, such as release checklists, roadmaps, ADRs, and plans,
  live in `dev/`, which is excluded from the package build.

## Changing these standards

1. Open a PR in this repo that changes both `standards.md` and this README.
2. To try the change before merging, start a session in any package that
   uses the standards, pointed at your branch:
   `R_BIOC_STANDARDS_URL=https://raw.githubusercontent.com/<owner>/r-bioc-dev-standards/<branch>/standards.md claude`
3. After merging, every package picks up the change at its next session
   start. GitHub's file cache can delay this by a few minutes.
4. Bump the version in `standards.md`'s title for meaningful changes.

Keep `standards.md` short. Explanations belong here, and rules for a single
package belong in that package's `AGENTS.md`.

## Sources

- [Superpowers](https://github.com/obra/superpowers): workflow skills for
  Claude Code
- [Bioconductor ai-agent-skills](https://github.com/Bioconductor/ai-agent-skills):
  official Bioconductor skills
- [Bioconductor developer guide](https://contributions.bioconductor.org/):
  versioning, branches, and package guidelines
- [Adding code to an R package](https://www.camplab.net/adding-code-to-an-r-package/):
  a tutorial for new R package developers, with the
  [DevelExample](https://github.com/campbio/DevelExample) practice package
