param(
    [string]$ServerInstance = "AFMAIN\AFMAINSQL22",
    [string]$Database = "BlogDB",
    [string]$Username,
    [string]$Password,
    [string]$OutputPath = "docker/db/init/01-schema.sql"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module SqlServer
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.Smo')
[void][Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.ConnectionInfo')

$connection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
$connection.ServerInstance = $ServerInstance
$connection.EncryptConnection = $true
$connection.TrustServerCertificate = $true

if ($PSBoundParameters.ContainsKey('Username')) {
    $connection.LoginSecure = $false
    $connection.Login = $Username
    $connection.Password = $Password
}
else {
    $connection.LoginSecure = $true
}

$server = New-Object Microsoft.SqlServer.Management.Smo.Server($connection)
$db = $server.Databases[$Database]

if (-not $db) {
    throw "Database '$Database' was not found on '$ServerInstance'."
}

$options = New-Object Microsoft.SqlServer.Management.Smo.ScriptingOptions
$options.IncludeHeaders = $true
$options.SchemaQualify = $true
$options.DriAll = $true
$options.Indexes = $true
$options.Triggers = $true
$options.ClusteredIndexes = $true
$options.NonClusteredIndexes = $true
$options.Default = $true
$options.Bindings = $true
$options.ScriptData = $false
$options.ScriptSchema = $true
$options.IncludeDatabaseContext = $false
$options.AnsiFile = $true
$options.NoCollation = $true

function Write-ScriptLines {
    param(
        [System.Collections.IEnumerable]$ScriptLines,
        [switch]$SplitSetStatements
    )

    foreach ($line in $ScriptLines) {
        $physicalLines = [System.Text.RegularExpressions.Regex]::Split([string]$line, "\r\n?|\n")

        foreach ($text in $physicalLines) {
            $writer.WriteLine($text)

            if ($SplitSetStatements.IsPresent -and $text -match '^SET (ANSI_NULLS|QUOTED_IDENTIFIER)\s') {
                $writer.WriteLine('GO')
                $writer.WriteLine('')
            }
        }
    }

    $writer.WriteLine('')
    $writer.WriteLine('GO')
    $writer.WriteLine('')
}

function Get-TableKey {
    param([object]$Table)

    return ('{0}.{1}' -f $Table.Schema, $Table.Name)
}

function Get-OrderedTables {
    param([object[]]$Tables)

    $remaining = @($Tables | Sort-Object Schema, Name)
    $ordered = @()
    $resolved = @{}
    $tableKeys = @{}

    foreach ($table in $remaining) {
        $tableKeys[(Get-TableKey -Table $table)] = $true
    }

    while ($remaining.Count -gt 0) {
        $progress = $false
        $nextRemaining = @()

        foreach ($table in $remaining) {
            $dependencies = @(
                $table.ForeignKeys |
                ForEach-Object { '{0}.{1}' -f $_.ReferencedTableSchema, $_.ReferencedTable } |
                Where-Object { $tableKeys.ContainsKey($_) } |
                Select-Object -Unique
            )

            $unresolvedDependencies = @(
                $dependencies |
                Where-Object { -not $resolved.ContainsKey($_) }
            )

            if ($unresolvedDependencies.Count -eq 0) {
                $ordered += $table
                $resolved[(Get-TableKey -Table $table)] = $true
                $progress = $true
            }
            else {
                $nextRemaining += $table
            }
        }

        if (-not $progress) {
            $remainingTableNames = @($nextRemaining | ForEach-Object { Get-TableKey -Table $_ }) -join ', '
            throw "Unable to resolve table dependency order for: $remainingTableNames"
        }

        $remaining = $nextRemaining
    }

    return @($ordered)
}

$outputFullPath = Join-Path (Get-Location) $OutputPath
$outputDirectory = Split-Path -Parent $outputFullPath
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$tempOutputPath = Join-Path $outputDirectory ([System.IO.Path]::GetRandomFileName())

$header = @(
    "-- Generated from $ServerInstance / $Database on $(Get-Date -Format s)",
    "USE [$Database]",
    'GO',
    ''
)
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$writer = New-Object System.IO.StreamWriter($tempOutputPath, $false, $utf8NoBom)
foreach ($line in $header) {
    $writer.WriteLine($line)
}

function Write-SmoObjects {
    param(
        [string]$Title,
        [object[]]$Objects,
        [switch]$SplitSetStatements
    )

    if (-not $Objects -or $Objects.Count -eq 0) {
        return
    }

    $writer.WriteLine("-- $Title")
    $writer.WriteLine('')

    foreach ($object in $Objects) {
        $script = $object.Script($options)
        if ($null -ne $script -and $script.Count -gt 0) {
            Write-ScriptLines -ScriptLines $script -SplitSetStatements:$SplitSetStatements
        }
    }
}

$schemas = @(
    $db.Schemas |
    Where-Object { -not $_.IsSystemObject -and $_.Name -notin @('dbo', 'guest', 'sys', 'INFORMATION_SCHEMA') } |
    Sort-Object Name
)

$tableTypes = @(
    $db.UserDefinedTableTypes |
    Sort-Object Schema, Name
)

$tables = @(
    Get-OrderedTables -Tables @(
        $db.Tables |
        Where-Object { -not $_.IsSystemObject -and $_.Name -ne 'sysdiagrams' }
    )
)

$views = @(
    $db.Views |
    Where-Object { -not $_.IsSystemObject } |
    Sort-Object Schema, Name
)

$functions = @(
    $db.UserDefinedFunctions |
    Where-Object { -not $_.IsSystemObject -and $_.Name -ne 'fn_diagramobjects' } |
    Sort-Object Schema, Name
)

$storedProcedures = @(
    $db.StoredProcedures |
    Where-Object { -not $_.IsSystemObject -and $_.Name -notlike 'sp[_]%' } |
    Sort-Object Schema, Name
)

try {
    Write-SmoObjects -Title 'Schemas' -Objects $schemas -SplitSetStatements
    Write-SmoObjects -Title 'User-defined table types' -Objects $tableTypes -SplitSetStatements
    Write-SmoObjects -Title 'Tables' -Objects $tables -SplitSetStatements
    Write-SmoObjects -Title 'Functions' -Objects $functions -SplitSetStatements
    Write-SmoObjects -Title 'Views' -Objects $views -SplitSetStatements
    Write-SmoObjects -Title 'Stored procedures' -Objects $storedProcedures -SplitSetStatements

    $writer.Flush()
}
finally {
    if ($null -ne $writer) {
        $writer.Dispose()
    }
}

Move-Item -Force -Path $tempOutputPath -Destination $outputFullPath

Write-Output "Schema exported to $outputFullPath"