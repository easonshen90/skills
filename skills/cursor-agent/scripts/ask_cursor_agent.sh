#!/usr/bin/env bash
# Host-agnostic wrapper around Cursor Agent headless CLI (`agent -p`).
# Parses official stream-json NDJSON; writes a compact Markdown handoff.
# Docs: https://cursor.com/docs/cli/headless
#       https://cursor.com/docs/cli/reference/output-format
set -euo pipefail

DEFAULT_MODEL="cursor-grok-4.5-high-fast"

usage() {
  cat <<'USAGE'
Usage:
  ask_cursor_agent.sh <task> [options]
  ask_cursor_agent.sh -t <task> [options]

Task input:
  First positional argument is the task text
  -t, --task <text>     Alias for positional task
  (stdin)               Pipe task text via stdin if no arg/flag is given

Context (optional, repeatable):
  -f, --file <path>     Priority file or media path hint (added to prompt)
  --add-dir <path>      Additional workspace directory for the agent

Multi-turn:
  --session <id>        Resume a previous session (--resume)

Options:
  -w, --workspace <dir> Workspace directory (default: current directory)
  --model <id>          Model override (default: cursor-grok-4.5-high-fast)
  --mode <plan|ask>     Read-only plan or ask mode
  --yolo / --force      Allow file edits (default: on)
  --no-yolo / --no-force  Propose only; do not apply edits
  --trust               Trust workspace without prompting (default: on)
  --no-trust            Disable --trust
  --worktree [name]     Run in an isolated git worktree
  -o, --output <path>   Markdown output path
  -h, --help            Show this help

Output (on success):
  session_id=<id>       Use with --session for a follow-up
  output_path=<path>    Absolute path to the Markdown result
  elapsed=<seconds>s

Defaults:
  --yolo --trust --model cursor-grok-4.5-high-fast
  --output-format stream-json --stream-partial-output

Notes:
  Binary: prefers `agent`, falls back to `cursor-agent`.
  Auth: CURSOR_API_KEY or `agent login`. See `agent about` / `agent status`.
USAGE
}

fail() {
  echo "[ERROR] $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

require_value() {
  local option="$1" value="${2:-}"
  [[ -n "$value" ]] || fail "Missing value for $option"
}

trim_whitespace() {
  awk 'BEGIN { RS=""; ORS="" } { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, ""); print }' <<<"$1"
}

to_absolute() {
  local base="$1" target="$2" parent
  if [[ "$target" != /* ]]; then
    target="$base/$target"
  fi
  if [[ -e "$target" ]]; then
    parent="$(cd "$(dirname "$target")" && pwd)"
    printf '%s/%s\n' "$parent" "$(basename "$target")"
  else
    printf '%s\n' "$target"
  fi
}

resolve_hint() {
  local base="$1" raw="$2" cleaned
  cleaned="$(trim_whitespace "$raw")"
  [[ -n "$cleaned" ]] || return 0
  if [[ "$cleaned" =~ ^(.+)#L[0-9]+$ ]]; then cleaned="${BASH_REMATCH[1]}"; fi
  if [[ "$cleaned" =~ ^(.+):[0-9]+(-[0-9]+)?$ ]]; then cleaned="${BASH_REMATCH[1]}"; fi
  to_absolute "$base" "$cleaned"
}

append_file_hints() {
  local raw="$1" item trimmed
  IFS=',' read -r -a split_hints <<<"$raw"
  for item in "${split_hints[@]}"; do
    trimmed="$(trim_whitespace "$item")"
    [[ -n "$trimmed" ]] && file_hints+=("$trimmed")
  done
}

redact_stderr() {
  sed -E \
    -e 's/(Bearer )[A-Za-z0-9._~+\/=:-]+/\1[REDACTED]/g' \
    -e 's/(sk-[A-Za-z0-9_-]{6})[A-Za-z0-9_-]+/\1...[REDACTED]/g' \
    -e 's/(key_[A-Za-z0-9]{6})[A-Za-z0-9]+/\1...[REDACTED]/g' \
    -e 's/((api_key|api-key|CURSOR_API_KEY|access_token|refresh_token|secret)[[:space:]]*[:=][[:space:]]*)[^[:space:]]+/\1[REDACTED]/g'
}

resolve_agent_bin() {
  if command -v agent >/dev/null 2>&1; then
    printf '%s\n' "agent"
  elif command -v cursor-agent >/dev/null 2>&1; then
    printf '%s\n' "cursor-agent"
  else
    return 1
  fi
}

# Progress from official stream-json events (Headless + output-format docs).
print_progress() {
  local line="$1"
  local event_type subtype tool_label preview has_ts has_mc

  event_type="$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null || true)"
  [[ -n "$event_type" ]] || return 0

  case "$event_type" in
    system)
      subtype="$(printf '%s' "$line" | jq -r '.subtype // empty' 2>/dev/null || true)"
      if [[ "$subtype" == "init" ]]; then
        local model_name
        model_name="$(printf '%s' "$line" | jq -r '.model // "unknown"' 2>/dev/null || true)"
        echo "[cursor-agent] model: $model_name" >&2
      fi
      ;;
    tool_call)
      subtype="$(printf '%s' "$line" | jq -r '.subtype // empty' 2>/dev/null || true)"
      [[ "$subtype" == "started" ]] || return 0
      tool_label="$(printf '%s' "$line" | jq -r '
        if .tool_call.writeToolCall then
          "write " + (.tool_call.writeToolCall.args.path // "unknown")
        elif .tool_call.readToolCall then
          "read " + (.tool_call.readToolCall.args.path // "unknown")
        elif .tool_call.function then
          (.tool_call.function.name // "function")
        else
          (.tool_call | keys[0] // "tool")
        end
      ' 2>/dev/null || true)"
      [[ -n "$tool_label" ]] && echo "[cursor-agent] tool: $tool_label" >&2
      ;;
    assistant)
      # Only consume streaming deltas: timestamp_ms present, model_call_id absent.
      has_ts="$(printf '%s' "$line" | jq 'has("timestamp_ms")' 2>/dev/null || echo false)"
      has_mc="$(printf '%s' "$line" | jq 'has("model_call_id")' 2>/dev/null || echo false)"
      if [[ "$has_ts" == "true" && "$has_mc" == "false" ]]; then
        preview="$(printf '%s' "$line" | jq -r '
          [.message.content[]? | select(.type == "text") | .text // empty] | join("")
        ' 2>/dev/null | awk 'NF { print; exit }' | cut -c1-140 || true)"
        [[ -n "$preview" ]] && echo "[cursor-agent] $preview" >&2
      fi
      ;;
  esac
}

workspace="$PWD"
task_text=""
model="$DEFAULT_MODEL"
session_id=""
output_path=""
mode=""
yolo=1
trust=1
worktree=""
worktree_set=0
file_hints=()
add_dirs=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)
      require_value "$1" "${2:-}"; workspace="$2"; shift 2 ;;
    -t|--task)
      require_value "$1" "${2:-}"; task_text="$2"; shift 2 ;;
    -f|--file|--focus)
      require_value "$1" "${2:-}"; append_file_hints "$2"; shift 2 ;;
    --add-dir)
      require_value "$1" "${2:-}"; add_dirs+=("$2"); shift 2 ;;
    --model)
      require_value "$1" "${2:-}"; model="$2"; shift 2 ;;
    --session)
      require_value "$1" "${2:-}"; session_id="$2"; shift 2 ;;
    --mode)
      require_value "$1" "${2:-}"
      case "$2" in
        plan|ask) mode="$2" ;;
        *) fail "Invalid --mode: $2 (expected plan or ask)" ;;
      esac
      shift 2 ;;
    --yolo|--force)
      yolo=1; shift ;;
    --no-yolo|--no-force)
      yolo=0; shift ;;
    --trust)
      trust=1; shift ;;
    --no-trust)
      trust=0; shift ;;
    --worktree)
      worktree_set=1
      if [[ $# -ge 2 && "$2" != -* ]]; then
        worktree="$2"; shift 2
      else
        worktree=""; shift
      fi
      ;;
    -o|--output)
      require_value "$1" "${2:-}"; output_path="$2"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    -*)
      echo "[ERROR] Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)
      if [[ -z "$task_text" ]]; then
        task_text="$1"; shift
      else
        echo "[ERROR] Unexpected argument: $1" >&2; usage >&2; exit 1
      fi ;;
  esac
done

agent_bin="$(resolve_agent_bin)" || fail \
  "Cursor Agent CLI not found (tried: agent, cursor-agent). Install from https://cursor.com/docs/cli/headless then run: agent about / agent login"
require_cmd jq

[[ -d "$workspace" ]] || fail "Workspace does not exist: $workspace"
workspace="$(cd "$workspace" && pwd)"

if [[ -z "$task_text" && ! -t 0 ]]; then
  task_text="$(cat)"
fi
task_text="$(trim_whitespace "$task_text")"
[[ -n "$task_text" ]] || fail "Request text is empty. Pass a positional task, --task, or stdin."

resolved_add_dirs=()
if (( ${#add_dirs[@]} > 0 )); then
  for raw_dir in "${add_dirs[@]}"; do
    resolved_dir="$(to_absolute "$workspace" "$raw_dir")"
    [[ -d "$resolved_dir" ]] || fail "Additional directory does not exist: $resolved_dir"
    resolved_add_dirs+=("$resolved_dir")
  done
fi

file_block=""
if (( ${#file_hints[@]} > 0 )); then
  file_block=$'\nPriority files or media (inspect these first):'
  for hint in "${file_hints[@]}"; do
    resolved_hint="$(resolve_hint "$workspace" "$hint")"
    [[ -n "$resolved_hint" ]] || continue
    existence="missing"
    [[ -e "$resolved_hint" ]] && existence="exists"
    file_block+=$'\n- '"$resolved_hint ($existence)"
  done
fi

prompt="$task_text$file_block"

if [[ -z "$output_path" ]]; then
  timestamp="$(date -u +"%Y%m%d-%H%M%S")"
  skill_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  output_path="$skill_dir/.runtime/${timestamp}-$$.md"
elif [[ "$output_path" != /* ]]; then
  output_path="$workspace/$output_path"
fi
mkdir -p "$(dirname "$output_path")"
output_parent="$(cd "$(dirname "$output_path")" && pwd)"
output_path="$output_parent/$(basename "$output_path")"

cmd=("$agent_bin" -p)
(( yolo )) && cmd+=(--yolo)
(( trust )) && cmd+=(--trust)
cmd+=(--model "$model")
cmd+=(--output-format stream-json --stream-partial-output)
cmd+=(--workspace "$workspace")
[[ -n "$session_id" ]] && cmd+=(--resume "$session_id")
[[ -n "$mode" ]] && cmd+=(--mode "$mode")
if (( worktree_set )); then
  if [[ -n "$worktree" ]]; then
    cmd+=(--worktree "$worktree")
  else
    cmd+=(--worktree)
  fi
fi
if (( ${#resolved_add_dirs[@]} > 0 )); then
  for resolved_dir in "${resolved_add_dirs[@]}"; do
    cmd+=(--add-dir "$resolved_dir")
  done
fi
cmd+=("$prompt")

json_file="$(mktemp)"
stderr_file="$(mktemp)"
trap 'rm -f "$json_file" "$stderr_file"' EXIT

run_agent() {
  "${cmd[@]}"
}

start_seconds=$SECONDS
agent_status=0
set +e
run_agent 2>"$stderr_file" | while IFS= read -r line; do
  line="${line//$'\r'/}"
  [[ -n "$line" ]] || continue
  if printf '%s' "$line" | jq -e . >/dev/null 2>&1; then
    printf '%s\n' "$line" >>"$json_file"
    print_progress "$line"
  else
    echo "[cursor-agent] Ignored non-JSON output from stream-json mode" >&2
  fi
done
agent_status=${PIPESTATUS[0]}
set -e
elapsed=$((SECONDS - start_seconds))

if (( agent_status != 0 )); then
  echo "[ERROR] Cursor Agent command failed (exit $agent_status)" >&2
  echo "[HINT] Check: $agent_bin about | $agent_bin status | $agent_bin login (or CURSOR_API_KEY)" >&2
  if [[ -s "$stderr_file" ]]; then
    tail -n 40 "$stderr_file" | redact_stderr >&2
  fi
  exit "$agent_status"
fi

[[ -s "$json_file" ]] || fail "Cursor Agent returned no JSONL events. Check: $agent_bin about / $agent_bin status / auth."

# Prefer terminal result.session_id; fall back to system.init (official schema).
captured_session_id="$(jq -rs '
  ([.[] | select(.type == "result") | .session_id // empty] | map(select(length > 0)) | last)
  // ([.[] | select(.type == "system" and .subtype == "init") | .session_id // empty] | map(select(length > 0)) | first)
  // ""
' <"$json_file" 2>/dev/null || true)"
[[ -n "$captured_session_id" ]] || captured_session_id="$session_id"

duration_ms="$(jq -rs '
  [.[] | select(.type == "result") | .duration_ms // empty]
  | map(select(. != null and . != ""))
  | last // ""
' <"$json_file" 2>/dev/null || true)"

summary_text="$(jq -rs '
  [.[] | select(.type == "result") | .result // empty]
  | map(select(length > 0))
  | last // ""
' <"$json_file" 2>/dev/null || true)"
[[ -n "$summary_text" ]] || summary_text="(Cursor Agent completed without a terminal result.result.)"

tool_summary="$(jq -rs '
  [
    .[]
    | select(.type == "tool_call" and .subtype == "started")
    | if .tool_call.writeToolCall then "write"
      elif .tool_call.readToolCall then "read"
      elif .tool_call.function then (.tool_call.function.name // "function")
      else (.tool_call | keys[0] // "tool") end
  ]
  | group_by(.)
  | map("- `" + .[0] + "` ×" + (length | tostring))
  | .[]
' <"$json_file" 2>/dev/null || true)"
tool_count="$(jq -rs '
  [.[] | select(.type == "tool_call" and .subtype == "started")] | length
' <"$json_file" 2>/dev/null || true)"
[[ -n "$tool_count" ]] || tool_count=0

{
  printf '## Summary\n\n%s\n\n' "$summary_text"
  [[ -n "$tool_summary" ]] && printf '## Tools used\n\n%s\n\n' "$tool_summary"
  if [[ -n "$duration_ms" ]]; then
    printf -- '---\nelapsed %ss · agent %sms · %s tools\n' "$elapsed" "$duration_ms" "${tool_count:-0}"
  else
    printf -- '---\nelapsed %ss · %s tools\n' "$elapsed" "${tool_count:-0}"
  fi
} >"$output_path"

[[ -n "$captured_session_id" ]] && echo "session_id=$captured_session_id"
echo "output_path=$output_path"
echo "elapsed=${elapsed}s"
