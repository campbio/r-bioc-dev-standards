# <package>: notes for coding agents

The shared development standards (r-bioc-dev-standards) load automatically
at session start in Claude Code. This file adds only what is specific to
this package. Other agents (for example through GEMINI.md) don't get them
automatically: read
https://raw.githubusercontent.com/campbio/r-bioc-dev-standards/v1/standards.md
(or the cached copy in `~/.cache/r-bioc-dev-standards/v1/`) before
starting, and follow it; those agents also aren't bound by
`.claude/settings.json`.

## About

<One or two sentences: what the package does and who uses it.>

## Layout

<Where the main code lives, entry points, and any compiled code (e.g. Rcpp
in src/, Stan models in inst/stan/).>

## Object model

<The main classes (S4 or otherwise), their slots, and the accessors to use
instead of `@`. Write "None" if the package has no classes of its own.>

## Tests

<Slow test files to avoid during development, where fixtures live, and any
optional dependencies that tests skip without.>

## Extra make targets

<Targets beyond the standard set, what each does, and whether agents may
run it without asking (e.g. "`build`: builds the tarball in the repo root;
ask first", "`clean`: deletes compiled objects; people only"). Safe targets
go in the settings allow-list and people-only ones in its deny list. Write
"None" if there are none.>

## Setup in a new worktree

<Anything needed before tests run in a fresh checkout, e.g.
`renv::restore()`. Write "None" if nothing is needed.>

## Related packages

<Packages that depend on this one or share code with it, and what to check
there when this package changes. Each related package lists this one too,
describing the relationship the same way. Write "None" if there are none.>

## Overrides

<Deliberate exceptions to the shared standards, each with a reason.
Write "None" if there are none.>
