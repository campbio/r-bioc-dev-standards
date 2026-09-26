# <package>: notes for coding agents

The shared development standards (r-bioc-dev-standards) load automatically
at session start. This file adds only what is specific to this package.

## About

<One or two sentences: what the package does and who uses it.>

## Layout

<Where the main code lives, key classes and entry points, and any compiled
code (e.g. Rcpp in src/, Stan models in inst/stan/).>

## Tests

<Slow test files to avoid during development, where fixtures live, and any
optional dependencies that tests skip without.>

## Setup in a new worktree

<Anything needed before tests run in a fresh checkout, e.g.
`renv::restore()`. Write "None" if nothing is needed.>

## Related packages

<Packages that depend on this one or share code with it, and what to check
there when this package changes. Write "None" if there are none.>

## Overrides

<Deliberate exceptions to the shared standards, each with a reason.
Write "None" if there are none.>
