#!/usr/bin/env python3
"""
Build standalone Anime365 applications.

Desktop (Windows / Linux / macOS):
    uv run --group build python build.py desktop

Options:
    --onefile   Pack everything into a single executable (slower startup)
    --clean     Remove build artifacts before building
"""

import argparse
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent
SRC = ROOT / "src"
DIST = ROOT / "dist"
BUILD = ROOT / "build"
ICON_PNG = ROOT / "resources" / "icon-512.png"

APP_NAME = "Anime365"

# PyInstaller uses os.pathsep as src<sep>dest separator in --add-data
SEP = os.pathsep


def _make_icon() -> Path | None:
    """Convert icon-512.png to platform-specific icon format."""
    if not ICON_PNG.exists():
        print("Warning: icon-512.png not found, building without icon")
        return None

    from PIL import Image

    if sys.platform == "win32":
        ico_path = BUILD / "icon.ico"
        ico_path.parent.mkdir(parents=True, exist_ok=True)
        img = Image.open(ICON_PNG)
        sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
        img.save(ico_path, format="ICO", sizes=sizes)
        return ico_path

    if sys.platform == "darwin":
        iconset = BUILD / "icon.iconset"
        iconset.mkdir(parents=True, exist_ok=True)
        img = Image.open(ICON_PNG)
        for size in (16, 32, 64, 128, 256, 512):
            img.resize((size, size), Image.LANCZOS).save(iconset / f"icon_{size}x{size}.png")
            if size <= 256:
                doubled = size * 2
                img.resize((doubled, doubled), Image.LANCZOS).save(iconset / f"icon_{size}x{size}@2x.png")
        icns_path = BUILD / "icon.icns"
        subprocess.run(["iconutil", "-c", "icns", str(iconset), "-o", str(icns_path)], check=True)
        return icns_path

    return None


def _write_version_file():
    """Read version from pyproject.toml and write src/_version.txt for PyInstaller."""
    import re
    text = (ROOT / "pyproject.toml").read_text()
    m = re.search(r'^version\s*=\s*"(.+?)"', text, re.MULTILINE)
    version = m.group(1) if m else "0.0.0"
    (SRC / "_version.txt").write_text(version)
    print(f"Wrote version {version} to src/_version.txt")


def clean():
    for d in (DIST, BUILD):
        if d.exists():
            shutil.rmtree(d)
            print(f"Removed {d}")


def build_desktop(onefile: bool = False):
    """Build standalone desktop app using PyInstaller."""
    try:
        import PyInstaller  # noqa: F401
    except ImportError:
        sys.exit(
            "PyInstaller not found. Run with:\n"
            "  uv run --group build python build.py desktop"
        )

    icon_path = _make_icon()

    # Write version file so the frozen app can read it without package metadata
    _write_version_file()

    cmd = [
        sys.executable,
        "-m",
        "PyInstaller",
        "--name",
        APP_NAME,
        "--noconfirm",
        # Include QML files in the bundle
        "--add-data",
        f"src/qml{SEP}qml",
        # Include version file in the bundle
        "--add-data",
        f"src/_version.txt{SEP}.",
        "--add-data",
        f"resources/icon-512.png{SEP}.",
        # Add src/ to Python path so 'backend' and 'constants' imports resolve
        "--paths",
        "src",
    ]

    if icon_path:
        cmd.extend(["--icon", str(icon_path)])

    if onefile:
        cmd.append("--onefile")
    else:
        cmd.append("--onedir")

    # Windowed mode (no console) on Windows and macOS
    if sys.platform in ("win32", "darwin"):
        cmd.append("--windowed")

    # macOS bundle identifier
    if sys.platform == "darwin":
        cmd.extend(["--osx-bundle-identifier", "org.anime365.client"])

    # Entry point
    cmd.append(str(SRC / "main.py"))

    print(f"Building {APP_NAME} for {platform.system()}...")
    print(f"  Command: {' '.join(cmd)}")
    subprocess.run(cmd, check=True)

    out = DIST / APP_NAME
    if onefile:
        suffix = ".exe" if sys.platform == "win32" else ""
        out = DIST / f"{APP_NAME}{suffix}"

    print(f"\nBuild complete: {out}")


def main():
    parser = argparse.ArgumentParser(description="Build Anime365 standalone app")
    parser.add_argument(
        "target",
        choices=["desktop"],
        help="Build target platform",
    )
    parser.add_argument(
        "--onefile",
        action="store_true",
        help="Pack into a single executable",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove build/ and dist/ before building",
    )
    args = parser.parse_args()

    if args.clean:
        clean()

    build_desktop(onefile=args.onefile)


if __name__ == "__main__":
    main()
