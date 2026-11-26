# `prdlk/skills`

A collection of skills for cross-platform agentic development.

## Install

**Claude Code**

```sh
claude plugin marketplace add prdlk/skills
claude plugin install skills@prdlk
```

**omp**

```sh
omp plugin marketplace add prdlk/skills
omp plugin install skills@prdlk
```

**Codex**

```sh
codex plugin marketplace add prdlk/skills
codex plugin add skills@prdlk
```

**opencode** (or any other agent, via [`skills`](https://github.com/vercel-labs/skills))

```sh
npx skills add prdlk/skills -g -a opencode
```

## Layout

```
.github/skills/<name>/SKILL.md     skills (source of truth)
.agents/skills -> ../.github/skills  project discovery for Codex, opencode, omp
.claude-plugin/marketplace.json    marketplace catalog for Claude Code, omp, Codex
.claude-plugin/plugin.json         plugin manifest, points at .github/skills/
commands/<cmd>.md                  plugin slash commands, invoked as /skills:<cmd>
```

To add a skill, create `.github/skills/<name>/SKILL.md`. Its frontmatter `name` must match `<name>`.

Or run `/skills:build-new-skill <name> [doc-url ...]` in omp (or `/skill:skill-builder <name> [doc-url ...]` before the plugin is upgraded). The `skill-builder` skill interviews you with `ask` forms, has its `skill-researcher` subagent read the links with Exa and distill library docs with Context7, runs a gap analysis, writes the skill, adding slash commands, subagents, custom tools, or scripts only with your approval, and links it into `~/.omp/agent/skills`, `~/.agents/skills`, and `~/.claude/skills` (subagents and tools into `~/.omp/agent/agents` and `~/.omp/agent/tools`). Skills built this way stay out of `.github/skill-sources.json`.

## Upstream sync

Skills vendored from other repositories are listed in `.github/skill-sources.json` (`repo`, `path`, optional `ref` branch, tag, or full commit SHA; pin to a tag or commit when upstream has removed the skill from its default branch). The `Sync skills` workflow (`.github/workflows/sync-skills.yml`) runs every Monday, Wednesday, and Friday at 06:17 UTC and on demand: it replaces each listed skill with the upstream copy, records the upstream `commit`, and pushes any changes to the default branch. Local edits to a listed skill are overwritten; skills absent from the manifest are left alone.

Run it locally with `.github/scripts/sync-skills.sh [skill...]`.
