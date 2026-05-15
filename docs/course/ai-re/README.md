# AI-assisted reversing (macOS Reversing Station)

In this course repo the **whole class pack** is this directory: `docs/course/ai-re/` (all `.md` files below are the student docs). If you only opened `labs/ai-re/README.md`, that file is a stub; **come back here.**

Off-cycle unit between Chapter 8 (XPC) and Chapter 9. You use an agent plus the [mac-reversing-station](https://github.com/UnsaltedHash42/mac-reversing-station) repo to run a full pass on a planted XPC daemon.

**Copy-paste lab setup (SSH, `setup-keep.sh`, smoke):** [**SETUP.md**](SETUP.md)

**Start here (full narrative):** [STUDENT_GUIDE.md](STUDENT_GUIDE.md) — Session 0 matches `SETUP.md` step-for-step.

**In class:** keep [STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md) open for agent prompts.

**Prerequisite:** Chapter 8 Sessions A–D ([`../ch08-xpc/STUDENT_GUIDE.md`](../ch08-xpc/STUDENT_GUIDE.md)) if you are new to XPC.

---

## What you need

- Mac with Cursor or Claude Code (workstation)
- macOS VM with SSH (lab host) — Apple Silicon guest recommended
- Two git clones of `mac-reversing-station` (see Session 0 in the guide)
- Planted daemon is **already built** in the station repo: `templates/tutorial-target/bin/tutorial_daemon` (no compile step for class)

---

## Files in this folder

| File | Use |
|------|-----|
| [SETUP.md](SETUP.md) | **SSH config, `setup-keep.sh`, verify commands** — one-page copy-paste |
| [STUDENT_GUIDE.md](STUDENT_GUIDE.md) | Full walkthrough + why |
| [STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md) | Agent prompts + Plan-B shell |
| [diagrams.md](diagrams.md) | Topology and pass loop |
| [case-studies/tutorial-daemon-planted.md](case-studies/tutorial-daemon-planted.md) | Worksheet |
| [ASSESSMENT.md](ASSESSMENT.md) | Optional homework |
| [LAB_II.md](LAB_II.md) | Optional follow-up (`PluginHost.app`) |

Station install stub: [`labs/ai-re/README.md`](../../../labs/ai-re/README.md).

---

## SSH config (copy-paste)

On your **workstation**, edit `~/.ssh/config`. Change IP and username:

```
Host lab-mac
  HostName 192.168.64.2
  User student
  ServerAliveInterval 30
```

Then: `ssh lab-mac 'uname -m; sw_vers -productVersion'` (password OK once).

Full setup (**all steps**): [**SETUP.md**](SETUP.md) · checklist + narrative [STUDENT_GUIDE Session 0](STUDENT_GUIDE.md#session-0--lab-setup-do-these-steps-in-order).

---

## Safety

Use a disposable VM. Fill `LAB_SAFETY.md` before dynamic work. Tear down the planted daemon after class ([QUICK_REFERENCE](STUDENT_QUICK_REFERENCE.md) tear-down section).
