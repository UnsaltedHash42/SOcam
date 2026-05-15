# Lab II — multi-binary bundle pass (`PluginHost.app`)

This is a **separate** lab from the 3-hour AI-assisted reversing spine. Take it home, schedule it for next week's class, or treat it as optional homework. Plan for **45–60 minutes** end-to-end if you've already completed the planted-daemon pass.

The point of Lab II is to walk the same pass loop against a different target shape — a `.app` **bundle** with multiple Mach-Os — and feel where the loop has to bend. The planted daemon was a single Mach-O; most real macOS targets are not.

**Prerequisites:**

- You finished the planted-daemon pass (Sessions C–G of [`STUDENT_GUIDE.md`](STUDENT_GUIDE.md)). The triage state machine, the dossier shape, the `--vuln-class` / `--severity` traps, the `pocs/<target>/` convention — all assumed.
- Your workstation has a working station (`bash scripts/smoke-wave3.sh` passes).
- Your lab host has the `tutorial_daemon` install torn down (run the Session F teardown if you didn't already).

**The target:** `templates/tutorial-target-2/PluginHost.app` ships in the station repo, prebuilt and ad-hoc-signed. You do **not** need to run `build.sh` first. The bundle contains a host binary, a bundled XPC helper, and a sample plugin dylib — three Mach-Os, one bundle. Three planted bugs all live across the host/helper boundary.

---

## What's new vs the planted daemon

- **Bundle intake.** The bare-binary intake you ran in Session C produces an empty `bundle: {}`, `mach_services: []`, no entitlements. Bundle intake reads `Contents/Info.plist`, walks `Contents/MacOS/` and `Contents/XPCServices/`, and emits a `components` array — host executable, every nested `.xpc`/`.appex`/`.systemextension`, every helper tool, every launchd plist. **Heuristics fire when intake has structure to read.**
- **One target id, many components.** Pointing intake at `PluginHost.app` produces target id `pluginhost` (slug of the bundle name, lowercased, `.app` stripped). Inside the dossier, `components` lists each Mach-O. Triage candidates against the **same** target id; the component the candidate refers to lives in the candidate's title and body, not in the target id.
- **`dlopen` of a wire-supplied path.** The planted daemon's bug class was wrong-door (multiple listeners, no branching). The bundle's bug class is **plugin loading** — a privileged process trusts a string from a less-privileged peer and `dlopen`s it. Same shape, different scan recipe (`scan_private_framework_dependency.py`, family playbook `offensive-macos-hunt-private-framework-hijack`).

---

## Pass loop

### 1. Fresh per-target project clone

```bash
mkdir -p ~/re && cd ~/re
git clone https://github.com/UnsaltedHash42/mac-reversing-station tutorial-bundle-class
cd tutorial-bundle-class
scripts/init-project.sh --name tutorial-bundle-class
$EDITOR LAB_SAFETY.md       # set lab_disposable: true if your VM is disposable
$EDITOR machines.md         # name your lab host alias
```

### 2. Intake against the bundle path

```bash
python3 scripts/start-target.py templates/tutorial-target-2/PluginHost.app \
    --pass-id PASS-LAB-II
```

Watch's output names the slug: `OK - initialized pluginhost for PASS-LAB-II`. The dossier lands at `findings/analysis/PASS-LAB-II-pluginhost-dossier.json`.

### 3. Read the dossier

```bash
cat findings/analysis/PASS-LAB-II-pluginhost-dossier.json | python3 -m json.tool | head -120
```

What you should see:

- `bundle.identifier = "com.tutorial.pluginhost"`, `bundle.executable = "PluginHost"`
- `classification.family_labels` includes `"privileged helpers / updaters"`, `"developer tools"`, `"TCC-heavy consumer apps"` (a bundle with a plugin surface and an Apple Events usage description hits multiple buckets)
- `classification.surfaces` includes `"plugin-or-extension"`, `"privacy-permissions"`, `"xpc-services"`
- `component_summary.total = 3`, with one `main-executable`, one `xpc-service`, one `executable` (the dylib — intake labels `.dylib` files as `executable` in the components list, which is a small intake quirk; the `name` field still says `sample.dylib`)
- `decision_support.recommended_ghidra_scripts` lists `scan_xpc_client_validation.py`, `scan_tcc_prompt_surface.py`, `scan_persistent_authorization.py`. Note: `scan_private_framework_dependency.py` is **not** auto-recommended for this shape — we add it manually in step 5 because we already know the bug class.

**Try the contrast.** Run intake once against the host binary alone:

```bash
python3 scripts/start-target.py templates/tutorial-target-2/PluginHost.app/Contents/MacOS/PluginHost \
    --pass-id PASS-LAB-II-CONTRAST
cat findings/analysis/PASS-LAB-II-CONTRAST-pluginhost-dossier.json | python3 -m json.tool | head -40
```

Empty `bundle`, empty `mach_services`, fewer family labels. **The bundle is the unit of intake** — pointing at the bare binary throws away exactly the structure that drives recipe selection.

### 4. Sync to the lab host

```bash
MACRE_MACHINE=<lab-host> MACRE_REMOTE_TARGETS=/Users/<remote-user>/Targets \
    scripts/rsync-to-vm.sh --record pluginhost targets/
```

Records a `Lab Host Path Mapping` row in `CORPUS.md` keyed to `pluginhost`.

### 5. Static sweep on the helper binary

The static sweep targets a **specific component**, not the whole bundle. The helper is the binary that calls `dlopen` on a wire-supplied path, so it's the right place to start.

Agent prompt:

> Open the helper executable inside `PluginHost.app` (`Contents/XPCServices/PluginHelper.xpc/Contents/MacOS/PluginHelper`) in Ghidra. Run `scan_xpc_client_validation.py` and `scan_private_framework_dependency.py`. Call out any tier-A `dlopen` callsites whose path argument is recovered from an XPC dictionary lookup, and any tier-A allowlist functions whose return value gates a subsequent `dlopen`.

Expected anchors:

- `scan_xpc_client_validation.py` finds `-[PluginHandler loadPluginAtPath:withReply:]` as a tier-A entry that reads a string from an XPC argument.
- `scan_private_framework_dependency.py` finds the `dlopen` callsite inside `loadPluginAtPath:withReply:` with a literal-derived (parameter-derived) path argument — that's the dlopen Tier-A anchor.

### 6. Triage three candidates

All three carry `--target pluginhost`; the component they refer to is named in the title.

```bash
scripts/triage.py create --id C-101 --pass-id PASS-LAB-II --target pluginhost \
    --title "PluginHost: forwards wire-supplied path to helper without validation" \
    --vuln-class wrong-door --severity medium \
    --primary-artifact findings/analysis/PASS-LAB-II-pluginhost-xpc-client-validation.tsv
scripts/triage.py transition C-101 escalated

scripts/triage.py create --id C-102 --pass-id PASS-LAB-II --target pluginhost \
    --title "PluginHelper: loadPluginAtPath: allowlist bypass via path traversal" \
    --vuln-class privfw-hijack --severity high \
    --primary-artifact findings/analysis/PASS-LAB-II-pluginhost-private-framework-dependency.tsv
scripts/triage.py transition C-102 escalated

scripts/triage.py create --id C-103 --pass-id PASS-LAB-II --target pluginhost \
    --title "PluginHelper: dlopen of allowlisted path with no team-id / SecCode check" \
    --vuln-class privfw-hijack --severity high \
    --primary-artifact findings/analysis/PASS-LAB-II-pluginhost-private-framework-dependency.tsv
scripts/triage.py transition C-103 escalated
```

**Stop here for the take-home version.** Confirming the `dlopen` callsite dynamically requires installing the bundle into `~/Applications`, attaching lldb to the helper at the wire-supplied path, and triggering it with a host-impersonating client; that's a full extra session.

### 7. Render and HANDOFF

```bash
scripts/triage.py render
cat INDEX.md | head -20
```

Three candidates against `pluginhost`, all `escalated`. Write `HANDOFF.md` so a future session can resume from this state and pick up the dynamic confirmation.

---

## Rules of thumb (cross-binary tracking)

- **The bundle is the unit of intake**, not the binary. Pointing intake at the host binary alone misses the helper.
- **One target id, many components.** Don't fight intake by trying to fan out to a per-binary target id — the dossier already lists every binary under one target. Triage candidates carry the component path in their title (and, if you want it for tooling, in the candidate JSON body — there's no `--component` flag, but `validate` won't reject extra keys you add by hand).
- **`dlopen` of an attacker-influenced path is the wrong-door's cousin.** Same shape (a privileged process trusts a string from a less-privileged peer) but different scan recipe. The watch layer doesn't auto-recommend `scan_private_framework_dependency.py` for this shape — add it manually when the dossier surfaces `plugin-or-extension`.
- **Closures count here too.** If you cannot articulate why each of `C-101`, `C-102`, `C-103` is exploitable as a chain, close one with rationale rather than leaving it `escalated`. Same discipline as the planted daemon.

---

## Optional: rebuild `PluginHost.app`

Default: use the committed bundle — **no build step**.

Rebuild only if you edited `src/`, the `.app` is missing, or your lab host is **Intel** (committed binaries are arm64):

```bash
cd templates/tutorial-target-2
./build.sh
```

Requires Xcode Command Line Tools (`clang`, `codesign`). The script builds the host, nested XPC helper, and `sample.dylib`, then ad-hoc-signs in nested order. Output: `PluginHost.app/`.

---

## Read the source after you finish

`templates/tutorial-target-2/README.md` has the bug rundown and the red herring. Do not read it before you've triaged the three candidates yourself — the answer key invalidates the practice.
