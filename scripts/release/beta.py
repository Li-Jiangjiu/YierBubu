"""Produce explicitly unnotarized beta ZIP/DMG downloads from a verified app."""
import argparse
import json
import os
from pathlib import Path
import shutil
import tempfile
from common import ROOT, ReleaseError, entry, new_output, run, sha256, validate_version
from package import verify


def verify_disk_image(dmg, expected_app):
    """Read back the mounted payload; image checksums alone do not validate its app."""
    expected_app = Path(expected_app)
    parent = Path(tempfile.mkdtemp(prefix="yierbubu-dmg-check-"))
    mount = parent / "volume"
    mount.mkdir()
    attached = False
    try:
        run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, dmg)
        attached = True
        link = mount / "Applications"
        if not link.is_symlink() or os.readlink(link) != "/Applications":
            raise ReleaseError("DMG is missing the Applications installation link")
        actual_app = mount / "YierBubu.app"
        verify(actual_app)
        def inventory(root):
            return {str(p.relative_to(root)): ("link", os.readlink(p)) if p.is_symlink()
                    else (sha256(p), p.stat().st_mode & 0o111)
                    for p in root.rglob("*") if p.is_file() or p.is_symlink()}
        if inventory(expected_app) != inventory(actual_app):
            raise ReleaseError("DMG app differs from the verified input app")
    finally:
        if attached or mount.is_mount():
            run("hdiutil", "detach", mount)
        shutil.rmtree(parent)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("app")
    parser.add_argument("--output", required=True)
    parser.add_argument("--zip-only", action="store_true", help="Build ZIP only; useful for headless checks")
    args = parser.parse_args()
    destination = new_output(args.output)
    app = Path(args.app).absolute()
    info = verify(app)
    if info.get("YierBubuUnnotarizedBeta") is not True:
        raise ReleaseError("Input is not an explicitly selected unnotarized beta")
    version = info.get("YierBubuReleaseVersion", "")
    validate_version(version, info["CFBundleVersion"], info["CFBundleIdentifier"])
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".beta-", dir=destination.parent))
    try:
        payload = staging / "YierBubu"
        payload.mkdir()
        copy = payload / "YierBubu.app"
        run("ditto", app, copy)
        verify(copy)
        public = ROOT / "docs/public"
        if not public.is_dir():
            public = ROOT
        instructions = public / "INSTALL.md"
        (payload / "先读我.txt").write_text(
            f"一二布布 {version} 免费测试版\nmacOS 14 及以上；Apple 芯片与 Intel 通用版。\n"
            "本版本采用本地签名，未公证；首次打开可能需要系统设置中的“仍要打开”。\n\n" +
            instructions.read_text())
        (payload / "隐私与素材说明.txt").write_text(
            (public / "PRIVACY.md").read_text() + "\n\n" + (public / "THIRD_PARTY_NOTICES.md").read_text())
        downloads = staging / "downloads"
        downloads.mkdir()
        basename = f"YierBubu-macOS-Universal-v{version}"
        archive = downloads / f"{basename}.zip"
        run("ditto", "-c", "-k", "--keepParent", "--norsrc", "--noextattr", payload, archive)
        # Verify the actual archive, not just the input staging bundle.
        extracted = staging / "roundtrip"
        run("ditto", "-x", "-k", archive, extracted)
        verify(extracted / "YierBubu/YierBubu.app")
        if sha256(copy / "Contents/MacOS/BubuDesktop") != sha256(extracted / "YierBubu/YierBubu.app/Contents/MacOS/BubuDesktop"):
            raise ReleaseError("ZIP changed the executable")
        if not args.zip_only:
            image = staging / "image"
            run("ditto", payload, image)
            (image / "Applications").symlink_to("/Applications")
            dmg = downloads / f"{basename}.dmg"
            run("hdiutil", "create", "-volname", "一二布布", "-srcfolder", image,
                "-format", "UDZO", dmg)
            run("hdiutil", "verify", dmg)
            verify_disk_image(dmg, copy)
        checksums = [f"{sha256(p)}  {p.name}" for p in sorted(downloads.iterdir())]
        (downloads / "SHA256SUMS.txt").write_text("\n".join(checksums) + "\n")
        (downloads / "RELEASE-INFO.json").write_text(json.dumps(dict(
            version=version, minimum_macos="14.0", architectures=["arm64", "x86_64"],
            build=info["CFBundleVersion"], bundle_id=info["CFBundleIdentifier"],
            base_bundle_id=info["YierBubuBaseBundleIdentifier"],
            permission_identity_policy=info["YierBubuPermissionIdentityPolicy"],
            requires_fresh_input_authorization=True,
            signing="ad-hoc", notarized=False, channel="public-beta",
            disk_image_verified=not args.zip_only,
            character_authorization="not-confirmed", physical_intel_tested=False,
            macos14_physical_tested=False), indent=2) + "\n")
        # Keep a ready-to-install app beside the downloadable archives.
        run("ditto", payload, downloads / "YierBubu")
        downloads.rename(destination)
        print(destination)
    finally:
        shutil.rmtree(staging)


if __name__ == "__main__":
    entry(main)
