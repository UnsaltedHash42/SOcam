# Case studies (real-world)

Each worksheet is a **structured worksheet**: questions, Hopper prompts, and vocabulary — not a second textbook. Use it alongside the **runnable PoC source** in [`../../../../labs/ch08-xpc/`](../../../../labs/ch08-xpc/) when your instructor runs that segment.

## Before you start

1. Use only **instructor-supplied** installers / VM images (Drive or class portal). **Do not** download random “old Zoom” or “old WiFiSpoof” builds from the open web for this unit.
2. **Snapshot the VM** before installing vulnerable-by-design software.
3. Symbols and Mach names **drift between releases** — always match Hopper prompts to the **exact** binary you were given.

## Tracks

| File | Topic | PoC / demo code in repo |
|------|--------|---------------------------|
| [cve-2021-44214-wifispoof.md](cve-2021-44214-wifispoof.md) | Third-party privileged helper, authorization mistakes | [`03_wifispoofexp.m`](../../../../labs/ch08-xpc/03_wifispoofexp.m) |
| [cve-2022-26712-packagekit.md](cve-2022-26712-packagekit.md) | System component / SIP-class move (**Monterey &lt; 12.4**) | [`04_shovexpc.m`](../../../../labs/ch08-xpc/04_shovexpc.m) |
| [zoom-583-lpe.md](zoom-583-lpe.md) | Installer daemon + TOCTOU (**Drive artifacts required**) | [`05_zoomxpc.m`](../../../../labs/ch08-xpc/05_zoomxpc.m), [`05_zoom_exploit_lab.sh`](../../../../labs/ch08-xpc/05_zoom_exploit_lab.sh) |

## Legal

Only analyze software you are **licensed** to run for security education. Your institution’s policy governs redistribution of installers.

## Instructors only

Cohort version pinning belongs in a **private** YAML (see `cohort-software.template.yaml`); do not commit filled paths to a **public** fork.
