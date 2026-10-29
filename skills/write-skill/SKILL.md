---
name: write-skill
description: >-
  Use when creating, rewriting, reviewing, or turning a workflow into an agent
  skill (SKILL.md). Also when asking about skill composition, progressive
  disclosure, trigger descriptions, eval/smoke of a skill, or whether one skill
  is swallowing another. Prefer this over ad-hoc drafting whenever the
  deliverable is a reusable skill — this skill is the self-contained authoring
  guide (no need to load separate writing-for-agents or skill-creator).
---
# Write an agent skill

Job: ship a reusable `SKILL.md` (optional `references/`, `scripts/`, `assets/`) that loads by name, stays lean in always-on context, and never duplicates another skill's how.

This skill is a self-contained authoring guide (craft + mechanics + create/eval). It replaces separate writing-for-agents / skill-creator installs.

**Host notes:** save with whatever your Agent host uses to install skills (copy into the skills directory, or Grok Bot `UpdateSkill`). On Grok Bot, mention a new skill as `[name](sand-workflow:<id>)`. Users often name skills in plain language — do not invent slash UX the host lacks. Keep assistant-specific channels, repos, and people out of shared recipes (those belong in the routine or the chat).

## Process

1. **Capture intent** — outcome, trigger contexts, output shape, edge cases, dependencies. Prefer answers already in chat. Interview only the gaps: formats, success criteria, example files, tools/MCPs.
2. **One job** — unrelated jobs become separate focused skills that compose. Several focused skills beat one monolith.
3. **Choose invocation** — see Mechanics. Default model-invoked when the agent (or another skill) must discover it.
4. **Draft** — anatomy + writing craft + composition rules below. Body ideally under ~500 lines; rare branches go to `references/`.
5. **Composition pass** — wherever another skill owns the work, leave a one-line pointer by skill id and an outcome contract. Do not paste that skill's tools, steps, params, retries, or checklists.
6. **Save** — write the skill into the host skill store (name, pushy description, body).
7. **Smoke / eval** — see Eval loop. Iterate until triggers and outputs hold; generalize, do not overfit the test prompts.

## Anatomy

```text
skill-id/
├── SKILL.md           # required
├── references/        # on-demand docs
├── scripts/           # deterministic helpers reused every run
└── assets/            # templates / files copied into outputs
```

Frontmatter minimum:

```yaml
---
name: short-name
description: Use when … (what it does AND concrete trigger branches). Pushy against under-trigger; one short anti-scope clause if it would steal adjacent jobs.
---
```

Optional: `disable-model-invocation: true` for user-only skills (see Mechanics).

Put all "when to use" in `description`, not only in the body. Imperative steps. Prefer explaining *why* over ALL-CAPS MUST/NEVER walls. Bundle a script when every run would reinvent the same mechanical work.

Progressive disclosure:

1. Metadata (`name` + `description`) — always visible to the router (~100 words).
2. `SKILL.md` body — when the skill fires.
3. Bundled resources — only when the body points at them.

Do not double-write the same fact in body and `references/`. Keep references **one level deep** from `SKILL.md`. For multi-domain skills, put each variant in its own reference file and load only the needed one.

## Writing craft

**Context pointer** — a reference in context that names out-of-context material and the branches that should reach it. The skill `description` is the top pointer. Wording decides reliability: a must-have target behind a weak pointer is a variance bug — sharpen wording before inlining.

Pointer rules: front-load the leading word; one trigger per distinct branch (collapse synonym rewrites); cut identity the body already carries.

**Two loads**

- *Context load* — always-on tokens (descriptions, always-loaded files).
- *Cognitive load* — what the human must remember as the index. Spend cognitive load where judgement matters; remove it where it does not.

Material behind a pointer escapes context load at the price of the pointer line.

**Information hierarchy**

1. In-file step (ordered actions)
2. In-file reference (consulted on demand)
3. Disclosed reference (separate file via pointer)

Push down the ladder so the top stays legible. Inline what every branch needs; disclose what only some branches need. Co-locate a concept's definition, rules, and caveats. Cure sprawl by disclosing reference and splitting by branch.

**Steps** — every step ends on a **completion criterion** (done vs not-done), checkable and exhaustive. Sharpen vague bounds before hiding later steps.

**Leading words** — compact pretrained tokens (`lesson`, `tracer bullets`, …). Repeat as tokens, not sentences. Prefer existing words over coined ones. Prompt the positive target; avoid steering only by prohibition when a positive phrasing exists.

**Pruning**

- Single source of truth per meaning.
- The environment is also truth; restating it is a cache — only cache what lookup cannot cheaply give.
- Delete no-op sentences; retire restatements that a leading word can replace.

**Patterns** — define exact output templates when format matters; include short input→output examples when they teach better than prose. Lack of surprise: no malware, exfiltration, or misleading intent.

## Mechanics (invocation + routers)

**Model-invoked** — has an agent-facing `description`; the agent can fire it, and **other skills can reach it**. Description is permanent context load for discoverability. Omit `disable-model-invocation`.

**User-invoked** — `disable-model-invocation: true`; only the human naming it can fire it; **no other skill can**. Description becomes human-facing summary (strip trigger lists). Zero context load, more cognitive load.

Pick model-invocation when the agent or another skill must reach it. If it only fires by hand, make it user-invoked.

Shared reference needed by two user-invoked skills cannot live in either (neither can fire the other). Put it in a plain file outside the skill system and point both at it.

**Router skill** — one skill that names others and when to reach each, curing piled cognitive load. It **hints and stops**; it does not execute callees or override their `SKILL.md`. Prefer the user / slash / explicit name as orchestrator when that fits the harness; do not build middle layers that swallow callee context (personas do not invoke personas).

Split out a new model-invoked skill when a distinct leading word should trigger alone, or another skill must reach it — and the always-on description cost is worth it.

## Cross-skill boundaries

Caller owns: when / why / order / cross-step invariants / outcome contract / one-sentence pointer by skill id.

Callee owns: how — tools, params, retries, internal checklists, authoritative procedure.

Hard rules:

1. **Don't duplicate content between skills — reference and link instead.**
2. **Single source of truth** — if this skill touches another's topic, one sentence + skill name, not a second manual.
3. **Callee must be model-invoked** if this skill should fire it autonomously; otherwise change invocation mode or use an external shared file.
4. **Orchestrators keep ordering and invariants only** — not the inner contract of each phase.
5. **Lint** — if you deleted the callee's `SKILL.md`, could this skill still complete that step from its own text? If yes, it overreached.

Same rule inside one skill: body points at `references/`; no twin copies.

Programming isomorphism (use as review questions, not new jargon to invent): single responsibility; least knowledge (don't reach into the callee's internals); encapsulation; facade = description + outcome; depend on the outcome contract, not a concrete tool sequence; tell the callee to do the work rather than asking for its state and re-implementing.

## Description checklist

- Real user phrasing; what + when (branches).
- Slightly pushy against under-trigger; short anti-scope if collisions are likely.
- Pointer, not a second copy of the workflow.
- For user-invoked skills: human summary only, no agent trigger list.

## Eval loop

Default lightweight:

1. 2–3 should-trigger prompts and 1–2 near-miss should-not prompts (realistic, specific, not toy).
2. Run; note load/no-load, step fidelity, whether any callee was re-implemented.
3. Patch description or body; re-run failures.
4. Generalize from feedback — do not overfit the sample prompts. Keep the prompt lean; cut instructions that waste runs. Explain why.

When the user wants depth: draft assertions that are objectively checkable; compare with-skill vs without (or old vs new); iterate in rounds; optionally tune the description against a larger should/should-not set. Use tools this environment actually has — do not invent missing viewer scripts. Subjective skills (style, design) lean on human review, not forced numeric assertions.

Stop when the user is happy, feedback is empty, or changes stop helping.

## Anti-patterns

- Monolith that embeds other skills' how-tos
- Weak pointer to a must-have target
- Caching the environment
- Expecting a user-invoked skill to be fired by another skill
- Coined jargon when a pretrained leading word exists
- Assistant-specific IDs in a shared skill
- Description that dumps the whole workflow
- Double-writing body and `references/`
- Overfitting eval prompts; ALL-CAPS rule walls instead of reasons

## After save

Reply with the skill id/path your host expects and one line on when it fires. Follow up only for a real open item (edge case, split, description tune).

## Optional deep links

Upstream essays if you need the author's voice (this skill is enough to author without them):

- https://github.com/mattpocock/skills/blob/main/skills/productivity/writing-for-agents/SKILL.md
- https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/writing-for-agents/SKILL-MECHANICS.md
- https://github.com/anthropics/skills/blob/main/skills/skill-creator/SKILL.md
- https://claude.com/docs/skills/how-to
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
- https://github.com/addyosmani/agent-skills/blob/main/docs/skill-anatomy.md
