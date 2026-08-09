# Agent Instructions

Practical guidelines for AI coding agents operating within the Cantora repository.

---

## 1. How to Navigate the Codebase
- **Backend Business Logic:** Look in `lib/admin_console/backend/features/<domain>/service.py`.
- **Backend Routes:** Look in `lib/admin_console/backend/features/<domain>/router.py`.
- **Database Access:** Look in `lib/admin_console/backend/features/<domain>/repository.py`.
- **Flutter UI & Screens:** Look in `lib/user_console/screens/` and `lib/staff_console/screens/`.
- **Flutter Network Calls:** Look for `ApiClient.instance` calls in `lib/*/services/`.

---

## 2. Standard Commands for Agents
- **Run Backend Tests:** `pytest lib/admin_console/backend/tests -v`
- **Run Flutter Tests:** `flutter test`
- **Run Flutter Analyzer:** `flutter analyze`
- **Run Security Rules Tests:** `firebase emulators:exec --only firestore "npm test"` (in `tests/rules/`)

---

## 3. Tool Calling & Editing Protocol
- Always use specific file viewing and replacement tools rather than running terminal shell commands like `cat`, `sed`, or `grep`.
- Always check that `flutter analyze` passes with 0 issues after making any Dart modifications.
- Always run `pytest` after making any Python backend modifications.

---

## Cross-References
- [Feature Implementation Protocol](file:///docs/agents/FEATURE_IMPLEMENTATION_PROTOCOL.md)
- [AI Code Review Checklist](file:///docs/agents/AI_CODE_REVIEW_CHECKLIST.md)
