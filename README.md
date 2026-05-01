# macOS reverse engineering — course materials

Student-facing labs and guides for an in-house macOS RE series. **Clone this repo before class** and follow the module index below.

## Start here

| Module | Topic | Student entry |
|--------|--------|-----------------|
| 02 | Mach task injection → dylib injection | [`labs/dylib-injection/README.md`](labs/dylib-injection/README.md) · theory [`session_dylib_injection.md`](session_dylib_injection.md) |
| 02b | Mach ports scratch / class examples | [`labs/machports/README.md`](labs/machports/README.md) |
| — | Mach / microkernel lecture notes | [`mach_microkernel_master_class.md`](mach_microkernel_master_class.md) |
| 08 | XPC attacks (Apple Silicon track) | [`docs/course/ch08-xpc/README.md`](docs/course/ch08-xpc/README.md) |

More modules will be linked under [`docs/course/README.md`](docs/course/README.md) as they are backfilled.

## Large software (Slack, MachOView, Cyberduck, …)

Binaries are **not** in git. Read [`resources/README.md`](resources/README.md) and install artifacts locally or from your instructor’s download link.

## Repo layout

```
labs/
  dylib-injection/     # Primary dylib / shellcode lab (use this path)
  machports/           # Extra Mach port samples from class
  ch08-c-xpc/          # C libxpc Mach service lab (Chapter 8)
  xpc/                 # Swift NSXPC privileged-helper lab
docs/
  course/
    ch08-xpc/          # XPC student guide, diagrams, assessment, case worksheets
```

## License / course text

This repo does **not** include vendor course PDFs or proprietary manuals. Use only what your organization is licensed to teach.

## Instructors

- **Chapter 8 (full voice lectures, in order):** start at [`instructor/ch08-xpc/00_HOW_TO_TEACH_CH08.md`](instructor/ch08-xpc/00_HOW_TO_TEACH_CH08.md), then teach from [`01_what_is_xpc.md`](instructor/ch08-xpc/01_what_is_xpc.md) through [`09_wrap_and_swift_capstone.md`](instructor/ch08-xpc/09_wrap_and_swift_capstone.md).
- **Chapter 8 cheat sheet (bailouts / Drive filenames only):** [`instructor/ch08-xpc/MASTER_CH08_INSTRUCTOR.md`](instructor/ch08-xpc/MASTER_CH08_INSTRUCTOR.md)
- **Org workflow / git hygiene:** [`FOR_INSTRUCTORS.md`](FOR_INSTRUCTORS.md)
- **Reference POC sources (WiFiSpoof / Shove / Zoom / NSXPC demo):** [`labs/ch08-pocs/README.md`](labs/ch08-pocs/README.md)
