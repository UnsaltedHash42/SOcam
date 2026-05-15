# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Course materials for an in-house macOS reverse-engineering series: student-facing Markdown guides plus runnable lab code (Mach injection, dylib injection, XPC). It is **not** an application — there is no top-level build, test, or lint, and no CI. "Building" means compiling individual lab sources from their lab folder; "testing" means running the lab on a macOS VM and observing the documented effect (file appearing in `~/Library/Colors/`, log line, etc.).

## Public/private boundary — must respect before any commit

`.gitignore` enforces a strict student-vs-instructor split. The following must **never** end up in the tracked tree (the gitignore covers them, but new files added in the wrong place will leak):

- `instructor/`, `instructor_private/`, `FOR_INSTRUCTORS.md`, `instructor_notes.md`, `instructor_master_class.md`, `module_09_xpc.md`
- `exp-312.pdf`, `exp-312.md`, `exp-312-assets/` (vendor course material)
- `resources/**` except `resources/README.md` and `resources/.gitkeep` (large third-party binaries — Slack, MachOView, Cyberduck — are downloaded locally, not committed)
- `docs/plans/` (internal planning)
- Any nested `.git/` from a sibling clone

Run `./scripts/verify-student-repo.sh` from the repo root before pushing — it fails if any forbidden path is in the index. Run it whenever you stage files that might cross the line.

When the user asks for "instructor" content, that work goes under `instructor/` or `instructor_private/` (gitignored) — do not move it into `docs/` or `labs/` without explicit instruction.

## Big-picture layout

Two parallel trees:

- **Student spine (Markdown):** `README.md` → `docs/course/README.md` → per-chapter folders under `docs/course/`. Published chapters: `ch08-xpc/`, `ai-re/`; earlier modules link directly to lab READMEs and root-level narrative docs (`session_dylib_injection.md`, `mach_microkernel_master_class.md`, `lab_guide.md`, `deep_dive_guide.md`, `dylib.md`).
- **Runnable code:** `labs/<module>/`. Each lab folder has its own `README.md` with the canonical build/run/teardown commands — those READMEs are authoritative; do not duplicate their command sequences elsewhere.

Module ↔ folder map (when in doubt, the tables in `README.md` and `docs/course/README.md` are the source of truth):

| Module | Code | Student doc |
|--------|------|-------------|
| 02 — dylib injection | `labs/dylib-injection/{01_shellcode_inject,02_dylib_inject}/` | `session_dylib_injection.md` (root) |
| 02b — Mach ports scratch | `labs/machports/` | `labs/machports/README.md` |
| 08 — XPC (all sessions) | `labs/ch08-xpc/` (single folder, files prefixed `01_`–`06_`) | `docs/course/ch08-xpc/{README,STUDENT_GUIDE,STUDENT_QUICK_REFERENCE,ASSESSMENT,diagrams}.md` + `case-studies/` |
| AI-assisted RE (off-cycle) | Station repo `mac-reversing-station` (clone per student; see `labs/ai-re/README.md`) | `docs/course/ai-re/{README,STUDENT_GUIDE,STUDENT_QUICK_REFERENCE,ASSESSMENT,diagrams,LAB_II}.md` + `case-studies/` |

Stub folders like `lab_dylib_injection/` exist only so old links don't 404 — don't put new content there.

## Building lab code

There is no Makefile. Each source compiles standalone from inside its lab folder. Common patterns (full sequences live in the lab READMEs):

- C XPC sources need `-fblocks`: `clang -fblocks -o 01_xpcserver 01_xpcserver.c`
- Objective-C with ARC + frameworks: `gcc -fobjc-arc -framework Foundation [-framework Security] file.m -o out`
- Apple Silicon ARM64 shellcode: `as shellcode.asm -o shellcode.o`, then `dd` the `__text` section out of the Mach-O and `xxd -i` it into the injector source (the `OFFSET=$(otool -l ... )` snippet in `labs/dylib-injection/README.md` is the canonical extraction recipe).
- Swift NSXPC capstone: `swiftc 06_exploit.swift -o exploit`; helper build/install handled by `06_install_lab.sh`.
- PackageKit private framework (Monterey lab): link `"$(xcrun --show-sdk-path)/System/Library/PrivateFrameworks/PackageKit.framework/PackageKit.tbd"`.

## Runtime context the labs assume

These are not optional — they are why a lab silently fails:

- Run **inside an isolated macOS VM**, not the host. Several labs install LaunchDaemons or vulnerable-by-design helpers under `/Library/LaunchDaemons/`.
- Most injection/helper labs need **root** (`sudo`).
- `task_for_pid` requires **SIP disabled** (`csrutil status` → `disabled`, or at minimum `csrutil enable --without debug`) on macOS 14+ targeting Hardened Runtime processes.
- The dylib lab targets **direct-download Cyberduck 9.4.1** (TeamIdentifier `G69SCX94XU`). The Mac App Store build is sandboxed and will not accept injection — verifying the team ID is part of lab setup.
- XPC case-study labs (`03_`–`05_`) target specific OS versions / vendor builds (e.g. Monterey < 12.4 for Shove, Sonoma-class VM for the Zoom installer race). Don't "fix" them on a newer OS — the OS version is the vulnerability.
- After privileged labs, run the matching uninstall script (e.g. `06_uninstall_lab.sh`) and remove any plist under `/Library/LaunchDaemons/`.

## Editing conventions specific to this repo

- The student-facing tone in `docs/` and `labs/*/README.md` is plain imperative ("download", "compile", "verify"). Match it; don't add marketing language to teaching prose.
- Lab README command blocks are copy-pasted verbatim by students in class. Preserve exact paths, env-var names, and `sudo` placement when editing — a "cleanup" that breaks copy-paste is a regression.
- Mach service names (`com.example.student.xpc`, `com.offsec.nsxpc`, `com.example.vulnerablehelper`) are referenced from both plist templates and source code. Renaming one without the others breaks the lab.
- Files in `labs/machports/` keep their historical class spellings (e.g. `reciver.c`) — do not silently rename.
- `scripts/pdf_to_markdown_exp312.py` is a one-off converter for the gitignored vendor PDF; it is currently untracked and should stay that way unless explicitly asked to commit it.
