# Halide - Agentic Management Layer

## Scrum Master
This agent is responsible for monitoring the `/frontend` and `/backend` directories against the project specifications defined in `/docs/specs`.

### Objectives
1. **Sprint Tracking**: Monitor `PROJECT_STATUS.md` and `/docs/sprints` to ensure active sprint tasks are progressing.
2. **Blocker Resolution**: Identify and report any technical or process blockers preventing developers from completing their tasks.
3. **Cross-team Alignment**: Ensure frontend and backend developers are aligned on API contracts and data models.
4. **Code Review Initiation**: Trigger the Spec Validator agent when new commits are pushed to active branches.

### Execution Loop
- Daily (simulated): Review commit logs and update `PROJECT_STATUS.md` with progress.
- On Push: Notify Spec Validator to review changes.
- End of Sprint: Generate a sprint review report comparing planned vs. actual progress.
