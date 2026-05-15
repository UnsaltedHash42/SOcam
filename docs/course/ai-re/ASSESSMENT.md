# AI-assisted reversing — optional practice

This cohort is **colleagues learning together**. Nothing here is scored, ranked, or required for a transcript. Use it if you want **extra reps** after the AI-assisted reversing lab or **conversation starters** when you are pairing with someone.

**Where the real "answers" live:** same repo paths and agent prompts as **[STUDENT_QUICK_REFERENCE.md](STUDENT_QUICK_REFERENCE.md)** and **[STUDENT_GUIDE.md](STUDENT_GUIDE.md)** — run from your per-target project clone when you want hands-on.

---

## Short prompts

1. Why is **`xpc_connection_get_pid`** alone a weak authorization boundary, and what does **`xpc_connection_get_audit_token`** fix? (Chapter 8 recap.)
2. What does the station's **three-tier evidence model** assume about decompiler output that grep does not?
3. In the planted daemon, **`com.apple.private.tcc.allow`** is the red herring. Name two things you would look at on **any** macOS binary before deciding a private entitlement is exploitable.
4. The triage state machine has **no `interesting` state**. Why is closing a candidate with rationale considered research output rather than a failure?
5. Session F may use `sudo` to open the **privileged** Mach name; Session H uses the **internal** name without `sudo`. Explain both results if you saw "connection invalid" on only one of them.
6. **`resetCacheAtPath:`** vs **`writeAuditLog:`** — which proved reachability, which proved root impact, and why do you need both for a credible report?

---

## lab extensions

- **Pass loop reps (planted daemon):** Re-run the lab from a fresh project clone but **don't** read your previous notes. Time how long the second pass takes vs the first; the gap is your indicator of where the discipline is sticking.
- **Confirm C-002 dynamically:** You confirmed `C-001` and `C-003` together in class via the `shouldAcceptNewConnection:` breakpoint and the `writeAuditLog` reply. C-002 (the methodID-0 bypass) is the candidate you did **not** confirm. Set an `lldb_run_anchors` breakpoint on `-[PrivilegedHandler authorizeMethodID:connection:]` with a watch on the `methodID` argument, then send a message with `methodID == 0` from the client. Capture the transcript, hash-pin as a new SCRIPTORIUM anchor, transition `C-002 → reproducing → confirmed`.
- **Trust framing (no new code):** Write five bullets — "If I were shipping this daemon tomorrow, what would I change to block our PoC?" Compare notes with a partner; steal each other's best bullet.
- **Tier triage drill:** Pick **one** unfamiliar binary on your lab host (e.g. `/usr/libexec/secinitd` or a third-party menubar app's helper). Run intake + watch. Do not run any scan beyond what the watch layer recommends. Stop after one recipe and write the dossier summary in your own words.
- **Lab II — multi-binary bundle pass:** A full follow-up lab against `PluginHost.app`. Walkthrough at [`LAB_II.md`](LAB_II.md). 45–60 min. Different target shape, different bug class, different intake behavior — the most useful single thing to do after class.

---

## Stretch ideas

- From the station's **skill index** (`Skills/` in the cloned repo), open three skills you didn't touch in class — `offensive-macos-hunt-iokit-userclient`, `offensive-macos-hunt-private-framework-hijack`, `offensive-macos-hunt-tcc-prompt-attribution`. For each, write one sentence: what surface does the skill assume, and which `scan_*.py` does it pair with?
- In prose only: how would you **harden** `-[DaemonDelegate listener:shouldAcceptNewConnection:]` for a two-listener daemon where each listener carries a different exported interface? (Step list + Security framework API names; no obligation to ship code.)
- Sketch a third bug class the planted daemon could plausibly hide but currently does **not** — and the scan recipe you would write to find it. Rationale is the exercise.

If your group wants a private "answer sheet" for prompts above, keep it wherever you already share cohort notes — nothing in this repo needs to mirror a formal key.
