# Aykan Akduman Tarafından Tasarlandı
# Designed by Aykan Akduman
# Integrity protected. Removing the credit or modifying this script invalidates the integrity check.
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$ProjectArchivePath = "",

    [string]$BundlePath = "",

    [string]$BundleArchivePath = "",

    [string]$OutputPath = ""
)

$script:IntegrityCreditTr = "Aykan Akduman Tarafından Tasarlandı"
$script:IntegrityCreditEn = "Designed by Aykan Akduman"
$script:IntegrityExpectedLength = "0000042252"
$script:IntegrityExpectedSha256 = "C89C274267BBC20876B6C7D2601774AC7B515DA48179CDE6E3D778705857802E"

function Get-ScriptIntegrityCanonicalText {
    param([string]$Text)

    $reader = New-Object System.IO.StringReader -ArgumentList $Text
    $builder = New-Object System.Text.StringBuilder
    $firstLine = $true

    try {
        while ($true) {
            $line = $reader.ReadLine()

            if ($null -eq $line) {
                break
            }

            if (-not $firstLine) {
                [void]$builder.Append([char]10)
            }

            $firstLine = $false

            if ($line.StartsWith('$script:IntegrityExpectedLength = "')) {
                [void]$builder.Append('$script:IntegrityExpectedLength = "0000000000"')
            }
            elseif ($line.StartsWith('$script:IntegrityExpectedSha256 = "')) {
                [void]$builder.Append('$script:IntegrityExpectedSha256 = "0000000000000000000000000000000000000000000000000000000000000000"')
            }
            else {
                [void]$builder.Append($line)
            }
        }
    }
    finally {
        $reader.Dispose()
    }

    return $builder.ToString()
}

function Assert-ScriptIntegrity {
    param([string]$ScriptPath)

    if ([string]::IsNullOrWhiteSpace($ScriptPath) -or -not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        throw "Script integrity check failed: script path could not be resolved."
    }

    $scriptText = [System.IO.File]::ReadAllText($ScriptPath, [System.Text.Encoding]::UTF8)

    if (-not $scriptText.Contains("# Aykan Akduman Tarafından Tasarlandı")) {
        throw "Script integrity check failed: required Turkish author credit is missing."
    }

    if (-not $scriptText.Contains("# Designed by Aykan Akduman")) {
        throw "Script integrity check failed: required English author credit is missing."
    }

    if ($script:IntegrityCreditTr -ne "Aykan Akduman Tarafından Tasarlandı") {
        throw "Script integrity check failed: Turkish author credit was modified."
    }

    if ($script:IntegrityCreditEn -ne "Designed by Aykan Akduman") {
        throw "Script integrity check failed: English author credit was modified."
    }

    $canonicalText = Get-ScriptIntegrityCanonicalText -Text $scriptText
    $actualLength = $canonicalText.Length
    $expectedLength = [Int64]::Parse($script:IntegrityExpectedLength)

    if ($actualLength -ne $expectedLength) {
        throw ("Script integrity check failed: length mismatch. Expected " + $expectedLength + ", actual " + $actualLength + ".")
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $bytes = $utf8NoBom.GetBytes($canonicalText)
    $sha256 = [System.Security.Cryptography.SHA256]::Create()

    try {
        $hashBytes = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }

    $actualHash = ([System.BitConverter]::ToString($hashBytes)).Replace("-", "")

    if ($actualHash -ne $script:IntegrityExpectedSha256) {
        throw "Script integrity check failed: SHA-256 mismatch. This script was modified after release."
    }
}

Assert-ScriptIntegrity -ScriptPath $PSCommandPath

$ErrorActionPreference = "Stop"


$ScriptSettingsPath = Join-Path -Path $PSScriptRoot -ChildPath "script-settings.json"

function Get-DefaultScriptSettings {
    return [ordered]@{
        promptLanguage = "tr"
        exclude = [ordered]@{
            folders = @(
                ".git",
                "node_modules",
                "target",
                "dist",
                "build",
                "bin",
                "obj",
                ".idea",
                ".vscode",
                "coverage",
                ".next",
                "out",
                "vendor",
                "packages",
                "__pycache__",
                ".venv",
                "venv",
                ".turbo",
                ".cache",
                ".angular",
                ".parcel-cache"
            )
            files = @()
        }
    }
}

function Save-ScriptSettings {
    param([object]$Settings)

    $json = $Settings | ConvertTo-Json -Depth 8
    $utf8BomSettings = New-Object System.Text.UTF8Encoding($true)
    [System.IO.File]::WriteAllText($ScriptSettingsPath, $json, $utf8BomSettings)
}

function Initialize-ScriptSettings {
    $defaults = Get-DefaultScriptSettings

    if (-not (Test-Path -LiteralPath $ScriptSettingsPath -PathType Leaf)) {
        Save-ScriptSettings -Settings $defaults
        return $defaults
    }

    try {
        $raw = [System.IO.File]::ReadAllText($ScriptSettingsPath)
        $loaded = $raw | ConvertFrom-Json
    }
    catch {
        throw ("Invalid script-settings.json: " + $_.Exception.Message)
    }

    $changed = $false

    if ($null -eq $loaded.PSObject.Properties["promptLanguage"]) {
        $loaded | Add-Member -NotePropertyName "promptLanguage" -NotePropertyValue "tr"
        $changed = $true
    }

    if ($null -eq $loaded.PSObject.Properties["exclude"] -or $null -eq $loaded.exclude) {
        $loaded | Add-Member -NotePropertyName "exclude" -NotePropertyValue ([PSCustomObject]@{
            folders = @($defaults.exclude.folders)
            files = @($defaults.exclude.files)
        })
        $changed = $true
    }
    else {
        if ($null -eq $loaded.exclude.PSObject.Properties["folders"]) {
            $loaded.exclude | Add-Member -NotePropertyName "folders" -NotePropertyValue @($defaults.exclude.folders)
            $changed = $true
        }

        if ($null -eq $loaded.exclude.PSObject.Properties["files"]) {
            $loaded.exclude | Add-Member -NotePropertyName "files" -NotePropertyValue @()
            $changed = $true
        }
    }

    if ($changed) {
        Save-ScriptSettings -Settings $loaded
    }

    return $loaded
}

function Test-NameMatchesExcludeList {
    param(
        [string]$Name,
        [System.Collections.IEnumerable]$Patterns
    )

    if ([string]::IsNullOrWhiteSpace($Name) -or $null -eq $Patterns) {
        return $false
    }

    foreach ($patternValue in $Patterns) {
        $pattern = [string]$patternValue

        if ([string]::IsNullOrWhiteSpace($pattern)) {
            continue
        }

        if ($Name -like $pattern) {
            return $true
        }
    }

    return $false
}

function Test-IsExcludedFolderName {
    param([string]$Name)

    return Test-NameMatchesExcludeList -Name $Name -Patterns $script:ExcludedFolderNames
}

function Test-IsExcludedFileName {
    param([string]$Name)

    return Test-NameMatchesExcludeList -Name $Name -Patterns $script:ExcludedFileNames
}


function Test-PathContainsExcludedFolderName {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $false
    }

    try {
        $fullPath = [System.IO.Path]::GetFullPath($PathValue)
    }
    catch {
        $fullPath = $PathValue
    }

    $root = [System.IO.Path]::GetPathRoot($fullPath)
    $withoutRoot = $fullPath

    if (-not [string]::IsNullOrWhiteSpace($root) -and $withoutRoot.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        $withoutRoot = $withoutRoot.Substring($root.Length)
    }

    $parts = $withoutRoot.Split(@("\", "/"), [System.StringSplitOptions]::RemoveEmptyEntries)

    foreach ($part in $parts) {
        if (Test-IsExcludedFolderName -Name $part) {
            return $true
        }
    }

    return $false
}

function Test-IsToolOwnedPath {
    param([string]$CandidatePath)

    if ([string]::IsNullOrWhiteSpace($CandidatePath)) {
        return $false
    }

    try {
        $candidate = ([System.IO.Path]::GetFullPath($CandidatePath)).TrimEnd("\", "/").ToLowerInvariant()
        $scriptRoot = ([System.IO.Path]::GetFullPath($PSScriptRoot)).TrimEnd("\", "/").ToLowerInvariant()
    }
    catch {
        return $false
    }

    if ($candidate -eq $scriptRoot) {
        return $true
    }

    if (($scriptRoot + "\").StartsWith($candidate + "\")) {
        return $true
    }

    if (($candidate + "\").StartsWith($scriptRoot + "\")) {
        return $true
    }

    return $false
}

$ScriptSettings = Initialize-ScriptSettings

$script:PromptLanguage = ([string]$ScriptSettings.promptLanguage).Trim().ToLowerInvariant()
$script:ExcludedFolderNames = @($ScriptSettings.exclude.folders)
$script:ExcludedFileNames = @($ScriptSettings.exclude.files)

if ($script:PromptLanguage -in @("turkish", "tr-tr")) {
    $script:PromptLanguage = "tr"
}
elseif ($script:PromptLanguage -in @("english", "en-us", "en-gb")) {
    $script:PromptLanguage = "en"
}

if ($script:PromptLanguage -notin @("tr", "en")) {
    Write-Warning ("Unknown promptLanguage '" + $ScriptSettings.promptLanguage + "'. Falling back to 'tr'.")
    $script:PromptLanguage = "tr"
}


if ($script:PromptLanguage -eq "tr") {
    $SiblingGenerator = Join-Path -Path $PSScriptRoot -ChildPath "codex-handoff-prompt-generator-tr.ps1"

    if (Test-Path -LiteralPath $SiblingGenerator -PathType Leaf) {
        try {
            & $SiblingGenerator -ProjectPath $ProjectPath -ProjectArchivePath $ProjectArchivePath -BundlePath $BundlePath -BundleArchivePath $BundleArchivePath -OutputPath $OutputPath

            if (-not $?) {
                throw "Turkish prompt generator reported failure."
            }

            return
        }
        catch {
            throw ("Turkish prompt generator failed: " + $_.Exception.Message)
        }
    }

    Write-Warning "promptLanguage is 'tr' but codex-handoff-prompt-generator-tr.ps1 was not found. Continuing with the English generator."
}


trap {
    Write-Host ""
    Write-Host "PROMPT GENERATOR FAILED" -ForegroundColor Red
    Write-Host ("Message: " + $_.Exception.Message) -ForegroundColor Red

    if ($null -ne $_.InvocationInfo) {
        Write-Host ("Script line: " + $_.InvocationInfo.ScriptLineNumber) -ForegroundColor Yellow
        Write-Host ("Line text: " + $_.InvocationInfo.Line) -ForegroundColor Yellow
        Write-Host ("Position: " + $_.InvocationInfo.PositionMessage) -ForegroundColor DarkYellow
    }

    throw
}


Add-Type -AssemblyName System.IO.Compression.FileSystem

function Normalize-RelativePath {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    $result = $Value.Replace("\", "/").TrimStart("/")

    while ($result.Contains("//")) {
        $result = $result.Replace("//", "/")
    }

    return $result
}

function Get-RelativePathSimple {
    param(
        [string]$Root,
        [string]$FullPath
    )

    try {
        $rootPath = $Root.TrimEnd("\", "/") + "\"
        $rootUri = New-Object System.Uri($rootPath)
        $fileUri = New-Object System.Uri($FullPath)
        $relative = $rootUri.MakeRelativeUri($fileUri).ToString()
        return [System.Uri]::UnescapeDataString($relative).Replace("/", "\")
    }
    catch {
        return $FullPath
    }
}

function Get-ZipEntrySet {
    param(
        [string]$ZipPath,
        [string]$ProjectName
    )

    $raw = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $firstSegments = [System.Collections.Generic.Dictionary[string,int]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $fileEntryCount = 0

    $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)

    try {
        foreach ($entry in $zip.Entries) {
            if ([string]::IsNullOrWhiteSpace($entry.Name)) {
                continue
            }

            $path = Normalize-RelativePath -Value $entry.FullName

            if ([string]::IsNullOrWhiteSpace($path)) {
                continue
            }

            $raw.Add($path) | Out-Null
            $fileEntryCount = $fileEntryCount + 1

            $parts = $path.Split("/")

            if ($parts.Count -gt 1) {
                $first = $parts[0]

                if ($firstSegments.ContainsKey($first)) {
                    $firstSegments[$first] = $firstSegments[$first] + 1
                }
                else {
                    $firstSegments[$first] = 1
                }
            }
        }
    }
    finally {
        $zip.Dispose()
    }

    $stripPrefix = ""

    if ($fileEntryCount -gt 0) {
        $bestName = ""
        $bestCount = 0

        foreach ($pair in $firstSegments.GetEnumerator()) {
            if ($pair.Value -gt $bestCount) {
                $bestCount = $pair.Value
                $bestName = $pair.Key
            }
        }

        if (-not [string]::IsNullOrWhiteSpace($bestName)) {
            $ratio = $bestCount / [double]$fileEntryCount

            if (
                $ratio -ge 0.70 -or
                $bestName.Equals($ProjectName, [System.StringComparison]::OrdinalIgnoreCase)
            ) {
                $stripPrefix = $bestName + "/"
            }
        }
    }

    $normalized = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($item in $raw) {
        $value = $item

        if (
            -not [string]::IsNullOrWhiteSpace($stripPrefix) -and
            $value.StartsWith($stripPrefix, [System.StringComparison]::OrdinalIgnoreCase)
        ) {
            $value = $value.Substring($stripPrefix.Length)
        }

        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $normalized.Add($value) | Out-Null
        }
    }

    return [PSCustomObject]@{
        Entries = $normalized
        RawEntries = $raw
        StrippedPrefix = $stripPrefix
        FileCount = $fileEntryCount
    }
}

function Get-ProjectSampleFiles {
    param(
        [string]$Root,
        [int]$Limit = 250
    )

    $result = New-Object System.Collections.Generic.List[string]
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Root)

    while ($stack.Count -gt 0 -and $result.Count -lt $Limit) {
        $current = $stack.Pop()

        try {
            $items = Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop
        }
        catch {
            continue
        }

        foreach ($item in $items) {
            if ($item.PSIsContainer) {
                if (Test-IsExcludedFolderName -Name $item.Name) {
                    continue
                }

                if ($item.Name.StartsWith("AI_HANDOFF_BUNDLE_")) {
                    continue
                }

                if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                    continue
                }

                $stack.Push($item.FullName)
            }
            else {
                if (Test-IsExcludedFileName -Name $item.Name) {
                    continue
                }

                if ($item.Name -like "codex-handoff*.ps1") {
                    continue
                }

                if ($item.Name -eq "script-settings.json") {
                    continue
                }

                $relative = Get-RelativePathSimple -Root $Root -FullPath $item.FullName
                $result.Add((Normalize-RelativePath -Value $relative))

                if ($result.Count -ge $Limit) {
                    break
                }
            }
        }
    }

    return $result
}

function Get-ZipSimilarity {
    param(
        [string]$ZipPath,
        [string]$ProjectRoot,
        [string]$ProjectName
    )

    try {
        $zipInfo = Get-ZipEntrySet -ZipPath $ZipPath -ProjectName $ProjectName
        $sample = Get-ProjectSampleFiles -Root $ProjectRoot -Limit 250

        if ($sample.Count -eq 0) {
            return 0.0
        }

        $matches = 0

        foreach ($relative in $sample) {
            if ($zipInfo.Entries.Contains($relative)) {
                $matches = $matches + 1
            }
        }

        return [Math]::Round(($matches / [double]$sample.Count), 3)
    }
    catch {
        return 0.0
    }
}

function Find-BundleDirectory {
    param([string]$ProjectRoot)

    $candidates = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
    $roots = New-Object System.Collections.Generic.List[string]

    $roots.Add($ProjectRoot)

    $parent = Split-Path -Parent $ProjectRoot

    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $parentName = Split-Path -Leaf $parent

        if (-not (Test-IsExcludedFolderName -Name $parentName)) {
            $roots.Add($parent)
        }
    }

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        foreach ($dir in (
            Get-ChildItem -LiteralPath $root -Force -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name.StartsWith("AI_HANDOFF_BUNDLE_") }
        )) {
            $candidates.Add($dir)
        }
    }

    if ($candidates.Count -eq 0) {
        return $null
    }

    return $candidates |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1
}

function Find-BundleArchive {
    param(
        [string]$ProjectRoot,
        [string]$KnownBundlePath
    )

    $candidates = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $roots = New-Object System.Collections.Generic.List[string]

    $roots.Add($ProjectRoot)

    $parent = Split-Path -Parent $ProjectRoot

    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $parentName = Split-Path -Leaf $parent

        if (-not (Test-IsExcludedFolderName -Name $parentName)) {
            $roots.Add($parent)
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($KnownBundlePath)) {
        $bundleParent = Split-Path -Parent $KnownBundlePath

        if (-not [string]::IsNullOrWhiteSpace($bundleParent)) {
            $bundleParentName = Split-Path -Leaf $bundleParent

            if (-not (Test-IsExcludedFolderName -Name $bundleParentName)) {
                if (-not ($roots -contains $bundleParent)) {
                    $roots.Add($bundleParent)
                }
            }
        }
    }

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        foreach ($file in (
            Get-ChildItem -LiteralPath $root -Force -File -Filter "*.zip" -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName.StartsWith("AI_HANDOFF_BUNDLE_") }
        )) {
            $candidates.Add($file)
        }
    }

    if ($candidates.Count -eq 0) {
        return $null
    }

    if (-not [string]::IsNullOrWhiteSpace($KnownBundlePath)) {
        $expectedBase = Split-Path -Leaf $KnownBundlePath

        $exact = $candidates |
            Where-Object { $_.BaseName -eq $expectedBase } |
            Sort-Object -Property LastWriteTime -Descending |
            Select-Object -First 1

        if ($null -ne $exact) {
            return $exact
        }
    }

    return $candidates |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1
}

function Find-ProjectArchive {
    param(
        [string]$ProjectRoot,
        [string]$ProjectName
    )

    $candidates = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $roots = New-Object System.Collections.Generic.List[string]

    $roots.Add($ProjectRoot)

    $parent = Split-Path -Parent $ProjectRoot

    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        if (-not (Test-PathContainsExcludedFolderName -PathValue $parent)) {
            if (-not (Test-IsToolOwnedPath -CandidatePath $parent)) {
                $roots.Add($parent)
            }
        }

        $grandParent = Split-Path -Parent $parent

        if (-not [string]::IsNullOrWhiteSpace($grandParent)) {
            if (-not (Test-PathContainsExcludedFolderName -PathValue $grandParent)) {
                if (-not (Test-IsToolOwnedPath -CandidatePath $grandParent)) {
                    $roots.Add($grandParent)
                }
            }
        }
    }

    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root -PathType Container)) {
            continue
        }

        foreach ($file in (
            Get-ChildItem -LiteralPath $root -Force -File -Filter "*.zip" -ErrorAction SilentlyContinue |
            Where-Object {
                -not $_.BaseName.StartsWith("AI_HANDOFF_BUNDLE_") -and
                -not $_.BaseName.StartsWith("codex-handoff-report-tool") -and
                -not $_.BaseName.StartsWith("codex-handoff-tool")
            }
        )) {
            if (-not ($candidates.FullName -contains $file.FullName)) {
                $candidates.Add($file)
            }
        }
    }

    if ($candidates.Count -eq 0) {
        return $null
    }

    $scored = New-Object System.Collections.Generic.List[object]

    foreach ($file in $candidates) {
        $score = Get-ZipSimilarity -ZipPath $file.FullName -ProjectRoot $ProjectRoot -ProjectName $ProjectName

        $nameBonus = 0.0

        if ($file.BaseName.Equals($ProjectName, [System.StringComparison]::OrdinalIgnoreCase)) {
            $nameBonus = 0.20
        }
        elseif ($file.BaseName.ToLowerInvariant().Contains($ProjectName.ToLowerInvariant())) {
            $nameBonus = 0.10
        }

        $scored.Add(
            [PSCustomObject]@{
                File = $file
                Similarity = $score
                FinalScore = $score + $nameBonus
            }
        )
    }

    $sorted = @(
        $scored |
        Sort-Object -Property @(
            @{ Expression = { $_.FinalScore }; Descending = $true },
            @{ Expression = { $_.File.LastWriteTime }; Descending = $true }
        )
    )

    if ($sorted.Count -gt 0) {
        return $sorted[0]
    }

    return $null
}

function Test-IgnoredForOmission {
    param(
        [System.IO.FileSystemInfo]$Item,
        [string]$ProjectArchive,
        [string]$BundleArchive,
        [string]$BundleDirectory
    )

    if ($Item.PSIsContainer) {
        if (Test-IsExcludedFolderName -Name $Item.Name) {
            return $true
        }
    }
    else {
        if (Test-IsExcludedFileName -Name $Item.Name) {
            return $true
        }
    }

    if ($Item.Name -eq ".git") {
        return $true
    }

    if ($Item.Name.StartsWith("AI_HANDOFF_BUNDLE_")) {
        return $true
    }

    if ($Item.Name -like "codex-handoff*.ps1") {
        return $true
    }

    if ($Item.Name -eq "AI_CONTINUATION_PROMPT.txt" -or $Item.Name -eq "AI_CONTINUATION_PROMPT_EN.txt") {
        return $true
    }

    if ($Item.Name -eq "script-settings.json") {
        return $true
    }

    if ($Item.Name -eq "PROJECT_ARCHIVE_OMISSIONS.md") {
        return $true
    }

    if (-not [string]::IsNullOrWhiteSpace($ProjectArchive)) {
        if ($Item.FullName -eq $ProjectArchive) {
            return $true
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($BundleArchive)) {
        if ($Item.FullName -eq $BundleArchive) {
            return $true
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($BundleDirectory)) {
        if ($Item.FullName -eq $BundleDirectory) {
            return $true
        }
    }

    return $false
}

function Get-ArchiveOmissionReport {
    param(
        [string]$ProjectRoot,
        [string]$ZipPath,
        [string]$ProjectName,
        [string]$BundleZipPath,
        [string]$BundleDirectoryPath
    )

    $zipInfo = Get-ZipEntrySet -ZipPath $ZipPath -ProjectName $ProjectName
    $entries = $zipInfo.Entries

    $wholeMissingItems = New-Object System.Collections.Generic.List[string]
    $missingFiles = New-Object System.Collections.Generic.List[string]
    $includedTopLevel = New-Object System.Collections.Generic.List[string]

    $topItems = @(
        Get-ChildItem -LiteralPath $ProjectRoot -Force -ErrorAction SilentlyContinue
    )

    foreach ($item in $topItems) {
        if (Test-IgnoredForOmission -Item $item -ProjectArchive $ZipPath -BundleArchive $BundleZipPath -BundleDirectory $BundleDirectoryPath) {
            continue
        }

        if ($item.PSIsContainer) {
            $prefix = Normalize-RelativePath -Value ($item.Name + "/")
            $foundAny = $false

            foreach ($entry in $entries) {
                if ($entry.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $foundAny = $true
                    break
                }
            }

            if (-not $foundAny) {
                $wholeMissingItems.Add($item.Name + "\")
            }
            else {
                $includedTopLevel.Add($item.FullName)
            }
        }
        else {
            $relative = Normalize-RelativePath -Value $item.Name

            if (-not $entries.Contains($relative)) {
                $wholeMissingItems.Add($item.Name)
            }
        }
    }

    foreach ($root in $includedTopLevel) {
        $stack = New-Object System.Collections.Generic.Stack[string]
        $stack.Push($root)

        while ($stack.Count -gt 0) {
            $current = $stack.Pop()

            try {
                $items = Get-ChildItem -LiteralPath $current -Force -ErrorAction Stop
            }
            catch {
                continue
            }

            foreach ($item in $items) {
                if ($item.PSIsContainer) {
                    if (Test-IsExcludedFolderName -Name $item.Name) {
                        continue
                    }

                    if ($item.Name -eq ".git") {
                        continue
                    }

                    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                        continue
                    }

                    $stack.Push($item.FullName)
                }
                else {
                    if (Test-IgnoredForOmission -Item $item -ProjectArchive $ZipPath -BundleArchive $BundleZipPath -BundleDirectory $BundleDirectoryPath) {
                        continue
                    }

                    $relativeWin = Get-RelativePathSimple -Root $ProjectRoot -FullPath $item.FullName
                    $relative = Normalize-RelativePath -Value $relativeWin

                    if (-not $entries.Contains($relative)) {
                        $missingFiles.Add($relativeWin)
                    }
                }
            }
        }
    }

    return [PSCustomObject]@{
        ZipPrefixRemoved = $zipInfo.StrippedPrefix
        ZipFileCount = $zipInfo.FileCount
        WholeMissingItems = $wholeMissingItems
        MissingFiles = $missingFiles
    }
}

try {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}
catch {
    throw ("Project directory not found: " + $ProjectPath)
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    throw ("Path is not a directory: " + $ProjectPath)
}

$ProjectName = Split-Path -Leaf $ProjectPath

if ([string]::IsNullOrWhiteSpace($BundlePath)) {
    $bundleDir = Find-BundleDirectory -ProjectRoot $ProjectPath

    if ($null -ne $bundleDir) {
        $BundlePath = $bundleDir.FullName
    }
}
else {
    try {
        $BundlePath = (Resolve-Path -LiteralPath $BundlePath).Path
    }
    catch {
        throw ("Bundle directory not found: " + $BundlePath)
    }
}

if ([string]::IsNullOrWhiteSpace($ProjectArchivePath)) {
    $projectArchiveCandidate = Find-ProjectArchive -ProjectRoot $ProjectPath -ProjectName $ProjectName

    if ($null -eq $projectArchiveCandidate) {
        throw "No project ZIP archive could be detected automatically."
    }

    $ProjectArchivePath = $projectArchiveCandidate.File.FullName
    $ProjectArchiveSimilarity = $projectArchiveCandidate.Similarity
}
else {
    try {
        $ProjectArchivePath = (Resolve-Path -LiteralPath $ProjectArchivePath).Path
    }
    catch {
        throw ("Project archive not found: " + $ProjectArchivePath)
    }

    $ProjectArchiveSimilarity = Get-ZipSimilarity -ZipPath $ProjectArchivePath -ProjectRoot $ProjectPath -ProjectName $ProjectName
}

if ([string]::IsNullOrWhiteSpace($BundleArchivePath)) {
    $bundleArchiveCandidate = Find-BundleArchive -ProjectRoot $ProjectPath -KnownBundlePath $BundlePath

    if ($null -ne $bundleArchiveCandidate) {
        $BundleArchivePath = $bundleArchiveCandidate.FullName
    }
}

$ProjectArchiveName = [System.IO.Path]::GetFileName($ProjectArchivePath)

$BundleArchiveName = ""

if (-not [string]::IsNullOrWhiteSpace($BundleArchivePath)) {
    $BundleArchiveName = [System.IO.Path]::GetFileName($BundleArchivePath)
}
elseif (-not [string]::IsNullOrWhiteSpace($BundlePath)) {
    $BundleArchiveName = (Split-Path -Leaf $BundlePath) + ".zip"
}
else {
    $BundleArchiveName = "AI_HANDOFF_BUNDLE_<generated_timestamp>.zip"
}

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    if (-not [string]::IsNullOrWhiteSpace($BundlePath)) {
        $OutputPath = Join-Path -Path $BundlePath -ChildPath "AI_CONTINUATION_PROMPT_EN.txt"
    }
    else {
        $projectArchiveDirectory = Split-Path -Parent $ProjectArchivePath
        $OutputPath = Join-Path -Path $projectArchiveDirectory -ChildPath "AI_CONTINUATION_PROMPT_EN.txt"
    }
}

$omission = Get-ArchiveOmissionReport -ProjectRoot $ProjectPath -ZipPath $ProjectArchivePath -ProjectName $ProjectName -BundleZipPath $BundleArchivePath -BundleDirectoryPath $BundlePath

$OmissionReportPath = ""

if (-not [string]::IsNullOrWhiteSpace($BundlePath)) {
    $OmissionReportPath = Join-Path -Path $BundlePath -ChildPath "PROJECT_ARCHIVE_OMISSIONS.md"
}
else {
    $outputParentDirectory = Split-Path -Parent $OutputPath
    $OmissionReportPath = Join-Path -Path $outputParentDirectory -ChildPath "PROJECT_ARCHIVE_OMISSIONS.md"
}

$Utf8Bom = New-Object System.Text.UTF8Encoding($true)

$omissionReport = New-Object System.Collections.Generic.List[string]
$omissionReport.Add("# Project Archive Omissions")
$omissionReport.Add("")
$omissionReport.Add("Project directory: " + $ProjectPath)
$omissionReport.Add("Project archive: " + $ProjectArchiveName)
$omissionReport.Add("Archive similarity score: " + $ProjectArchiveSimilarity)
$omissionReport.Add("ZIP root prefix removed during comparison: " + $omission.ZipPrefixRemoved)
$omissionReport.Add("ZIP file entries: " + $omission.ZipFileCount)
$omissionReport.Add("Excluded folder name patterns: " + ($script:ExcludedFolderNames -join ", "))
$omissionReport.Add("Excluded file name patterns: " + ($script:ExcludedFileNames -join ", "))
$omissionReport.Add("")
$omissionReport.Add("IMPORTANT: Missing items are detected by comparing the live project directory with the supplied project ZIP.")
$omissionReport.Add("Names excluded by script-settings.json are intentionally ignored and are not reported as archive omissions.")
$omissionReport.Add("The script cannot know whether an omission was intentional. Treat these as archive omissions, not deleted project content.")
$omissionReport.Add("")
$omissionReport.Add("## Entire top-level items missing from project ZIP")
$omissionReport.Add("")

if ($omission.WholeMissingItems.Count -eq 0) {
    $omissionReport.Add("- None detected.")
}
else {
    foreach ($item in $omission.WholeMissingItems) {
        $omissionReport.Add("- " + $item)
    }
}

$omissionReport.Add("")
$omissionReport.Add("## Individual files missing inside otherwise included directories")
$omissionReport.Add("")

if ($omission.MissingFiles.Count -eq 0) {
    $omissionReport.Add("- None detected.")
}
else {
    foreach ($item in $omission.MissingFiles) {
        $omissionReport.Add("- " + $item)
    }
}

[System.IO.File]::WriteAllLines($OmissionReportPath, $omissionReport.ToArray(), $Utf8Bom)

$prompt = New-Object System.Collections.Generic.List[string]

$prompt.Add("You are taking over this project from another Codex/AI coding session. The previous work may have been interrupted because of usage or credit limits, a crash, disconnection, or the session ending before all changes were finalized.")
$prompt.Add("")
$prompt.Add("You are being given at least two primary archives:")
$prompt.Add("")
$prompt.Add("- " + $ProjectArchiveName + ": Main project source archive.")
$prompt.Add("- " + $BundleArchiveName + ": Handoff and recovery bundle generated from previous Codex sessions.")
$prompt.Add("")

if ($omission.WholeMissingItems.Count -gt 0 -or $omission.MissingFiles.Count -gt 0) {
    $prompt.Add("IMPORTANT - THE PROJECT ZIP IS NOT A COMPLETE COPY OF THE LIVE PROJECT DIRECTORY.")
    $prompt.Add("")
    $prompt.Add("The generator compared the live project directory with " + $ProjectArchiveName + " and detected files or directories that are not present in the ZIP.")
    $prompt.Add("Do not assume these items were deleted. They may have been intentionally or unintentionally excluded from the archive.")
    $prompt.Add("")

    if ($omission.WholeMissingItems.Count -gt 0) {
        $prompt.Add("Top-level items completely missing from the project ZIP:")

        foreach ($item in $omission.WholeMissingItems) {
            $prompt.Add("- " + $item)
        }

        $prompt.Add("")
    }

    if ($omission.MissingFiles.Count -gt 0) {
        $previewCount = [Math]::Min(20, $omission.MissingFiles.Count)
        $prompt.Add("The comparison also found " + $omission.MissingFiles.Count + " file(s) missing from directories that are otherwise present in the ZIP.")

        for ($i = 0; $i -lt $previewCount; $i = $i + 1) {
            $prompt.Add("- " + $omission.MissingFiles[$i])
        }

        if ($omission.MissingFiles.Count -gt $previewCount) {
            $prompt.Add("- ... additional missing files exist.")
        }

        $prompt.Add("")
    }

    $prompt.Add("The complete archive-omission report is available in PROJECT_ARCHIVE_OMISSIONS.md inside the handoff bundle.")
    $prompt.Add("")
}

$prompt.Add("CRITICAL: Do not assume that the project tree inside " + $ProjectArchiveName + " is the most advanced state reached by the previous Codex session.")
$prompt.Add("")
$prompt.Add("Codex may have created or modified files outside the main project directory in staging, worktree, scratch, temporary, backup, shadow, or other external workspaces. Those changes may not have been copied back into the main project before the session ended.")
$prompt.Add("")
$prompt.Add("Therefore, do not continue implementation until you compare the project in " + $ProjectArchiveName + " with the recovery sources in " + $BundleArchiveName + ".")
$prompt.Add("")
$prompt.Add("At the beginning, do not blindly overwrite files, reimplement existing work, or apply the same patch more than once.")
$prompt.Add("")
$prompt.Add("Proceed in this order:")
$prompt.Add("")
$prompt.Add("1. Inspect the contents of " + $BundleArchiveName + ".")
$prompt.Add("")
$prompt.Add("Pay particular attention to these resources when present:")
$prompt.Add("- HANDOFF.md")
$prompt.Add("- BUNDLE_MANIFEST.md")
$prompt.Add("- LAST_USER_PROMPT.md")
$prompt.Add("- PRIMARY_TASK_PROMPT.md")
$prompt.Add("- PROMPT_HISTORY.md")
$prompt.Add("- FEATURE_EVIDENCE.md")
$prompt.Add("- PROJECT_SCAN.md")
$prompt.Add("- PROJECT_ARCHIVE_OMISSIONS.md")
$prompt.Add("- SESSION_INDEX.md")
$prompt.Add("- PATCH_INDEX.md")
$prompt.Add("- EXTERNAL_WORKSPACES.md")
$prompt.Add("- transcripts/")
$prompt.Add("- sessions/")
$prompt.Add("- patches/")
$prompt.Add("- external_workspaces/")
$prompt.Add("- external_workspace_diffs/")
$prompt.Add("")
$prompt.Add("2. Compare the actual project contained in " + $ProjectArchiveName + " with all recovery sources in the handoff bundle.")
$prompt.Add("")
$prompt.Add("Specifically determine:")
$prompt.Add("- Whether external_workspaces/ contains a staging, worktree, scratch, temporary, or similar workspace that is more advanced than the main project.")
$prompt.Add("- Whether there are files missing from the main project or files whose recovered versions differ from the main project.")
$prompt.Add("- Whether an external-workspace version of the same file is newer or contains additional changes.")
$prompt.Add("- Whether patches/ contains apply_patch changes that were never applied to the main project.")
$prompt.Add("- Whether raw Codex session records contain file writes or modifications that were not separately recovered as patches.")
$prompt.Add("- Whether work that the previous AI appears to have completed exists only in a staging or external workspace.")
$prompt.Add("")
$prompt.Add("3. Reconstruct the actual final working state reached by the previous Codex session.")
$prompt.Add("")
$prompt.Add("A change being absent from " + $ProjectArchiveName + " does not prove that the previous AI never implemented it.")
$prompt.Add("Likewise, a change appearing in a session record or patch does not automatically mean it should be applied.")
$prompt.Add("Cross-check every recovered change against the main project, external workspaces, patch history, and session records.")
$prompt.Add("")
$prompt.Add("If an external workspace represents a more advanced state than the main project, safely integrate those changes into the project first.")
$prompt.Add("Before applying any recovered patch, verify that the same change was not already recovered through an external workspace or another source.")
$prompt.Add("")
$prompt.Add("4. Reconstruct the original user requests.")
$prompt.Add("")
$prompt.Add("Use PRIMARY_TASK_PROMPT.md, LAST_USER_PROMPT.md, PROMPT_HISTORY.md, and the relevant transcripts or raw session records.")
$prompt.Add("Classify every requested item as one of:")
$prompt.Add("- COMPLETED")
$prompt.Add("- PARTIALLY_COMPLETED")
$prompt.Add("- NOT_STARTED_OR_SKIPPED")
$prompt.Add("- UNCERTAIN")
$prompt.Add("")
$prompt.Add("FEATURE_EVIDENCE.md is only a discovery aid. NO_OBVIOUS_SIGNAL does not prove that a feature was not implemented, and an implementation signal does not prove that a feature is functionally complete.")
$prompt.Add("")
$prompt.Add("5. Before changing code, provide a concise recovery and status report using this structure:")
$prompt.Add("")
$prompt.Add("ORIGINAL TASK")
$prompt.Add("- What was the main task given to the previous Codex session?")
$prompt.Add("")
$prompt.Add("RECOVERED WORK")
$prompt.Add("- What changes were found outside the main project?")
$prompt.Add("- Were any external workspaces found?")
$prompt.Add("- How many differing or additional files were found?")
$prompt.Add("- How many patches were recovered?")
$prompt.Add("- What work was missing from the main project but recovered from the handoff sources?")
$prompt.Add("")
$prompt.Add("COMPLETED")
$prompt.Add("- ...")
$prompt.Add("")
$prompt.Add("PARTIALLY COMPLETED")
$prompt.Add("- ...")
$prompt.Add("")
$prompt.Add("NOT STARTED OR SKIPPED")
$prompt.Add("- ...")
$prompt.Add("")
$prompt.Add("UNCERTAIN")
$prompt.Add("- ...")
$prompt.Add("")
$prompt.Add("CURRENT SOURCE OF TRUTH")
$prompt.Add("- Which working tree or combination of sources do you consider the most advanced state, and why?")
$prompt.Add("- How did you resolve differences between the project archive, external workspaces, recovered patches, and session history?")
$prompt.Add("")
$prompt.Add("NEXT STEPS")
$prompt.Add("1. ...")
$prompt.Add("2. ...")
$prompt.Add("3. ...")
$prompt.Add("")
$prompt.Add("6. After the recovery/status analysis, continue the implementation from the recovered state without waiting for additional confirmation.")
$prompt.Add("")
$prompt.Add("Rules:")
$prompt.Add("- Do not rewrite working implementation without a concrete reason.")
$prompt.Add("- Do not redo work that the previous AI already completed.")
$prompt.Add("- Do not lose staging or worktree changes.")
$prompt.Add("- Never apply the same patch twice.")
$prompt.Add("- Complete missing requested items.")
$prompt.Add("- Finish partially completed items.")
$prompt.Add("- Run appropriate build, lint, type-check, tests, or project-specific validation when needed.")
$prompt.Add("- If dependency, cache, build-output, generated, or other directories are absent from the project ZIP, do not automatically treat their absence as source-code loss. Recreate them from manifests, lock files, build instructions, or the project toolchain when appropriate.")
$prompt.Add("- Do not modify lock files without a concrete reason.")
$prompt.Add("- Do not introduce large architectural changes unless the original task requires them.")
$prompt.Add("- If evidence is insufficient, do not guess. Mark the item UNCERTAIN and verify it from available recovery sources.")
$prompt.Add("- Do not load all raw session files into context unnecessarily. Start with summaries, transcripts, indexes, and targeted evidence. Consult only the relevant raw session sections when more forensic detail is required.")
$prompt.Add("")
$prompt.Add("The goal is not merely to make the project build or run. The goal is to recover the most advanced development state left by the previous Codex session as completely as possible, preserve already completed work, and then finish the remaining items from the original task list.")

$outputDirectory = Split-Path -Parent $OutputPath

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

[System.IO.File]::WriteAllLines($OutputPath, $prompt.ToArray(), $Utf8Bom)

Write-Host ""
Write-Host "Prompt generated." -ForegroundColor Green
Write-Host ("Project archive: " + $ProjectArchiveName) -ForegroundColor Cyan
Write-Host ("Project archive similarity: " + $ProjectArchiveSimilarity) -ForegroundColor DarkGray
Write-Host ("Bundle archive: " + $BundleArchiveName) -ForegroundColor Cyan
Write-Host ("Whole omitted items: " + $omission.WholeMissingItems.Count) -ForegroundColor DarkGray
Write-Host ("Missing individual files: " + $omission.MissingFiles.Count) -ForegroundColor DarkGray
Write-Host ""
Write-Host $OutputPath -ForegroundColor Yellow