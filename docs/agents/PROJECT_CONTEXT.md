# Agent Project Context

## What is Cantora?
Cantora is a smart canteen ordering, dynamic queue management, and digital wallet system tailored for high-rush institutional and campus dining.

---

## Architectural Summary
- **Architecture Standard:** **ADR-001 (Backend-First Architecture)** — permanently locked under **EEL-001**.
- **Backend Application Layer:** FastAPI (Python 3.11) on Google Cloud Run (`lib/admin_console/backend/`).
- **Frontend Presentation Layer:** Flutter (`lib/`), cross-platform (Android, iOS, Web).
- **Persistence Layer:** Cloud Firestore with strict backend-only write security rules (`firestore.rules`).
- **Event Workers:** Firebase Cloud Functions (Node.js 20).

---

## Key Directories

```
canteen_app/
├── lib/
│   ├── admin_console/
│   │   └── backend/              # FastAPI Server (Routes, Services, Repositories, Tests)
│   │       ├── features/         # Modular backend domains (orders, wallet, inventory, users)
│   │       ├── core/             # Auth dependencies, Firebase Admin singleton, config
│   │       └── tests/            # pytest suite (40+ test cases)
│   ├── user_console/             # Student ordering screens & order services
│   ├── staff_console/            # Canteen counter staff & admin terminal screens
│   ├── wallet/                   # Student wallet screens, models & read-only repository
│   ├── core/                     # ApiClient HTTP client, Idempotency utilities
│   ├── theme/                    # AppColors, AppTheme
│   └── main.dart                 # Application root & authentication state gate
├── test/                         # Flutter client unit & widget tests
├── tests/
│   └── rules/                    # Firestore Security Rules emulator test suite (Jest)
├── docs/                         # Engineering handbook & documentation
└── firestore.rules               # Locked Firestore security rules
```

---

## Cross-References
- [Project Constraints](file:///docs/agents/PROJECT_CONSTRAINTS.md)
- [Agent Instructions](file:///docs/agents/AGENT_INSTRUCTIONS.md)
- [Feature Implementation Protocol](file:///docs/agents/FEATURE_IMPLEMENTATION_PROTOCOL.md)
