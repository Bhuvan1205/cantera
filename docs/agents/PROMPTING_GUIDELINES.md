# AI Agent Prompting Guidelines

Guidelines for human engineers and automated orchestrators when prompting AI agents in this repository.

---

## 1. Effective Prompt Structure
When delegating tasks to AI coding agents, structure instructions using:
1. **Goal:** High-level user story or fix.
2. **Impacted Layers:** Explicitly mention FastAPI backend and/or Flutter presentation.
3. **Required Endpoints:** Specify required route method and path.
4. **Verification Requirement:** Explicitly demand `flutter analyze` and `pytest` execution.

### Example Prompt
```markdown
Implement feature: "Allow students to view their transaction receipt details".
- Backend: Add GET /api/wallet/transactions/{id}/receipt returning itemized receipt details.
- Frontend: Bind ReceiptSheet widget in Flutter to the new endpoint via ApiClient.
- Adhere to ADR-001 backend-first architecture.
- Verify with backend pytest and flutter analyze.
```

---

## 2. Anti-Patterns to Avoid in Prompts
- ❌ Do NOT ask the agent to "write directly to Firestore from Flutter".
- ❌ Do NOT ask the agent to "skip backend tests to save time".
- ❌ Do NOT ask the agent to "loosen Firestore security rules".

---

## Cross-References
- [Project Context](file:///docs/agents/PROJECT_CONTEXT.md)
- [Feature Implementation Protocol](file:///docs/agents/FEATURE_IMPLEMENTATION_PROTOCOL.md)
