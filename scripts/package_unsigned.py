#!/usr/bin/env python3
"""Package a device build for re-signing; verify every Mach-O is unsigned."""
import hashlib
import plistlib
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

app, output = map(lambda value: Path(value).resolve(), sys.argv[1:3])
if not app.is_dir() or app.suffix != '.app':
    raise SystemExit('Expected an existing device .app bundle')
output.parent.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix='jector-ipa-') as directory:
    staging = Path(directory)
    target = staging / 'Payload' / 'Jector.app'
    shutil.copytree(app, target, symlinks=True)
    info = plistlib.loads((target / 'Info.plist').read_bytes())
    assert info['CFBundleDisplayName'] == 'Jector'
    assert info['CFBundleExecutable'] == 'Jector'
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS']
    assert not list(target.rglob('*.gguf')), 'Model weights must not be bundled'
    binaries = []
    for path in target.rglob('*'):
        if path.is_symlink():
            raise SystemExit(f'Unexpected symlink in device app: {path}')
        if not path.is_file():
            continue
        kind = subprocess.check_output(['file', '-b', str(path)], text=True)
        if 'Mach-O' in kind:
            binaries.append(path)
            signed = subprocess.run(['codesign', '-d', str(path)], capture_output=True)
            if signed.returncode == 0:
                subprocess.run(['codesign', '--remove-signature', str(path)], check=True)
    for path in list(target.rglob('_CodeSignature')):
        shutil.rmtree(path)
    for path in list(target.rglob('embedded.mobileprovision')):
        path.unlink()
    assert binaries, 'No Mach-O executable found'
    for path in binaries:
        load_commands = subprocess.check_output(['otool', '-l', str(path)], text=True)
        assert 'LC_CODE_SIGNATURE' not in load_commands, f'Signature remains: {path}'
    with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(target.rglob('*')):
            if path.is_file():
                archive.write(path, path.relative_to(staging))
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        assert 'Payload/Jector.app/Jector' in archive.namelist()
    print(f'Unsigned device IPA: {output} ({len(binaries)} verified Mach-O binaries)')
checksum = hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix(output.suffix + '.sha256').write_text(f'{checksum}  {output.name}\n')
print(f'SHA-256: {checksum}')
