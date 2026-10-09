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
for bad in '{"env": {"X": "1"}}' '{"permissions": {"defaultMode": "auto"}}' '{ not json' \
    '{"hooks": {"PostToolUse": {"matcher": "Bash", "hooks": []}}}' \
    '{"permissions": {"allow": [{"x": 1}]}}' \
    '{"permissions": {"deny": ["a"]}, "permissions": {"deny": ["b"]}}' \
    '"just a string"'; do
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
# `!` in Claude Code runs commands in Claude's shell, so the message must
# send the developer to a terminal outside it.
msg="$(CLAUDECODE=1 make -s claude-setup 2>&1)"
status=$?
if [ $status -ne 0 ] && printf '%s' "$msg" | grep -q "outside Claude Code" \
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

# 9a. No Write(path) rules: Claude Code warns about each at startup, and
# Edit(path) rules already cover every file-editing tool.
name="shared settings have no Write() rules"
check jq -e '[.permissions[][] | select(startswith("Write("))] | length == 0' "$base"

# 9. Listed by make help.
name="make help lists claude-setup"
check sh -c 'make -s help | grep -q "^  claude-setup "'

# 10. Refuses in a package that still commits .claude/settings.json, so
# the package's own rules aren't silently dropped.
name="refuses while .claude/settings.json is tracked"
mkdir -p "$work/tracked" && cd "$work/tracked" || exit 1
cp "$repo/templates/Makefile" Makefile
mkdir -p .claude
echo '{"permissions": {"allow": ["Bash(git fetch campbio)"]}}' > .claude/settings.json
cp .claude/settings.json "$work/tracked.json"
git init -q . && git add .claude/settings.json
msg="$(make -s claude-setup 2>&1)"
status=$?
if [ $status -ne 0 ] && printf '%s' "$msg" | grep -q "Migrating a package that tracks" \
   && cmp -s .claude/settings.json "$work/tracked.json"; then ok "$name"; else fail "$name"; fi
cd "$work/pkg" || exit 1

echo
echo "Test files are in $work"
if [ "$fails" -eq 0 ]; then echo "All passed."; else echo "$fails failed."; exit 1; fi
