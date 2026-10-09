# Adopting the standards in a package

These steps set up a Bioconductor package so every Claude Code session in it
loads the shared standards. Make the changes on a branch and merge them by
pull request, like any other change. The files to copy are in `hooks/` and
`templates/` in this repo.

## Once per machine

Install Claude Code, the Superpowers plugin, and the two Bioconductor skills,
as described under "What you need on your machine" in the README.

## Once per clone

In each new clone of a package that has adopted the standards, run
`make claude-setup` before starting `claude`, then approve the hooks when
asked. Run it again after pulling a change to `dev/claude-settings.json`.

## Once per package

1. **Add the hooks.** Copy `hooks/load-standards.sh` and
   `hooks/lint-changed.sh` to `dev/hooks/` in the package. Both are small
   and rarely change: the startup hook downloads the shared files, and
   `lint-changed.sh` is a stub that runs the downloaded lint hook. If the
   package already has a `lint-changed.sh`, replace it. If you use a fork
   of these standards, set `R_BIOC_STANDARDS_BASE` in `load-standards.sh`
   and the Makefile to your fork's raw-file URL.

2. **Register the hooks and permissions.** Claude Code reads them from
   `.claude/settings.json`, but packages don't commit that file:
   BiocCheck (1.49 and later) fails a package whose Git repository tracks
   anything under `.claude/`. Instead, `make claude-setup` (step 3 adds
   the Makefile) writes it by combining the shared settings, downloaded
   at the same tag as the other shared files, with the package's own
   rules in `dev/claude-settings.json`. Copy
   `templates/dev/claude-settings.json` to `dev/claude-settings.json` and
   put only package-specific rules in it; its lists are added to the
   shared ones, and it can't remove a shared rule. Each developer runs
   `make claude-setup` once in each clone, and again after pulling a
   change to `dev/claude-settings.json` or when the maintainer announces
   a settings change. Claude can't run it. The hook commands use paths
   relative to the package root (`bash dev/hooks/...`), so start `claude`
   from the package root.

   The permissions let Claude run the standard `make` targets and a short
   list of safe git commands without asking; any other git command asks
   first. They block pushes to Bioconductor, force-pushes, recursive
   deletes, and edits to generated files and to the guardrails themselves.
   `git push`, `gh pr create`, and branch deletion are ask rules, so Claude
   must ask you each time, even in auto mode. That prompt is your hand-off
   checkpoint. Add a `Bash(git fetch <remote>)` allow rule to
   `dev/claude-settings.json` for each remote the package uses (for
   example the org-named shared remote); the shared settings cover
   `origin`, `upstream`, and `bioc`.

3. **Provide the standard `make` targets and lint settings.** The standards
   expect `test`, `test-one`, `check`, `check-full`, `bioccheck`, `docs`,
   `lint`, `coverage`, and `site-check`. Their recipes live in
   `shared/standards.mk` in this repo, so don't copy them into the package.
   Copy `templates/Makefile`, which includes the shared file. If the package
   already has a Makefile, start from the template and move over only the
   package's extra targets, below the include; delete its own versions of
   the standard targets. Where a standard target needs to behave
   differently, use a setting above the include (see the comments in
   `shared/standards.mk`), and ask for a new setting here if none fits.
   Recipe lines must start with a tab. List the extra targets in AGENTS.md
   (step 4). For any that are for people only, set `PEOPLE_ONLY` in the
   Makefile's settings (e.g. `PEOPLE_ONLY := clean site-deploy`), which
   makes them refuse to run from Claude Code, and also add them to the
   deny list in `dev/claude-settings.json`, e.g. `Bash(make clean)`. Then
   run `make claude-setup` (step 2).
   `site-check` fails unless `_pkgdown.yml` sets `url:` and the site URL
   appears in DESCRIPTION's `URL` field. In a package with no pkgdown site
   it doesn't apply; say so in AGENTS.md.

   Copy `templates/.lintr` to the package root, or keep the package's own.
   Either way, set `indentation_linter` to match the existing code, not the
   other way round. The template uses 4 spaces, Bioconductor's
   recommendation, but many packages use 2. If `make lint` reports hundreds
   of indentation lints, set `indent = 2L`; converting the code is a
   separate decision and its own PR. Narrow `object_name_linter` to the
   package's naming style if it uses only one.

4. **Add package notes.** Copy `templates/AGENTS.md` to the package root and
   fill it in, then copy `templates/CLAUDE.md` (a single line, `@AGENTS.md`)
   next to it so Claude Code loads the notes. If the package already has an
   AGENTS.md that repeats general rules now covered by the standards, remove
   those parts and keep only what's specific to the package.

   If the package has no `dev/adr/`, copy `templates/dev/adr/` there. It
   holds the ADR template and a README explaining when one is needed.

5. **Keep the new files out of the package build.** Add these lines to
   `.Rbuildignore`, skipping any that are already there:

   ```
   ^dev$
   ^\.github$
   ^\.claude$
   ^AGENTS\.md$
   ^CLAUDE\.md$
   ^Makefile$
   ^\.lintr$
   ^\.worktrees$
   ^\.worktreeinclude$
   ```

   Add these to `.gitignore`:

   ```
   .worktrees/
   .claude
   ```

   `.claude/` holds the settings `make claude-setup` writes and each
   developer's own `settings.local.json`; neither is committed. Write
   `.claude` without a trailing slash: when the `gert` package isn't
   installed, BiocCheck reads `.gitignore` itself and misses `.claude/`.

   Copy `templates/.worktreeinclude` to the package root, so worktrees
   that Claude Code creates get a copy of the generated settings.

   Commit `dev/plans/`, since plans are part of the record of a change.

6. **Check the remotes.** Run `git remote -v` in your clone and confirm
   each remote points where you expect, especially the Bioconductor one
   (`bioc` by convention). Remotes aren't stored in the repo, so each
   developer checks their own clone.

7. **Set up the stable branch.** This makes `main` (or `master`) an
   automatic copy of the current Bioconductor release. See "Branches,
   releases, and tags" in the README for how it works.

   a. Copy `templates/github/workflows/sync-stable.yaml` and
      `pr-base-devel.yaml` to `.github/workflows/`, and
      `templates/github/pull_request_template.md` to `.github/`. In
      `sync-stable.yaml`, set `stable-branch` to `main` or `master` to match
      the repo. Both workflows are short: they call the shared workflows in
      this repo. Merge these into `devel` by PR.

   b. Make sure the current release branch is on GitHub. Fetch it from
      Bioconductor and push it to the shared GitHub repo, not a fork. Below,
      `<shared>` is the remote whose URL is the shared repo: `origin` if you
      cloned it directly, or the org-named remote if you work from a fork.
      `git fetch bioc` then
      `git push <shared> bioc/RELEASE_X_Y:refs/heads/RELEASE_X_Y`,
      using the release named in <https://bioconductor.org/config.yaml>.

   c. Add the same three files to that release branch, so pushes to it
      trigger the sync: check out `RELEASE_X_Y`, cherry-pick the commit from
      step a, and push to `<shared>`. That push runs the sync for the first
      time. It brings the stable branch up to date, keeping its old history,
      and tags the current release version if it isn't tagged yet. You don't
      need to push this commit to Bioconductor or bump the version, since
      `.github/` is excluded from the package build. Future release branches
      inherit the files from `devel` automatically.

   d. In the repo's GitHub settings, under **General**, make the stable
      branch the default branch.

   e. Protect the stable branch. Under **Rules → Rulesets**, add a branch
      ruleset targeting it with **Restrict deletions** and **Block force
      pushes** turned on. Leave "Restrict updates" and "Require a pull
      request" off, because either one would block the sync Action.

   f. Check the **Actions** tab for a green "Sync stable branch" run, and
      confirm the stable branch's DESCRIPTION version matches the release.
      If the run fails with a permissions error, your organization may
      restrict Actions; check **Settings → Actions → General → Workflow
      permissions**.

8. **Verify.** Start a new `claude` session in the package and approve the
   changed hooks when asked. If Claude says the standards weren't loaded,
   `.claude/settings.json` is missing; run `make claude-setup`. Then ask:
   "Which remote do the standards say never to push to, and when may a
   pull request be opened?" Claude should
   answer from the standards without reading any files: never push to
   Bioconductor, and open a PR only after you've reviewed the branch. If it
   can't, run the hook by hand to see its output:
   `bash dev/hooks/load-standards.sh | head`

## Updating

When the maintainer moves the `v1` tag, changes to `standards.md`, the lint
hook, the shared make targets, and the shared workflows reach every package
at its next session start or workflow run. Nothing in the package needs to
change.

A package still needs its own edit when:

- the shared settings (`shared/claude-settings.json`) change: each
  developer re-runs `make claude-setup`, but nothing in the package is
  edited;
- a package-specific file changes: `dev/claude-settings.json`,
  `AGENTS.md`, `.lintr`, the PR template, `.Rbuildignore`, or
  `.gitignore`;
- a breaking change is published as `v2` (the package moves when ready).

## Migrating a package adopted before shared delivery

Packages set up before the shared files moved into this repo have full
copies that no longer update. Replace them once:

1. Replace `dev/hooks/load-standards.sh` and `dev/hooks/lint-changed.sh`
   with the current `hooks/` versions.
2. Replace the Makefile with `templates/Makefile`, then add back only the
   package's extra targets below the include, and any settings above it.
3. Replace `.github/workflows/sync-stable.yaml` and `pr-base-devel.yaml`
   with the templates, keeping the repo's `stable-branch` value.
4. Run `make help` and confirm it lists the standard targets.
5. Then follow "Migrating a package that tracks `.claude/`" below.

## Migrating a package that tracks `.claude/`

Packages adopted before `make claude-setup` existed commit
`.claude/settings.json`, which BiocCheck 1.49 and later reports as an
error. Move them over once, on a branch:

1. Copy `templates/dev/claude-settings.json` to `dev/claude-settings.json`
   and `templates/.worktreeinclude` to the package root, and add
   `^\.worktreeinclude$` to `.Rbuildignore`. Compare the package's
   `.claude/settings.json` with `shared/claude-settings.json` in this
   repo, and copy into the new file only the entries the shared one
   lacks, such as the package's `git fetch` remotes, extra make targets,
   or people-only denies.
2. Replace `.claude/settings.local.json` in `.gitignore` with `.claude`
   (no trailing slash; see step 5 above), then stop tracking the folder without deleting your copy:
   `git rm -r --cached .claude`
3. Run `make claude-setup` and compare the result with the old file:
   `git show HEAD:.claude/settings.json | diff - .claude/settings.json`.
   Only the order of entries and the newer shared rules should differ.
4. Commit and open a PR. Say in its description that **pulling it deletes
   each developer's `.claude/settings.json`**, so everyone must run
   `make claude-setup` after pulling.
