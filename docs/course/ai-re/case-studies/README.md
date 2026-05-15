# Case study: planted daemon (in-repo)

This folder holds the **structured worksheet** for the primary in-class lab. It is the ai-re equivalent of Chapter 8's `case-studies/*.md` tracks: questions, session mapping, and vocabulary — not a second textbook.

**Runnable target:** `templates/tutorial-target/bin/tutorial_daemon` in the [mac-reversing-station](https://github.com/UnsaltedHash42/mac-reversing-station) repo (no Drive download).

**Teaching order:** [STUDENT_GUIDE.md](../STUDENT_GUIDE.md) Sessions C–H+ · agent prompts in [STUDENT_QUICK_REFERENCE.md](../STUDENT_QUICK_REFERENCE.md).

## Before you start

1. Use a **disposable lab VM** — the lab installs a LaunchDaemon under `/Library` and runs root-context PoCs.
2. Fill in **`LAB_SAFETY.md`** in your per-target project clone before any dynamic step.
3. Do **not** read `tutorial_daemon.m` until after triage (Session E) unless your instructor says otherwise — the worksheet is written to stand without spoilers.

## Track

| File | Topic | Station path |
|------|--------|--------------|
| [tutorial-daemon-planted.md](tutorial-daemon-planted.md) | Wrong-door XPC daemon, red herring entitlement, chain to root file delete | `templates/tutorial-target/` |

## Legal / ethics

Only analyze the **course-provided** planted binary on machines you are allowed to modify. Do not point station tooling at production or classmates' systems.
