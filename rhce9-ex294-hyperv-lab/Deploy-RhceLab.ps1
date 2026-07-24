#requires -RunAsAdministrator
# Deploy-RhceLab.ps1 — RHCE EX294 (RHEL 9) lab on Hyper-V, fully automated.
# Repo: https://github.com/<you>/rhce9-ex294-hyperv-lab
# License: MIT

$ErrorActionPreference = 'Stop'

#region ================= CONFIG =================
$RhelIso   = "C:\ISO\rhel-9.0-x86_64-dvd.iso"     # <-- set to YOUR RHEL 9 DVD ISO
$LabRoot   = "C:\HyperV\rhce"                      # where VHDX + kickstart ISOs go
$SwitchName= "rhce"
$NatName   = "rhce-nat"
$Subnet    = "192.168.55.0/24"
$HostIP    = "192.168.55.1"
$Gateway   = $HostIP
$DNS       = "1.1.1.1"
$Domain    = "example.com"
$RootPw    = "redhat"
$AnsPw     = "redhat"

$VMs = @(
  @{ Name='control'; IP='192.168.55.200'; Ram=2560MB; Cpu=2; Disks='-';   Ansible=1 }
  @{ Name='node1';   IP='192.168.55.201'; Ram=2048MB; Cpu=1; Disks='-';   Ansible=0 }
  @{ Name='node2';   IP='192.168.55.202'; Ram=2048MB; Cpu=1; Disks='1,1'; Ansible=0 }
  @{ Name='node3';   IP='192.168.55.203'; Ram=2048MB; Cpu=1; Disks='1,1'; Ansible=0 }
  @{ Name='node4';   IP='192.168.55.204'; Ram=2048MB; Cpu=1; Disks='-';   Ansible=0 }
)
#endregion

#region ============ PRE-FLIGHT VALIDATION ============
if ($PSVersionTable.PSVersion.Major -ne 5) {
    throw "Run this in Windows PowerShell 5.1 (not PowerShell 7). Current: $($PSVersionTable.PSVersion)"
}
if (-not (Get-Command New-VM -ErrorAction SilentlyContinue)) {
    throw "Hyper-V module not found. Enable Hyper-V and reboot first."
}
if (-not (Test-Path $RhelIso)) { throw "RHEL ISO not found: $RhelIso" }
if ((Get-Item $RhelIso).Length -lt 3GB) {
    Write-Warning "ISO is < 3 GB - make sure this is the full DVD, not boot.iso."
}
New-Item -ItemType Directory -Force -Path $LabRoot | Out-Null
#endregion

#region ============ SSH key (host -> guests) ============
$SshDir     = "$env:USERPROFILE\.ssh"
$SshPubPath = "$SshDir\id_rsa.pub"
if (-not (Test-Path $SshDir)) { New-Item -ItemType Directory -Path $SshDir -Force | Out-Null }
if (-not (Test-Path $SshPubPath)) {
    Write-Host "Generating SSH key..." -ForegroundColor Cyan
    ssh-keygen -t rsa -b 4096 -N '""' -f "$SshDir\id_rsa" -q
}
if (-not (Test-Path $SshPubPath)) { throw "SSH key generation failed (is OpenSSH client installed?)." }
$SshPub = (Get-Content $SshPubPath -Raw).Trim()
#endregion

#region ============ /etc/hosts block (shared) ============
$HostsBlock = "127.0.0.1 localhost localhost.localdomain`n"
foreach ($v in $VMs) { $HostsBlock += "$($v.IP) $($v.Name).$Domain $($v.Name)`n" }
#endregion

#region ============ Network: internal switch + NAT ============
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    New-VMSwitch -SwitchName $SwitchName -SwitchType Internal | Out-Null
    Start-Sleep -Seconds 3
}
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
    throw "Virtual switch '$SwitchName' was not created. See docs/04-troubleshooting.md (error 0x800700B7)."
}
$if = Get-NetAdapter -Name "vEthernet ($SwitchName)"
if (-not (Get-NetIPAddress -InterfaceIndex $if.ifIndex -IPAddress $HostIP -ErrorAction SilentlyContinue)) {
    New-NetIPAddress -IPAddress $HostIP -PrefixLength 24 -InterfaceIndex $if.ifIndex | Out-Null
}
if (-not (Get-NetNat -Name $NatName -ErrorAction SilentlyContinue)) {
    New-NetNat -Name $NatName -InternalIPInterfaceAddressPrefix $Subnet | Out-Null
}
#endregion

#region ============ ISO builder (labels volume OEMDRV) ============
if (-not ('ISOFile' -as [type])) {
$code = @'
public class ISOFile {
  public unsafe static void Create(string Path, object Stream, int BlockSize, int TotalBlocks) {
    int bytes = 0; byte[] buf = new byte[BlockSize];
    var ptr = (System.IntPtr)(&bytes);
    System.IO.FileStream o = System.IO.File.OpenWrite(Path);
    System.Runtime.InteropServices.ComTypes.IStream i =
        Stream as System.Runtime.InteropServices.ComTypes.IStream;
    if (o != null) {
      while (TotalBlocks-- > 0) { i.Read(buf, BlockSize, ptr); o.Write(buf, 0, bytes); }
      o.Flush(); o.Close();
    }
  }
}
'@
Add-Type -CompilerParameters (New-Object System.CodeDom.Compiler.CompilerParameters -Property `
  @{CompilerOptions='/unsafe'}) -TypeDefinition $code
}

function New-OemDrvIso {
    param([string]$KsContent, [string]$IsoPath)
    $tmp = Join-Path $env:TEMP ("oemdrv_" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Set-Content -Path (Join-Path $tmp 'ks.cfg') -Value $KsContent -Encoding Ascii
    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 3
    $fsi.VolumeName = 'OEMDRV'
    $fsi.Root.AddTree($tmp, $false)
    $img = $fsi.CreateResultImage()
    if (Test-Path $IsoPath) { Remove-Item $IsoPath -Force }
    [ISOFile]::Create($IsoPath, $img.ImageStream, $img.BlockSize, $img.TotalBlocks)
    Remove-Item $tmp -Recurse -Force
}
#endregion

#region ============ Kickstart generator ============
function New-Kickstart {
    param($V)
    $fqdn = "$($V.Name).$Domain"
    $ansiblePkg = if ($V.Ansible -eq 1) { "ansible-core`ngit`nvim-enhanced`ntar" } else { "" }
@"
text
eula --agreed
cdrom
lang en_US.UTF-8
keyboard us
timezone America/New_York --utc
network --bootproto=static --ip=$($V.IP) --netmask=255.255.255.0 --gateway=$Gateway --nameserver=$DNS --hostname=$fqdn --device=link --activate
rootpw $RootPw
user --name=ansible --password=$AnsPw --groups=wheel
firstboot --disable
firewall --enabled --service=ssh
selinux --enforcing
services --enabled=sshd
bootloader --location=mbr
clearpart --all --initlabel --drives=sda
autopart --type=lvm
reboot
%packages
@^minimal-environment
openssh-server
$ansiblePkg
%end
%post --log=/root/ks-post.log
echo '%wheel ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel
cat >> /etc/hosts <<'HOSTS'
$HostsBlock
HOSTS
mkdir -p /root/.ssh /home/ansible/.ssh
echo '$SshPub' >> /root/.ssh/authorized_keys
echo '$SshPub' >> /home/ansible/.ssh/authorized_keys
chmod 700 /root/.ssh /home/ansible/.ssh
chmod 600 /root/.ssh/authorized_keys /home/ansible/.ssh/authorized_keys
chown -R ansible:ansible /home/ansible/.ssh
%end
"@
}
#endregion

#region ============ Build & launch each VM ============
foreach ($V in $VMs) {
    $name = $V.Name
    Write-Host "=== Building $name ===" -ForegroundColor Green
    $vhd = Join-Path $LabRoot "$name.vhdx"
    $ks  = Join-Path $LabRoot "$name-oemdrv.iso"

    New-OemDrvIso -KsContent (New-Kickstart $V) -IsoPath $ks

    if (Get-VM -Name $name -ErrorAction SilentlyContinue) {
        Stop-VM $name -TurnOff -Force -ErrorAction SilentlyContinue
        Remove-VM $name -Force
    }
    if (Test-Path $vhd) { Remove-Item $vhd -Force }

    New-VM -Name $name -Generation 2 -MemoryStartupBytes $V.Ram `
           -NewVHDPath $vhd -NewVHDSizeBytes 20GB -SwitchName $SwitchName | Out-Null

    Set-VMMemory    -VMName $name -DynamicMemoryEnabled $false
    Set-VMProcessor -VMName $name -Count $V.Cpu
    Set-VM -Name $name -AutomaticCheckpointsEnabled $false
    Set-VMFirmware -VMName $name -EnableSecureBoot Off

    Add-VMDvdDrive -VMName $name -Path $ks
    $dvd = Add-VMDvdDrive -VMName $name -Path $RhelIso -Passthru
    Set-VMFirmware -VMName $name -FirstBootDevice $dvd

    if ($V.Disks -ne '-') {
        $i = 1
        foreach ($sz in ($V.Disks -split ',')) {
            $extra = Join-Path $LabRoot "$name-disk$i.vhdx"
            if (Test-Path $extra) { Remove-Item $extra -Force }
            New-VHD -Path $extra -SizeBytes ([int]$sz * 1GB) -Dynamic | Out-Null
            Add-VMHardDiskDrive -VMName $name -Path $extra
            $i++
        }
    }
    Start-VM -Name $name
}

Write-Host "`nAll VMs launched. Anaconda is installing unattended (~5-10 min each)." -ForegroundColor Cyan
Write-Host "Watch a console with:  vmconnect localhost control"
#endregion
