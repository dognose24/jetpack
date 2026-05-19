# Skill naming + registration

Conventions for skills under `.agents/skills/` and how they surface as Claude Code
slash commands.

---

## Naming convention

```
<scope>-<verb>[-<object>]
```

- **scope** — package name, topic, or the repo. Examples in tree: `jetpack`,
  `premium-analytics`, `wp-abilities`, `charts`. Use the package directory name
  when the skill is bound to a package.
- **verb** — what the skill does. Examples in tree: `verify`, `review`, `audit`,
  `screenshot`. Other reasonable verbs: `implement`, `prototype`, `build`.
- **object** — optional, when the verb needs disambiguation. Examples in tree:
  `wp-abilities-verify` (verb only, object implied by scope),
  `premium-analytics-implement-task` (verb + object).

Use kebab-case. The file name is `<full-name>.md`.

---

## Slash-command registration

A skill under `.agents/skills/<name>.md` is **not** automatically invocable as
`/<name>` in Claude Code. It needs a stub file at `.claude/commands/<name>.md`:

```markdown
---
description: One-line description of what `/the-skill` does and when to use it.
---

@../../.agents/skills/<name>.md
```

The stub's frontmatter `description` is what users see in the slash-command
picker. The body imports the actual skill file via `@`-import. Keep the stub
small — all real logic lives in the skill file.

### When to add a stub

Add a stub whenever the skill is meant to be **directly invoked by name** during
a session. Skills that are only invoked by other skills (e.g. utility helpers,
sub-flows of a larger pipeline) don't need stubs.

Rule of thumb: if you'd want to type `/the-skill` to start it, it needs a stub.

### Why it matters

Without the stub, typing `/premium-analytics-foo <arg>` fails with
`Args from unknown skill: <arg>` — an unhelpful error that surfaces at
invocation time, not at file creation time. The lint script catches it before
that happens.

---

## Lint

```bash
bash .agents/check-skill-registration.sh
```

Scope is currently narrow: it enforces stub-presence only for skills matching
`.agents/skills/premium-analytics-*.md`. Other namespaces are unaffected.

To extend enforcement to a new namespace, edit the glob in the script. Don't
extend it speculatively — only widen when an actual second namespace shows the
same trap.

### When to run

- Before committing a new skill — fastest catch.
- Manually any time you suspect a stub got dropped during a rebase / refactor.

The script is plain bash and exits non-zero on any missing stub, so it composes
cleanly with pre-commit hooks or CI later if desired. Not wired up
automatically today.
