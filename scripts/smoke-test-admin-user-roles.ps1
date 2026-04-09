param(
    [string]$BaseUrl = "http://127.0.0.1:3002",
    [string]$AdminUsername = "adminlab",
    [string]$AdminPassword = "Admin12345!"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function ConvertTo-JsonBody {
    param([object]$Value)

    return $Value | ConvertTo-Json -Compress
}

function Invoke-JsonRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [object]$Body,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )

    $params = @{
        Method             = $Method
        Uri                = $Uri
        WebSession         = $Session
        Headers            = @{ Accept = "application/json" }
        TimeoutSec         = 30
        SkipHttpErrorCheck = $true
    }

    if ($null -ne $Body) {
        $params.ContentType = "application/json"
        $params.Body = ConvertTo-JsonBody $Body
    }

    $response = Invoke-WebRequest @params
    $parsedBody = $null

    if (-not [string]::IsNullOrWhiteSpace($response.Content)) {
        try {
            $parsedBody = $response.Content | ConvertFrom-Json -Depth 20
        }
        catch {
            $parsedBody = $response.Content
        }
    }

    return [PSCustomObject]@{
        StatusCode = [int]$response.StatusCode
        Body       = $parsedBody
        RawBody    = $response.Content
    }
}

$adminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
$promotedAdminSession = $null
$adminUser = $null
$newUser = $null
$newUsername = $null

try {
    $loginResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" -Body @{
        username = $AdminUsername
        password = $AdminPassword
    } -Session $adminSession

    if ($loginResponse.StatusCode -ne 200) {
        throw "Admin login failed: $($loginResponse.StatusCode) $($loginResponse.RawBody)"
    }

    $seed = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $newUsername = "rsmk$seed"
    $newEmail = "r$seed@ex.com"

    $registrationSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $registerResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/auth/register" -Body @{
        username = $newUsername
        email    = $newEmail
        fullname = "Role Smoke"
        password = $AdminPassword
    } -Session $registrationSession

    if ($registerResponse.StatusCode -ne 200) {
        throw "User registration failed: $($registerResponse.StatusCode) $($registerResponse.RawBody)"
    }

    $listResponse = Invoke-JsonRequest -Method "GET" -Uri "$BaseUrl/api/admin/users?page=1&pageSize=20" -Body $null -Session $adminSession
    if ($listResponse.StatusCode -ne 200) {
        throw "Admin user list failed: $($listResponse.StatusCode) $($listResponse.RawBody)"
    }

    $adminUser = $listResponse.Body.users.items | Where-Object { $_.username -eq $AdminUsername } | Select-Object -First 1
    $newUser = $listResponse.Body.users.items | Where-Object { $_.username -eq $newUsername } | Select-Object -First 1

    if ($null -eq $adminUser -or $null -eq $newUser) {
        throw "Missing admin or newly registered user in admin list."
    }

    $promotionResponse = Invoke-JsonRequest -Method "PATCH" -Uri "$BaseUrl/api/admin/users/$($newUser.applicationUserId)/role" -Body @{
        isAdmin = $true
    } -Session $adminSession

    if ($promotionResponse.StatusCode -ne 200 -or -not $promotionResponse.Body.user.isAdmin) {
        throw "Promotion failed: $($promotionResponse.StatusCode) $($promotionResponse.RawBody)"
    }

    $promotedAdminSession = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $promotedLoginResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/auth/login" -Body @{
        username = $newUsername
        password = $AdminPassword
    } -Session $promotedAdminSession

    if ($promotedLoginResponse.StatusCode -ne 200) {
        throw "Promoted admin login failed: $($promotedLoginResponse.StatusCode) $($promotedLoginResponse.RawBody)"
    }

    $promotedAdminListResponse = Invoke-JsonRequest -Method "GET" -Uri "$BaseUrl/api/admin/users?page=1&pageSize=20" -Body $null -Session $promotedAdminSession

    $selfDemotionResponse = Invoke-JsonRequest -Method "PATCH" -Uri "$BaseUrl/api/admin/users/$($adminUser.applicationUserId)/role" -Body @{
        isAdmin = $false
    } -Session $adminSession

    if ($selfDemotionResponse.StatusCode -ne 200 -or $selfDemotionResponse.Body.user.isAdmin) {
        throw "Self-demotion failed: $($selfDemotionResponse.StatusCode) $($selfDemotionResponse.RawBody)"
    }

    $sessionAfterSelfDemotion = Invoke-JsonRequest -Method "GET" -Uri "$BaseUrl/api/auth/session" -Body $null -Session $adminSession
    $adminListAfterSelfDemotion = Invoke-JsonRequest -Method "GET" -Uri "$BaseUrl/api/admin/users?page=1&pageSize=20" -Body $null -Session $adminSession
    $lastAdminProtectionResponse = Invoke-JsonRequest -Method "PATCH" -Uri "$BaseUrl/api/admin/users/$($newUser.applicationUserId)/role" -Body @{
        isAdmin = $false
    } -Session $promotedAdminSession

    $restoreAdminResponse = Invoke-JsonRequest -Method "PATCH" -Uri "$BaseUrl/api/admin/users/$($adminUser.applicationUserId)/role" -Body @{
        isAdmin = $true
    } -Session $promotedAdminSession

    if ($restoreAdminResponse.StatusCode -ne 200 -or -not $restoreAdminResponse.Body.user.isAdmin) {
        throw "Restoring the seeded admin failed: $($restoreAdminResponse.StatusCode) $($restoreAdminResponse.RawBody)"
    }

    $cleanupDemotionResponse = Invoke-JsonRequest -Method "PATCH" -Uri "$BaseUrl/api/admin/users/$($newUser.applicationUserId)/role" -Body @{
        isAdmin = $false
    } -Session $promotedAdminSession

    if ($cleanupDemotionResponse.StatusCode -ne 200 -or $cleanupDemotionResponse.Body.user.isAdmin) {
        throw "Cleanup demotion failed: $($cleanupDemotionResponse.StatusCode) $($cleanupDemotionResponse.RawBody)"
    }

    [PSCustomObject]@{
        BaseUrl                         = $BaseUrl
        NewUsername                     = $newUsername
        PromotionStatus                 = $promotionResponse.StatusCode
        PromotedUserAdminListStatus     = $promotedAdminListResponse.StatusCode
        SelfDemotionStatus              = $selfDemotionResponse.StatusCode
        SelfDemotionSessionIsAdmin      = $sessionAfterSelfDemotion.Body.session.user.isAdmin
        PostSelfDemotionAdminListStatus = $adminListAfterSelfDemotion.StatusCode
        LastAdminProtectionStatus       = $lastAdminProtectionResponse.StatusCode
        LastAdminProtectionBody         = if ($lastAdminProtectionResponse.Body -is [string]) { $lastAdminProtectionResponse.Body } else { $lastAdminProtectionResponse.RawBody }
        RestoreAdminStatus              = $restoreAdminResponse.StatusCode
        CleanupDemotionStatus           = $cleanupDemotionResponse.StatusCode
    } | Format-List
}
finally {
    if ($null -ne $promotedAdminSession -and $null -ne $adminUser -and $null -ne $newUser) {
        try {
            $restoreAttempt = Invoke-JsonRequest -Method "PATCH" -Uri "$BaseUrl/api/admin/users/$($adminUser.applicationUserId)/role" -Body @{
                isAdmin = $true
            } -Session $promotedAdminSession

            if ($restoreAttempt.StatusCode -eq 200) {
                Invoke-JsonRequest -Method "PATCH" -Uri "$BaseUrl/api/admin/users/$($newUser.applicationUserId)/role" -Body @{
                    isAdmin = $false
                } -Session $promotedAdminSession | Out-Null
            }
        }
        catch {
        }
    }
}