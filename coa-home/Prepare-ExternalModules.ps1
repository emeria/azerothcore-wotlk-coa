# Puts the external modules listed in external-modules.json into <Core>\modules.
#
# Each repo is fetched once per pinned commit into <SrcRoot>\<repo>-<sha8>, then
# <Core>\modules\<folder> is made a junction to it (or to its subdir). modules\* is
# gitignored apart from the in-repo modules, so the junctions don't show in git status.
#
# Patches follow Corfirean/coa-server-build scripts/prepare-external-modules.py: the
# checkout must be at the pinned commit, the patch must match its SHA-256, and a
# checkout that already has changes must hold exactly that patch.
param(
    [string]$Core = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$SrcRoot = 'C:\wow-server\coa\src'
)
$ErrorActionPreference = 'Stop'

$definition = Get-Content "$PSScriptRoot\external-modules.json" -Raw | ConvertFrom-Json
if ($definition.schema -ne 1) { throw 'Unknown external-modules.json schema' }

function Invoke-Git {
    $output = & git @args 2>&1
    if ($LASTEXITCODE) { throw "git $($args -join ' ') failed: $output" }
    $output
}

$patched = @{}
foreach ($module in $definition.modules) {
    if ($module.repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Bad repository: $($module.repository)" }
    if ($module.sha -notmatch '^[a-f0-9]{40}$') { throw "$($module.folder) needs a full commit SHA" }

    $clone = Join-Path $SrcRoot ("{0}-{1}" -f ($module.repository -split '/')[1], $module.sha.Substring(0, 8))
    if (-not (Test-Path $clone)) {
        New-Item -ItemType Directory -Force $clone | Out-Null
        Invoke-Git -C $clone init -q | Out-Null
        Invoke-Git -C $clone remote add origin "https://github.com/$($module.repository).git" | Out-Null
        Invoke-Git -C $clone fetch -q --depth=1 origin $module.sha | Out-Null
        Invoke-Git -C $clone checkout -q --detach FETCH_HEAD | Out-Null
    }
    if ((Invoke-Git -C $clone rev-parse HEAD) -ne $module.sha) { throw "$clone is not at $($module.sha)" }

    $changes = (Invoke-Git -C $clone diff --binary --full-index HEAD --) -join "`n"
    if ($module.patch) {
        $patch = Join-Path $PSScriptRoot $module.patch
        if ((Get-FileHash $patch -Algorithm SHA256).Hash.ToLower() -ne $module.patchSha256) { throw "Patch checksum differs: $($module.patch)" }
        if (-not $changes) {
            Invoke-Git -C $clone apply --index $patch | Out-Null
        } elseif (-not $patched.ContainsKey($clone)) {
            Invoke-Git -C $clone apply --check --reverse $patch | Out-Null
        }
        $patched[$clone] = $true
    } elseif ($changes -and -not $patched.ContainsKey($clone)) {
        throw "$clone has local changes but no patch is listed for it"
    }

    $target = if ($module.subdir) { Join-Path $clone $module.subdir } else { $clone }
    if (-not (Test-Path "$target\src")) { throw "$target has no src folder" }

    $link = Join-Path $Core "modules\$($module.folder)"
    if (Test-Path $link) {
        $item = Get-Item $link -Force
        if ($item.LinkType -ne 'Junction') { throw "$link is a real folder; move it away first" }
        if ($item.Target -ne $target) { $item.Delete() }
    }
    if (-not (Test-Path $link)) { New-Item -ItemType Junction -Path $link -Target $target | Out-Null }
    $note = if ($module.patch) { " + $($module.patch)" } else { '' }
    "$($module.folder) -> $target ($($module.sha.Substring(0, 8))$note)"
}
