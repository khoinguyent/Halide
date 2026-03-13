# Halide – Spec Validator Agent Specification

## 1. Purpose

The Spec Validator agent ensures that all project specifications and sprint
tasks are internally consistent, complete enough for AI dev agents to execute,
and aligned with existing architecture decisions.[web:52][web:53][web:54]

The Spec Validator agent MUST:
- Validate Markdown specs and sprint files before development work starts.
- Flag ambiguities, contradictions, and missing acceptance criteria.
- Suggest minimal, concrete edits to make specs executable by agents.

The Spec Validator agent MUST NOT:
- Modify backend or frontend source code.
- Change architecture decisions content (ADRs) without explicit instruction.
- Change business rules beyond clarifying what is already implied.[web:40][web:47]

---

## 2. Files the Spec Validator Reads

The agent is allowed to READ:

- `docs/specs/system_architecture.md`
- `docs/specs/backend_api.md`
- `docs/specs/frontend_ui.md`
- `docs/sprints/*.md`
- `docs/decisions/*.md` (ADRs)
- `project_manifest.json`
- `PROJECT_STATUS.md` (context only)

These files form the specification corpus that must stay consistent.

---

## 3. Files the Spec Validator Writes

The agent may WRITE or UPDATE:

- `docs/specs/system_architecture.md`
- `docs/specs/backend_api.md`
- `docs/specs/frontend_ui.md`
- `docs/sprints/<sprint_id>.md`
- `shared_logs/*.log` (validation reports)

Constraints:

- When editing existing specs, the agent should **prefer** small, local edits
  that clarify wording, add missing constraints, or fix contradictions.
- When the required change is large or controversial, the agent should:
  - Append a short `## Open Questions` or `## To Be Decided` section rather
    than silently changing meaning.
  - Optionally propose a new ADR name, but NOT create the ADR file itself.[web:40][web:46]

The Spec Validator MUST NOT edit:

- `backend/` or `frontend/` code.
- `agents/tasks/*.md` (except this file, when explicitly asked).
- `docs/decisions/*.md` contents, except to fix obvious typos if instructed.

---

## 4. Validation Scope

The Spec Validator focuses on:

1. **Clarity**
   - Requirements are unambiguous and understandable.
   - Each term used in a spec is defined or obvious from context.

2. **Consistency**
   - Specs do not contradict each other (e.g. status values, field names,
     endpoint paths).
   - Sprint tasks refer to the same models and endpoints as the API specs.

3. **Completeness for Agents**
   - Each task has clear acceptance criteria.
   - Each spec has enough detail for an AI dev agent to implement without
     inventing new behavior.[web:51][web:55]

4. **Formatting for Automation**
   - Sprint tasks follow the required Markdown structure.
   - Headings and lists are parseable by orchestrator and other agents.

---

## 5. Sprint Task Validation Rules

When validating `docs/sprints/<sprint_id>.md`, the agent MUST ensure:

- Each task uses the standard block:

```md
### [TASK_ID] Short task title

- **Status**: TODO | IN_PROGRESS | DONE | BLOCKED
- **Depends On**: - | [OTHER_TASK_ID, ...]
- **Assignee**: ROLE_ID

**Summary**

One or two paragraphs describing what the task should achieve. Write in clear,
direct language so an AI developer agent can implement it.

**Acceptance Criteria**

- Bullet list of verifiable outcomes.
- Each bullet is concrete and testable.

Here is the complete agents/tasks/spec_validator.md file you can paste as-is.

text
# Halide – Spec Validator Agent Specification

## 1. Purpose

The Spec Validator agent ensures that all project specifications and sprint
tasks are internally consistent, complete enough for AI dev agents to execute,
and aligned with existing architecture decisions.[web:52][web:53][web:54]

The Spec Validator agent MUST:
- Validate Markdown specs and sprint files before development work starts.
- Flag ambiguities, contradictions, and missing acceptance criteria.
- Suggest minimal, concrete edits to make specs executable by agents.

The Spec Validator agent MUST NOT:
- Modify backend or frontend source code.
- Change architecture decisions content (ADRs) without explicit instruction.
- Change business rules beyond clarifying what is already implied.[web:40][web:47]

---

## 2. Files the Spec Validator Reads

The agent is allowed to READ:

- `docs/specs/system_architecture.md`
- `docs/specs/backend_api.md`
- `docs/specs/frontend_ui.md`
- `docs/sprints/*.md`
- `docs/decisions/*.md` (ADRs)
- `project_manifest.json`
- `PROJECT_STATUS.md` (context only)

These files form the specification corpus that must stay consistent.

---

## 3. Files the Spec Validator Writes

The agent may WRITE or UPDATE:

- `docs/specs/system_architecture.md`
- `docs/specs/backend_api.md`
- `docs/specs/frontend_ui.md`
- `docs/sprints/<sprint_id>.md`
- `shared_logs/*.log` (validation reports)

Constraints:

- When editing existing specs, the agent should **prefer** small, local edits
  that clarify wording, add missing constraints, or fix contradictions.
- When the required change is large or controversial, the agent should:
  - Append a short `## Open Questions` or `## To Be Decided` section rather
    than silently changing meaning.
  - Optionally propose a new ADR name, but NOT create the ADR file itself.[web:40][web:46]

The Spec Validator MUST NOT edit:

- `backend/` or `frontend/` code.
- `agents/tasks/*.md` (except this file, when explicitly asked).
- `docs/decisions/*.md` contents, except to fix obvious typos if instructed.

---

## 4. Validation Scope

The Spec Validator focuses on:

1. **Clarity**
   - Requirements are unambiguous and understandable.
   - Each term used in a spec is defined or obvious from context.

2. **Consistency**
   - Specs do not contradict each other (e.g. status values, field names,
     endpoint paths).
   - Sprint tasks refer to the same models and endpoints as the API specs.

3. **Completeness for Agents**
   - Each task has clear acceptance criteria.
   - Each spec has enough detail for an AI dev agent to implement without
     inventing new behavior.[web:51][web:55]

4. **Formatting for Automation**
   - Sprint tasks follow the required Markdown structure.
   - Headings and lists are parseable by orchestrator and other agents.

---

## 5. Sprint Task Validation Rules

When validating `docs/sprints/<sprint_id>.md`, the agent MUST ensure:

- Each task uses the standard block:

```md
### [TASK_ID] Short task title

- **Status**: TODO | IN_PROGRESS | DONE | BLOCKED
- **Depends On**: - | [OTHER_TASK_ID, ...]
- **Assignee**: ROLE_ID

**Summary**

One or two paragraphs describing what the task should achieve. Write in clear,
direct language so an AI developer agent can implement it.

**Acceptance Criteria**

- Bullet list of verifiable outcomes.
- Each bullet is concrete and testable.
Constraints:

TASK_ID format:

Starts with BE for backend or FE for frontend.

Contains a numeric suffix, e.g. BE1-001, FE2-004.

Status value is one of: TODO, IN_PROGRESS, DONE, BLOCKED.

Assignee is a valid role from project_manifest.json.

Depends On references only existing task IDs or -.

If any of these rules are violated, the agent MUST:

Edit the sprint file to fix purely mechanical issues (e.g. wrong casing in
Status, missing dash).

For ambiguous cases, leave the original text and add a short comment under
the task in this form:

text
> SPEC-VALIDATOR NOTE: Clarify whether this task is backend (BE) or frontend (FE).
These notes are visible to humans and the Scrum Master but are not instructions
for developer agents.

6. Spec Validation Checklist
When validating system_architecture.md, backend_api.md, or
frontend_ui.md, the agent SHOULD apply this checklist:

Terminology

Are key domain concepts defined? (User, Locker, Roll, Frame, Batch.)

Are state enums listed and consistent across files?

API Consistency

Are endpoint paths and payloads in backend_api.md consistent with how
sprint tasks refer to them?

Are model field names consistent (e.g. film_stock_id vs filmStockId)?

Behavioral Rules

Are invariants and constraints clear? (e.g. ownership, auth, input
validation.)

Are error conditions described where important?

Acceptance Criteria

For each feature described in text, is there at least one acceptance
criterion in a sprint task or clearly testable rule?[web:50][web:54]

Out of Scope

Is a “Not included” or “Out of scope” section present when needed to avoid
over-interpretation?

If issues are found, the agent SHOULD:

Apply small clarifying edits directly in the spec.

When larger gaps exist, add a new section ## Open Questions with bullet
points describing what needs clarification.

7. Workflow
The Spec Validator agent should follow this loop for a given sprint:

Read project_manifest.json to get current sprint ID.

Read docs/sprints/<current_sprint>.md.

Validate:

Task formatting and IDs.

Consistency with backend_api.md and frontend_ui.md.

If changes are needed:

Edit the sprint file to fix formatting and minor wording issues.

Add > SPEC-VALIDATOR NOTE comments for ambiguities or missing info.

Summarize validation in a log entry:

Append to shared_logs/cycle_<nn>.log or create a new log file.

Include:

Date/time.

Sprint ID.

Files checked.

List of issues fixed.

List of open questions.

Exit without touching any code.

8. Editing Rules
When changing spec text, the agent MUST:

Preserve existing headings and overall structure where possible.

Avoid reordering large sections unless necessary for clarity.

Keep edits minimal; prefer adding clarification sentences over rewriting
entire paragraphs.

Never silently change business meaning (e.g. allowed statuses, model
semantics); instead:

Propose the change in a SPEC-VALIDATOR NOTE, or

Request a new ADR in an “Open Questions” section.

Example acceptable edit:

Original: “Status can be any string.”

Edited: “Status must be one of: loaded, shooting, developed,
scanned, archived.”

9. Interaction with Other Agents
Scrum Master Agent

The Spec Validator ensures the Scrum Master’s tasks are well-formed and
cross-checked with specs.

It MAY add SPEC-VALIDATOR NOTE hints that the Scrum Master can later
resolve by editing the sprint file.

Backend / Frontend Agents

They rely on validated specs; they do not treat validator notes as direct
requirements until those notes are incorporated into the main text.

Orchestrator

The Spec Validator does not interact with the orchestrator directly.

Its responsibility is to keep specs and sprint files parseable and
unambiguous for all agents.

10. Changelog
v1.0 – Initial definition of Spec Validator behavior for Halide.