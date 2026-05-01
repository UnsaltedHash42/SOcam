# Case study: Zoom 5.8.3 — local privilege escalation (historical)

**Prerequisite:** Instructor supplies the **specific Zoom build** (or VM with it pre-installed) for static analysis only unless they explicitly enable dynamic exploitation labs.

**Repo (class narration):** [`zoom_exploit_lab.sh`](../../../../labs/ch08-pocs/zoom_exploit_lab.sh) + [`zoomxpc.m`](../../../../labs/ch08-pocs/zoomxpc.m) — requires Drive files named in the script header.

## Learning goals

- Trace a **third-party privileged helper** pattern similar to other desktop apps.
- Identify **Mach service** exposure and weak **client authentication** in the historical build.
- Articulate **impact** (user → root or equivalent) in one paragraph.

## Worksheet

1. **Mach / XPC name(s):** List names you found (strings / Hopper): `________________________`
2. **Trust gate:** Where should the app have verified the peer? File + symbol name if found: `________________________`
3. **Primitive:** What dangerous action could an attacker request through the surface? `________________________`
4. **Defense in depth:** Name two mitigations **users** have today (updates, MDM, removal) vs two **developer** mitigations (code signing checks, hardened runtime, least privilege).

## Ethics

Do not use historical vulnerable builds against **real** user accounts or production machines.

## References

Search vendor security bulletins and `CVE` entries associated with Zoom **5.8.3** / contemporaneous LPE reports (instructor will confirm the exact CVE string for your packet).
