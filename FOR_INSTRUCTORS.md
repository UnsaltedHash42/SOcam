# For instructors (read before pushing to GitHub)

This repository is organized so **`git clone`** gives students **labs + student docs** without OffSec PDFs, proprietary course text mirrors, or your speaker scripts.

## What never goes to the student remote

**Entire `instructor/` directory** (including `instructor/ch08-xpc/` voice tracks: `00`, `01_…`–`09_`, `MASTER_*`, optional `module_09_xpc.md`, `LESSON_SCRIPT.md`, etc.) is **`.gitignore`d** and **never pushed**. After `git clone`, recreate **`instructor/ch08-xpc/`** from backup/LMS or copy from **`instructor_private/ch08-xpc/`**. **`labs/ch08-xpc/`** (student lab sources) stays tracked here. Treat any **public** fork as student-safe: no speaker scripts on the remote.

The root **`.gitignore`** still excludes:

- **`instructor/`** — whole tree; do not `git add -f` paths under it.
- `exp-312.pdf`, `exp-312.md` — keep on your laptop or LMS; do not rely on git for OffSec redistribution policy.
- `module_09_xpc.md` — moved under **`instructor_private/`** (copy there; root copy removed from the canonical tree).
- **`instructor_private/`** — lesson scripts, answer keys, cohort YAML with DMG paths.
- **`resources/*`** except `resources/README.md` — Slack.app, MachOView, zips, VM disks.
- **`socam_from_git/`**, **`Callandor/`** — nested clones / unrelated projects.
- **`docs/plans/`** — internal planning (optional: delete this line from `.gitignore` if you use a private monorepo).

## First-time machine setup

1. `git clone` this repo.
2. Create **`instructor_private/`** and restore files from your backup (see `instructor_private/README.md`).
3. Drop large apps under **`resources/`** per `resources/README.md`.
4. Keep **`exp-312.md`** / PDF next to the repo or in LMS if your license allows — **do not** `git add` them.

## Big binaries for students

GitHub is a poor CDN. Prefer:

- **Google Drive** (or similar): student-facing filenames are summarized in **`docs/course/ch08-xpc/README.md`** (*Lab artifacts* table) and **`resources/README.md`**; your private **`MASTER_CH08_INSTRUCTOR.md`** §15 duplicate (under `instructor_private/ch08-xpc/`) can hold extra bailout detail. Paste your folder URL into **`docs/course/ch08-xpc/README.md`** by replacing `REPLACE_WITH_YOUR_FOLDER_ID` in the markdown link (or point students to LMS only and strip the placeholder from a private fork).
- **GitHub Releases** (attach a `.zip` / `.dmg` per cohort; students download release asset), or
- **Org file share** (S3, internal artifact server) linked from LMS, or
- **Git LFS** only if your org pays for bandwidth and you enforce quotas.

## One remote workflow

- **Single public (or org-internal) repo**: what is tracked **is** the student bundle. Your voice tracks live under **`instructor/`** and **`instructor_private/`** on disk only (both ignored); local-only PDFs stay out of git.
- If you need **backup** of instructor files on GitHub too, use a **second private repository** or a **private branch** on a paid/org plan — do not push `instructor_private/` to a student-visible remote.

## Verify before `git push`

```bash
./scripts/verify-student-repo.sh
```

Fix any reported paths before pushing.

## Chapter 8 filenames to restore locally (not in `git clone`)

Create **`instructor/ch08-xpc/`** (or **`instructor_private/ch08-xpc/`**) and drop in:

- `00_HOW_TO_TEACH_CH08.md`
- `01_what_is_xpc.md` … `09_wrap_and_swift_capstone.md`
- `MASTER_CH08_INSTRUCTOR.md`
- optionally `module_09_xpc.md`, `LESSON_SCRIPT.md`, answer keys or cohort YAML (**never** commit filled cohort paths to this remote)
