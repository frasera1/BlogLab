param(
  [switch]$SkipComposeUp,
  [switch]$SkipApiStart,
  [string]$ApiBaseUrl = 'http://localhost:5000',
  [int]$ContainerTimeoutSeconds = 300,
  [int]$ApiTimeoutSeconds = 180
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

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

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'

  try {
    $output = & $script:dockerCli @Arguments 2>&1
  }
  finally {
    $ErrorActionPreference = $previousErrorActionPreference
  }

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

function Get-DotNetPath {
  $dotnetCommand = Get-Command dotnet -ErrorAction SilentlyContinue
  if ($dotnetCommand) {
    return $dotnetCommand.Source
  }

  $fallbackPath = 'C:\Program Files\dotnet\dotnet.exe'
  if (Test-Path $fallbackPath) {
    return $fallbackPath
  }

  throw 'dotnet CLI was not found on PATH or at the standard install location.'
}

function Get-EnvFileValues {
  param([Parameter(Mandatory)][string]$FilePath)

  $values = @{}
  if (-not (Test-Path $FilePath)) {
    return $values
  }

  foreach ($line in Get-Content $FilePath) {
    if ([string]::IsNullOrWhiteSpace($line) -or $line.TrimStart().StartsWith('#')) {
      continue
    }

    $parts = $line -split '=', 2
    if ($parts.Count -eq 2) {
      $values[$parts[0]] = $parts[1]
    }
  }

  return $values
}

function Start-ApiProcess {
  param(
    [Parameter(Mandatory)][string]$RepoRoot,
    [Parameter(Mandatory)][string]$ApiBaseUrl,
    [Parameter(Mandatory)][hashtable]$EnvFileValues
  )

  $logDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('bloglab-backend-smoke-' + [guid]::NewGuid().ToString('N'))
  [System.IO.Directory]::CreateDirectory($logDirectory) | Out-Null

  $stdoutPath = Join-Path $logDirectory 'api-stdout.log'
  $stderrPath = Join-Path $logDirectory 'api-stderr.log'
  $dotnetPath = Get-DotNetPath
  $saPassword = if ($EnvFileValues.ContainsKey('BLOGDB_SA_PASSWORD')) { $EnvFileValues['BLOGDB_SA_PASSWORD'] } else { 'BlogLab!DevSa2026' }

  $startEnvironment = @{
    ASPNETCORE_ENVIRONMENT               = 'Development'
    Jwt__Issuer                          = $ApiBaseUrl
    ConnectionStrings__DefaultConnection = "Server=localhost,14333;Database=BlogDB;User Id=sa;Password=$saPassword;Persist Security Info=False;Pooling=False;MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=True"
  }

  foreach ($key in 'CLOUDINARY_CLOUD_NAME', 'CLOUDINARY_API_KEY', 'CLOUDINARY_API_SECRET') {
    if (-not $EnvFileValues.ContainsKey($key)) {
      continue
    }

    switch ($key) {
      'CLOUDINARY_CLOUD_NAME' { $startEnvironment['CloudinaryOptions__CloudName'] = $EnvFileValues[$key] }
      'CLOUDINARY_API_KEY' { $startEnvironment['CloudinaryOptions__ApiKey'] = $EnvFileValues[$key] }
      'CLOUDINARY_API_SECRET' { $startEnvironment['CloudinaryOptions__ApiSecret'] = $EnvFileValues[$key] }
    }
  }

  $process = Start-Process -FilePath $dotnetPath `
    -ArgumentList @('run', '--project', 'BlogLab.Web', '--no-launch-profile', '--urls', $ApiBaseUrl) `
    -WorkingDirectory $RepoRoot `
    -RedirectStandardOutput $stdoutPath `
    -RedirectStandardError $stderrPath `
    -Environment $startEnvironment `
    -PassThru

  return [pscustomobject]@{
    Process    = $process
    StdOutPath = $stdoutPath
    StdErrPath = $stderrPath
  }
}

function Stop-ApiProcess {
  param([Parameter(Mandatory)]$ApiProcessInfo)

  $process = $ApiProcessInfo.Process
  if ($null -ne $process) {
    if (-not $process.HasExited) {
      $process.Kill($true)
      $process.WaitForExit()
    }

    $process.Dispose()
  }
}

function New-JsonContent {
  param($Body)

  $json = if ($Body -is [string]) { $Body } else { $Body | ConvertTo-Json -Compress }
  return [System.Net.Http.StringContent]::new($json, [System.Text.Encoding]::UTF8, 'application/json')
}

function Invoke-ApiRequest {
  param(
    [Parameter(Mandatory)][System.Net.Http.HttpMethod]$Method,
    [Parameter(Mandatory)][string]$Url,
    $Body,
    [hashtable]$Headers
  )

  $request = [System.Net.Http.HttpRequestMessage]::new($Method, $Url)
  try {
    if ($Headers) {
      foreach ($header in $Headers.GetEnumerator()) {
        $request.Headers.TryAddWithoutValidation([string]$header.Key, [string]$header.Value) | Out-Null
      }
    }

    if ($PSBoundParameters.ContainsKey('Body')) {
      $request.Content = New-JsonContent -Body $Body
    }

    $response = $script:httpClient.SendAsync($request).GetAwaiter().GetResult()
    $content = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()

    return [pscustomobject]@{
      StatusCode = [int]$response.StatusCode
      Body       = $content
    }
  }
  finally {
    $request.Dispose()
  }
}

function Wait-ForApiReady {
  param(
    [Parameter(Mandatory)][string]$ApiBaseUrl,
    [Parameter(Mandatory)][datetime]$Deadline,
    $ApiProcessInfo
  )

  while ((Get-Date) -lt $Deadline) {
    $result = $null
    try {
      $result = Invoke-ApiRequest -Method ([System.Net.Http.HttpMethod]::Get) -Url "$ApiBaseUrl/api/blog"
    }
    catch {
      $result = $null
    }

    if ($null -ne $result -and $result.StatusCode -eq 200) {
      return $result
    }

    if ($null -ne $ApiProcessInfo -and $ApiProcessInfo.Process.HasExited) {
      $stdout = if (Test-Path $ApiProcessInfo.StdOutPath) { Get-Content $ApiProcessInfo.StdOutPath -Raw } else { '' }
      $stderr = if (Test-Path $ApiProcessInfo.StdErrPath) { Get-Content $ApiProcessInfo.StdErrPath -Raw } else { '' }
      throw "The host API exited before it became ready.`nSTDOUT:`n$stdout`nSTDERR:`n$stderr"
    }

    Start-Sleep -Seconds 3
  }

  throw "Timed out waiting for $ApiBaseUrl/api/blog to return HTTP 200."
}

function Promote-AdminUser {
  param(
    [Parameter(Mandatory)][string]$Username,
    [Parameter(Mandatory)][hashtable]$EnvFileValues
  )

  $saPassword = if ($EnvFileValues.ContainsKey('BLOGDB_SA_PASSWORD')) { $EnvFileValues['BLOGDB_SA_PASSWORD'] } else { 'BlogLab!DevSa2026' }
  Invoke-Docker -Arguments @(
    'exec',
    'bloglab-db',
    '/opt/mssql-tools18/bin/sqlcmd',
    '-C',
    '-S',
    'localhost',
    '-U',
    'sa',
    '-P',
    $saPassword,
    '-d',
    'BlogDB',
    '-Q',
    "UPDATE dbo.ApplicationUser SET IsAdmin = 1 WHERE Username = '$Username'"
  ) | Out-Null
}

function Show-DbLogs {
  $logs = Invoke-Docker -Arguments @('compose', 'logs', '--no-color', '--tail=120', 'db', 'db-init') -AllowFailure
  if ($logs.Output.Count -gt 0) {
    Write-Host ''
    Write-Host 'Recent database logs:'
    $logs.Output | ForEach-Object { Write-Host $_ }
  }
}

$script:dockerCli = Get-DockerCliPath
Ensure-DockerCliOnPath -DockerCliPath $script:dockerCli
$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

$envFileValues = Get-EnvFileValues -FilePath (Join-Path $repoRoot '.env')
$script:httpClient = [System.Net.Http.HttpClient]::new()
$script:httpClient.Timeout = [TimeSpan]::FromSeconds(20)
$apiProcessInfo = $null
$stoppedComposeApi = $false

try {
  if (-not $SkipComposeUp.IsPresent) {
    Write-Host 'Starting Docker database services...'
    Invoke-Docker -Arguments @('compose', 'up', '-d', 'db', 'db-init') | Out-Null
  }

  $containerDeadline = (Get-Date).AddSeconds($ContainerTimeoutSeconds)
  Write-Host 'Waiting for db-init to complete...'
  Wait-ForDbInitSuccess -Deadline $containerDeadline

  if (-not $SkipApiStart.IsPresent) {
    $composeApiState = Get-ContainerState -ContainerName 'bloglab-api'
    if ($null -ne $composeApiState -and $composeApiState.Running) {
      Write-Host 'Stopping Compose API to avoid host/container build output contention...'
      Invoke-Docker -Arguments @('compose', 'stop', 'api') | Out-Null
      $stoppedComposeApi = $true
    }

    Write-Host 'Starting host API...'
    $apiProcessInfo = Start-ApiProcess -RepoRoot $repoRoot -ApiBaseUrl $ApiBaseUrl -EnvFileValues $envFileValues
  }

  $apiDeadline = (Get-Date).AddSeconds($ApiTimeoutSeconds)
  Write-Host 'Waiting for API readiness...'
  $anonymousRead = Wait-ForApiReady -ApiBaseUrl $ApiBaseUrl -Deadline $apiDeadline -ApiProcessInfo $apiProcessInfo

  $username = 'smoke' + (Get-Date -Format 'HHmmss')
  $password = 'SmokePass!2026'

  Write-Host 'Registering smoke user...'
  $register = Invoke-ApiRequest -Method ([System.Net.Http.HttpMethod]::Post) -Url "$ApiBaseUrl/api/account/register" -Body @{
    username = $username
    password = $password
    fullname = 'Backend Smoke User'
    email    = "$username@ex.co"
  }

  if ($register.StatusCode -ne 200) {
    throw "Expected register to return 200 but got $($register.StatusCode). Body: $($register.Body)"
  }

  Write-Host 'Logging in smoke user...'
  $login = Invoke-ApiRequest -Method ([System.Net.Http.HttpMethod]::Post) -Url "$ApiBaseUrl/api/account/login" -Body @{
    username = $username
    password = $password
  }

  if ($login.StatusCode -ne 200) {
    throw "Expected login to return 200 but got $($login.StatusCode). Body: $($login.Body)"
  }

  $loginBody = $login.Body | ConvertFrom-Json
  $authHeaders = @{ Authorization = "Bearer $($loginBody.token)" }

  Write-Host 'Creating blog as authenticated user...'
  $blogCreate = Invoke-ApiRequest -Method ([System.Net.Http.HttpMethod]::Post) -Url "$ApiBaseUrl/api/blog" -Headers $authHeaders -Body @{
    blogId  = 0
    title   = 'Backend smoke blog'
    content = ('Backend smoke content. ' * 16)
    photoId = $null
  }

  if ($blogCreate.StatusCode -ne 200) {
    throw "Expected authenticated blog create to return 200 but got $($blogCreate.StatusCode). Body: $($blogCreate.Body)"
  }

  Write-Host 'Checking admin route as non-admin...'
  $adminForbidden = Invoke-ApiRequest -Method ([System.Net.Http.HttpMethod]::Get) -Url "$ApiBaseUrl/api/admin/blog" -Headers $authHeaders
  if ($adminForbidden.StatusCode -ne 403) {
    throw "Expected non-admin GET /api/admin/blog to return 403 but got $($adminForbidden.StatusCode). Body: $($adminForbidden.Body)"
  }

  Write-Host 'Promoting smoke user to admin...'
  Promote-AdminUser -Username $username -EnvFileValues $envFileValues

  Write-Host 'Logging in promoted admin user...'
  $adminLogin = Invoke-ApiRequest -Method ([System.Net.Http.HttpMethod]::Post) -Url "$ApiBaseUrl/api/account/login" -Body @{
    username = $username
    password = $password
  }

  if ($adminLogin.StatusCode -ne 200) {
    throw "Expected admin login to return 200 but got $($adminLogin.StatusCode). Body: $($adminLogin.Body)"
  }

  $adminLoginBody = $adminLogin.Body | ConvertFrom-Json
  $adminHeaders = @{ Authorization = "Bearer $($adminLoginBody.token)" }

  Write-Host 'Checking admin route as admin...'
  $adminOk = Invoke-ApiRequest -Method ([System.Net.Http.HttpMethod]::Get) -Url "$ApiBaseUrl/api/admin/blog" -Headers $adminHeaders
  if ($adminOk.StatusCode -ne 200) {
    throw "Expected admin GET /api/admin/blog to return 200 but got $($adminOk.StatusCode). Body: $($adminOk.Body)"
  }

  Write-Host ''
  Write-Host 'Backend host smoke test passed.'
  Write-Host "Startup/anonymous read : $($anonymousRead.StatusCode) $ApiBaseUrl/api/blog"
  Write-Host "Authenticated route    : $($blogCreate.StatusCode) POST $ApiBaseUrl/api/blog"
  Write-Host "Admin route (non-admin): $($adminForbidden.StatusCode) GET $ApiBaseUrl/api/admin/blog"
  Write-Host "Admin route (admin)    : $($adminOk.StatusCode) GET $ApiBaseUrl/api/admin/blog"
}
catch {
  Show-DbLogs
  throw
}
finally {
  if ($null -ne $apiProcessInfo) {
    Stop-ApiProcess -ApiProcessInfo $apiProcessInfo
  }

  if ($null -ne $script:httpClient) {
    $script:httpClient.Dispose()
  }

  if ($stoppedComposeApi) {
    Write-Host ''
    Write-Host 'Compose API was stopped for this smoke test to avoid host/container output contention.'
  }
}