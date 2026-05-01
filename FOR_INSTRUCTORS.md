# For instructors (read before pushing to GitHub)

This repository is organized so **`git clone`** gives students **labs + student docs** without OffSec PDFs, proprietary course text mirrors, or your speaker scripts.

## What never goes to the student remote

**Org-private repo:** `instructor/ch08-xpc/` (MASTER sheet, `module_09_xpc.md`) and `labs/ch08-pocs/` (reference POCs) are **tracked** for staff + enrolled students on the same GitHub — still classroom-only; do not mirror to a **public** fork without stripping them.

The root **`.gitignore`** still excludes:

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

- **GitHub Releases** (attach a `.zip` / `.dmg` per cohort; students download release asset), or
- **Org file share** (Drive, S3, internal artifact server) linked from LMS, or
- **Git LFS** only if your org pays for bandwidth and you enforce quotas.

## One remote workflow

- **Single public (or org-internal) repo**: what is tracked **is** the student bundle. Your private notes stay untracked in `instructor_private/` and local-only PDFs.
- If you need **backup** of instructor files on GitHub too, use a **second private repository** or a **private branch** on a paid/org plan — do not push `instructor_private/` to a student-visible remote.

## Verify before `git push`

```bash
./scripts/verify-student-repo.sh
```

Fix any reported paths before pushing.
