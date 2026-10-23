#!/usr/bin/env python3
"""Validate a portable ZIP independently of the publishing machine."""
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import sys
import zipfile

spec=importlib.util.spec_from_file_location('approved_assets',Path(__file__).with_name('prepare-assets.py'))
assets=importlib.util.module_from_spec(spec);spec.loader.exec_module(assets)

def verify(path):
    with zipfile.ZipFile(path) as archive:
        names=archive.namelist()
        if len(names)!=len(set(names)):raise ValueError('Duplicate ZIP members')
        if any(n.startswith(('/','\\')) or '..' in Path(n.replace('\\','/')).parts for n in names):raise ValueError('Unsafe ZIP member')
        root='YierBubu/'
        for component in ('Microsoft.NETCore.App','Microsoft.WindowsDesktop.App'):
            prefix=root+'RuntimeNotices/'+component+'/'
            if not any(n.startswith(prefix) and Path(n).name.lower() in ('license','license.txt') for n in names):raise ValueError('Missing runtime license: '+component)
        if not any(n.startswith(root+'RuntimeNotices/Microsoft.NETCore.App/') and 'third' in Path(n).name.lower() for n in names):raise ValueError('Missing .NET third-party notices')
        exe=archive.read(root+'YierBubu.exe')
        if len(exe)<64 or exe[:2]!=b'MZ':raise ValueError('Not a Windows executable')
        offset=struct.unpack_from('<I',exe,0x3c)[0]
        if offset+6>len(exe) or exe[offset:offset+4]!=b'PE\0\0' or struct.unpack_from('<H',exe,offset+4)[0]!=0x8664:raise ValueError('Not a Windows x64 PE')
        config=json.loads(archive.read(root+'YierBubu.runtimeconfig.json').decode('utf-8-sig'))
        if not config['runtimeOptions'].get('includedFrameworks'):raise ValueError('Not self-contained')
        for name,sha in assets.LAYERS.items():
            data=archive.read(root+'Assets/'+name);assets.validate_png(data,1536,1024)
            if hashlib.sha256(data).hexdigest()!=sha:raise ValueError('Runtime PNG hash mismatch')
        info=json.loads(archive.read(root+'RELEASE-INFO.json').decode('utf-8-sig'))
        if info['platform']!='win-x64' or not info['selfContained']:raise ValueError('Incorrect release metadata')
        print('Verified x64 PE, self-contained runtime, approved artwork and runtime notices:',len(names),'files')
        return info
if __name__=='__main__':verify(Path(sys.argv[1]))
