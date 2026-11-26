# Authoring a skill

## Layout

```
.github/skills/<name>/
  SKILL.md                  required; the only file loaded when the skill triggers
  references/*.md           optional; detail loaded on demand, one level deep
  scripts/*                 approved helper scripts, executable
  agents/<agent>.md         approved omp subagents; linked into <omp agent dir>/agents/
  tools/<tool>/index.ts     approved omp custom tools; linked into <omp agent dir>/tools/
  assets/*                  optional; templates or files the skill copies, never loaded as context
commands/<cmd>.md           approved slash commands, at the repository root; run as /skills:<cmd>
```

`agents/` and `tools/` are omp-only. Every other harness ignores them, so `SKILL.md` must still work without them; say so where it delegates or calls a tool ("if the `x` tool is unavailable, run …").

## Frontmatter

```yaml
---
name: <name>            # equals the directory name: kebab-case, at most 64 characters
description: <text>     # at most 1024 characters, one line; omp requires it for .github/skills
---
```

The description decides when the skill loads, because omp and other harnesses list it in the system prompt. Write it for routing:

- First, what the skill does, in the third person.
- Then "Use when/for …" followed by concrete triggers: the product names, file names, commands, and phrases from interview round 1.
- End with exclusions ("not for …") that separate it from the overlapping skills.

Add no other keys: the same `SKILL.md` is read by Claude Code, Codex, and other harnesses, and omp-only keys such as `hide` mean nothing there.

## Body

- Keep it imperative and specific, under about 300 lines. Don't explain what a capable agent already knows; spend the words on the things the interview showed agents get wrong.
- Start with a one-paragraph purpose, then **Rules** (the hard constraints and never-dos from the interview), then the **Workflow** or task sections, then **Verification**.
- Put exact commands, flags, config keys, and API calls in code blocks, at the versions recorded in the ledger.
- Show one short, real example per core task instead of describing it abstractly.
- Move long material (API tables, option references, edge cases) to `references/<topic>.md`, link it from the section that needs it, and say when to read it.
- Refer to bundled files with relative Markdown links (to `references/<topic>.md`) and to scripts by skill URL in commands (`skill://<name>/scripts/foo.sh`, which omp's `bash` runs directly). Mention that other harnesses resolve the same path against the skill directory.
- Use omp tool names when the skill needs a tool: `ask` for user decisions, `todo` for multi-step work, `task` for delegation, `web_search`, `read` (files, URLs, `skill://`), `local://` for scratch artifacts.
- Nothing user-specific: no absolute home paths, hostnames, tokens, or account IDs.

## Sources

End `SKILL.md` with the ledger from `local://skill-<name>-ledger.md`, condensed:

```markdown
## Sources

Distilled on <YYYY-MM-DD> from:

- <title>: <url>
- Context7 `<library-id>` (<version>): <topics queried>
```

## Slash commands

Location: `commands/<cmd>.md` at the repository root. The `skills@prdlk` plugin exposes it as `/skills:<cmd>` in omp and Claude Code. Keep it thin: it hands off to the skill and doesn't repeat the skill's instructions.

```markdown
---
description: <one line shown in / autocomplete>
argument-hint: "<required> [optional ...]"
---

Use the `<name>` skill (read skill://<name>) to <task>.

Target: $1
Details: $@[2:]
```

omp argument syntax (one-based): `$1`, `$2` for positional arguments; `$@` or `$ARGUMENTS` for all of them; `$@[2:]` for everything from the second; `$@[2:1]` for exactly the second. Quote arguments that contain spaces; there are no backslash escapes. After the `$` substitution omp renders Handlebars: `{{default (arg 1) "the current branch"}}` and `{{#if args}}…{{/if}}`. Use Handlebars only for defaults or conditional sections; Claude Code shows it literally. Add `side: true` for a read-only question that should run as a `/btw` side query without steering the current turn.

Names must be unique across built-in, skill, and other plugin commands. A new command appears after `omp plugin upgrade skills@prdlk` and `/reload-plugins`.

## Subagents

Location: `.github/skills/<name>/agents/<agent>.md`; the filename equals `name`. Add one only for a recurring, separable delegation.

```markdown
---
name: <agent>
description: <task, subject, and boundary that distinguish it; this is a selection hint>
tools: read, grep, glob        # smallest set that works; add bash, edit, write, or web_search only if the role needs them
thinking-level: medium         # optional
structured: true               # with output: the agent must return JSON matching the schema
output:                        # optional JSON Schema for the result
  type: object
  required: [findings]
  properties:
    findings: { type: array, items: { type: string } }
---

<What the agent owns and must not do, the workflow it follows, the evidence its answer must carry, and whether it may edit files.>
```

Put the changing work in the `task` call, not in the definition. Omit `tools` only if inheriting every parent tool is intended. Add `task` to `tools` only with an explicit `spawns:` list. Omit `model` unless the user named a model or a role alias such as `"@review"`. In `SKILL.md`, delegate with a `task` item whose `agent` is `"<agent>"`, plus an inline fallback. omp re-reads agent definitions on each delegation, so a linked agent is live at once.

## Custom tools

Location: `.github/skills/<name>/tools/<tool>/index.ts`. Custom tools run as trusted code with the user's permissions, so propose one only for a narrow, typed operation that a script and prose can't make reliable.

```ts
import type { CustomToolFactory } from "@oh-my-pi/pi-coding-agent";

const factory: CustomToolFactory = pi => ({
  name: "<tool>",                 // unique across built-in and other custom tools
  label: "<Label>",
  description: "<exactly when the model should call it>",
  approval: "read",               // "read" | "write" | "exec"; omitted means "exec"
  parameters: pi.zod.object({
    action: pi.zod.enum(["check", "summarize"]),
    path: pi.zod.string().describe("Repository-relative path"),
  }),
  async execute(_id, params, _onUpdate, _ctx, signal) {
    const r = await pi.exec("<cli>", [params.action, params.path], { cwd: pi.cwd, signal });
    if (r.code !== 0) throw new Error(r.stderr || "<cli> failed");
    return { content: [{ type: "text", text: r.stdout }] };
  },
});

export default factory;
```

- Narrow schemas: enums for finite actions, a description on every non-obvious field, defaults where omission is safe.
- Forward `signal` to `pi.exec`. Throw on failure; never return success-looking text for a failure.
- Guard `pi.ui` with `pi.hasUI` and keep a headless path.
- Tools load at session start: verify in a new omp session with `/tools`, then with a prompt that names the tool.

## Scripts

- `#!/usr/bin/env bash` and `set -euo pipefail` (or a portable `node`/`python3` shebang when shell is a poor fit).
- `--help` prints usage. Fail with a clear message on stderr and a non-zero exit code.
- Idempotent where possible. Never destructive without a flag the skill tells the agent to pass explicitly.
- Prefer tools that are already required; state any new dependency in `SKILL.md`.
- `chmod +x`, then run each script once with `--help` and once on a real input.
