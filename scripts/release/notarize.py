"""Notarize explicitly signed candidates using a preconfigured Keychain profile."""
import argparse
import json
from pathlib import Path
import plistlib
import shutil
import tempfile
from common import ROOT, ReleaseError, entry, run, sha256, new_output
from package import verify


def notarize(path, profile):
    result = json.loads(run("xcrun", "notarytool", "submit", path, "--keychain-profile", profile,
                            "--wait", "--output-format", "json"))
    if result.get("status") != "Accepted":
        raise ReleaseError(f"Notarization did not succeed: {result.get('status')}, id {result.get('id')}")
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app")
    parser.add_argument("--keychain-profile", required=True)
    args = parser.parse_args()
    import os
    app = Path(os.path.abspath(args.app))
    for component in (app, *app.parents):
        if component.is_symlink():
            raise ReleaseError(f"Candidate path contains a symlink: {component}")
    base = ROOT / "output/releases"
    if base not in app.parents:
        raise ReleaseError("Only candidates inside output/releases can be notarized")
    if app.name != "YierBubu.app" or app.parent.name != "SIGNED-UNNOTARIZED" or app.parent.parent == base:
        raise ReleaseError("Invalid candidate layout; expected output/releases/<candidate>/SIGNED-UNNOTARIZED/YierBubu.app")
    final = new_output(app.parent.parent / "FINAL")
    verify(app)
    import subprocess
    result = subprocess.run(["codesign", "-dv", "--verbose=4", str(app)], capture_output=True, text=True)
    details = result.stderr
    if "Authority=Developer ID Application:" not in details or "runtime" not in details:
        raise ReleaseError("A hardened-runtime Developer ID Application signature is required")
    scratch = Path(tempfile.mkdtemp(prefix=".notary-", dir=app.parent.parent))
    try:
        working = scratch / "YierBubu.app"
        run("ditto", app, working)
        archive = scratch / "submission.zip"
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", working, archive)
        app_result = notarize(archive, args.keychain_profile)
        run("xcrun", "stapler", "staple", working)
        run("xcrun", "stapler", "validate", working)
        run("spctl", "--assess", "--type", "execute", "--verbose=2", working)
        verify(working)
        image_root = scratch / "image"
        image_root.mkdir()
        run("ditto", working, image_root / "YierBubu.app")
        (image_root / "Applications").symlink_to("/Applications")
        info = plistlib.loads((working / "Contents/Info.plist").read_bytes())
        name = f"YierBubu-macOS-Universal-v{info['CFBundleShortVersionString']}.dmg"
        dmg = scratch / name
        run("hdiutil", "create", "-volname", "一二布布", "-srcfolder", image_root,
            "-format", "UDZO", dmg)
        # Sign container with the same explicitly configured Developer ID identity.
        authority = next(line[len("Authority="):] for line in details.splitlines()
                         if line.startswith("Authority=Developer ID Application:"))
        run("codesign", "--sign", authority, "--timestamp", dmg)
        dmg_result = notarize(dmg, args.keychain_profile)
        run("xcrun", "stapler", "staple", dmg)
        run("xcrun", "stapler", "validate", dmg)
        run("hdiutil", "verify", dmg)
        run("spctl", "--assess", "--type", "open", "--context", "context:primary-signature", dmg)
        finished = scratch / "final"
        finished.mkdir()
        shutil.move(dmg, finished / name)
        (finished / "SHA256SUMS.txt").write_text(f"{sha256(finished / name)}  {name}\n")
        (finished / "NOTARIZATION.json").write_text(json.dumps({"app": app_result, "dmg": dmg_result}, indent=2) + "\n")
        finished.rename(final)
        print(final)
    finally:
        shutil.rmtree(scratch)


if __name__ == "__main__":
    entry(main)
