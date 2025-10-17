# 🌐 Linux Network Sharing Automation

Automated setup of **Samba, NFS, and FTP servers** on Debian/RHEL systems using Bash scripts.  
Simplifies network file sharing setup and testing across Linux servers.

![Linux](https://img.shields.io/badge/Linux-Compatible-blue) ![Bash](https://img.shields.io/badge/Shell-Bash-green) ![Samba](https://img.shields.io/badge/Samba-Server-orange) ![NFS](https://img.shields.io/badge/NFS-Server-lightgrey) ![FTP](https://img.shields.io/badge/FTP-vsftpd-purple)

---

## 🌟 Features

- Install and configure **Samba** with a public share  
- Install and configure **NFS** with a shared directory  
- Install and configure **FTP server (vsftpd)**  
- Client test scripts to verify **shares and transfers**  
- Works on **Debian/Ubuntu** and **RHEL/CentOS**  

---

## ⚙️ Usage

### Server Installation

```bash
sudo ./install_services.sh <samba|nfs|ftp>
Client Testing
bash
Copy code
sudo ./client_test.sh <SAMBA_IP> <NFS_IP> <FTP_IP>
💡 Tip: Replace <SAMBA_IP>, <NFS_IP>, and <FTP_IP> with the respective server IP addresses.

📁 Folder Structure
bash
Copy code
Linux_network_sharing_automation/
│
├─ configs/   # Configuration files for Samba, NFS, FTP
├─ docs/      # Screenshots, logs, and documentation
├─ install_services.sh   # Main installation script
└─ client_test.sh        # Client testing script

## 🎯 Skills Demonstrated
Linux server administration

Network file sharing with Samba, NFS, FTP

Bash scripting for automation

Client-server testing and validation

## 💡 Pro Tips
Use for small office or lab environments

Extend to include user authentication and permissions

Check logs in docs/ for troubleshooting
