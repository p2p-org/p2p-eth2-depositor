---
name: validate-rfc
description: Validate the codebase against one or more RFC documents. Use when the user asks to "validate the codebase", "check RFC compliance", "compare code against the RFC", or runs /validate-rfc. Also use for setup questions that explicitly name RFC validation or this skill — e.g. "how do I set up validate-rfc?", "how do I add an RFC?", "where do RFCs go for /validate-rfc?" — answer from the Setup section instead of running validation. Produces a structured compliance report classifying each RFC requirement as implemented, partial, pending, deviated, or out-of-scope, with file:line citations.
---

# Validate codebase against RFC(s)

Produce a compliance report that compares this codebase against one or more RFC documents.

## Setup

How to load RFCs so this skill can validate against them. When the user asks a setup question, answer from this section instead of running validation.

1. **Create `rfcs/` at the repo root** if it doesn't exist: `mkdir rfcs`.
2. **Add each RFC** as one of:
   - A single markdown file: `rfcs/<name>.md`.
   - A folder: `rfcs/<name>/` with `.md` files inside. Images and diagrams can sit alongside — they're referenced by path, not interpreted.
3. **Verify:** running this skill should now discover your RFCs. Each top-level entry under `rfcs/` (file or folder) is treated as one RFC; its name is the file stem or directory name.

That's all. The skill is read-only on code — it only writes `rfc-validation-report.md`.

## Preflight — does `rfcs/` exist and have content?

**Run this check fresh on every invocation. Never rely on what you "remember" about `rfcs/` from earlier in the conversation — the directory may have been deleted, renamed, or never existed in this worktree.** Use Bash (`ls`, `test -d`, `find rfcs -name '*.md'`) at the start of every run.

1. **If `rfcs/` does not exist:** stop and direct the user to the Setup section above.
2. **If `rfcs/` exists but contains no `.md` files and no subdirectories with `.md` content** (only images, `.DS_Store`, etc., counts as empty): stop and direct the user to the Setup section above.
3. Also re-check existence and contents when the user asks setup/usage questions ("how do I validate?", "what RFCs are loaded?"). Do not claim RFCs exist based on conversation history.

Only proceed past Preflight when at least one RFC is discoverable on disk *right now*.

## Inputs

All RFCs live under `rfcs/` at the repo root. An RFC can be either:

- **A single file:** `rfcs/<name>.md` — the whole RFC in one markdown file.
- **A folder:** `rfcs/<name>/` — multiple files belonging to one RFC. Read every `.md` (and any other text-like file: `.txt`, `.mmd`, `.puml`, etc.) inside, recursively, and treat their combined content as one RFC. If the folder contains an `index.md` or `README.md`, start there; otherwise read files in sorted order. Include images/diagrams by reference (note their paths in the report; do not try to interpret binary files).

**Discovery:**
- Treat each top-level entry inside `rfcs/` as one RFC: every `*.md` file is an RFC, and every subdirectory is an RFC. The RFC name is the file stem or directory name.
- If `rfcs/` is missing or empty, the Preflight section above handles it — do not silently continue.

**Selecting which RFC(s) to validate:**
1. **User says "all" / "every RFC" / "all of them"** → validate every discovered RFC. Produce one report with a per-RFC section and a multi-RFC summary table at the top.
2. **User names a specific RFC** (e.g. "validate against payout-guard", "the granularity RFC") → match case-insensitively against file stems and directory names. If exactly one matches, validate it. If multiple plausibly match, list the matches and ask which one. If none match, list all discovered RFCs and ask.
3. **User does not specify** → do not assume "all". List the discovered RFCs and ask which to validate. Use the AskUserQuestion tool with options:
   - All RFCs
   - One option per discovered RFC (up to the tool's option cap; if more, present the full list as text and ask the user to name one or "all")
   Wait for the answer before proceeding.

Do not assume a fixed internal structure for folder-based RFCs (no required filenames, no required section headings). Extract requirements from whatever content is there.

## Procedure

1. **Read the RFC(s) fully.** Do not skim.
2. **Extract a requirement checklist.** For each RFC, enumerate:
   - Goals / success criteria
   - Components / modules to build or change
   - Public APIs, CLI flags, config keys
   - Data models / DB schema / migrations
   - Flows (sequence of operations, triggers, schedules)
   - Non-functional requirements (performance, retries, idempotency, logging, metrics)
   - Explicit non-goals (useful for the "out of scope" bucket)
3. **Gather evidence from the codebase.** Use Grep/Glob/Read. For each requirement, find concrete code locations (file:line) that implement it — or confirm absence.
4. **Classify each requirement** into exactly one bucket (see Report Format).
5. **Capture inputs metadata** before writing:
   - Current branch (`git rev-parse --abbrev-ref HEAD`).
   - HEAD commit SHA (`git rev-parse --short HEAD`) and its date.
   - **Working tree state** (`git status --porcelain`). If non-empty, the report header MUST say `Working tree: dirty (N files modified, M untracked)` and list the paths. This warns the reader that the report reflects HEAD *plus uncommitted edits* — the SHA alone does not pin what was validated.
   - Last-modified date for each RFC file/folder. Prefer `git log -1 --format=%cs -- <path>` (returns the date of the last commit that changed the path; survives clones). Fall back to `stat` only if the path is untracked by git (no commit history yet).
   Record all of this in the report header so a stale or dirty report is obvious at a glance.
6. **Tag each Pending and Deviation finding with a priority** — `[P:high]`, `[P:med]`, or `[P:low]`. High = blocks the RFC's stated goal or has correctness/safety impact. Med = meaningful gap but workable. Low = cosmetic / nice-to-have. Be explicit; this turns the report into a triage list.
7. **Write the report** to `rfc-validation-report.md` at the repo root (overwrite if exists) and also print a short summary to the user.

## Report format

```markdown
# RFC Validation Report — <date>

## Inputs
- **Branch:** <branch>
- **Commit:** <short-sha> (<commit-date>)
- **Working tree:** clean  *— or —*  dirty (N modified, M untracked); see list below
  - `path/to/changed/file`  *(only when dirty)*
- **RFCs validated:**
  - `rfcs/<rfc-1>` — last modified <YYYY-MM-DD>
  - `rfcs/<rfc-2>` — last modified <YYYY-MM-DD>

> If the working tree is dirty, the report reflects HEAD **plus uncommitted edits** — the SHA does not pin what was validated.
> If any RFC last-modified date is months older than the commit date, flag it: the spec may be lagging the code.

## RFC: <rfc-name>
**Source:** rfcs/<file>.md
**Summary:** <X implemented / Y partial / Z pending / N deviations / M extras>

### ✅ Implemented
- <requirement> — `path/to/file.rs:123` [+ short evidence note]

### ⚠️ Partially implemented
- <requirement> — what's done vs missing, with citations

### ❌ Pending
- `[P:high|med|low]` <requirement> — in RFC, no matching code found (note what you searched for)

### 🔀 Deviations
- `[P:high|med|low]` <requirement> — RFC says X, code does Y at `file.rs:42`.

### ➕ Out of scope / extras
- <feature in code not in RFC> — `file.rs:L`. Likely intentional? <yes/no/unclear>

### 🧪 Test coverage
**Covered:**
- <implemented requirement> — test at `tests/foo.rs:42`

**Gaps:**
- <implemented requirement with no test found> — searched `tests/`, `*_test.rs`, etc.

### ❓ Ambiguous / needs human review
- <RFC item too vague to verify, or conflicting signals>

### 📝 RFC quality notes
- <contradictions, under-specified areas, stale references>
```

At the top of the file (after Inputs), include an overall multi-RFC summary table if more than one RFC was validated. The summary table should include a `High-priority gaps` column counting `[P:high]` items across Pending + Deviations.

## Rules

- **Every claim needs a citation.** "Implemented" without `file:line` is not acceptable.
- **Do not guess.** If you cannot find evidence either way, put it in "Ambiguous", not "Pending".
- **Be conservative about "Implemented".** Prefer "Partial" when unsure — the user would rather investigate a false-partial than miss a real gap.
- **Deviation > Implemented.** If the code solves the RFC's goal a different way, that's a deviation, not a pass.
- **Do not modify code.** This skill is read-only except for writing the report file.

## Where RFCs live

RFCs should be committed to `rfcs/` in this repo as markdown. Reasons:
- Versioned with the code they describe — you can diff an RFC change against the code change in the same PR.
- Works offline and in CI without Notion credentials.
- Claude can read them directly with no extra tooling.
