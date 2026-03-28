#!/usr/bin/env python3
"""
Build standalone Anime365 applications.

Desktop (Windows / Linux / macOS):
    uv run --group build python build.py desktop

Android (requires pre-built wheels — PyPI does not publish Android wheels):
    uv run --group android python build.py android \\
        --wheel-pyside /path/to/PySide6-...-android_aarch64.whl \\
        --wheel-shiboken /path/to/shiboken6-...-android_aarch64.whl

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
        # Include package metadata so importlib.metadata.version() works when frozen
        "--copy-metadata",
        "anime365-qtquick",
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


def build_android(wheel_pyside: str, wheel_shiboken: str):
    """Build Android APK using pyside6-android-deploy.

    Requires pre-downloaded Android aarch64 wheels for PySide6 and shiboken6,
    since PyPI does not publish them. Build wheels from Qt sources or obtain
    them from Qt's CI artifacts.
    """

    # Check environment
    sdk = os.environ.get("ANDROID_SDK_ROOT") or os.environ.get("ANDROID_HOME")
    ndk = os.environ.get("ANDROID_NDK_ROOT")

    if not sdk:
        sys.exit(
            "ANDROID_SDK_ROOT (or ANDROID_HOME) is not set.\n"
            "Install Android SDK and set the environment variable.\n"
            "  export ANDROID_SDK_ROOT=$HOME/Android/Sdk"
        )
    if not ndk:
        sys.exit(
            "ANDROID_NDK_ROOT is not set.\n"
            "Install Android NDK via SDK Manager and set the variable.\n"
            "  export ANDROID_NDK_ROOT=$ANDROID_SDK_ROOT/ndk/<version>"
        )

    tool = shutil.which("pyside6-android-deploy")
    if not tool:
        sys.exit(
            "pyside6-android-deploy not found.\n"
            "It ships with PySide6 >= 6.5. Make sure PySide6 is installed:\n"
            "  uv run pyside6-android-deploy --help"
        )

    # Write deployment config
    deploy_spec = ROOT / "pysidedeploy.spec"
    if not deploy_spec.exists():
        _write_android_spec(deploy_spec, sdk, ndk)
        print(f"Created {deploy_spec}")

    cmd = [
        tool,
        "--input-file", str(SRC / "main.py"),
        "--wheel-pyside", wheel_pyside,
        "--wheel-shiboken", wheel_shiboken,
        "--verbose",
    ]
    print(f"Building {APP_NAME} for Android...")
    print(f"  SDK: {sdk}")
    print(f"  NDK: {ndk}")
    print(f"  PySide6 wheel: {wheel_pyside}")
    print(f"  shiboken6 wheel: {wheel_shiboken}")
    subprocess.run(cmd, check=True)

    # Look for APK output
    for apk in ROOT.rglob("*.apk"):
        dest = DIST / apk.name
        DIST.mkdir(exist_ok=True)
        shutil.copy2(apk, dest)
        print(f"\nAPK copied to: {dest}")
        return

    print("\nBuild finished. Check the output above for the APK location.")


def _write_android_spec(path: Path, sdk: str, ndk: str):
    """Generate a pyside6-android-deploy spec file."""
    path.write_text(
        f"""\
[app]
title = {APP_NAME}
project_dir = .
input_file = src/main.py
project_file = pyproject.toml
exec_directory = .

[python]
python_path = {sys.executable}
packages = aiohttp,aiohttp_socks,ass

[qt]
qml_files = src/qml/main.qml,src/qml/components/

[android]
ndk_path = {ndk}
sdk_path = {sdk}
"""
    )


def main():
    parser = argparse.ArgumentParser(description="Build Anime365 standalone app")
    parser.add_argument(
        "target",
        choices=["desktop", "android"],
        help="Build target platform",
    )
    parser.add_argument(
        "--onefile",
        action="store_true",
        help="Desktop: pack into a single executable",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove build/ and dist/ before building",
    )
    parser.add_argument(
        "--wheel-pyside",
        help="Android: path to PySide6 android_aarch64 wheel",
    )
    parser.add_argument(
        "--wheel-shiboken",
        help="Android: path to shiboken6 android_aarch64 wheel",
    )
    args = parser.parse_args()

    if args.clean:
        clean()

    if args.target == "desktop":
        build_desktop(onefile=args.onefile)
    elif args.target == "android":
        if not args.wheel_pyside or not args.wheel_shiboken:
            parser.error(
                "Android builds require --wheel-pyside and --wheel-shiboken.\n"
                "PyPI does not publish Android wheels — build them from Qt sources\n"
                "or obtain them from Qt's CI artifacts."
            )
        build_android(args.wheel_pyside, args.wheel_shiboken)


if __name__ == "__main__":
    main()
