# Chapter 8 — assessment

## Rubric (100 points — instructor may reweight)


| Criterion                                               | Excellent (4)                              | Adequate (2)       | Weak (0)                       |
| ------------------------------------------------------- | ------------------------------------------ | ------------------ | ------------------------------ |
| **R-A1** Explains Mach vs XPC vs NSXPC in one paragraph | Clear layering + dictionary rule           | Partially confused | Wrong or missing               |
| **R-A2** C lab: client/server + plist lifecycle         | Runs end-to-end; explains listener flag    | Runs with help     | Fails                          |
| **R-A3** Trust checklist                                | Names ≥4 distinct checks with rationale    | 2–3 vague items    | PID-only or “signing” handwave |
| **R-A4** Capstone Swift lab                             | Exploit + cleanup; explains missing auth   | Exploit only       | No demo                        |
| **R-A5** One case study worksheet                       | Accurate to **instructor-supplied** binary | Partial            | Off-target                     |


## Exit tickets (5 minutes each)

1. **ET-1:** Why is `xpc_connection_get_pid` alone a weak authorization boundary?
2. **ET-2:** What does `XPC_CONNECTION_MACH_SERVICE_LISTENER` change about `xpc_connection_create_mach_service`?
3. **ET-3:** In NSXPC, where is the first place an app should decide “is this peer allowed to talk to me?”

## Practical exam ideas (instructor)

- Given `strings` / `nm` output from a helper binary, identify the **Mach service name** and one **Objective-C class** involved in IPC.
- Short answer: describe how you would **patch** `shouldAcceptNewConnection:` to enforce a team-ID requirement (no full code — steps and API names).

Answer key (if used): keep in `instructor_private/ch08-xpc/ASSESSMENT_KEY.md` (gitignored) and **exclude** from student archives.