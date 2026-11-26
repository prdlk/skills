#!/usr/bin/env bash
# Exa fallback for agents without the Exa MCP tools: calls the public Exa MCP endpoint.
#
# Usage: exa.sh fetch <url>...                         page content as markdown
#        exa.sh search <query> <objective> [results]   ranked results with highlights
#
# EXA_MAX_CHARACTERS caps each fetched page (default 20000); EXA_MCP_URL overrides
# the endpoint (default https://mcp.exa.ai/mcp). Needs curl and jq.
set -euo pipefail

usage() { sed -n '2,9s/^# \{0,1\}//p' "${BASH_SOURCE[0]}"; }

# Call an Exa MCP tool and print its text content.
call() {
  local body
  body=$(jq -nc --arg t "$1" --argjson a "$2" \
    '{jsonrpc: "2.0", id: 1, method: "tools/call", params: {name: $t, arguments: $a}}')
  curl -fsS -X POST "${EXA_MCP_URL:-https://mcp.exa.ai/mcp}" \
    -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' \
    -d "$body" |
    sed -n 's/^data: //p; t; /^{/p' |
    jq -r 'if .error then ("exa: \(.error.message)\n" | halt_error(1))
           elif .result.isError then ("exa: \([.result.content[].text] | join(" "))\n" | halt_error(1))
           else .result.content[].text end'
}

case ${1:-} in
fetch)
  shift
  (($#)) || { usage >&2; exit 2; }
  call web_fetch_exa "$(jq -nc --argjson n "${EXA_MAX_CHARACTERS:-20000}" \
    '{urls: $ARGS.positional, maxCharacters: $n}' --args "$@")"
  ;;
search)
  (($# >= 3)) || { usage >&2; exit 2; }
  call web_search_exa "$(jq -nc --arg q "$2" --arg o "$3" --argjson n "${4:-8}" \
    '{query: $q, objective: $o, numResults: $n}')"
  ;;
-h | --help) usage ;;
*) usage >&2; exit 2 ;;
esac
