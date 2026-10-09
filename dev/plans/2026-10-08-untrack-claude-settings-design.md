# Fix #8: stop tracking `.claude/`; generate settings with `make claude-setup`

## Context

BiocCheck 1.49 (Bioc 3.24 devel) fails `BiocCheckGitClone` when any
Git-tracked path contains `.claude` ("System files found that should not be
Git tracked"). ADOPTING step 2 has every package commit
`.claude/settings.json`. The result is that `make bioccheck` fails and new
submissions get flagged. The issue recommends option 1: untrack `.claude/`
and generate the settings locally. Agreed decisions:

- Option 1 from the issue.
- **Refresh is manual.** Developers run `make claude-setup` once per clone
  and again whenever ADOPTING or a release note says to. The session hook
  doesn't change.

## Design

**Files and their roles**

| Path | Tracked where | Role |
|---|---|---|
| `shared/claude-settings.json` (moved from `templates/settings.json`) | this repo; downloaded at the pinned ref | Base hooks and permissions, the same for every package |
| `templates/dev/claude-settings.json` → package `dev/claude-settings.json` | package repo | Package-only additions: extra `allow`/`ask`/`deny` rules (e.g. `git fetch <org-remote>`, safe extra make targets, `make clean` deny) and optional extra hooks. Skeleton has empty lists. |
| `.claude/settings.json` | **gitignored** | Generated: base + additions |

Moving the base into `shared/` follows the repo's convention ("`shared/` =
downloaded at run time"). As a side benefit, a new standard `make` target no
longer needs an allow-list edit in every package.

**`make claude-setup` (new target in `shared/standards.mk`)**
1. Downloads `$(R_BIOC_STANDARDS_BASE)/shared/claude-settings.json` into the
   same cache directory as `standards.mk` (`curl` to `.tmp`, then `mv`, the
   same pattern as `standards-update`). If the download fails, it uses the
   cached copy. If there's no cache either, it fails with a clear message.
2. Merges the base and the additions with `Rscript` + `jsonlite` (comes in
   with devtools; `jq` isn't guaranteed). Paths go to R through env vars,
   never pasted into the R code (the same rule as `FILTER`). Merge rules:
   - `permissions.allow|ask|deny`: base first, then additions, with
     duplicates removed.
   - `hooks.<Event>`: base entries, then the package's entries.
   - The additions file is optional. If it's missing, the base is used
     unchanged.
   - Additions can't remove base rules. That's deliberate: weakening a
     guardrail means overriding a target in the Makefile or using
     `settings.local.json`, the same as now.
3. Writes `.claude/settings.json` (pretty, `auto_unbox`) via a temp file
   plus `mv`. It overwrites without asking. Personal tweaks belong in
   `.claude/settings.local.json`, which this target never touches.
4. Tells the user to restart `claude` and approve the hooks.
5. **Refuses to run when `CLAUDECODE` is set** (Claude mustn't regenerate
   its own guardrails). The check is in the recipe, the same idea as
   `PEOPLE_ONLY`. It is not in the allow list. Claude can suggest
   `! make claude-setup`.
- Add it to `.PHONY` and give it a `##` help line.

**Base settings changes** (`shared/claude-settings.json`)
- Add `Edit(dev/claude-settings.json)` and `Write(dev/claude-settings.json)`
  to the deny list (the additions are now a guardrail file).
- Keep the `.claude/settings.json` denies.
- Add `Bash(make claude-setup*)` to the deny list too, as a second layer
  behind the `CLAUDECODE` check.

**Bootstrap gap (fresh clone with no generated settings → no hook, no
guardrails, no warning)**
- `templates/AGENTS.md` (tracked, always loaded) gets one line near the
  top. If the session context has no r-bioc-dev-standards text from the
  startup hook, the settings haven't been generated: Claude stops and asks
  the user to run `make claude-setup` and restart.

**Worktrees**: a `claude --worktree` session reads the worktree's own
`.claude/settings.json`, which is no longer checked out. A new
`templates/.worktreeinclude` (copied to the package root) lists
`.claude/settings.json`, so Claude Code copies the generated file into the
worktrees it creates (https://code.claude.com/docs/en/worktrees). Add
`^\.worktreeinclude$` to `.Rbuildignore`.

**Ignore lists**
- `.gitignore`: replace `.claude/settings.local.json` with `.claude/`.
- `.Rbuildignore`: `^\.claude$` stays as it is. Don't add
  `^dev/claude-settings\.json$`, because `^dev$` already covers it.

## Doc changes

- **ADOPTING.md**
  - Step 2 is rewritten. Copy `templates/dev/claude-settings.json` to
    `dev/`, put package-only rules there, and run `make claude-setup`.
    Each developer runs it once per clone. Keep the explanation of the
    permissions.
  - Step 3 is reordered or cross-referenced, because `make claude-setup`
    needs the Makefile. The safe order is: copy the Makefile (step 3)
    before running claude-setup, or move the claude-setup run into
    step 8 (Verify).
  - Step 5 gets the new `.gitignore` lines.
  - "Updating": a package edit is no longer needed for new standard
    targets. Instead, re-run `make claude-setup` after a tag move that
    changes the settings, or after pulling a change to
    `dev/claude-settings.json`.
  - **New section "Migrating a package that tracks `.claude/`":**
    1. Diff the package's `.claude/settings.json` against the base and move
       the package-only entries into `dev/claude-settings.json`.
    2. `git rm --cached -r .claude`, then update `.gitignore`.
    3. Run `make claude-setup`, then diff the generated file against the
       old one; only reordering should differ.
    4. Commit and open a PR.
    5. **Warning:** when other developers pull this commit, Git deletes
       their `.claude/settings.json`. Each of them must run
       `make claude-setup`. Say this in the PR description.
  - Add a line to "Once per machine/clone".
- **README.md**: the file table (row for `templates/settings.json` → two
  rows), the lines at ~26, ~37, and ~314 that describe the tracked
  `.claude/settings.json`, and a short "why it's not tracked" note citing
  BiocCheck ≥ 1.49.
- **standards.md:164**: add `dev/claude-settings.json` to the never-edit
  list. Keep it compact.
- **Comments** in `hooks/load-standards.sh`, `hooks/lint-changed.sh`, and
  `templates/AGENTS.md`: change "register it in `.claude/settings.json`"
  to "registered by `make claude-setup`". These are comment-only edits,
  and packages don't need to re-copy anything.

**Versioning**: this is additive for packages that haven't migrated (a
tracked settings file keeps working until they move), so it stays on `v1`.
After merging, move the `v1` tag, then open the migration PR on
singleCellTK (compbiomed/singleCellTK#807's stopgap can then be reverted).

## Verification

1. Branch `fix/untrack-claude-settings`. Scratch package in the scratchpad
   (`git init`, minimal DESCRIPTION, `templates/Makefile`), with
   `R_BIOC_STANDARDS_BASE=file://$PWD` pointing at this checkout.
   - `make claude-setup` with no `dev/claude-settings.json` → output equals
     the base (`jq -S` diff).
   - With additions (an extra `allow`, a duplicate `deny`, an extra
     `PostToolUse` hook) → union with no duplicates, base order kept, hook
     appended.
   - `CLAUDECODE=1 make claude-setup` → refuses and leaves the file
     untouched.
   - Offline with a cached copy → uses the cache. Offline with no cache →
     fails with a clear message and leaves the existing settings untouched.
   - `make help` lists `claude-setup`.
2. `git ls-files` in the scratch package shows no `.claude` path. Run
   `BiocCheck::BiocCheckGitClone(".")` there if BiocCheck ≥ 1.49 is
   installed (otherwise confirm against `.HIDDEN_PATH_COMPONENTS` logic by
   inspection) → no "System files" error.
3. Start `claude` in the scratch package: hooks prompt for approval, the
   standards load, and a denied action (e.g. editing
   `dev/claude-settings.json`) is blocked. Then delete
   `.claude/settings.json` and start again: Claude follows the AGENTS.md
   line and asks for `make claude-setup`.
4. Run the migration steps on a copy of singleCellTK's settings and diff
   the old file against the regenerated one.
