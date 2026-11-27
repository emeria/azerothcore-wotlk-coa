# coa-home

Build files for the `home` branch: the server that runs at home, built from this fork.

- `external-modules.json`: the modules that live in other repos, each pinned to a commit. The pins match what the live server runs (CoA Server Manager update 0.261125.124).
- `patches/`: CoA patches for three of those modules (SQUID, dungeon-clear, mod-pbc), copied unchanged from Corfirean/coa-server-build. `external-modules.json` holds their SHA-256. The repo's `.gitignore` ignores `*.patch`, so add new ones with `git add -f`.
- `Prepare-ExternalModules.ps1`: fetches each pinned repo into `C:\wow-server\coa\src\<repo>-<sha8>`, applies its patch, and joins it into `modules\` with a junction.
- `Configure-HomeBuild.ps1`: configures a Release build with the flags from `.github/workflows/coa-bots-build.yml`.

## Build

```powershell
pwsh -NoProfile -File coa-home\Prepare-ExternalModules.ps1
pwsh -NoProfile -File coa-home\Configure-HomeBuild.ps1 -Build C:\wow-server\coa\build
cmake --build C:\wow-server\coa\build --config Release
```

Output: `C:\wow-server\coa\build\bin\Release\worldserver.exe` and `authserver.exe`.

Needs Visual Studio Build Tools 2022, CMake, Boost 1.87 (`C:\local\boost_1_87_0`), OpenSSL 3 (`C:\Program Files\OpenSSL-Win64`) and the MySQL 8.4 client (`C:\tools\mysql\current`).

## Moving a pin

Change the `sha` in `external-modules.json` and run the prepare script again. It fetches the new commit into a new folder and moves the junction. If a patch no longer applies, take the new one from coa-server-build and update `patchSha256`.

mod-coa-playerbots (CoA Companions) and mod-playerbots (SQUID) are both compiled in. Only one may be enabled at run time; the Manager refuses to start the server with both on.
