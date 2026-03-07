param(
    [switch]$SkipComposeUp,
    [int]$ContainerTimeoutSeconds = 300,
    [int]$HttpTimeoutSeconds = 300
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DockerCliPath {
    $dockerCommand = Get-Command docker -ErrorAction SilentlyContinue
    if ($dockerCommand) {
        return $dockerCommand.Source
    }

    $fallbackPath = 'C:\Program Files\Docker\Docker\resources\bin\docker.exe'
    if (Test-Path $fallbackPath) {
        return $fallbackPath
    }

    throw 'Docker CLI was not found on PATH or at the standard Docker Desktop location.'
}

function Ensure-DockerCliOnPath {
    param([Parameter(Mandatory)][string]$DockerCliPath)

    $dockerDirectory = Split-Path -Parent $DockerCliPath
    $pathEntries = @($env:Path -split ';' | Where-Object { $_ })

    if ($pathEntries -notcontains $dockerDirectory) {
        $env:Path = "$dockerDirectory;$env:Path"
    }
}

function Invoke-Docker {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & $script:dockerCli @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $lines = @($output | ForEach-Object { [string]$_ })

    if (-not $AllowFailure.IsPresent -and $exitCode -ne 0) {
        throw "docker $($Arguments -join ' ') failed with exit code $exitCode.`n$($lines -join [Environment]::NewLine)"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output   = $lines
    }
}

function Get-ContainerState {
    param([Parameter(Mandatory)][string]$ContainerName)

    $result = Invoke-Docker -Arguments @('inspect', $ContainerName, '--format', '{{.State.Status}}|{{.State.Running}}|{{.State.ExitCode}}') -AllowFailure
    if ($result.ExitCode -ne 0 -or $result.Output.Count -eq 0) {
        return $null
    }

    $parts = $result.Output[0].Split('|')
    if ($parts.Count -lt 3) {
        return $null
    }

    return [pscustomobject]@{
        Status   = $parts[0]
        Running  = $parts[1] -eq 'true'
        ExitCode = [int]$parts[2]
    }
}

function Wait-ForContainerRunning {
    param(
        [Parameter(Mandatory)][string]$ContainerName,
        [Parameter(Mandatory)][datetime]$Deadline
    )

    while ((Get-Date) -lt $Deadline) {
        $state = Get-ContainerState -ContainerName $ContainerName
        if ($null -ne $state) {
            if ($state.Running) {
                return
            }

            if ($state.Status -eq 'exited' -and $state.ExitCode -ne 0) {
                throw "$ContainerName exited with code $($state.ExitCode)."
            }
        }

        Start-Sleep -Seconds 3
    }

    throw "Timed out waiting for $ContainerName to be running."
}

function Wait-ForDbInitSuccess {
    param([Parameter(Mandatory)][datetime]$Deadline)

    while ((Get-Date) -lt $Deadline) {
        $state = Get-ContainerState -ContainerName 'bloglab-db-init'
        if ($null -ne $state -and $state.Status -eq 'exited') {
            if ($state.ExitCode -eq 0) {
                return
            }

            throw "bloglab-db-init exited with code $($state.ExitCode)."
        }

        Start-Sleep -Seconds 3
    }

    throw 'Timed out waiting for bloglab-db-init to complete successfully.'
}

function Get-HttpResult {
    param([Parameter(Mandatory)][string]$Url)

    try {
        $response = $script:httpClient.GetAsync($Url).GetAwaiter().GetResult()
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

        return [pscustomobject]@{
            StatusCode = [int]$response.StatusCode
            Body       = $body
        }
    }
    catch {
        return $null
    }
}

function Wait-ForHttpOk {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][datetime]$Deadline
    )

    while ((Get-Date) -lt $Deadline) {
        $result = Get-HttpResult -Url $Url
        if ($null -ne $result -and $result.StatusCode -eq 200) {
            return $result
        }

        Start-Sleep -Seconds 5
    }

    throw "Timed out waiting for $Name to return HTTP 200 from $Url."
}

function Show-ComposeLogs {
    $logs = Invoke-Docker -Arguments @('compose', 'logs', '--no-color', '--tail=120', 'db-init', 'api', 'ui') -AllowFailure
    if ($logs.Output.Count -gt 0) {
        Write-Host ''
        Write-Host 'Recent compose logs:'
        $logs.Output | ForEach-Object { Write-Host $_ }
    }
}

$script:dockerCli = Get-DockerCliPath
Ensure-DockerCliOnPath -DockerCliPath $script:dockerCli
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$script:httpClient = [System.Net.Http.HttpClient]::new()
$script:httpClient.Timeout = [TimeSpan]::FromSeconds(10)

try {
    if (-not $SkipComposeUp.IsPresent) {
        Write-Host 'Starting Docker dev stack...'
        Invoke-Docker -Arguments @('compose', 'up', '--build', '-d') | Out-Null
    }

    $containerDeadline = (Get-Date).AddSeconds($ContainerTimeoutSeconds)
    Write-Host 'Waiting for db-init to complete...'
    Wait-ForDbInitSuccess -Deadline $containerDeadline

    Write-Host 'Waiting for API and UI containers...'
    Wait-ForContainerRunning -ContainerName 'bloglab-api' -Deadline $containerDeadline
    Wait-ForContainerRunning -ContainerName 'bloglab-ui' -Deadline $containerDeadline

    $httpDeadline = (Get-Date).AddSeconds($HttpTimeoutSeconds)
    Write-Host 'Checking API endpoint...'
    $apiResult = Wait-ForHttpOk -Name 'API' -Url 'http://localhost:5000/api/blog' -Deadline $httpDeadline

    Write-Host 'Checking UI endpoint...'
    $uiResult = Wait-ForHttpOk -Name 'UI' -Url 'http://localhost:4200' -Deadline $httpDeadline

    Write-Host ''
    Write-Host 'Docker dev smoke test passed.'
    Write-Host "API  : $($apiResult.StatusCode) http://localhost:5000/api/blog"
    Write-Host "UI   : $($uiResult.StatusCode) http://localhost:4200"
    Write-Host "Body : $($apiResult.Body)"
}
catch {
    Show-ComposeLogs
    throw
}
finally {
    if ($null -ne $script:httpClient) {
        $script:httpClient.Dispose()
    }
}