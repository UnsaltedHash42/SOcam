# Case studies (real-world)

Each worksheet assumes you are using **instructor-supplied** software builds (VM image, `.dmg`, or folder). **Do not** hunt random installers from the web in class.

## Before you start

1. Copy `cohort-software.template.yaml` to a **private** file under `instructor-bundles/` (gitignored) listing version, SHA-256, and paths for each cohort.
2. Snapshot the VM **before** installing old vulnerable builds.
3. Validate every **Hopper / lldb** prompt in the worksheet against the **exact** binary you were given — symbols and Mach names drift across releases.

## Tracks

| File | Topic |
|------|--------|
| [cve-2021-44214-wifispoof.md](cve-2021-44214-wifispoof.md) | Third-party privileged helper, authorization mistakes |
| [cve-2022-26712-packagekit.md](cve-2022-26712-packagekit.md) | System component / trust boundary (historical macOS) |
| [zoom-583-lpe.md](zoom-583-lpe.md) | Third-party helper surface (historical Zoom build) |

## Legal

Only analyze software you are **licensed** to run for security education. Your institution’s policy governs redistribution of installers.
