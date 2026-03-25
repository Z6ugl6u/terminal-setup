#Requires -Version 5.1
<#
.SYNOPSIS
    Terminal Setup for Windows - PowerShell, CMD, Windows Terminal
.DESCRIPTION
    Installs and configures:
    - PSReadLine    : historique persistant + predictions ListView
    - Oh My Posh    : prompt Powerline colore
    - McFly         : recherche intelligente dans l'historique
    - navi          : cheatsheets interactives (Ctrl+G)
    - tldr          : pages man simplifiees
    - Clink         : historique persistant pour CMD
    - MesloLGS NF   : police Nerd Font pour les icones
    - Windows Terminal: configuration automatique (police + WSL home)
.NOTES
    - Aucun droit admin requis
    - Compatible : Windows 10 / 11, PowerShell 5.1+
    - Gestionnaire de paquets : winget (fallback scoop)
#>

$ErrorActionPreference = "Continue"

# Force TLS 1.2 pour les telechargements (necessaire sur PS 5.1 / Win 10)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$script:Results = @{ Installed = @(); Configured = @(); Skipped = @(); Failed = @() }

function Write-Step { param([string]$m) Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-OK   { param([string]$m) Write-Host "  [+] $m" -ForegroundColor Green;  $script:Results.Configured += $m }
function Write-SKIP { param([string]$m) Write-Host "  [~] $m" -ForegroundColor Yellow; $script:Results.Skipped   += $m }
function Write-FAIL { param([string]$m) Write-Host "  [!] $m" -ForegroundColor Red;    $script:Results.Failed    += $m }
function Write-INFO { param([string]$m) Write-Host "  [*] $m" -ForegroundColor White }
function Write-INST { param([string]$m) Write-Host "  [+] $m installe" -ForegroundColor Green; $script:Results.Installed += $m }

function Test-CommandExists {
    param([string]$cmd)
    return [bool](Get-Command $cmd -ErrorAction SilentlyContinue)
}

function Test-WingetAvailable {
    if (-not (Test-CommandExists "winget")) { return $false }
    $null = winget --version 2>&1
    return ($LASTEXITCODE -eq 0)
}

function Install-WithWinget {
    param([string]$Id, [string]$Name)
    if (-not (Test-WingetAvailable)) {
        Write-FAIL "winget indisponible - installez App Installer depuis le Microsoft Store"
        return $false
    }
    Write-INFO "Installation de $Name via winget..."
    $result = winget install --id $Id --silent --accept-package-agreements --accept-source-agreements 2>&1
    $output = ($result -join "")
    if ($LASTEXITCODE -eq 0 -or $output -match "already installed|No newer package|Successfully installed|deja installe") {
        Write-INST $Name
        return $true
    }
    Write-FAIL "Echec winget pour $Name"
    return $false
}

function Backup-File {
    param([string]$Path)
    if (Test-Path $Path) {
        Copy-Item $Path "$Path.bak" -Force
        Write-INFO "Backup : $Path.bak"
    }
}

# Detecter le nom de la distro WSL par defaut
function Get-DefaultWslDistro {
    try {
        $distros = wsl --list --quiet 2>&1
        if ($distros) {
            # La premiere ligne non vide est la distro par defaut
            $default = ($distros | Where-Object { $_ -match '\S' } | Select-Object -First 1)
            # Nettoyer les caracteres nuls (wsl --list retourne du UTF-16)
            return ($default -replace '\x00', '').Trim()
        }
    } catch { }
    return "Ubuntu"
}

# =============================================================================
Write-Host "`n  Terminal Setup for Windows" -ForegroundColor Magenta
Write-Host "  Compatible : Windows 10/11 - PowerShell 5.1+`n" -ForegroundColor White

# =============================================================================
Write-Step "1. PSReadLine - Historique persistant + predictions ListView"

$psrl = Get-Module -ListAvailable PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
if ($psrl -and $psrl.Version -ge [version]"2.2.0") {
    Write-SKIP "PSReadLine $($psrl.Version) deja present"
} else {
    try {
        Install-Module PSReadLine -Scope CurrentUser -Force -SkipPublisherCheck -MinimumVersion 2.2.0
        Write-INST "PSReadLine"
    } catch {
        Write-FAIL "PSReadLine : $_"
    }
}

$histDir = "$env:USERPROFILE\.powershell_history"
if (-not (Test-Path $histDir)) { New-Item -ItemType Directory -Path $histDir -Force | Out-Null }

$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
Backup-File $PROFILE

$profileContent = @"
# ── PSReadLine - Historique persistant + predictions ──────────────────────────
Import-Module PSReadLine -ErrorAction SilentlyContinue

Set-PSReadLineOption -MaximumHistoryCount 10000
Set-PSReadLineOption -HistorySavePath "`$env:USERPROFILE\.powershell_history\history.txt"
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -BellStyle None

Set-PSReadLineKeyHandler -Key Ctrl+r   -Function ReverseSearchHistory
Set-PSReadLineKeyHandler -Key UpArrow  -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# ── McFly - Recherche intelligente ───────────────────────────────────────────
if (Get-Command mcfly -ErrorAction SilentlyContinue) {
    `$env:MCFLY_FUZZY = 2
    `$env:MCFLY_RESULTS = 50
    `$env:MCFLY_INTERFACE_VIEW = "BOTTOM"
    Invoke-Expression -Command `$(mcfly init powershell | Out-String)
}

# ── navi - Cheatsheets interactives (Ctrl+G) ──────────────────────────────────
if (Get-Command navi -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Key Ctrl+g -ScriptBlock {
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        navi
    }
}

# ── Oh My Posh - Prompt Powerline ─────────────────────────────────────────────
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    `$themePath = "`$env:POSH_THEMES_PATH\paradox.omp.json"
    if (Test-Path `$themePath) {
        oh-my-posh init pwsh --config `$themePath | Invoke-Expression
    } else {
        oh-my-posh init pwsh | Invoke-Expression
    }
}

# ── Fonctions utiles ──────────────────────────────────────────────────────────
function which(`$cmd) { (Get-Command `$cmd -ErrorAction SilentlyContinue).Source }
function mkcd(`$path) { New-Item -ItemType Directory -Path `$path -Force | Out-Null; Set-Location `$path }
function ll { Get-ChildItem -Force `$args }
"@

Set-Content -Path $PROFILE -Value $profileContent -Encoding UTF8
Write-OK "PowerShell PROFILE : $PROFILE"

# =============================================================================
Write-Step "2. Oh My Posh - Prompt Powerline"

if (Test-CommandExists "oh-my-posh") {
    Write-SKIP "Oh My Posh deja installe"
} else {
    Install-WithWinget "JanDeDobbeleer.OhMyPosh" "Oh My Posh" | Out-Null
}

# =============================================================================
Write-Step "3. Police MesloLGS NF (Nerd Font)"

$fontsDir  = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$fontFiles = @(
    "MesloLGS NF Regular.ttf",
    "MesloLGS NF Bold.ttf",
    "MesloLGS NF Italic.ttf",
    "MesloLGS NF Bold Italic.ttf"
)

# Verifier si deja installee
Add-Type -AssemblyName System.Drawing
$alreadyInstalled = [System.Drawing.FontFamily]::Families | Where-Object { $_.Name -eq "MesloLGS NF" }

if ($alreadyInstalled) {
    Write-SKIP "MesloLGS NF deja installee"
} else {
    $tmpDir  = "$env:TEMP\MesloLGS_NF"
    $regPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    New-Item -ItemType Directory -Force -Path $tmpDir  | Out-Null
    New-Item -ItemType Directory -Force -Path $fontsDir | Out-Null

    $allOk = $true
    foreach ($f in $fontFiles) {
        $url = "https://github.com/romkatv/powerlevel10k-media/raw/master/" + ($f -replace ' ', '%20')
        $out = "$tmpDir\$f"
        Write-INFO "Telechargement : $f"
        try {
            Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 30
            Copy-Item $out "$fontsDir\$f" -Force
            $regName = [IO.Path]::GetFileNameWithoutExtension($f) + " (TrueType)"
            Set-ItemProperty -Path $regPath -Name $regName -Value "$fontsDir\$f" -Force
        } catch {
            Write-FAIL "Echec : $f - $_"
            $allOk = $false
        }
    }
    if ($allOk) { Write-INST "MesloLGS NF" } else { Write-FAIL "MesloLGS NF (partiel - relancez)" }
}

# =============================================================================
Write-Step "4. Windows Terminal - Configuration automatique"

$wtPath = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal*\LocalState\settings.json" `
    -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName

if (-not $wtPath) {
    Write-SKIP "Windows Terminal non trouve"
} else {
    try {
        $wt = Get-Content $wtPath -Raw -Encoding UTF8 | ConvertFrom-Json

        # Detecter le profil WSL (Ubuntu, Debian, Kali, ou tout profil WSL)
        $wslProfile = $wt.profiles.list | Where-Object {
            $_.source -match "WSL" -or $_.name -match "Ubuntu|Debian|Kali|WSL"
        } | Select-Object -First 1

        if ($wslProfile) {
            # Detecter la distro par defaut pour le startingDirectory
            $distroName = Get-DefaultWslDistro
            $linuxHome  = "//wsl$/$distroName/home/$env:USERNAME"

            # Police
            if (-not $wslProfile.PSObject.Properties["font"]) {
                $wslProfile | Add-Member -NotePropertyName font `
                    -NotePropertyValue ([PSCustomObject]@{ face = "MesloLGS NF"; size = 11 }) -Force
            } else {
                $wslProfile.font.face = "MesloLGS NF"
                if (-not $wslProfile.font.PSObject.Properties["size"]) {
                    $wslProfile.font | Add-Member -NotePropertyName size -NotePropertyValue 11 -Force
                } else {
                    $wslProfile.font.size = 11
                }
            }

            # Dossier de depart = home Linux
            if (-not $wslProfile.PSObject.Properties["startingDirectory"]) {
                $wslProfile | Add-Member -NotePropertyName startingDirectory -NotePropertyValue $linuxHome -Force
            } else {
                $wslProfile.startingDirectory = $linuxHome
            }

            Backup-File $wtPath
            $wt | ConvertTo-Json -Depth 20 | Set-Content $wtPath -Encoding UTF8
            Write-OK "Windows Terminal : police MesloLGS NF + home Linux ($distroName)"
        } else {
            Write-SKIP "Aucun profil WSL trouve dans Windows Terminal"
        }
    } catch {
        Write-FAIL "Windows Terminal : $_"
    }
}

# =============================================================================
Write-Step "5. McFly - Recherche intelligente dans l'historique"

if (Test-CommandExists "mcfly") {
    Write-SKIP "McFly deja installe"
} else {
    $ok = Install-WithWinget "cantino.mcfly" "McFly"
    if (-not $ok -and (Test-CommandExists "scoop")) {
        scoop install mcfly 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-INST "McFly (scoop)" } else { Write-FAIL "McFly" }
    }
}

# =============================================================================
Write-Step "6. navi - Cheatsheets interactives (Ctrl+G)"

if (Test-CommandExists "navi") {
    Write-SKIP "navi deja installe"
} else {
    $ok = Install-WithWinget "denisidoro.navi" "navi"
    if (-not $ok -and (Test-CommandExists "scoop")) {
        scoop install navi 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-INST "navi (scoop)" } else { Write-FAIL "navi" }
    }
}

$naviCheatsDir = "$env:USERPROFILE\.config\navi\cheats"
if (-not (Test-Path $naviCheatsDir)) { New-Item -ItemType Directory -Path $naviCheatsDir -Force | Out-Null }
$naviCheatFile = "$naviCheatsDir\custom.cheat"
Backup-File $naviCheatFile

@'
% reseau, windows

# Toutes les interfaces reseau
ipconfig /all

# Connexions actives avec PID
netstat -ano

# Ports en ecoute
netstat -an | findstr LISTENING

# Tester la connectivite
ping -n 4 <host>

# Traceroute
tracert <host>

# Resoudre un nom DNS
nslookup <host>

# Vider le cache DNS
ipconfig /flushdns

# Cache ARP
arp -a

% reseau, nmap

# Scan rapide
nmap -T4 -F <target>

# Scan SYN tous les ports
nmap -sS -p- <target>

# Detection version + OS
nmap -sV -O <target>

# Scripts NSE + versions
nmap -sC -sV <target>

# Ping sweep
nmap -sn <cidr>

# Export tous les formats
nmap -sC -sV -oA <output_file> <target>

% pentest, windows

# Utilisateurs locaux
net user

# Groupes locaux
net localgroup administrators

# Processus + PID
tasklist /v

# Services
sc query

# Privileges
whoami /all

# Informations systeme
systeminfo

# Fichiers potentiellement sensibles
dir /s /b *password* *secret* *credential* 2>nul

% git

# Cloner un depot
git clone <url>

# Log compact en graphe
git log --oneline --graph --all

# Annuler le dernier commit (garder les fichiers)
git reset --soft HEAD~1

# Chercher une chaine dans l historique
git log -S "<string>" --all

% docker

# Shell interactif dans un conteneur
docker run -it --rm <image> /bin/bash

# Conteneur en arriere-plan avec port
docker run -d -p <host_port>:<container_port> <image>

# Nettoyage complet
docker system prune -af
'@ | Set-Content -Path $naviCheatFile -Encoding UTF8
Write-OK "Cheatsheets navi : $naviCheatFile"

# =============================================================================
Write-Step "7. tldr - Pages man simplifiees"

if (Test-CommandExists "tldr") {
    Write-SKIP "tldr deja installe"
} else {
    $ok = Install-WithWinget "dbrgn.tealdeer" "tldr (tealdeer)"
    if (-not $ok) { Install-WithWinget "isacikgoz.tldr" "tldr" | Out-Null }
}

# =============================================================================
Write-Step "8. Clink - Historique persistant pour CMD"

if (Test-CommandExists "clink") {
    Write-SKIP "Clink deja installe"
} else {
    Install-WithWinget "chrisant996.Clink" "Clink" | Out-Null
}

$clinkDir = "$env:LOCALAPPDATA\clink"
if (-not (Test-Path $clinkDir)) { New-Item -ItemType Directory -Path $clinkDir -Force | Out-Null }

$clinkSettings = "$clinkDir\clink_settings"
if (-not (Test-Path $clinkSettings)) {
@'
history.save                = true
history.max_lines           = 10000
history.shared              = true
history.time_stamp          = both
match.ignore_case           = relaxed
'@ | Set-Content -Path $clinkSettings -Encoding UTF8
    Write-OK "Clink configure"
} else {
    Write-SKIP "Clink settings deja present"
}

# Auto-injection Clink dans CMD
$clinkCmd = Get-Command clink -ErrorAction SilentlyContinue
$clinkExe = if ($clinkCmd) { $clinkCmd.Source } else { $null }

if (-not $clinkExe) {
    $candidates = @(
        "$env:ProgramFiles\clink\clink.exe",
        "$env:ProgramFiles (x86)\clink\clink.exe",
        "$env:LOCALAPPDATA\Programs\clink\clink.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $clinkExe = $c; break } }
    if (-not $clinkExe) {
        $found = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Filter "clink.exe" `
            -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) { $clinkExe = $found.FullName }
    }
}

if ($clinkExe) {
    $regPath  = "HKCU:\Software\Microsoft\Command Processor"
    $existing = (Get-ItemProperty $regPath -Name AutoRun -ErrorAction SilentlyContinue).AutoRun
    $inject   = "`"$clinkExe`" inject --quiet"
    if ($existing -notmatch "clink") {
        $newVal = if ($existing) { "$existing & $inject" } else { $inject }
        Set-ItemProperty $regPath AutoRun $newVal
        Write-OK "Clink auto-injection CMD"
    } else {
        Write-SKIP "Clink deja dans CMD AutoRun"
    }
} else {
    Write-FAIL "Clink exe introuvable - auto-injection CMD skippee"
}

# =============================================================================
Write-Step "Rafraichissement du PATH"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path","User")
Write-OK "PATH recharge"

# =============================================================================
Write-Host "`n============================================================" -ForegroundColor Magenta
Write-Host "  RESUME FINAL" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

if ($script:Results.Installed.Count  -gt 0) { Write-Host "`n  INSTALLE :"    -ForegroundColor Green;  $script:Results.Installed  | ForEach-Object { Write-Host "    + $_" -ForegroundColor Green  } }
if ($script:Results.Configured.Count -gt 0) { Write-Host "`n  CONFIGURE :"   -ForegroundColor Cyan;   $script:Results.Configured | ForEach-Object { Write-Host "    ~ $_" -ForegroundColor Cyan   } }
if ($script:Results.Skipped.Count    -gt 0) { Write-Host "`n  DEJA PRESENT :" -ForegroundColor Yellow; $script:Results.Skipped    | ForEach-Object { Write-Host "    = $_" -ForegroundColor Yellow } }
if ($script:Results.Failed.Count     -gt 0) { Write-Host "`n  ECHECS :"      -ForegroundColor Red;    $script:Results.Failed     | ForEach-Object { Write-Host "    ! $_" -ForegroundColor Red    } }

Write-Host @"

  Actions post-installation :
  1. Redemarrez Windows Terminal
  2. Si les icones ne s'affichent pas : oh-my-posh font install
  3. Raccourcis : Ctrl+R (historique), Ctrl+G (navi cheatsheets)
  4. CMD : rouvrez cmd.exe pour tester Clink

"@ -ForegroundColor White
