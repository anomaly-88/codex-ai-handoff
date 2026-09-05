# Aykan Akduman Tarafından Tasarlandı
# Designed by Aykan Akduman
# Integrity protected. Removing the credit or modifying this script invalidates the integrity check.
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectPath,

    [string]$BundlePath = "",

    [int]$RecentFileCount = 100,

    [int]$BurstMinutes = 90,

    [int]$PromptWindow = 8,

    [int]$MaxMarkerResults = 300,

    [int]$MaxDiffRows = 500
)

$script:IntegrityCreditTr = "Aykan Akduman Tarafından Tasarlandı"
$script:IntegrityCreditEn = "Designed by Aykan Akduman"
$script:IntegrityExpectedLength = "0000095133"
$script:IntegrityExpectedSha256 = "F29B12AD52F9055F24427AB8C626BFF73B6D6BDCDC943E5BFF8D7F0877CC6D04"

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

    $candidate = Normalize-PathSimple -Value $CandidatePath
    $scriptRoot = Normalize-PathSimple -Value $PSScriptRoot

    if ([string]::IsNullOrWhiteSpace($candidate) -or [string]::IsNullOrWhiteSpace($scriptRoot)) {
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


function Normalize-PathSimple {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }

    try {
        return ([System.IO.Path]::GetFullPath($Value)).TrimEnd("\", "/").ToLowerInvariant()
    }
    catch {
        return $Value.TrimEnd("\", "/").ToLowerInvariant()
    }
}

function Test-PathInside {
    param(
        [string]$Child,
        [string]$Parent
    )

    $c = Normalize-PathSimple -Value $Child
    $p = Normalize-PathSimple -Value $Parent

    if ([string]::IsNullOrWhiteSpace($c) -or [string]::IsNullOrWhiteSpace($p)) {
        return $false
    }

    if ($c -eq $p) {
        return $true
    }

    return ($c + "\").StartsWith($p + "\")
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

function Limit-TextSimple {
    param(
        [string]$Text,
        [int]$MaxLength
    )

    if ($null -eq $Text) {
        return ""
    }

    $value = [string]$Text

    if ($value.Length -le $MaxLength) {
        return $value
    }

    return $value.Substring(0, $MaxLength) + "..."
}

function Escape-MarkdownCell {
    param([string]$Text)

    if ($null -eq $Text) {
        return ""
    }

    $value = [string]$Text
    $value = $value.Replace("|", "\|")
    $value = $value.Replace([string][char]13, " ")
    $value = $value.Replace([string][char]10, " ")
    return $value
}

function Add-TextLines {
    param(
        [System.Collections.Generic.List[string]]$Target,
        [string]$Text
    )

    if ($null -eq $Text) {
        return
    }

    $normalized = ([string]$Text).Replace([string][char]13, "")
    $parts = $normalized.Split([char]10)

    foreach ($part in $parts) {
        $Target.Add($part)
    }
}

function Get-FilteredProjectFiles {
    param(
        [string]$Root,
        [int]$Limit = 0
    )

    $result = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Root)

    while ($stack.Count -gt 0) {
        if ($Limit -gt 0 -and $result.Count -ge $Limit) {
            break
        }

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

                $result.Add($item)

                if ($Limit -gt 0 -and $result.Count -ge $Limit) {
                    break
                }
            }
        }
    }

    return $result
}

function Get-TextFileList {
    param([System.Collections.IEnumerable]$Files)

    $extensions = @(
        ".php", ".phtml", ".inc",
        ".rs", ".toml", ".tsx", ".ts", ".jsx", ".js", ".mjs", ".cjs",
        ".json", ".md", ".css", ".scss", ".sass", ".less", ".html", ".htm",
        ".cs", ".csproj", ".fs", ".fsproj", ".vb", ".sln", ".xml",
        ".yml", ".yaml", ".py", ".ps1", ".psm1", ".bat", ".cmd", ".sql",
        ".java", ".kt", ".kts", ".go", ".cpp", ".cc", ".c", ".h", ".hpp",
        ".vue", ".svelte", ".env", ".ini", ".cfg", ".conf", ".txt", ".sh"
    )

    $specialNames = @(
        "Dockerfile",
        "Makefile",
        "Rakefile",
        "Gemfile",
        "Procfile"
    )

    return @(
        $Files |
        Where-Object {
            ($extensions -contains $_.Extension.ToLowerInvariant()) -or
            ($specialNames -contains $_.Name)
        } |
        Where-Object {
            $_.Length -lt 5242880
        }
    )
}

function Get-TextLikeRelativeSample {
    param(
        [string]$Root,
        [int]$Limit = 250
    )

    $extensions = @(
        ".php", ".phtml", ".inc", ".html", ".htm", ".css", ".scss", ".sass",
        ".js", ".jsx", ".ts", ".tsx", ".json", ".md", ".xml", ".yml", ".yaml",
        ".cs", ".csproj", ".rs", ".toml", ".py", ".java", ".kt", ".go",
        ".c", ".cc", ".cpp", ".h", ".hpp", ".vue", ".svelte", ".sql"
    )

    $files = Get-FilteredProjectFiles -Root $Root -Limit 1500
    $result = New-Object System.Collections.Generic.List[string]

    foreach ($file in $files) {
        if ($extensions -contains $file.Extension.ToLowerInvariant()) {
            $relative = Get-RelativePathSimple -Root $Root -FullPath $file.FullName
            $result.Add($relative)

            if ($result.Count -ge $Limit) {
                break
            }
        }
    }

    return $result
}

function Get-StructuralSimilarity {
    param(
        [string]$ProjectRoot,
        [string]$CandidateRoot
    )

    $sample = Get-TextLikeRelativeSample -Root $ProjectRoot -Limit 250

    if ($sample.Count -eq 0) {
        return 0.0
    }

    $matches = 0

    foreach ($relative in $sample) {
        if (Test-Path -LiteralPath (Join-Path $CandidateRoot $relative) -PathType Leaf) {
            $matches = $matches + 1
        }
    }

    return [Math]::Round(($matches / [double]$sample.Count), 3)
}

function Resolve-CandidateCompareRoot {
    param(
        [string]$ProjectRoot,
        [string]$CandidateRoot,
        [string]$ProjectName
    )

    $bestRoot = $CandidateRoot
    $bestSimilarity = Get-StructuralSimilarity -ProjectRoot $ProjectRoot -CandidateRoot $CandidateRoot

    $level1 = @(
        Get-ChildItem -LiteralPath $CandidateRoot -Force -Directory -ErrorAction SilentlyContinue |
        Select-Object -First 30
    )

    foreach ($child in $level1) {
        if (Test-IsExcludedFolderName -Name $child.Name) {
            continue
        }

        $similarity = Get-StructuralSimilarity -ProjectRoot $ProjectRoot -CandidateRoot $child.FullName

        if ($similarity -gt $bestSimilarity) {
            $bestSimilarity = $similarity
            $bestRoot = $child.FullName
        }

        if ($child.Name -eq $ProjectName -and $similarity -ge $bestSimilarity) {
            $bestSimilarity = $similarity
            $bestRoot = $child.FullName
        }

        $level2 = @(
            Get-ChildItem -LiteralPath $child.FullName -Force -Directory -ErrorAction SilentlyContinue |
            Select-Object -First 20
        )

        foreach ($grandchild in $level2) {
            if (Test-IsExcludedFolderName -Name $grandchild.Name) {
                continue
            }

            $similarity2 = Get-StructuralSimilarity -ProjectRoot $ProjectRoot -CandidateRoot $grandchild.FullName

            if ($similarity2 -gt $bestSimilarity) {
                $bestSimilarity = $similarity2
                $bestRoot = $grandchild.FullName
            }
        }
    }

    return [PSCustomObject]@{
        Root = $bestRoot
        Similarity = $bestSimilarity
    }
}

function Get-NewestFilteredFileTime {
    param([string]$Root)

    $files = Get-FilteredProjectFiles -Root $Root -Limit 3000

    if ($files.Count -eq 0) {
        return $null
    }

    return ($files | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime
}

function Get-ContentItemText {
    param([object]$Content)

    $parts = New-Object System.Collections.Generic.List[string]

    if ($null -eq $Content) {
        return ""
    }

    if ($Content -is [string]) {
        return [string]$Content
    }

    if ($Content -is [System.Collections.IEnumerable]) {
        foreach ($item in $Content) {
            if ($null -eq $item) {
                continue
            }

            if ($item -is [string]) {
                if (-not [string]::IsNullOrWhiteSpace([string]$item)) {
                    $parts.Add([string]$item)
                }

                continue
            }

            foreach ($name in @("text", "input_text", "output_text", "message")) {
                $prop = $item.PSObject.Properties[$name]

                if ($null -ne $prop) {
                    $value = [string]$prop.Value

                    if (-not [string]::IsNullOrWhiteSpace($value)) {
                        $parts.Add($value)
                        break
                    }
                }
            }
        }

        return ($parts -join [Environment]::NewLine)
    }

    foreach ($name in @("text", "input_text", "output_text", "message")) {
        $prop = $Content.PSObject.Properties[$name]

        if ($null -ne $prop) {
            return [string]$prop.Value
        }
    }

    return ""
}

function Test-MeaningfulUserText {
    param([string]$Text)

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    $value = $Text.Trim()

    if ($value.Length -lt 2) {
        return $false
    }

    $ignoredPrefixes = @(
        "# AGENTS.md instructions",
        "<environment_context>",
        "<developer_instructions>",
        "<system_instructions>",
        "<permissions instructions>",
        "<permissions_instructions>"
    )

    foreach ($prefix in $ignoredPrefixes) {
        if ($value.StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $false
        }
    }

    return $true
}

function Get-CodexSessionMeta {
    param([string]$Path)

    $cwd = ""
    $sessionId = ""
    $created = ""
    $source = ""
    $cliVersion = ""

    try {
        $count = 0

        foreach ($line in [System.IO.File]::ReadLines($Path)) {
            $count = $count + 1

            if ([string]::IsNullOrWhiteSpace($line)) {
                if ($count -ge 40) {
                    break
                }

                continue
            }

            try {
                $obj = $line | ConvertFrom-Json
            }
            catch {
                if ($count -ge 40) {
                    break
                }

                continue
            }

            if ([string]$obj.type -eq "session_meta") {
                $payload = $obj.payload

                if ($null -ne $payload) {
                    if ($null -ne $payload.PSObject.Properties["cwd"]) {
                        $cwd = [string]$payload.cwd
                    }

                    if ($null -ne $payload.PSObject.Properties["session_id"]) {
                        $sessionId = [string]$payload.session_id
                    }
                    elseif ($null -ne $payload.PSObject.Properties["id"]) {
                        $sessionId = [string]$payload.id
                    }

                    if ($null -ne $payload.PSObject.Properties["timestamp"]) {
                        $created = [string]$payload.timestamp
                    }

                    if ($null -ne $payload.PSObject.Properties["source"]) {
                        $source = [string]$payload.source
                    }

                    if ($null -ne $payload.PSObject.Properties["cli_version"]) {
                        $cliVersion = [string]$payload.cli_version
                    }
                }

                break
            }

            if ($count -ge 40) {
                break
            }
        }
    }
    catch {
    }

    return [PSCustomObject]@{
        Path = $Path
        Cwd = $cwd
        SessionId = $sessionId
        Created = $created
        Source = $source
        CliVersion = $cliVersion
    }
}

function Get-CodexSessionDetails {
    param([string]$Path)

    $messages = New-Object System.Collections.Generic.List[object]
    $commands = New-Object System.Collections.Generic.List[object]
    $goals = New-Object System.Collections.Generic.List[string]
    $cwd = ""
    $sessionId = ""
    $created = ""
    $source = ""
    $cliVersion = ""
    $sequence = 0

    try {
        foreach ($line in [System.IO.File]::ReadLines($Path)) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }

            try {
                $obj = $line | ConvertFrom-Json
            }
            catch {
                continue
            }

            $sequence = $sequence + 1
            $timestamp = ""

            if ($null -ne $obj.PSObject.Properties["timestamp"]) {
                $timestamp = [string]$obj.timestamp
            }

            $recordType = [string]$obj.type
            $payload = $obj.payload

            if ($recordType -eq "session_meta") {
                if ($null -ne $payload) {
                    if ($null -ne $payload.PSObject.Properties["cwd"]) {
                        $cwd = [string]$payload.cwd
                    }

                    if ($null -ne $payload.PSObject.Properties["session_id"]) {
                        $sessionId = [string]$payload.session_id
                    }
                    elseif ($null -ne $payload.PSObject.Properties["id"]) {
                        $sessionId = [string]$payload.id
                    }

                    if ($null -ne $payload.PSObject.Properties["timestamp"]) {
                        $created = [string]$payload.timestamp
                    }

                    if ($null -ne $payload.PSObject.Properties["source"]) {
                        $source = [string]$payload.source
                    }

                    if ($null -ne $payload.PSObject.Properties["cli_version"]) {
                        $cliVersion = [string]$payload.cli_version
                    }
                }

                continue
            }

            if ($recordType -eq "event_msg" -and $null -ne $payload) {
                $payloadType = [string]$payload.type

                if ($payloadType -eq "user_message") {
                    $text = ""

                    if ($null -ne $payload.PSObject.Properties["message"]) {
                        $text = [string]$payload.message
                    }

                    if (Test-MeaningfulUserText -Text $text) {
                        $messages.Add(
                            [PSCustomObject]@{
                                Sequence = $sequence
                                Timestamp = $timestamp
                                Role = "user"
                                Text = $text
                                Source = "event_msg.user_message"
                            }
                        )
                    }

                    continue
                }

                if ($payloadType -eq "agent_message") {
                    $text = ""

                    if ($null -ne $payload.PSObject.Properties["message"]) {
                        $text = [string]$payload.message
                    }

                    if (-not [string]::IsNullOrWhiteSpace($text)) {
                        $messages.Add(
                            [PSCustomObject]@{
                                Sequence = $sequence
                                Timestamp = $timestamp
                                Role = "assistant"
                                Text = $text
                                Source = "event_msg.agent_message"
                            }
                        )
                    }

                    continue
                }

                if ($payloadType -eq "exec_command_end") {
                    $commandText = ""

                    if ($null -ne $payload.PSObject.Properties["command"]) {
                        if ($payload.command -is [System.Collections.IEnumerable] -and -not ($payload.command -is [string])) {
                            $commandText = ($payload.command | ForEach-Object { [string]$_ }) -join " "
                        }
                        else {
                            $commandText = [string]$payload.command
                        }
                    }

                    if (-not [string]::IsNullOrWhiteSpace($commandText)) {
                        $exitCodeValue = ""

                        if ($null -ne $payload.PSObject.Properties["exit_code"]) {
                            $exitCodeValue = [string]$payload.exit_code
                        }

                        $commands.Add(
                            [PSCustomObject]@{
                                Sequence = $sequence
                                Timestamp = $timestamp
                                Command = $commandText
                                ExitCode = $exitCodeValue
                            }
                        )
                    }
                }

                $goalProp = $payload.PSObject.Properties["goal"]

                if ($null -ne $goalProp -and $null -ne $goalProp.Value) {
                    $goalObject = $goalProp.Value
                    $objectiveProp = $goalObject.PSObject.Properties["objective"]

                    if ($null -ne $objectiveProp) {
                        $objectiveText = [string]$objectiveProp.Value

                        if (-not [string]::IsNullOrWhiteSpace($objectiveText)) {
                            if (-not ($goals -contains $objectiveText)) {
                                $goals.Add($objectiveText)
                            }
                        }
                    }
                }

                continue
            }

            if ($recordType -eq "response_item" -and $null -ne $payload) {
                $payloadType = [string]$payload.type

                if ($payloadType -eq "message") {
                    $role = [string]$payload.role
                    $text = ""

                    if ($null -ne $payload.PSObject.Properties["content"]) {
                        $text = Get-ContentItemText -Content $payload.content
                    }

                    if ($role -eq "user") {
                        if (Test-MeaningfulUserText -Text $text) {
                            $messages.Add(
                                [PSCustomObject]@{
                                    Sequence = $sequence
                                    Timestamp = $timestamp
                                    Role = "user"
                                    Text = $text
                                    Source = "response_item.message"
                                }
                            )
                        }
                    }
                    elseif ($role -eq "assistant") {
                        if (-not [string]::IsNullOrWhiteSpace($text)) {
                            $messages.Add(
                                [PSCustomObject]@{
                                    Sequence = $sequence
                                    Timestamp = $timestamp
                                    Role = "assistant"
                                    Text = $text
                                    Source = "response_item.message"
                                }
                            )
                        }
                    }
                }
            }
        }
    }
    catch {
    }

    $deduped = New-Object System.Collections.Generic.List[object]
    $lastKey = ""

    foreach ($message in ($messages | Sort-Object Sequence)) {
        $key = $message.Role + "|" + $message.Text.Trim()

        if ($key -ne $lastKey) {
            $deduped.Add($message)
            $lastKey = $key
        }
    }

    return [PSCustomObject]@{
        Path = $Path
        Cwd = $cwd
        SessionId = $sessionId
        Created = $created
        Source = $source
        CliVersion = $cliVersion
        Messages = $deduped
        Commands = $commands
        GoalObjectives = $goals
    }
}

function Get-FeatureLines {
    param([string]$PromptText)

    $items = New-Object System.Collections.Generic.List[string]

    if ([string]::IsNullOrWhiteSpace($PromptText)) {
        return $items
    }

    $normalized = $PromptText.Replace([string][char]13, "")
    $lines = $normalized.Split([char]10)

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        $match = [System.Text.RegularExpressions.Regex]::Match(
            $trimmed,
            "^(?:[-*+]|\d+[.)]|[A-Za-z][.)])\s+(.+)$"
        )

        if ($match.Success) {
            $value = $match.Groups[1].Value.Trim()

            if ($value.Length -ge 4) {
                $items.Add($value)
            }
        }
    }

    if ($items.Count -eq 0 -and $PromptText.Trim().Length -ge 20) {
        $items.Add($PromptText.Trim())
    }

    return $items
}

function Get-SearchTokens {
    param(
        [string]$Text,
        [int]$MaxTokens = 6
    )

    $stopWords = @(
        "this", "that", "with", "from", "then", "than", "when", "where",
        "what", "which", "there", "their", "should", "would", "could",
        "have", "has", "will", "into", "also", "only", "make", "made",
        "icin", "gibi", "olan", "olarak", "bunu", "buna", "daha", "sonra",
        "olsun", "yapilsin", "tarafinda", "tarafi", "ekle", "eklenmeli",
        "bence", "mesela", "ancak", "falan", "veya", "yani"
    )

    $tokens = New-Object System.Collections.Generic.List[string]
    $matches = [System.Text.RegularExpressions.Regex]::Matches(
        $Text.ToLowerInvariant(),
        "[\p{L}\p{Nd}_-]{4,}"
    )

    foreach ($match in $matches) {
        $token = $match.Value

        if ($stopWords -contains $token) {
            continue
        }

        if (-not ($tokens -contains $token)) {
            $tokens.Add($token)
        }

        if ($tokens.Count -ge $MaxTokens) {
            break
        }
    }

    return $tokens
}

function Find-FeatureEvidence {
    param(
        [string]$Feature,
        [System.Collections.IEnumerable]$RecentCandidateFiles,
        [System.Collections.IEnumerable]$AllCandidateFiles,
        [string]$Root
    )

    $tokens = Get-SearchTokens -Text $Feature -MaxTokens 6
    $recentHits = New-Object System.Collections.Generic.List[string]
    $generalHits = New-Object System.Collections.Generic.List[string]

    if ($tokens.Count -eq 0) {
        return [PSCustomObject]@{
            Signal = "UNKNOWN"
            Tokens = @()
            RecentHits = @()
            GeneralHits = @()
        }
    }

    foreach ($file in $RecentCandidateFiles) {
        if ($recentHits.Count -ge 8) {
            break
        }

        foreach ($token in $tokens) {
            try {
                $hit = Select-String -LiteralPath $file.FullName -Pattern $token -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1

                if ($null -ne $hit) {
                    $entry = (Get-RelativePathSimple -Root $Root -FullPath $file.FullName) + ":" + $hit.LineNumber + " -> " + (Limit-TextSimple -Text $hit.Line.Trim() -MaxLength 180)

                    if (-not ($recentHits -contains $entry)) {
                        $recentHits.Add($entry)
                    }

                    break
                }
            }
            catch {
            }
        }
    }

    foreach ($file in $AllCandidateFiles) {
        if ($generalHits.Count -ge 6) {
            break
        }

        foreach ($token in $tokens) {
            try {
                $hit = Select-String -LiteralPath $file.FullName -Pattern $token -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1

                if ($null -ne $hit) {
                    $entry = (Get-RelativePathSimple -Root $Root -FullPath $file.FullName) + ":" + $hit.LineNumber + " -> " + (Limit-TextSimple -Text $hit.Line.Trim() -MaxLength 180)

                    if (-not ($generalHits -contains $entry)) {
                        $generalHits.Add($entry)
                    }

                    break
                }
            }
            catch {
            }
        }
    }

    $signal = "NO_OBVIOUS_SIGNAL"

    if ($recentHits.Count -ge 2) {
        $signal = "STRONG_RECENT_IMPLEMENTATION_SIGNAL"
    }
    elseif ($recentHits.Count -eq 1) {
        $signal = "WEAK_RECENT_IMPLEMENTATION_SIGNAL"
    }
    elseif ($generalHits.Count -gt 0) {
        $signal = "EXISTING_CODE_SIGNAL_ONLY"
    }

    return [PSCustomObject]@{
        Signal = $signal
        Tokens = $tokens
        RecentHits = $recentHits
        GeneralHits = $generalHits
    }
}

function Test-SessionMentionsCandidate {
    param(
        [System.Collections.IEnumerable]$SessionFiles,
        [string]$CandidatePath,
        [string]$CandidateName
    )

    foreach ($session in $SessionFiles) {
        try {
            if (Select-String -LiteralPath $session.FullName -Pattern $CandidateName -SimpleMatch -Quiet -ErrorAction SilentlyContinue) {
                return $true
            }

            $escapedPath = $CandidatePath.Replace("\", "\\")

            if (Select-String -LiteralPath $session.FullName -Pattern $escapedPath -SimpleMatch -Quiet -ErrorAction SilentlyContinue) {
                return $true
            }
        }
        catch {
        }
    }

    return $false
}

function Get-SafeFolderName {
    param([string]$Name)

    $invalid = [System.IO.Path]::GetInvalidFileNameChars()
    $value = $Name

    foreach ($char in $invalid) {
        $value = $value.Replace([string]$char, "_")
    }

    if ([string]::IsNullOrWhiteSpace($value)) {
        return "external_workspace"
    }

    return $value
}

function Copy-DirectoryComplete {
    param(
        [string]$SourceRoot,
        [string]$DestinationRoot
    )

    $destinationParent = Split-Path -Parent $DestinationRoot

    if (-not (Test-Path -LiteralPath $destinationParent)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }

    $tempDestination = $DestinationRoot + ".copying"

    if (Test-Path -LiteralPath $tempDestination) {
        Remove-Item -LiteralPath $tempDestination -Recurse -Force
    }

    if (Test-Path -LiteralPath $DestinationRoot) {
        Remove-Item -LiteralPath $DestinationRoot -Recurse -Force
    }

    $robocopy = Get-Command robocopy.exe -ErrorAction SilentlyContinue

    if ($null -ne $robocopy) {
        New-Item -ItemType Directory -Path $tempDestination -Force | Out-Null

        $robocopyArgs = @(
            $SourceRoot,
            $tempDestination,
            "/E",
            "/COPY:DAT",
            "/DCOPY:T",
            "/R:1",
            "/W:1",
            "/XJ",
            "/NFL",
            "/NDL",
            "/NJH",
            "/NJS",
            "/NP"
        )

        if ($script:ExcludedFolderNames.Count -gt 0) {
            $robocopyArgs += "/XD"

            foreach ($folderPattern in $script:ExcludedFolderNames) {
                if (-not [string]::IsNullOrWhiteSpace([string]$folderPattern)) {
                    $robocopyArgs += [string]$folderPattern
                }
            }
        }

        if ($script:ExcludedFileNames.Count -gt 0) {
            $robocopyArgs += "/XF"

            foreach ($filePattern in $script:ExcludedFileNames) {
                if (-not [string]::IsNullOrWhiteSpace([string]$filePattern)) {
                    $robocopyArgs += [string]$filePattern
                }
            }
        }

        & $robocopy.Source @robocopyArgs | Out-Null
        $code = $LASTEXITCODE

        if ($code -le 7) {
            Move-Item -LiteralPath $tempDestination -Destination $DestinationRoot
            return [PSCustomObject]@{
                Success = $true
                Method = "robocopy"
                ExitCode = $code
                Error = ""
            }
        }

        if (Test-Path -LiteralPath $tempDestination) {
            Remove-Item -LiteralPath $tempDestination -Recurse -Force
        }

        return [PSCustomObject]@{
            Success = $false
            Method = "robocopy"
            ExitCode = $code
            Error = "Robocopy failed. Partial copy removed."
        }
    }

    try {
        New-Item -ItemType Directory -Path $tempDestination -Force | Out-Null

        $stack = New-Object System.Collections.Generic.Stack[object]
        $stack.Push(
            [PSCustomObject]@{
                Source = $SourceRoot
                Destination = $tempDestination
            }
        )

        while ($stack.Count -gt 0) {
            $pair = $stack.Pop()
            $sourceDir = [string]$pair.Source
            $destinationDir = [string]$pair.Destination

            if (-not (Test-Path -LiteralPath $destinationDir)) {
                New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
            }

            foreach ($item in (Get-ChildItem -LiteralPath $sourceDir -Force -ErrorAction Stop)) {
                if ($item.PSIsContainer) {
                    if (Test-IsExcludedFolderName -Name $item.Name) {
                        continue
                    }

                    if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                        continue
                    }

                    $stack.Push(
                        [PSCustomObject]@{
                            Source = $item.FullName
                            Destination = (Join-Path -Path $destinationDir -ChildPath $item.Name)
                        }
                    )
                }
                else {
                    if (Test-IsExcludedFileName -Name $item.Name) {
                        continue
                    }

                    Copy-Item -LiteralPath $item.FullName -Destination (Join-Path -Path $destinationDir -ChildPath $item.Name) -Force -ErrorAction Stop
                }
            }
        }

        Move-Item -LiteralPath $tempDestination -Destination $DestinationRoot

        return [PSCustomObject]@{
            Success = $true
            Method = "PowerShellFilteredCopy"
            ExitCode = 0
            Error = ""
        }
    }
    catch {
        if (Test-Path -LiteralPath $tempDestination) {
            Remove-Item -LiteralPath $tempDestination -Recurse -Force -ErrorAction SilentlyContinue
        }

        return [PSCustomObject]@{
            Success = $false
            Method = "PowerShellFilteredCopy"
            ExitCode = -1
            Error = $_.Exception.Message
        }
    }
}

function Get-DirectoryStats {
    param([string]$Root)

    $count = 0L
    $bytes = 0L
    $files = Get-FilteredProjectFiles -Root $Root -Limit 0

    foreach ($file in $files) {
        $count = $count + 1
        $bytes = $bytes + $file.Length
    }

    return [PSCustomObject]@{
        FileCount = $count
        Bytes = $bytes
    }
}

function Get-WorkspaceDiff {
    param(
        [string]$ProjectRoot,
        [string]$CandidateRoot,
        [int]$MaxRows
    )

    $candidateFiles = Get-FilteredProjectFiles -Root $CandidateRoot -Limit 0
    $rows = New-Object System.Collections.Generic.List[object]
    $differentCount = 0
    $externalOnlyCount = 0
    $externalNewerCount = 0
    $sameCount = 0

    foreach ($externalFile in $candidateFiles) {
        $relative = Get-RelativePathSimple -Root $CandidateRoot -FullPath $externalFile.FullName
        $projectFilePath = Join-Path $ProjectRoot $relative

        if (-not (Test-Path -LiteralPath $projectFilePath -PathType Leaf)) {
            $externalOnlyCount = $externalOnlyCount + 1

            if ($rows.Count -lt $MaxRows) {
                $rows.Add(
                    [PSCustomObject]@{
                        Status = "EXTERNAL_ONLY"
                        RelativePath = $relative
                        ExternalTime = $externalFile.LastWriteTime
                        ProjectTime = $null
                    }
                )
            }

            continue
        }

        try {
            $projectFile = Get-Item -LiteralPath $projectFilePath -Force
        }
        catch {
            continue
        }

        $isDifferent = $false

        if ($projectFile.Length -ne $externalFile.Length) {
            $isDifferent = $true
        }
        else {
            try {
                $projectHash = (Get-FileHash -LiteralPath $projectFile.FullName -Algorithm SHA256).Hash
                $externalHash = (Get-FileHash -LiteralPath $externalFile.FullName -Algorithm SHA256).Hash

                if ($projectHash -ne $externalHash) {
                    $isDifferent = $true
                }
            }
            catch {
                if ($projectFile.LastWriteTimeUtc -ne $externalFile.LastWriteTimeUtc) {
                    $isDifferent = $true
                }
            }
        }

        if ($isDifferent) {
            $differentCount = $differentCount + 1

            if ($externalFile.LastWriteTimeUtc -gt $projectFile.LastWriteTimeUtc) {
                $externalNewerCount = $externalNewerCount + 1
            }

            if ($rows.Count -lt $MaxRows) {
                $status = "DIFFERENT"

                if ($externalFile.LastWriteTimeUtc -gt $projectFile.LastWriteTimeUtc) {
                    $status = "DIFFERENT_EXTERNAL_NEWER"
                }

                $rows.Add(
                    [PSCustomObject]@{
                        Status = $status
                        RelativePath = $relative
                        ExternalTime = $externalFile.LastWriteTime
                        ProjectTime = $projectFile.LastWriteTime
                    }
                )
            }
        }
        else {
            $sameCount = $sameCount + 1
        }
    }

    return [PSCustomObject]@{
        DifferentCount = $differentCount
        ExternalOnlyCount = $externalOnlyCount
        ExternalNewerCount = $externalNewerCount
        SameCount = $sameCount
        Rows = $rows
    }
}

function Extract-ApplyPatches {
    param(
        [System.Collections.IEnumerable]$SessionFiles,
        [string]$PatchOutputRoot,
        [string]$IndexPath,
        [System.Text.Encoding]$Encoding
    )

    New-Item -ItemType Directory -Path $PatchOutputRoot -Force | Out-Null

    $index = New-Object System.Collections.Generic.List[string]
    $index.Add("# Recovered Apply Patches")
    $index.Add("")
    $index.Add("These patches were extracted from related Codex rollout JSONL files.")
    $index.Add("They are recovery evidence. Verify target roots before applying them.")
    $index.Add("")

    $patchCount = 0

    foreach ($session in ($SessionFiles | Sort-Object LastWriteTime)) {
        try {
            foreach ($line in [System.IO.File]::ReadLines($session.FullName)) {
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }

                if (-not $line.Contains("*** Begin Patch")) {
                    continue
                }

                try {
                    $obj = $line | ConvertFrom-Json
                }
                catch {
                    continue
                }

                if ([string]$obj.type -ne "response_item") {
                    continue
                }

                $payload = $obj.payload

                if ($null -eq $payload) {
                    continue
                }

                $toolName = ""

                if ($null -ne $payload.PSObject.Properties["name"]) {
                    $toolName = [string]$payload.name
                }

                if ($toolName -ne "apply_patch") {
                    continue
                }

                $patchText = ""
                $callId = ""
                $payloadType = [string]$payload.type

                if ($null -ne $payload.PSObject.Properties["call_id"]) {
                    $callId = [string]$payload.call_id
                }

                if ($payloadType -eq "custom_tool_call") {
                    if ($null -ne $payload.PSObject.Properties["input"]) {
                        $patchText = [string]$payload.input
                    }
                }
                elseif ($payloadType -eq "function_call") {
                    if ($null -ne $payload.PSObject.Properties["arguments"]) {
                        $argumentsText = [string]$payload.arguments

                        try {
                            $argumentsObject = $argumentsText | ConvertFrom-Json

                            foreach ($propertyName in @("patch", "input", "command")) {
                                $property = $argumentsObject.PSObject.Properties[$propertyName]

                                if ($null -ne $property) {
                                    $candidateText = [string]$property.Value

                                    if ($candidateText.Contains("*** Begin Patch")) {
                                        $patchText = $candidateText
                                        break
                                    }
                                }
                            }
                        }
                        catch {
                            if ($argumentsText.Contains("*** Begin Patch")) {
                                $patchText = $argumentsText
                            }
                        }
                    }
                }

                if ([string]::IsNullOrWhiteSpace($patchText)) {
                    continue
                }

                if (-not $patchText.Contains("*** Begin Patch")) {
                    continue
                }

                $patchCount = $patchCount + 1
                $sessionBase = [System.IO.Path]::GetFileNameWithoutExtension($session.Name)
                $safeCallId = $callId

                if ([string]::IsNullOrWhiteSpace($safeCallId)) {
                    $safeCallId = "no_call_id"
                }

                $safeCallId = $safeCallId.Replace(":", "_").Replace("/", "_").Replace("\", "_")
                $patchFileName = ("{0:D4}_{1}_{2}.patch" -f $patchCount, $sessionBase, $safeCallId)
                $patchPath = Join-Path $PatchOutputRoot $patchFileName

                [System.IO.File]::WriteAllText($patchPath, $patchText, $Encoding)

                $index.Add("## Patch " + $patchCount)
                $index.Add("")
                $index.Add("- Session: " + $session.FullName)
                $index.Add("- Call id: " + $callId)
                $index.Add("- File: patches\" + $patchFileName)
                $index.Add("")
            }
        }
        catch {
        }
    }

    if ($patchCount -eq 0) {
        $index.Add("No apply_patch payloads were extracted automatically.")
    }

    [System.IO.File]::WriteAllLines($IndexPath, $index.ToArray(), $Encoding)

    return $patchCount
}


function New-ArchiveFromFiles {
    param(
        [System.Collections.IEnumerable]$Files,
        [string]$SourceRoot,
        [string]$DestinationZip,
        [string]$RootEntryName
    )

    Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

    $destinationDirectory = Split-Path -Parent $DestinationZip

    if (-not (Test-Path -LiteralPath $destinationDirectory -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
    }

    $temporaryZip = $DestinationZip + ".creating"

    if (Test-Path -LiteralPath $temporaryZip -PathType Leaf) {
        Remove-Item -LiteralPath $temporaryZip -Force
    }

    try {
        $fileStream = [System.IO.File]::Open(
            $temporaryZip,
            [System.IO.FileMode]::Create,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )

        try {
            $archiveArguments = @(
                $fileStream,
                [System.IO.Compression.ZipArchiveMode]::Create,
                $false
            )

            $archive = New-Object -TypeName System.IO.Compression.ZipArchive -ArgumentList $archiveArguments

            try {
                foreach ($file in $Files) {
                    if ($null -eq $file) {
                        continue
                    }

                    $relative = Get-RelativePathSimple -Root $SourceRoot -FullPath $file.FullName
                    $entryName = $relative.Replace("\", "/").TrimStart("/")

                    if (-not [string]::IsNullOrWhiteSpace($RootEntryName)) {
                        $entryName = $RootEntryName.TrimEnd("/", "\") + "/" + $entryName
                    }

                    $entry = $archive.CreateEntry(
                        $entryName,
                        [System.IO.Compression.CompressionLevel]::Optimal
                    )

                    if ($file.LastWriteTime.Year -ge 1980) {
                        try {
                            $entry.LastWriteTime = $file.LastWriteTime
                        }
                        catch {
                        }
                    }

                    $inputStream = [System.IO.File]::Open(
                        $file.FullName,
                        [System.IO.FileMode]::Open,
                        [System.IO.FileAccess]::Read,
                        [System.IO.FileShare]::ReadWrite
                    )

                    try {
                        $outputStream = $entry.Open()

                        try {
                            $inputStream.CopyTo($outputStream)
                        }
                        finally {
                            $outputStream.Dispose()
                        }
                    }
                    finally {
                        $inputStream.Dispose()
                    }
                }
            }
            finally {
                $archive.Dispose()
            }
        }
        finally {
            $fileStream.Dispose()
        }

        if (Test-Path -LiteralPath $DestinationZip -PathType Leaf) {
            Remove-Item -LiteralPath $DestinationZip -Force
        }

        Move-Item -LiteralPath $temporaryZip -Destination $DestinationZip -Force
    }
    catch {
        if (Test-Path -LiteralPath $temporaryZip -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryZip -Force -ErrorAction SilentlyContinue
        }

        throw
    }
}

function New-ProjectSourceArchive {
    param(
        [string]$SourceRoot,
        [string]$DestinationZip
    )

    $projectArchiveFiles = Get-FilteredProjectFiles -Root $SourceRoot -Limit 0
    $projectRootName = Split-Path -Leaf $SourceRoot

    New-ArchiveFromFiles -Files $projectArchiveFiles -SourceRoot $SourceRoot -DestinationZip $DestinationZip -RootEntryName $projectRootName
}

function New-HandoffBundleArchive {
    param(
        [string]$SourceRoot,
        [string]$DestinationZip
    )

    $bundleFiles = @(
        Get-ChildItem -LiteralPath $SourceRoot -Recurse -Force -File -ErrorAction Stop
    )

    $bundleRootName = Split-Path -Leaf $SourceRoot

    New-ArchiveFromFiles -Files $bundleFiles -SourceRoot $SourceRoot -DestinationZip $DestinationZip -RootEntryName $bundleRootName
}


try {
    $ProjectPath = (Resolve-Path -LiteralPath $ProjectPath).Path
}
catch {
    Write-Error ("Project directory not found: " + $ProjectPath)
    exit 1
}

if (-not (Test-Path -LiteralPath $ProjectPath -PathType Container)) {
    Write-Error ("Path is not a directory: " + $ProjectPath)
    exit 1
}

$ProjectParent = Split-Path -Parent $ProjectPath
$ProjectName = Split-Path -Leaf $ProjectPath

if ([string]::IsNullOrWhiteSpace($BundlePath)) {
    $stamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $BundlePath = Join-Path $ProjectPath ("AI_HANDOFF_BUNDLE_" + $stamp)
}

New-Item -ItemType Directory -Path $BundlePath -Force | Out-Null

$SettingsSnapshotPath = Join-Path -Path $BundlePath -ChildPath "SCRIPT_SETTINGS_SNAPSHOT.json"
Copy-Item -LiteralPath $ScriptSettingsPath -Destination $SettingsSnapshotPath -Force

$SessionsOut = Join-Path $BundlePath "sessions"
$TranscriptsOut = Join-Path $BundlePath "transcripts"
$ExternalOut = Join-Path $BundlePath "external_workspaces"
$ExternalDiffOut = Join-Path $BundlePath "external_workspace_diffs"
$PatchOut = Join-Path $BundlePath "patches"

New-Item -ItemType Directory -Path $SessionsOut -Force | Out-Null
New-Item -ItemType Directory -Path $TranscriptsOut -Force | Out-Null
New-Item -ItemType Directory -Path $ExternalOut -Force | Out-Null
New-Item -ItemType Directory -Path $ExternalDiffOut -Force | Out-Null
New-Item -ItemType Directory -Path $PatchOut -Force | Out-Null

$Utf8Bom = New-Object System.Text.UTF8Encoding($true)

Write-Host "Scanning project files..." -ForegroundColor Cyan

$AllFiles = Get-FilteredProjectFiles -Root $ProjectPath -Limit 0
$TextFiles = Get-TextFileList -Files $AllFiles

$RecentFiles = @(
    $AllFiles |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First $RecentFileCount
)

$BurstFiles = @()

if ($RecentFiles.Count -gt 0) {
    $LatestModification = $RecentFiles[0].LastWriteTime
    $BurstStart = $LatestModification.AddMinutes(-1 * $BurstMinutes)

    $BurstFiles = @(
        $AllFiles |
        Where-Object {
            $_.LastWriteTime -ge $BurstStart -and
            $_.LastWriteTime -le $LatestModification
        } |
        Sort-Object LastWriteTime
    )
}

$RecentTextFileSet = Get-TextFileList -Files $BurstFiles

$ProjectTypes = New-Object System.Collections.Generic.List[string]
$ValidationCommands = New-Object System.Collections.Generic.List[string]

$HasPhpFiles = $false
$HasDotNetProject = $false

foreach ($File in $AllFiles) {
    if ($File.Extension.ToLowerInvariant() -in @(".php", ".phtml", ".inc")) {
        $HasPhpFiles = $true
    }

    if ($File.Extension.ToLowerInvariant() -in @(".sln", ".csproj", ".fsproj", ".vbproj")) {
        $HasDotNetProject = $true
    }
}

if ($HasPhpFiles -or (Test-Path -LiteralPath (Join-Path $ProjectPath "composer.json"))) {
    $ProjectTypes.Add("PHP")

    if (Test-Path -LiteralPath (Join-Path $ProjectPath "composer.json")) {
        $ValidationCommands.Add("composer validate")
    }
}

if (Test-Path -LiteralPath (Join-Path $ProjectPath "artisan")) {
    $ProjectTypes.Add("Laravel")
}

if (
    (Test-Path -LiteralPath (Join-Path $ProjectPath "wp-config.php")) -or
    (Test-Path -LiteralPath (Join-Path $ProjectPath "wp-content"))
) {
    $ProjectTypes.Add("WordPress")
}

if (
    (Test-Path -LiteralPath (Join-Path $ProjectPath "bin\console")) -and
    (Test-Path -LiteralPath (Join-Path $ProjectPath "composer.json"))
) {
    $ProjectTypes.Add("Symfony-like PHP")
}

if (Test-Path -LiteralPath (Join-Path $ProjectPath "Cargo.toml")) {
    $ProjectTypes.Add("Rust")
    $ValidationCommands.Add("cargo check")
}

if (Test-Path -LiteralPath (Join-Path $ProjectPath "src-tauri")) {
    $ProjectTypes.Add("Tauri")
}

if (Test-Path -LiteralPath (Join-Path $ProjectPath "package.json")) {
    $ProjectTypes.Add("Node.js / JavaScript / TypeScript")

    if (Test-Path -LiteralPath (Join-Path $ProjectPath "pnpm-lock.yaml")) {
        $ValidationCommands.Add("pnpm run build")
    }
    elseif (Test-Path -LiteralPath (Join-Path $ProjectPath "yarn.lock")) {
        $ValidationCommands.Add("yarn build")
    }
    else {
        $ValidationCommands.Add("npm run build")
    }
}

if ($HasDotNetProject) {
    $ProjectTypes.Add(".NET")
    $ValidationCommands.Add("dotnet build")
}

if (
    (Test-Path -LiteralPath (Join-Path $ProjectPath "pyproject.toml")) -or
    (Test-Path -LiteralPath (Join-Path $ProjectPath "requirements.txt"))
) {
    $ProjectTypes.Add("Python")
}

if ($ProjectTypes.Count -eq 0) {
    $ProjectTypes.Add("Unknown")
}

Write-Host "Searching unfinished markers..." -ForegroundColor Cyan

$MarkerPatterns = @(
    "\bTODO\b",
    "\bFIXME\b",
    "\bXXX\b",
    "\bHACK\b",
    "\bWIP\b",
    "\bTEMP\b",
    "NotImplemented",
    "NotImplementedException",
    "NotImplementedError",
    "unimplemented!\s*\(",
    "todo!\s*\(",
    "throw\s+new\s+NotImplementedException",
    "raise\s+NotImplementedError"
)

$MarkerResults = New-Object System.Collections.Generic.List[object]

foreach ($File in $TextFiles) {
    if ($MarkerResults.Count -ge $MaxMarkerResults) {
        break
    }

    try {
        $Matches = Select-String -LiteralPath $File.FullName -Pattern $MarkerPatterns -AllMatches -ErrorAction Stop

        foreach ($Match in $Matches) {
            $MarkerResults.Add(
                [PSCustomObject]@{
                    File = Get-RelativePathSimple -Root $ProjectPath -FullPath $File.FullName
                    Line = $Match.LineNumber
                    Text = Limit-TextSimple -Text $Match.Line.Trim() -MaxLength 400
                }
            )

            if ($MarkerResults.Count -ge $MaxMarkerResults) {
                break
            }
        }
    }
    catch {
    }
}

Write-Host "Finding related Codex sessions..." -ForegroundColor Cyan

$CodexSessionRoot = Join-Path $env:USERPROFILE ".codex\sessions"
$RelatedSessionEntries = New-Object System.Collections.Generic.List[object]
$RecentFallbackEntries = New-Object System.Collections.Generic.List[object]

if (Test-Path -LiteralPath $CodexSessionRoot) {
    $SessionFiles = @(
        Get-ChildItem -LiteralPath $CodexSessionRoot -Recurse -File -Filter "*.jsonl" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    )

    foreach ($SessionFile in $SessionFiles) {
        $meta = Get-CodexSessionMeta -Path $SessionFile.FullName

        $entry = [PSCustomObject]@{
            File = $SessionFile
            Meta = $meta
        }

        if (Test-PathInside -Child $meta.Cwd -Parent $ProjectPath) {
            $RelatedSessionEntries.Add($entry)
        }
        elseif (Test-PathInside -Child $ProjectPath -Parent $meta.Cwd) {
            $RelatedSessionEntries.Add($entry)
        }
        elseif ($RecentFallbackEntries.Count -lt 100) {
            $RecentFallbackEntries.Add($entry)
        }
    }
}

if ($RelatedSessionEntries.Count -eq 0) {
    foreach ($entry in $RecentFallbackEntries) {
        $found = $false

        try {
            if (Select-String -LiteralPath $entry.File.FullName -Pattern $ProjectName -SimpleMatch -Quiet -ErrorAction SilentlyContinue) {
                $found = $true
            }
        }
        catch {
        }

        if ($found) {
            $RelatedSessionEntries.Add($entry)
        }
    }
}

$RelatedDetails = New-Object System.Collections.Generic.List[object]
$RelatedSessionFiles = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($entry in ($RelatedSessionEntries | Sort-Object { $_.File.LastWriteTime })) {
    $details = Get-CodexSessionDetails -Path $entry.File.FullName

    $RelatedDetails.Add(
        [PSCustomObject]@{
            File = $entry.File
            Details = $details
        }
    )

    $RelatedSessionFiles.Add($entry.File)
}

$SessionStart = $null
$SessionEnd = $null

if ($RelatedSessionFiles.Count -gt 0) {
    $ordered = @($RelatedSessionFiles | Sort-Object LastWriteTime)
    $SessionStart = $ordered[0].CreationTime
    $SessionEnd = $ordered[$ordered.Count - 1].LastWriteTime
}

Write-Host "Copying related Codex sessions without size limits..." -ForegroundColor Cyan

$SessionIndex = New-Object System.Collections.Generic.List[string]
$SessionIndex.Add("# Session Index")
$SessionIndex.Add("")
$SessionIndex.Add("All related raw Codex sessions are copied in full. No size limit is applied.")
$SessionIndex.Add("Read transcripts first. Use raw JSONL when forensic detail is needed.")
$SessionIndex.Add("")

$sessionCounter = 0

foreach ($entry in $RelatedDetails) {
    $sessionCounter = $sessionCounter + 1
    $file = $entry.File
    $details = $entry.Details
    $rawTarget = Join-Path $SessionsOut $file.Name

    Copy-Item -LiteralPath $file.FullName -Destination $rawTarget -Force

    $transcriptName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name) + ".md"
    $transcriptPath = Join-Path $TranscriptsOut $transcriptName
    $transcript = New-Object System.Collections.Generic.List[string]

    $transcript.Add("# Codex Session Transcript")
    $transcript.Add("")
    $transcript.Add("Source: " + $file.FullName)
    $transcript.Add("Recorded cwd: " + $details.Cwd)
    $transcript.Add("Session id: " + $details.SessionId)
    $transcript.Add("Created: " + $details.Created)
    $transcript.Add("Modified: " + $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))
    $transcript.Add("")

    foreach ($goal in $details.GoalObjectives) {
        $transcript.Add("## Goal Objective")
        $transcript.Add("")
        Add-TextLines -Target $transcript -Text $goal
        $transcript.Add("")
    }

    foreach ($message in $details.Messages) {
        if ($message.Role -eq "user") {
            $transcript.Add("## USER")
        }
        else {
            $transcript.Add("## CODEX")
        }

        $transcript.Add("")
        $transcript.Add("Timestamp: " + $message.Timestamp)
        $transcript.Add("Source record: " + $message.Source)
        $transcript.Add("")
        Add-TextLines -Target $transcript -Text $message.Text
        $transcript.Add("")
    }

    if ($details.Commands.Count -gt 0) {
        $transcript.Add("## Recent Commands")
        $transcript.Add("")

        foreach ($command in ($details.Commands | Select-Object -Last 100)) {
            $transcript.Add("- " + $command.Timestamp + " | exit=" + $command.ExitCode + " | " + $command.Command)
        }

        $transcript.Add("")
    }

    [System.IO.File]::WriteAllLines($transcriptPath, $transcript.ToArray(), $Utf8Bom)

    $SessionIndex.Add("## Session " + $sessionCounter)
    $SessionIndex.Add("")
    $SessionIndex.Add("- File: " + $file.Name)
    $SessionIndex.Add("- Recorded cwd: " + $details.Cwd)
    $SessionIndex.Add("- Modified: " + $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss"))
    $SessionIndex.Add("- Raw JSONL: sessions\" + $file.Name)
    $SessionIndex.Add("- Transcript: transcripts\" + $transcriptName)
    $SessionIndex.Add("")
}

if ($RelatedDetails.Count -eq 0) {
    $SessionIndex.Add("No related Codex sessions were found.")
}

$SessionIndexPath = Join-Path $BundlePath "SESSION_INDEX.md"
[System.IO.File]::WriteAllLines($SessionIndexPath, $SessionIndex.ToArray(), $Utf8Bom)

$AllMeaningfulUserMessages = New-Object System.Collections.Generic.List[object]

foreach ($entry in $RelatedDetails) {
    foreach ($message in $entry.Details.Messages) {
        if ($message.Role -eq "user") {
            $AllMeaningfulUserMessages.Add(
                [PSCustomObject]@{
                    SessionFile = $entry.File.FullName
                    SessionModified = $entry.File.LastWriteTime
                    Sequence = $message.Sequence
                    Timestamp = $message.Timestamp
                    Text = $message.Text
                }
            )
        }
    }
}

$SelectedEntry = $null

if ($RelatedDetails.Count -gt 0) {
    $SelectedEntry = $RelatedDetails |
        Sort-Object { $_.File.LastWriteTime } -Descending |
        Select-Object -First 1
}

$SelectedUserMessages = @()

if ($null -ne $SelectedEntry) {
    $SelectedUserMessages = @(
        $SelectedEntry.Details.Messages |
        Where-Object { $_.Role -eq "user" } |
        Sort-Object Sequence
    )
}

$LastUserPrompt = ""
$PrimaryTaskPrompt = ""

if ($SelectedUserMessages.Count -gt 0) {
    $LastUserPrompt = [string]$SelectedUserMessages[$SelectedUserMessages.Count - 1].Text

    for ($i = $SelectedUserMessages.Count - 1; $i -ge 0; $i = $i - 1) {
        $candidate = [string]$SelectedUserMessages[$i].Text
        $candidateFeatures = Get-FeatureLines -PromptText $candidate

        if ($candidateFeatures.Count -ge 2 -or $candidate.Length -ge 250) {
            $PrimaryTaskPrompt = $candidate
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($PrimaryTaskPrompt)) {
        $PrimaryTaskPrompt = $LastUserPrompt
    }
}

if (
    [string]::IsNullOrWhiteSpace($PrimaryTaskPrompt) -and
    $null -ne $SelectedEntry -and
    $SelectedEntry.Details.GoalObjectives.Count -gt 0
) {
    $PrimaryTaskPrompt = [string]$SelectedEntry.Details.GoalObjectives[$SelectedEntry.Details.GoalObjectives.Count - 1]
}

$LastPromptPath = Join-Path $BundlePath "LAST_USER_PROMPT.md"
$PrimaryPromptPath = Join-Path $BundlePath "PRIMARY_TASK_PROMPT.md"
$PromptHistoryPath = Join-Path $BundlePath "PROMPT_HISTORY.md"

$lastPromptReport = New-Object System.Collections.Generic.List[string]
$lastPromptReport.Add("# Last User Prompt")
$lastPromptReport.Add("")

if ([string]::IsNullOrWhiteSpace($LastUserPrompt)) {
    $lastPromptReport.Add("No meaningful user prompt could be extracted from the selected session.")
}
else {
    Add-TextLines -Target $lastPromptReport -Text $LastUserPrompt
}

[System.IO.File]::WriteAllLines($LastPromptPath, $lastPromptReport.ToArray(), $Utf8Bom)

$primaryPromptReport = New-Object System.Collections.Generic.List[string]
$primaryPromptReport.Add("# Primary Task Prompt")
$primaryPromptReport.Add("")
$primaryPromptReport.Add("This is the nearest recent prompt that looks like the main implementation request.")
$primaryPromptReport.Add("")

if ([string]::IsNullOrWhiteSpace($PrimaryTaskPrompt)) {
    $primaryPromptReport.Add("No primary task prompt could be extracted.")
}
else {
    Add-TextLines -Target $primaryPromptReport -Text $PrimaryTaskPrompt
}

[System.IO.File]::WriteAllLines($PrimaryPromptPath, $primaryPromptReport.ToArray(), $Utf8Bom)

$promptHistoryReport = New-Object System.Collections.Generic.List[string]
$promptHistoryReport.Add("# Prompt History")
$promptHistoryReport.Add("")
$promptHistoryReport.Add("Meaningful user messages extracted from related Codex sessions.")
$promptHistoryReport.Add("")

$historyMessages = @(
    $AllMeaningfulUserMessages |
    Sort-Object SessionModified, Sequence
)

$historyStart = [Math]::Max(0, $historyMessages.Count - $PromptWindow)

for ($i = $historyStart; $i -lt $historyMessages.Count; $i = $i + 1) {
    $item = $historyMessages[$i]
    $promptHistoryReport.Add("## Prompt " + ($i - $historyStart + 1))
    $promptHistoryReport.Add("")
    $promptHistoryReport.Add("Session: " + [System.IO.Path]::GetFileName($item.SessionFile))
    $promptHistoryReport.Add("Timestamp: " + $item.Timestamp)
    $promptHistoryReport.Add("")
    Add-TextLines -Target $promptHistoryReport -Text $item.Text
    $promptHistoryReport.Add("")
}

[System.IO.File]::WriteAllLines($PromptHistoryPath, $promptHistoryReport.ToArray(), $Utf8Bom)

$RequestedFeatures = Get-FeatureLines -PromptText $PrimaryTaskPrompt
$FeatureEvidence = New-Object System.Collections.Generic.List[object]
$featureNumber = 0

foreach ($feature in $RequestedFeatures) {
    $featureNumber = $featureNumber + 1
    $evidence = Find-FeatureEvidence -Feature $feature -RecentCandidateFiles $RecentTextFileSet -AllCandidateFiles $TextFiles -Root $ProjectPath

    $FeatureEvidence.Add(
        [PSCustomObject]@{
            Number = $featureNumber
            Feature = $feature
            Evidence = $evidence
        }
    )
}

$FeaturePath = Join-Path $BundlePath "FEATURE_EVIDENCE.md"
$featureReport = New-Object System.Collections.Generic.List[string]

$featureReport.Add("# Feature Evidence")
$featureReport.Add("")
$featureReport.Add("IMPORTANT: These signals do NOT prove completion.")
$featureReport.Add("NO_OBVIOUS_SIGNAL can mean skipped work or an implementation that simple text matching could not detect.")
$featureReport.Add("The next AI must verify every requested item against actual source and runtime behavior.")
$featureReport.Add("")

if ($FeatureEvidence.Count -eq 0) {
    $featureReport.Add("No feature checklist could be extracted automatically from PRIMARY_TASK_PROMPT.md.")
}
else {
    foreach ($item in $FeatureEvidence) {
        $featureReport.Add("## " + $item.Number + ". " + $item.Feature)
        $featureReport.Add("")
        $featureReport.Add("Automated signal: " + $item.Evidence.Signal)
        $featureReport.Add("Search tokens: " + ($item.Evidence.Tokens -join ", "))
        $featureReport.Add("")

        if ($item.Evidence.RecentHits.Count -gt 0) {
            $featureReport.Add("Recent work-burst evidence:")

            foreach ($hit in $item.Evidence.RecentHits) {
                $featureReport.Add("- " + $hit)
            }

            $featureReport.Add("")
        }

        if ($item.Evidence.GeneralHits.Count -gt 0) {
            $featureReport.Add("General project evidence:")

            foreach ($hit in $item.Evidence.GeneralHits) {
                $featureReport.Add("- " + $hit)
            }

            $featureReport.Add("")
        }

        $featureReport.Add("Verification status: MUST_BE_CHECKED_BY_NEXT_AI")
        $featureReport.Add("")
    }
}

[System.IO.File]::WriteAllLines($FeaturePath, $featureReport.ToArray(), $Utf8Bom)

$ProjectScanPath = Join-Path $BundlePath "PROJECT_SCAN.md"
$projectScanReport = New-Object System.Collections.Generic.List[string]

$projectScanReport.Add("# Project Scan")
$projectScanReport.Add("")
$projectScanReport.Add("Project path: " + $ProjectPath)
$projectScanReport.Add("Scan time: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$projectScanReport.Add("Detected project type: " + ($ProjectTypes -join ", "))
$projectScanReport.Add("Total files scanned: " + $AllFiles.Count)
$projectScanReport.Add("Text or source files: " + $TextFiles.Count)
$projectScanReport.Add("")
$projectScanReport.Add("## Possible validation commands")
$projectScanReport.Add("")

foreach ($command in ($ValidationCommands | Select-Object -Unique)) {
    $projectScanReport.Add("- " + $command)
}

if ($ValidationCommands.Count -eq 0) {
    $projectScanReport.Add("- None detected automatically.")
}

$projectScanReport.Add("")
$projectScanReport.Add("## Possible last work burst")
$projectScanReport.Add("")
$projectScanReport.Add("| Time | File | Size |")
$projectScanReport.Add("|---|---|---:|")

foreach ($File in $BurstFiles) {
    $relative = Escape-MarkdownCell -Text (Get-RelativePathSimple -Root $ProjectPath -FullPath $File.FullName)
    $projectScanReport.Add("| " + $File.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") + " | " + $relative + " | " + $File.Length + " |")
}

$projectScanReport.Add("")
$projectScanReport.Add("## Recently modified files")
$projectScanReport.Add("")
$projectScanReport.Add("| Time | File | Size |")
$projectScanReport.Add("|---|---|---:|")

foreach ($File in $RecentFiles) {
    $relative = Escape-MarkdownCell -Text (Get-RelativePathSimple -Root $ProjectPath -FullPath $File.FullName)
    $projectScanReport.Add("| " + $File.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss") + " | " + $relative + " | " + $File.Length + " |")
}

$projectScanReport.Add("")
$projectScanReport.Add("## TODO FIXME WIP and unfinished markers")
$projectScanReport.Add("")

if ($MarkerResults.Count -gt 0) {
    $projectScanReport.Add("| File | Line | Content |")
    $projectScanReport.Add("|---|---:|---|")

    foreach ($marker in $MarkerResults) {
        $markerFile = Escape-MarkdownCell -Text $marker.File
        $markerText = Escape-MarkdownCell -Text $marker.Text
        $projectScanReport.Add("| " + $markerFile + " | " + $marker.Line + " | " + $markerText + " |")
    }
}
else {
    $projectScanReport.Add("No obvious unfinished markers were found.")
}

[System.IO.File]::WriteAllLines($ProjectScanPath, $projectScanReport.ToArray(), $Utf8Bom)

$PatchIndexPath = Join-Path $BundlePath "PATCH_INDEX.md"
$RecoveredPatchCount = Extract-ApplyPatches -SessionFiles $RelatedSessionFiles -PatchOutputRoot $PatchOut -IndexPath $PatchIndexPath -Encoding $Utf8Bom

Write-Host ("Recovered apply_patch payloads: " + $RecoveredPatchCount) -ForegroundColor DarkGray

Write-Host "Discovering external Codex workspaces automatically..." -ForegroundColor Cyan

$CandidateDirs = New-Object System.Collections.Generic.List[System.IO.DirectoryInfo]
$CandidateSeen = New-Object System.Collections.Generic.HashSet[string]

$rootsToInspect = New-Object System.Collections.Generic.List[string]

if (-not (Test-PathContainsExcludedFolderName -PathValue $ProjectParent)) {
    if (-not (Test-IsToolOwnedPath -CandidatePath $ProjectParent)) {
        $rootsToInspect.Add($ProjectParent)
    }
}

$grandParent = Split-Path -Parent $ProjectParent

if (-not [string]::IsNullOrWhiteSpace($grandParent)) {
    if (-not (Test-PathContainsExcludedFolderName -PathValue $grandParent)) {
        if (-not (Test-IsToolOwnedPath -CandidatePath $grandParent)) {
            if (-not ($rootsToInspect -contains $grandParent)) {
                $rootsToInspect.Add($grandParent)
            }
        }
    }
}

foreach ($root in $rootsToInspect) {
    if (-not (Test-Path -LiteralPath $root -PathType Container)) {
        continue
    }

    foreach ($dir in (Get-ChildItem -LiteralPath $root -Force -Directory -ErrorAction SilentlyContinue)) {
        if (Test-IsExcludedFolderName -Name $dir.Name) {
            continue
        }

        if (Test-PathContainsExcludedFolderName -PathValue $dir.FullName) {
            continue
        }

        if (Test-IsToolOwnedPath -CandidatePath $dir.FullName) {
            continue
        }

        if (Test-PathInside -Child $ProjectPath -Parent $dir.FullName) {
            continue
        }

        if (Test-PathInside -Child $BundlePath -Parent $dir.FullName) {
            continue
        }

        if ($dir.Name.StartsWith("AI_HANDOFF_BUNDLE_")) {
            continue
        }

        $normalizedDir = Normalize-PathSimple -Value $dir.FullName

        if ($CandidateSeen.Add($normalizedDir)) {
            $CandidateDirs.Add($dir)
        }

        if ($root -eq $grandParent) {
            foreach ($child in (Get-ChildItem -LiteralPath $dir.FullName -Force -Directory -ErrorAction SilentlyContinue | Select-Object -First 50)) {
                if (Test-IsExcludedFolderName -Name $child.Name) {
                    continue
                }

                if (Test-PathContainsExcludedFolderName -PathValue $child.FullName) {
                    continue
                }

                if (Test-IsToolOwnedPath -CandidatePath $child.FullName) {
                    continue
                }

                if (Test-PathInside -Child $ProjectPath -Parent $child.FullName) {
                    continue
                }

                if (Test-PathInside -Child $BundlePath -Parent $child.FullName) {
                    continue
                }

                $normalizedChild = Normalize-PathSimple -Value $child.FullName

                if ($CandidateSeen.Add($normalizedChild)) {
                    $CandidateDirs.Add($child)
                }
            }
        }
    }
}

$Candidates = New-Object System.Collections.Generic.List[object]

foreach ($dir in $CandidateDirs) {
    if (Test-IsToolOwnedPath -CandidatePath $dir.FullName) {
        continue
    }

    if (Test-PathContainsExcludedFolderName -PathValue $dir.FullName) {
        continue
    }

    $mentioned = Test-SessionMentionsCandidate -SessionFiles $RelatedSessionFiles -CandidatePath $dir.FullName -CandidateName $dir.Name
    $resolved = Resolve-CandidateCompareRoot -ProjectRoot $ProjectPath -CandidateRoot $dir.FullName -ProjectName $ProjectName
    $similarity = $resolved.Similarity
    $compareRoot = $resolved.Root
    $newest = Get-NewestFilteredFileTime -Root $dir.FullName
    $stageLike = $dir.Name -match "(?i)(stage|staging|worktree|workspace|scratch|temp|tmp|patch|copy|backup|bak|shadow)"
    $nameMatchesProject = $dir.Name.ToLowerInvariant().Contains($ProjectName.ToLowerInvariant())

    $score = 0
    $reasons = New-Object System.Collections.Generic.List[string]

    if ($mentioned) {
        $score = $score + 10
        $reasons.Add("Referenced by a related Codex session.")
    }

    if ($stageLike) {
        $score = $score + 5
        $reasons.Add("Directory name looks like staging, worktree, scratch, temp, patch, backup, or Codex workspace.")
    }

    if ($nameMatchesProject) {
        $score = $score + 4
        $reasons.Add("Directory name contains the project directory name.")
    }

    if ($compareRoot -ne $dir.FullName) {
        $score = $score + 2
        $reasons.Add("A nested directory matches the project structure better.")
    }

    if ($similarity -ge 0.75) {
        $score = $score + 7
        $reasons.Add("Very high structural similarity to the project.")
    }
    elseif ($similarity -ge 0.50) {
        $score = $score + 5
        $reasons.Add("High structural similarity to the project.")
    }
    elseif ($similarity -ge 0.20) {
        $score = $score + 2
        $reasons.Add("Some structural similarity to the project.")
    }

    if ($null -ne $newest -and $null -ne $SessionStart -and $null -ne $SessionEnd) {
        $windowStart = $SessionStart.AddHours(-3)
        $windowEnd = $SessionEnd.AddHours(3)

        if ($newest -ge $windowStart -and $newest -le $windowEnd) {
            $score = $score + 4
            $reasons.Add("Workspace activity overlaps the Codex session time window.")
        }
    }

    $copyEligible = $false

    if ($mentioned -and $similarity -ge 0.05) {
        $copyEligible = $true
    }
    elseif ($similarity -ge 0.50) {
        $copyEligible = $true
    }
    elseif ($stageLike -and $similarity -ge 0.10) {
        $copyEligible = $true
    }
    elseif ($nameMatchesProject -and $similarity -ge 0.10) {
        $copyEligible = $true
    }
    elseif ($score -ge 12) {
        $copyEligible = $true
    }

    if ($score -ge 4 -or $copyEligible) {
        $Candidates.Add(
            [PSCustomObject]@{
                Directory = $dir
                CompareRoot = $compareRoot
                Score = $score
                Mentioned = $mentioned
                Similarity = $similarity
                Newest = $newest
                StageLike = $stageLike
                NameMatchesProject = $nameMatchesProject
                CopyEligible = $copyEligible
                Reasons = $reasons
            }
        )
    }
}

$ExternalReportPath = Join-Path $BundlePath "EXTERNAL_WORKSPACES.md"
$externalReport = New-Object System.Collections.Generic.List[string]

$externalReport.Add("# External Workspace Recovery")
$externalReport.Add("")
$externalReport.Add("The script automatically scans outside the project for staging, worktree, workspace, scratch, temp, backup, copied, or shadow workspaces. The handoff tool's own installation path is never treated as a recovery workspace.")
$externalReport.Add("Eligible workspaces are copied without size limits. Names excluded by script-settings.json are not processed or copied.")
$externalReport.Add("Copy policy is all-or-fail: a failed partial copy is removed and reported as failure.")
$externalReport.Add("")
$externalReport.Add("Project: " + $ProjectPath)
$externalReport.Add("Candidates found: " + $Candidates.Count)
$externalReport.Add("")

$CopiedExternalCount = 0
$FailedExternalCount = 0

foreach ($candidate in ($Candidates | Sort-Object Score -Descending)) {
    $dir = $candidate.Directory
    $safeName = Get-SafeFolderName -Name $dir.Name
    $diff = Get-WorkspaceDiff -ProjectRoot $ProjectPath -CandidateRoot $candidate.CompareRoot -MaxRows $MaxDiffRows
    $diffPath = Join-Path $ExternalDiffOut ($safeName + ".md")

    $diffReport = New-Object System.Collections.Generic.List[string]
    $diffReport.Add("# External Workspace Diff")
    $diffReport.Add("")
    $diffReport.Add("Main project: " + $ProjectPath)
    $diffReport.Add("External workspace container: " + $dir.FullName)
    $diffReport.Add("External compare root: " + $candidate.CompareRoot)
    $diffReport.Add("")
    $diffReport.Add("- Different files: " + $diff.DifferentCount)
    $diffReport.Add("- External-only files: " + $diff.ExternalOnlyCount)
    $diffReport.Add("- External-newer different files: " + $diff.ExternalNewerCount)
    $diffReport.Add("- Same files: " + $diff.SameCount)
    $diffReport.Add("")
    $diffReport.Add("| Status | Relative path | External time | Project time |")
    $diffReport.Add("|---|---|---|---|")

    foreach ($row in $diff.Rows) {
        $externalTimeText = ""
        $projectTimeText = ""

        if ($null -ne $row.ExternalTime) {
            $externalTimeText = $row.ExternalTime.ToString("yyyy-MM-dd HH:mm:ss")
        }

        if ($null -ne $row.ProjectTime) {
            $projectTimeText = $row.ProjectTime.ToString("yyyy-MM-dd HH:mm:ss")
        }

        $relativeCell = Escape-MarkdownCell -Text $row.RelativePath
        $diffReport.Add("| " + $row.Status + " | " + $relativeCell + " | " + $externalTimeText + " | " + $projectTimeText + " |")
    }

    [System.IO.File]::WriteAllLines($diffPath, $diffReport.ToArray(), $Utf8Bom)

    $externalReport.Add("## " + $dir.Name)
    $externalReport.Add("")
    $externalReport.Add("- Path: " + $dir.FullName)
    $externalReport.Add("- Compare root: " + $candidate.CompareRoot)
    $externalReport.Add("- Detection score: " + $candidate.Score)
    $externalReport.Add("- Mentioned by Codex session: " + $candidate.Mentioned)
    $externalReport.Add("- Structural similarity: " + $candidate.Similarity)
    $externalReport.Add("- Stage-like name: " + $candidate.StageLike)
    $externalReport.Add("- Project-name match: " + $candidate.NameMatchesProject)
    $externalReport.Add("- Copy eligible: " + $candidate.CopyEligible)
    $externalReport.Add("- Different files: " + $diff.DifferentCount)
    $externalReport.Add("- External-only files: " + $diff.ExternalOnlyCount)
    $externalReport.Add("- External-newer different files: " + $diff.ExternalNewerCount)
    $externalReport.Add("")

    $externalReport.Add("Detection reasons:")

    foreach ($reason in $candidate.Reasons) {
        $externalReport.Add("- " + $reason)
    }

    $externalReport.Add("")

    if ($candidate.CopyEligible) {
        $copyTarget = Join-Path $ExternalOut $safeName
        $copyResult = Copy-DirectoryComplete -SourceRoot $dir.FullName -DestinationRoot $copyTarget

        if ($copyResult.Success) {
            $CopiedExternalCount = $CopiedExternalCount + 1
            $stats = Get-DirectoryStats -Root $copyTarget
            $externalReport.Add("- Bundle copy: external_workspaces\" + $safeName)
            $externalReport.Add("- Copy method: " + $copyResult.Method)
            $externalReport.Add("- Copied files: " + $stats.FileCount)
            $externalReport.Add("- Copied bytes: " + $stats.Bytes)
        }
        else {
            $FailedExternalCount = $FailedExternalCount + 1
            $externalReport.Add("- COPY FAILED")
            $externalReport.Add("- Method: " + $copyResult.Method)
            $externalReport.Add("- Exit code: " + $copyResult.ExitCode)
            $externalReport.Add("- Error: " + $copyResult.Error)
            $externalReport.Add("- No partial copy is kept.")
            $externalReport.Add("- Original workspace remains at: " + $dir.FullName)
        }
    }
    else {
        $externalReport.Add("- Not copied because automated evidence was not strong enough.")
        $externalReport.Add("- It remains listed for manual review by the next AI.")
    }

    $externalReport.Add("- Diff report: external_workspace_diffs\" + $safeName + ".md")
    $externalReport.Add("")
}

if ($Candidates.Count -eq 0) {
    $externalReport.Add("No external workspace candidate reached the detection threshold.")
}

[System.IO.File]::WriteAllLines($ExternalReportPath, $externalReport.ToArray(), $Utf8Bom)

$HandoffPath = Join-Path $BundlePath "HANDOFF.md"
$handoff = New-Object System.Collections.Generic.List[string]

$handoff.Add("# AI Coding Handoff")
$handoff.Add("")
$handoff.Add("This is the short entry point for the next coding AI.")
$handoff.Add("The bundle contains the project evidence, all related Codex sessions, recovered patches, and automatically discovered external workspaces.")
$handoff.Add("")
$handoff.Add("## Project")
$handoff.Add("")
$handoff.Add("- Path: " + $ProjectPath)
$handoff.Add("- Detected type: " + ($ProjectTypes -join ", "))
$handoff.Add("- Related Codex sessions copied in full: " + $RelatedDetails.Count)
$handoff.Add("- Recovered apply_patch payloads: " + $RecoveredPatchCount)
$handoff.Add("- External workspace candidates: " + $Candidates.Count)
$handoff.Add("- External workspaces copied in full: " + $CopiedExternalCount)
$handoff.Add("- External workspace copy failures: " + $FailedExternalCount)
$handoff.Add("")
$handoff.Add("## Read these first")
$handoff.Add("")
$handoff.Add("1. LAST_USER_PROMPT.md")
$handoff.Add("2. PRIMARY_TASK_PROMPT.md")
$handoff.Add("3. FEATURE_EVIDENCE.md")
$handoff.Add("4. EXTERNAL_WORKSPACES.md")
$handoff.Add("5. PATCH_INDEX.md")
$handoff.Add("6. PROJECT_SCAN.md")
$handoff.Add("7. SESSION_INDEX.md")
$handoff.Add("8. PROMPT_HISTORY.md")
$handoff.Add("9. SCRIPT_SETTINGS_SNAPSHOT.json")
$handoff.Add("")
$handoff.Add("The settings snapshot records the prompt language and name patterns excluded from project/workspace processing.")
$handoff.Add("")
$handoff.Add("IMPORTANT: Do not assume the main project directory contains the newest Codex work.")
$handoff.Add("External staging or worktree directories may contain newer changes.")
$handoff.Add("Review EXTERNAL_WORKSPACES.md and external_workspace_diffs before continuing.")
$handoff.Add("If an external workspace was copied, inspect external_workspaces before applying recovered patches.")
$handoff.Add("Recovered patches are a second recovery source if a staging workspace is missing or incomplete.")
$handoff.Add("")
$handoff.Add("## Last user prompt")
$handoff.Add("")

if ([string]::IsNullOrWhiteSpace($LastUserPrompt)) {
    $handoff.Add("No meaningful last user prompt was extracted.")
    $handoff.Add("Check PROMPT_HISTORY.md, transcripts, and raw sessions.")
}
else {
    $preview = Limit-TextSimple -Text $LastUserPrompt -MaxLength 5000
    Add-TextLines -Target $handoff -Text $preview

    if ($LastUserPrompt.Length -gt 5000) {
        $handoff.Add("")
        $handoff.Add("The prompt was truncated here. Read LAST_USER_PROMPT.md for the full text.")
    }
}

$handoff.Add("")
$handoff.Add("## Handoff task")
$handoff.Add("")
$handoff.Add("Another Codex session was interrupted during implementation.")
$handoff.Add("Reconstruct the task and verify every requested feature against actual code and runtime behavior.")
$handoff.Add("")
$handoff.Add("Classify every requested item as:")
$handoff.Add("- COMPLETED")
$handoff.Add("- PARTIALLY_COMPLETED")
$handoff.Add("- NOT_STARTED_OR_SKIPPED")
$handoff.Add("- UNCERTAIN")
$handoff.Add("")
$handoff.Add("For each classification, cite the actual file, function, component, route, handler, command, UI flow, or runtime result that proves it.")
$handoff.Add("Do not equate a text-search signal with functional completion.")
$handoff.Add("Do not ignore external_workspaces or recovered patches.")
$handoff.Add("Then continue only the missing or partial work while preserving working implementation.")

[System.IO.File]::WriteAllLines($HandoffPath, $handoff.ToArray(), $Utf8Bom)

$ManifestPath = Join-Path $BundlePath "BUNDLE_MANIFEST.md"
$manifest = New-Object System.Collections.Generic.List[string]

$manifest.Add("# Bundle Manifest")
$manifest.Add("")
$manifest.Add("Bundle path: " + $BundlePath)
$manifest.Add("Generated: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
$manifest.Add("")
$manifest.Add("- Project type: " + ($ProjectTypes -join ", "))
$manifest.Add("- Sessions copied: " + $RelatedDetails.Count)
$manifest.Add("- Patches recovered: " + $RecoveredPatchCount)
$manifest.Add("- External candidates: " + $Candidates.Count)
$manifest.Add("- External workspaces copied: " + $CopiedExternalCount)
$manifest.Add("- External copy failures: " + $FailedExternalCount)
$manifest.Add("- Prompt language: " + $script:PromptLanguage)
$manifest.Add("- Excluded folder name patterns: " + ($script:ExcludedFolderNames -join ", "))
$manifest.Add("- Excluded file name patterns: " + ($script:ExcludedFileNames -join ", "))
$manifest.Add("")
$manifest.Add("All related session files are copied without size limits.")
$manifest.Add("Eligible external workspaces are copied without size limits, except names excluded by script-settings.json.")
$manifest.Add("External workspace copies use all-or-fail semantics; failed partial copies are removed.")

[System.IO.File]::WriteAllLines($ManifestPath, $manifest.ToArray(), $Utf8Bom)

$ProjectArchivePath = Join-Path -Path $ProjectParent -ChildPath ($ProjectName + ".zip")
$BundleArchiveName = (Split-Path -Leaf $BundlePath) + ".zip"
$BundleArchivePath = Join-Path -Path $ProjectParent -ChildPath $BundleArchiveName

$archiveManifestLines = New-Object System.Collections.Generic.List[string]
$archiveManifestLines.Add("")
$archiveManifestLines.Add("## Generated archives")
$archiveManifestLines.Add("")
$archiveManifestLines.Add("- Project archive: " + $ProjectArchivePath)
$archiveManifestLines.Add("- Bundle archive: " + $BundleArchivePath)
$archiveManifestLines.Add("- Archive order: project ZIP, initial bundle ZIP, prompt generation, final bundle ZIP refresh.")
$archiveManifestLines.Add("- Project ZIP respects script-settings.json exclude rules.")
$archiveManifestLines.Add("- Bundle ZIP contains the complete generated handoff bundle.")
[System.IO.File]::AppendAllLines($ManifestPath, $archiveManifestLines.ToArray(), $Utf8Bom)

Write-Host ""
Write-Host "Creating project source ZIP before prompt generation..." -ForegroundColor Cyan
Write-Host $ProjectArchivePath -ForegroundColor DarkGray

New-ProjectSourceArchive -SourceRoot $ProjectPath -DestinationZip $ProjectArchivePath

Write-Host "Project source ZIP created." -ForegroundColor Green
Write-Host ""
Write-Host "Creating initial handoff bundle ZIP before prompt generation..." -ForegroundColor Cyan
Write-Host $BundleArchivePath -ForegroundColor DarkGray

New-HandoffBundleArchive -SourceRoot $BundlePath -DestinationZip $BundleArchivePath

Write-Host "Initial handoff bundle ZIP created." -ForegroundColor Green
Write-Host ""

if ($script:PromptLanguage -eq "en") {
    $PromptGeneratorFileName = "codex-handoff-prompt-generator-en.ps1"
    $PromptGeneratorFallbackPattern = "codex-handoff-prompt-generator-en*.ps1"
}
else {
    $PromptGeneratorFileName = "codex-handoff-prompt-generator-tr.ps1"
    $PromptGeneratorFallbackPattern = "codex-handoff-prompt-generator-tr*.ps1"
}

$PromptGenerator = Join-Path -Path $PSScriptRoot -ChildPath $PromptGeneratorFileName

if (-not (Test-Path -LiteralPath $PromptGenerator -PathType Leaf)) {
    $PromptGeneratorCandidate = Get-ChildItem -LiteralPath $PSScriptRoot -File -Filter $PromptGeneratorFallbackPattern -ErrorAction SilentlyContinue |
        Sort-Object -Property LastWriteTime -Descending |
        Select-Object -First 1

    if ($null -ne $PromptGeneratorCandidate) {
        $PromptGenerator = $PromptGeneratorCandidate.FullName
    }
}

if (Test-Path -LiteralPath $PromptGenerator -PathType Leaf) {
    Write-Host ("Prompt language: " + $script:PromptLanguage) -ForegroundColor Cyan
    Write-Host ("Prompt generator: " + $PromptGenerator) -ForegroundColor DarkGray

    # Do not use $LASTEXITCODE here. It belongs to the last native executable
    # and may still contain a successful robocopy status such as 1.
    $PromptGeneratorSucceeded = $true

    try {
        & $PromptGenerator -ProjectPath $ProjectPath -ProjectArchivePath $ProjectArchivePath -BundlePath $BundlePath -BundleArchivePath $BundleArchivePath

        if (-not $?) {
            $PromptGeneratorSucceeded = $false
        }
    }
    catch {
        $PromptGeneratorSucceeded = $false
        throw ("Prompt generator failed: " + $_.Exception.Message)
    }

    if (-not $PromptGeneratorSucceeded) {
        throw "Prompt generator reported failure."
    }

    Write-Host ""
    Write-Host "Refreshing handoff bundle ZIP so the generated prompt and omission report are included..." -ForegroundColor Cyan

    New-HandoffBundleArchive -SourceRoot $BundlePath -DestinationZip $BundleArchivePath

    Write-Host "Final handoff bundle ZIP refreshed." -ForegroundColor Green
}
else {
    Write-Warning ("Prompt generator not found for language '" + $script:PromptLanguage + "'. Expected: " + $PromptGeneratorFileName)
    Write-Warning "The project and initial bundle ZIP files were still created."
}

Write-Host ""
Write-Host "AI handoff process completed." -ForegroundColor Green
Write-Host ("Bundle folder: " + $BundlePath) -ForegroundColor Yellow
Write-Host ("Project ZIP: " + $ProjectArchivePath) -ForegroundColor Yellow
Write-Host ("Bundle ZIP: " + $BundleArchivePath) -ForegroundColor Yellow
Write-Host ""
Write-Host ("Sessions copied: " + $RelatedDetails.Count) -ForegroundColor Cyan
Write-Host ("Patches recovered: " + $RecoveredPatchCount) -ForegroundColor Cyan
Write-Host ("External workspaces copied: " + $CopiedExternalCount) -ForegroundColor Cyan

if ($FailedExternalCount -gt 0) {
    Write-Warning ("External workspace copy failures: " + $FailedExternalCount + ". Check EXTERNAL_WORKSPACES.md.")
}

Write-Host ""
Write-Host "Give the generated project ZIP and bundle ZIP to the next AI, together with the generated continuation prompt." -ForegroundColor Cyan
