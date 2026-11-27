# Configures an out-of-source Release build of this checkout.
# Flags follow .github/workflows/coa-bots-build.yml, except the generator: Visual Studio 2022
# here (multi-config, so build with --config Release), Ninja + RelWithDebInfo in CI.
# Run Prepare-ExternalModules.ps1 first.
param(
    [string]$Source = (Resolve-Path "$PSScriptRoot\..").Path,
    [string]$Build = 'C:\wow-server\coa\build',
    [string]$BoostRoot = 'C:\local\boost_1_87_0',
    [string]$OpenSslRoot = 'C:\Program Files\OpenSSL-Win64',
    [string]$MySqlRoot = 'C:\tools\mysql\current'
)
$ErrorActionPreference = 'Stop'

$modules = (Get-Content "$PSScriptRoot\external-modules.json" -Raw | ConvertFrom-Json).modules.folder
foreach ($m in $modules) {
    if (-not (Test-Path "$Source\modules\$m\src")) { throw "modules\$m\src is missing; run coa-home\Prepare-ExternalModules.ps1 first" }
}

cmake -S $Source -B $Build -G 'Visual Studio 17 2022' -A x64 `
    -DAPPS_BUILD=all -DTOOLS_BUILD=none `
    -DSCRIPTS=static -DMODULES=static `
    -DUSE_COREPCH=1 -DUSE_SCRIPTPCH=1 `
    "-DBOOST_ROOT=$BoostRoot" `
    "-DMYSQL_INCLUDE_DIR=$MySqlRoot/include" `
    "-DMYSQL_LIBRARY=$MySqlRoot/lib/mysqlclient.lib" `
    "-DOPENSSL_ROOT_DIR=$OpenSslRoot"
exit $LASTEXITCODE
