#!/bin/bash
set -euo pipefail

HELPER_BIN="com.example.vulnerablehelper"
DEST_BIN="/Library/PrivilegedHelperTools/${HELPER_BIN}"
DEST_PLIST="/Library/LaunchDaemons/${HELPER_BIN}.plist"
MARKER="/Library/PrivilegedHelperTools/PWNED_BY_XPC"

if [[ "${EUID:-}" -ne 0 ]]; then
	echo "[!] Run as root: sudo $0"
	exit 1
fi

echo "[*] Unloading LaunchDaemon (if loaded)..."
launchctl bootout "system/${HELPER_BIN}" 2>/dev/null || true
launchctl unload "$DEST_PLIST" 2>/dev/null || true

echo "[*] Removing plist and binary..."
rm -f "$DEST_PLIST"
rm -f "$DEST_BIN"

echo "[*] Removing lab marker file (if present)..."
rm -f "$MARKER"

echo "[+] Uninstall complete. Verify: launchctl print system/${HELPER_BIN} (should fail)."
