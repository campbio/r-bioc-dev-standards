# Spec: leaner workflow (standards v1.1)

## Why

v1.0 required Superpowers and named five of its skills in the workflow.
An r/ClaudeAI thread ("Opus 5.5 - is the Superpowers skill still
needed?") found that the full workflow overspecs and burns context with
current models. One user found that building from the spec beat following
the Superpowers implementation plan. Brainstorming and the debugging
structure were the parts people kept. Here, PR #9 had 780 lines of plan
for about 330 lines of change.

## What changes

- `standards.md` (v1.1):
  - Precedence names superbrainstorming instead of Superpowers.
  - EVALUATE: bugs are reproduced first; features use brainstorming.
  - PLAN becomes SPEC: what, why, and how it's tested. Small changes get
    the spec in chat, larger ones a file in `dev/plans/`. No step-by-step
    plan.
  - EXECUTE: build from the spec and stay within it; new tests fail on
    their assertion first; never weaken, skip, or delete a test.
  - REVIEW: a fresh subagent checks the diff against the spec, then
    `/code-review`.
  - Specs never go in `docs/`, including superbrainstorming's
    `docs/specs/`.
- `README.md`:
  - Install superbrainstorming, with optional `/grill-me` (symlink
    `grill-me` and `grilling` from mattpocock/skills).
  - Superpowers becomes optional, installed instead of superbrainstorming.
  - Process steps 1–4 are rewritten to match the standards, and sources
    are added.
- `ADOPTING.md`: per-machine install line.
- PR template: "Plan review" becomes "Spec review".

## Not changed

Hooks, settings, the Makefile, and workflows. Moving the `v1` tag after
merge is a maintainer step.

## How it's tested

- `standards.md` stays near its previous size.
- No workflow skill names remain outside `dev/plans/`.
- README process steps match the standards.
- `dev/tests/test-claude-setup.sh` still passes.
- After merge, a pilot on one package compares v1.1 against v1.0 sessions.
