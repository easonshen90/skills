# skills

Personal Agent Skills collection. Each skill lives under [`skills/`](./skills/) and can be linked into an Agent host's skill directory.

## Skills

| Skill | Description |
| --- | --- |
| [cursor-agent](./skills/cursor-agent/) | Delegate tasks to the local Cursor Agent CLI (`agent -p`) with session resume and Markdown handoff. |

## Install a skill

```bash
git clone https://github.com/easonshen90/skills.git
mkdir -p ~/.cursor/skills
ln -sfn "$PWD/skills/cursor-agent" ~/.cursor/skills/cursor-agent
```

Repeat the `ln -sfn` line for other skills as they are added.

## License

Individual skills carry their own `LICENSE` / `NOTICE` when present. The `cursor-agent` skill is MIT (unofficial; not affiliated with Cursor).
