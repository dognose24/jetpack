# How the `eslint-disable-line` inline-form requirement was discovered

Captured here because the path to the resolved invariant ran through
four rounds of PR review and the wrong answer was committed twice before
the right one held. Future implementers should not need to retrace this
— the invariant itself lives in
[`../../AGENTS.md`](../../AGENTS.md) → "Common patterns and pitfalls" →
"ESLint patterns". This file is the forensic trail explaining *how* the
team reached that invariant, not what it is.

Audience: agents and humans extending the chart-related code in this
package. Read this only if you are touching the `@automattic/charts`
CSS-import pattern itself or are about to question the inline-form
choice.

---

## What was being implemented

A pie chart on the analytics dashboard, requiring a CSS subpath import:

```ts
import '@automattic/charts/style.css';
```

The subpath resolves to `dist/index.css`, which is gitignored and not
built during the ESLint CI step, so `import/no-unresolved` fires on
the import in CI lint.

The task md (now removed; see [`../../AGENTS.md`](../../AGENTS.md) for
the current canonical reference) initially told the agent to disable
the rule. The form of the disable directive turned out to be
load-bearing in a non-obvious way.

## Round 1 — first attempt: `eslint-disable-next-line`

Initial form:

```ts
// eslint-disable-next-line import/no-unresolved -- CSS subpath; dist/index.css is gitignored
import '@automattic/charts/style.css';
```

Locally, this was fine. On CI, `import/no-unresolved` fired anyway —
the disable comment was *not in the committed file*. The agent's
sandbox tree had it; the pushed commit didn't.

## Round 2 — first guess at the mechanism: Prettier blank line

Hypothesis: Prettier was inserting a blank line between the disable
comment and the import, breaking the next-line scope.

The fix proposed was to switch to inline `eslint-disable-line`, which
travels with the import token and isn't affected by intervening
whitespace.

Verified empirically (the inline form survived the pipeline), so the
fix shipped. The hypothesis about Prettier was wrong — confirmed in
Round 3 — but the fix happened to also solve the actual underlying
problem, so the symptom went away.

## Round 3 — Copilot review caught the wrong mechanism

A Copilot review on the task md called out that
`.prettierrc.js` only loads `prettier-plugin-svelte`; no
import-organizing plugin is in the Prettier config. So Prettier
couldn't have been the cause of the blank line in Round 2.

Re-investigation pointed at ESLint instead. `tools/js-tools/eslintrc/base.mjs:318-325`
configures `import/order`:

```js
'newlines-between': 'never',
```

…plus alphabetic ordering. The `pnpm run lint-file --fix` step in
pre-commit applies this rule, which reorders imports. During that
reorder pass, the standalone `eslint-disable-next-line` comment ends
up missing from the file that subsequently gets committed.

The task md was rewritten in Round 3 to blame ESLint's `import/order`
reorder + `--fix` removing the now-detached comment, instead of
Prettier.

## Round 4 — Copilot caught the next-rung wrong mechanism

Round 3's "ESLint `--fix` removes the orphaned comment" was *also*
unverified. Copilot pointed out that `pnpm run lint-file` is just
`eslint --flag v10_config_lookup_from_file`; it does not pass
`--report-unused-disable-directives`, and `reportUnusedDisableDirectives`
doesn't appear in the ESLint configs either. So `--fix` should not be
removing the directive even when it's orphaned.

At this point the team chose to stop chasing the mechanism. The
relevant signal is the observed outcome — multiple sandbox runs of
the task show the next-line form's directive missing from the
committed file — not whichever specific rule or fix interaction is
responsible.

The task md was rewritten one more time to describe the failure chain
purely in terms of *what is observed*, not *why*:

> pre-commit reorders imports → disable comment ends up missing from
> the committed file → CI lint fails on `import/no-unresolved`.

The practical fix (inline `eslint-disable-line`) is unchanged; the
spec just stopped making claims about lint internals it couldn't
substantiate.

## Discipline that came out of this

1. **Spec-as-source-of-truth for future agents** means we can't encode
   wrong mechanisms even when the practical fix happens to work — the
   wrong mechanism propagates into the next agent's mental model.
2. **The inline-vs-next-line choice is load-bearing**, but the *reason*
   it's load-bearing is observed, not understood. That's OK to ship
   provided we say so explicitly.
3. **Multi-round Copilot review is genuinely useful** for spec
   correctness, not just code. Two of the four rounds caught
   wrong-but-plausible mechanism claims that would otherwise have
   become baked-in wisdom.

## Why this file exists

The invariant ("use inline `eslint-disable-line`") lives in
[`../../AGENTS.md`](../../AGENTS.md). It would be a one-liner there if
someone discovered it from scratch, but in practice the wrong forms
look reasonable and the team has already burned cycles on each of
them. This file is the receipt — if a future implementer or reviewer
proposes switching to `eslint-disable-next-line` thinking "the agents
just got confused", they can find here a concrete account of which
specific guesses turned out to be wrong and why the team stopped
trying to explain the mechanism.

---

## Index

This is the first entry under `docs/research/`. The convention is:
short, specific, named after the invariant the research produced.
Future entries should follow the same shape — what was implemented,
what went wrong, what was tried, what the final discipline is.
