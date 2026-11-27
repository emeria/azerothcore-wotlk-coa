import ast
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN = {'.mpq', '.dbc', '.wtf', '.wdb', '.pdb', '.dmp', '.pfx', '.pem'}
PATTERN = re.compile(rb'(?:github_pat_|gh[pousr]_|sk-proj-)[A-Za-z0-9_]{20,}')
ACCOUNT = re.compile(rb'(?i)WTF[/\\]+Account[/\\]+[^/\\\s"\x27]+@')
SYNTAX_EXCEPTIONS = {
    '.devcontainer/devcontainer.json': 'Upstream JSON-with-comments configuration',
    '.vscode/extensions.json': 'Upstream JSON-with-comments configuration',
    '.vscode/settings.json': 'Upstream JSON-with-comments configuration',
    'deps/libmpq/bindings/python/mpq.py': 'Preserved upstream Python 2 binding',
}


SHIPPED_DBC_DIR = 'modules/mod-coa-custom-races/data/dbc/'
SHIPPED_DBC_HASHES = {
    "Achievement.dbc": "dc9bcdb7feca2fe8c1fc4b0b6861e6a246c6d4861c3a032b9c6c64636a265e6f",
    "Achievement_Criteria.dbc": "855c80496f57aa6f3540f9d971351d436f8f2700b57171e6ca9fd419a77464f9",
    "AppearanceCategories.dbc": "c1528097731f5ecccfdfb54b5c7bf2f54b1679bbb902163da62ded344c435832",
    "CharBaseInfo.dbc": "5aa9dec708b38644d5e37f585bfc519afa63ab27d8a29bc147ef28b29a3553a0",
    "CharHairGeosets.dbc": "4080e3578d37435eccd86cd6a8e69e222f8107e981f7519f000d666b688644e3",
    "CharSections.dbc": "a522ab487c5de47f3a44950817991ce6ed929661d4b1e76833199ffd2b5948f4",
    "CharStartOutfit.dbc": "caef9f2adaf58c7f8d31cfe59fcfad0a1d11bb83ef53d83055bd3c56d010b76d",
    "CharacterCreationArchetypeDetails.dbc": "68515d13821b8384d88ec2c94387a2929a31256e38c485bb345d8b3f0ec27029",
    "CharacterCreationClassDetails.dbc": "8aaff2fd08959496ca6f83f5ffe49a9f0852e0bf3509a57896ba98e3f627587e",
    "CharacterCreationPetDetails.dbc": "fbca248ed9654c100f0ae072e862f47b60ff969de1f414865ce94e17456c205b",
    "CharacterCreationShapeshiftDetails.dbc": "a9fa4fb42726497b5b14582b215fcd73e3244d39c43507122e8687cec24f87ea",
    "CharacterFacialHairStyles.dbc": "dfb3dea785f11a099e2abf2920282235917273344a69fad95388c435adc2fcfc",
    "ChrRaces.dbc": "fad3687902584d0f9dc33afeaa3f61bd47aa153282683fe47865c33217046c7b",
    "CreatureDisplayInfo.dbc": "6b5d4dcacb8bad245490be6c5492f5e6a6aa99458fb84a1d38b96d56ae3b2136",
    "CreatureDisplayInfoGeosetData.dbc": "a5864d2505b150d745037dc3f2a85db84e9027238500665bcb7a36004bf7baf0",
    "CreatureModelData.dbc": "c43173a420152b611c61257382e94f918986a7596cbb92d1a84fac0788cef452",
    "CreatureSoundData.dbc": "baba49726c2d97e2e13669ed30176f78c530bbb9ec80a1c4498e7c3aa947a349",
    "EmotesTextSound.dbc": "070c4bd824f051d86a0d1b0d98d46768c246ff9a807b2b2aa390544ada31c550",
    "Faction.dbc": "065a60b57cba239a80c46456232142e56a883c952e93e1e5750ee378e7421ec0",
    "HDCharSections.dbc": "0b061fe4c1886000f9ab38e809c498487dc918e94c2f68b610e0de2ce5b97a06",
    "NameGen.dbc": "7755026437c25c56d76ae4060e01c7a409f99081243749c3275f49f8fbb50500",
    "NamesProfanity.dbc": "95907fe85af598465a785437fd8c5d4a2441e18c7109bfa2112d98b7faa23a0b",
    "NamesReserved.dbc": "95907fe85af598465a785437fd8c5d4a2441e18c7109bfa2112d98b7faa23a0b",
    "SkillLineAbility.dbc": "7fd79bc684c359504cd9852bb085a2cda119321934cc5e484458cfaeb90cfc39",
    "SkillRaceClassInfo.dbc": "c43f301e9388f963ea2d962b06fb40ce49a30df08689989cc9be6a1b291e2f47",
    "SoundEntries.dbc": "14379f04d0032e421f8d45582c8939e24d2dabdbbe75b05a34f4cc53c95a8b8b",
    "Talent.dbc": "b11369fc16b208507ef75f9201fac939fca090380c2eb7a3f5d0cca70500a7a1",
    "TaxiPath.dbc": "fbbb7fe1a195516f58cb34351cf867605efd78149ecff21916f41b19b7921331",
    "TaxiPathNode.dbc": "4224661f5be407b50b387d8b55042922a9c8f035b7f1dbe36dd0290f11f05008",
    "UICameraAppearanceChrRaces.dbc": "c245b7751088d2a027fd34cadffa5bc86988b079af74c3174e1554dbfcb89c93",
    "VocalUISounds.dbc": "45c783e13dfb792fe97ac018790f584f5a568a7c288c7a729c6d3fa74c330f58"
}


def is_shipped_dbc(name, raw):
    if not name.startswith(SHIPPED_DBC_DIR):
        return False
    return SHIPPED_DBC_HASHES.get(name.removeprefix(SHIPPED_DBC_DIR)) == hashlib.sha256(raw).hexdigest()


def main():
    git = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], cwd=ROOT, capture_output=True)
    if git.returncode == 0:
        paths = [ROOT / p.decode('utf-8') for p in git.stdout.split(b'\0') if p]
    else:
        paths = [p for p in ROOT.rglob('*') if p.is_file() and not {'.git', '.local', '__pycache__'} & set(p.relative_to(ROOT).parts)]
    issues = []
    checked = 0
    for path in paths:
        name = path.relative_to(ROOT).as_posix()
        if path.is_symlink():
            raw = os.readlink(path).encode('utf-8')
            target = path.resolve()
            if not target.is_relative_to(ROOT) or not target.exists():
                issues.append((name, 'broken or external symbolic link'))
        elif not path.is_file():
            issues.append((name, 'tracked file missing'))
            continue
        else:
            raw = path.read_bytes()
        if (path.suffix.lower() in FORBIDDEN and not is_shipped_dbc(name, raw)) or path.name == '.env' or '/WTF/' in '/' + name:
            issues.append((name, 'private/generated artifact'))
        if PATTERN.search(raw):
            issues.append((name, 'credential pattern'))
        if ACCOUNT.search(raw):
            issues.append((name, 'personal account path'))
        if path.suffix == '.ps1':
            lines = raw.decode('utf-8-sig').splitlines()
            for index, line in enumerate(lines):
                if re.search(r'(?i)password', line):
                    for follow in lines[index + 1:index + 4]:
                        if re.search(r'\.WriteLine\(\s*[\x27\x22][^\x27\x22]+[\x27\x22]\s*\)', follow):
                            issues.append((name, 'literal administrator credential after password prompt'))
                            break
        if path.suffix == '.py' and name not in SYNTAX_EXCEPTIONS:
            try:
                ast.parse(raw.decode('utf-8-sig'), filename=name)
            except (SyntaxError, UnicodeError) as error:
                issues.append((name, 'Python syntax: ' + type(error).__name__))
        if path.suffix == '.json' and name not in SYNTAX_EXCEPTIONS:
            try:
                json.loads(raw.decode('utf-8-sig'))
            except (ValueError, UnicodeError):
                issues.append((name, 'invalid JSON'))
        checked += 1
    print(json.dumps({'checkedFiles': checked, 'issues': issues,
                      'reviewedShippedDbc': [SHIPPED_DBC_DIR + name for name in sorted(SHIPPED_DBC_HASHES)],
                      'reviewedSyntaxExceptions': {name: reason for name, reason in SYNTAX_EXCEPTIONS.items() if (ROOT / name).is_file()},
                      'scope': 'tracked source artifact/credential patterns and Python/JSON syntax; not a complete secret/license audit'}, indent=2))
    return bool(issues)


if __name__ == '__main__':
    sys.exit(main())
