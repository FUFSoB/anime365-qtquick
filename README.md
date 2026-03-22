# Anime365 QtQuick

A QtQuick frontend for [Anime365](https://smotret-anime.org/) using Python as the backend.

![Screenshot](docs/screenshots/main_page.png)

## Requirements

- [uv](https://docs.astral.sh/uv/) — Python package manager
- Python 3.12+
- On NixOS: enter the dev shell first (`nix-shell`)

## Running from source

```sh
./start.sh
```

On NixOS:

```sh
nix-shell
./start.sh
```

## Building

### Desktop (Windows / Linux / macOS)

```sh
uv run --group build python build.py desktop
```

Output: `dist/Anime365/`

Single-file executable (slower startup):

```sh
uv run --group build python build.py desktop --onefile
```

Clean before building:

```sh
uv run --group build python build.py desktop --clean
```

### Android APK

Requires Android SDK and NDK. Set environment variables first:

```sh
export ANDROID_SDK_ROOT=$HOME/Android/Sdk
export ANDROID_NDK_ROOT=$ANDROID_SDK_ROOT/ndk/<version>
```

Then:

```sh
uv run python build.py android
```

A `pysidedeploy.spec` config file will be created on first run; edit it if needed.

## Data locations

| Platform | Config | Database | Cache |
|----------|--------|----------|-------|
| Linux    | `~/.config/anime365/` | `~/.local/share/anime365/` | `~/.cache/anime365/` |
| Windows  | `%APPDATA%\anime365\` | `%APPDATA%\anime365\` | `%LOCALAPPDATA%\anime365\cache\` |
| macOS    | `~/Library/Preferences/anime365/` | `~/Library/Application Support/anime365/` | `~/Library/Caches/anime365/` |
| Android  | `/storage/emulated/0/Android/data/org.anime365.app/files/` | same | same |
