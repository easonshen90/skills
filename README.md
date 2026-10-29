# skills

Personal Agent Skills collection. Each skill lives under [`skills/`](./skills/) and can be linked into an Agent host's skill directory.

## Skills

| Skill | Description |
| --- | --- |
| [commits](./skills/commits/) | Commit on a feature branch: split mixed changes into atomic Conventional Commits with safety and privacy guardrails. |
| [cursor-agent](./skills/cursor-agent/) | Delegate tasks to the local Cursor Agent CLI (`agent -p`) with session resume and Markdown handoff. |
| [write-skill](./skills/write-skill/) | Self-contained guide to author agent skills: progressive disclosure, invocation, cross-skill boundaries, descriptions, smoke eval. |

## Install a skill

```bash
git clone https://github.com/easonshen90/skills.git
mkdir -p ~/.cursor/skills
ln -sfn "$PWD/skills/cursor-agent" ~/.cursor/skills/cursor-agent
ln -sfn "$PWD/skills/write-skill" ~/.cursor/skills/write-skill
```

Repeat the `ln -sfn` line for other skills as they are added.

## License

Individual skills carry their own `LICENSE` / `NOTICE` when present. The `cursor-agent` skill is MIT (unofficial; not affiliated with Cursor).
