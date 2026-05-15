# macOS reverse engineering — course materials

Student-facing labs and guides for an in-house macOS RE series. **Clone this repo before class** and follow the module index below.

## Start here

| Module | Topic | Student entry |
|--------|--------|-----------------|
| 02 | Mach task injection → dylib injection | [`labs/dylib-injection/README.md`](labs/dylib-injection/README.md) · theory [`session_dylib_injection.md`](session_dylib_injection.md) |
| 02b | Mach ports scratch / class examples | [`labs/machports/README.md`](labs/machports/README.md) |
| — | Mach / microkernel lecture notes | [`mach_microkernel_master_class.md`](mach_microkernel_master_class.md) |
| 08 | XPC attacks (Apple Silicon track) | [`docs/course/ch08-xpc/README.md`](docs/course/ch08-xpc/README.md) |
| — | **AI-assisted RE** (agent + Reversing Station) | **Guides live in** [`docs/course/ai-re/`](docs/course/ai-re/) — start [`STUDENT_GUIDE.md`](docs/course/ai-re/STUDENT_GUIDE.md) · [`STUDENT_QUICK_REFERENCE.md`](docs/course/ai-re/STUDENT_QUICK_REFERENCE.md). *Not* under `labs/ai-re/` (that folder is a pointer only). |

More modules will be linked under [`docs/course/README.md`](docs/course/README.md) as they are backfilled.

## Large software (Slack, MachOView, Cyberduck, …)

Binaries are **not** in git. Read [`resources/README.md`](resources/README.md) and install artifacts locally or from your instructor’s download link.

## Repo layout

```
labs/
  dylib-injection/     # Primary dylib / shellcode lab (use this path)
  machports/           # Extra Mach port samples from class
  ch08-xpc/            # Chapter 8 — all XPC labs (`01_`–`06_*` sources in one folder)
  ai-re/               # Pointer only → real student prose in docs/course/ai-re/
docs/
  course/
    ch08-xpc/          # XPC student guide, diagrams, assessment, case worksheets
    ai-re/             # AI-assisted RE: STUDENT_GUIDE, QUICK_REFERENCE, worksheet, LAB_II
```

## License / course text

This repo does **not** include vendor course PDFs or proprietary manuals. Use only what your organization is licensed to teach.

## Chapter 8 lab sources (in repo)

- **Runnable XPC teaching code (C / NSXPC / PoCs / Swift):** [`labs/ch08-xpc/README.md`](labs/ch08-xpc/README.md)
