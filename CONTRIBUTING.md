# Contributing to Neopop

We welcome contributions of all kinds — bug reports, feature ideas, documentation improvements, and code changes.

## How to Contribute

### 1. Reporting Issues

- Use the [issue tracker](https://github.com/normenmueller/neopop/issues) for bugs, feature requests, and questions.
- Include:
  - Neopop version and Neo4j version
  - Steps to reproduce
  - Expected and actual behavior
- **For security vulnerabilities**: use GitHub’s *Private vulnerability reporting* instead of opening a public issue.

### 2. Submitting Changes

1. **Fork** the repository and create a branch from `trunk`.
2. Make your changes in small, logically separated commits.
3. Write clear commit messages (imperative mood, short first line).
4. Submit a **pull request** (PR) against the `trunk` branch.
5. Reference related issues in the PR description.

### 3. Code Guidelines

- Keep CLI interface minimal and intuitive.
- Avoid introducing hard dependencies; prefer optional features.
- Follow existing code style and naming conventions.
- Add/update tests where applicable.

### 4. Design Changes

- For non-trivial changes (e.g., altering core behavior), submit an **Architectural Decision Record (ADR)** in `doc/adl.md` before implementing.
- Discuss significant design proposals in an issue or draft PR.

### 5. Documentation

- Keep README concise; move extensive guides to `docs/` or dedicated files.
- Update relevant documentation when making changes.

## Licensing

By contributing to Neopop, you agree that your contributions will be licensed under the [LICENSE](LICENSE).

---

Thank you for helping improve Neopop!

