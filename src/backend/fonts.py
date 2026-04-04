"""Font searching and downloading from public sources."""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

import aiohttp
import ass

from constants import CACHE_DIR, DOWNLOADS_DIR
from .utils import _ASS_TAG_RE, _detect_scripts as detect_scripts

# Downloaded fonts land here — user-visible, easy to find and install manually
FONTS_DIR = DOWNLOADS_DIR / "Fonts"

# Internal registry: font name → list of filenames in FONTS_DIR
_FONT_REGISTRY = CACHE_DIR / "font_registry.json"

_FONT_EXTS = {".ttf", ".otf", ".ttc", ".otc", ".woff2"}


def _load_registry() -> dict[str, list[str]]:
    try:
        return json.loads(_FONT_REGISTRY.read_text())
    except Exception:
        return {}


def _save_registry(registry: dict[str, list[str]]) -> None:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    _FONT_REGISTRY.write_text(json.dumps(registry, indent=2, ensure_ascii=False))


def _find_system_font(font_name: str) -> Path | None:
    """Return path to a font file for font_name already on the system, or None."""
    if sys.platform != "win32":
        try:
            result = subprocess.run(
                ["fc-match", "--format=%{file}", font_name],
                capture_output=True, text=True, timeout=3,
            )
            if result.returncode == 0 and result.stdout:
                path = Path(result.stdout.strip())
                if path.exists() and path.suffix.lower() in _FONT_EXTS:
                    return path
        except (FileNotFoundError, subprocess.TimeoutExpired):
            pass

        # Fallback: scan common system/nix font dirs with fuzzy name match
        search_dirs = [
            Path.home() / ".nix-profile" / "share" / "fonts",
            Path.home() / ".local" / "share" / "fonts",
            Path("/run/current-system/sw/share/X11/fonts"),
            Path("/run/current-system/sw/share/fonts"),
            Path("/usr/share/fonts"),
            Path("/usr/local/share/fonts"),
        ]
        needle = re.sub(r"[\s\-_]", "", font_name).lower()
        for d in search_dirs:
            if not d.exists():
                continue
            for f in d.rglob("*"):
                if f.suffix.lower() not in _FONT_EXTS:
                    continue
                hay = re.sub(r"[\s\-_]", "", f.stem).lower()
                if needle in hay or hay in needle:
                    return f
        return None
    else:
        dirs = [
            Path("C:/Windows/Fonts"),
            Path.home() / "AppData" / "Local" / "Microsoft" / "Windows" / "Fonts",
        ]
        needle = re.sub(r"[\s\-_]", "", font_name).lower()
        for d in dirs:
            if not d.exists():
                continue
            for f in d.rglob("*"):
                if f.suffix.lower() not in _FONT_EXTS:
                    continue
                hay = re.sub(r"[\s\-_]", "", f.stem).lower()
                if needle in hay or hay in needle:
                    return f
        return None


# ---------------------------------------------------------------------------
# Download sources
# ---------------------------------------------------------------------------

_OLD_UA = "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; .NET CLR 1.1.4322)"


async def _fetch_css_font_urls(
    css_url: str,
    session: aiohttp.ClientSession,
    accept_woff2: bool = False,
) -> list[str]:
    try:
        async with session.get(
            css_url,
            headers={"User-Agent": _OLD_UA},
            timeout=aiohttp.ClientTimeout(total=10),
        ) as resp:
            if resp.status != 200:
                return []
            css = await resp.text()
    except Exception as exc:
        print(f"[fonts] CSS fetch failed ({css_url!r}): {exc}")
        return []

    exts = r"ttf|otf|woff2" if accept_woff2 else r"ttf|otf"
    urls = re.findall(rf"url\(([^)]+\.(?:{exts}))\)", css)
    return list(dict.fromkeys(urls))


async def _google_fonts_urls(
    font_name: str, subsets: list[str], session: aiohttp.ClientSession
) -> list[str]:
    family = font_name.replace(" ", "+")
    url = f"https://fonts.googleapis.com/css?family={family}:400,700"
    if subsets:
        url += "&subset=" + ",".join(subsets)
    return await _fetch_css_font_urls(url, session)


async def _bunny_fonts_urls(
    font_name: str, subsets: list[str], session: aiohttp.ClientSession
) -> list[str]:
    family_kebab = font_name.lower().replace(" ", "-")
    url = f"https://fonts.bunny.net/css?family={family_kebab}:400,700"
    if subsets:
        url += "&subset=" + ",".join(subsets)
    urls = await _fetch_css_font_urls(url, session)
    if not urls:
        family_plus = font_name.replace(" ", "+")
        url2 = f"https://fonts.bunny.net/css2?family={family_plus}:wght@400;700"
        urls = await _fetch_css_font_urls(url2, session, accept_woff2=True)
    return urls


async def _fontsource_urls(
    font_name: str, subsets: list[str], session: aiohttp.ClientSession
) -> list[str]:
    pkg = font_name.lower().replace(" ", "-")
    meta_url = f"https://cdn.jsdelivr.net/npm/@fontsource/{pkg}/package.json"
    try:
        async with session.get(meta_url, timeout=aiohttp.ClientTimeout(total=8)) as resp:
            if resp.status != 200:
                return []
            meta = await resp.json(content_type=None)
    except Exception:
        return []
    version = meta.get("version", "")
    if not version:
        return []
    wanted = {"latin"} | set(subsets)
    urls = []
    for subset in wanted:
        for weight in ("400", "700"):
            urls.append(
                f"https://cdn.jsdelivr.net/npm/@fontsource/{pkg}@{version}"
                f"/files/{pkg}-{subset}-{weight}-normal.woff2"
            )
    return urls


_SOURCES = [_google_fonts_urls, _bunny_fonts_urls, _fontsource_urls]


async def _download_urls(
    font_name: str,
    urls: list[str],
    session: aiohttp.ClientSession,
) -> list[str]:
    """Download font URLs to FONTS_DIR. Returns list of saved filenames."""
    FONTS_DIR.mkdir(parents=True, exist_ok=True)
    saved: list[str] = []
    for url in urls:
        raw = url.split("/")[-1].split("?")[0]
        safe = re.sub(r"[^\w\-.]", "_", raw)
        dest = FONTS_DIR / safe
        if dest.exists():
            saved.append(safe)
            continue
        try:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=30)) as resp:
                if resp.status == 200:
                    dest.write_bytes(await resp.read())
                    saved.append(safe)
                    print(f"[fonts] Downloaded {font_name!r} → {safe}")
                else:
                    print(f"[fonts] HTTP {resp.status} for {url}")
        except Exception as exc:
            print(f"[fonts] Error downloading {url}: {exc}")
    return saved


async def search_and_download_fonts(
    missing_fonts: list[str],
    scripts: list[str],
    status_cb=None,  # callable(font_name: str, status: "downloading"|"done"|"failed")
) -> dict:
    """
    Try every available source for each missing font.
    Returns {"downloaded": [Path, ...], "not_found": [str, ...]}.
    Fonts land in FONTS_DIR (inside the downloads folder).
    """
    if not missing_fonts:
        return {"downloaded": [], "not_found": []}

    FONTS_DIR.mkdir(parents=True, exist_ok=True)
    registry = _load_registry()
    downloaded: list[Path] = []
    not_found: list[str] = []

    async with aiohttp.ClientSession() as session:
        for font_name in missing_fonts:
            # Already registered
            if font_name in registry:
                for fname in registry[font_name]:
                    p = FONTS_DIR / fname
                    if p.exists():
                        downloaded.append(p)
                if status_cb:
                    status_cb(font_name, "done")
                continue

            if status_cb:
                status_cb(font_name, "downloading")

            font_files: list[str] = []
            for source_fn in _SOURCES:
                urls = await source_fn(font_name, scripts, session)
                if urls:
                    font_files = await _download_urls(font_name, urls, session)
                    if font_files:
                        break

            if font_files:
                registry[font_name] = font_files
                _save_registry(registry)
                for fname in font_files:
                    p = FONTS_DIR / fname
                    if p.exists():
                        downloaded.append(p)
                if status_cb:
                    status_cb(font_name, "done")
            else:
                print(f"[fonts] Not found anywhere: {font_name!r}")
                not_found.append(font_name)
                if status_cb:
                    status_cb(font_name, "failed")

    return {"downloaded": downloaded, "not_found": not_found}


async def get_fonts_for_subs(subs_path: Path) -> list[Path]:
    """
    Parse an ASS subtitle file, find/download all required fonts.
    Returns only fonts found exactly (for MKV attachment — substitute fonts
    are skipped because they won't match the ASS style name at playback time).
    """
    try:
        content = subs_path.read_text(encoding="utf-8-sig", errors="replace")
        subtitle = ass.parse_string(content)
    except Exception as exc:
        print(f"[fonts] Failed to parse {subs_path.name}: {exc}")
        return []

    font_names = sorted({style.fontname for style in subtitle.styles})

    text_parts: list[str] = []
    for event in subtitle.events:
        raw = getattr(event, "text", "") or ""
        text_parts.append(_ASS_TAG_RE.sub("", raw))
    scripts = detect_scripts("\n".join(text_parts))

    found: list[Path] = []
    missing: list[str] = []

    for name in font_names:
        path = _find_system_font(name)
        if path:
            found.append(path)
        else:
            missing.append(name)

    if missing:
        result = await search_and_download_fonts(missing, scripts)
        found.extend(result["downloaded"])
        # not_found fonts are simply skipped — player handles fallback

    return found
