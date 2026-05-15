# AI-assisted reversing — lab setup (copy-paste)

Do these steps **in order** on the machine where Cursor or Claude runs (**workstation**). The **lab host** is a macOS VM (or spare Mac).

**Related:** prose and checkpoints live in [`STUDENT_GUIDE.md`](STUDENT_GUIDE.md) Session 0. This file is the short playbook only.

---

## 1 — VM

1. Create a macOS VM (UTM, Fusion, Parallels). Use an **Apple Silicon guest** if your workstation is Apple Silicon — the installer downloads arm64 JDK/Ghidra.
2. Create one **admin** lab account. Example username: `student`. Remember its password (`YOUR_VM_PASSWORD` below).
3. On the VM: **System Settings → General → Sharing → Remote Login → On**.
4. Note the VM's IP (often `192.168.64.x` with shared networking). Optionally: `ping` it from the workstation.
5. Power off and **snapshot** the VM.

---

## 2 — SSH config (workstation)

Edit `~/.ssh/config` **on your Mac** (not inside the VM). **Replace** `HostName` with your VM's IP and `User` with the lab username.

```
Host lab-mac
  HostName 192.168.64.2
  User student
  ServerAliveInterval 30
```

**First contact** (password is fine once):

```bash
ssh lab-mac 'uname -m; sw_vers -productVersion'
```

You want **`arm64`** and a recent macOS (version **13+** is typical for class VMs).

**Local key** (create if missing; `setup-keep.sh` can also create one):

```bash
test -f ~/.ssh/id_ed25519.pub || ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519
```

---

## 3 — Station repo (station home)

On the workstation:

```bash
git clone https://github.com/UnsaltedHash42/mac-reversing-station ~/tools/mac-reversing-station
cd ~/tools/mac-reversing-station
```

This directory is **station home** (`setup-keep.sh`, `Skills/`, `templates/`).

---

<a id="setup-keep"></a>

## 4 — setup-keep.sh (first run ~15–20 min)

Still in `~/tools/mac-reversing-station`. Substitute:

- **`YOUR_VM_PASSWORD`** — VM account login password  
- **`/Users/student`** — must match **`User`** above (`/Users/<short-name>`)

```bash
scripts/setup-keep.sh \
  --host lab-mac \
  --remote-home /Users/student \
  --vm-password 'YOUR_VM_PASSWORD' \
  --lab-disposable \
  --live-smoke
```

Flags:

- **`--host`** matches the **`Host`** line in `~/.ssh/config`.
- **`--vm-password`** is used once to install your **`~/.ssh/id_ed25519.pub`** into `authorized_keys` on the VM.
- **`--lab-disposable`** installs a sudoers snippet on the VM so **`sudo`** over SSH does not hang (VM you can wipe only).
- **`--live-smoke`** runs a live toolchain check after install.

### What you should see

Roughly this order:

1. Cursor / Claude Code **skills linked** (or run `skill-link` scripts afterward — see below).
2. **`OK`** for **non-interactive SSH key** login to `lab-mac` (or "already works").
3. **Downloads** onto the VM (Ghidra, JDK, MCP pieces) — longest wait on first run.
4. **`OK`** / **NOPASSWD sudo** for your lab user (with `--lab-disposable`).
5. **Structural smoke** then **live smoke** ending with **`[OK]`** on key checks from `smoke-wave3.sh --live`.

If you ran setup **without** `--live-smoke`, run afterward:

```bash
bash scripts/skill-link-claude-code.sh
# or: bash cursor/skill-link.sh

bash scripts/smoke-wave3.sh
MACRE_MACHINE=lab-mac bash scripts/smoke-wave3.sh --live
```

---

## 5 — Shell exports (workstation)

Add to `~/.zshrc` (adjust paths if username is not `student`):

```bash
export MACRE_MACHINE=lab-mac
export MACRE_REMOTE_TARGETS=/Users/student/Targets
```

```bash
source ~/.zshrc
```

**Quit and reopen** Cursor / Claude Code so MCP servers reload.

---

## 6 — Verify before class

```bash
ssh -o BatchMode=yes lab-mac 'echo ssh-ok'
ssh -o BatchMode=yes lab-mac 'sudo -n true && echo sudo-ok'
cd ~/tools/mac-reversing-station
MACRE_MACHINE=lab-mac bash scripts/smoke-wave3.sh --live
```

- **`ssh-ok` fails:** fix `~/.ssh/config` / re-run Step 4 with **`--vm-password`**.  
- **`sudo-ok` fails:** re-run Step 4 with **`--lab-disposable`**.  

**Ghidra lock / stale sessions:**  

```bash
cd ~/tools/mac-reversing-station && bash scripts/lab-health.sh --remove-stale
```

---

## 7 — Project clone (where the agent works)

```bash
mkdir -p ~/re && cd ~/re
git clone https://github.com/UnsaltedHash42/mac-reversing-station tutorial-daemon-class
cd tutorial-daemon-class
scripts/init-project.sh --name tutorial-daemon-class
```

Open **`~/re/tutorial-daemon-class/`** in your editor. **Fill** `LAB_SAFETY.md` and **`machines.md` yourself.**

---

## 8 — First agent message

Paste **orientation** from [`STUDENT_QUICK_REFERENCE.md`](STUDENT_QUICK_REFERENCE.md) § **0.7 — Orientation**. Done when line **`READY FOR PASS`** appears (no intake yet).

---

## After class (optional sudoers cleanup)

On a disposable snapshot/restore workflow you can skip this. To remove lab NOPASSWD on the VM (filename uses your Unix username):

```bash
ssh lab-mac 'sudo rm /etc/sudoers.d/lab-nopasswd-student'
```

Replace **`student`** with your lab username if different.
