#!/bin/bash
#
# install_lab.sh — build and install the teaching-only VulnerableHelper as root.
#
# Prerequisites: run from labs/xpc with sudo. Uninstall with ./uninstall_lab.sh.
# Students: all logic is also explained in VulnerableHelper.swift and README_STUDENT.md.
#

# Configuration
HELPER_SRC="./VulnerableHelper/VulnerableHelper.swift"
HELPER_PLIST="./VulnerableHelper/com.example.vulnerablehelper.plist"
HELPER_BIN="com.example.vulnerablehelper"
DEST_BIN="/Library/PrivilegedHelperTools/$HELPER_BIN"
DEST_PLIST="/Library/LaunchDaemons/com.example.vulnerablehelper.plist"

echo "[*] Setting up Module 9 Lab: Vulnerable XPC Service"

# 1. Compile the Helper
echo "[*] Compiling VulnerableHelper..."
swiftc "$HELPER_SRC" -o "$HELPER_BIN"

if [ ! -f "$HELPER_BIN" ]; then
    echo "[-] Compilation failed!"
    exit 1
fi

# 2. Install (Requires Root)
if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run as root (sudo ./install_lab.sh)"
    rm "$HELPER_BIN"
    exit 1
fi

echo "[*] Installing Binary to $DEST_BIN..."
rm -f "$DEST_BIN"
mv "$HELPER_BIN" "$DEST_BIN"
chmod 755 "$DEST_BIN"
chown root:wheel "$DEST_BIN"

# 3. Install Plist
echo "[*] Installing LaunchDaemon Plist..."
cp "$HELPER_PLIST" "$DEST_PLIST"
chmod 644 "$DEST_PLIST"
chown root:wheel "$DEST_PLIST"

# 4. Load Service
echo "[*] Unloading old service (if any)..."
launchctl unload "$DEST_PLIST" 2>/dev/null
echo "[*] Loading new service..."
launchctl load "$DEST_PLIST"

echo "[+] Lab Installed! Service 'com.example.vulnerablehelper' is running."
echo "[*] You can verify with: launchctl list | grep vulnerablehelper"
echo "[*] Teardown: sudo ./uninstall_lab.sh"
