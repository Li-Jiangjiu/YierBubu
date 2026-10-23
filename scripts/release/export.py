"""Export a reviewable source tree without private history or unapproved artwork."""
import argparse
import re
from pathlib import Path
import shutil
import tempfile
from common import ROOT, LAYERS, ReleaseError, entry, new_output, assert_no_external_links, sha256


def copy_file(source, destination):
    assert_no_external_links(source)
    shutil.copy2(source, destination)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    parser.add_argument("--include-artwork", "--include-approved-artwork", dest="include_artwork", action="store_true",
                        help="Include local character PNGs; this does not assert or grant redistribution rights")
    args = parser.parse_args()
    destination = new_output(args.output)
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = Path(tempfile.mkdtemp(prefix=".export-", dir=destination.parent))
    try:
        for directory in ("Sources", "Tests", "scripts", ".github"):
            source = ROOT / directory
            assert_no_external_links(source)
            shutil.copytree(source, staging / directory,
                            ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
        copy_file(ROOT / "Package.swift", staging / "Package.swift")
        copy_file(ROOT / "LICENSE", staging / "LICENSE")
        copy_file(ROOT / ".gitignore", staging / ".gitignore")
        # Public explanations contain no machine-specific paths.
        public_docs = ROOT / "docs/public"
        if not public_docs.is_dir():
            public_docs = ROOT  # Exported trees keep public documents at the root.
        for name in ("README.md", "PRIVACY.md", "INSTALL.md", "LICENSE-DECISION.md", "RELEASE-NOTES.md", "THIRD_PARTY_NOTICES.md"):
            copy_file(public_docs / name, staging / name)
        (staging / "docs").mkdir()
        copy_file(ROOT / "docs/release-process.md", staging / "docs/release-process.md")
        layers = staging / "Resources/Layered"
        layers.mkdir(parents=True)
        if args.include_artwork:
            for name in LAYERS:
                source = ROOT / "Resources/Layered" / name
                copy_file(source, layers / name)
            icons = staging / "Resources/Icon"
            icons.mkdir()
            for name in ("app-icon.png", "YierBubu.icns", "README.md"):
                copy_file(ROOT / "Resources/Icon" / name, icons / name)
        (layers / "README.md").write_text("运行需要三张 1536×1024 PNG：" + "、".join(LAYERS) +
            ("。此导出含本地运行素材。" if args.include_artwork else "。此导出不含角色素材。") +
            "角色素材不在 MIT 代码许可范围内，公开分发授权尚未确认；包含文件不代表取得角色授权。\n")
        for path in staging.rglob("*"):
            if path.is_file() and path.suffix in (".md", ".swift", ".sh", ".py", ".yml"):
                if re.search(r"/Users/[A-Za-z0-9_.-]+/", path.read_text()):
                    raise ReleaseError(f"Review local absolute path in export: {path.relative_to(staging)}")
        inventory = [f"{sha256(p)}  {p.relative_to(staging)}" for p in sorted(staging.rglob("*")) if p.is_file()]
        (staging / "SOURCE-SHA256SUMS.txt").write_text("\n".join(inventory) + "\n")
        staging.rename(destination)
        print(destination)
    finally:
        if staging.exists():
            shutil.rmtree(staging)


if __name__ == "__main__":
    entry(main)
