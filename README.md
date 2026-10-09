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
```

To add a skill, create `.github/skills/<name>/SKILL.md`. Its frontmatter `name` must match `<name>`.
