# 🖥️ Debian Zabbix‐Proxy Preseed & Images ativactor 

Automate a headless Debian install with built‑in Zabbix Proxy (MySQL) in Docker, firewall rules, PSK generation and SSH user setup.

---

🌟 **Highlights**

- **Fully unattended Debian “Bookworm” install** via preseed.cfg  
- **Dynamic Zabbix Proxy** bootstrap script (`ativador.sh`)  
- MySQL container, Zabbix Proxy container (PSK/TLS)  
- Opinionated **iptables** rules + persistence  
- **SSH user** creation with key auth only  
- Designed to be easily forked and customized  

---

ℹ️ **Overview**

This project provides:

1. **`preseed.cfg`** – answers all Debian installer prompts, configures root password, network, packages (Docker, SSH, iptables‑persistent), and invokes `ativador.sh` on first boot.
2. **`ativador.sh`** – once Debian is up, installs Docker, sets up firewall, generates a Zabbix PSK, runs MySQL & Zabbix‑Proxy in containers, and creates a limited SSH user for your client.

Who’s this for?  
- **Sysadmins** who deploy dozens of Zabbix Proxy VMs or bare‑metal boxes  
- **Small teams** that want a reproducible, automated workflow  
- Anyone who’d rather not click through Debian’s installer questions  

---

🚀 **Quickstart**

1. **Host your files** (e.g. on HTTP server or GitHub raw URLs).  
2. Boot Debian net‑install media and, at the “Enter preseed URL” prompt, supply:  
