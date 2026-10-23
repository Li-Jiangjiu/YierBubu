"""Convert the approved PNG master into a native multi-resolution ICNS."""
import struct
import tempfile
from pathlib import Path
from common import ROOT, ReleaseError, entry, run


def main():
    directory = ROOT / "Resources/Icon"
    master = directory / "app-icon.png"
    header = master.read_bytes()[:24]
    if header[:8] != b"\x89PNG\r\n\x1a\n" or len(header) < 24 or struct.unpack(">II", header[16:24]) != (1024, 1024):
        raise ReleaseError("Icon master must be a 1024×1024 PNG")
    with tempfile.TemporaryDirectory(prefix="yierbubu-icon-") as work:
        iconset = Path(work) / "YierBubu.iconset"
        iconset.mkdir()
        for points in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                name = f"icon_{points}x{points}" + ("@2x" if scale == 2 else "") + ".png"
                size = str(points * scale)
                run("sips", "-z", size, size, master, "--out", iconset / name)
        output = Path(work) / "YierBubu.icns"
        run("iconutil", "-c", "icns", iconset, "-o", output)
        (directory / "YierBubu.icns").write_bytes(output.read_bytes())
    print(directory / "YierBubu.icns")


if __name__ == "__main__":
    entry(main)
