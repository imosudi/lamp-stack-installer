# UPGRADE_PLAN.md  
### Modular Upgrade Roadmap - LAMP Stack Installer for Ubuntu 24.04+

This document defines a structured roadmap for improving the LAMP Stack Installer modules.  
Each section lists proposed enhancements grouped by **priority**:  
- 🔴 **Critical** - Security, reliability, or compatibility upgrades.  
- 🟡 **Recommended** - Enhancements that improve usability, automation, or maintainability.  
- 🟢 **Optional** - Nice-to-have or advanced capabilities for future versions.

---

## 1. install.sh - Main Orchestrator
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Pre-flight checks | Validate OS version (≥ 24.04), disk space, and network reachability. |
| 🟡 | Idempotent runs | Detect and skip already-installed modules safely. |
| 🟡 | Rollback mode | Undo partial installations upon failure. |
| 🟡 | Colourised output | Use `tput` for progress icons and readable logs. |
| 🟢 | System snapshot | Optional backup of Apache/MySQL configs before execution. |

---

## 2. config.sh - Configuration & CLI Parsing
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Input validation | Enforce strict domain, IP, and password validation pre-install. |
| 🟡 | `.env` / `config.yaml` support | Load configuration for CI/CD or non-interactive automation. |
| 🟡 | Config persistence | Save sanitised config state in `/var/log/lamp-installer/config.state`. |
| 🟢 | SSH key import | Auto-detect and secure SSH key-based login in `--auto` mode. |

---

## 3. helpers.sh - Utility Library
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Structured logging | Add log levels (`INFO`, `WARN`, `ERROR`) with timestamp and JSON mode. |
| 🟡 | Enhanced password generator | Variable entropy and complexity levels. |
| 🟡 | Remote logging | Optional syslog/webhook log streaming. |
| 🟢 | TTY detection | Disable colour codes in non-interactive environments (CI/CD, cron). |

---

## 4. firewall.sh - UFW Configuration
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Fail2ban integration | Auto-install and configure fail2ban after UFW setup. |
| 🟡 | Application profiles | Register UFW app profiles for Apache, MySQL, phpMyAdmin. |
| 🟡 | Dynamic rules | Detect active services and open only required ports. |
| 🟢 | Log centralisation | Enable dedicated UFW log under `/var/log/ufw/lamp.log`. |

---

## 5. install_packages.sh - Base Package Setup
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Retry mechanism | Automatically retry failed apt installs (transient errors). |
| 🟡 | Version pinning | Use `apt-mark hold` for stability on production. |
| 🟡 | Developer mode | `--dev` flag to install tools like `vim`, `htop`, `git`. |
| 🟢 | Integrity checks | Verify package checksums for additional security. |

---

## 6. mysql.sh - MySQL Installation & Hardening
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Remote access control | `--allow-remote-db` flag with IP whitelist and SSL-based connections. |
| 🔴 | Audit plugin | Enable MySQL audit logging for privileged queries. |
| 🟡 | Automated backups | Daily `mysqldump` via systemd timer + retention policy. |
| 🟢 | Tunable parameters | Customise performance options (`max_connections`, `buffer_pool_size`, etc.). |

---

## 7. php.sh - PHP Installation & Configuration
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | PHP security hardening | Disable unsafe functions (`exec`, `shell_exec`, `system`) in production. |
| 🟡 | OPcache / JIT optimisation | Auto-tune performance settings in `php.ini`. |
| 🟡 | Version selection | Add `--php-version` flag (e.g. 8.2 / 8.3). |
| 🟢 | Apache integration | Auto-enable proxy modules when using FPM. |

---

## 8. apache.sh - Apache Virtual Host Configuration
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | HSTS enforcement | Add strict-transport-security headers to SSL vhosts. |
| 🟡 | HTTP/2 + Brotli | Enable modern compression and multiplexing. |
| 🟡 | Auto SSL binding | Link 443 VirtualHost to generated certs. |
| 🟢 | Reverse proxy readiness | Pre-enable `proxy`, `proxy_fcgi`, `rewrite` modules. |

---

## 9. certbot.sh - SSL Provisioning
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Renewal monitoring | Alert admin via email if auto-renew fails. |
| 🟡 | Wildcard certificates | Support DNS-01 challenge with provider API keys. |
| 🟡 | Staging mode | `--staging` flag for dry-run without rate limits. |
| 🟢 | Nginx fallback | Detect Nginx and use appropriate Certbot plugin. |

---

## 10. cleanup.sh - Post-Installation Tasks
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Secure temp deletion | Wipe temporary files (`.my.cnf`, etc.) using `shred`. |
| 🟡 | Summary report | Generate `/root/lamp_install_summary.txt` with all credentials & URLs. |
| 🟡 | Reboot prompt | Offer reboot if kernel updates detected. |
| 🟢 | Telemetry (opt-in) | Anonymised install stats for future optimisation. |

---

## 11. Cross-Module Enhancements
| Priority | Upgrade | Description |
|-----------|----------|-------------|
| 🔴 | Global error trap | Capture failing module name, log gracefully, exit cleanly. |
| 🟡 | Health-check utility | Verify Apache, MySQL, PHP, and SSL status post-install. |
| 🟡 | Self-update flag | `--update` option to pull latest scripts from GitHub. |
| 🟢 | Docker support | Optional containerised mode for CI/CD. |

---

## Implementation Phases

| Phase | Focus | Modules |
|-------|--------|----------|
| **Phase 1 (Security & Reliability)** | Critical updates - pre-flight checks, MySQL hardening, UFW + fail2ban, logging improvements | `install.sh`, `mysql.sh`, `firewall.sh`, `helpers.sh` |
| **Phase 2 (Automation & Usability)** | Non-interactive config, rollback, backup, structured logs | `config.sh`, `install_packages.sh`, `cleanup.sh` |
| **Phase 3 (Performance & Optimisation)** | PHP tuning, Apache HTTP/2, SSL binding, OPcache | `php.sh`, `apache.sh`, `certbot.sh` |
| **Phase 4 (Advanced Features)** | Docker support, telemetry, health-check, self-update | Cross-module |

---

## Version Target
| Milestone | Planned Release |
|------------|----------------|
| **v1.1.0** | Phase 1 security + logging upgrades |
| **v1.2.0** | Automation / rollback / config import |
| **v1.3.0** | Performance & cert enhancements |
| **v2.0.0** | Container / Telemetry / Self-update integration |

---

### Maintainer
**Mosudi Isiaka**  
GitHub: [@imosudi](https://github.com/imosudi)

---
