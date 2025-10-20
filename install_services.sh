#!/usr/bin/env bash
# install_services.sh
# Auto setup Samba, NFS, or FTP on Debian/RHEL with spinner + percentage
# Usage: sudo ./install_services.sh <role>
# Roles: samba | nfs | ftp

set -euo pipefail

# --------- helpers & color ----------
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

timestamp() { date +"%Y%m%d-%H%M%S"; }

logfile="/tmp/install_services.$(timestamp).log"

# Spinner+percentage while a background PID runs.
# It shows a dynamic percentage that climbs while process runs,
# and finishes with 100% when the process exits.
spinner_watch() {
  local pid=$1
  local msg="$2"
  local spin_chars=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  local percent=0

  printf "%b  " "$YELLOW"
  while kill -0 "$pid" 2>/dev/null; do
    i=$(((i+1) % 10))
    # increment percent gradually but clamp below 99 to avoid jumping to 100 prematurely
    percent=$((percent + 1))
    [ $percent -gt 98 ] && percent=98
    printf "\r%s  %s... %3d%%" "${spin_chars[$i]}" "$msg" "$percent"
    sleep 0.1
  done
  # final state
  printf "\r%b✅  %s... 100%%%b\n" "$GREEN" "$msg" "$RESET"
}

run_quiet() {
  # run a command in background redirecting output to logfile
  # usage: run_quiet command arg1 arg2 ...
  ("$@") >>"$logfile" 2>&1 &
  echo $!
}

# --------- distro detection ----------
if [ -f /etc/debian_version ]; then
  DISTRO="debian"
  UPDATE_CMD=(apt-get update -y -qq)
  INSTALL_CMD=(apt-get install -y -qq)
  PKG_SAMBA="samba"
  PKG_NFS="nfs-kernel-server"
  PKG_FTP="vsftpd"
elif [ -f /etc/redhat-release ]; then
  DISTRO="rhel"
  # prefer dnf if available
  if command -v dnf &>/dev/null; then
    UPDATE_CMD=(dnf makecache -y -q)
    INSTALL_CMD=(dnf install -y -q)
  else
    UPDATE_CMD=(yum makecache -y -q)
    INSTALL_CMD=(yum install -y -q)
  fi
  PKG_SAMBA="samba"        # on RHEL/SUSE may be different but 'samba' generally works
  PKG_NFS="nfs-utils"
  PKG_FTP="vsftpd"
else
  echo -e "${RED}Unsupported OS${RESET}"
  exit 1
fi

ROLE=${1:-}
if [ -z "$ROLE" ]; then
  echo "Select a service to install:"
  select r in samba nfs ftp; do
    ROLE=$r
    break
  done
fi

# --------- install flows ----------
install_samba() {
  echo "[*] Updating package index (quiet). Logs: $logfile"
  pid=$(run_quiet "${UPDATE_CMD[@]}")
  spinner_watch $pid "Updating package index"
  wait $pid || { echo -e "${RED}Update failed. See $logfile${RESET}"; exit 1; }

  echo "[*] Installing Samba (quiet). Logs: $logfile"
  pid=$(run_quiet "${INSTALL_CMD[@]}" "$PKG_SAMBA")
  spinner_watch $pid "Installing Samba"
  wait $pid || { echo -e "${RED}Samba install failed. See $logfile${RESET}"; exit 1; }

  mkdir -p /srv/samba/share
  if command -v chown &>/dev/null; then
    chown nobody:nogroup /srv/samba/share 2>/dev/null || chown nobody:nobody /srv/samba/share 2>/dev/null || true
  fi
  chmod 0777 /srv/samba/share

  # append share if not exists
  if ! grep -q "^\[PublicShare\]" /etc/samba/smb.conf 2>/dev/null; then
    cat >> /etc/samba/smb.conf <<'EOF'

[PublicShare]
   path = /srv/samba/share
   browseable = yes
   writable = yes
   guest ok = yes
EOF
  fi

  echo "[*] Enabling and starting Samba (smbd)"
  systemctl enable --now smbd &>/dev/null || systemctl enable --now samba &>/dev/null || true
  sleep 1
  if systemctl is-active --quiet smbd || systemctl is-active --quiet samba; then
    echo -e "${GREEN}[+] Samba configured successfully!${RESET}"
  else
    echo -e "${RED}[!] Samba service not running properly. See $logfile${RESET}"
    exit 1
  fi
}

install_nfs() {
  echo "[*] Updating package index (quiet). Logs: $logfile"
  pid=$(run_quiet "${UPDATE_CMD[@]}")
  spinner_watch $pid "Updating package index"
  wait $pid || { echo -e "${RED}Update failed. See $logfile${RESET}"; exit 1; }

  echo "[*] Installing NFS kernel utilities (quiet). Logs: $logfile"
  pid=$(run_quiet "${INSTALL_CMD[@]}" "$PKG_NFS")
  spinner_watch $pid "Installing NFS"
  wait $pid || { echo -e "${RED}NFS install failed. See $logfile${RESET}"; exit 1; }

  mkdir -p /srv/nfs/share
  chown nobody:nogroup /srv/nfs/share 2>/dev/null || chown nobody:nobody /srv/nfs/share 2>/dev/null || true
  chmod 0777 /srv/nfs/share

  if ! grep -q "^/srv/nfs/share" /etc/exports 2>/dev/null; then
    echo "/srv/nfs/share *(rw,sync,no_subtree_check,no_root_squash)" >> /etc/exports
  fi
  exportfs -ra

  # enable and start service (service names differ)
  systemctl enable --now nfs-server &>/dev/null || systemctl enable --now nfs-kernel-server &>/dev/null || true
  sleep 1
  if systemctl is-active --quiet nfs-server || systemctl is-active --quiet nfs-kernel-server; then
    echo -e "${GREEN}[+] NFS configured successfully!${RESET}"
  else
    echo -e "${RED}[!] NFS service not running properly. See $logfile${RESET}"
    exit 1
  fi
}

install_ftp() {
  echo "[*] Updating package index (quiet). Logs: $logfile"
  pid=$(run_quiet "${UPDATE_CMD[@]}")
  spinner_watch $pid "Updating package index"
  wait $pid || { echo -e "${RED}Update failed. See $logfile${RESET}"; exit 1; }

  echo "[*] Installing vsftpd (quiet). Logs: $logfile"
  pid=$(run_quiet "${INSTALL_CMD[@]}" "$PKG_FTP")
  spinner_watch $pid "Installing vsftpd"
  wait $pid || { echo -e "${RED}vsftpd install failed. See $logfile${RESET}"; exit 1; }

  [ -f /etc/vsftpd.conf ] && cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
  cat > /etc/vsftpd.conf <<'EOF'
listen=YES
anonymous_enable=YES
local_enable=YES
write_enable=YES
anon_upload_enable=YES
anon_mkdir_write_enable=YES
chroot_local_user=YES
EOF

  systemctl enable --now vsftpd &>/dev/null || true
  sleep 1
  if systemctl is-active --quiet vsftpd; then
    echo -e "${GREEN}[+] FTP (vsftpd) configured successfully!${RESET}"
  else
    echo -e "${RED}[!] FTP service not running properly. See $logfile${RESET}"
    exit 1
  fi
}

case "$ROLE" in
  samba) install_samba ;;
  nfs)   install_nfs ;;
  ftp)   install_ftp ;;
  *)
    echo -e "${RED}Invalid role: $ROLE (use samba|nfs|ftp)${RESET}"
    exit 1
    ;;
esac

echo -e "\n${GREEN}All done. Logs: $logfile${RESET}"
