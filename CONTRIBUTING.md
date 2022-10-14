# Contributing to Lattice

Thank you for your interest in contributing to Lattice. Lattice is engineered to institutional software engineering standards. Please review the following guidelines before submitting pull requests.

---

## 1. Code Standards and Smalltalk Conventions

- **ANSI Smalltalk Compliance**: All core classes must conform strictly to ANSI Smalltalk semantics and execute cleanly under GNU Smalltalk (`gst`).
- **Turn Isolation**: Virtual actor grains must not introduce shared-memory concurrency, locks, or unprotected state mutations. All state changes must occur within single-threaded turns.
- **Message Dispatch**: Prefer polymorphic message dispatch over explicit conditional type checking (`isKindOf:` should only be used in serialization and structural equality).
- **Comments and Documentation**: Every class must include an introductory header comment describing its purpose, invariants, and threading model. All public methods must document their contract.
- **Zero Forbidden Characters**: Do not use em dashes or en dashes in any comments, docs, or code. Use standard ASCII hyphens, colons, or parentheses.

---

## 2. Test-Driven Development and Bug Resolution

Every bug fix or feature addition must adhere to the following protocol:
1. Write a unit or integration test reproducing the issue or verifying the new capability.
2. Verify that the test initially fails.
3. Implement the minimal, robust code change resolving the issue.
4. Verify that all test suites pass without regression:
   ```bash
   make test
   make verify
   ```

---

## 3. Commit Message Conventions

Commit messages must adhere to the Conventional Commits specification:
```
<type>(<scope>): <short description in lowercase>
```

Types:
- `feat`: A new user-facing capability or subsystem component
- `test`: Addition or modification of unit, integration, or stress tests
- `bench`: Performance benchmarks and profiling harnesses
- `docs`: Documentation, architecture diagrams, and guides
- `build`: Build system, Makefile, or compiler configuration changes
- `chore`: Scaffolding, repository housekeeping, and linting

---

## 4. Verification Pass

Before submitting a pull request, run the hard verification pass:
```bash
python3 scripts/verify_project.py
```
This script executes:
- Zero-em-dash static analysis across all files
- Native C library tests (`test-native`)
- Smalltalk unit tests (`test-unit`)
- Multi-node loopback integration tests (`test-integration`)
- Jepsen-style fault-injection stress tests (`test-stress`)
- Python client test suite (`test-python`)
