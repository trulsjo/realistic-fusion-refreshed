#Requires -Version 7
<#
.SYNOPSIS
    Build one distributable zip per mod, named the way the mod portal requires.

.DESCRIPTION
    Turns each of this repository's mod directories into a zip a player could install, and reports
    what each one weighs. It uploads nothing and it changes no version -- the version is read out of
    each mod's own info.json and never written.

    WHY THE ZIP IS WORTH BUILDING AT ALL, given nothing is published yet. Every check in this
    repository runs off junctions: dev-launch.ps1 and each check-*.ps1 link the mod directories into
    a scratch mod directory and let Factorio read the repo in place. So "it loads" currently means
    "it loads when the game can see the working tree". A file that resolves through a junction but
    never makes it into a zip fails for a player and for nobody else -- the same shape as the stale
    dependency floor ADR 0023 records, and it wants the same answer: exercise the path the player is
    actually on. `load-check.ps1 -FromZips` is that exercise, and this script is what it runs.

    WHAT GOES IN, AND WHY IT IS NOT A DENYLIST. The file list comes from `git ls-files` -- every
    tracked path under the mod directory -- rather than from walking the filesystem and skipping
    known junk. A denylist is wrong here by construction: `.omc/state/` has already appeared inside
    graphics/krastorio-2/buildings/ in this repo, and the next stray directory will be named
    something else. Tracking is the allowlist, and it is the same answer as "what is this mod",
    which is the question being asked.

    Content is read from the WORKING TREE, not from the index. Only the path list comes from git.
    That distinction is deliberate: packing the index would mean `-FromZips` silently checked
    committed content while you edited something else, which is the exact failure mode a check like
    that exists to remove. Uncommitted edits are packed; untracked files are not, and are reported
    rather than dropped in silence.

    THE ZIP NAME IS THE STRICT PART, NOT THE FOLDER. Verified against the 2.0.77 mod-structure
    documentation: the zip must be named `{mod-name}_{version-number}` -- the example given is
    `better-armor_0.3.6` -- while "the folder inside the zip file does not have any naming
    restrictions". info.json must sit in that top-level folder. So the name is computed from
    info.json rather than passed in, because a name passed in is a name that can disagree with the
    mod it labels.

.PARAMETER OutputDirectory
    Where to write the zips. Defaults to dist/ beside the repository root, which is git-ignored.

.PARAMETER SelfTest
    Verify this script can fail. Packs into a scratch directory and checks that the naming, the
    layout and -- the half that matters -- the exclusion actually hold, by planting an ignored file
    inside a mod directory and proving it does not reach the zip. Without that half, "no junk in the
    zip" is a claim about a directory that happened to be clean.

.EXAMPLE
    pwsh -File scripts/pack-mods.ps1
    pwsh -File scripts/pack-mods.ps1 -OutputDirectory C:\somewhere\else
    pwsh -File scripts/pack-mods.ps1 -SelfTest
#>
[CmdletBinding()]
param(
    [string] $OutputDirectory,
    [switch] $SelfTest
)

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/factorio-lib.ps1"

Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = Split-Path $PSScriptRoot -Parent

function Get-ModManifest {
    <#  What a mod is called, what version it declares, and which files belong to it.

        The name is checked against the directory rather than trusted, because everything
        downstream is named from info.json while the directory is what Get-RepoMods hands out. Let
        those two disagree and the zip is named after one mod and filled with another -- which the
        portal would accept, since it only reads the name.  #>
    param([Parameter(Mandatory)] [string] $Mod)

    $modDir = Join-Path $repoRoot $Mod
    if (-not (Test-Path -LiteralPath $modDir)) { throw "mod directory not found: $modDir" }

    $infoPath = Join-Path $modDir 'info.json'
    if (-not (Test-Path -LiteralPath $infoPath)) { throw "$Mod has no info.json" }
    $info = Get-Content -LiteralPath $infoPath -Raw | ConvertFrom-Json

    if ($info.name -ne $Mod) {
        throw "$Mod/info.json declares name '$($info.name)'. The zip is named from info.json and the files come from the directory, so these must agree."
    }
    # major.minor.sub, each 0-65535, and 0.0.0 invalid -- the shape the changelog format and the
    # portal both require. The bounds are enforced rather than only described: a regex of three
    # digit-runs accepts 0.0.0 and 1.0.99999, which the portal rejects at upload, and this check
    # exists precisely so that a version nobody questions does not become a zip filename nobody
    # reads twice.
    if ($info.version -notmatch '^\d{1,5}\.\d{1,5}\.\d{1,5}$') {
        throw "$Mod/info.json version '$($info.version)' is not major.minor.sub."
    }
    $parts = @($info.version -split '\.' | ForEach-Object { [int]$_ })
    if ($parts | Where-Object { $_ -gt 65535 }) {
        throw "$Mod/info.json version '$($info.version)' has a component above 65535."
    }
    if (($parts | Measure-Object -Sum).Sum -eq 0) {
        throw "$Mod/info.json version is 0.0.0, which Factorio rejects."
    }

    # -c core.quotePath=false, because the default is true and it is not cosmetic here: a tracked
    # path holding any non-ASCII byte comes back C-quoted ("mod/caf\303\251.png"), Test-Path then
    # misses it, and Write-ModZip throws "tracked but not on disk" about a file that is on disk.
    # That message sends whoever hits it looking for a deletion that never happened, and it blocks
    # packing entirely. No such path exists in this repo today; the flag is what keeps that true
    # from mattering.
    $tracked = @(git -C $repoRoot -c core.quotePath=false ls-files --cached -- $Mod)
    if ($LASTEXITCODE -ne 0) { throw "git ls-files failed for $Mod." }
    if (-not $tracked) { throw "$Mod has no tracked files; there would be nothing to ship." }

    [pscustomobject]@{
        Name    = $info.name
        Version = $info.version
        ZipName = "$($info.name)_$($info.version).zip"
        Files   = $tracked
    }
}

function Write-ModZip {
    <#  Write one mod's zip. Entries are the tracked paths verbatim, which already begin with the
        mod directory name -- so the required single top-level folder falls out of the path list
        rather than being assembled, and cannot drift from it.  #>
    param(
        [Parameter(Mandatory)] [pscustomobject] $Manifest,
        [Parameter(Mandatory)] [string]         $Destination
    )

    # Built under a temporary name and moved into place only on success. Disposing a ZipArchive
    # writes a valid central directory whatever happened before it, so a throw partway through the
    # loop -- the tracked-but-missing guard below is the one that fires -- would otherwise leave a
    # zip in dist/ that opens cleanly and is quietly missing every file after the failure point.
    # An artefact that looks finished and is not is worse than no artefact.
    $partial = "$Destination.partial"
    if (Test-Path -LiteralPath $partial) { Remove-Item -LiteralPath $partial -Force }

    $zip = [IO.Compression.ZipFile]::Open($partial, 'Create')
    try {
        foreach ($rel in $Manifest.Files) {
            $full = Join-Path $repoRoot $rel
            # A tracked path with no file behind it means the working tree is mid-delete. Packing
            # around it would ship a mod missing a file that every other check still sees.
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
                throw "$rel is tracked but not on disk. Commit the deletion or restore the file before packing."
            }
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip, $full, $rel, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        }
    }
    catch {
        $zip.Dispose()
        Remove-Item -LiteralPath $partial -Force -ErrorAction SilentlyContinue
        throw
    }
    $zip.Dispose()

    if (Test-Path -LiteralPath $Destination) { Remove-Item -LiteralPath $Destination -Force }
    Move-Item -LiteralPath $partial -Destination $Destination
}

function Invoke-Pack {
    <#  Pack every mod into $Destination and return what was written.  #>
    param([Parameter(Mandatory)] [string] $Destination, [switch] $Quiet)

    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    $built = @()

    foreach ($mod in Get-RepoMods) {
        $manifest = Get-ModManifest -Mod $mod

        # Reported, never silently dropped. An untracked sprite is invisible to git ls-files, so it
        # would be missing from the zip while every junction-mode check still resolved it -- a pass
        # here and a broken mod for a player, which is the failure this whole path exists to catch.
        $untracked = @(git -C $repoRoot -c core.quotePath=false ls-files --others --exclude-standard -- $mod)
        if ($untracked) {
            Write-Warning "$mod has $($untracked.Count) untracked file(s), which will NOT be in the zip:"
            foreach ($u in $untracked | Select-Object -First 5) { Write-Warning "    $u" }
        }

        $path = Join-Path $Destination $manifest.ZipName
        Write-ModZip -Manifest $manifest -Destination $path
        $built += [pscustomobject]@{
            Mod   = $mod
            Zip   = $path
            Files = $manifest.Files.Count
            Bytes = (Get-Item -LiteralPath $path).Length
        }
    }

    if (-not $Quiet) {
        $total = ($built | Measure-Object -Property Bytes -Sum).Sum
        foreach ($b in $built) {
            Write-Host ("{0,-44} {1,5} files{2,10}" -f (Split-Path $b.Zip -Leaf), $b.Files, (Format-Bytes $b.Bytes))
        }
        Write-Host ("{0,-44} {1,11}{2,10}" -f '', '', (Format-Bytes $total))
    }

    return $built
}

function Format-Bytes {
    <#  Invariant culture on purpose: these figures get quoted in ADRs and issues, and a decimal
        comma on one machine against a point on another is noise in a number people compare.  #>
    param([long] $Bytes)
    $c = [cultureinfo]::InvariantCulture
    if ($Bytes -ge 1MB) { return ((($Bytes / 1MB)).ToString('N1', $c) + ' MB') }
    if ($Bytes -ge 1KB) { return ((($Bytes / 1KB)).ToString('N0', $c) + ' KB') }
    return "$Bytes B"
}

if ($SelfTest) {
    $scratch = Join-Path ([IO.Path]::GetTempPath()) ('rf-pack-selftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    # Inside a mod directory on purpose, and under .omc/ on purpose: that is a real path that has
    # really held stray state in this repository, and it is git-ignored, so a filesystem walk would
    # ship it and `git ls-files` will not.
    # The plant has to be IGNORED, not merely untracked, or it demonstrates the wrong thing --
    # git ls-files --cached excludes untracked files too, so an untracked plant would be absent from
    # the zip without the ignore rule doing any work. .gitignore's rule is `.omc/`, which matches a
    # directory called exactly that, so the plant lives UNDER .omc in a uniquely named subdirectory.
    #
    # The subdirectory is what makes cleanup safe. An earlier version planted directly into
    # <mod>/prototypes/.omc and removed that whole directory afterwards, which would have destroyed
    # real OMC state had any been sitting there -- and this script's own docstring is the record
    # that such state does land inside mod directories; two .omc directories exist under
    # realistic-fusion-refreshed/ as this is written. Only what was created here is removed.
    $omcDir      = Join-Path $repoRoot 'realistic-fusion-refreshed-core/prototypes/.omc'
    $omcPreExisted = Test-Path -LiteralPath $omcDir
    $plantedDir  = Join-Path $omcDir ('packselftest-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    $plantedFile = Join-Path $plantedDir 'selftest-junk.json'
    $failures = [System.Collections.Generic.List[string]]::new()

    try {
        New-Item -ItemType Directory -Path $plantedDir -Force | Out-Null
        Set-Content -LiteralPath $plantedFile -Value '{"selftest":true}' -Encoding utf8

        # Prove the plant is really IGNORED, not just untracked, or the exclusion assert below
        # proves nothing: --others --exclude-standard lists untracked-but-not-ignored files, so a
        # hit here means the plant would have been left out for the wrong reason.
        $plantedRel = $plantedFile.Substring($repoRoot.Length + 1).Replace('\', '/')
        $seen = @(git -C $repoRoot -c core.quotePath=false ls-files --cached --others --exclude-standard -- 'realistic-fusion-refreshed-core')
        if ($seen -contains $plantedRel) {
            $failures.Add("the planted file is not git-ignored ($plantedRel), so it cannot demonstrate the exclusion")
        }
        $ignored = @(git -C $repoRoot -c core.quotePath=false ls-files --others --ignored --exclude-standard -- 'realistic-fusion-refreshed-core')
        if ($ignored -notcontains $plantedRel) {
            $failures.Add("the planted file is not reported as ignored ($plantedRel); the exclusion would be untested")
        }

        $built = Invoke-Pack -Destination $scratch -Quiet
        if ($built.Count -lt 3) { $failures.Add("packed $($built.Count) mod(s); expected the three this repo publishes") }

        foreach ($b in $built) {
            $manifest = Get-ModManifest -Mod $b.Mod
            $leaf = Split-Path $b.Zip -Leaf
            if ($leaf -ne "$($b.Mod)_$($manifest.Version).zip") {
                $failures.Add("$($b.Mod) packed as '$leaf', not '{mod-name}_{version}.zip'")
            }

            $zip = [IO.Compression.ZipFile]::OpenRead($b.Zip)
            try {
                $names = @($zip.Entries | ForEach-Object { $_.FullName })
                if ($names -notcontains "$($b.Mod)/info.json") {
                    $failures.Add("$($b.Mod): info.json is not in the top-level folder inside the zip")
                }
                $outside = @($names | Where-Object { $_ -notlike "$($b.Mod)/*" })
                if ($outside) {
                    $failures.Add("$($b.Mod): $($outside.Count) entr(y/ies) outside the single top-level folder, e.g. $($outside[0])")
                }
                if ($names | Where-Object { $_ -match '(^|/)\.omc' }) {
                    $failures.Add("$($b.Mod): ignored .omc state reached the zip")
                }
            }
            finally { $zip.Dispose() }
        }

        # The falsifiable half: the planted file exists on disk, inside a packed mod, right now.
        $coreZip = ($built | Where-Object { $_.Mod -eq 'realistic-fusion-refreshed-core' }).Zip
        $zip = [IO.Compression.ZipFile]::OpenRead($coreZip)
        try {
            if ($zip.Entries | Where-Object { $_.FullName -like '*selftest-junk.json' }) {
                $failures.Add('the planted ignored file WAS packed; the exclusion does not work')
            }
            if (-not ($zip.Entries | Where-Object { $_.FullName -eq 'realistic-fusion-refreshed-core/prototypes/entities.lua' })) {
                $failures.Add('a tracked file next to the plant was missing; the exclusion is too broad')
            }
        }
        finally { $zip.Dispose() }
    }
    finally {
        # Only what this created. The .omc directory itself goes only if it was not there before and
        # is empty now -- anything else in it is somebody's state, not this test's litter.
        Remove-Item -LiteralPath $plantedDir -Recurse -Force -ErrorAction SilentlyContinue
        if (-not $omcPreExisted -and (Test-Path -LiteralPath $omcDir)) {
            if (-not (Get-ChildItem -LiteralPath $omcDir -Force)) {
                Remove-Item -LiteralPath $omcDir -Force -ErrorAction SilentlyContinue
            }
        }
        Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($failures.Count) {
        Write-Host ''
        foreach ($f in $failures) { Write-Host "FAIL  $f" -ForegroundColor Red }
        exit 1
    }
    Write-Host 'OK - self-test passed: zips are named {mod-name}_{version}, info.json sits in a single'
    Write-Host '     top-level folder, and a git-ignored file planted inside a mod did not reach the zip'
    Write-Host '     while its tracked neighbour did.'
    exit 0
}

$explicitOutput = [bool]$OutputDirectory
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }
$built = Invoke-Pack -Destination $OutputDirectory

if (-not $explicitOutput) {
    Write-Host ''
    Write-Host "wrote $($built.Count) zip(s) to $OutputDirectory"
    Write-Host 'Nothing is uploaded and no version is changed. To prove these load, run:'
    Write-Host '  pwsh -File scripts/load-check.ps1 -FromZips'
}
exit 0
