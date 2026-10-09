# Untrack `.claude/` (issue #8) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Packages stop committing `.claude/settings.json` (BiocCheck ≥ 1.49
fails on it). A new shared `make claude-setup` target generates it from the
shared base settings plus a tracked `dev/claude-settings.json`.

**Architecture:** The base settings move from `templates/settings.json` to
`shared/claude-settings.json`. Like `shared/standards.mk`, they're
downloaded at the pinned ref into `~/.cache/r-bioc-dev-standards/<ref>/`.
`make claude-setup` (in `shared/standards.mk`) downloads them, falling back
to the cache. It then merges in the package's additions with
`Rscript`/`jsonlite` and writes `.claude/settings.json`, which is now
gitignored. The docs change to match.

**Tech Stack:** GNU Make 3.81+ (macOS ships 3.81: no make-4 features),
POSIX sh in recipes, curl, Rscript + jsonlite (≥ 1.0), jq (tests only),
bash (tests).

**Spec:** `dev/plans/2026-10-08-untrack-claude-settings-design.md`

## Global Constraints

- Refresh is manual: the session hook (`hooks/load-standards.sh`) gains no
  new behaviour. Only its comments change.
- `make claude-setup` must refuse to run when `CLAUDECODE` is non-empty.
- Values reach R through environment variables, never pasted into R code.
- Downloads go to `<file>.tmp`, then `mv`. A failed download never
  replaces a good cached copy, and a failed merge never replaces an
  existing `.claude/settings.json`.
- Merge: `permissions.allow|ask|deny` = base then additions, de-duplicated;
  `hooks.<Event>` = base entries then additions. Additions can't remove
  base rules. Unknown keys in the additions file are an error, not
  silently dropped.
- Never touch `.claude/settings.local.json`.
- Stays on `v1`: packages that still track `.claude/settings.json` keep
  working unchanged.
- `standards.md` must stay compact (~8,250 chars). Add words, not
  paragraphs.

## Review Focus

1. **Running inside Claude Code.** `CLAUDECODE` is set in Claude's shell,
   so the target must refuse there, and the test script must unset it or
   every test fails for the wrong reason. Covered by Task 2 tests 1 and 5.
2. **Bad additions file** (malformed JSON, or a key such as `env` or
   `permissions.defaultMode` the merge doesn't handle). Expect a non-zero
   exit with the file named, and the existing `.claude/settings.json` left
   byte-for-byte unchanged. Task 2 tests 3 and 4.
3. **Offline.** With a cached base: succeed with a NOTE. With no cache:
   fail with a message that names the URL, leaving the settings untouched.
   Task 2 tests 6 and 7.
4. **Developer's own `.claude/settings.local.json`** must survive
   `make claude-setup`. Task 2 test 8.
5. **Fresh clone or new worktree with no generated settings.** No hook
   runs, so there are no standards and no guardrails. Worktrees made by
   `claude --worktree` or worktree subagents get the file through
   `.worktreeinclude`. A plain clone, or a `git worktree add` made outside
   Claude, relies on the AGENTS.md bootstrap line making Claude stop and
   ask. Task 4 (manual E2E, step 3).

---

## File map

| File | Change |
|---|---|
| `templates/settings.json` → `shared/claude-settings.json` | `git mv`, then add 4 deny rules |
| `templates/dev/claude-settings.json` | Create: the empty skeleton for package additions |
| `templates/.worktreeinclude` | Create: makes Claude Code copy the generated settings into worktrees it creates |
| `shared/standards.mk` | Add the `claude-setup` target, `CLAUDE_BASE_JSON`, `.PHONY`, header comment |
| `dev/tests/test-claude-setup.sh` | Create: shell test for the target |
| `templates/AGENTS.md` | Bootstrap line; update the `.claude/settings.json` mentions |
| `ADOPTING.md`, `README.md`, `standards.md` | Docs |
| `hooks/load-standards.sh`, `hooks/lint-changed.sh` | Comment wording only |

---

### Task 1: Move the base settings to `shared/` and add the additions skeleton

**Files:**
- Move: `templates/settings.json` → `shared/claude-settings.json`
- Modify: `shared/claude-settings.json` (deny list, after line 82
  `"Write(.claude/settings.json)",`)
- Create: `templates/dev/claude-settings.json`
- Create: `templates/.worktreeinclude`

**Interfaces:**
- Produces: `shared/claude-settings.json` (downloaded by Task 2's target
  from `$(R_BIOC_STANDARDS_BASE)/shared/claude-settings.json`);
  `templates/dev/claude-settings.json` (skeleton; Task 2 test 2 merges it
  and expects output identical to the base).

- [ ] **Step 1: Move the file with history**

```bash
git mv templates/settings.json shared/claude-settings.json
```

- [ ] **Step 2: Add the deny rules.** Directly after
  `"Write(.claude/settings.json)",` insert:

```json
      "Edit(dev/claude-settings.json)",
      "Write(dev/claude-settings.json)",
      "Bash(make claude-setup)",
      "Bash(make claude-setup *)",
```

(Use two rules because `Bash(make claude-setup*)` would also match a
future `make claude-setup-foo`. The existing `Bash(make * -*)` already
covers flags.)

- [ ] **Step 3: Create `templates/dev/claude-settings.json`**

```json
{
  "permissions": {
    "allow": [],
    "ask": [],
    "deny": []
  },
  "hooks": {}
}
```

- [ ] **Step 3b: Create `templates/.worktreeinclude`.** Claude Code
  copies gitignored files that match this file (gitignore syntax) into the
  worktrees it creates (`claude --worktree`, worktree subagents; see
  https://code.claude.com/docs/en/worktrees). A worktree session reads its
  own `.claude/settings.json`, so without this file it would start with no
  hooks or guardrails.

```
# Gitignored files Claude Code copies into new worktrees. The settings are
# generated by `make claude-setup` and not committed.
.claude/settings.json
```

- [ ] **Step 4: Verify**

```bash
jq -e '.permissions.deny | index("Edit(dev/claude-settings.json)") and index("Bash(make claude-setup)")' shared/claude-settings.json
jq -e . templates/dev/claude-settings.json
git status --short
```

Expected: `true` (or a truthy number), the skeleton is echoed, and the
status shows `R  templates/settings.json -> shared/claude-settings.json`,
plus the new file.

- [ ] **Step 5: Commit**

```bash
git add shared/claude-settings.json templates/dev/claude-settings.json templates/.worktreeinclude
git commit -m "Move base Claude settings to shared/ and add package additions skeleton

Packages will generate .claude/settings.json instead of tracking it (#8).
Also deny Claude editing dev/claude-settings.json or running make
claude-setup."
```

---

### Task 2: `make claude-setup`

**Files:**
- Create: `dev/tests/test-claude-setup.sh`
- Modify: `shared/standards.mk` (header comment lines 1-6; `.PHONY` at
  lines 25-26; new target after `standards-update`, end of file)

**Interfaces:**
- Consumes: `shared/claude-settings.json` and
  `templates/dev/claude-settings.json` (Task 1); `STANDARDS_MK` and
  `R_BIOC_STANDARDS_BASE`, which are defined by the package Makefile
  (`templates/Makefile:53-55`).
- Produces: the `make claude-setup` target, which writes
  `.claude/settings.json` and reads the optional `dev/claude-settings.json`.
  The cached base is `$(dir $(STANDARDS_MK))claude-settings.json`.

- [ ] **Step 1: Write the test script** `dev/tests/test-claude-setup.sh`

```bash
#!/usr/bin/env bash
# Tests `make claude-setup` (shared/standards.mk) in a throwaway package.
# Uses this checkout as the download source, so it tests uncommitted
# changes. Needs make, curl, jq, and Rscript with jsonlite.
#
#   bash dev/tests/test-claude-setup.sh

set -u

repo="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
fails=0
ok()   { echo "ok   $1"; }
fail() { echo "FAIL $1"; fails=$((fails + 1)); }
check() { if "$@" > /dev/null 2>&1; then ok "$name"; else fail "$name"; fi; }
same_json() { diff <(jq -S . "$1") <(jq -S . "$2"); }

# Claude Code sets CLAUDECODE, which makes the target refuse.
unset CLAUDECODE
export XDG_CACHE_HOME="$work/cache"
export R_BIOC_STANDARDS_BASE="file://$repo"
base="$repo/shared/claude-settings.json"
cached="$XDG_CACHE_HOME/r-bioc-dev-standards/v1/claude-settings.json"
out=.claude/settings.json

mkdir -p "$work/pkg/dev" && cd "$work/pkg" || exit 1
cp "$repo/templates/Makefile" Makefile

# 1. No additions file: output is the base.
name="no additions: output equals base"
make -s claude-setup > /dev/null 2>&1
check same_json "$out" "$base"

# 2. The empty skeleton changes nothing.
name="skeleton additions: output equals base"
cp "$repo/templates/dev/claude-settings.json" dev/claude-settings.json
make -s claude-setup > /dev/null 2>&1
check same_json "$out" "$base"

# 3. Additions merge: lists appended without duplicates, hooks appended.
name="additions merged"
cat > dev/claude-settings.json << 'EOF'
{
  "permissions": {
    "allow": ["Bash(make build)", "Bash(git fetch campbio)"],
    "deny": ["Bash(make clean)", "Bash(rm -rf:*)"]
  },
  "hooks": {
    "PostToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "echo hi"}]}
    ]
  }
}
EOF
make -s claude-setup > /dev/null 2>&1
check jq -e --slurpfile b "$base" '
  ($b[0]) as $b
  | .permissions.allow == ($b.permissions.allow + ["Bash(make build)", "Bash(git fetch campbio)"])
  and .permissions.ask == $b.permissions.ask
  and .permissions.deny == ($b.permissions.deny + ["Bash(make clean)"])
  and .hooks.SessionStart == $b.hooks.SessionStart
  and .hooks.PostToolUse == ($b.hooks.PostToolUse + [{"matcher": "Bash", "hooks": [{"type": "command", "command": "echo hi"}]}])
  and ."$schema" == $b."$schema"' "$out"
cp "$out" "$work/good.json"

# 4. Unsupported keys fail and leave the settings alone.
for bad in '{"env": {"X": "1"}}' '{"permissions": {"defaultMode": "auto"}}' '{ not json'; do
  name="rejects additions $bad"
  printf '%s\n' "$bad" > dev/claude-settings.json
  if ! make -s claude-setup > /dev/null 2>&1 && cmp -s "$out" "$work/good.json"; then
    ok "$name"; else fail "$name"; fi
done
rm dev/claude-settings.json
make -s claude-setup > /dev/null 2>&1

# 5. Refuses inside Claude Code and changes nothing.
name="refuses when CLAUDECODE is set"
cp "$out" "$work/before.json"
echo '{}' > "$out"
if ! CLAUDECODE=1 make -s claude-setup > /dev/null 2>&1 \
   && [ "$(cat "$out")" = "{}" ]; then ok "$name"; else fail "$name"; fi
cp "$work/before.json" "$out"

# 6. Download fails, cache present: succeeds with a note.
name="offline with cache: uses cache"
msg="$(R_BIOC_STANDARDS_BASE=file:///nonexistent make -s claude-setup 2>&1)"
if [ $? -eq 0 ] && printf '%s' "$msg" | grep -q "cached copy"; then
  ok "$name"; else fail "$name"; fi

# 7. Download fails, no cache: fails, names the URL, settings untouched.
name="offline without cache: fails clearly"
mv "$cached" "$work/cached.json"
msg="$(R_BIOC_STANDARDS_BASE=file:///nonexistent make -s claude-setup 2>&1)"
status=$?
if [ $status -ne 0 ] && printf '%s' "$msg" | grep -q "file:///nonexistent/shared/claude-settings.json" \
   && cmp -s "$out" "$work/before.json"; then ok "$name"; else fail "$name"; fi
mv "$work/cached.json" "$cached"

# 8. settings.local.json is never touched.
name="leaves settings.local.json alone"
echo '{"permissions": {"allow": ["Bash(ls)"]}}' > .claude/settings.local.json
cp .claude/settings.local.json "$work/local.json"
make -s claude-setup > /dev/null 2>&1
check cmp -s .claude/settings.local.json "$work/local.json"

# 9. Listed by make help.
name="make help lists claude-setup"
check sh -c 'make -s help | grep -q "^  claude-setup "'

echo
echo "Test files are in $work"
if [ "$fails" -eq 0 ]; then echo "All passed."; else echo "$fails failed."; exit 1; fi
```

(The script leaves `$work` behind and prints its path, so a failure can be
inspected. The standards say not to delete files, and it lives under
`$TMPDIR` anyway.)

- [ ] **Step 2: Run it and confirm that it fails**

Run: `bash dev/tests/test-claude-setup.sh`
Expected: tests 1-9 print `FAIL` (make reports "No rule to make target
`claude-setup`"), except possibly test 7's mv noise. The last line is
`N failed.`, and the exit status is 1.

- [ ] **Step 3: Implement the target in `shared/standards.mk`**

3a. Header comment. Replace lines 3-6 with:

```make
# Packages don't copy this file. Each package's Makefile includes a cached
# copy, which dev/hooks/load-standards.sh refreshes at every Claude session
# start (or run `make standards-update`). Package-specific settings go above
# the include in the package's Makefile; extra targets go below it.
# `make claude-setup` writes .claude/settings.json, which packages don't
# commit (BiocCheck rejects a tracked .claude/).
```

3b. `.PHONY` (lines 25-26):

```make
.PHONY: help docs test test-one check check-full bioccheck lint coverage \
  site-check article standards-update claude-setup
```

3c. Append at the end of the file:

```make

# Claude Code's settings for this clone: the shared base (downloaded next to
# this file, at the same ref) plus the package's own rules in
# dev/claude-settings.json. Lists and hooks are appended; the package file
# can't remove a base rule. Each developer runs this once per clone, and
# again after the settings change. Claude may not run it, since it writes
# Claude's own permissions.
CLAUDE_BASE_JSON := $(dir $(STANDARDS_MK))claude-settings.json

claude-setup:  ## Write .claude/settings.json (people only; once per clone)
	@if [ -n "$$CLAUDECODE" ]; then \
	  echo "make claude-setup is for people only: it writes Claude's own permissions."; exit 1; \
	fi
	@mkdir -p "$(dir $(CLAUDE_BASE_JSON))"
	@if curl -fsSL --max-time 30 "$(R_BIOC_STANDARDS_BASE)/shared/claude-settings.json" -o "$(CLAUDE_BASE_JSON).tmp" \
	    && [ -s "$(CLAUDE_BASE_JSON).tmp" ]; then \
	  mv -f "$(CLAUDE_BASE_JSON).tmp" "$(CLAUDE_BASE_JSON)"; \
	else \
	  rm -f "$(CLAUDE_BASE_JSON).tmp"; \
	  if [ -s "$(CLAUDE_BASE_JSON)" ]; then \
	    echo "NOTE: Couldn't download the shared settings; using the cached copy, which may be out of date."; \
	  else \
	    echo "Couldn't download $(R_BIOC_STANDARDS_BASE)/shared/claude-settings.json, and there is no cached copy."; exit 1; \
	  fi; \
	fi
	@mkdir -p .claude
	@BASE="$(CLAUDE_BASE_JSON)" ADD=dev/claude-settings.json OUT=.claude/settings.json \
	  Rscript -e 'rd <- function(p) jsonlite::read_json(p, simplifyVector = FALSE); s <- rd(Sys.getenv("BASE")); add <- Sys.getenv("ADD"); a <- if (file.exists(add)) rd(add) else list(); bad <- c(setdiff(names(a), c("$$schema", "permissions", "hooks")), setdiff(names(a[["permissions"]]), c("allow", "ask", "deny"))); if (length(bad)) stop(add, " has keys claude-setup does not merge: ", paste(bad, collapse = ", "), call. = FALSE); for (k in c("allow", "ask", "deny")) s[["permissions"]][[k]] <- unique(c(s[["permissions"]][[k]], a[["permissions"]][[k]])); for (e in names(a[["hooks"]])) s[["hooks"]][[e]] <- c(s[["hooks"]][[e]], a[["hooks"]][[e]]); out <- Sys.getenv("OUT"); jsonlite::write_json(s, paste0(out, ".tmp"), auto_unbox = TRUE, pretty = TRUE); stopifnot(file.rename(paste0(out, ".tmp"), out))'
	@echo "Wrote .claude/settings.json. Restart claude in this folder and approve the hooks when asked."
```

Notes for the implementer: recipe lines start with a **tab**. `$$schema`
reaches R as the literal `$schema`, because the shell's single quotes stop
expansion. A parse error in `jsonlite::read_json` makes Rscript exit
non-zero before anything is written. The `.tmp` + `file.rename` step keeps
the old file if the write fails.

- [ ] **Step 4: Run the tests and confirm that they pass**

Run: `bash dev/tests/test-claude-setup.sh`
Expected: nine `ok` lines for tests 1-3 and 5-9, three for test 4, then
`All passed.` and exit 0. If test 9 fails, check that the `##` help line
matches `help`'s regex `^[a-zA-Z_-]+:.*## `.

- [ ] **Step 5: Commit**

```bash
git add shared/standards.mk dev/tests/test-claude-setup.sh
git commit -m "Add make claude-setup to generate .claude/settings.json

Merges the shared base settings (downloaded at the pinned ref, cached)
with the package's dev/claude-settings.json. Refuses to run inside
Claude Code. Part of #8."
```

---

### Task 3: Documentation

**Files:**
- Modify: `ADOPTING.md` (steps 2, 3, 5, 8; "Updating"; a new migration
  section)
- Modify: `README.md` (lines ~26, ~37, file table ~80, ~314; a "why"
  note)
- Modify: `standards.md:164`
- Modify: `templates/AGENTS.md` (lines 3-10)
- Modify: comments in `hooks/load-standards.sh:10-11` and
  `hooks/lint-changed.sh:7`

**Interfaces:**
- Consumes: the names from Tasks 1-2: `make claude-setup`,
  `dev/claude-settings.json`, `shared/claude-settings.json`,
  `templates/dev/claude-settings.json`.

- [ ] **Step 1: `ADOPTING.md` step 2.** Replace lines 23-29 (from
  "2. **Register the hook and permissions.**" through "so start `claude`
  from the package root.") with:

```markdown
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
```

In the next paragraph (lines 31-39), change "Add a `Bash(git fetch
<remote>)` allow rule for each remote the package uses" to "Add a
`Bash(git fetch <remote>)` allow rule to `dev/claude-settings.json` for
each remote the package uses". Change "the template covers" to "the shared
settings cover".

- [ ] **Step 2: `ADOPTING.md` step 3.** On line 55, change "also add
  them to the deny list in `.claude/settings.json`" to "also add them to
  the deny list in `dev/claude-settings.json`". After the sentence ending
  "and ask for a new setting here if none fits." (line 50), add: "Then run
  `make claude-setup` (step 2)."

- [ ] **Step 3: `ADOPTING.md` step 5.** Add `^\.worktreeinclude$` to the
  `.Rbuildignore` block (after `^\.worktrees$`). Replace the `.gitignore`
  block and add one sentence after it:

````markdown
   Add these to `.gitignore`:

   ```
   .worktrees/
   .claude/
   ```

   `.claude/` holds the settings `make claude-setup` writes and each
   developer's own `settings.local.json`; neither is committed.

   Copy `templates/.worktreeinclude` to the package root, so worktrees
   that Claude Code creates get a copy of the generated settings.
````

- [ ] **Step 4: `ADOPTING.md` step 8.** After "approve the changed hooks
  when asked." add: "If Claude says the standards weren't loaded,
  `.claude/settings.json` is missing; run `make claude-setup`."

- [ ] **Step 5: Add an `ADOPTING.md` "Once per clone" section** between
  "Once per machine" and "Once per package":

```markdown
## Once per clone

In each new clone of a package that has adopted the standards, run
`make claude-setup` before starting `claude`, then approve the hooks when
asked. Run it again after pulling a change to `dev/claude-settings.json`.
```

- [ ] **Step 6: `ADOPTING.md` "Updating".** Replace the first bullet
  ("a new standard `make` target is added, ...") and change the second
  bullet's list. The new list:

```markdown
- the shared settings (`shared/claude-settings.json`) change: each
  developer re-runs `make claude-setup`, but nothing in the package is
  edited;
- a package-specific file changes: `dev/claude-settings.json`,
  `AGENTS.md`, `.lintr`, the PR template, `.Rbuildignore`, or
  `.gitignore`;
- a breaking change is published as `v2` (the package moves when ready).
```

- [ ] **Step 7: Add the `ADOPTING.md` migration section** at the end of
  the file. In "Migrating a package adopted before shared delivery",
  step 4 changes to "Then follow 'Migrating a package that tracks
  `.claude/`' below." (its deny rules are now in the shared settings).

````markdown
## Migrating a package that tracks `.claude/`

Packages adopted before `make claude-setup` existed commit
`.claude/settings.json`, which BiocCheck 1.49 and later reports as an
error. Move them over once, on a branch:

1. Copy `templates/dev/claude-settings.json` to `dev/claude-settings.json`
   and `templates/.worktreeinclude` to the package root, and add
   `^\.worktreeinclude$` to `.Rbuildignore`. Compare the package's `.claude/settings.json` with
   `shared/claude-settings.json` in this repo, and copy into the new file
   only the entries the shared one lacks, such as the package's
   `git fetch` remotes, extra make targets, or people-only denies.
2. Replace `.claude/settings.local.json` in `.gitignore` with `.claude/`,
   then stop tracking the folder without deleting your copy:
   `git rm -r --cached .claude`
3. Run `make claude-setup` and compare the result with the old file:
   `git show HEAD:.claude/settings.json | diff - .claude/settings.json`.
   Only the order of entries and the newer shared rules should differ.
4. Commit and open a PR. Say in its description that **pulling it deletes
   each developer's `.claude/settings.json`**, so everyone must run
   `make claude-setup` after pulling.
````

- [ ] **Step 8: `README.md`.**
  - Line ~26: "registered in its `.claude/settings.json`" → "registered in
    `.claude/settings.json`, which `make claude-setup` writes from the
    shared settings (`shared/claude-settings.json`) and the package's
    `dev/claude-settings.json`. That file isn't committed, because
    BiocCheck (1.49 and later) rejects a tracked `.claude/` folder."
  - Line ~37: "Files that differ between packages (`.claude/settings.json`,
    `AGENTS.md`, ..." → "Files that differ between packages
    (`dev/claude-settings.json`, `AGENTS.md`, ...".
  - File table: replace the `templates/settings.json` row with two rows,
    `shared/claude-settings.json` placed after `shared/standards.mk`:

```markdown
| `shared/claude-settings.json` | Hook registration and permissions shared by every package; `make claude-setup` combines it with the package's own |
| `templates/dev/claude-settings.json` | Empty starting point for a package's own permission rules and hooks |
| `templates/.worktreeinclude` | Makes Claude Code copy the generated settings into worktrees it creates |
```

  - Line ~314: "Add safe extra targets to the allow-list in
    `.claude/settings.json`" → "Add safe extra targets to the allow list
    in `dev/claude-settings.json`".
  - Run `grep -n "settings.json\|the template" README.md` and fix any
    remaining sentence that says packages edit `.claude/settings.json` or
    "the template" for permissions.
  - Under "Commands", add a line for `claude-setup` if the targets are
    listed there (`grep -n "standards-update" README.md` to find the
    list), described as "people only; writes `.claude/settings.json`".

- [ ] **Step 9: `standards.md:164`.** Change "Never edit
  `.claude/settings.json`, `Makefile`, ..." to "Never edit
  `.claude/settings.json`, `dev/claude-settings.json`, `Makefile`, ...".
  Then, in the same section (one line, compact):
  "- Never run `make claude-setup`; ask the developer." Check the length:
  `wc -c standards.md` should grow by less than 120 characters.

- [ ] **Step 10: `templates/AGENTS.md`.** After the first paragraph's
  "...This file adds only what is specific to this package." add:

```markdown
If the standards aren't in your context at session start, this clone has
no `.claude/settings.json`, so neither the standards nor the permission
guardrails are active: stop, and ask the developer to run
`make claude-setup` and restart `claude`.
```

  Leave "those agents also aren't bound by `.claude/settings.json`" as
  it is (still true).

- [ ] **Step 11: Hook comments.** `hooks/load-standards.sh:10-11`: "and
  register it in .claude/settings.json (see ADOPTING.md)" → "`make
  claude-setup` registers it in .claude/settings.json (see ADOPTING.md)".
  Make the same change in `hooks/lint-changed.sh:7`.

- [ ] **Step 12: Verify that no stale references remain**

```bash
grep -rn "templates/settings.json" --exclude-dir=.git --exclude-dir=plans .
grep -n "\.claude/settings\.local\.json" ADOPTING.md
```

Expected: no output from the first. The second shows only the migration
step and the "neither is committed" sentence.

- [ ] **Step 13: Commit**

```bash
git add ADOPTING.md README.md standards.md templates/AGENTS.md hooks/
git commit -m "Document make claude-setup and untracking .claude/ (#8)"
```

---

### Task 4: End-to-end verification and PR

**Files:** none changed. Scratch files go in the session scratchpad.

- [ ] **Step 1: Rerun the automated tests.** Run
  `bash dev/tests/test-claude-setup.sh`. Expected: `All passed.`

- [ ] **Step 2: BiocCheck.** Installed: 1.48.1, which doesn't have the
  check. Confirm the rule only looks at tracked files:

```bash
curl -fsSL https://raw.githubusercontent.com/Bioconductor/BiocCheck/devel/R/BiocCheckGitClone.R | grep -n -A12 "HIDDEN_PATH_COMPONENTS"
```

Expected: the check iterates over `git ls-files` output (tracked paths),
not the directory listing. If it scans the filesystem, **stop**: the
design doesn't fix the issue, so report back. Then, in a scratch git
package with `.claude/` in `.gitignore` and a generated settings file,
confirm `git ls-files | grep -c '\.claude'` prints `0`.

- [ ] **Step 3: Real Claude session (the developer does this; Claude
  can't start a nested session).** Ask the user to run, in a scratch
  package set up with the branch
  (`R_BIOC_STANDARDS_REF=fix/untrack-claude-settings`):
  1. `make claude-setup`, then `claude`: the hooks prompt for approval and
     the standards load.
  2. Ask Claude to edit `dev/claude-settings.json`: denied.
  3. Delete `.claude/settings.json` and start `claude` again: Claude
     follows the AGENTS.md line and asks for `make claude-setup`.
  4. Regenerate, commit `.worktreeinclude`, and run `claude --worktree
     e2e`: the hooks run in the worktree, and `/status` lists
     `.claude/settings.json` as a source.

- [ ] **Step 4: Finish the branch.** Use
  superpowers:finishing-a-development-branch. The PR body says `Fixes #8`
  and notes that after merge the maintainer moves the `v1` tag, then
  migrates singleCellTK and reverts compbiomed/singleCellTK#807's
  tarball-only stopgap. `git push` and `gh pr create` are ask rules, so
  the user approves each one.
