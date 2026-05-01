# Chapter 8: XPC (student materials)

This folder is the **Markdown-first** spine for the macOS reverse-engineering unit on **XPC** and attacks against **privileged helpers**. It is designed so students can follow **without** the course PDF: everything needed for structure, exercises, and ethics is here or in `labs/`. **Instructor** talk-track: [`../../instructor/ch08-xpc/00_HOW_TO_TEACH_CH08.md`](../../instructor/ch08-xpc/00_HOW_TO_TEACH_CH08.md) (numbered `01_…`–`09_…` lectures walk the same repo code).

## What you need

- **macOS** (Apple Silicon or Intel) with **Xcode** or **Command Line Tools** (`xcode-select --install`).
- An **isolated VM** or dedicated lab machine for anything that loads **LaunchDaemons**, runs **root helpers**, or installs **vulnerable-by-design** binaries.
- **Instructor-supplied** follow-along packages for the **case studies** (exact builds, disk images, or VM snapshots). Paths and checksums live in private manifests derived from `case-studies/cohort-software.template.yaml` — do not commit filled YAML if it points to licensed DMGs.

### Lab artifacts (Google Drive)

**Instructor:** Replace the URL below with your shared folder (view or comment access for students). One folder can hold everything in the table.

**Students:** Download only what your instructor lists for your cohort; unzip/copy into `~/TeachingArtifacts/ch08/` or `resources/` as directed.

**[Chapter 8 lab artifacts — Google Drive](https://drive.google.com/drive/folders/REPLACE_WITH_YOUR_FOLDER_ID)** — *instructor: replace `REPLACE_WITH_YOUR_FOLDER_ID` with your shared folder ID (or paste the full `https://drive.google.com/...` URL as the link target).*

| Filename (typical) | Session / lab |
|--------------------|---------------|
| `ZoomInstallerIT-5.8.3.pkg` | Zoom 5.8.3 / `zoom_exploit_lab.sh` |
| `zoom.us.app-4.6.7.zip` | same |
| WiFiSpoof vulnerable installer (instructor-named) | WiFiSpoof / CVE-2021-44214 |
| `EvenBetterAuthorizationSample.zip` (optional) | EvenBetter pattern (Session F) |
| Monterey **&lt; 12.4** VM image or snapshot export | PackageKit Shove (Session H) |

Full rationale and optional course-wide files (Slack, MachOView, Cyberduck): [`../../../resources/README.md`](../../../resources/README.md).

## Repo layout (this chapter)

| Path | Audience | Purpose |
|------|----------|---------|
| [STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md) | Student | **One page:** lab paths, Mach names, copy-paste builds — use during class instead of transcribing |
| [STUDENT_GUIDE.md](STUDENT_GUIDE.md) | Student | Session order, concepts, labs, troubleshooting |
| [diagrams.md](diagrams.md) | Student | Figures (Mermaid) and whiteboard prompts |
| [ASSESSMENT.md](ASSESSMENT.md) | Student | Rubric and exit tickets |
| [case-studies/](case-studies/) | Student + instructor | Real-world tracks; instructor fills bundle YAML (private YAML gitignored) |

Answer keys (if used): keep private per [`FOR_INSTRUCTORS.md`](../../FOR_INSTRUCTORS.md); not required to complete labs.

## Labs (code)

| Path | Purpose |
|------|---------|
| [labs/ch08-c-xpc/README.md](../../../labs/ch08-c-xpc/README.md) | Minimal **C / libxpc** Mach service + client |
| [labs/ch08-pocs/README.md](../../../labs/ch08-pocs/README.md) | **NSXPC** minimal pair + **case-study PoCs** (WiFiSpoof / Shove / Zoom) — VM-only |
| [labs/xpc/README_STUDENT.md](../../../labs/xpc/README_STUDENT.md) | **Swift NSXPC** privileged helper + exploit |

## Ethics and safety

- Only attack **your own** VMs or **course-provided** targets.
- Do not point class exploits at **classmates’**, **production**, or **unknown** Mach services.
- After privileged labs, run **`uninstall_lab.sh`** (see Swift lab README) and delete marker files.

## Copyright note

This student guide is **standalone** teaching prose (no vendor PDF required). For API details, use Apple’s public headers (`xpc.h`, `connection.h`) and Apple documentation.
