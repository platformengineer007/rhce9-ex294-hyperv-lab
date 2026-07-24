#requires -RunAsAdministrator
# Reset-RhceLab.ps1 — wipe all lab VMs and files. License: MIT
$ErrorActionPreference = 'SilentlyContinue'
$LabRoot="C:\HyperV\rhce"; $NatName="rhce-nat"; $SwitchName="rhce"

foreach ($v in 'control','node1','node2','node3','node4') {
    if (Get-VM -Name $v) {
        Stop-VM $v -TurnOff -Force
        Remove-VM $v -Force
    }
}
Remove-Item "$LabRoot\*" -Recurse -Force

# Uncomment for a FULL teardown (also removes network):
# Get-NetNat -Name $NatName | Remove-NetNat -Confirm:$false
# Get-VMSwitch -Name $SwitchName | Remove-VMSwitch -Force

Write-Host "Lab wiped. Re-run .\Deploy-RhceLab.ps1 to rebuild." -ForegroundColor Green
