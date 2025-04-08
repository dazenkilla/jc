# -----------------------------------------
# Ambil versi terbaru JumpCloud dari website
# -----------------------------------------
Add-Type -AssemblyName System.Net.Http
$handler = New-Object System.Net.Http.HttpClientHandler
$client = New-Object System.Net.Http.HttpClient($handler)

$client.DefaultRequestHeaders.UserAgent.ParseAdd("Mozilla/5.0")  # Biar gak diblok

$response = $client.GetStringAsync("https://jumpcloud.com/support/list-of-jumpcloud-agent-release-notes").Result
$content = $response.ToString()

# Cari pola "- x.y.z"
$entryPattern = '-\s+(\d+\.\d+\.\d+)\b'
$matches = [regex]::Matches($content, $entryPattern)

$versions = @()
foreach ($m in $matches) {
    $versions += $m.Groups[1].Value
}

# Hilangkan duplikat dan urutkan dari yang terbaru
$uniqueVersions = $versions | Sort-Object -Unique | Sort-Object { [Version]$_ } -Descending
$latestVersionOnline = $uniqueVersions | Select-Object -First 1

Write-Host "🌐 Versi terbaru dari JumpCloud Website: v$latestVersionOnline"

# -----------------------------------------
# Bandingkan dengan versi lokal
# -----------------------------------------
$JCPATH = 'C:\Program Files\JumpCloud'
$SERVICEVERSION = Get-Content -Path (Join-Path -Path $JCPATH -ChildPath "Plugins\Contrib\version.txt")

Write-Output "💻 Local Service Version: $SERVICEVERSION"
Write-Output "🌍 Online Service Version: $latestVersionOnline"

if ([Version]$latestVersionOnline -gt [Version]$SERVICEVERSION) {
    Write-Output "⚠️ Local version is outdated. Proceeding with installation."

    # Path dan URL installer
    $TempPath = 'C:\Windows\Temp\'
    $AGENT_INSTALLER_URL = "https://cdn02.jumpcloud.com/production/jcagent-msi-signed.msi"
    $AGENT_INSTALLER_PATH = Join-Path $TempPath "jcagent-msi-signed.msi"

    # Function untuk install agent
    Function InstallAgent() {
        msiexec /i $AGENT_INSTALLER_PATH /quiet JCINSTALLERARGUMENTS=`"-k 5ede3dd0e94e49f715ca4ba4074b2849f95edf1c /VERYSILENT /NORESTART /NOCLOSEAPPLICATIONS /L*V 'C:\Windows\Temp\jcUpdate.log'`"
    }

    # Function untuk download installer
    Function DownloadAgentInstaller() {
        if (Test-Path -Path $AGENT_INSTALLER_PATH) {
            Write-Output "🧹 Old installer found. Deleting..."
            Remove-Item -Path $AGENT_INSTALLER_PATH -Force
        }

        Write-Output "⬇️ Downloading new installer..."
        (New-Object System.Net.WebClient).DownloadFile($AGENT_INSTALLER_URL, $AGENT_INSTALLER_PATH)
    }

    # Function utama download + install
    Function DownloadAndInstallAgent() {
        Write-Output '🚧 Preparing installation...'
        DownloadAgentInstaller
        Write-Output '✅ Download complete.'
        Write-Output '⚙️ Installing agent...'
        InstallAgent

        for ($i = 0; $i -lt 300; $i++) {
            Start-Sleep -Seconds 1
            $AgentService = Get-Service -Name "jumpcloud-agent" -ErrorAction SilentlyContinue
            if ($AgentService.Status -eq 'Running') {
                Write-Output '✅ JumpCloud Agent successfully installed and running.'
                return
            }
        }
        Write-Output '❌ JumpCloud Agent failed to start after installation.'
    }

    # Jalankan instalasi
    ipconfig /FlushDNS
    DownloadAndInstallAgent

} else {
    Write-Output "✅ Local version is up to date. No installation required."
}
