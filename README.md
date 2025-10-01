# Linux_network_sharing_automation

Automated setup of **Samba, NFS, and FTP servers** on Debian/RHEL systems using Bash.

## Features
- Install and configure Samba with a public share
- Install and configure NFS with a shared directory
- Install and configure FTP server (vsftpd)
- Client test scripts to verify shares and transfers
- Works on Debian/Ubuntu and RHEL/CentOS

## Usage

### Server Installation

sudo ./install_services.sh <samba|nfs|ftp>

### Client Testing

sudo ./client_test.sh <SAMBA_IP> <NFS_IP> <FTP_IP>

### Folder Structure

configs/  Configuration files

docs/  Screenshots, logs, and documentation
