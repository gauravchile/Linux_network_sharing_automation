#!/bin/bash
# ========================================
# client_test.sh
# Test Samba, NFS, FTP connections
# Usage: ./client_test.sh <samba_ip> <nfs_ip> <ftp_ip>
# ========================================

SAMBA_IP=$1
NFS_IP=$2
FTP_IP=$3

if [ $# -ne 3 ]; then
  echo "Usage: $0 <samba_ip> <nfs_ip> <ftp_ip>"
  exit 1
fi

echo "[*] Installing client tools..."
sudo apt update && sudo apt install -y smbclient nfs-common ftp &/dev/null

echo "===== Testing Samba ====="
smbclient -L //$SAMBA_IP/PublicShare -N || echo "[!] Samba test failed"
echo "Hello_from_Client" > test_file.txt
smbclient //$SAMBA_IP/PublicShare -N -c "put test_file.txt"   || { echo "[!] Failed to upload test file"; exit 1; }
smbclient //$SAMBA_IP/PublicShare -N -c "ls"

echo "===== Testing NFS ====="
sudo mkdir -p /mnt/nfs_test
sudo mount $NFS_IP:/srv/nfs/share /mnt/nfs_test && echo "[+] Mounted NFS share!"
ls /mnt/nfs_test
sudo umount /mnt/nfs_test

echo "===== Testing FTP ====="
echo "ls" | ftp -n $FTP_IP <<EOF
user anonymous anonymous
ls
bye
EOF

echo "[+] All tests completed!"
