#!/usr/bin/env bash
# Fail if forbidden paths are tracked (run from repo root after `git add`).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo "[!] Not a git repository. Run: git init"
	exit 2
fi

FORBIDDEN=(
	"exp-312.pdf"
	"exp-312.md"
	"module_09_xpc.md"
	"instructor_private"
	"resources/Slack.app"
	"resources/MachOView"
	"socam_from_git"
)

bad=0
for f in "${FORBIDDEN[@]}"; do
	if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
		echo "[-] Forbidden tracked path: $f"
		bad=1
	fi
done

# Any nested .git inside tracked tree (except .git itself)
while IFS= read -r g; do
	if [[ "$g" == "./.git" ]]; then
		continue
	fi
	echo "[-] Nested git dir tracked: $g"
	bad=1
done < <(git ls-files | grep -E '/\.git/' || true)

if [[ "$bad" -ne 0 ]]; then
	echo "[!] Fix .gitignore and git rm --cached before pushing to students."
	exit 1
fi

echo "[+] No forbidden paths in git index."
exit 0
