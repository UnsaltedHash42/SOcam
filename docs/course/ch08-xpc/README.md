# Chapter 8: XPC (student materials)

This folder is the **Markdown-first** spine for the macOS reverse-engineering unit on **XPC** and attacks against **privileged helpers**. It is designed so students can follow **without** the course PDF: everything needed for structure, exercises, and ethics is here or in `labs/`.

## What you need

- **macOS** (Apple Silicon or Intel) with **Xcode** or **Command Line Tools** (`xcode-select --install`).
- An **isolated VM** or dedicated lab machine for anything that loads **LaunchDaemons**, runs **root helpers**, or installs **vulnerable-by-design** binaries.
- **Instructor-supplied** follow-along packages for the **case studies** (exact builds, disk images, or VM snapshots). Paths and checksums live in private manifests derived from `case-studies/cohort-software.template.yaml` — do not commit filled YAML if it points to licensed DMGs.

## Repo layout (this chapter)

| Path | Audience | Purpose |
|------|----------|---------|
| [STUDENT_GUIDE.md](STUDENT_GUIDE.md) | Student | Session order, concepts, labs, troubleshooting |
| [diagrams.md](diagrams.md) | Student | Figures (Mermaid) and whiteboard prompts |
| [ASSESSMENT.md](ASSESSMENT.md) | Student | Rubric and exit tickets |
| [case-studies/](case-studies/) | Student + instructor | Real-world tracks; instructor fills bundle YAML (private YAML gitignored) |

Instructor talk tracks and answer keys: **`instructor_private/`** (see [`FOR_INSTRUCTORS.md`](../../FOR_INSTRUCTORS.md)).

## Labs (code)

| Path | Purpose |
|------|---------|
| [labs/ch08-c-xpc/README.md](../../../labs/ch08-c-xpc/README.md) | Minimal **C / libxpc** Mach service + client |
| [labs/xpc/README_STUDENT.md](../../../labs/xpc/README_STUDENT.md) | **Swift NSXPC** privileged helper + exploit |

## Ethics and safety

- Only attack **your own** VMs or **course-provided** targets.
- Do not point class exploits at **classmates’**, **production**, or **unknown** Mach services.
- After privileged labs, run **`uninstall_lab.sh`** (see Swift lab README) and delete marker files.

## Copyright note

This student guide is **standalone** teaching prose (no vendor PDF required). For API details, use Apple’s public headers (`xpc.h`, `connection.h`) and Apple documentation.
