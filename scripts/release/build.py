"""Preflight and isolated Universal SwiftPM builds."""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
from common import ROOT, MINIMUM_OS, ReleaseError, entry, new_output, run, validate_binary, rpaths


def preflight():
    try:
        swift = Path(run("xcrun", "--find", "swiftc"))
        sdk = run("xcrun", "--sdk", "macosx", "--show-sdk-path")
        for tool in ("swift", "lipo", "otool", "install_name_tool", "swift-stdlib-tool", "clang"):
            run("xcrun", "--find", tool)
        # Test the target we actually ship; macOS 11 compatibility archives are irrelevant to 14.
        with tempfile.TemporaryDirectory(prefix="yierbubu-toolchain-") as directory:
            directory = Path(directory)
            source = directory / "main.swift"
            source.write_text("import Foundation\n@MainActor final class Probe {}\nlet _ = Probe()\n")
            for arch in ("arm64", "x86_64"):
                run(swift, "-sdk", sdk, "-swift-version", "6", "-target", f"{arch}-apple-macosx{MINIMUM_OS}",
                    "-module-cache-path", ROOT / ".build/preflight-modules", source,
                    "-o", directory / arch)
    except ReleaseError as error:
        raise ReleaseError(f"Release toolchain is incomplete: {error}") from error
    return swift


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--work-dir")
    args = parser.parse_args()
    if args.check_only:
        print(f"Release toolchain ready: {preflight()}")
        return
    if not args.work_dir:
        parser.error("--work-dir is required")
    work = new_output(args.work_dir)
    preflight()  # Do not even create the work directory on incomplete toolchains.
    work.mkdir(parents=True)
    try:
        os.environ["CLANG_MODULE_CACHE_PATH"] = str(work / "module-cache")
        os.environ["SWIFTPM_MODULECACHE_OVERRIDE"] = str(work / "module-cache")
        binaries = []
        for arch in ("arm64", "x86_64"):
            scratch = work / arch
            command = ["xcrun", "swift", "build", "--package-path", ROOT, "--scratch-path", scratch,
                       "--cache-path", work / "cache", "--config-path", work / "config",
                       "--security-path", work / "security",
                       "--disable-sandbox", "--build-system", "native", "-c", "release",
                       "--triple", f"{arch}-apple-macosx{MINIMUM_OS}", "-Xlinker", "-headerpad_max_install_names"]
            log = run(*command)
            (work / f"{arch}.log").write_text(log)
            directory = Path(run(*command, "--show-bin-path"))
            binaries.append(directory / "BubuDesktop")
        output = work / "bin/BubuDesktop"
        output.parent.mkdir()
        run("lipo", "-create", *binaries, "-output", output)
        # Swift's driver may add its own toolchain rpath even without test flags.
        bad = set()
        for arch in ("arm64", "x86_64"):
            bad.update(p for p in rpaths(output, arch) if p.startswith("/") and p != "/usr/lib/swift")
        for path in sorted(bad):
            run("install_name_tool", "-delete_rpath", path, output)
        validate_binary(output)
        print(output)
    except Exception:
        # Logs remain for diagnosis, but the promised success artifact cannot survive.
        shutil.rmtree(work / "bin", ignore_errors=True)
        raise


if __name__ == "__main__":
    entry(main)
