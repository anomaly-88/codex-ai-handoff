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
$script:IntegrityExpectedLength = "0000041146"
$script:IntegrityExpectedSha256 = "B24CEC3429FEFF1E0743D64A89BB2104677E0F52F5B8EAAABA1CB2948F83B666"

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


if ($script:PromptLanguage -eq "en") {
    $SiblingGenerator = Join-Path -Path $PSScriptRoot -ChildPath "codex-handoff-prompt-generator-en.ps1"

    if (Test-Path -LiteralPath $SiblingGenerator -PathType Leaf) {
        try {
            & $SiblingGenerator -ProjectPath $ProjectPath -ProjectArchivePath $ProjectArchivePath -BundlePath $BundlePath -BundleArchivePath $BundleArchivePath -OutputPath $OutputPath

            if (-not $?) {
                throw "English prompt generator reported failure."
            }

            return
        }
        catch {
            throw ("English prompt generator failed: " + $_.Exception.Message)
        }
    }

    Write-Warning "promptLanguage is 'en' but codex-handoff-prompt-generator-en.ps1 was not found. Continuing with the Turkish generator."
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
        $OutputPath = Join-Path -Path $BundlePath -ChildPath "AI_CONTINUATION_PROMPT.txt"
    }
    else {
        $projectArchiveDirectory = Split-Path -Parent $ProjectArchivePath
        $OutputPath = Join-Path -Path $projectArchiveDirectory -ChildPath "AI_CONTINUATION_PROMPT.txt"
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

$prompt.Add("Bu projeyi baska bir Codex/AI oturumundan devraliyorsun. Onceki calisma kullanim/kredi siniri, kesinti veya oturumun sona ermesi nedeniyle yarida kalmis olabilir.")
$prompt.Add("")
$prompt.Add("Sana en az iki ana arsiv veriliyor:")
$prompt.Add("")
$prompt.Add("- " + $ProjectArchiveName + ": Ana proje kaynak kodu arsivi.")
$prompt.Add("- " + $BundleArchiveName + ": Onceki Codex oturumlarindan uretilmis handoff/recovery paketi.")
$prompt.Add("")

if ($omission.WholeMissingItems.Count -gt 0 -or $omission.MissingFiles.Count -gt 0) {
    $prompt.Add("ONEMLI - PROJE ZIP'I TAM BIR DISK KOPYASI DEGILDIR.")
    $prompt.Add("")
    $prompt.Add("Script, proje klasoru ile " + $ProjectArchiveName + " arsivini karsilastirdi ve ZIP icinde bulunmayan bazi dosya/klasorler tespit etti.")
    $prompt.Add("Bunlar silinmis kabul edilmemelidir. Arsive bilincli veya bilincli olmadan dahil edilmemis olabilir.")
    $prompt.Add("")

    if ($omission.WholeMissingItems.Count -gt 0) {
        $prompt.Add("Tamamen ZIP disinda kalan ust seviye oge(ler):")

        foreach ($item in $omission.WholeMissingItems) {
            $prompt.Add("- " + $item)
        }

        $prompt.Add("")
    }

    if ($omission.MissingFiles.Count -gt 0) {
        $previewCount = [Math]::Min(20, $omission.MissingFiles.Count)
        $prompt.Add("Ayrica dahil edilen klasorlerin icinde ZIP'te bulunmayan " + $omission.MissingFiles.Count + " dosya tespit edildi.")

        for ($i = 0; $i -lt $previewCount; $i = $i + 1) {
            $prompt.Add("- " + $omission.MissingFiles[$i])
        }

        if ($omission.MissingFiles.Count -gt $previewCount) {
            $prompt.Add("- ... daha fazla dosya var.")
        }

        $prompt.Add("")
    }

    $prompt.Add("Ayrintili liste handoff paketindeki PROJECT_ARCHIVE_OMISSIONS.md dosyasinda bulunur.")
    $prompt.Add("")
}

$prompt.Add("KRITIK: " + $ProjectArchiveName + " icindeki ana proje klasorunun onceki Codex'in ulastigi en guncel kod oldugunu varsayma.")
$prompt.Add("")
$prompt.Add("Codex ana proje klasoru disinda staging, worktree, scratch, temp, backup veya baska bir harici calisma alaninda degisiklik birakmis olabilir. Bu degisiklikler ana proje arsivine aktarilmadan oturum sona ermis olabilir.")
$prompt.Add("")
$prompt.Add("Bu nedenle " + $BundleArchiveName + " icindeki recovery kaynaklarini gercek proje ile karsilastirmadan gelistirmeye devam etme.")
$prompt.Add("")
$prompt.Add("Ilk asamada hicbir seyi korlemesine overwrite etme, yeniden implement etme veya ayni patch'i iki kez uygulama.")
$prompt.Add("")
$prompt.Add("Su sirayla ilerle:")
$prompt.Add("")
$prompt.Add("1. " + $BundleArchiveName + " icerigini incele.")
$prompt.Add("")
$prompt.Add("Ozellikle varsa su kaynaklara bak:")
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
$prompt.Add("2. " + $ProjectArchiveName + " icindeki gercek proje ile handoff paketindeki tum recovery kaynaklarini karsilastir.")
$prompt.Add("")
$prompt.Add("Ozellikle:")
$prompt.Add("- external_workspaces/ altinda ana projeden daha guncel staging/worktree/scratch benzeri bir calisma agaci var mi?")
$prompt.Add("- Ana projede bulunmayan veya farkli olan dosyalar var mi?")
$prompt.Add("- Ayni dosyanin external workspace surumu daha yeni veya icerik olarak farkli mi?")
$prompt.Add("- patches/ altinda ana projeye uygulanmamis apply_patch degisiklikleri var mi?")
$prompt.Add("- Raw Codex session kayitlarinda patch olarak ayrica cikartilmamis dosya yazma/degistirme islemleri var mi?")
$prompt.Add("- Onceki AI'in tamamladigini dusundugu fakat yalnizca staging alaninda kalan degisiklikler var mi?")
$prompt.Add("")
$prompt.Add("3. Onceki Codex'in gercek son calisma durumunu yeniden olustur.")
$prompt.Add("")
$prompt.Add("Bir degisikligin sadece " + $ProjectArchiveName + " icinde olmamasi onun yapilmadigi anlamina gelmez.")
$prompt.Add("Bir degisikligin session veya patch icinde bulunmasi da otomatik olarak uygulanmasi gerektigi anlamina gelmez.")
$prompt.Add("Her degisikligi ana proje, external workspace, patch gecmisi ve session kayitlariyla capraz dogrula.")
$prompt.Add("")
$prompt.Add("External workspace ana projeden daha ileri bir durumdaysa once oradaki degisiklikleri guvenli sekilde ana projeye entegre et.")
$prompt.Add("Patch'leri uygularken ayni degisikligin external workspace uzerinden zaten gelmis olup olmadigini kontrol et.")
$prompt.Add("")
$prompt.Add("4. Ardindan orijinal kullanici taleplerini yeniden cikar.")
$prompt.Add("")
$prompt.Add("PRIMARY_TASK_PROMPT.md, LAST_USER_PROMPT.md, PROMPT_HISTORY.md ve ilgili transcript/session kayitlarini kullan.")
$prompt.Add("Her talep maddesini su durumlardan biriyle siniflandir:")
$prompt.Add("- COMPLETED")
$prompt.Add("- PARTIALLY_COMPLETED")
$prompt.Add("- NOT_STARTED_OR_SKIPPED")
$prompt.Add("- UNCERTAIN")
$prompt.Add("")
$prompt.Add("FEATURE_EVIDENCE.md yalnizca kesif sinyalidir. NO_OBVIOUS_SIGNAL, ozelligin kesinlikle yapilmadigi anlamina gelmez. Implementation sinyali bulunmasi da ozelligin tamamlandigini kanitlamaz.")
$prompt.Add("")
$prompt.Add("5. Kod degistirmeden once kisa bir durum raporu ver:")
$prompt.Add("")
$prompt.Add("ORIGINAL TASK")
$prompt.Add("- Onceki Codex'e verilen ana gorev neydi?")
$prompt.Add("")
$prompt.Add("RECOVERED WORK")
$prompt.Add("- Ana proje disinda hangi degisiklikler bulundu?")
$prompt.Add("- External workspace bulundu mu?")
$prompt.Add("- Kac farkli/degismis dosya vardi?")
$prompt.Add("- Kac patch bulundu?")
$prompt.Add("- Ana projede eksik olup recovery kaynaklarindan geri kazanilan neler var?")
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
$prompt.Add("- Hangi calisma agacini neden en guncel kaynak kabul ettin?")
$prompt.Add("- Proje arsivi, external workspace ve patch gecmisi arasinda nasil karar verdin?")
$prompt.Add("")
$prompt.Add("NEXT STEPS")
$prompt.Add("1. ...")
$prompt.Add("2. ...")
$prompt.Add("3. ...")
$prompt.Add("")
$prompt.Add("6. Bu durum analizinden sonra ayrica onay beklemeden gelistirmeye kaldigi yerden devam et.")
$prompt.Add("")
$prompt.Add("Kurallar:")
$prompt.Add("- Mevcut calisan implementasyonu gereksiz yere bastan yazma.")
$prompt.Add("- Onceki AI'in tamamladigi isleri yeniden yapma.")
$prompt.Add("- Staging/worktree degisikliklerini kaybetme.")
$prompt.Add("- Ayni patch'i iki kez uygulama.")
$prompt.Add("- Eksik olan maddeleri tamamla.")
$prompt.Add("- Kismi maddeleri tamamla.")
$prompt.Add("- Gerekirse build, lint, type-check ve proje yapisina uygun testleri calistir.")
$prompt.Add("- Proje ZIP'inde yer almayan dependency/cache/build klasorleri varsa bunlarin arsivde olmamasini kaynak kod kaybi olarak yorumlama; gerekiyorsa manifest/lock dosyalarindan yeniden olustur.")
$prompt.Add("- Lock dosyalarini sebepsiz yere degistirme.")
$prompt.Add("- Kullanici istemedikce buyuk mimari degisikliklere girisme.")
$prompt.Add("- Kanit yoksa varsayim yapma; UNCERTAIN olarak isaretle ve kaynaklardan dogrulamaya calis.")
$prompt.Add("- Raw session dosyalarini bastan sona gereksiz yere context'e yukleme. Once ozet, transcript ve index dosyalarini kullan; yalnizca ihtiyac halinde ilgili raw session bolumune basvur.")
$prompt.Add("")
$prompt.Add("Amac yalnizca projeyi calisir hale getirmek degil; onceki Codex'in biraktigi en ileri calisma durumunu mumkun oldugunca eksiksiz geri kazanmak ve ardindan orijinal gorev listesindeki kalan isleri tamamlamaktir.")

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