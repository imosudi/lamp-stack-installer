# LAMP Stack Installer for Ubuntu 24.04+

Automated **LAMP (Linux, Apache, MySQL, PHP)** stack installer for Ubuntu 24.04+ with full support for both **interactive** and **non-interactive (`--auto`)** deployment modes.

---

## Features
-  Installs **Apache2**, **MySQL 8.0**, **PHP 8.x**, and **PHPMyAdmin**
-  Automatic **SSL provisioning** via Let's Encrypt (**Certbot**)
-  Security hardening with safe default configurations
-  Configures **UFW firewall** and automatic **HTTPS redirection**
-  Persistent installation logs and configuration tracking
-  One-liner deploy for production or developer environments
-  Compatible with Ubuntu 24.04 and newer

---

## ⚙️ Installation

### 1. Clone the Repository
```bash
git clone https://github.com/imosudi/lamp-stack-installer.git
cd lamp-stack-installer
```

### 2. Run the Installer
Run interactively:
```bash
sudo bash install.sh
```

Or use non-interactive mode for automated deployment:
```bash
sudo bash install.sh --auto
```

---

## Components Installed

| Component  | Version (default) | Description |
|-------------|-------------------|--------------|
| Apache2     | Latest (Ubuntu 24.04) | Web server |
| MySQL       | 8.0.x | Database engine |
| PHP         | 8.x | Scripting language |
| PHPMyAdmin  | Latest | Web database admin tool |
| Certbot     | Latest | SSL/TLS certificate automation |
| UFW         | Latest | Firewall configuration |

---

##  Security Hardening

- Enforces **strong MySQL root password policy**
- Configures **UFW** to allow only HTTP (80), HTTPS (443), and SSH (22)
- Enables **fail2ban** (optional prompt in interactive mode)
- Auto-renews Let's Encrypt certificates via cron job
- Sets secure permissions for `/var/www/html`

---

##  Logging & Persistence

All logs and configuration details are stored under:
```
/var/log/lamp-installer/
```
Key files include:
- `install.log` — complete installation output  
- `certbot.log` — SSL provisioning details  
- `mysql_secure.log` — MySQL security configuration results  

---

## Example One-liner for Auto Setup

```bash
curl -sSL https://raw.githubusercontent.com/imosudi/lamp-stack-installer/main/install.sh | sudo bash -s -- --auto
```

---

## Environment Variables (Optional)

If running in `--auto` mode, you can predefine variables in an `.env` file:

```bash
DB_ROOT_PASSWORD=your_strong_password
DOMAIN_NAME=example.com
EMAIL_ADDRESS=admin@example.com
INSTALL_PHPMYADMIN=true
ENABLE_UFW=true
```

The installer automatically loads them if `.env` exists in the working directory.

---

## Uninstallation

To remove all installed components (use with caution):

```bash
sudo bash uninstall.sh
```

---

## Troubleshooting

- Ensure ports **80** and **443** are not already in use.
- Check logs under `/var/log/lamp-installer/` for detailed errors.
- For SSL issues, test Certbot manually:
  ```bash
  sudo certbot renew --dry-run
  ```

---

## Author
**Mosudi Isiaka**  
GitHub: [@imosudi](https://github.com/imosudi)

---

## License
This project is licensed under the **BSD 3-Clause License**.  
See the [LICENSE](LICENSE) file for more details.