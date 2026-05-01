# Chapter 8 — optional practice (no grades)

This cohort is **colleagues learning together**. Nothing here is scored, ranked, or required for a transcript. Use it if you want **extra reps** after class or **conversation starters** when you are pairing with someone.

**Where the real “answers” live:** same repo paths and Mach names as **[STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md)** and **[STUDENT_GUIDE.md](STUDENT_GUIDE.md)** — build and run from `labs/ch08-xpc/` when you want hands-on.

---

## Short prompts (good over coffee or Slack)

1. Why is **`xpc_connection_get_pid`** alone a weak authorization boundary?
2. What does **`XPC_CONNECTION_MACH_SERVICE_LISTENER`** change about **`xpc_connection_create_mach_service`**?
3. In NSXPC, where is the **first** place an app should decide whether a peer is allowed to talk to the helper?

---

## Optional lab extensions (pick what sounds fun)

- **C (`01_*`):** Add a second message type (e.g. a string key in the dictionary and a personalized reply). Rebuild, reinstall, confirm in **`launchctl print`**.
- **NSXPC (`02_*`):** Add a second method to the shared protocol (client + server must stay in lockstep — you will feel why “one shared header” exists).
- **Trust framing (no new code):** Write five bullets: “If I were shipping this helper tomorrow, what would I check **before** returning `YES` from `shouldAcceptNewConnection:`?” Compare notes with a partner; steal each other’s best bullet.
- **Swift capstone (`06_*`):** After you have run install → exploit → uninstall once, skim **`06_VulnerableHelper.swift`** and describe **one** concrete change that would block an arbitrary client (API names are enough; full implementation optional).
- **Case studies:** Finish one worksheet under **`case-studies/`** on paper or in a doc — the value is **articulating** reach / trust failure / primitive, not matching a model answer.

---

## Stretch ideas (self-paced or small groups)

- From **`strings`** / **`nm`** (or Hopper) on a helper you are allowed to analyze, note the **Mach service name** and one **Objective-C** symbol tied to IPC.
- In prose only: how would you **harden** `listener:shouldAcceptNewConnection:` for a known team ID? (Steps + Security framework API names; no obligation to ship code.)

If your group wants a private “answer sheet” for prompts above, keep it wherever you already share cohort notes — nothing in this repo needs to mirror a formal key.
