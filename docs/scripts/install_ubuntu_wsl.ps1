<#
    install_ubuntu_wsl.ps1 - Step 1 of https://aikaryashala.com/system_setup

    Installs Ubuntu 24.04 LTS on Windows using WSL 2 (Windows Subsystem for
    Linux).

    The version is pinned on purpose. "wsl --install -d Ubuntu" installs
    whichever release Microsoft currently considers default, which changes over
    time - so two people running this months apart would not get the same
    system. Every other step on this site is written against 24.04 LTS, so that
    is what this installs.

    If ANY Ubuntu is already installed - 22.04, for example - this script leaves
    it alone and installs nothing. The later steps work on any recent Ubuntu, and
    a second download is not worth the confusion of having two.

    Run in Windows PowerShell AS ADMINISTRATOR:

        irm https://aikaryashala.com/system_setup/scripts/install_ubuntu_wsl.ps1 | iex

    Safe to run more than once. Anything already in place is left alone.

    Optional environment variables:
        $env:WSL_DISTRO = "Ubuntu-22.04"   # default: Ubuntu-24.04
#>

$ErrorActionPreference = 'Stop'

# Makes wsl.exe emit normal UTF-8 instead of UTF-16, which PowerShell would
# otherwise render as text riddled with null characters.
$env:WSL_UTF8 = '1'

function Write-Step { param([string]$Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok   { param([string]$Message) Write-Host "  ok $Message" -ForegroundColor Green }
function Write-Skip { param([string]$Message) Write-Host " skip $Message" -ForegroundColor DarkGray }
function Write-Warn { param([string]$Message) Write-Host "warn $Message" -ForegroundColor Yellow }
function Write-Fail { param([string]$Message) Write-Host "fail $Message" -ForegroundColor Red }

function Write-Banner {
    param([string]$Message)
    Write-Host ''
    Write-Host $Message -ForegroundColor White
    Write-Host ('-' * 60) -ForegroundColor DarkGray
}

function Test-Administrator {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-WindowsBuild {
    return [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber
}

function Test-WslCommand {
    return $null -ne (Get-Command wsl.exe -ErrorAction SilentlyContinue)
}

# True when this WSL understands `--no-launch` on `wsl --install`.
#
# That option arrived with the Microsoft Store build of WSL, which is also the
# first build to answer `wsl --version`. The inbox WSL that ships inside Windows
# has neither, and rejects the whole command line if it is passed.
function Test-WslNoLaunchSupport {
    if (-not (Test-WslCommand)) { return $false }
    & wsl.exe --version 2>&1 | Out-Null
    return ($LASTEXITCODE -eq 0)
}

# Returns the list of installed distribution names, or an empty array.
function Get-InstalledDistro {
    if (-not (Test-WslCommand)) { return @() }
    try {
        $output = & wsl.exe --list --quiet 2>$null
        if ($LASTEXITCODE -ne 0 -or -not $output) { return @() }
        return @($output | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    } catch {
        return @()
    }
}

function Install-UbuntuWsl {

    Write-Banner 'system_setup - Step 1: Ubuntu 24.04 LTS on Windows via WSL 2'

    # -- Preconditions ------------------------------------------------------

    if (-not (Test-Administrator)) {
        Write-Fail 'This script must run as Administrator.'
        Write-Host ''
        Write-Host 'Close this window, then:'
        Write-Host '  1. Press the Start button and type: PowerShell'
        Write-Host '  2. Right-click "Windows PowerShell" and choose "Run as administrator"'
        Write-Host '  3. Paste the command again.'
        return
    }
    Write-Ok 'Running with Administrator rights'

    $build = Get-WindowsBuild
    if ($build -lt 19041) {
        Write-Fail "Windows build $build is too old for WSL 2 (build 19041 or newer is required)."
        Write-Host 'Run Windows Update and try again.'
        return
    }
    Write-Ok "Windows build $build supports WSL 2"

    # Pinned to the exact release the rest of system_setup is written against.
    # The bare name "Ubuntu" tracks whatever Microsoft makes default, which is
    # not the same thing and drifts between releases.
    $distro = if ($env:WSL_DISTRO) { $env:WSL_DISTRO } else { 'Ubuntu-24.04' }
    Write-Ok "Target distribution: $distro"

    # -- Windows optional features -----------------------------------------

    Write-Step 'Checking the Windows features WSL depends on'
    $rebootNeeded = $false
    $features = @(
        @{ Name = 'Microsoft-Windows-Subsystem-Linux'; Label = 'Windows Subsystem for Linux' },
        @{ Name = 'VirtualMachinePlatform';            Label = 'Virtual Machine Platform' }
    )

    foreach ($feature in $features) {
        $state = (Get-WindowsOptionalFeature -Online -FeatureName $feature.Name).State
        if ($state -eq 'Enabled') {
            Write-Skip "$($feature.Label) is already enabled"
        } else {
            Write-Step "Enabling $($feature.Label)"
            $result = Enable-WindowsOptionalFeature -Online -FeatureName $feature.Name -All -NoRestart
            Write-Ok "$($feature.Label) enabled"
            if ($result.RestartNeeded) { $rebootNeeded = $true }
        }
    }

    if ($rebootNeeded) {
        Write-Banner 'Restart required'
        Write-Host 'Windows features were just turned on and need a restart before WSL can run.'
        Write-Host ''
        Write-Host '  1. Restart your computer.'
        Write-Host '  2. Open PowerShell as Administrator again.'
        Write-Host '  3. Run this same command a second time to finish the install.'
        Write-Host ''
        return
    }

    # -- WSL itself ---------------------------------------------------------

    if (-not (Test-WslCommand)) {
        Write-Fail 'wsl.exe is still missing even though the Windows features are enabled.'
        Write-Host 'Restart your computer and run this command again.'
        return
    }

    Write-Step 'Updating the WSL kernel'
    # --update takes no other options. Do not add --no-launch here: it is only
    # understood by --install, and WSL rejects the whole command.
    & wsl.exe --update 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0) {
        Write-Ok 'WSL kernel is up to date'
    } else {
        Write-Warn 'Could not update the WSL kernel automatically. Continuing.'
    }

    Write-Step 'Setting WSL 2 as the default version'
    & wsl.exe --set-default-version 2 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0) { Write-Ok 'Default WSL version is 2' }

    # -- The Ubuntu distribution -------------------------------------------

    $installed = Get-InstalledDistro

    $exact       = $installed | Where-Object { $_ -eq $distro }
    $otherUbuntu = $installed | Where-Object { $_ -like 'Ubuntu*' -and $_ -ne $distro }

    # $active is whichever Ubuntu this machine will actually be using.
    $active = $distro

    if ($exact) {
        Write-Skip "$distro is already installed"
    }
    elseif ($otherUbuntu) {
        # An Ubuntu is already here. Downloading another one would cost a few
        # hundred megabytes and leave the user with two systems to keep straight,
        # so leave well alone - the later steps work on any recent Ubuntu.
        $active = $otherUbuntu | Select-Object -First 1
        Write-Skip "Ubuntu is already installed: $($otherUbuntu -join ', ')"
        Write-Skip "Skipping the $distro download - your existing Ubuntu will be used."
        Write-Host ''
        Write-Host "  These guides are written and tested against Ubuntu 24.04 LTS."
        Write-Host "  Almost everything works the same on $active, but if a package"
        Write-Host "  name differs later, that is why."
        Write-Host ''
        Write-Host "  To install 24.04 as well, run this yourself:"
        Write-Host "    wsl --install -d $distro" -ForegroundColor White
        Write-Host ''
    }
    else {
        Write-Step "Installing $distro - this downloads a few hundred megabytes"

        # --no-launch stops WSL opening a setup window the moment the download
        # finishes, which is what we want when this script is being piped into
        # PowerShell. The option only exists on the Microsoft Store build of WSL,
        # so ask first rather than sending an argument the inbox build rejects.
        if (Test-WslNoLaunchSupport) {
            & wsl.exe --install --no-launch -d $distro 2>&1 | Out-Host
        } else {
            Write-Skip 'This WSL build has no --no-launch option; installing without it.'
            Write-Skip 'Ubuntu may open its own window and ask for a username - that is fine.'
            & wsl.exe --install -d $distro 2>&1 | Out-Host
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warn "wsl --install -d $distro did not succeed."
            Write-Host ''
            Write-Host 'Distributions this machine can install:'
            & wsl.exe --list --online 2>&1 | Out-Host
            Write-Host ''
            Write-Host "Look for Ubuntu-24.04 in the NAME column, then run:"
            Write-Host "  wsl --install -d Ubuntu-24.04"
            return
        }
        Write-Ok "$distro installed"
    }

    # Make that Ubuntu the one a bare "wsl" command opens.
    & wsl.exe --set-default $active 2>&1 | Out-Null
    Write-Ok "$active is the default distribution"

    # -- Summary ------------------------------------------------------------

    Write-Banner 'Installed'
    & wsl.exe --list --verbose 2>&1 | Out-Host

    Write-Banner 'Next steps'
    Write-Host "  1. Open the Start menu and launch `"$active`"."
    if ($active -eq 'Ubuntu-24.04') {
        Write-Host '     It appears as "Ubuntu 24.04.x LTS".'
    }
    Write-Host '  2. On first launch it asks you to create a username and password.'
    Write-Host '     This is your Linux account - it is separate from your Windows login.'
    Write-Host '     The password is invisible as you type. That is normal.'
    Write-Host ''
    Write-Host '  3. Inside that Ubuntu window, continue with step 2:'
    Write-Host ''
    Write-Host '       curl -fsSL https://aikaryashala.com/system_setup/scripts/install_cmds.sh | bash' -ForegroundColor White
    Write-Host ''
    Write-Host '  More detail: https://aikaryashala.com/system_setup/01_install_ubuntu/'
    Write-Host ''
}

Install-UbuntuWsl
