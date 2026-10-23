"""Build and validate app bundles; no launch or permission changes."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import shutil
import struct
import tempfile
from common import (ROOT, LAYERS, MINIMUM_OS, ReleaseError, entry, new_output, run,
                    validate_binary, validate_version, rpaths, sha256)

PERMISSION_IDENTITY_POLICY = "content-scoped-ad-hoc-v1"


def beta_permission_identity(contents, base, build):
    # Hash the fully assembled payload BEFORE signing and replacing the base ID.
    # A rebuild with changed code/resources must not reuse the old TCC identity,
    # even if the maintainer accidentally reuses its version/build number.
    inventory = "\n".join(f"{p.relative_to(contents)}:{sha256(p)}"
                          for p in sorted(contents.rglob("*")) if p.is_file())
    digest = hashlib.sha256(inventory.encode()).hexdigest()
    return f"{base}.beta.b{build}.h{digest[:32]}"


def dependencies(binary, arch):
    # Ignore the heading. Whitespace in a path is preserved.
    lines = run("otool", "-arch", arch, "-L", binary).splitlines()[1:]
    return [line.strip().split(" (compatibility version")[0] for line in lines if line.startswith("\t")]


def verify(app):
    app = Path(app).absolute()
    if app.is_symlink():
        raise ReleaseError("App path is a symlink")
    contents = app / "Contents"
    for name in LAYERS:
        resource = contents / "Resources/Layered" / name
        if not resource.is_file() or resource.is_symlink():
            raise ReleaseError(f"Missing resource: {name}")
        header = resource.read_bytes()[:24]
        if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) < 24 or struct.unpack(">II", header[16:24]) != (1536, 1024):
            raise ReleaseError(f"Invalid resource size: {name}")
    try:
        info = plistlib.loads((contents / "Info.plist").read_bytes())
        validate_version(info["CFBundleShortVersionString"], info["CFBundleVersion"], info["CFBundleIdentifier"])
    except (KeyError, plistlib.InvalidFileException) as error:
        raise ReleaseError(f"Invalid Info.plist: {error}") from error
    if info.get("LSMinimumSystemVersion") != MINIMUM_OS or info.get("CFBundleExecutable") != "BubuDesktop":
        raise ReleaseError("Incorrect minimum OS or executable in Info.plist")
    if info.get("YierBubuUnnotarizedBeta") is True:
        base = info.get("YierBubuBaseBundleIdentifier", "")
        pattern = re.escape(base) + r"\.beta\.b" + re.escape(info["CFBundleVersion"]) + r"\.h[0-9a-f]{32}"
        if (not base or info.get("YierBubuPermissionIdentityPolicy") != PERMISSION_IDENTITY_POLICY
                or not re.fullmatch(pattern, info["CFBundleIdentifier"])):
            raise ReleaseError("Unsafe beta permission identity: do not reuse legacy shared identifiers")
    if info.get("CFBundleIconFile") != "YierBubu.icns":
        raise ReleaseError("Missing application icon declaration")
    icon = contents / "Resources/YierBubu.icns"
    if not icon.is_file() or icon.is_symlink():
        raise ReleaseError("Missing application icon")
    data = icon.read_bytes()
    if len(data) < 8 or data[:4] != b"icns" or struct.unpack(">I", data[4:8])[0] != len(data):
        raise ReleaseError("Invalid application icon container")
    executable = contents / "MacOS/BubuDesktop"
    validate_binary(executable)
    frameworks = contents / "Frameworks"
    binaries = [executable] + list(frameworks.glob("*.dylib"))
    for binary in binaries:
        if binary.is_symlink():
            raise ReleaseError(f"Unexpected binary symlink: {binary}")
        if binary != executable:
            validate_binary(binary, exact_floor=False)
        for arch in ("arm64", "x86_64"):
            search = rpaths(binary, arch)
            for path in search:
                if path.startswith("/") and path != "/usr/lib/swift":
                    raise ReleaseError(f"External development rpath: {path}")
                if not (path == "/usr/lib/swift" or path.startswith(("@executable_path", "@loader_path"))):
                    raise ReleaseError(f"Unresolved runtime search path: {path}")
            for dependency in dependencies(binary, arch):
                if dependency == f"@rpath/{binary.name}" and binary != executable:
                    continue  # dylib's own install name
                if dependency.startswith(("/usr/lib/", "/System/Library/")):
                    continue
                def expand(value):
                    return Path(value.replace("@executable_path", str(executable.parent)).replace("@loader_path", str(binary.parent)))
                if dependency.startswith("@rpath/"):
                    candidates = [expand(path) / dependency[len("@rpath/"):] for path in search if path.startswith("@")]
                    # Embedded libraries can inherit the executable's rpaths.
                    if binary != executable:
                        for inherited in rpaths(executable, arch):
                            if inherited.startswith(("@loader_path", "@executable_path")):
                                inherited = inherited.replace("@loader_path", str(executable.parent)).replace(
                                    "@executable_path", str(executable.parent))
                                candidates.append(Path(inherited) / dependency[len("@rpath/"):])
                elif dependency.startswith(("@loader_path/", "@executable_path/")):
                    candidates = [expand(dependency)]
                else:
                    raise ReleaseError(f"External binary dependency: {dependency}")
                if not any(p.is_file() and contents.resolve() in p.resolve().parents for p in candidates):
                    raise ReleaseError(f"Missing bundled dependency: {dependency}")
    run("codesign", "--verify", "--strict", "--deep", "--all-architectures",
        "--test-requirement", f'=identifier "{info["CFBundleIdentifier"]}"', app)
    return info


def ensure_frameworks_rpath(executable):
    path = "@executable_path/../Frameworks"
    present = {arch: path in rpaths(executable, arch) for arch in ("arm64", "x86_64")}
    if all(present.values()):
        return
    if not any(present.values()):
        run("install_name_tool", "-add_rpath", path, executable)
        return
    # install_name_tool operates on every slice; avoid duplicate rpaths in asymmetric input.
    with tempfile.TemporaryDirectory(prefix=".rpath-", dir=executable.parent) as work:
        slices = []
        for arch in ("arm64", "x86_64"):
            thin = Path(work) / arch
            run("lipo", executable, "-thin", arch, "-output", thin)
            if not present[arch]:
                run("install_name_tool", "-add_rpath", path, thin)
            slices.append(thin)
        merged = Path(work) / "merged"
        run("lipo", "-create", *slices, "-output", merged)
        shutil.copyfile(merged, executable)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify")
    parser.add_argument("--version")
    parser.add_argument("--build")
    parser.add_argument("--bundle-id")
    parser.add_argument("--binary")
    parser.add_argument("--output")
    parser.add_argument("--identity")
    parser.add_argument("--unnotarized-beta", action="store_true")
    args = parser.parse_args()
    if args.verify:
        verify(args.verify)
        print("Verified Universal app, macOS 14 deployment, resources, dependencies and signature.")
        return
    if not all((args.version, args.build, args.bundle_id, args.binary, args.output)):
        parser.error("--version --build --bundle-id --binary --output are required")
    validate_version(args.version, args.build, args.bundle_id)
    destination = new_output(args.output)
    binary = Path(args.binary).resolve(strict=True)
    validate_binary(binary)
    for name in LAYERS:
        if not (ROOT / "Resources/Layered" / name).is_file():
            raise ReleaseError(f"Missing source resource: {name}")
    if not (ROOT / "Resources/Icon/YierBubu.icns").is_file():
        raise ReleaseError("Missing source application icon; run scripts/build-icon.sh")
    if args.identity and not args.identity.startswith("Developer ID Application:"):
        raise ReleaseError("Use a Developer ID Application identity")
    if args.identity and args.unnotarized_beta:
        raise ReleaseError("Cannot combine a Developer ID identity with the ad-hoc beta channel")
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".package-", dir=destination.parent))
    try:
        category = "SIGNED-UNNOTARIZED" if args.identity else "BETA-UNNOTARIZED" if args.unnotarized_beta else "INTERNAL"
        app = staging / category / "YierBubu.app"
        contents = app / "Contents"
        (contents / "MacOS").mkdir(parents=True)
        layers = contents / "Resources/Layered"
        layers.mkdir(parents=True)
        executable = contents / "MacOS/BubuDesktop"
        shutil.copy2(binary, executable)
        executable.chmod(0o755)
        # Strip only debug/STABS records, including local object/source paths, before signing.
        run("xcrun", "strip", "-S", executable)
        for name in LAYERS:
            shutil.copy2(ROOT / "Resources/Layered" / name, layers / name)
        shutil.copy2(ROOT / "Resources/Icon/YierBubu.icns", contents / "Resources/YierBubu.icns")
        info = dict(CFBundleName="YierBubu", CFBundleDisplayName="一二布布",
                    CFBundleIconFile="YierBubu.icns",
                    CFBundleIdentifier=args.bundle_id, CFBundleExecutable="BubuDesktop",
                    CFBundlePackageType="APPL", CFBundleVersion=args.build,
                    CFBundleShortVersionString=args.version.split("-")[0],
                    LSMinimumSystemVersion=MINIMUM_OS, LSUIElement=True, NSHighResolutionCapable=True,
                    YierBubuReleaseVersion=args.version, YierBubuUnnotarizedBeta=args.unnotarized_beta)
        if args.unnotarized_beta:
            info.update(YierBubuBaseBundleIdentifier=args.bundle_id,
                        YierBubuPermissionIdentityPolicy=PERMISSION_IDENTITY_POLICY,
                        CFBundleDisplayName=f"一二布布 {args.version}")
        (contents / "Info.plist").write_bytes(plistlib.dumps(info))
        frameworks = contents / "Frameworks"
        frameworks.mkdir()
        run("xcrun", "swift-stdlib-tool", "--copy", "--scan-executable", executable,
            "--platform", "macosx", "--destination", frameworks)
        # macOS 14 includes the Swift concurrency runtime; no macOS 11 back-deployment copy.
        # Package only needs system Swift and its private embedded Frameworks.
        for image in [executable] + list(frameworks.glob("*.dylib")):
            unwanted = {p for arch in ("arm64", "x86_64") for p in rpaths(image, arch)
                        if p.startswith("/") and p != "/usr/lib/swift"}
            for path in unwanted:
                run("install_name_tool", "-delete_rpath", path, image)
        ensure_frameworks_rpath(executable)
        if args.unnotarized_beta:
            info["CFBundleIdentifier"] = beta_permission_identity(contents, args.bundle_id, args.build)
            (contents / "Info.plist").write_bytes(plistlib.dumps(info))
        identity = args.identity or "-"
        options = ["--options", "runtime", "--timestamp"] if args.identity else []
        for library in frameworks.glob("*.dylib"):
            run("codesign", "--force", "--sign", identity, *options, library)
        run("codesign", "--force", "--sign", identity, *options, "--identifier", info["CFBundleIdentifier"], app)
        verify(app)
        (staging / "BUILD-REPORT.json").write_text(json.dumps(dict(
            version=args.version, build=args.build, bundle_id=info["CFBundleIdentifier"],
            base_bundle_id=args.bundle_id,
            permission_identity_policy=info.get("YierBubuPermissionIdentityPolicy", "signer-managed"),
            architectures=["arm64", "x86_64"], deployment_target=MINIMUM_OS, notarized=False,
            channel=category, binary_sha256=sha256(executable),
            icon_sha256=sha256(contents / "Resources/YierBubu.icns"),
            resources={name: sha256(layers / name) for name in LAYERS}), indent=2) + "\n")
        staging.rename(destination)
        print(destination / category / "YierBubu.app")
    finally:
        if staging.exists():
            shutil.rmtree(staging)


if __name__ == "__main__":
    entry(main)
