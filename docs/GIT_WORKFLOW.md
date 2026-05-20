# Git Workflow Policy

This document defines the commit and push workflow for agents and humans working on **re:direct**. It is the authoritative reference for git operations; other docs should link here rather than restate the full policy.

---

## Local commits vs GitHub pushes

A local commit saves work only on this machine. It does **not** update GitHub.

A push uploads local commits to the remote GitHub repository.

Agents may create local commits automatically under this policy, but may **not** push unless the user explicitly asks.

---

## 1. When you may commit automatically

You may commit without asking when **all** of the following are true:

1. The change is inside the approved task scope.
2. `git status` contains only files related to the current task, or unrelated files are clearly left untouched.
3. The app builds successfully, or any failure is clearly environment-only and not a Swift compile error.
4. The commit is a coherent checkpoint that can be summarized in one sentence.
5. No secrets, tokens, local credentials, DerivedData, build products, local metadata, or private files are staged.
6. The change does not expand what data leaves the device.

---

## 2. Commit frequency

Commit stable, reviewable slices locally.

Good commit points:

- AI proxy contract added
- SwiftData models added
- Model container wired
- Seed schema added
- Seed importer implemented
- Local cache implemented
- Build/debug fix completed
- README/docs updated for a completed slice
- Before starting risky follow-up work
- Before handing off to another agent

Do **not** create a commit for every tiny edit.

Do **not** leave a large approved work batch uncommitted.

A commit should answer one sentence:

> What changed, and why does this checkpoint matter?

---

## 3. Before committing

1. Run `git status --short`.
2. Review changed files with `git diff --stat`.
3. Review actual changes with `git diff`.
4. Stage only task-related files.
5. Do not stage unrelated user/agent changes.
6. If unrelated changes exist, leave them unstaged and mention them in the report.
7. Confirm `.kiro/` remains ignored and unstaged.
8. Confirm no secrets, tokens, API keys, local credentials, DerivedData, build products, generated logs, local metadata, or private files are staged.
9. Confirm the change does not expand what data leaves the device.
10. Confirm file deletions are intentional.

---

## 4. Commit message format

Use a concise imperative subject, ideally under 70 characters.

Use only the message subject and body. Do not add trailer lines, metadata, or co-author tags unless the user explicitly requests them.

Add a body only when the change has multiple parts. Otherwise, the subject alone is fine.

Preferred subject prefixes:

- `chore:` - setup, dependencies, configuration, scaffolding
- `feat:` - user-visible functionality
- `fix:` - bug fixes
- `docs:` - documentation only
- `refactor:` - internal restructuring with no behavior change
- `test:` - tests only

Examples:

```text
chore: add AI proxy contract types
chore: add local-first SwiftData models
chore: wire redirect SwiftData schema
docs: add curiosity seed schema notes
fix: correct SwiftData model compile issues
```

For multi-part commits, use a short body:

```text
chore: add local-first integration foundation

- Add provider-agnostic AI proxy DTOs
- Register local-first SwiftData schema
- Remove unused template scaffolding
- Keep runtime network calls disabled
```

---

## 5. After committing

Report:

- Commit hash
- Commit message
- Whether the commit is local-only or pushed
- Files changed
- Build/test result
- Remaining untracked or unstaged files
- Anything still needing user approval

---

## 6. When NOT to commit

Do not commit if any of the following are true:

- Build fails from likely source errors.
- The diff includes secrets, tokens, API keys, or credentials.
- The diff includes unrelated files you did not introduce.
- The diff includes `.kiro/`, DerivedData, local metadata, generated logs, build products, or private workspace files.
- The task scope is unclear.
- A file deletion is ambiguous.
- The commit would mix multiple unrelated concerns.
- The next step requires user approval under a stop condition.
- The change expands what data leaves the device without explicit approval.
- A dependency/package was added without explicit approval.

---

## 7. Pushing

Commit stable slices locally. Push stable chapters remotely.

Agents may **not** push unless the user explicitly asks.

Good push points:

- End of a working session
- Before another agent or device needs the latest checkpoint
- After a build-passing milestone
- After a complete feature/setup slice
- Before risky work that needs a remote backup
- When the user explicitly requests GitHub sync

Do not push:

- Half-finished slices
- Broken source states
- Commits that include secrets or private files
- Commits that mix unrelated work
- Any branch unless the user explicitly approves the push

Before pushing:

1. Run `git status --short`.
2. Run `git log --oneline origin/main..HEAD`, or the equivalent upstream comparison for the active branch.
3. Confirm the target branch is correct.
4. Confirm no secrets, credentials, local metadata, build products, or unrelated files are included.
5. Confirm the latest build/test result is known.

Allowed user wording:

- "push to GitHub"
- "push this branch"
- "sync remote"
- "publish these commits"

If the user has not clearly asked for a push, stop after the local commit.

Never force-push to `main` or any shared branch.

Never push with hooks bypassed using `--no-verify`.

---

## 8. After pushing

Report:

- Remote name and branch
- Commit hash pushed
- Final `git status --short`
- Any remaining local commits not pushed
- Any remaining untracked or unstaged files

---

## 9. Destructive operations

Avoid these unless the user explicitly requests them:

- `git reset --hard`
- `git checkout .` / `git restore .`
- `git clean -f` / `git clean -fd`
- `git branch -D`
- `git push --force` / `git push --force-with-lease`
- Amending a commit that has already been pushed

When tempted to use a destructive operation, prefer a non-destructive alternative such as a new commit, revert, or stash, and explain the choice.

---

## 10. Hooks and signing

- Never skip pre-commit hooks using `--no-verify` without explicit user approval.
- Never disable commit signing using `--no-gpg-sign` or `commit.gpgsign=false` without explicit user approval.
- If a hook fails, investigate and fix the root cause. Do not bypass it.

---

## 11. Branching

- Default branch is `main`.
- Feature branches are encouraged for risky or multi-slice work.
- Ask the user before creating a new branch.
- Do not rename, delete, or move branches without explicit user approval.

Recommended branch names:

```text
phase-1-integration-foundation
seed-import-foundation
ai-proxy-contract
```

---

## 12. Stop conditions

Stop and ask before committing or pushing if:

- The diff includes unrelated files.
- A file deletion is ambiguous.
- Build fails from source errors.
- A dependency/package was added.
- Secrets or credentials might be included.
- The branch target is unclear.
- The push would publish private/local-only files.
- The change expands what data leaves the device.
- The change touches backend/cloud provider configuration.
- The change alters app navigation or root view initializers.

---

## 13. Conflict resolution

If anything here conflicts with `re_direct/CLAUDE.md`, `CLAUDE.md` wins for product, design, and implementation rules; this file wins for git commit/push operations.

This policy applies to all agents working on this repo, including Claude Code sessions.
