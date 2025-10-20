#!/bin/bash
# ========================================
# client_test.sh
# Test Samba, NFS, FTP connections
# Auto-detects Debian or RHEL
# ========================================

set -euo pipefail

SAMBA_IP=${1:-}
NFS_IP=${2:-}
FTP_IP=${3:-}

if [ $# -ne 3 ]; then
  echo "Usage: $0 <samba_ip> <nfs_ip> <ftp_ip>"
  exit 1
fi

# Detect OS
if [ -f /etc/debian_version ]; then
    DISTRO="debian"
    UPDATE_CMD="apt-get update -y"
    INSTALL_CMD="apt-get install -y"
    PKGS="smbclient nfs-common ftp"
elif [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    UPDATE_CMD="yum makecache -y"
    INSTALL_CMD="yum install -y"
    PKGS="samba-client nfs-utils ftp"
else
    echo "Unsupported OS"
    exit 1
fi

spinner() {
  local pid=$1
  local delay=0.1
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  local percent=0

  while ps -p $pid &>/dev/null; do
    i=$(((i + 1) % 10))
    percent=$(((percent + 2) % 100))
    printf "\r%s  Installing client tools... %s%%" "${spin:$i:1}" "$percent"
    sleep $delay
  done
  printf "\r✅  Installing client tools... 100%%\n"
}

echo "[*] Installing client tools..."
{
  $UPDATE_CMD >/dev/null 2>&1
  $INSTALL_CMD $PKGS >/dev/null 2>&1
} &
spinner $!

echo "===== Testing Samba ====="
smbclient -L "//$SAMBA_IP/PublicShare" -N || echo "[!] Samba test failed"
echo "Hello_from_Client" > test_file.txt
smbclient "//$SAMBA_IP/PublicShare" -N -c "put test_file.txt" || echo "[!] Failed to upload test file"
smbclient "//$SAMBA_IP/PublicShare" -N -c "ls"

echo "===== Testing NFS ====="
sudo mkdir -p /mnt/nfs_test
sudo mount "$NFS_IP:/srv/nfs/share" /mnt/nfs_test && echo "[+] Mounted NFS share!"
ls /mnt/nfs_test
sudo umount /mnt/nfs_test

echo "===== Testing FTP ====="
echo "ls" | ftp -n "$FTP_IP" <<EOF
user anonymous anonymous
ls
bye
EOF

echo "[+] All tests completed!"
