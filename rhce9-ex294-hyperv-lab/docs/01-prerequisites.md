# 01 – Prerequisites

## Host requirements (Windows 11)

- Windows 11 **Pro** or **Enterprise** (Hyper-V is not on Home edition)
- CPU virtualization enabled in firmware (VT-x/AMD-V)
- ~12 GB free RAM, ~100 GB free disk (SSD recommended)
- **Windows PowerShell 5.1** run **as Administrator** (not PowerShell 7)
- **OpenSSH client** (ships with Windows 11; provides `ssh` and `ssh-keygen`)

## Software you must supply

- A **RHEL 9 DVD ISO** — the full ~8–9 GB image (not `boot.iso`).
  Get a free copy via a **Red Hat Developer** subscription at
  <https://developer.redhat.com>. Rocky Linux 9 / AlmaLinux 9 GenericCloud or
  DVD ISOs work too.

## Enable Hyper-V

