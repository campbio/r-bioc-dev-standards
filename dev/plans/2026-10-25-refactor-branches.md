# Spec: refactor branches (standards v1.2)

## Why

Some refactors are too large for one PR but would leave `devel` broken or
half-converted if merged piece by piece. Bioconductor builds `devel`
nightly, so `devel` must stay releasable. A `refactor/<topic>` branch acts
as a temporary integration base: the pieces land there by PR, and the
finished refactor reaches `devel` in one final PR.

## The rules

1. **ADR first.** The refactor is proposed in an issue and its ADR is
   merged into `devel` by a normal PR before the branch exists, so the
   decision is recorded even if the refactor is abandoned. The ADR names
   the `refactor/<topic>` branch.
2. **A maintainer cuts the branch.** A maintainer creates
   `refactor/<topic>` from current `devel` and pushes it to the shared
   repo. Claude never creates, pushes, or commits directly to a refactor
   branch.
3. **Pieces are normal branches.** Each piece is a `fix/<topic>` or
   `feature/<topic>` branch made from `refactor/<topic>`, with its PR based
   on `refactor/<topic>`. Sub-branches can't be named
   `refactor/<topic>/<part>`: git can't hold both a ref and a directory of
   the same name. All six process steps apply unchanged, with the full PR
   checklist, including the z version bump. The hand-off shows
   `git log <remote>/refactor/<topic>..HEAD` and
   `git diff <remote>/refactor/<topic>...HEAD`, since Claude has no local
   copy of the refactor branch.
4. **No syncing.** `devel` is never merged into the refactor branch while
   it is open. Keep other `devel` changes to a minimum meanwhile.
5. **Final PR into `devel`.** When the refactor is complete, tested, and
   documented: a fresh subagent checks the full diff against the ADR,
   `/code-review` runs on the whole branch, and `check-full` and
   `bioccheck` pass. Then a PR from `refactor/<topic>` to `devel`. Only a
   maintainer resolves its conflicts (GitHub's editor or a local merge of
   `devel` into the refactor branch, the one exception to rule 4); for
   DESCRIPTION, the version becomes one past the higher of the two. It is
   merged with a merge commit, never squash or rebase, so the reviewed
   pieces stay in history for `git bisect`, and only after a person
   approves on GitHub.
6. **Clean up.** A maintainer deletes the refactor branch after the merge.
   If the refactor is abandoned, the maintainer deletes the branch and a
   new ADR supersedes the old one.

## What changes

- `standards.md` (v1.2), kept condensed:
  - Workflow step 3: branch from `refactor/<topic>` when the work belongs
    to an open refactor. Steps 5 and 6: that branch replaces `devel` in
    the hand-off commands and as the PR base.
  - Branches and tags: a `refactor/<topic>` entry with rules 2–5.
- `README.md`: a `refactor/<topic>` row in the branches table, a "Large
  refactors" subsection with the lifecycle and its reasons, and matching
  edits to process steps 3, 5, and 6.
- `templates/github/pull_request_template.md`: the base-branch comment
  allows `refactor/<topic>` for a piece of an approved refactor.
- `ADOPTING.md`: an optional note for packages that use refactor branches:
  add `refactor/**` to the CI workflows' `pull_request` branches so pieces
  get CI, and optionally a ruleset on `refactor/*` that requires a PR and
  blocks force-pushes, with maintainers as bypass actors for the final
  conflict resolution.
- `templates/dev/adr/README.md`: a large refactor's ADR names its
  `refactor/<topic>` branch.

## Not changed

- Settings: `git switch -c feature/x origin/refactor/x` already matches
  the allow rule and not the `git switch -c * -*` deny rule; switching to
  an existing branch already asks; push and branch deletion stay ask
  rules.
- Workflow logic: `pr-base-devel` only fails PRs into `main`/`master`, so
  PRs into `refactor/*` and the final PR into `devel` pass. Only its error
  message changes, to mention a refactor branch as a valid base.
- Moving the `v1` tag after merge is a maintainer step.

## How it is checked

No tests cover prose. Check that `standards.md` and `README.md` agree,
that the settings rules permit branching from a refactor branch as
claimed, and grep for remaining "base `devel`" statements that lack the
refactor exception.
