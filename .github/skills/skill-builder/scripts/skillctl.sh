#!/usr/bin/env bash
# Check, validate, and link skills in the prdlk/skills repository.
#
# Usage: skillctl.sh check-name <name>   name is valid and unused in the repo, manifest, and link dirs
#        skillctl.sh validate <name>     .github/skills/<name> and its omp companions are well-formed
#        skillctl.sh link <name>         symlink the skill and its omp companions into this machine
#
# Repository: $SKILLS_REPO, else the prdlk/skills checkout containing the working
# directory, else the checkout this script lives in (never a plugin cache).
# Skill link dirs: <omp agent dir>/skills (wins over the plugin's cached copy),
# ~/.agents/skills (Codex, opencode, Gemini CLI, ...), ~/.claude/skills (Claude Code);
# override with SKILL_LINK_DIRS="dir:dir". omp companions inside the skill are linked
# into the omp agent dir: agents/<agent>.md -> agents/, tools/<tool>/ -> tools/.
set -euo pipefail

usage() { sed -n '2,14s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; }
die() { echo "skillctl: $*" >&2; exit 1; }

is_repo() { [[ -d $1/.github/skills && -f $1/.github/skill-sources.json && $1 != */plugins/cache/* ]]; }

find_repo() {
  local top
  if [[ -n ${SKILLS_REPO:-} ]]; then
    is_repo "$SKILLS_REPO" || die "SKILLS_REPO=$SKILLS_REPO is not a prdlk/skills checkout"
    echo "$SKILLS_REPO"
    return
  fi
  if top=$(git rev-parse --show-toplevel 2>/dev/null) && is_repo "$top"; then
    echo "$top"
    return
  fi
  top=$(cd "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../../../.." && pwd)
  is_repo "$top" || die "no prdlk/skills checkout found; cd into one or set SKILLS_REPO"
  echo "$top"
}

repo=$(find_repo)
manifest=$repo/.github/skill-sources.json
omp_dir=$(omp config path 2>/dev/null || echo "$HOME/.omp/agent")
IFS=: read -ra link_dirs <<<"${SKILL_LINK_DIRS:-$omp_dir/skills:$HOME/.agents/skills:$HOME/.claude/skills}"

# Value of a top-level frontmatter key in a Markdown file.
frontmatter() {
  awk -v key="$2" 'NR == 1 { if ($0 != "---") exit; next }
       $0 == "---" { exit }
       index($0, key ":") == 1 { sub(/^[^:]*:[ \t]*/, ""); gsub(/^["\047]|["\047]$/, ""); print; exit }' "$1"
}

in_manifest() { jq -e --arg n "$1" '.skills | has($n)' "$manifest" >/dev/null; }

# "<source>\t<dest>" for each omp companion of a skill directory.
companions() {
  local dir=$1 f
  for f in "$dir"/agents/*.md; do
    [[ -f $f ]] && printf '%s\t%s\n' "$f" "$omp_dir/agents/${f##*/}"
  done
  for f in "$dir"/tools/*/; do
    [[ -d $f ]] && f=${f%/} && printf '%s\t%s\n' "$f" "$omp_dir/tools/${f##*/}"
  done
  return 0
}

check_name() {
  local name=$1 d
  [[ $name =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || die "'$name' is not kebab-case (a-z, 0-9, single hyphens)"
  ((${#name} <= 64)) || die "'$name' is longer than 64 characters"
  [[ ! -e $repo/.github/skills/$name ]] || die "$repo/.github/skills/$name already exists"
  ! in_manifest "$name" || die "'$name' is a vendored skill in $manifest"
  for d in "${link_dirs[@]}"; do
    [[ ! -e $d/$name && ! -L $d/$name ]] || die "$d/$name is already installed"
  done
  echo "ok: '$name' is available"
}

validate() {
  local name=$1 dir=$repo/.github/skills/$1 errors=0 md desc link target f lines
  err() { echo "error: $*" >&2; errors=$((errors + 1)); }
  [[ -f $dir/SKILL.md ]] || die "no SKILL.md in $dir"
  md=$dir/SKILL.md

  [[ $(head -1 "$md") == --- ]] || err "SKILL.md must start with a --- frontmatter block"
  [[ $(frontmatter "$md" name) == "$name" ]] || err "frontmatter name must be '$name'"
  desc=$(frontmatter "$md" description)
  if [[ -z $desc || $desc == [\>\|]* ]]; then
    err "frontmatter description must be a non-empty single line"
  elif ((${#desc} > 1024)); then
    err "description is ${#desc} characters (max 1024)"
  fi
  ! in_manifest "$name" || err "'$name' is listed in $manifest; the sync workflow would overwrite it"

  while IFS= read -r -d '' f; do
    while IFS= read -r link; do
      target=${link%%#*}
      [[ -z $target || $target =~ ^[a-z]+: ]] && continue
      [[ -e $(dirname "$f")/$target ]] || err "${f#"$dir"/}: broken link '$link'"
    done < <(grep -o '](\([^)]*\))' "$f" | sed 's/^](//; s/)$//; s/ .*//')
  done < <(find "$dir" -name '*.md' -print0)

  while IFS= read -r f; do
    err "user-specific path: $f"
  done < <(grep -rnE '/home/[a-z_][a-z0-9_-]*/|/Users/[A-Za-z]' "$dir" | sed "s|^$dir/||")

  if [[ -d $dir/scripts ]]; then
    while IFS= read -r -d '' f; do
      err "${f#"$dir"/} is not executable"
    done < <(find "$dir/scripts" -type f ! -perm -u+x -print0)
  fi

  for f in "$dir"/agents/*.md; do
    [[ -f $f ]] || continue
    [[ $(frontmatter "$f" name) == "$(basename "$f" .md)" ]] ||
      err "${f#"$dir"/}: frontmatter name must be '$(basename "$f" .md)'"
    [[ -n $(frontmatter "$f" description) ]] || err "${f#"$dir"/}: frontmatter description is required"
  done
  for f in "$dir"/tools/*/; do
    [[ -d $f ]] || continue
    [[ -f $f/index.ts || -f $f/index.js ]] || err "${f#"$dir"/}: needs index.ts or index.js"
  done

  lines=$(wc -l <"$md")
  ((lines <= 500)) || echo "warning: SKILL.md is $lines lines; move detail into references/" >&2

  ((errors == 0)) || die "$errors problem(s) in $dir"
  echo "ok: $dir is valid"
}

# Symlink $1 at $2 unless something else already occupies $2.
link_one() {
  local src=$1 dest=$2
  if [[ -L $dest && $(realpath "$dest") == "$(realpath "$src")" ]]; then
    echo "already linked: $dest"
  elif [[ -e $dest || -L $dest ]]; then
    echo "skipped: $dest exists and is not a link to $src" >&2
    return 1
  else
    mkdir -p "$(dirname "$dest")"
    ln -s "$src" "$dest"
    echo "linked: $dest -> $src"
  fi
}

link() {
  local name=$1 src=$repo/.github/skills/$1 d c dest status=0
  [[ -f $src/SKILL.md ]] || die "no SKILL.md in $src"
  for d in "${link_dirs[@]}"; do
    link_one "$src" "$d/$name" || status=1
  done
  while IFS=$'\t' read -r c dest; do
    link_one "$c" "$dest" || status=1
  done < <(companions "$src")
  return "$status"
}

case ${1:-} in
check-name | validate | link)
  (($# == 2)) || { usage >&2; exit 2; }
  "${1//-/_}" "$2"
  ;;
-h | --help) usage ;;
*) usage >&2; exit 2 ;;
esac
