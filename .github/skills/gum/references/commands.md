# gum — complete command and flag reference

Every flag, default, environment variable and enum for **gum 0.17.x** (`/opt/homebrew/bin/gum`, the
current upstream release). Dumped from `gum <cmd> --help` on this machine and cross-checked against
the `v0.17.0` source, so the defaults below are the ones you will actually get.

⚠ Regenerate this file after `brew upgrade gum` — see the SKILL.md maintenance section.

---

## 1. The universal contract

```text
gum <command> [flags] [args]
```

Global flags on every command: `-h/--help`, `-v/--version`.

| Property             | Behaviour                                                                                                                                                                                         |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **TUI stream**       | Every interactive command renders through `tea.WithOutput(os.Stderr)` — the interface is on **stderr**, the result on **stdout**. `$(gum choose …)` is therefore safe and still shows the picker. |
| **Colour profile**   | Detected from **stderr**, not stdout (`termenv.NewOutput(os.Stderr)`). Capturing stdout does not kill colour; redirecting stderr does.                                                            |
| **Input device**     | Interactive commands open `/dev/tty` directly. No tty → `could not open a new TTY` on stderr, exit 1.                                                                                             |
| **Result stripping** | Selection results print via `internal/tty.Println`, which strips ANSI when stdout is not a tty. So a captured selection is always clean text.                                                     |
| **stdin**            | `choose`, `filter`, `table`, `pager`, `format`, `style`, `write`, `input` read stdin when it is a pipe. `confirm` reads a *single line* and answers from it without prompting.                    |

### Exit codes

| Code  | Meaning                                                                | Source               |
| ----- | ---------------------------------------------------------------------- | -------------------- |
| `0`   | success / affirmative                                                  |                      |
| `1`   | negative answer (`confirm`), nothing selected, no tty, any other error |                      |
| `124` | `--timeout` elapsed; prints `timed out` on stderr                      | `exit.StatusTimeout` |
| `130` | user aborted (`ctrl+c`, `esc`)                                         | `exit.StatusAborted` |
| *n*   | `gum spin` propagates the wrapped command's exit code verbatim         |                      |

⚠ `confirm --timeout` is the exception: it does **not** return 124. It returns `--default`, and
`--default` is **`true`** unless you pass `--default=false`.

### Environment variables

Every flag has an env var; flags win over env. The scheme is
`GUM_<COMMAND>_<FLAG>`, with `.`-style flags flattened: `--cursor.foreground` →
`GUM_CHOOSE_CURSOR_FOREGROUND`. The exception is `gum style`, whose flags are **unprefixed**
(`$FOREGROUND`, `$BORDER`, `$PADDING`, …) because they are the shared style block itself.

`NO_COLOR=1` disables colour and beats `CLICOLOR_FORCE=1`. `CLICOLOR_FORCE=1` forces colour into a
pipe. `FORCE_COLOR` is **not** honoured.

### Shared value formats

| Value            | Format                                                                                                                                                                                 |
| ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Colour           | ANSI `0`–`15`, ANSI256 `0`–`255`, or hex `"#6cb6fa"`. Adaptive/light-dark pairs are not supported.                                                                                     |
| Padding / margin | 1, 2 or 4 space-separated ints — `"1"` = all sides, `"1 2"` = vertical horizontal, `"1 2 3 4"` = top right bottom left. ⚠ **3 tokens, or any non-integer, silently yields `0 0 0 0`.** |
| Duration         | Go duration string — `500ms`, `5s`, `2m`. `0s` disables the timeout.                                                                                                                   |

### Enum catalogue

| Enum                    | Values                                                                                                                |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------- |
| `--border` (style)      | `none` `hidden` `normal` `rounded` `thick` `double` — default `none`                                                  |
| `--border` (table)      | same set — default `rounded`                                                                                          |
| `--align` (style, join) | `left` `center` `right` `bottom` `middle` `top`                                                                       |
| `--align` (spin)        | `left` `right`                                                                                                        |
| `--spinner`             | `line` `dot` `minidot` `jump` `pulse` `points` `globe` `moon` `monkey` `meter` `hamburger`                            |
| `--cursor.mode`         | `blink` `hide` `static`                                                                                               |
| `--level` (log)         | `none` `debug` `info` `warn` `error` `fatal`                                                                          |
| `--formatter` (log)     | `text` `logfmt` `json`                                                                                                |
| `-t/--type` (format)    | `markdown` `template` `code` `emoji`                                                                                  |
| `--theme` (format)      | `pink` (default) `ascii` `auto` `dark` `dracula` `light` `notty` `tokyo-night`, **or a path to a glamour JSON style** |

### The shared style block

Most commands embed one or more copies of the same style struct, namespaced by a prefix. Wherever
the tables below say **style keys**, each key `K` gives you `--K.foreground` and `--K.background`.
`gum style` exposes the block unnamespaced and in full:

`--foreground --background --border --border-foreground --border-background --align --width --height
--margin --padding --bold --faint --italic --strikethrough --underline`

---

## 2. `gum choose` — pick from a fixed list

```text
gum choose [<options>...]
cat list.txt | gum choose
```

| Flag                  | Default     | Env                                                                  |
| --------------------- | ----------- | -------------------------------------------------------------------- |
| `--limit`             | `1`         |                                                                      |
| `--no-limit`          |             |                                                                      |
| `--select-if-one`     |             | auto-return when only one option exists                              |
| `--ordered`           |             | keep the list's order in multi-select output ($`GUM_CHOOSE_ORDERED`) |
| `--height`            | `10`        | `GUM_CHOOSE_HEIGHT`                                                  |
| `--header`            | `"Choose:"` | `GUM_CHOOSE_HEADER`                                                  |
| `--cursor`            | `"> "`      | `GUM_CHOOSE_CURSOR`                                                  |
| `--cursor-prefix`     | `"• "`      | `GUM_CHOOSE_CURSOR_PREFIX`                                           |
| `--selected-prefix`   | `"✓ "`      | `GUM_CHOOSE_SELECTED_PREFIX`                                         |
| `--unselected-prefix` | `"• "`      | `GUM_CHOOSE_UNSELECTED_PREFIX`                                       |
| `--selected`          |             | pre-select; `*` selects all (`GUM_CHOOSE_SELECTED`)                  |
| `--label-delimiter`   | `""`        | split each option as `label:value`, display label, print value       |
| `--input-delimiter`   | `"\n"`      | `GUM_CHOOSE_INPUT_DELIMITER`                                         |
| `--output-delimiter`  | `"\n"`      | `GUM_CHOOSE_OUTPUT_DELIMITER`                                        |
| `--[no-]strip-ansi`   |             | `GUM_CHOOSE_STRIP_ANSI`                                              |
| `--[no-]show-help`    | on          | `GUM_CHOOSE_SHOW_HELP`                                               |
| `--timeout`           | `0s`        | `GUM_CHOOSE_TIMEOUT`                                                 |
| `--padding`           | `"0 0"`     | `GUM_CHOOSE_PADDING`                                                 |

Style keys: `cursor` (fg `212`), `header` (fg `99`), `item`, `selected` (fg `212`).

The three prefix flags are hidden when `--limit 1`. Keys: `↑/↓/j/k` navigate, `tab`/`ctrl+space`
toggle in multi-select, `enter` submit, `esc`/`ctrl+c` abort (130).

---

## 3. `gum filter` — fuzzy-search a list

```text
gum filter [<options>...]
cat list.txt | gum filter
```

Same selection model as `choose` plus a search field.

| Flag                                                              | Default       | Env                                                                         |
| ----------------------------------------------------------------- | ------------- | --------------------------------------------------------------------------- |
| `--limit` / `--no-limit` / `--select-if-one`                      | `1`           |                                                                             |
| `--[no-]strict`                                                   | on            | with `--strict`, return nothing if no item matched instead of the raw query |
| `--[no-]fuzzy`                                                    | on            | off = match from start of word (`GUM_FILTER_FUZZY`)                         |
| `--[no-]fuzzy-sort`                                               | on            | sort by fuzzy score (`GUM_FILTER_FUZZY_SORT`)                               |
| `--placeholder`                                                   | `"Filter..."` | `GUM_FILTER_PLACEHOLDER`                                                    |
| `--prompt`                                                        | `"> "`        | `GUM_FILTER_PROMPT`                                                         |
| `--indicator`                                                     | `"•"`         | `GUM_FILTER_INDICATOR`                                                      |
| `--selected-prefix`                                               | `" ◉ "`       | `GUM_FILTER_SELECTED_PREFIX`                                                |
| `--unselected-prefix`                                             | `" ○ "`       | `GUM_FILTER_UNSELECTED_PREFIX`                                              |
| `--selected`                                                      |               | pre-select, `*` for all                                                     |
| `--header`                                                        | `""`          | `GUM_FILTER_HEADER`                                                         |
| `--value`                                                         | `""`          | initial query (`GUM_FILTER_VALUE`)                                          |
| `--width` / `--height`                                            | `0` / `0`     | 0 = auto                                                                    |
| `--reverse`                                                       |               | draw from the bottom (`GUM_FILTER_REVERSE`)                                 |
| `--input-delimiter` / `--output-delimiter`                        | `"\n"`        |                                                                             |
| `--[no-]strip-ansi`, `--[no-]show-help`, `--timeout`, `--padding` |               |                                                                             |

Style keys: `indicator` (fg `212`), `selected-indicator` (fg `212`, env `…SELECTED_PREFIX_…`),
`unselected-prefix` (fg `240`), `header` (fg `99`), `text`, `cursor-text`, `match` (fg `212`),
`prompt` (fg `240`), `placeholder` (fg `240`).

`choose` vs `filter`: **`choose` for a short known set, `filter` for anything long or unbounded.**

---

## 4. `gum confirm` — yes/no gate

```text
gum confirm [<prompt>]     # default prompt: "Are you sure?"
```

| Flag               | Default    | Notes                                                                                                |
| ------------------ | ---------- | ---------------------------------------------------------------------------------------------------- |
| `--default`        | **`true`** | ⚠ the pre-selected answer *and* the timeout answer. Pass `--default=false` for anything destructive. |
| `--affirmative`    | `"Yes"`    |                                                                                                      |
| `--negative`       | `"No"`     |                                                                                                      |
| `--show-output`    | off        | echo `<prompt> <answer>` to **stdout**                                                               |
| `--[no-]show-help` | on         | `GUM_CONFIRM_SHOW_HELP`                                                                              |
| `--timeout`        | `0s`       | returns `--default`, **not** 124 (`GUM_CONFIRM_TIMEOUT`)                                             |
| `--padding`        | `"0 0"`    |                                                                                                      |

Style keys: `prompt` (fg `#7571F9`, bold), `selected` (fg `230` on `212`), `unselected` (fg `254` on
`235`).

⚠ **Non-interactive short-circuit.** If stdin is a pipe, `confirm` reads one line *before* touching
the tty: `yes`/`y` → exit 0, anything else → exit 1, no prompt drawn. That is the supported way to
pre-answer in CI (`echo y | gum confirm`), and the reason a stray pipe can silently auto-decline.

---

## 5. `gum input` — one-line prompt

```text
gum input [flags]
```

| Flag                                                              | Default               | Env                                    |
| ----------------------------------------------------------------- | --------------------- | -------------------------------------- |
| `--placeholder`                                                   | `"Type something..."` | `GUM_INPUT_PLACEHOLDER`                |
| `--prompt`                                                        | `"> "`                | `GUM_INPUT_PROMPT`                     |
| `--header`                                                        | `""`                  | `GUM_INPUT_HEADER`                     |
| `--value`                                                         | `""`                  | initial text; also accepted on stdin   |
| `--password`                                                      |                       | mask characters                        |
| `--char-limit`                                                    | `400`                 | `0` = unlimited                        |
| `--width`                                                         | `0`                   | 0 = terminal width (`GUM_INPUT_WIDTH`) |
| `--cursor.mode`                                                   | `blink`               | `GUM_INPUT_CURSOR_MODE`                |
| `--[no-]show-help`, `--[no-]strip-ansi`, `--timeout`, `--padding` |                       |                                        |

Style keys: `prompt`, `placeholder` (fg `240`), `cursor` (fg `212`), `header` (fg `240`).

---

## 6. `gum write` — multi-line prompt

`ctrl+d` submits; `esc`/`ctrl+c` aborts (130).

| Flag                                                                               | Default                | Env                                            |
| ---------------------------------------------------------------------------------- | ---------------------- | ---------------------------------------------- |
| `--header`                                                                         | `""`                   | `GUM_WRITE_HEADER`                             |
| `--placeholder`                                                                    | `"Write something..."` | `GUM_WRITE_PLACEHOLDER`                        |
| `--prompt`                                                                         | `"┃ "`                 | `GUM_WRITE_PROMPT`                             |
| `--width`                                                                          | `0`                    | 0 = terminal width                             |
| `--height`                                                                         | `5`                    | `GUM_WRITE_HEIGHT`                             |
| `--value`                                                                          | `""`                   | initial text, or via stdin (`GUM_WRITE_VALUE`) |
| `--char-limit` / `--max-lines`                                                     | `0` / `0`              | 0 = unlimited                                  |
| `--show-cursor-line` / `--show-line-numbers`                                       | off                    |                                                |
| `--cursor.mode`, `--[no-]show-help`, `--[no-]strip-ansi`, `--timeout`, `--padding` |                        |                                                |

Style keys: `base`, `cursor` (fg `212`), `cursor-line`, `cursor-line-number` (fg `7`), `line-number`
(fg `7`), `end-of-buffer` (fg `0`), `header` (fg `240`), `placeholder` (fg `240`), `prompt` (fg
`7`).

---

## 7. `gum file` — file/directory picker

```text
gum file [<path>]        # $GUM_FILE_PATH; default cwd
```

| Flag                                         | Default | Env                                                           |
| -------------------------------------------- | ------- | ------------------------------------------------------------- |
| `-a, --all`                                  | off     | show dotfiles (`GUM_FILE_ALL`)                                |
| `--file` / `--directory`                     |         | what is selectable; pass `--directory` alone to pick a folder |
| `-c, --cursor`                               | `">"`   | `GUM_FILE_CURSOR`                                             |
| `-p, --[no-]permissions`                     |         | `GUM_FILE_PERMISSION`                                         |
| `-s, --[no-]size`                            |         | `GUM_FILE_SIZE`                                               |
| `--header`                                   | `""`    | `GUM_FILE_HEADER`                                             |
| `--height`                                   | `10`    | `GUM_FILE_HEIGHT`                                             |
| `--[no-]show-help`, `--timeout`, `--padding` |         |                                                               |

Style keys: `cursor` (fg `212`), `symlink` (fg `36`), `directory` (fg `99`), `file`, `permissions`
(fg `244`), `selected` (fg `212`), `file-size` (fg `240`), `header` (fg `99`).

---

## 8. `gum table` — render or select from tabular data

```text
gum table < data.csv                 # interactive row selection → stdout
gum table --print < data.csv         # static render, no tty needed
gum table -f data.csv -r 1           # return column 1 instead of the whole row
```

| Flag                                                              | Default   | Notes                                                    |
| ----------------------------------------------------------------- | --------- | -------------------------------------------------------- |
| `-s, --separator`                                                 | `","`     | input field separator                                    |
| `-c, --columns`                                                   |           | header names when the data has none                      |
| `-w, --widths`                                                    |           | ⚠ ignored in `--print` mode; columns are auto-sized      |
| `--height`                                                        | `0`       |                                                          |
| `-p, --print`                                                     | off       | static render — the one gum renderer that needs no tty   |
| `-f, --file`                                                      |           | read from a path instead of stdin                        |
| `-b, --border`                                                    | `rounded` |                                                          |
| `-r, --return-column`                                             | `0`       | 1-based column to print; 0 = whole row                   |
| `--lazy-quotes`                                                   | off       | tolerate malformed CSV quoting (`GUM_TABLE_LAZY_QUOTES`) |
| `--fields-per-record`                                             | `0`       | expected field count (`GUM_TABLE_FIELDS_PER_RECORD`)     |
| `--[no-]show-help`, `--[no-]hide-count`, `--timeout`, `--padding` |           |                                                          |

Style keys: `border`, `cell`, `header`, `selected` (fg `212`).

---

## 9. `gum pager` — scrollable viewport

```text
gum pager < README.md
gum pager "$(some-command)"
```

| Flag                  | Default                    |
| --------------------- | -------------------------- |
| `--show-line-numbers` | off                        |
| `--[no-]soft-wrap`    |                            |
| `--timeout`           | `0s` (`GUM_PAGER_TIMEOUT`) |

Style keys: the pager itself (`--foreground`/`--background`), `line-number` (fg `237`), `match`
(fg `212`), `match-highlight` (fg `235` on `225`), `help` (fg `241`).

`/` searches. This is a viewer, not a `$PAGER` replacement — `less` is still `$PAGER` here.

---

## 10. `gum spin` — spinner around a command

```text
gum spin --title "Fetching…" -- git fetch --all
```

| Flag                              | Default        | Env                                            |
| --------------------------------- | -------------- | ---------------------------------------------- |
| `--title`                         | `"Loading..."` | `GUM_SPIN_TITLE`                               |
| `-s, --spinner`                   | `dot`          | `GUM_SPIN_SPINNER`                             |
| `-a, --align`                     | `left`         | `left`\|`right` (`GUM_SPIN_ALIGN`)             |
| `--show-output`                   | off            | stdout **and** stderr (`GUM_SPIN_SHOW_OUTPUT`) |
| `--show-stdout` / `--show-stderr` | off            | one stream each                                |
| `--show-error`                    | off            | dump combined output only if the command fails |
| `--timeout`                       | `0s`           | `GUM_SPIN_TIMEOUT`                             |
| `--padding`                       | `"0 0"`        |                                                |

Style keys: `spinner` (fg `212`), `title`.

Exit code is the wrapped command's. `ctrl+c` sends **SIGINT to the child**, then aborts.

⚠ **`--show-*` only matters when stdout is a tty.** Interactively, gum runs the command under a pty
and buffers its output, replaying it afterwards only if a `--show-*` flag asked for it. When stdout
is *not* a tty the child inherits gum's stdout/stderr directly, so output always passes through and
the `--show-*` flags become no-ops. Practical consequence: `out=$(gum spin -- cmd)` captures `cmd`'s
output with or without `--show-output`, and `--show-error` shows nothing in that mode because the
buffer is empty.

⚠ `--` before the command is required whenever the command has its own flags.

---

## 11. `gum style` — box, colour and space text

```text
gum style --border double --align center --width 40 --padding "1 2" 'Line one' 'Line two'
```

Each positional argument becomes a **line**. Takes the full style block (§1). No tty needed.

| Flag                                                  | Default | Env                                              |
| ----------------------------------------------------- | ------- | ------------------------------------------------ |
| `--foreground` / `--background`                       | `""`    | `$FOREGROUND` / `$BACKGROUND`                    |
| `--border`                                            | `none`  | `$BORDER`                                        |
| `--border-foreground` / `--border-background`         | `""`    | `$BORDER_FOREGROUND` / `$BORDER_BACKGROUND`      |
| `--align`                                             | `left`  | `$ALIGN`                                         |
| `--width` / `--height`                                | `0`     | `$WIDTH` / `$HEIGHT`                             |
| `--margin` / `--padding`                              | `"0 0"` | `$MARGIN` / `$PADDING`                           |
| `--bold --faint --italic --underline --strikethrough` | off     | `$BOLD` etc.                                     |
| `--trim`                                              | off     | strip leading/trailing whitespace per input line |
| `--[no-]strip-ansi`                                   |         | `GUM_STYLE_STRIP_ANSI`                           |

⚠ The unprefixed env vars are global. Exporting `BORDER=double` changes every `gum style` call in
the shell — and nothing else, since other commands namespace their style flags.

---

## 12. `gum join` — compose blocks

```text
gum join --horizontal "$LEFT" "$RIGHT"
gum join --vertical --align center "$TOP" "$BOTTOM"
```

`--horizontal` | `--vertical` (default horizontal) and `--align` (see §1). Always **quote** the
arguments — unquoted, the newlines inside a `gum style` block collapse and the layout breaks.

---

## 13. `gum format` — markdown, templates, code, emoji

```text
gum format -- "# Title" "- one" "- two"       # markdown (default)
cat main.go | gum format -t code -l go        # syntax highlight
echo '{{ Bold "hi" }}' | gum format -t template
echo 'ship it :rocket:' | gum format -t emoji
```

| Flag                | Default    | Env                                                                 |
| ------------------- | ---------- | ------------------------------------------------------------------- |
| `-t, --type`        | `markdown` | `markdown`\|`template`\|`code`\|`emoji` (`GUM_FORMAT_TYPE`)         |
| `--theme`           | `pink`     | glamour style name **or path to a JSON style** (`GUM_FORMAT_THEME`) |
| `-l, --language`    | `""`       | chroma lexer for `-t code` (`GUM_FORMAT_LANGUAGE`)                  |
| `--[no-]strip-ansi` |            | `GUM_FORMAT_STRIP_ANSI`                                             |

⚠ Use `--` before arguments that begin with `-` or `#`-prefixed markdown that could parse as flags.

`gum format` **is** the glamour surface — glamour is vendored as a library (v0.10.0), and no `glow`
binary is installed on this machine. `--theme` is the only glamour knob gum exposes; `GLAMOUR_STYLE`
is not read.

**Template helpers** (from termenv, available with `-t template`):
`{{ Color "<fg>" "<bg>" "text" }}` (1 or 2 colour args) · `{{ Foreground "<c>" "text" }}` ·
`{{ Background "<c>" "text" }}` · `{{ Bold }}` `{{ Faint }}` `{{ Italic }}` `{{ Underline }}`
`{{ Overline }}` `{{ Blink }}` `{{ Reverse }}` `{{ CrossOut }}`. They degrade to no-ops when the
colour profile is ASCII.

---

## 14. `gum log` — levelled, styled logging

```text
gum log --level info "Starting"
gum log --structured --level error "Upload failed" file report.pdf retries 3
```

| Flag               | Default | Notes                                                            |
| ------------------ | ------- | ---------------------------------------------------------------- |
| `-l, --level`      | `none`  | `none debug info warn error fatal`                               |
| `--min-level`      | `""`    | suppress below this level — `$GUM_LOG_LEVEL`                     |
| `-s, --structured` | off     | trailing args become `key=value` pairs                           |
| `--formatter`      | `text`  | `text` `logfmt` `json`                                           |
| `-t, --time`       | `""`    | Go time layout or a name: `kitchen` `ansic` `rfc822` `rfc3339` … |
| `--prefix`         |         | printed before the message                                       |
| `-f, --format`     | off     | treat the first arg as a `printf` format string                  |
| `-o, --file`       |         | append to a file instead                                         |

Style keys: `level`, `time`, `prefix`, `message`, `key`, `value`, `separator`.

⚠ **`gum log` writes to stderr**, so it never pollutes a captured stdout — use it freely inside
`$(...)`-style helpers.
⚠ **Without `--structured`, trailing args are appended to the message**, even with the `json`
formatter: `gum log --formatter json --level warn msg k v` → `{"level":"warn","msg":"msg k v"}`.
Adding `--structured` gives `{"level":"warn","msg":"msg","k":"v"}`.
⚠ `--level fatal` styles the line as fatal; it does **not** exit for you.

---

## 15. `gum version-check` — guard a script against an old gum

```text
gum version-check '>= 0.16' || { echo "gum too old"; exit 1; }
```

Semver constraint as the sole argument. Exit 0 if satisfied, 1 with an explanatory line on stderr
otherwise. Use it at the top of any script that relies on a flag added recently.
