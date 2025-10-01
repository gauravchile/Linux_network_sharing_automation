#!/bin/bash
# ========================================
# install_services.sh
# Auto setup Samba, NFS, or FTP on Debian/RHEL
# Usage: sudo ./install_services.sh <role>
# Roles: samba | nfs | ftp
# ========================================

set -euo pipefail

# Detect distro
if [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="apt-get install -y"
    UPDATE_CMD="apt-get update -y"
elif [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    PKG_INSTALL="yum install -y"
    UPDATE_CMD="yum makecache"
else
    echo "Unsupported OS"
    exit 1
fi

ROLE=${1:-}

# Prompt user if no role given
if [ -z "$ROLE" ]; then
    echo "Select a service to install:"
    select r in samba nfs ftp; do
        ROLE=$r
        break
    done
fi

install_samba() {
    echo "[*] Installing Samba..."
    $UPDATE_CMD
    $PKG_INSTALL samba
    mkdir -p /srv/samba/share
    chown nobody:nogroup /srv/samba/share || chown nobody:nobody /srv/samba/share
    chmod 0777 /srv/samba/share

    cat >> /etc/samba/smb.conf <<EOF

[PublicShare]
   path = /srv/samba/share
   browseable = yes
   writable = yes
   guest ok = yes
EOF

    systemctl enable smbd
    systemctl restart smbd
    echo "[+] Samba configured successfully!"
}

install_nfs() {
    echo "[*] Installing NFS..."
    $UPDATE_CMD
    if [ "$DISTRO" = "debian" ]; then
        $PKG_INSTALL nfs-kernel-server
    else
        $PKG_INSTALL nfs-utils
    fi

    mkdir -p /srv/nfs/share
    chown nobody:nogroup /srv/nfs/share || chown nobody:nobody /srv/nfs/share
    chmod 0777 /srv/nfs/share

    echo "/srv/nfs/share *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    exportfs -ra

    systemctl enable nfs-server || systemctl enable nfs-kernel-server
    systemctl restart nfs-server || systemctl restart nfs-kernel-server
    echo "[+] NFS configured successfully!"
}

install_ftp() {
    echo "[*] Installing FTP (vsftpd)..."
    $UPDATE_CMD
    $PKG_INSTALL vsftpd

    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
    cat > /etc/vsftpd.conf <<EOF
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
chroot_local_user=YES
EOF

    systemctl enable vsftpd
    systemctl restart vsftpd
    echo "[+] FTP configured successfully!"
}

case "$ROLE" in
    samba) install_samba ;;
    nfs)   install_nfs ;;
    ftp)   install_ftp ;;
    *)     echo "Invalid role: $ROLE (use samba|nfs|ftp)" ;;
esac

