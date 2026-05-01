# Lab resources (local only)

Large binaries **are not stored in git** (GitHub file limits, repo bloat, licensing). Put them here on your own machine or VM.

## What to place in this folder

| Artifact | Purpose | How to obtain |
|----------|---------|----------------|
| **Slack.app** | Mach / Electron RE target (example) | Install from vendor DMG, or copy `.app` from `/Applications` |
| **MachOView** (or similar) | Static analysis GUI | Download release you are licensed to use |
| **Cyberduck.app** | Dylib injection lab target | **Direct-download** build only — see `labs/dylib-injection/README.md` |

## Optional class mirror

If your instructor shares a **Google Drive / internal portal** link for frozen lab builds, download archives into `resources/` (still gitignored).

Example (from a legacy class README — replace with your current link):

- `https://drive.google.com/...` — *instructor maintains*

## Git

Everything under `resources/` except this `README.md` is ignored by the root `.gitignore`.
