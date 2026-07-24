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
