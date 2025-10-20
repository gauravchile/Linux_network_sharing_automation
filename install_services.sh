#!/bin/bash
# ========================================
# install_services.sh
# Auto setup Samba, NFS, or FTP on Debian/RHEL
# Shows spinner + percentage while installing/updating
# Usage: sudo ./install_services.sh <role>
# Roles: samba | nfs | ftp
# ========================================

set -euo pipefail

# Detect distro
if [ -f /etc/debian_version ]; then
    DISTRO="debian"
    PKG_INSTALL="apt-get install -y -qq"
    UPDATE_CMD="apt-get update -y -qq"
elif [ -f /etc/redhat-release ]; then
    DISTRO="rhel"
    PKG_INSTALL="yum install -y -q"
    UPDATE_CMD="yum makecache -q"
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

# Spinner function
spinner() {
    local pid=$1
    local task="$2"
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0
    local percent=0

    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        percent=$((percent+1))
        [[ $percent -gt 99 ]] && percent=99
        printf "\r%s  %s... %d%%" "${spin:i:1}" "$task" "$percent"
        sleep 0.1
    done
    printf "\r✅  %s... 100%%\n" "$task"
}

update_system() {
    local task="Updating package index"
    if [ "$DISTRO" = "debian" ]; then
        $UPDATE_CMD &
    else
        $UPDATE_CMD &
    fi
    spinner $! "$task"
}

install_pkg() {
    local pkg="$1"
    local task="Installing $pkg"
    $PKG_INSTALL "$pkg" &
    spinner $! "$task"
}

install_samba() {
    update_system
    install_pkg "samba"

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
    update_system
    if [ "$DISTRO" = "debian" ]; then
        install_pkg "nfs-kernel-server"
    else
        install_pkg "nfs-utils"
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
    update_system
    install_pkg "vsftpd"

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
