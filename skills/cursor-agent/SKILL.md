---
name: cursor-agent
description: Delegate implementation, review, exploration, and general coding tasks to the local Cursor Agent CLI through a bundled non-interactive headless wrapper. Invoke only when the user explicitly asks to use Cursor Agent, the `agent` CLI, or phrases like "用 Cursor 做", "让 Cursor Agent 执行", or "ask Cursor Agent to...". Use for new or resumed sessions, model selection, priority file or media hints, analysis, and implementation in trusted workspaces. Do not use for ordinary in-IDE work where you are already the Cursor agent (avoid recursive self-delegation).
---

# Cursor Agent

## Core rules

- Use `scripts/ask_cursor_agent.sh` instead of invoking `agent -p` directly. The wrapper captures official `stream-json` NDJSON, streams compact progress, records the session ID, and writes a Markdown result.
- Run the wrapper once per task. After success, read the reported `output_path` and inspect the workspace before deciding whether a follow-up is needed.
- Give the agent the goal, completion criteria, constraints, and non-obvious context. Keep delegated prompts focused, normally under 500 words.
- Pass 1–4 useful entry points with `--file`; the agent can discover the rest. File hints may point to code, images, or other media the agent reads via tools (paths in the prompt are enough).
- Treat this as a general-purpose headless coding Agent (implement / review / explore), not a design-specialist skill.
- Quote paths containing spaces, brackets, or shell metacharacters.
- Do not mention this Skill or its wrapper implementation in the delegated prompt.

## Host compatibility

Use this Skill from any Agent that can load `SKILL.md` instructions and execute a local shell command. The wrapper is host-agnostic: it talks to Cursor Agent through its CLI and does not call a host-specific API. `agents/openai.yaml` is optional metadata for OpenAI hosts; other Agents may ignore it.

## Safety boundary

**Defaults include `--yolo` (`--force`) and model `cursor-grok-4.5-high-fast`.** Headless mode with `--yolo` applies file edits and may run commands. Use only in a trusted workspace and only when the user authorizes those changes.

For analysis or Q&A without writing files:

- Pass `--no-yolo` / `--no-force` (propose only, do not apply), and/or
- Pass `--mode ask` or `--mode plan` (read-only exploration / planning).

Override the model with `--model <id>` (see `agent --list-models`). Do not expect image *generation* unless the agent has an explicit tool for it; media paths in the prompt are for inspection.

Official semantics: [Using Headless CLI](https://cursor.com/docs/cli/headless), [Output format](https://cursor.com/docs/cli/reference/output-format).

## Wrapper path

```text
<skill-directory>/scripts/ask_cursor_agent.sh
```

## Usage

Run a task in the current workspace (defaults: `--yolo --trust`, Grok 4.5 High Fast):

```bash
./scripts/ask_cursor_agent.sh "Implement the requested change"
```

Add priority files and an explicit workspace:

```bash
./scripts/ask_cursor_agent.sh "Refactor these components to use the new API" \
  --workspace "/path/to/repo" \
  --file "src/components/UserList.tsx" \
  --file "src/components/UserDetail.tsx"
```

Read-only ask (no edits):

```bash
./scripts/ask_cursor_agent.sh "What does the auth middleware do?" \
  --mode ask \
  --no-yolo \
  --file "src/middleware/auth.ts"
```

Use a different model:

```bash
./scripts/ask_cursor_agent.sh "Review the active request path" \
  --model "claude-4-sonnet"
```

Resume a previous session:

```bash
./scripts/ask_cursor_agent.sh "Also add the missing regression test" \
  --session <session_id>
```

Allow access to another directory:

```bash
./scripts/ask_cursor_agent.sh "Compare the app with the shared package" \
  --add-dir "/path/to/shared-package"
```

## Workflow

1. Read enough local context to state the actual goal and important constraints.
2. Choose the workspace, optional model/mode, and 1–4 priority files.
3. Run the wrapper with one focused prompt.
4. Read the Markdown file printed as `output_path`.
5. Review workspace changes and run verification proportional to risk.
6. Use `--session` only for a true follow-up that benefits from prior context.

## Output

Successful runs print:

```text
session_id=<cursor_session_id>
output_path=<absolute_markdown_path>
elapsed=<seconds>s
```

The Markdown file contains the terminal `result.result` summary, a compact tool-type aggregate, and elapsed time. Raw tool payloads are omitted to keep the handoff concise and reduce secret exposure.

## Options

- `--workspace <dir>`: working directory; defaults to the current directory.
- `--file <path>`: priority file or media hint; repeatable.
- `--session <id>`: resume a previous session (`agent --resume`).
- `--model <id>`: model override (default `cursor-grok-4.5-high-fast`).
- `--mode plan|ask`: read-only plan or ask mode.
- `--yolo` / `--force`: allow edits (default on); `--no-yolo` / `--no-force` to disable.
- `--trust`: skip workspace trust prompt (default on); `--no-trust` to disable.
- `--add-dir <path>`: additional workspace root; repeatable.
- `--worktree [name]`: isolated git worktree.
- `--output <path>`: Markdown result path.

Task text may be passed as the first positional argument, with `--task`, or through stdin.

## Failure handling

- If the CLI is unavailable, run `agent about` (or `cursor-agent`) and check installation: [Headless CLI](https://cursor.com/docs/cli/headless).
- If authentication fails, run `agent status` / `agent login`, or set `CURSOR_API_KEY`.
- If a flag stops working after an upgrade, inspect `agent --help` and the official docs; update the wrapper rather than assuming another Agent CLI's flags.
- A non-zero agent exit is treated as failure. Failure output is truncated and common token patterns are redacted.
