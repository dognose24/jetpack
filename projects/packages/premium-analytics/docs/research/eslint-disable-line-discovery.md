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

## Round 5 — host dogfood (PR #49 / [RSM-3713](https://linear.app/a8c/issue/RSM-3713)) falsifies "inline is robust"

The Phase 1 Linear-first restructure (PR #48) shipped an AGENTS.md
"ESLint patterns" section claiming the inline form persists because
"the trailing-on-the-same-line form travels with the import token, so
reordering doesn't separate them." The first dogfood task run under
that spec — adding a page-views line chart on host — falsified that
claim within minutes.

The sequence on
`add/premium-analytics-line-chart` (commit `dd52a32094`):

1. `Write` placed
   `import '@automattic/charts/style.css'; // eslint-disable-line import/no-unresolved -- ...`
   in `stage.tsx` alongside three other new imports.
2. `git commit` ran the pre-commit pipeline (Prettier formatting, then
   `eslint --fix` via `lint-file` on the three staged files).
3. `git show HEAD -- ...stage.tsx` revealed the import line was
   present but the inline directive **was gone**.

A follow-up commit (`e60c87ea93`) re-added the comment manually. That
commit's pre-commit pass left the directive intact — most plausibly
because the only change in that commit was the comment itself; the
strip mechanism (whatever it is) seems to require a broader rewrite
in the same pass.

### The pie chart branch never actually shipped the inline form either

While investigating Round 5, `git log --all -S 'eslint-disable-line
import/no-unresolved' --oneline -- projects/packages/premium-analytics/routes/dashboard/stage.tsx`
returned a single commit: `e60c87ea93` (the Round 5 follow-up
above). No commit on `fork/add/premium-analytics-pie-chart` —
the branch whose review cycle drove Rounds 1–4 — ever contained the
inline directive in `stage.tsx`. `git show
fork/add/premium-analytics-pie-chart:.../stage.tsx` confirms it: the
import is there, the directive is not.

Implication: the Round 2 conclusion that "the inline form survived
the pipeline" appears to have been a misread of the local working
tree at the time, never re-verified against the committed file.
Rounds 3–4's confident claims about *why* the inline form was robust
were therefore built on a load-bearing observation that turned out
to be wrong.

## Updated discipline (post-Round 5)

1. **Spec-as-source-of-truth for future agents** means we can't encode
   wrong mechanisms even when the practical fix happens to work — the
   wrong mechanism propagates into the next agent's mental model.
   Round 5 demonstrates this directly: the Round 4 "inline is robust"
   claim survived because nobody re-read the committed file, and the
   first agent run under the spec immediately tripped it.
2. **Both forms are unreliable across pre-commit, and we still don't
   understand the mechanism.** The inline-vs-next-line distinction is
   no longer load-bearing; both have been observed to strip. The
   load-bearing thing is the *post-commit verification step* — `git
   show HEAD -- <file>` and re-add if missing.
3. **Multi-round Copilot review is genuinely useful** for spec
   correctness, not just code. Two of the original four rounds caught
   wrong-but-plausible mechanism claims; Round 5 (a dogfood, not a
   Copilot round) caught the residual wrong observation that survived
   all four.
4. **Dogfood-as-validation actually fires.** PR #48 (the spec change)
   was designed to be gated by a real implement-task run before merge.
   That run (RSM-3713 / PR #49) falsified a load-bearing spec claim
   within the first commit. The two-PR-stack pattern was the difference
   between "ship the wrong spec" and "catch the wrong spec".

## Why this file exists

The current invariant ("both forms strip; verify after commit, re-add
if missing") lives in [`../../AGENTS.md`](../../AGENTS.md) →
"Common patterns and pitfalls" → "ESLint patterns". It would be a
one-liner there if someone discovered it from scratch, but in practice
this team has now burned five rounds on the question. This file is
the receipt — if a future implementer or reviewer proposes "let's
just use the inline form and skip the post-commit check", they can
find here a concrete account of how each prior shortcut failed, and
why the only durable fix (so far) is the verification step itself.

---

## Index

This is the first entry under `docs/research/`. The convention is:
short, specific, named after the invariant the research produced.
Future entries should follow the same shape — what was implemented,
what went wrong, what was tried, what the final discipline is.
