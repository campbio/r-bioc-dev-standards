# Adopting the standards in a package

These steps set up a Bioconductor package so every Claude Code session in it
loads the shared standards. Make the changes on a branch and merge them by
pull request, like any other change. The files to copy are in `hooks/` and
`templates/` in this repo.

## Once per machine

Install Claude Code, the Superpowers plugin, and the two Bioconductor skills,
as described under "What you need on your machine" in the README.

## Once per package

1. **Add the hooks.** Copy `hooks/load-standards.sh` and
   `hooks/lint-changed.sh` to `dev/hooks/` in the package. If you use a fork
   of these standards, change the default URL near the top of
   `load-standards.sh` to point at your fork. If the package already has a
   `lint-changed.sh`, replace it: older versions printed lints to plain
   output, which Claude Code never shows to Claude.

2. **Register the hook and permissions.** Copy `templates/settings.json` to
   `.claude/settings.json`. If the package already has one, merge the
   template's entries into it: add the `SessionStart` and `PostToolUse`
   blocks inside the existing `"hooks"` object (replacing any older
   `lint-changed.sh` entry), and add the `allow` and `deny` rules to the
   existing lists. The hook commands use paths relative to the package root
   (`bash dev/hooks/...`), so start `claude` from the package root.

   The permissions let Claude run the standard `make` targets and read-only
   or local git commands without asking. They block pushes to Bioconductor,
   force-pushes, branch deletion, recursive deletes, and edits to generated
   files and to the guardrails themselves. `git push` and `gh pr create` are
   deliberately left out of the allow list, so Claude must ask you each
   time. That prompt is your hand-off checkpoint.

3. **Provide the standard `make` targets and lint settings.** The standards
   expect `test`, `test-one`, `check`, `check-full`, `bioccheck`, `docs`,
   `lint`, `coverage`, and `site-check`. Copy `templates/Makefile` if the
   package has no Makefile. If it has one, add whichever targets are
   missing, keeping the same names, and compare the existing ones against
   the template. Recipe lines must start with a tab. Keep any extra targets
   the package already has, and list them in AGENTS.md (step 4).
   `site-check` also fails unless `_pkgdown.yml` sets `url:` and the site
   URL appears in DESCRIPTION's `URL` field. A package with no pkgdown site
   can leave the target out.

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
   ```

   Add these to `.gitignore`:

   ```
   .worktrees/
   .claude/settings.local.json
   ```

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
      `sync-stable.yaml`, set `STABLE_BRANCH` to `main` or `master` to match
      the repo. Merge these into `devel` by PR.

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
   changed hooks when asked. Then ask: "Which remote do the standards say
   never to push to, and when may a pull request be opened?" Claude should
   answer from the standards without reading any files: never push to
   Bioconductor, and open a PR only after you've reviewed the branch. If it
   can't, run the hook by hand to see its output:
   `bash dev/hooks/load-standards.sh | head`

## Updating

Changes to `standards.md` reach every package at its next session start;
nothing in the package needs to change. Update a package's copies of the
hooks in `dev/hooks/` only if the scripts themselves change here.
