#Requires -Version 7

<#
.SYNOPSIS
    SSH into the 'mini' server and run start-tracker.sh to bring the
    torrents-tracker stack online.

.DESCRIPTION
    Thin remote-launcher around scripts/start-tracker.sh on the server.
    Connects via SSH (the host alias 'mini' must be defined in your
    ~/.ssh/config or %USERPROFILE%\.ssh\config), runs the start script,
    streams its output to your local console, and propagates the remote
    exit code.

    The remote bash script handles all the real work:
      - disk-space guard on /mnt/datassd
      - docker compose up -d
      - VPN tunnel verification (correct exit country)
      - tracker app HTTP probe
      - post-start stability re-check

.PARAMETER SshHost
    SSH host alias. Defaults to 'mini'.

.PARAMETER RemoteScript
    Absolute path to the bash script on the remote host.
    Defaults to /home/gp/dev/torrents-tracker/scripts/start-tracker.sh.

.PARAMETER Force
    Pass --force to the remote script (skip the disk-space guard).

.EXAMPLE
    .\Start-Tracker.ps1
    Run with all defaults: ssh mini, run start-tracker.sh.

.EXAMPLE
    .\Start-Tracker.ps1 -Force
    Skip the disk guard on the remote side.

.EXAMPLE
    .\Start-Tracker.ps1 -SshHost mini -RemoteScript /home/gp/dev/torrents-tracker/scripts/start-tracker.sh

.NOTES
    Author: Guillaume Plante <codegp@icloud.com>
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SshHost = 'mini',

    [Parameter(Mandatory = $false)]
    [string]$RemoteScript = '/home/gp/dev/torrents-tracker/scripts/start-tracker.sh',

    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Message
    )
    Write-Host "[start-tracker] $Message" -ForegroundColor Cyan
}

# --- Pre-flight: ssh client must be available ---
$sshCmd = Get-Command ssh -ErrorAction SilentlyContinue
if (-not $sshCmd) {
    Write-Error "ssh client not found in PATH. Install OpenSSH (Windows: 'Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0')."
    exit 1
}

# --- Pre-flight: SSH host must be reachable ---
Write-Step "Probing ssh host '$SshHost'"
$probe = & ssh -o BatchMode=yes -o ConnectTimeout=5 -- $SshHost 'echo ok' 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Cannot ssh to '$SshHost' non-interactively. Check ~/.ssh/config and key auth.`n$probe"
    exit 1
}
if ($probe -notmatch 'ok') {
    Write-Error "Unexpected ssh probe response from '$SshHost': $probe"
    exit 1
}

# --- Pre-flight: remote script must exist and be executable ---
Write-Step "Checking remote script $RemoteScript exists"
$check = & ssh -o BatchMode=yes -- $SshHost "test -x '$RemoteScript' && echo present || echo missing" 2>&1
if ($LASTEXITCODE -ne 0 -or $check -notmatch 'present') {
    Write-Error "Remote script not found or not executable at '$RemoteScript' on '$SshHost'.`n$check"
    exit 1
}

# --- Build remote command ---
$remoteArgs = @()
if ($Force) { $remoteArgs += '--force' }

# Single-quote the script path for the remote shell, append args.
$remoteCmd = "'$RemoteScript'"
if ($remoteArgs.Count -gt 0) {
    $remoteCmd += ' ' + ($remoteArgs -join ' ')
}

Write-Step "Running on $SshHost : $remoteCmd"
Write-Host ('-' * 72) -ForegroundColor DarkGray

# Use -t to allocate a TTY so the bash script's color output renders correctly,
# but only if our local stdout is a console. In a non-interactive context, skip
# -t to avoid 'Pseudo-terminal will not be allocated because stdin is not a terminal.'
$sshFlags = @('-o', 'BatchMode=yes')
if ([Environment]::UserInteractive -and -not [Console]::IsOutputRedirected) {
    $sshFlags += '-t'
}

# Stream output live; ssh inherits stdio.
& ssh @sshFlags -- $SshHost $remoteCmd
$remoteExit = $LASTEXITCODE

Write-Host ('-' * 72) -ForegroundColor DarkGray

switch ($remoteExit) {
    0 { Write-Host "[start-tracker] Remote reports SUCCESS" -ForegroundColor Green }
    2 { Write-Warning "[start-tracker] Remote aborted: disk space exceeded the limit" }
    3 { Write-Warning "[start-tracker] Remote aborted: docker compose up failed" }
    4 { Write-Warning "[start-tracker] Remote aborted: VPN tunnel did not establish or wrong exit country" }
    5 { Write-Warning "[start-tracker] Remote aborted: tracker app never responded on port 7070" }
    6 { Write-Warning "[start-tracker] Remote aborted: stack went unstable during the post-start window" }
    default { Write-Warning "[start-tracker] Remote exited with code $remoteExit" }
}

exit $remoteExit
