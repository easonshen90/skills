# Cursor Agent Skill

Delegate focused coding tasks from any Agent to your local [Cursor Agent CLI](https://cursor.com/docs/cli/headless) (`agent -p`). Capture progress, resume sessions, and return a compact Markdown handoff.

```text
Host Agent → ask_cursor_agent.sh → agent -p --yolo --stream-json → result.md + session_id → review / resume
```

This is an **unofficial**, host-agnostic [Agent Skill](./SKILL.md) patterned after [oil-oil/kimi](https://github.com/oil-oil/kimi). It is not affiliated with or endorsed by Cursor / Anysphere. See [NOTICE](./NOTICE).

## Requirements

- macOS or Linux with Bash 3.2+
- [Cursor Agent CLI](https://cursor.com/docs/cli/headless) (`agent` or `cursor-agent`) installed and authenticated (`agent login` or `CURSOR_API_KEY`)
- [`jq`](https://jqlang.org/) on `PATH`
- An Agent that can load `SKILL.md` and run local shell commands

## Install

```bash
git clone https://github.com/easonshen90/skills.git
cd skills
mkdir -p ~/.cursor/skills
ln -sfn "$PWD/skills/cursor-agent" ~/.cursor/skills/cursor-agent
```

Hosts may also load this skill's `SKILL.md` directly without a symlink.

## First task

```bash
./scripts/ask_cursor_agent.sh \
  "Explain the active request path" \
  --workspace "/path/to/repository" \
  --file "src/main.ts" \
  --mode ask \
  --no-yolo
```

Defaults are `--yolo`, `--trust`, and model `cursor-grok-4.5-high-fast` (writes files). For read-only asks, use `--mode ask --no-yolo` as above.

Resume:

```bash
./scripts/ask_cursor_agent.sh \
  "Now add the missing regression test" \
  --workspace "/path/to/repository" \
  --session "<session_id>"
```

## Wrapper options

| Option | Purpose |
| --- | --- |
| `--workspace <dir>` | Working directory (default: cwd). |
| `--file <path>` | Priority file/media hint; repeatable. |
| `--session <id>` | Resume via `agent --resume`. |
| `--model <id>` | Model override (default `cursor-grok-4.5-high-fast`). |
| `--mode plan\|ask` | Read-only plan or ask. |
| `--yolo` / `--force` | Allow edits (default on). |
| `--no-yolo` / `--no-force` | Propose only; do not apply. |
| `--trust` / `--no-trust` | Workspace trust (default on). |
| `--add-dir <path>` | Extra workspace root; repeatable. |
| `--worktree [name]` | Isolated git worktree. |
| `--output <path>` | Markdown result path. |

Task text: positional, `--task`, or stdin.

Official references: [Headless CLI](https://cursor.com/docs/cli/headless) · [Output format](https://cursor.com/docs/cli/reference/output-format).

## Layout

```text
skills/cursor-agent/
├── SKILL.md                      # Triggering metadata and agent workflow
├── agents/openai.yaml            # Optional OpenAI-host metadata
├── scripts/ask_cursor_agent.sh   # Headless Cursor Agent wrapper
├── LICENSE
└── NOTICE
```

This skill is part of [easonshen90/skills](https://github.com/easonshen90/skills).

## Validate

```bash
bash -n scripts/ask_cursor_agent.sh
scripts/ask_cursor_agent.sh --help
```

## License

MIT — see [LICENSE](./LICENSE). Unofficial project; see [NOTICE](./NOTICE).
