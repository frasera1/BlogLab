param(
  [string]$BaseUrl = "http://127.0.0.1:5000",
  [string]$AdminUsername = "adminlab",
  [string]$AdminPassword = "Admin12345!",
  [string]$TestPassword = "Admin12345!",
  [switch]$SkipPhotoUpload
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
    [hashtable]$Headers
  )

  $params = @{
    Method             = $Method
    Uri                = $Uri
    Headers            = @{ Accept = "application/json" }
    TimeoutSec         = 60
    SkipHttpErrorCheck = $true
  }

  if ($null -ne $Headers) {
    foreach ($entry in $Headers.GetEnumerator()) {
      $params.Headers[$entry.Key] = $entry.Value
    }
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

function Assert-StatusCode {
  param(
    [Parameter(Mandatory)]$Response,
    [Parameter(Mandatory)][int]$Expected,
    [Parameter(Mandatory)][string]$Operation
  )

  if ($Response.StatusCode -ne $Expected) {
    throw "$Operation failed: expected HTTP $Expected but got $($Response.StatusCode). Body: $($Response.RawBody)"
  }
}

function New-AuthHeaders {
  param([Parameter(Mandatory)][string]$Token)

  return @{ Authorization = "Bearer $Token" }
}

function Register-TestUser {
  param(
    [Parameter(Mandatory)][string]$BaseUrl,
    [Parameter(Mandatory)][string]$Username,
    [Parameter(Mandatory)][string]$Email,
    [Parameter(Mandatory)][string]$Fullname,
    [Parameter(Mandatory)][string]$Password
  )

  $response = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/account/register" -Body @{
    username = $Username
    email    = $Email
    fullname = $Fullname
    password = $Password
  }

  Assert-StatusCode -Response $response -Expected 200 -Operation "Register user '$Username'"

  return $response.Body
}

function Login-TestUser {
  param(
    [Parameter(Mandatory)][string]$BaseUrl,
    [Parameter(Mandatory)][string]$Username,
    [Parameter(Mandatory)][string]$Password
  )

  $response = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/account/login" -Body @{
    username = $Username
    password = $Password
  }

  Assert-StatusCode -Response $response -Expected 200 -Operation "Login user '$Username'"

  return $response.Body
}

function New-TempPngFile {
  $pngBytes = [Convert]::FromBase64String("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wn8N7sAAAAASUVORK5CYII=")
  $filePath = Join-Path ([System.IO.Path]::GetTempPath()) (([System.Guid]::NewGuid().ToString("N")) + ".png")
  [System.IO.File]::WriteAllBytes($filePath, $pngBytes)
  return $filePath
}

function Upload-Photo {
  param(
    [Parameter(Mandatory)][string]$BaseUrl,
    [Parameter(Mandatory)][string]$Token
  )

  $filePath = New-TempPngFile

  try {
    $response = Invoke-WebRequest -Method "POST" -Uri "$BaseUrl/api/photo" -Headers @{
      Accept        = "application/json"
      Authorization = "Bearer $Token"
    } -Form @{ file = Get-Item $filePath } -TimeoutSec 60 -SkipHttpErrorCheck

    $body = if ([string]::IsNullOrWhiteSpace($response.Content)) { $null } else { $response.Content | ConvertFrom-Json -Depth 20 }
    if ([int]$response.StatusCode -ne 200) {
      throw "Upload photo failed: expected HTTP 200 but got $([int]$response.StatusCode). Body: $($response.Content)"
    }

    return $body
  }
  finally {
    if (Test-Path $filePath) {
      Remove-Item $filePath -Force
    }
  }
}

function New-BlogContent {
  param([Parameter(Mandatory)][string]$Seed)

  return ("Delete smoke content $Seed. " * 16).Substring(0, 360)
}

$seed = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$targetUsername = ("delu" + $seed).Substring(0, [Math]::Min(20, ("delu" + $seed).Length))
$actorUsername = ("dela" + $seed).Substring(0, [Math]::Min(20, ("dela" + $seed).Length))
$targetEmail = "delu$seed@example.com"
$actorEmail = "dela$seed@example.com"

$adminUser = $null
$targetUser = $null
$actorUser = $null
$adminHeaders = $null
$targetHeaders = $null
$actorHeaders = $null
$targetPhoto = $null
$targetBlog = $null
$actorBlog = $null
$rootComment = $null
$replyComment = $null

try {
  $adminUser = Login-TestUser -BaseUrl $BaseUrl -Username $AdminUsername -Password $AdminPassword
  $adminHeaders = New-AuthHeaders -Token $adminUser.token

  $targetUser = Register-TestUser -BaseUrl $BaseUrl -Username $targetUsername -Email $targetEmail -Fullname "Delete Target" -Password $TestPassword
  $actorUser = Register-TestUser -BaseUrl $BaseUrl -Username $actorUsername -Email $actorEmail -Fullname "Delete Actor" -Password $TestPassword

  $targetUser = Login-TestUser -BaseUrl $BaseUrl -Username $targetUsername -Password $TestPassword
  $actorUser = Login-TestUser -BaseUrl $BaseUrl -Username $actorUsername -Password $TestPassword

  $targetHeaders = New-AuthHeaders -Token $targetUser.token
  $actorHeaders = New-AuthHeaders -Token $actorUser.token

  if (-not $SkipPhotoUpload.IsPresent) {
    $targetPhoto = Upload-Photo -BaseUrl $BaseUrl -Token $targetUser.token
  }

  $actorBlogResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/blog" -Headers $actorHeaders -Body @{
    title   = "Actor smoke blog $seed"
    content = New-BlogContent -Seed "actor-$seed"
  }
  Assert-StatusCode -Response $actorBlogResponse -Expected 200 -Operation "Create actor blog"
  $actorBlog = $actorBlogResponse.Body

  $targetBlogBody = @{
    title   = "Target smoke blog $seed"
    content = New-BlogContent -Seed "target-$seed"
  }
  if ($null -ne $targetPhoto) {
    $targetBlogBody.photoId = $targetPhoto.photoId
  }

  $targetBlogResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/blog" -Headers $targetHeaders -Body $targetBlogBody
  Assert-StatusCode -Response $targetBlogResponse -Expected 200 -Operation "Create target blog"
  $targetBlog = $targetBlogResponse.Body

  $actorLikeResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/blog/$($targetBlog.blogId)/like/toggle" -Headers $actorHeaders
  Assert-StatusCode -Response $actorLikeResponse -Expected 200 -Operation "Like target blog as actor"

  $targetLikeResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/blog/$($actorBlog.blogId)/like/toggle" -Headers $targetHeaders
  Assert-StatusCode -Response $targetLikeResponse -Expected 200 -Operation "Like actor blog as target"

  $rootCommentResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/blogcomment" -Headers $actorHeaders -Body @{
    blogId  = $targetBlog.blogId
    content = "Actor root comment for delete smoke."
  }
  Assert-StatusCode -Response $rootCommentResponse -Expected 200 -Operation "Create root comment"
  $rootComment = $rootCommentResponse.Body

  $replyCommentResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/blogcomment" -Headers $targetHeaders -Body @{
    parentBlogCommentId = $rootComment.blogCommentId
    blogId              = $targetBlog.blogId
    content             = "Target reply comment for delete smoke."
  }
  Assert-StatusCode -Response $replyCommentResponse -Expected 200 -Operation "Create target reply comment"
  $replyComment = $replyCommentResponse.Body

  $nestedCommentResponse = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/blogcomment" -Headers $actorHeaders -Body @{
    parentBlogCommentId = $replyComment.blogCommentId
    blogId              = $targetBlog.blogId
    content             = "Actor nested reply for delete smoke."
  }
  Assert-StatusCode -Response $nestedCommentResponse -Expected 200 -Operation "Create nested reply comment"

  $deleteResponse = Invoke-JsonRequest -Method "DELETE" -Uri "$BaseUrl/api/admin/users/$($targetUser.applicationUserId)" -Headers $adminHeaders
  Assert-StatusCode -Response $deleteResponse -Expected 200 -Operation "Admin delete target user"

  if ($deleteResponse.Body.deletedUserCount -ne 1) {
    throw "Expected deletedUserCount = 1 but got $($deleteResponse.Body.deletedUserCount)."
  }

  if ($deleteResponse.Body.deletedBlogCount -ne 1) {
    throw "Expected deletedBlogCount = 1 but got $($deleteResponse.Body.deletedBlogCount)."
  }

  if ($deleteResponse.Body.deletedCommentCount -lt 3) {
    throw "Expected at least 3 deleted comments but got $($deleteResponse.Body.deletedCommentCount)."
  }

  if ($deleteResponse.Body.deletedLikeCount -lt 2) {
    throw "Expected at least 2 deleted likes but got $($deleteResponse.Body.deletedLikeCount)."
  }

  $expectedPhotoCount = if ($SkipPhotoUpload.IsPresent) { 0 } else { 1 }
  if ($deleteResponse.Body.deletedPhotoCount -ne $expectedPhotoCount) {
    throw "Expected deletedPhotoCount = $expectedPhotoCount but got $($deleteResponse.Body.deletedPhotoCount)."
  }

  $targetBlogAfterDelete = Invoke-JsonRequest -Method "GET" -Uri "$BaseUrl/api/blog/$($targetBlog.blogId)"
  if ($targetBlogAfterDelete.StatusCode -ne 204) {
    throw "Expected target blog lookup after delete to return 204 but got $($targetBlogAfterDelete.StatusCode). Body: $($targetBlogAfterDelete.RawBody)"
  }

  $actorBlogAfterDelete = Invoke-JsonRequest -Method "GET" -Uri "$BaseUrl/api/blog/$($actorBlog.blogId)"
  Assert-StatusCode -Response $actorBlogAfterDelete -Expected 200 -Operation "Verify actor blog still exists"

  $targetLoginAfterDelete = Invoke-JsonRequest -Method "POST" -Uri "$BaseUrl/api/account/login" -Body @{
    username = $targetUsername
    password = $TestPassword
  }
  if ($targetLoginAfterDelete.StatusCode -ne 400) {
    throw "Expected deleted target login to return 400 but got $($targetLoginAfterDelete.StatusCode). Body: $($targetLoginAfterDelete.RawBody)"
  }

  $userListAfterDelete = Invoke-JsonRequest -Method "GET" -Uri "$BaseUrl/api/admin/users?page=1&pageSize=50" -Headers $adminHeaders
  Assert-StatusCode -Response $userListAfterDelete -Expected 200 -Operation "List users after delete"

  $foundDeletedUser = @($userListAfterDelete.Body.items | Where-Object { $_.username -eq $targetUsername })
  if ($foundDeletedUser.Count -ne 0) {
    throw "Deleted target user '$targetUsername' is still present in the admin list."
  }

  [PSCustomObject]@{
    BaseUrl                      = $BaseUrl
    DeletedUsername              = $targetUsername
    DeletedApplicationUserId     = $deleteResponse.Body.applicationUserId
    DeletedBlogCount             = $deleteResponse.Body.deletedBlogCount
    DeletedCommentCount          = $deleteResponse.Body.deletedCommentCount
    DeletedLikeCount             = $deleteResponse.Body.deletedLikeCount
    DeletedPhotoCount            = $deleteResponse.Body.deletedPhotoCount
    DeletedUserCount             = $deleteResponse.Body.deletedUserCount
    TargetBlogAfterDeleteStatus  = $targetBlogAfterDelete.StatusCode
    ActorBlogAfterDeleteStatus   = $actorBlogAfterDelete.StatusCode
    TargetLoginAfterDeleteStatus = $targetLoginAfterDelete.StatusCode
    UserListAfterDeleteStatus    = $userListAfterDelete.StatusCode
    PhotoCoverage                = if ($SkipPhotoUpload.IsPresent) { "skipped" } else { "included" }
  } | Format-List
}
finally {
  if ($null -ne $adminHeaders -and $null -ne $targetUser) {
    try {
      Invoke-JsonRequest -Method "DELETE" -Uri "$BaseUrl/api/admin/users/$($targetUser.applicationUserId)" -Headers $adminHeaders | Out-Null
    }
    catch {
    }
  }

  if ($null -ne $adminHeaders -and $null -ne $actorUser) {
    try {
      Invoke-JsonRequest -Method "DELETE" -Uri "$BaseUrl/api/admin/users/$($actorUser.applicationUserId)" -Headers $adminHeaders | Out-Null
    }
    catch {
    }
  }
}