# Interview and gap analysis

The goal is a skill that makes an agent do the right thing without asking. Every question below closes a gap the docs alone can't close. Skip a question only when an earlier answer or the sources already answer it, and state the inferred answer so the user can correct it.

## Asking with omp

Ask each round as one `ask` form with at most four questions:

- One `<fieldset>` and `<legend>` per question, with a `<p>` of context taken from the sources or earlier answers.
- Concrete options as radio buttons (pick one) or checkboxes (pick many). Preselect your recommendation with `checked`. Don't add your own "Other" option: omp adds a free-text one to every radio and checkbox group.
- A `<textarea>` for open questions (problem statement, example prompts, the walkthrough).
- If the form times out, omp submits the preselected values. Treat those answers as unconfirmed and ask them again in the next round.

```html
<form>
  <p>Round 1 of the interview for <code>pg-migrate</code>: purpose and triggers.</p>
  <fieldset>
    <legend>What should this skill fix?</legend>
    <textarea name="problem" placeholder="What agents get wrong or rediscover today"></textarea>
  </fieldset>
  <fieldset>
    <legend>Which agents use it?</legend>
    <label><input type="checkbox" name="agents" value="omp" checked> omp</label>
    <label><input type="checkbox" name="agents" value="claude"> Claude Code</label>
    <label><input type="checkbox" name="agents" value="codex"> Codex</label>
  </fieldset>
</form>
```

If `ask` is unavailable (a headless or subagent session), put the round's questions in your reply and stop until the user answers.

## Round 1: purpose and triggers

1. What problem should this skill solve? What does the agent get wrong or have to rediscover today without it?
2. Write three or more prompts that should load the skill.
3. Which nearby requests should *not* load it? Name the overlapping skills, if any.
4. Who uses it, and where? (Which agents; personal machine or any machine; one project or any project.)

## Round 2: scope and environment

1. Which products, libraries, CLIs, or APIs does it cover, and which versions? Is "latest" acceptable, or should it be pinned?
2. What runtime, OS, package manager, or toolchain does it assume?
3. Does it need credentials, accounts, network access, or local services? How should the agent get them? (Never store them in the skill.)
4. What is explicitly out of scope?

## Round 3: workflow and output

1. Walk through one real task from start to finish. What does "done" look like?
2. What artifacts does it produce (files, configs, commands run, PRs, reports), and in what format or style?
3. Which conventions, preferences, or house rules must the agent follow?
4. What must the agent never do? Which mistakes are costly or irreversible?

## Round 4: verification and maintenance

1. How should the agent verify its work (a command, a test, a visual check)?
2. Which failure modes or error messages come up often, and how are they fixed?
3. Should the skill track upstream changes (changelog, version notes) or stay frozen at a version?
4. Are there examples, internal docs, or repos it should copy patterns from?

## Round 5+: gap analysis (after research)

Build this matrix from the interview and the source ledger. Each row ends up **answered** (with its source), **out of scope** (the user said so), or **open**. Ask about every open row, plus:

- **Uncovered docs**: sections the sources cover that the user never mentioned. Ask whether each is in scope.
- **Unsupported asks**: requirements the user stated that no source backs up. Ask for a source, or record the requirement as the user's rule.
- **Contradictions**: the docs disagree with the user, or one version disagrees with another. The user picks; record the choice.
- **Companions**: the proposal from workflow step 6, with a yes/no for each item.

| Dimension | Question it settles |
|---|---|
| Trigger | When does the skill load, and when doesn't it? |
| Overlap | How does it differ from the existing skills? |
| Scope | What does it cover, and what is excluded? |
| Environment | Runtime, OS, toolchain, versions |
| Access | Credentials, accounts, network, services |
| Inputs | What the user or project provides |
| Procedure | The ordered steps for each core task |
| Output | Artifacts, formats, conventions |
| Constraints | Hard rules and forbidden actions |
| Failure modes | Common errors and their fixes |
| Verification | How the agent proves the task is done |
| Companions | Approved slash commands, subagents, custom tools, or scripts, or none |
| Maintenance | Pinned version, or how to stay current |

Stop interviewing only when no row is open.
