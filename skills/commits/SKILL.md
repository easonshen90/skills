---
name: commit
description: Use for every request to commit changes, stage and commit working tree modifications, split mixed changes into atomic commits, or draft a commit message. Enforces feature branch creation before committing, splits mixed changes into sequential atomic commits instead of squashing everything together, and creates clean conventional commits with strict safety and privacy guardrails.
---
# Commit

Create standardized, atomic Conventional Commits by combining Sentry's high-density engineering guardrails with GitHub's staging and safety protocols. Always isolate work onto a feature branch and commit changes in logical batches rather than a single monolithic commit.

## When to Use

- The user asks to commit changes, stage and commit files, or mentions `/commit`
- The working tree or staging area contains multiple mixed changes that need to be split into clean, sequential atomic commits
- The user wants to draft or format a Conventional Commit message from a diff

## Steps

### 1. Branch Verification and Auto-Creation

Always verify the current branch before staging or committing:

```bash
git branch --show-current
```

If the current branch is `main`, `master`, or `develop` (unless the user explicitly requested a direct commit to the default branch):

1. Inspect the pending changes to infer the primary intent (`feat`, `fix`, `refactor`, `chore`, etc.) and a concise slug.
2. Automatically create and switch to a descriptive branch (e.g., `git switch -c feat/<concise-slug>` or `git checkout -b fix/<concise-slug>`).
3. Re-check `git branch --show-current` and stop immediately if still on `main` or `master`.

### 2. Inspect Changes and Plan Atomic Batches

Examine both staged and unstaged changes to understand the full scope of work:

```bash
git status --porcelain
git diff --staged
git diff
```

**Never bundle unrelated changes into a single commit.** Group modifications into sequential, independently reviewable atomic batches:

- Separate refactoring (`refactor`) or formatting (`style`) from behavioral changes (`feat`, `fix`).
- Separate underlying dependency, build, or configuration updates (`build`, `ci`, `chore`) from application logic.
- Separate distinct modules or independent features into their own commits.
- Order the batches logically so earlier commits provide the foundation for later ones (e.g., 1. dependencies/config -> 2. core refactor -> 3. feature/fix -> 4. tests/docs).

### 3. Stage and Commit Sequentially

For each planned batch, stage only the relevant files or hunks:

```bash
# Stage specific files for the current batch
git add path/to/file1 path/to/file2

# Or stage specific hunks when a single file contains mixed logical changes
git add -p path/to/file
```

Verify the staged diff (`git diff --staged`) before committing each batch to ensure no unintended hunks or sensitive files slipped in.

### 4. Format the Commit Message

Follow the Conventional Commits structure:

```text
<type>(<scope>): <subject>

<optional body>

<optional footer>
```

- **Allowed Types**:
  - `feat`: New feature or user-facing capability
  - `fix`: Bug fix
  - `refactor` (or `ref` if repository history prefers it): Code restructuring without behavior changes
  - `perf`: Performance improvement
  - `docs`: Documentation only
  - `test`: Adding or updating tests
  - `build`: Build system or external dependencies
  - `ci`: CI/CD configuration and scripts
  - `chore`: Maintenance and tooling
  - `style`: Formatting/whitespace without logic changes
  - `meta`: Repository metadata
  - `license`: License updates
  - `revert`: Revert a previous commit
- **Breaking Changes**: Add `!` before `:` (e.g., `feat(api)!: ...`) and include `BREAKING CHANGE: <impact>` in the footer.
- **Subject Rules**:
  - Use imperative, present tense ("Handle null response", not "Handled" or "Handles").
  - Capitalize the first word and omit any trailing period.
  - Keep the subject line at 70 characters or fewer.
- **Body Rules**:
  - Include a body only when it adds context beyond the subject.
  - Explain **what** changed and **why** (motivation or previous behavior).
  - Keep every line under 100 characters.
- **Footers**:
  - `Fixes <issue>` or `Closes #123` to close an issue when merged.
  - `Refs <issue>` to link an issue without closing it.

### 5. Execute the Commit

Use separate `-m` arguments for the subject, body paragraphs, and footers. Never put literal `\n` sequences inside a `-m` string and never open an interactive editor:

```bash
git commit -m "fix(api): Handle null response in user endpoint" \
  -m "Return 404 when the user API encounters a deleted account instead of throwing an unhandled AttributeError." \
  -m "Fixes #5678"
```

Repeat Steps 3-5 until all atomic batches are committed cleanly, then run `git log -n <batch_count> --oneline` and `git status` to verify the final state.

## Gotchas and Safety Protocol

- **Privacy and PII Redaction**: Never include customer or organization names, user email addresses, raw support ticket contents, internal URLs, secrets, or PII in commit messages. Describe the underlying technical symptom and root cause instead.
- **Secret Prevention**: Never stage or commit `.env` files, `credentials.json`, private keys, tokens, or local environment overrides.
- **Pre-commit Hook Failures**: Never bypass hooks with `--no-verify` unless explicitly instructed by the user. If a commit fails due to a pre-commit hook (e.g., linter or formatter), fix the issue, re-stage the files, and create a **NEW** commit. Never run `git commit --amend` after a failed hook, as doing so will silently overwrite the previous unrelated commit.
- **No Destructive Git Operations**: Never modify `git config`, run `git reset --hard`, or force push (`--force`) without explicit user confirmation.