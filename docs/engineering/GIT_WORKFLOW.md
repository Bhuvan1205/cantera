# Git Workflow & Branching Strategy

This document outlines the Git branching, commit conventions, and release management workflow for the repository.

---

## 1. Branching Model

```
main (Production)
  ▲
  │ PR (Squash & Merge / Release Tag)
staging (Staging & Pre-production QA)
  ▲
  │ PR (Approved & Verified)
feature/<feature-name>  /  fix/<issue-name>
```

- **`main`**: Protected branch representing live production. Direct pushes are disabled.
- **`staging`**: Integration branch for pre-production validation and smoke testing.
- **Feature Branches**: Created off `staging` or `main` using standard prefixes:
  - `feature/<name>`: New feature work
  - `fix/<name>`: Bug fixes
  - `chore/<name>`: Refactoring, dependencies, documentation

---

## 2. Commit Message Conventions
Follow Conventional Commits format:

```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

### Types
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation updates
- `test`: Adding or modifying tests
- `refactor`: Code refactoring without changing behavior
- `chore`: Tooling, build config, or dependency updates

### Examples
- `feat(orders): add multi-counter token routing endpoint`
- `fix(wallet): validate max deposit limit in backend schema`
- `test(security): add test for unauthenticated queue access`

---

## 3. PR Lifecycle
1. Branch from latest `staging`.
2. Implement feature adhering to the [Feature Development Guide](file:///docs/engineering/FEATURE_DEVELOPMENT_GUIDE.md).
3. Execute all automated tests.
4. Open PR with completed [Pull Request Template](file:///docs/engineering/PULL_REQUEST_TEMPLATE.md).
5. Pass CI checks (Flutter analyze/tests, Pytest, Rules).
6. Obtain approval and squash-merge.
