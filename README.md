# LAMP Stack Installer for Ubuntu 24.04+

![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%2B-orange?logo=ubuntu)
![License](https://img.shields.io/badge/License-BSD_3--Clause-blue)
![Shell](https://img.shields.io/badge/Shell-Bash-green?logo=gnu-bash)

Automated **LAMP (Linux, Apache, MySQL, PHP)** stack installer for Ubuntu 24.04+ with full support for both **interactive** and **non-interactive (`--auto`)** deployment modes. Built for secure, repeatable production deployments.

---

## Features
- Installs **Apache2**, **MySQL 8.0**, **PHP 8.x**, and **phpMyAdmin**
- Automatic **SSL provisioning** via Let's Encrypt (**Certbot**)
- Security hardening with sane defaults (MySQL bind, file permissions, headers)
- Configures **UFW firewall** (HTTP/HTTPS/SSH) and optional SSH lock-down
- Persistent installation logging under `/var/log/lamp-installer/`
- Modular architecture — decomposed into `modules/` for maintainability
- Supports both **interactive** and **non-interactive (`--auto`)** deployment

---

## Modular Architecture

The installer is decomposed into modules in `modules/`:

| Module | Purpose |
|--------|---------|
| `helpers.sh` | Common utilities: logging, validation, password generation |
| `config.sh` | CLI parsing, environment variables, interactive fallbacks |
| `install_packages.sh` | Installs base packages and prerequisites |
| `apache.sh` | Apache2 installation and VirtualHost configuration |
| `mysql.sh` | MySQL 8.0 installation and hardening |
| `php.sh` | PHP 8.x installation and detection of PHP-FPM/mod_php |
| `phpmyadmin.sh` | phpMyAdmin installation and Apache integration |
| `certbot.sh` | Certbot installation and automatic certificate issuance |
| `firewall.sh` | UFW setup and rule management |
| `cleanup.sh` | Final tasks: remove temp creds, write credential file |
| `install.sh` | Orchestrator: sources modules in correct order and controls flow |
| `uninstall.sh` | (Optional) Reversal script to remove installed components |

---

## Installation

### 1) Clone the repository
```bash
git clone https://github.com/imosudi/lamp-stack-installer.git
cd lamp-stack-installer
```

### 2) Run interactively (recommended for first-time use)
```bash
sudo bash install.sh
```

### 3) Run non-interactively (CI / VPS provisioning)
Provide required parameters when using `--auto`:
```bash
sudo bash install.sh --auto --domain example.com --email admin@example.com   --ip 203.0.113.10 --mysql-root-pass 'StrongRootPwd!' --phpmyadmin-pass 'StrongPhpPwd!'
```

**Notes for `--auto` mode**
- `--domain` and `--email` are **required** for automated SSL issuance.
- Ensure DNS A records for both `example.com` and `phpmyadmin.example.com` point to the server IP before requesting certificates.

---

## Configuration / Environment variables (optional)

You can also create an `.env` file in the repo root and the installer will load it (example):

```bash
AUTO=true
DOMAIN=example.com
CERTBOT_EMAIL=admin@example.com
MANUAL_IP=203.0.113.10
MYSQL_ROOT_PASSWORD=StrongRootPwd!
PHPMYADMIN_PASSWORD=StrongPhpPwd!
ALLOW_SSH=true
LOGFILE=/var/log/lamp-installer/install.log
```

---

## What the Installer Does (high level)

1. Validates inputs (IP, domain) and checks DNS resolution (best effort)  
2. Updates packages and installs prerequisites (curl, wget, openssl, snapd)  
3. Installs and configures Apache (virtual hosts, security headers)  
4. Installs PHP and required extensions (detects PHP-FPM vs mod_php)  
5. Installs MySQL 8.0, sets secure root password, and applies hardening  
6. Installs phpMyAdmin and configures a dedicated Apache vhost  
7. Configures UFW firewall (allows 80/443 and OpenSSH by default)  
8. Installs Certbot via `snap` and requests certificates for both main domain and `phpmyadmin.` subdomain (if email provided)  
9. Writes credentials to `/root/lamp_credentials.txt` (chmod 600) and cleans temporary files  
10. Logs everything to `LOGFILE` (default `/var/log/lamp-installer/install.log`)

---

## Security Hardening Highlights
- MySQL `bind-address` set to `127.0.0.1` and `local-infile=0`  
- Anonymous MySQL users removed and test DB dropped  
- Strong TLS via Let’s Encrypt (automated)  
- Apache security headers added (`X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`)  
- UFW default `deny incoming` and `allow outgoing` policy  
- Credentials file permissioned to `600` and stored in `/root`

---

## Logs & Artifacts

All persistent logs are stored under:
```
/var/log/lamp-installer/
```

Key files:
- `/var/log/lamp-installer/install.log` — installation console output and errors  
- `/root/lamp_credentials.txt` — generated credentials (chmod 600)  
- Apache + MySQL logs remain in their standard locations (`/var/log/apache2/`, `/var/log/mysql/`)

---

## Example Output (success)
```
[2025-11-02 14:01:20] Installing Apache2...
[2025-11-02 14:02:01] Installing MySQL 8.0...
[2025-11-02 14:03:05] Configuring UFW...
[2025-11-02 14:04:10] Obtaining SSL via Let's Encrypt...
[2025-11-02 14:05:33] ✅ LAMP stack installation completed successfully!
Credentials saved to: /root/lamp_credentials.txt
```

---

## Uninstallation

A provided `uninstall.sh` (optional) should be used with caution. A minimal reversal might remove packages and sites but **won't** destroy user data unless explicitly designed to do so.

```bash
sudo bash uninstall.sh
```

---

## Contributing

Contributions welcome — please fork, create a feature branch, and open a pull request. Suggested improvements:
- Support for multiple domains and SAN certificates
- Automatic backup & restore hooks for MySQL
- SELinux/AppArmor policy guides for hardened hosts

---


## License

This project is licensed under the **BSD 3-Clause License** — see the [LICENSE](./LICENSE) file for details.

```
BSD 3-Clause License

Copyright (c) 2025, Mosudi Isiaka
All rights reserved.
```

## 👤 Author

**Mosudi Isiaka**  
📧 [mosudi.isiaka@gmail.com](mailto:mosudi.isiaka@gmail.com)  
🌐 [https://mioemi.com](https://mioemi.com)   
💻 [https://github.com/imosudi](https://github.com/imosudi)


---