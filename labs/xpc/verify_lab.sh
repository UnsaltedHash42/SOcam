#!/bin/bash
# Non-destructive: exit 0 if the vulnerable helper service is registered/loaded enough to print.
set -euo pipefail

LABEL="com.example.vulnerablehelper"

if launchctl print "system/${LABEL}" >/dev/null 2>&1; then
	echo "[+] launchd knows about ${LABEL}"
	exit 0
fi

echo "[-] ${LABEL} not found (install with sudo ./install_lab.sh first)"
exit 1
