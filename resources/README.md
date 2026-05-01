# Lab resources (local only)

Large binaries **are not stored in git** (GitHub file limits, repo bloat, licensing). Put them here on your own machine or VM.

## What to place in this folder

| Artifact | Purpose | How to obtain |
|----------|---------|----------------|
| **Slack.app** | Mach / Electron RE target (example) | Install from vendor DMG, or copy `.app` from `/Applications` |
| **MachOView** (or similar) | Static analysis GUI | Download release you are licensed to use |
| **Cyberduck.app** | Dylib injection lab target | **Direct-download** build only — see `labs/dylib-injection/README.md` |

## Optional class mirror (Google Drive)

If your instructor shares a **Google Drive** (or LMS) link for frozen lab builds, download archives into `resources/` (still gitignored). **Canonical filename list** for what belongs on Drive vs in git: **`instructor/ch08-xpc/MASTER_CH08_INSTRUCTOR.md`** §15 and **`docs/course/ch08-xpc/README.md`** (student link placeholder).

### Quick list — Chapter 8 artifacts (large / licensed)

| File / artifact | Why on Drive |
|-----------------|--------------|
| `ZoomInstallerIT-5.8.3.pkg` | Zoom LPE lab script expects this **exact** name in cwd. |
| `zoom.us.app-4.6.7.zip` | Old Zoom app bundle for dylib path in same lab. |
| WiFiSpoof vulnerable installer (your pinned `.dmg` / `.pkg`) | CVE-2021-44214 Hopper + `wifispoofexp` VM. |
| `EvenBetterAuthorizationSample.zip` | Session F reference (Apple sample or your mirror). |
| Monterey **&lt; 12.4** VM snapshot / OVA | PackageKit Shove PoC (`shovexpc`). |

### Quick list — other modules (same Drive folder is fine)

| Typical local folder | Purpose |
|---------------------|---------|
| `Slack.app/` | Mach / Electron RE labs. |
| `MachOView.app` | Static analysis. |
| `Cyberduck.app` | Dylib injection lab — vendor direct-download build only. |

**Student link:** instructor replaces `REPLACE_WITH_YOUR_FOLDER_ID` in **`docs/course/ch08-xpc/README.md`** (or uses LMS-only link and removes the broken placeholder from the tracked README in a private fork).

## Git

Everything under `resources/` except this `README.md` is ignored by the root `.gitignore`.
