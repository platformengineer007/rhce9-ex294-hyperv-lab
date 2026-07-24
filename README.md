# RHCE EX294 (RHEL 9) Practice Lab — Windows 11 + Hyper-V

Fully automated, zero-touch deployment of an **RHCE EX294 (RHEL 9)** practice lab
on **Windows 11 Pro** using **Hyper-V** and **PowerShell**. One script builds a
control node and four managed nodes via kickstart — no manual OS install.

Native **Hyper-V + PowerShell** automation instead of Vagrant/VirtualBox/KVM.

## Topology

| Role | Hostname | IP (`rhce` NAT net 192.168.55.0/24) | RAM | vCPU | Extra disks |
|------|----------|-------------------------------------|-----|------|-------------|
| control | control.example.com | 192.168.55.200 | 2560 MB | 2 | – |
| node1 | node1.example.com | 192.168.55.201 | 2048 MB | 1 | – |
| node2 | node2.example.com | 192.168.55.202 | 2048 MB | 1 | 1G + 1G |
| node3 | node3.example.com | 192.168.55.203 | 2048 MB | 1 | 1G + 1G |
| node4 | node4.example.com | 192.168.55.204 | 2048 MB | 1 | – |

- Users: `root` / `redhat`, and `ansible` / `redhat` (passwordless sudo).
- Guest OS: **RHEL 9** (works with Rocky/AlmaLinux 9 too).

## Requirements

- Windows 11 Pro/Enterprise with **Hyper-V** enabled
- **Windows PowerShell 5.1** (run as Administrator)
- A **RHEL 9 DVD ISO** (the full ~8–9 GB image, not `boot.iso`)
- ~12 GB free RAM and ~100 GB free disk

## Quick start

powershell

1. Enable Hyper-V (reboot afterwards)
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All

2. Edit the CONFIG block in Deploy-RhceLab.ps1 — set $RhelIso to your ISO path
3. Deploy (elevated Windows PowerShell 5.1)
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Deploy-RhceLab.ps1

4. When installs finish (~5-10 min each), log into the control node
ssh ansible@192.168.55.200


See [`docs/`](docs/) for full details, collection install workaround, troubleshooting, and practice exercises.

## Reset / teardown

powershell
.\Reset-RhceLab.ps1


## Documentation

- [01 – Prerequisites](docs/01-prerequisites.md)
- [02 – Deploy the lab](docs/02-deploy.md)
- [03 – Install Ansible collections (ansible-core 2.12 workaround)](docs/03-install-collections.md)
- [04 – Troubleshooting](docs/04-troubleshooting.md)
- [05 – Practice exercises](docs/05-exercises.md)

## Disclaimer

This lab is for **self-study only.

Repository structure

rhce9-ex294-hyperv-lab/
├── README.md
├── LICENSE
├── .gitignore
├── Deploy-RhceLab.ps1
├── Reset-RhceLab.ps1
├── scripts/
│   ├── install-collections.sh
│   └── collections.sha256
├── collections/
│   └── requirements.yml
├── control-node/
│   ├── ansible.cfg
│   └── inventory
└── docs/
    ├── 01-prerequisites.md
    ├── 02-deploy.md
    ├── 03-install-collections.md
    ├── 04-troubleshooting.md
    └── 05-exercises.md
