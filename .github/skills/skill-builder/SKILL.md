---
name: skill-builder
description: Builds a new agent skill in the prdlk/skills repository from documentation links, then links it into this machine's agent skill directories. Interviews the user at length for purpose and context, reads the links with Exa, distills library docs with Context7, and runs a gap analysis before writing. Use for "/skills:build-new-skill <name>", "build/create/make a new skill", or "turn these docs into a skill"; not for editing vendored skills listed in .github/skill-sources.json.
---

# Skill builder

Turn a skill name plus documentation links into a finished skill at `.github/skills/<name>/` in the prdlk/skills repository, linked into this machine's agents. omp is the primary harness: the steps below use omp tools (`todo`, `ask`, `task`, `web_search`, `read`, `bash`) and omp internal URLs (`skill://`, `local://`).

Invocation: `/skills:build-new-skill <name-of-skill> [doc-url ...]` (plugin command), or `/skill:skill-builder <name> [doc-url ...]`. The first argument is the skill name; the rest are documentation sources.

Helpers run directly by their skill URL from `bash`: `skill://skill-builder/scripts/skillctl.sh` and `skill://skill-builder/scripts/exa.sh`. `skillctl.sh` finds the prdlk/skills checkout from the working directory, else from its own location, else from `$SKILLS_REPO`.

## Rules

- Never write the skill before the interview and gap analysis are done. The user's answers outrank the docs; the docs outrank your memory.
- Never add a slash command, subagent, custom tool, or script that the user has not explicitly approved, item by item.
- Never put secrets, tokens, or user-specific absolute paths (`/home/<user>/…`) in the skill. Use `$HOME`, environment variables, or "ask the user".
- Never add the new skill to `.github/skill-sources.json`: that manifest is for vendored skills, and the sync workflow overwrites them.
- Don't commit or push unless the user asks.

## Workflow

Start with `todo` `init`, one task per step below; each must finish before the next begins.

### 1. Check the name

```sh
skill://skill-builder/scripts/skillctl.sh check-name <name>
```

The script rejects names that aren't kebab-case, are longer than 64 characters, or collide with a repo skill, a manifest entry, or an installed skill. On failure, show the reason and ask for another name.

### 2. Collect sources

Take every URL from the arguments. If there are none, ask for documentation links in the first `ask` form: official docs, API references, READMEs, changelogs, blog posts, internal pages. Ask what each link is for when that isn't obvious.

### 3. Interview: purpose and context

Follow [references/interview.md](references/interview.md): one `ask` form per round, at most four questions each, with your recommended option preselected. Don't stop after one round: continue until every row of the gap matrix is answered or the user explicitly marks it out of scope.

Before round 1, check the skills listed in your system prompt for overlap (read a candidate with `read skill://<name>` when its description is ambiguous) and raise it. The user decides whether to differentiate, merge, or stop.

### 4. Research

Read every source; don't summarize from memory. Fan the work out to the `skill-researcher` subagent (`skill://skill-builder/agents/skill-researcher.md`; linked into omp by step 8 of an earlier build, or by `skillctl.sh link skill-builder`):

- Make one `task` call with one item per source cluster (for example, a group of related pages, or one library), each with `agent: "skill-researcher"`. Each `task` names its sources, the versions the user pinned, and the interview topics it must answer. Put the interview summary in the shared `context`.
- Each researcher returns `sources` (facts with verbatim snippets), `gaps`, `conflicts`, and `extra_topics`.
- With two or fewer sources, or if the agent isn't available, do the research yourself the same way: `skill://skill-builder/scripts/exa.sh fetch <url>...` for pages (fall back to `read <url>`), `npx -y ctx7 library <name> "<topic>"` then `npx -y ctx7 docs <id> "<topic>" [--tag <version>]` for libraries, and `web_search` (Exa-backed) for missing official pages.

Merge the results into a source ledger at `local://skill-<name>-ledger.md`: source, version or retrieval date, and the facts taken from it. It becomes the skill's Sources section.

### 5. Gap analysis

Build the gap matrix from [references/interview.md](references/interview.md) out of the interview and the ledger, then hold another `ask` round covering:

- the researchers' `extra_topics` (in scope or out?)
- user requirements no source supports
- `conflicts` between sources, versions, or the user's answers
- the companion proposal from step 6

Repeat research and this step until no row is open.

### 6. Companions (only if necessary)

Propose an omp companion only when prose instructions in `SKILL.md` would not be enough:

| Companion | Where it lives | Propose it when |
|---|---|---|
| Slash command | `commands/<cmd>.md` at the repository root, run as `/skills:<cmd>` | the user asked for an entry point that takes arguments |
| Subagent | `.github/skills/<name>/agents/<agent>.md` | a recurring, separable delegation (research, review) needs its own instructions, tool limits, or structured output |
| Custom tool | `.github/skills/<name>/tools/<tool>/index.ts` | the agent needs a validated, typed operation, such as an internal API call or an invariant check |
| Script | `.github/skills/<name>/scripts/<verb>.sh` | a multi-step or error-prone shell sequence would otherwise be repeated |

Present every proposal in one `ask` form, one checkbox per item, nothing preselected, each with its name, purpose, inputs, outputs, and why prose is not enough. Build only what the user checks. If nothing qualifies, say so and build none.

### 7. Write the skill

Follow [references/authoring.md](references/authoring.md) for `SKILL.md`, `references/`, the Sources section, and each approved companion. Show the user the draft `SKILL.md` and file list in an `ask` form (approve, or a textarea for edits) and apply their edits before linking.

### 8. Validate and link

```sh
skill://skill-builder/scripts/skillctl.sh validate <name>
skill://skill-builder/scripts/skillctl.sh link <name>
```

`validate` checks the frontmatter, relative links, user-specific paths, script permissions, and companion structure; fix every error it reports. Run each approved script once with `--help` and once on a real input.

`link` symlinks `.github/skills/<name>` into `<omp agent dir>/skills` (so the working copy outranks the plugin's cached copy), `~/.agents/skills` (Codex, opencode, Gemini CLI, and others), and `~/.claude/skills` (Claude Code). It links `agents/*.md` into `<omp agent dir>/agents/` and `tools/<tool>/` into `<omp agent dir>/tools/`. It never overwrites an entry that isn't already its own link. `SKILL_LINK_DIRS="dir:dir"` replaces the skill link directories.

Then `read skill://<name>`: omp rediscovers skills on an unknown name, so this proves the link works and loads the skill into the current session.

### 9. Report

Report the files created, the link paths, the validation result, open questions, and the scope decisions the user made. Then say what needs a refresh:

- the skill and subagents: live now
- custom tools: start a new omp session, then check `/tools`
- slash commands: commit, push, run `omp plugin upgrade skills@prdlk`, then `/reload-plugins`; until then, use `/skill:<name>`
