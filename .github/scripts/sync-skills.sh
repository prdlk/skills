#!/usr/bin/env bash
# Replace each skill listed in .github/skill-sources.json with the latest copy
# from its upstream repository, and record the upstream commit it came from.
#
# Usage: .github/scripts/sync-skills.sh [skill...]   (default: every listed skill)
#
# Manifest entry: "<name>": { "repo": "owner/repo", "path": "dir/in/repo", "ref": "branch, tag, or commit" }
# `ref` is optional (default: the repo's default branch); a full commit SHA pins
# a skill that upstream has since removed. `path` may be "." for a repo whose
# root is the skill. `commit` is written by this script.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
manifest="$root/.github/skill-sources.json"
skills_dir="$root/.github/skills"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if (($#)); then
  selected=$(printf '%s\n' "$@" | jq -R . | jq -s .)
else
  selected=$(jq '.skills | keys' "$manifest")
fi
unknown=$(jq -r --argjson sel "$selected" '$sel - (.skills | keys) | .[]' "$manifest")
if [[ -n $unknown ]]; then
  echo "Not in $manifest: $unknown" >&2
  exit 2
fi

failed=()

# Frontmatter `name:` of a SKILL.md.
skill_name() {
  awk 'NR == 1 { if ($0 != "---") exit; next }
       $0 == "---" { exit }
       sub(/^name:[ \t]*/, "") { gsub(/["\047\r]/, ""); print; exit }' "$1"
}

# Copy a skill directory, dereferencing symlinks, without upstream git metadata.
copy_skill() {
  mkdir -p "$2" &&
    tar -C "$1" --exclude=./.git -chf - . | tar -C "$2" -xf -
}

# Upstream path patterns that dangling symlinks under the given checkout paths point to.
missing_link_targets() {
  local dir=$1 link target
  shift
  for p in "$@"; do
    find "$dir/$p" -type l -print0
  done | while IFS= read -r -d '' link; do
    target=$(realpath -m --relative-to="$dir" "$(dirname "$link")/$(readlink "$link")")
    [[ -e $dir/$target || $target == ../* || $target == .. ]] || printf '/%s\n' "$target"
  done | sort -u
}

while IFS=$'\t' read -r repo ref <&3; do
  mapfile -t names < <(jq -r --arg repo "$repo" --arg ref "$ref" --argjson sel "$selected" '
    .skills | to_entries[]
    | select(.value.repo == $repo and (.value.ref // "") == $ref and (.key | IN($sel[])))
    | .key' "$manifest")
  mapfile -t paths < <(jq -r --argjson names "$(printf '%s\n' "${names[@]}" | jq -R . | jq -s .)" \
    '.skills[$names[]].path' "$manifest")

  echo "::group::$repo${ref:+@$ref} (${names[*]})"
  dir=$(mktemp -d "$work/repo.XXXXXX")
  if ! git init --quiet "$dir" ||
    ! git -C "$dir" remote add origin "https://github.com/$repo.git" ||
    ! git -C "$dir" fetch --quiet --depth 1 --filter=blob:none origin "${ref:-HEAD}"; then
    echo "::error::Could not fetch $repo${ref:+ at $ref}"
    failed+=("${names[@]}")
    echo "::endgroup::"
    continue
  fi

  # Check out only the skill directories, plus whatever their symlinks point at.
  if [[ " ${paths[*]} " == *" . "* ]]; then
    git -C "$dir" checkout --quiet --detach FETCH_HEAD
  else
    patterns=()
    for p in "${paths[@]}"; do patterns+=("/$p/"); done
    git -C "$dir" sparse-checkout set --no-cone "${patterns[@]}"
    git -C "$dir" checkout --quiet --detach FETCH_HEAD
    for _ in 1 2 3 4 5; do
      mapfile -t extra < <(missing_link_targets "$dir" "${paths[@]}")
      ((${#extra[@]})) || break
      patterns+=("${extra[@]}")
      git -C "$dir" sparse-checkout set --no-cone "${patterns[@]}"
    done
  fi
  commit=$(git -C "$dir" rev-parse HEAD)

  for i in "${!names[@]}"; do
    name=${names[i]} src="$dir/${paths[i]}" stage="$work/stage/${names[i]}" dest="$skills_dir/${names[i]}"
    if [[ ! -f $src/SKILL.md ]]; then
      echo "::error::$name: $repo has no SKILL.md at ${paths[i]}"
      failed+=("$name")
      continue
    fi
    if ! copy_skill "$src" "$stage"; then
      echo "::error::$name: could not copy $repo/${paths[i]}"
      failed+=("$name")
      continue
    fi
    upstream_name=$(skill_name "$stage/SKILL.md")
    if [[ $upstream_name != "$name" ]]; then
      echo "::error::$name: upstream SKILL.md is named '$upstream_name'"
      failed+=("$name")
      continue
    fi
    rm -rf "$dest"
    mv "$stage" "$dest"

    recorded=$(jq -r --arg n "$name" '.skills[$n].commit // ""' "$manifest")
    if [[ -n $(git -C "$root" status --porcelain -- "$dest") || -z $recorded ]]; then
      jq --arg n "$name" --arg c "$commit" '.skills[$n].commit = $c' "$manifest" >"$work/manifest.json"
      mv "$work/manifest.json" "$manifest"
      echo "updated $name -> $repo@${commit:0:12}"
    else
      echo "unchanged $name"
    fi
  done
  echo "::endgroup::"
done 3< <(jq -r --argjson sel "$selected" '
  [.skills | to_entries[] | select(.key | IN($sel[])) | [.value.repo, (.value.ref // "")]]
  | unique[] | @tsv' "$manifest")

if ((${#failed[@]})); then
  echo "Failed to sync: ${failed[*]}" >&2
  exit 1
fi
