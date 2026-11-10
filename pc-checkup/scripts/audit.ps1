<#
  pc-checkup - audit Windows en LECTURE SEULE.
  Ne modifie rien. Fonctionne sans droits admin (les points qui en demandent sont signalés "ADMIN REQUIS").
  Usage : powershell -NoProfile -ExecutionPolicy Bypass -File audit.ps1 [-Quick]
    -Quick : saute les mesures de taille de dossiers (plus rapide).
  Chaque ligne "[!]" est un point à examiner, "[ok]" est conforme, "[i]" est une info.
#>
param([switch]$Quick)

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

function Section($n) { "`n## $n" }
function Flag($msg) { "[!] $msg" }
function Ok($msg)   { "[ok] $msg" }
function Info($msg) { "[i] $msg" }
function Get-RegVal($path, $name) {
  $v = (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue).$name
  if ($null -eq $v) { '(défaut)' } else { $v }
}
function Get-DirSizeGB($p) {
  if (-not (Test-Path -LiteralPath $p)) { return $null }
  [math]::Round(((Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB), 2)
}
function Run-Block($name, [scriptblock]$sb) {
  Section $name
  try { & $sb } catch { Flag "Section interrompue : $($_.Exception.Message)" }
}

$script:residueVendors = @()
$isAdmin =([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
"# Rapport pc-checkup - $(Get-Date -Format 'yyyy-MM-dd HH:mm') - admin: $isAdmin"

# ---------------------------------------------------------------- 1
Run-Block '1. Matériel et système' {
  $cs = Get-CimInstance Win32_ComputerSystem; $os = Get-CimInstance Win32_OperatingSystem
  $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
  $bb = Get-CimInstance Win32_BaseBoard; $bios = Get-CimInstance Win32_BIOS
  Info "PC : $($cs.Manufacturer) $($cs.Model)"
  Info "OS : $($os.Caption) build $($os.BuildNumber) (installé le $($os.InstallDate.ToString('yyyy-MM-dd')))"
  if ($os.Caption -match 'Windows 10') { Flag "Windows 10 ne reçoit plus de mises à jour de sécurité gratuites depuis octobre 2025 : passer à Windows 11 si le PC est compatible" }
  $lic = (cscript //nologo "$env:windir\System32\slmgr.vbs" /xpr 2>$null | Out-String).Trim()
  if ($lic -match 'finitivement|permanent') { Ok 'Windows activé définitivement' }
  elseif ($lic -match 'expir') { Info "Activation Windows : licence avec date d'expiration (KMS/entreprise)" }
  elseif ($lic) { Flag 'Windows ne semble pas activé (vérifier Paramètres > Système > Activation)' }
  Info "CPU : $($cpu.Name.Trim()) - $($cpu.NumberOfCores)c/$($cpu.NumberOfLogicalProcessors)t - charge $($cpu.LoadPercentage)%"
  Info "Carte mère : $($bb.Manufacturer) $($bb.Product)"
  $biosAge = ((Get-Date) - $bios.ReleaseDate).TotalDays / 365
  $msg = "BIOS : $($bios.SMBIOSBIOSVersion) du $($bios.ReleaseDate.ToString('yyyy-MM-dd')) ($([math]::Round($biosAge,1)) ans)"
  if ($biosAge -gt 2) { Flag "$msg -> probablement pas à jour, vérifier le site du fabricant" } else { Ok $msg }
  $up = (Get-Date) - $os.LastBootUpTime
  $msg = "Uptime : $([math]::Floor($up.TotalDays)) j $($up.Hours) h"
  if ($up.TotalDays -gt 7) { Flag "$msg -> redémarrer" } else { Ok $msg }
  $tot = [math]::Round($cs.TotalPhysicalMemory/1GB,1); $free = [math]::Round($os.FreePhysicalMemory/1MB,1)
  Info "RAM : $tot Go (libre $free Go)"
}

# ---------------------------------------------------------------- 2
Run-Block '2. Mémoire (XMP / EXPO)' {
  $mods = Get-CimInstance Win32_PhysicalMemory
  $parts = @()
  foreach ($m in $mods) {
    $pn = "$($m.PartNumber)".Trim()
    $rated = $null
    if ($pn -match '(2133|2400|2666|2933|3000|3200|3333|3466|3600|3733|3866|4000|4133|4266|4400|4800|5200|5600|6000|6200|6400|6600|6800|7200|7600|8000)') { $rated = [int]$Matches[1] }
    elseif ($pn -match 'G(2[4-9]|3[0-9]|4[0-9])C\d{2}') { $rated = [int]$Matches[1] * 100 }   # ex. BL8G32C16 (Crucial)
    elseif ($pn -match '4D(2[4-9]|3[0-9]|4[0-9])') { $rated = [int]$Matches[1] * 100 }        # ex. BLS8G4D32 (Crucial)
    elseif ($pn -match 'KF\d(2[4-9]|3[0-9]|4[0-9])C') { $rated = [int]$Matches[1] * 100 }     # ex. KF432C16 (Kingston)
    $type = switch ($m.SMBIOSMemoryType) { 26 {'DDR4'} 34 {'DDR5'} 24 {'DDR3'} default {"type $($m.SMBIOSMemoryType)"} }
    $parts += $pn
    $line = "$($m.DeviceLocator)/$($m.BankLabel) : $([math]::Round($m.Capacity/1GB)) Go $type @ $($m.ConfiguredClockSpeed) MT/s - réf. $pn"
    if ($rated -and $m.ConfiguredClockSpeed -lt ($rated - 50)) { Flag "$line -> barrette prévue pour $rated : XMP/EXPO désactivé" }
    elseif (-not $rated -and (($type -eq 'DDR4' -and $m.ConfiguredClockSpeed -le 2666) -or ($type -eq 'DDR5' -and $m.ConfiguredClockSpeed -le 4800))) { Flag "$line -> fréquence JEDEC de base, XMP/EXPO probablement désactivé (vérifier la référence)" }
    else { Ok $line }
  }
  # Dual channel : les barrettes doivent être réparties sur au moins 2 canaux
  $chans = $mods | ForEach-Object { if ("$($_.BankLabel) $($_.DeviceLocator)" -match '(?:CHANNEL\s*|Channel|ChannelA-|DIMM_?)([A-D])') { $Matches[1] } } | Select-Object -Unique
  if (@($mods).Count -eq 1) { Flag "Une seule barrette : mode single channel, performances réduites (surtout en jeu) - ajouter une 2e barrette identique" }
  elseif (@($chans).Count -eq 1) { Flag "Toutes les barrettes sont sur le canal $chans : mode single channel - les déplacer dans les slots indiqués par le manuel (souvent A2/B2)" }
  elseif (@($chans).Count -ge 2) { Ok "Dual channel : barrettes réparties sur les canaux $($chans -join ', ')" }
  else { Info 'Répartition des canaux mémoire non lisible (vérifier avec CPU-Z si doute)' }
  if (($parts | Select-Object -Unique).Count -gt 1) { Flag "Barrettes de références différentes ($((($parts | Select-Object -Unique) -join ', '))) : XMP possible mais stabilité à tester (mdsched), repli 3000 MHz si instable" }
}

# ---------------------------------------------------------------- 3
Run-Block '3. GPU et écrans' {
  Get-CimInstance Win32_VideoController | ForEach-Object {
    $age = ((Get-Date) - $_.DriverDate).TotalDays
    $line = "GPU : $($_.Name) - pilote $($_.DriverVersion) du $($_.DriverDate.ToString('yyyy-MM-dd'))"
    if ($age -gt 180 -and $_.Name -notmatch 'Basic|Virtual|Remote') { Flag "$line -> pilote de plus de 6 mois" } else { Ok $line }
  }
  $smi = "$env:windir\System32\nvidia-smi.exe"
  if (Test-Path $smi) {
    foreach ($l in (& $smi --query-gpu=name,temperature.gpu,utilization.gpu,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max,power.draw --format=csv,noheader,nounits 2>$null)) {
      $f = $l -split ',\s*'
      $line = "NVIDIA $($f[0]) : $($f[1])°C, charge $($f[2])%, PCIe Gen$($f[3]) x$($f[4]) (max x$($f[5])), $($f[6]) W"
      if ([int]$f[4] -lt [int]$f[5]) { Flag "$line -> la carte tourne en x$($f[4]) au lieu de x$($f[5]) : mauvais slot PCIe, carte mal enfoncée ou lignes partagées avec un SSD" }
      elseif ([int]$f[1] -ge 85) { Flag "$line -> température élevée : dépoussiérer, vérifier les ventilateurs et le flux d'air du boîtier" }
      else { Ok $line }
    }
  }
  Add-Type -AssemblyName System.Windows.Forms
  Add-Type @'
using System; using System.Runtime.InteropServices;
public class PcCheckDM {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)] public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string n; public short a,b,c,d; public int e; public int x,y; public int o,f;
    public short g,h,i,j,k; [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string fn; public short lp; public int bpp,w,hgt,flags,freq;
    public int a1,a2,a3,a4,a5,a6,a7,a8; }
  [DllImport("user32.dll")] public static extern bool EnumDisplaySettings(string d, int m, ref DEVMODE dm);
  public static int[] Cur(string d){ var m=new DEVMODE(); m.c=(short)Marshal.SizeOf(m); if(!EnumDisplaySettings(d,-1,ref m)) return new int[]{0,0,0}; return new int[]{m.w,m.hgt,m.freq}; }
  public static int MaxHz(string d,int w,int h){ int mx=0; var m=new DEVMODE(); m.c=(short)Marshal.SizeOf(m); for(int i=0;EnumDisplaySettings(d,i,ref m);i++){ if(m.w==w && m.hgt==h && m.freq>mx) mx=m.freq; } return mx; }
}
'@
  foreach ($s in [System.Windows.Forms.Screen]::AllScreens) {
    $c = [PcCheckDM]::Cur($s.DeviceName); $max = [PcCheckDM]::MaxHz($s.DeviceName, $c[0], $c[1])
    $line = "Écran $($s.DeviceName) : $($c[0])x$($c[1]) @ $($c[2]) Hz (max à cette résolution : $max Hz)$(if($s.Primary){' - principal'})"
    if ($max -gt $c[2] + 1) { Flag "$line -> fréquence sous-exploitée" } else { Ok $line }
  }
}

# ---------------------------------------------------------------- 4
Run-Block '4. Pilotes et périphériques' {
  $bad = Get-PnpDevice -PresentOnly | Where-Object { $_.Status -ne 'OK' -and $_.Status -ne 'Unknown' }
  if ($bad) { $bad | ForEach-Object { Flag "Périphérique en erreur : $($_.FriendlyName) [$($_.Class)] statut $($_.Status)" } } else { Ok 'Aucun périphérique en erreur' }
  Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceClass -in 'NET','MEDIA','SYSTEM','HDC','SCSIADAPTER','BLUETOOTH' -and $_.Manufacturer -and $_.Manufacturer -notmatch 'Microsoft|\(Standard|Standard ' -and $_.DriverDate } |
    Sort-Object DeviceClass, DeviceName -Unique | ForEach-Object {
      $age = ((Get-Date) - $_.DriverDate).TotalDays / 365
      $line = "$($_.DeviceClass) : $($_.DeviceName) - $($_.Manufacturer) $($_.DriverVersion) du $($_.DriverDate.ToString('yyyy-MM-dd'))"
      if ($age -gt 2) { Flag "$line -> pilote de plus de 2 ans" } else { Info $line }
    }
  Get-NetAdapter -Physical | ForEach-Object {
    $line = "Réseau : $($_.Name) ($($_.InterfaceDescription)) $($_.Status) $($_.LinkSpeed)"
    if ($_.Status -eq 'Up' -and $_.InterfaceDescription -match '2\.5G|5G|10G' -and $_.LinkSpeed -match '^(1|100) ') { Flag "$line -> carte multi-gigabit négociée en bas débit (câble/port box ?)" }
    else { Info $line }
  }
  $multi = Get-NetAdapter -Physical | Where-Object { $_.InterfaceDescription -match '2\.5G|5G' -and $_.Status -ne 'Up' }
  $up = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' -and $_.LinkSpeed -match '^1 G' -and $_.MediaType -match '802.3' }
  if ($multi -and $up) { Flag "Un port 2,5G est libre alors que le câble est sur un port 1G : brancher sur le 2,5G si la box le gère" }
  # Anciennes versions de pilotes conservées dans le DriverStore
  $blocks = (pnputil /enum-drivers 2>$null | Out-String) -split "`r?`n\s*`r?`n"
  $pk = foreach ($b in $blocks) {
    $l = $b -split "`r?`n"
    $orig = ($l | Where-Object { $_ -match 'Original Name|Nom d.origine' }) -replace '^[^:]*:\s*',''
    $pub  = ($l | Where-Object { $_ -match 'Published Name|Nom publi' }) -replace '^[^:]*:\s*',''
    if ($orig) { [pscustomobject]@{ Orig = $orig.Trim(); Pub = $pub.Trim() } }
  }
  $old = $pk | Group-Object Orig | Where-Object Count -gt 1
  if ($old) { Info "$(($old | ForEach-Object { $_.Count - 1 } | Measure-Object -Sum).Sum) ancienne(s) version(s) de pilotes conservée(s) : $(($old.Name) -join ', ') (nettoyage optionnel, gain faible)" }
}

# ---------------------------------------------------------------- 5
Run-Block '5. Mises à jour' {
  try {
    $r = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search('IsInstalled=0 and IsHidden=0')
    if ($r.Updates.Count -eq 0) { Ok 'Windows Update : rien en attente' }
    else { $r.Updates | ForEach-Object { Flag "Windows Update en attente : $($_.Title)" } }
  } catch { Info "Windows Update : interrogation impossible ($($_.Exception.Message))" }
  if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { Flag 'Redémarrage requis par Windows Update' }
  Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 3 | ForEach-Object { Info "Dernier correctif : $($_.HotFixID) $($_.InstalledOn)" }
  if (Get-Command winget -ErrorAction SilentlyContinue) {
    $w = winget upgrade --accept-source-agreements --disable-interactivity 2>$null | Out-String -Width 300
    $lines = $w -split "`r?`n" | Where-Object { $_ -match '\S+\s+\S+\s+\S+\s+\S+\s+(winget|msstore)\s*$' }
    if ($lines) { $lines | ForEach-Object { Flag "winget : $($_.Trim() -replace '\s{2,}',' | ')" } } else { Ok 'winget : tout est à jour' }
  } else { Info 'winget absent : mises à jour logicielles non vérifiables' }
}

# ---------------------------------------------------------------- 6
Run-Block '6. Applications installées et doublons' {
  $keys = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
  $apps = Get-ItemProperty $keys | Where-Object { $_.DisplayName -and -not $_.SystemComponent -and -not $_.ParentKeyName } | Sort-Object DisplayName -Unique
  Info "$($apps.Count) applications de bureau installées :"
  $apps | ForEach-Object { "    - $($_.DisplayName) | $($_.DisplayVersion) | $([math]::Round($_.EstimatedSize/1024)) Mo" }
  # Doublons de version (hors redistribuables qui coexistent normalement)
  $apps | Where-Object { $_.DisplayName -notmatch 'Redistributable|Runtime|SDK|Launcher|Update Health|GameInput' } |
    Group-Object { ($_.DisplayName -replace '\s*\(?(x64|x86|64-bit|32-bit)\)?','' -replace '[\s\-]*v?\d+(\.\d+)+.*$','').Trim() } |
    Where-Object { $_.Count -gt 1 } | ForEach-Object { Flag "Plusieurs versions de « $($_.Name) » : $(($_.Group | ForEach-Object { $_.DisplayVersion }) -join ', ')" }
  # Plusieurs Python : vérifier que « python » et « py » lancent le même
  $pyPath = (Get-Command python -All -ErrorAction SilentlyContinue | Where-Object { $_.Source -notmatch '\\WindowsApps\\' } | Select-Object -First 1).Source
  $pyDef = (py -0p 2>$null | Where-Object { $_ -match '\*' } | Select-Object -First 1) -replace '^.*?(\S+\\python\.exe)\s*$','$1'
  if ($pyPath -and $pyDef -and ($pyPath -ne $pyDef.Trim())) { Flag "« python » lance $pyPath mais « py » lance $($pyDef.Trim()) : deux Python actifs, les modules installés avec l'un manquent à l'autre" }
  # Même appli installée à la fois "pour tous" (Program Files) et "pour moi" (AppData\Programs).
  # Program Files + Program Files (x86) ensemble est normal (composants 32/64 bits) : on ne compare pas ces deux-là entre eux.
  $userRoot = "$env:LOCALAPPDATA\Programs"
  if (Test-Path $userRoot) {
    $machine = @($env:ProgramFiles, ${env:ProgramFiles(x86)}) | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object { Get-ChildItem $_ -Directory }
    Get-ChildItem $userRoot -Directory | ForEach-Object {
      $n = $_.Name; $twin = $machine | Where-Object Name -eq $n
      if ($twin) { Flag "« $n » installé deux fois : $(($twin.FullName) -join ' ; ') ET $($_.FullName)" }
    }
  }
  # Copie d'une appli sur un autre disque (ancienne install, restes d'un ancien Windows)
  $sysDrive = $env:SystemDrive.TrimEnd(':')
  $known = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, "$env:LOCALAPPDATA\Programs") | Where-Object { $_ -and (Test-Path $_) } | ForEach-Object { Get-ChildItem $_ -Directory }
  Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' -and $_.DriveLetter -ne $sysDrive } | ForEach-Object {
    Get-ChildItem "$($_.DriveLetter):\" -Directory -Force | Where-Object { $_.Name -notmatch '^(\$|System Volume|Recovery|Program Files|WindowsApps|Windows|Users|MSOCache|Config\.Msi|msdownld)' } | ForEach-Object {
      $n = $_.Name; $twin = $known | Where-Object Name -eq $n
      if ($twin) { Flag "« $n » existe sur $($_.FullName) alors que l'appli est installée dans $(($twin.FullName) -join ' ; ') : ancienne copie probable ($(Get-DirSizeGB $_.FullName) Go)" }
    }
  }
  # Résidus d'éditeurs connus sans désinstalleur
  $vendors = 'Avast Software','AVG','Norton','McAfee','Kaspersky','Adobe','CCleaner','Driver Booster','IObit','Opera','Avira','ESET','Bitdefender','Malwarebytes'
  foreach ($v in $vendors) {
    $dirs = @("$env:ProgramFiles\$v", "${env:ProgramFiles(x86)}\$v", "$env:ProgramData\$v", "$env:ProgramFiles\Common Files\$v") | Where-Object { Test-Path $_ }
    $vn = [regex]::Escape(($v -replace ' Software',''))
    $installed = $apps | Where-Object { $_.DisplayName -match $vn -or $_.Publisher -match $vn }
    # Composant encore enregistré mais sans nom affiché (invisible dans Paramètres) : il a un désinstalleur officiel
    $hidden = Get-ItemProperty $keys | Where-Object { -not $_.DisplayName -and ($_.Publisher -match $vn -or $_.UninstallString -match $vn) }
    foreach ($h in $hidden) { Flag "Composant $v encore installé mais caché (absent de Paramètres) : $($h.InstallLocation) -> utiliser son désinstalleur : $($h.UninstallString)" }
    if ($dirs -and -not $installed) { Flag "Résidus de $v (logiciel désinstallé) : $($dirs -join ' ; ')$(if($hidden){' - lancer d''abord le désinstalleur du composant caché'})"; $script:residueVendors += $v }
  }
  Section '6b. Applications du Store (hors système)'
  Get-AppxPackage | Where-Object { -not $_.IsFramework -and $_.SignatureKind -ne 'System' } | Sort-Object Name | ForEach-Object { "    - $($_.Name) $($_.Version)" }
}

# ---------------------------------------------------------------- 7
Run-Block '7. Démarrage, tâches et services' {
  $approved = @{}
  foreach ($p in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run','HKLM:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32','HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder') {
    $k = Get-Item $p; if ($k) { $k.GetValueNames() | ForEach-Object { $b = $k.GetValue($_); $approved[$_ -replace '\.lnk$',''] = ($b[0] -in 2,6) } }
  }
  Get-CimInstance Win32_StartupCommand | Sort-Object Name -Unique | ForEach-Object {
    $n = $_.Name -replace '\.lnk$',''
    $state = if ($approved.ContainsKey($n)) { if ($approved[$n]) {'activé'} else {'désactivé'} } else { 'activé' }
    Info "Démarrage : $n [$state] - $($_.Command)"
  }
  # Même programme lancé plusieurs fois au démarrage (ex. clé Run + raccourci du dossier Démarrage)
  $sf = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
  $entries = Get-CimInstance Win32_StartupCommand | ForEach-Object {
    $cmd = $_.Command
    if ($cmd -match '\.lnk$') { $lnk = $sf | ForEach-Object { Join-Path $_ $cmd } | Where-Object { Test-Path $_ } | Select-Object -First 1; if ($lnk) { $cmd = (New-Object -ComObject WScript.Shell).CreateShortcut($lnk).TargetPath } }
    $exe = if ($cmd -match '^"([^"]+)"') { $Matches[1] } else { ($cmd -split '\s')[0] }
    if ($exe -and $exe -notmatch 'Update\.exe$') { [pscustomobject]@{ Name = $_.Name; Exe = $exe; Leaf = (Split-Path $exe -Leaf) } }
  }
  $entries | Group-Object Leaf | Where-Object Count -gt 1 | ForEach-Object { Flag "« $($_.Name) » est lancé $($_.Count) fois au démarrage : $(($_.Group | ForEach-Object { "$($_.Name) -> $($_.Exe)" }) -join ' ; ')" }
  foreach ($f in $sf) {
    Get-ChildItem $f -Filter *.lnk | ForEach-Object {
      $t = (New-Object -ComObject WScript.Shell).CreateShortcut($_.FullName).TargetPath
      if ($t -and -not (Test-Path $t)) { Flag "Raccourci de démarrage mort : $($_.FullName) -> $t (cible absente)" }
    }
  }
  Get-ScheduledTask | Where-Object { $_.State -ne 'Disabled' -and $_.TaskPath -notlike '\Microsoft\*' } | ForEach-Object {
    $t = $_
    foreach ($a in $t.Actions) {
      $exe = [Environment]::ExpandEnvironmentVariables("$($a.Execute)".Trim('"'))
      if (-not $exe) { continue }
      $exists = (Test-Path $exe) -or (Get-Command $exe -ErrorAction SilentlyContinue)
      $line = "Tâche planifiée $($t.TaskPath)$($t.TaskName) -> $exe $($a.Arguments)"
      $fromResidue = $script:residueVendors | Where-Object { $exe -match [regex]::Escape($_) }
      if (-not $exists) { Flag "$line (exécutable absent : résidu)" }
      elseif ($fromResidue) { Flag "$line (appartient à un logiciel désinstallé : $($fromResidue -join ', '))" }
      else { Info $line }
    }
  }
  Get-CimInstance Win32_Service | Where-Object { $_.StartMode -eq 'Auto' -and $_.PathName -notmatch '\\Windows\\(System32|SysWOW64|servicing)|svchost' } |
    ForEach-Object { Info "Service tiers auto : $($_.DisplayName) ($($_.Name)) - $($_.State)" }
  Section '7b. Processus les plus gourmands (RAM)'
  Get-Process | Group-Object ProcessName | ForEach-Object { [pscustomobject]@{ N=$_.Name; C=$_.Count; MB=[math]::Round(($_.Group | Measure-Object WorkingSet64 -Sum).Sum/1MB) } } |
    Sort-Object MB -Descending | Select-Object -First 15 | ForEach-Object { "    - $($_.N) x$($_.C) : $($_.MB) Mo" }
}

# ---------------------------------------------------------------- 8
Run-Block '8. Disques et fichiers inutiles' {
  Get-PhysicalDisk | ForEach-Object {
    $rc = $_ | Get-StorageReliabilityCounter
    $wear = if ($null -ne $rc.Wear) { "$($rc.Wear)%" } else { 'n/d (ADMIN REQUIS)' }
    $temp = if ($rc.Temperature) { "$($rc.Temperature)°C" } else { 'n/d' }
    $line = "Disque : $($_.FriendlyName) $($_.MediaType) $($_.BusType) $([math]::Round($_.Size/1GB)) Go - santé $($_.HealthStatus) - usure $wear - temp $temp - FW $($_.FirmwareVersion)"
    if ($_.HealthStatus -ne 'Healthy' -or $rc.Wear -gt 80) { Flag $line } else { Ok $line }
  }
  Get-Volume | Where-Object DriveLetter | ForEach-Object {
    $pct = if ($_.Size) { [math]::Round(100 * $_.SizeRemaining / $_.Size) } else { 0 }
    $line = "Volume $($_.DriveLetter): $([math]::Round($_.SizeRemaining/1GB,1)) / $([math]::Round($_.Size/1GB,1)) Go libres ($pct %)"
    if ($_.DriveType -eq 'Fixed' -and $pct -lt 15) { Flag "$line -> espace faible" } else { Info $line }
  }
  $trim = (fsutil behavior query DisableDeleteNotify) -join ' '
  if ($trim -match 'NTFS DisableDeleteNotify = 0') { Ok 'TRIM SSD actif' } else { Flag "TRIM : $trim" }
  $dfrag = Get-ScheduledTask -TaskPath '\Microsoft\Windows\Defrag\' -TaskName ScheduledDefrag
  if ($dfrag.State -eq 'Disabled') { Flag "Optimisation automatique des lecteurs désactivée (TRIM SSD / défragmentation HDD)" } elseif ($dfrag) { Ok 'Optimisation automatique des lecteurs planifiée' }
  try {
    $rbSize = 0; $rbCount = 0
    foreach ($it in (New-Object -ComObject Shell.Application).Namespace(10).Items()) { $rbSize += $it.Size; $rbCount++ }
    $line = "Corbeille : $rbCount élément(s), $([math]::Round($rbSize/1GB,2)) Go"
    if ($rbSize -gt 1GB) { Flag "$line -> à vider (après vérification)" } else { Info $line }
  } catch {}
  if (-not $Quick) {
    $targets = [ordered]@{
      'Temp utilisateur (nettoyable)'            = $env:TEMP
      'Temp Windows (admin)'                     = "$env:windir\Temp"
      'Windows Update Download (nettoyage disque)' = "$env:windir\SoftwareDistribution\Download"
      'Windows.old (nettoyage disque)'           = "$env:SystemDrive\Windows.old"
      'CrashDumps utilisateur (nettoyable)'      = "$env:LOCALAPPDATA\CrashDumps"
      'Minidumps (admin)'                        = "$env:windir\Minidump"
      'Rapports WER'                             = "$env:ProgramData\Microsoft\Windows\WER"
      'Cache shaders DirectX (à garder)'         = "$env:LOCALAPPDATA\D3DSCache"
      'Cache shaders NVIDIA (à garder)'          = "$env:LOCALAPPDATA\NVIDIA\DXCache"
      'Cache shaders AMD (à garder)'             = "$env:LOCALAPPDATA\AMD\DxCache"
      'Téléchargements NVIDIA (nettoyable)'      = "$env:ProgramData\NVIDIA Corporation\Downloader"
      'Cache Edge'                               = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
      'Cache Chrome'                             = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
      'Cache Discord'                            = "$env:APPDATA\discord\Cache"
      'Cache Spotify (réglable dans Spotify)'    = "$env:LOCALAPPDATA\Spotify\Data"
      'Cache pip'                                = "$env:LOCALAPPDATA\pip\cache"
      'Cache npm'                                = "$env:LOCALAPPDATA\npm-cache"
      'Logs Fortnite (nettoyable)'               = "$env:LOCALAPPDATA\FortniteGame\Saved\Logs"
      'Téléchargements'                          = "$env:USERPROFILE\Downloads"
    }
    foreach ($k in $targets.Keys) { $g = Get-DirSizeGB $targets[$k]; if ($null -ne $g -and $g -gt 0.05) { "    - {0,7} Go  {1}  [{2}]" -f $g, $k, $targets[$k] } }
    Get-ChildItem "$env:USERPROFILE\Downloads" -File -Recurse | Where-Object Length -gt 500MB | ForEach-Object { Info "Gros fichier dans Téléchargements : $($_.Name) ($([math]::Round($_.Length/1GB,2)) Go, $($_.LastWriteTime.ToString('yyyy-MM-dd')))" }
    # Gros fichiers en double dans les dossiers perso (ignore les fichiers cloud non téléchargés pour ne pas les rapatrier)
    $userDirs = 'Desktop','Documents','Downloads','Pictures','Videos','Music' | ForEach-Object { Join-Path $env:USERPROFILE $_ } | Where-Object { Test-Path $_ }
    # Les dossiers de build/dépendances de projets contiennent des copies voulues : on les ignore
    $big = Get-ChildItem $userDirs -Recurse -File -Force | Where-Object { $_.Length -gt 20MB -and (([int]$_.Attributes -band 0x441000) -eq 0) -and $_.FullName -notmatch '\\(node_modules|\.git|dist|build|out|\.venv|venv|__pycache__|\.next|target|bin|obj)\\' }
    $dups = $big | Group-Object Length | Where-Object Count -gt 1 | ForEach-Object { $_.Group | Get-FileHash -Algorithm MD5 } | Group-Object Hash | Where-Object Count -gt 1
    if ($dups) {
      foreach ($d in $dups) { $sz = (Get-Item -LiteralPath $d.Group[0].Path).Length; Flag "Fichiers identiques ($([math]::Round($sz/1MB)) Mo chacun, $($d.Count) copies) : $(($d.Group.Path) -join ' ; ')" }
    } else { Ok 'Aucun gros fichier en double (> 20 Mo) dans les dossiers perso' }
    Section '8b. Plus gros dossiers AppData\Local'
    Get-ChildItem $env:LOCALAPPDATA -Directory -Force | ForEach-Object { [pscustomobject]@{ G = Get-DirSizeGB $_.FullName; N = $_.Name } } |
      Sort-Object G -Descending | Select-Object -First 10 | ForEach-Object { "    - {0,7} Go  {1}" -f $_.G, $_.N }
  } else { Info 'Mode -Quick : tailles de dossiers non mesurées' }
  $pf = Get-CimInstance Win32_PageFileUsage
  if ($pf) { $pf | ForEach-Object { Info "Fichier d'échange : $($_.Name) $($_.AllocatedBaseSize) Mo (pic $($_.PeakUsage) Mo) - auto: $((Get-CimInstance Win32_ComputerSystem).AutomaticManagedPagefile)" } }
  else { Flag "Aucun fichier d'échange : risque de plantages en cas de RAM pleine" }
}

# ---------------------------------------------------------------- 9
Run-Block '9. Réglages performance et jeu' {
  $raw = (powercfg /getactivescheme) -join ' '
  $plan = if ($raw -match '\(([^)]+)\)\s*$') { $Matches[1] } else { $raw }
  if ($plan -match 'Haute|High|Ultimate|optimales|Ultimes') { Ok "Plan d'alimentation : $plan" } else { Flag "Plan d'alimentation : $plan -> Haute performance recommandé sur un PC fixe" }
  $gm = Get-RegVal 'HKCU:\Software\Microsoft\GameBar' AutoGameModeEnabled
  if ($gm -eq 0) { Flag 'Mode Jeu désactivé' } else { Ok "Mode Jeu activé ($gm)" }
  $cap = Get-RegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' AppCaptureEnabled
  $dvr = Get-RegVal 'HKCU:\System\GameConfigStore' GameDVR_Enabled
  if ($cap -eq 1 -or $dvr -eq 1) { Flag "Capture en arrière-plan Game DVR active (AppCapture=$cap, GameDVR=$dvr)" } else { Ok 'Capture en arrière-plan désactivée' }
  $ms = Get-RegVal 'HKCU:\Control Panel\Mouse' MouseSpeed
  if ("$ms" -ne '0') { Flag "Accélération souris (précision du pointeur) active (MouseSpeed=$ms)" } else { Ok 'Accélération souris désactivée' }
  $hags = Get-RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' HwSchMode
  Info "Planification GPU accélérée (HAGS) : $(switch("$hags"){'2'{'activée'}'1'{'désactivée'}default{'défaut Windows'}})"
  $vrr = Get-RegVal 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences' DirectXUserGlobalSettings
  Info "Préférences DirectX globales (optimisations jeux fenêtrés / VRR) : $vrr"
  $tr = Get-RegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' EnableTransparency
  Info "Effets de transparence : $tr"
  $vfx = Get-RegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' VisualFXSetting
  Info "Effets visuels (0=auto,1=apparence,2=performances,3=perso) : $vfx"
  $fs = Get-RegVal 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' HiberbootEnabled
  Info "Démarrage rapide : $(if($fs -eq 1){'activé (à désactiver si bugs après veille/dual boot)'}else{$fs})"
  $ss = Get-RegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01'
  if ($ss -eq 1) { Ok 'Assistant de stockage activé' } else { Flag "Assistant de stockage désactivé ($ss)" }
  Info "Indexation : $((Get-Service WSearch).Status) | SysMain : $((Get-Service SysMain).Status)"
}

# ---------------------------------------------------------------- 10
Run-Block '10. Sécurité et sauvegarde' {
  $mp = Get-MpComputerStatus
  if ($mp) {
    $line = "Defender : temps réel $($mp.RealTimeProtectionEnabled), signatures du $($mp.AntivirusSignatureLastUpdated), dernière analyse rapide $($mp.QuickScanEndTime)"
    if (-not $mp.RealTimeProtectionEnabled) { Flag $line }
    elseif ($mp.QuickScanEndTime -and ((Get-Date) - $mp.QuickScanEndTime).TotalDays -gt 14) { Flag "$line -> aucune analyse depuis plus de 14 jours" }
    else { Ok $line }
  } else { Info 'Defender : statut indisponible (autre antivirus ?)' }
  $av = Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct
  if (($av | Measure-Object).Count -gt 1) { Flag "Plusieurs antivirus enregistrés : $(($av.displayName) -join ', ')" } else { Info "Antivirus : $(($av.displayName) -join ', ')" }
  $dg = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard Win32_DeviceGuard
  if ($dg) { Info "VBS : statut $($dg.VirtualizationBasedSecurityStatus) (2=actif) - services $($dg.SecurityServicesRunning -join ',') (2=HVCI)" }
  if ($isAdmin) { Info "Secure Boot : $(Confirm-SecureBootUEFI)"; Info "TPM prêt : $((Get-Tpm).TpmReady)" } else { Info 'Secure Boot / TPM : ADMIN REQUIS' }
  # Points de restauration : la liste exige les droits admin. Sans admin, ne JAMAIS conclure "0" : on lit le journal.
  try {
    $rp = Get-ComputerRestorePoint -ErrorAction Stop
    if ($rp) { Ok "Points de restauration : $(@($rp).Count), dernier « $(@($rp)[-1].Description) »" } else { Flag 'Aucun point de restauration' }
  } catch {
    $ev = Get-WinEvent -FilterHashtable @{ LogName='Application'; StartTime=(Get-Date).AddDays(-60) } -ErrorAction SilentlyContinue |
      Where-Object { $_.ProviderName -eq 'System Restore' -or $_.ProviderName -eq 'Microsoft-Windows-SystemRestore' } | Where-Object Id -eq 8194
    if ($ev) { Ok "Points de restauration : $(@($ev).Count) créé(s) en 60 j d'après le journal, dernier le $(@($ev)[0].TimeCreated) (liste exacte : ADMIN REQUIS)" }
    else { Flag "Aucun point de restauration créé en 60 j d'après le journal (protection système peut-être désactivée ; liste exacte : ADMIN REQUIS)" }
  }
}

# ---------------------------------------------------------------- 11
Run-Block '11. Stabilité (30 derniers jours)' {
  $since = (Get-Date).AddDays(-30)
  $sys = Get-WinEvent -FilterHashtable @{ LogName='System'; StartTime=$since } -ErrorAction SilentlyContinue
  $kp = @($sys | Where-Object { $_.ProviderName -eq 'Microsoft-Windows-Kernel-Power' -and $_.Id -eq 41 })
  $whea = @($sys | Where-Object { $_.ProviderName -match 'WHEA' })
  $bc = @($sys | Where-Object { $_.Id -eq 1001 -and $_.ProviderName -match 'BugCheck|WER-SystemErrorReporting' })
  if ($kp.Count) { Flag "$($kp.Count) arrêt(s) brutal(aux) Kernel-Power 41 (coupure, plantage, instabilité RAM/CPU)" } else { Ok 'Aucun arrêt brutal' }
  if ($whea.Count) { Flag "$($whea.Count) erreur(s) matérielle(s) WHEA (souvent RAM/XMP ou overclock instable)" } else { Ok 'Aucune erreur matérielle WHEA' }
  if ($bc.Count) { Flag "$($bc.Count) écran(s) bleu(s)" } else { Ok 'Aucun écran bleu' }
  # Dernier test mémoire Windows (mdsched) : 1101/1201 = OK, 1102/1202 = erreurs, 1103 = annulé
  $mt = Get-WinEvent -FilterHashtable @{ LogName='System'; ProviderName='Microsoft-Windows-MemoryDiagnostics-Results' } -MaxEvents 1 -ErrorAction SilentlyContinue
  if ($mt) {
    $when = $mt.TimeCreated.ToString('yyyy-MM-dd HH:mm')
    switch ($mt.Id) {
      { $_ -in 1101,1201 } { Ok "Test mémoire Windows du $when : aucune erreur" }
      { $_ -in 1102,1202 } { Flag "Test mémoire Windows du $when : ERREURS détectées -> baisser la fréquence RAM / désactiver XMP, tester barrette par barrette" }
      1103 { Flag "Test mémoire Windows du $when : annulé avant la fin, résultat inconnu -> le relancer sans toucher au clavier" }
      default { Info "Test mémoire Windows du $when : événement $($mt.Id)" }
    }
  } else { Info 'Aucun test mémoire Windows (mdsched) enregistré' }
  $md = Get-ChildItem "$env:windir\Minidump" -ErrorAction SilentlyContinue
  if ($md) { Flag "Minidumps présents : $(($md.Name) -join ', ')" }
  $sys | Where-Object { $_.Level -in 1,2 } | Group-Object ProviderName, Id | Sort-Object Count -Descending | Select-Object -First 10 |
    ForEach-Object { "    - $($_.Count)x $($_.Name) : $((($_.Group[0].Message) -split "`n")[0].Trim())" }
  $crash = Get-WinEvent -FilterHashtable @{ LogName='Application'; Id=1000; StartTime=$since } -ErrorAction SilentlyContinue | ForEach-Object { $_.Properties[0].Value } | Group-Object | Sort-Object Count -Descending
  if ($crash) { $crash | Select-Object -First 8 | ForEach-Object { Flag "Plantage d'application : $($_.Name) x$($_.Count)" } } else { Ok "Aucun plantage d'application" }
}

# ---------------------------------------------------------------- 12
Run-Block '12. Réseau' {
  Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | ForEach-Object {
    $dns = (($_.DNSServer | Where-Object AddressFamily -eq 2).ServerAddresses) -join ', '
    Info "Connexion active : $($_.InterfaceAlias) ($($_.NetAdapter.InterfaceDescription)) - passerelle $($_.IPv4DefaultGateway.NextHop) - DNS $dns"
    if ($_.NetAdapter.InterfaceDescription -match 'Wi-?Fi|Wireless|802\.11|WLAN') {
      Info 'Connexion en Wi-Fi : un câble Ethernet donne une latence plus stable en jeu'
      netsh wlan show interfaces | Select-String 'Signal|Type de radio|Radio type|Bande|Band|Canal|Channel' | ForEach-Object { Info "  Wi-Fi $($_.Line.Trim())" }
    }
  }
  foreach ($h in '1.1.1.1','8.8.8.8') {
    $r = @(Test-Connection $h -Count 4 -ErrorAction SilentlyContinue)
    if ($r.Count) {
      $avg = [math]::Round(($r | Measure-Object ResponseTime -Average).Average); $loss = 4 - $r.Count
      $line = "Ping $h : $avg ms en moyenne, $loss/4 perdu(s)"
      if ($avg -gt 60 -or $loss) { Flag "$line -> latence élevée ou pertes (Wi-Fi, box, câble ?)" } else { Ok $line }
    } else { Flag "Ping $h : aucune réponse (pare-feu ou connexion coupée)" }
  }
}

# ---------------------------------------------------------------- 13
Run-Block '13. Windows désencombré (pubs, suggestions, applis préinstallées)' {
  $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
  $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
  $checks = @(
    @('Installation automatique d''applis sponsorisées', $cdm, 'SilentInstalledAppsEnabled'),
    @('Suggestions dans le menu Démarrer', $cdm, 'SystemPaneSuggestionsEnabled'),
    @('Astuces et suggestions de Windows', $cdm, 'SubscribedContent-338389Enabled'),
    @('Contenu suggéré dans Paramètres', $cdm, 'SubscribedContent-338393Enabled'),
    @('Écran « bienvenue » après les mises à jour', $cdm, 'SubscribedContent-310093Enabled'),
    @('Recommandations du menu Démarrer', $adv, 'Start_IrisRecommendations'),
    @('Pubs OneDrive / Microsoft 365 dans l''Explorateur', $adv, 'ShowSyncProviderNotifications'),
    @('Rappels « Terminer la configuration de l''appareil »', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement', 'ScoobeSystemSettingEnabled'),
    @('ID publicitaire', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo', 'Enabled'),
    @('Expériences personnalisées (données de diagnostic)', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy', 'TailoredExperiencesWithDiagnosticDataEnabled')
  )
  foreach ($c in $checks) {
    $v = Get-RegVal $c[1] $c[2]
    if ("$v" -eq '0') { Ok "$($c[0]) : désactivé" } elseif ($v -eq '(défaut)') { Flag "$($c[0]) : actif (réglage par défaut)" } else { Flag "$($c[0]) : actif (valeur $v)" }
  }
  $bing = Get-RegVal 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' DisableSearchBoxSuggestions
  $bingUser = Get-RegVal 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' BingSearchEnabled
  if ("$bing" -eq '1') { Ok 'Résultats web Bing dans la recherche du menu Démarrer : désactivés (stratégie)' }
  elseif ("$bingUser" -eq '0') { Ok 'Résultats web Bing : désactivés côté utilisateur (si des résultats web persistent, appliquer la stratégie admin, voir fixes.md)' }
  else { Flag 'Résultats web Bing dans la recherche du menu Démarrer : actifs (recherche plus lente)' }
  $bloat = 'Microsoft.GetHelp','Microsoft.Getstarted','Microsoft.Windows.DevHome','Clipchamp.Clipchamp','Microsoft.BingNews','Microsoft.BingWeather','Microsoft.BingSearch',
           'Microsoft.MicrosoftSolitaireCollection','Microsoft.MicrosoftOfficeHub','Microsoft.People','Microsoft.WindowsFeedbackHub','Microsoft.ZuneVideo',
           'Microsoft.MixedReality.Portal','Microsoft.549981C3F5F10','Microsoft.PowerAutomateDesktop','MicrosoftTeams','MSTeams','Microsoft.SkypeApp',
           'Microsoft.MicrosoftJournal','Microsoft.Todos','Microsoft.WindowsMaps','king.com.*','*Disney*','*TikTok*','*Facebook*','*Instagram*','*AmazonVideo*','*CandyCrush*'
  $found = Get-AppxPackage | Where-Object { $n = $_.Name; $bloat | Where-Object { $n -like $_ } } | Select-Object -ExpandProperty Name -Unique
  if ($found) { Flag "Applis préinstallées souvent inutiles (à confirmer avec l'utilisateur) : $($found -join ', ')" } else { Ok 'Aucune appli préinstallée inutile connue' }
}

# ---------------------------------------------------------------- 14
Run-Block '14. Jeux (emplacement et overlays)' {
  function Get-DriveMedia($path) {
    try { $l = (Split-Path -Qualifier $path).TrimEnd(':'); $dn = (Get-Partition -DriveLetter $l -ErrorAction Stop).DiskNumber; "$((Get-PhysicalDisk | Where-Object DeviceId -eq "$dn").MediaType)" } catch { '?' }
  }
  $games = @()
  $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam').SteamPath
  if ($steam) {
    $vdf = Join-Path ($steam -replace '/','\') 'steamapps\libraryfolders.vdf'
    $libs = Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object { $_.Matches[0].Groups[1].Value -replace '\\\\','\' }
    foreach ($lib in $libs) {
      Get-ChildItem (Join-Path $lib 'steamapps') -Filter 'appmanifest_*.acf' | ForEach-Object {
        $txt = Get-Content $_.FullName -Raw
        $name = if ($txt -match '"name"\s+"([^"]+)"') { $Matches[1] } else { $_.BaseName }
        $size = if ($txt -match '"SizeOnDisk"\s+"(\d+)"') { [int64]$Matches[1] } else { 0 }
        $games += [pscustomobject]@{ Store='Steam'; Name=$name; Path=$lib; Size=$size }
      }
    }
  }
  Get-ChildItem "$env:ProgramData\Epic\EpicGamesLauncher\Data\Manifests" -Filter *.item | ForEach-Object {
    $j = Get-Content $_.FullName -Raw | ConvertFrom-Json
    $games += [pscustomobject]@{ Store='Epic'; Name=$j.DisplayName; Path=$j.InstallLocation; Size=[int64]$j.InstallSize }
  }
  # Epic ne garde pas toujours ses manifestes : on complète avec LauncherInstalled.dat puis les dossiers de jeu (.egstore)
  $epicPaths = @()
  $li = "$env:ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat"
  if (Test-Path $li) { $epicPaths += (Get-Content $li -Raw | ConvertFrom-Json).InstallationList.InstallLocation }
  Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
    $root = "$($_.DriveLetter):\"
    $epicPaths += Get-ChildItem $root, (Join-Path $root 'Program Files\Epic Games'), (Join-Path $root 'Epic Games') -Directory -Force |
      Where-Object { Test-Path (Join-Path $_.FullName '.egstore') } | ForEach-Object FullName
  }
  foreach ($ep in ($epicPaths | Where-Object { $_ } | Select-Object -Unique)) {
    if ($games.Path -notcontains $ep) {
      $sz = if ($Quick) { 0 } else { [int64]((Get-DirSizeGB $ep) * 1GB) }
      $games += [pscustomobject]@{ Store='Epic'; Name=(Split-Path $ep -Leaf); Path=$ep; Size=$sz }
    }
  }
  if ($games) {
    foreach ($g in $games) {
      $media = Get-DriveMedia $g.Path
      $sizeTxt = if ($g.Size -gt 0) { "$([math]::Round($g.Size/1GB,1)) Go" } else { 'taille non mesurée' }
      $line = "$($g.Store) : $($g.Name) ($sizeTxt) sur $($g.Path.Substring(0,2)) [$media]"
      if ($media -eq 'HDD') { Flag "$line -> sur disque dur : chargements lents, à déplacer sur le SSD s'il y a la place" } else { Info $line }
    }
  } else { Info 'Aucune bibliothèque Steam/Epic détectée' }
  $ov = @{ 'NVIDIA Overlay'='NVIDIA'; 'GameBar'='Xbox Game Bar'; 'gameoverlayui'='Steam'; 'gameoverlayui64'='Steam'; 'EOSOverlayRenderer-Win64-Shipping'='Epic'; 'RadeonSoftware'='AMD' }
  $running = $ov.Keys | Where-Object { Get-Process -Name $_ } | ForEach-Object { $ov[$_] } | Select-Object -Unique
  if (@($running).Count -gt 1) { Flag "Plusieurs overlays actifs en même temps : $($running -join ', ') (en garder un seul évite conflits et micro-saccades)" }
  elseif ($running) { Info "Overlay actif : $running" }
}

"`n# Fin du rapport"
