#!/usr/bin/env python3
"""Prepare approved runtime art. Character assets are NOT covered by code MIT."""
import argparse
import hashlib
from pathlib import Path
import shutil
import struct
import tempfile
import urllib.request
import zipfile

SOURCE_URL='https://github.com/Li-Jiangjiu/YierBubu/releases/download/v0.4.0-beta.3/YierBubu-macOS-Universal-v0.4.0-beta.3.zip'
SOURCE_SHA256='e4aa6030330ec0fdbb31bd63d6739793f1086cacf82b4eea1e4187ed8ddaed6b'
LAYERS={
 'compact-scene.png':'67cf9f967fe6bb3370dbaa1a6501e4f5a1705417c6e220e5648f1eed3a91abe7',
 'compact-cleanplate.png':'d9fb6272ef3f0b79ecee602f133a3c585110eab628389c9b1955a45d6b0995ba',
 'compact-paws.png':'663d0edec1eb9b14781c1216f22b00b8a804a02852e0e7b261a257f16817c481'}

def validate_png(data,width,height):
    if len(data)<24 or data[:8]!=b'\x89PNG\r\n\x1a\n' or data[12:16]!=b'IHDR' or struct.unpack('>II',data[16:24])!=(width,height):
        raise ValueError('Invalid PNG dimensions or header')

def icon_from_icns(data):
    if len(data)<8 or data[:4]!=b'icns' or struct.unpack('>I',data[4:8])[0]!=len(data):
        raise ValueError('Invalid ICNS container')
    offset=8
    while offset+8<=len(data):
        kind,size=struct.unpack('>4sI',data[offset:offset+8])
        if size<8 or offset+size>len(data):raise ValueError('Invalid ICNS chunk')
        png=data[offset+8:offset+size]
        if kind==b'ic08':
            validate_png(png,256,256)
            return struct.pack('<HHH',0,1,1)+struct.pack('<BBBBHHII',0,0,0,0,1,32,len(png),22)+png
        offset+=size
    raise ValueError('Missing 256px PNG icon')

def write_assets(layers,icon,output):
    # Validate everything before mutating the destination.
    for name,sha in LAYERS.items():
        validate_png(layers[name],1536,1024)
        if hashlib.sha256(layers[name]).hexdigest()!=sha:raise ValueError('Runtime artwork SHA256 mismatch: '+name)
    ico=icon_from_icns(icon)
    output.mkdir(parents=True,exist_ok=True)
    for name,data in layers.items():(output/name).write_bytes(data)
    (output/'YierBubu.ico').write_bytes(ico)

def extract(archive,output,expected_hash=SOURCE_SHA256):
    data=Path(archive).read_bytes()
    if hashlib.sha256(data).hexdigest()!=expected_hash:raise ValueError('Source ZIP SHA256 mismatch')
    with zipfile.ZipFile(archive) as z:
        def get(suffix):
            matches=[i for i in z.infolist() if i.filename.endswith(suffix) and not i.filename.startswith('__MACOSX/')]
            if len(matches)!=1:raise ValueError('Missing or ambiguous runtime resource: '+suffix)
            if matches[0].file_size>16*1024*1024:raise ValueError('Runtime resource too large')
            return z.read(matches[0])
        layers={n:get('/YierBubu.app/Contents/Resources/Layered/'+n) for n in LAYERS}
        icon=get('/YierBubu.app/Contents/Resources/YierBubu.icns')
    write_assets(layers,icon,Path(output))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output',type=Path,default=Path(__file__).resolve().parents[1]/'assets')
    p.add_argument('--local-resources',type=Path)
    p.add_argument('--archive',type=Path)
    a=p.parse_args()
    if a.local_resources:
        write_assets({n:(a.local_resources/'Layered'/n).read_bytes() for n in LAYERS},(a.local_resources/'Icon/YierBubu.icns').read_bytes(),a.output)
    elif a.archive:extract(a.archive,a.output)
    else:
        with tempfile.TemporaryDirectory(prefix='yierbubu-assets-') as d:
            target=Path(d)/'approved-macos.zip'
            with urllib.request.urlopen(SOURCE_URL,timeout=120) as r,target.open('wb') as f:shutil.copyfileobj(r,f)
            extract(target,a.output)
    print('Approved 3-layer assets and Windows icon validated. Artwork rights remain separate from MIT.')
if __name__=='__main__':main()
