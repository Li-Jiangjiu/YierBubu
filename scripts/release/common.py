"""Shared release checks. Python 3 is a developer-tool dependency, never an app dependency."""
import hashlib
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
LAYERS = ("compact-scene.png", "compact-cleanplate.png", "compact-paws.png")
MINIMUM_OS = "14.0"


class ReleaseError(Exception):
    pass


def run(*args):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True)
    if result.returncode:
        raise ReleaseError(f"{args[0]} failed ({result.returncode}):\n{result.stderr[-8000:]}\n{result.stdout[-2000:]}")
    return result.stdout.strip()


def entry(function):
    try:
        function()
    except (ReleaseError, OSError, ValueError) as error:
        print(f"Release error: {error}", file=sys.stderr)
        sys.exit(1)


def new_output(value):
    candidate = Path(os.path.abspath(value))
    # Check lexical components before resolve() so symlinks cannot hide a destination.
    for component in (candidate, *candidate.parents):
        if component.is_symlink():
            raise ReleaseError(f"Output contains a symlink: {component}")
    base = ROOT / "output/releases"
    if candidate == base or base not in candidate.parents:
        raise ReleaseError("Output must be a new directory inside output/releases")
    if candidate.exists():
        raise ReleaseError(f"Output already exists: {candidate}")
    return candidate


def validate_version(version, build, bundle_id):
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?", version):
        raise ReleaseError("Invalid version; use semantic version such as 0.4.0-beta.1")
    if not re.fullmatch(r"[1-9][0-9]*", str(build)):
        raise ReleaseError("Invalid build number")
    if not re.fullmatch(r"[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", bundle_id):
        raise ReleaseError("Invalid bundle identifier")


def architectures(binary):
    return set(run("/usr/bin/lipo", "-archs", binary).split())


def validate_binary(binary, exact_floor=True):
    if architectures(binary) != {"arm64", "x86_64"}:
        raise ReleaseError(f"Expected arm64 and x86_64 architectures: {binary}")
    for arch in ("arm64", "x86_64"):
        loads = run("/usr/bin/otool", "-arch", arch, "-l", binary)
        match = re.search(r"\bminos\s+(\d+(?:\.\d+){0,2})", loads)
        if match is None:
            match = re.search(r"LC_VERSION_MIN_MACOSX\s+cmdsize\s+\d+\s+version\s+(\d+(?:\.\d+){0,2})", loads)
        if match is None:
            raise ReleaseError(f"Cannot determine deployment target: {binary} ({arch})")
        values = tuple(map(int, match[1].split(".")))
        values = (values + (0, 0))[:3]
        floor = (14, 0, 0)
        if (exact_floor and values != floor) or values > floor:
            raise ReleaseError(f"Invalid deployment target {match[1]} for {arch}: {binary}")


def rpaths(binary, arch):
    loads = run("/usr/bin/otool", "-arch", arch, "-l", binary)
    return re.findall(r"cmd LC_RPATH\s+cmdsize\s+\d+\s+path (.*?) \(offset", loads)


def sha256(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def assert_no_external_links(directory):
    directory = Path(directory).absolute()
    if directory != ROOT and ROOT not in directory.parents:
        raise ReleaseError(f"Input is outside the source tree: {directory}")
    for component in (directory, *directory.parents):
        if component.is_symlink():
            raise ReleaseError(f"Unexpected symlink in input path: {component}")
        if component == ROOT:
            break
    if not directory.exists():
        raise ReleaseError(f"Missing source input: {directory}")
    for path in directory.rglob("*") if directory.is_dir() else ():
        if path.is_symlink():
            raise ReleaseError(f"Unexpected symlink in input tree: {path}")
