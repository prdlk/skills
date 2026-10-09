# gum recipes — patterns, layout, theming

Working patterns for this machine: fish first (the interactive shell), bash second (portable
scripts). Flag semantics live in [commands.md](commands.md); this file is about *composition*.

---

## 1. The script skeleton

Every interactive script here should degrade to something usable without a tty, and should never
half-execute after an abort.

### fish

```fish
#!/opt/homebrew/bin/fish
# release.fish — cut a release, interactively

function _die --description 'log an error and exit'
    gum log --level error $argv
    exit 1
end

type -q gum; or _die 'gum is not installed (brew install gum)'
gum version-check '>= 0.16'; or _die 'gum is too old'

# a tty is required for every interactive gum command
isatty stdin; or _die 'this script needs an interactive terminal'

set -l kind (gum choose --header 'Release type' patch minor major)
# 130 abort, 124 timeout — propagate, never continue
or exit $status

set -l notes (gum write --header 'Release notes' --placeholder 'What changed?' | string collect)
or exit $status

gum confirm --default=false "Tag a $kind release?"; or _die aborted

gum spin --title "Tagging $kind…" -- git tag -a "v$kind" -m "$notes"
```

⚠ Capture `$status` **immediately** — `set -l kind (...)` then `or exit $status` is correct;
anything between them clobbers it.

### bash

```bash
#!/usr/bin/env bash
set -euo pipefail

command -v gum >/dev/null || { echo "gum is not installed" >&2; exit 1; }
[[ -t 0 ]] || { echo "needs an interactive terminal" >&2; exit 1; }

kind=$(gum choose --header 'Release type' patch minor major) || exit $?
gum confirm --default=false "Tag a $kind release?" || exit 1
gum spin --title 'Tagging…' -- git tag "v$kind"
```

⚠ `set -e` plus `gum confirm` is a trap: a "No" answer exits 1 and kills the script silently. Always
write `gum confirm … || <handler>` so the negative branch is explicit.

---

## 2. fish-specific gum idioms

Command substitution in fish splits on newlines, which cuts both ways.

| Situation                           | Wrong                                                                                                        | Right                                                                                                    |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------- |
| Multi-line block for `gum join`     | `set -l b (gum style --border rounded A)` → a **3-element list**, and `gum join $b` receives three arguments | `set -l b (gum style --border rounded A \| string collect)`                                              |
| Multi-line text from `gum write`    | `set -l t (gum write)` → one element per line                                                                | `set -l t (gum write \| string collect)`                                                                 |
| Multi-select from `choose`/`filter` | —                                                                                                            | `set -l picks (gum choose --no-limit a b c)` — the split **is** what you want; `$picks` is a proper list |
| Boolean gate                        | `gum confirm && cmd`                                                                                         | `gum confirm; and cmd` — or just `if gum confirm "…"`                                                    |
| Exit status                         | `$?`                                                                                                         | `$status`, captured on the very next line                                                                |

⚠ `string collect` must be **inside** the substitution. `(string join \n -- $b)` re-splits at the
outer substitution and breaks the layout again.

Abbreviations and functions that wrap gum belong in `~/.config/fish/functions/` with a
`--description`; never `alias`. See the `fish` skill.

---

## 3. Layout: `style` + `join`

`gum style` boxes text; `gum join` glues boxes. Build leaves first, compose last.

```fish
set -l ok (gum style --border rounded --border-foreground '#86c452' --padding '0 2' ' PASS ' | string collect)
set -l no (gum style --border rounded --border-foreground '#fc8697' --padding '0 2' ' FAIL ' | string collect)
gum join --horizontal $ok $no
```

```bash
TITLE=$(gum style --bold --foreground '#c9d3f7' 'Deploy')
BODY=$(gum style --faint 'staging → production')
gum style --border double --border-foreground '#6cb6fa' --padding '1 3' --align center \
    "$(gum join --vertical --align center "$TITLE" "$BODY")"
```

Rules that save debugging time:

- Each positional argument to `gum style` is **one line**. Do not embed `\n` yourself.
- `--width` sets the *content* width; borders and padding are added outside it.
- `--padding "1 2 3"` — three tokens — silently becomes `0 0 0 0`. Use 1, 2 or 4.
- Always quote `gum join` arguments.

---

## 4. Colour, and where it disappears

gum reads its colour profile from **stderr**, then `internal/tty` strips ANSI from
*selection results* when stdout is not a tty. In practice:

| Context                                           | Colour in `gum style` output?  |
| ------------------------------------------------- | ------------------------------ |
| Interactive terminal                              | yes                            |
| `X=$(gum style …)` in an interactive terminal     | yes — stderr is still a tty    |
| `gum style … \| cat`, CI, a Claude Code Bash call | **no** — plain text            |
| Any of the above with `CLICOLOR_FORCE=1`          | yes                            |
| Anything with `NO_COLOR=1`                        | no — it beats `CLICOLOR_FORCE` |

`FORCE_COLOR` is not honoured. If a script's output is meant to be piped somewhere that renders
ANSI, set `CLICOLOR_FORCE=1` explicitly rather than hoping.

---

## 5. Markdown and glamour

glamour v0.10.0 is vendored into gum, and there is no `glow` binary. `gh` embeds its own copy for
issue/PR bodies, so the machine has **two glamour surfaces with two separate variables**:

| Renderer           | Variable           | Set by                                                |
| ------------------ | ------------------ | ----------------------------------------------------- |
| `gum format`       | `GUM_FORMAT_THEME` | `conf.d/gum.fish`                                     |
| `gh issue/pr view` | `GLAMOUR_STYLE`    | `conf.d/xdg-apps.fish` (guarded, `set -q`-respecting) |

Both point at `~/.config/glamour/laramie.json`. ⚠ **gum does not read `GLAMOUR_STYLE`** — setting it
alone changes `gh` and nothing else, and moving the theme file means editing both snippets.

```bash
gum format < CHANGELOG.md | gum pager                 # rendered laramie, scrollable
gum format --theme dark -- '# Heading' '- point one'  # one-off override
```

Built-in theme names: `pink` (default) `ascii` `auto` `dark` `dracula` `light` `notty`
`tokyo-night`. `laramie` is Tokyo Night-derived, so `tokyo-night` is the closest built-in fallback.

---

## 6. Theming gum with laramie

**Live and installed: `~/.config/fish/conf.d/gum.fish`** (2026-07-29). Read that file for the
current values — this repo mirrors no config. gum has no config file of its own, so theming is ~24
`GUM_<COMMAND>_<FLAG>` environment variables, which is why it earns its own `conf.d` snippet rather
than a stanza in `colours.fish` (which now carries a ⚠ pointer saying so).

What it does, and the decisions worth not re-litigating:

| Decision                                                            | Why                                                                                                                                                                                                      |
| ------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `type -q gum; or return` at the top                                 | one concern per file, so the bare `return` is safe                                                                                                                                                       |
| **No** `status is-interactive` guard                                | a *script* calling `gum choose` is precisely the case that needs the palette; `functions/reload.fish` is one such caller                                                                                 |
| `set -q theme_violet_base; or return`                               | ⚠ **added 2026-07-30.** The values are now `$theme_*`, not literal hex — see below. Without this guard a failed palette load would export empty strings, which gum renders unstyled rather than erroring |
| Foreground accents only                                             | `ui.accent` (violet) for cursors/indicators/spinners/selections, `ui.label` (blue) for headers/prompts, `text.faint` for placeholders. Backgrounds stay at gum's defaults except `confirm`'s two pills   |
| `GUM_FORMAT_THEME` set here, `GLAMOUR_STYLE` set in `xdg-apps.fish` | two renderers, two variables, one JSON file — see §5                                                                                                                                                     |
| Unprefixed `$FOREGROUND`/`$BORDER`/`$PADDING` deliberately absent   | not namespaced; exporting them would restyle every `gum style` call on the machine                                                                                                                       |

⚠ **The values are `$theme_*` variables, not literal hex — changed 2026-07-30.**
`conf.d/colours.fish` sources the palette *above* its own interactive guard and sorts earlier (`c` <
`g`), so the palette is always present here. This removed 23 hardcoded hexes and one whole copy of
the palette; benchmarked as marginally faster than the literals it replaced (30 runs, `hyperfine`),
since variable expansion forks nothing.

Extending it: add the `GUM_<COMMAND>_<KEY>_FOREGROUND` line ([commands.md](commands.md) lists every
style key per command), set it to the `$theme_*` primitive named by the **`laramie` skill's**
`references/bindings.md`, and re-run the verification in the SKILL.md.

⚠ **The `laramie` skill owns every colour value and the per-tool binding table.** Do not pick a hex
here; look it up there. A colour change is a change to `references/spec.md` first.

⚠ `set -x` displays a literal hex value as `'#cb92fc'` **with quotes**. That is fish quoting `#` for
round-trip safety in its listing, not part of the value; `string length` confirms 7.

⚠ Do **not** export the unprefixed `gum style` variables (`$FOREGROUND`, `$BORDER`, `$PADDING`, …)
globally. They are not namespaced and would restyle every `gum style` call in every script.

---

## 7. Recipes

**Menu from a command's output**

```fish
set -l branch (git branch --format='%(refname:short)' | gum filter --header 'Checkout')
and git switch $branch
```

**Multi-select, then act**

```fish
git branch --format='%(refname:short)' | gum choose --no-limit --header 'Delete branches' \
    | xargs -r git branch -D
```

**Label/value menu** — show something readable, return something machine-usable:

```bash
action=$(gum choose --label-delimiter=: \
    "Rebuild the site:make build" \
    "Deploy to staging:make deploy-staging" \
    "Tail logs:make logs")
eval "$action"
```

**Conventional commit** (the canonical gum demo, house-adjusted):

```fish
set -l type (gum choose feat fix docs style refactor test chore)
or exit $status
set -l scope (gum input --header 'Scope' --placeholder 'optional')
test -n "$scope"; and set scope "($scope)"
set -l summary (gum input --header 'Summary' --value "$type$scope: " --width 72)
or exit $status
set -l body (gum write --header 'Body' --placeholder 'optional details' | string collect)
gum confirm 'Commit?'; and git commit -m "$summary" -m "$body"
```

**Progress around slow work** — one `spin` per phase, exit codes preserved:

```bash
gum spin --title 'Resolving…'  -- brew update
gum spin --title 'Upgrading…'  --show-error -- brew upgrade
```

**Structured status output** instead of `echo`:

```bash
gum log --level info  --structured 'Uploading' file "$f" size "$(wc -c <"$f")"
gum log --level error --structured 'Upload failed' file "$f" code "$?"
```

**Summary table**

```bash
{ echo 'check,result'; echo 'fish,ok'; echo 'ghostty,ok'; } \
    | gum table --print --border rounded
```

**Password without a plaintext round-trip** — pipe straight into the consumer, never a variable:

```bash
gum input --password --header 'Vault passphrase' | sudo -nS true
```

⚠ For anything credential-shaped, prefer `op run` / `op://` references over prompting at all. See
`.claude/skills/auth/SKILL.md` and the `auth` skill — a prompted secret in a shell variable is a
plaintext secret.

---

## 8. Choosing the right command

| Need                               | Use                                          |
| ---------------------------------- | -------------------------------------------- |
| Pick 1 of a handful                | `choose`                                     |
| Pick from a long or generated list | `filter`                                     |
| Multi-select                       | `choose --no-limit` / `filter --no-limit`    |
| Yes/no gate                        | `confirm` (`--default=false` if destructive) |
| One-line answer                    | `input`                                      |
| Paragraph                          | `write`                                      |
| A path                             | `file` (`--directory` for folders)           |
| A row of CSV                       | `table`                                      |
| Show a long document               | `format` → `pager`                           |
| Wait on a command                  | `spin`                                       |
| A box, banner or coloured span     | `style` (+ `join`)                           |
| Status / progress messages         | `log`                                        |
| Render markdown                    | `format`                                     |
