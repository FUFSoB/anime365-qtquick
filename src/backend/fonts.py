"""Font searching and downloading from public sources."""

from __future__ import annotations

import asyncio
import json
import re
import subprocess
import sys
from pathlib import Path

import aiohttp
import ass

from constants import CACHE_DIR, DOWNLOADS_DIR
from .utils import _ASS_TAG_RE, _detect_scripts as detect_scripts

FONTS_DIR = DOWNLOADS_DIR / "Fonts"
_FONT_REGISTRY = CACHE_DIR / "font_registry.json"
_FONT_EXTS = {".ttf", ".otf", ".ttc", ".otc", ".woff2"}


def _normalize_name(name: str) -> str:
    return re.sub(r"[\s\-_]", "", name).lower()


def _load_registry() -> dict[str, list[str]]:
    try:
        return json.loads(_FONT_REGISTRY.read_text())
    except Exception:
        return {}


def _save_registry(registry: dict[str, list[str]]) -> None:
    _FONT_REGISTRY.write_text(json.dumps(registry, indent=2, ensure_ascii=False))


def _fc_match(font_name: str) -> Path | None:
    try:
        r = subprocess.run(
            ["fc-match", "--format=%{file}", font_name],
            capture_output=True, text=True, timeout=3,
        )
        if r.returncode == 0 and r.stdout:
            p = Path(r.stdout.strip())
            if p.exists() and p.suffix.lower() in _FONT_EXTS:
                return p
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return None


def _system_font_dirs() -> list[Path]:
    if sys.platform == "win32":
        return [
            Path("C:/Windows/Fonts"),
            Path.home() / "AppData" / "Local" / "Microsoft" / "Windows" / "Fonts",
        ]
    return [
        Path.home() / ".nix-profile" / "share" / "fonts",
        Path.home() / ".local" / "share" / "fonts",
        Path("/run/current-system/sw/share/X11/fonts"),
        Path("/run/current-system/sw/share/fonts"),
        Path("/usr/share/fonts"),
        Path("/usr/local/share/fonts"),
    ]


def _find_system_fonts(font_names: list[str]) -> dict[str, Path | None]:
    """Find system font files for multiple names with a single directory scan."""
    results: dict[str, Path | None] = {}
    need_scan: list[str] = []

    if sys.platform != "win32":
        for name in font_names:
            path = _fc_match(name)
            if path:
                results[name] = path
            else:
                need_scan.append(name)
    else:
        need_scan = list(font_names)

    if need_scan:
        needles = {name: _normalize_name(name) for name in need_scan}
        for d in _system_font_dirs():
            if not d.exists():
                continue
            for f in d.rglob("*"):
                if f.suffix.lower() not in _FONT_EXTS:
                    continue
                hay = _normalize_name(f.stem)
                for name, needle in list(needles.items()):
                    if needle in hay or hay in needle:
                        results[name] = f
                        del needles[name]
                if not needles:
                    break
            if not needles:
                break
        for name in needles:
            results[name] = None

    return results


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
    url = f"https://fonts.bunny.net/css?family={_normalize_name(font_name).replace('_', '-')}:{','.join(['400','700'])}"
    if subsets:
        url += "&subset=" + ",".join(subsets)
    urls = await _fetch_css_font_urls(url, session)
    if not urls:
        url2 = f"https://fonts.bunny.net/css2?family={font_name.replace(' ', '+')}:wght@400;700"
        urls = await _fetch_css_font_urls(url2, session, accept_woff2=True)
    return urls


async def _fontsource_urls(
    font_name: str, subsets: list[str], session: aiohttp.ClientSession
) -> list[str]:
    pkg = font_name.lower().replace(" ", "-")
    try:
        async with session.get(
            f"https://cdn.jsdelivr.net/npm/@fontsource/{pkg}/package.json",
            timeout=aiohttp.ClientTimeout(total=8),
        ) as resp:
            if resp.status != 200:
                return []
            meta = await resp.json(content_type=None)
    except Exception:
        return []
    version = meta.get("version", "")
    if not version:
        return []
    wanted = {"latin"} | set(subsets)
    return [
        f"https://cdn.jsdelivr.net/npm/@fontsource/{pkg}@{version}"
        f"/files/{pkg}-{subset}-{weight}-normal.woff2"
        for subset in wanted
        for weight in ("400", "700")
    ]


_SOURCES = [_google_fonts_urls, _bunny_fonts_urls, _fontsource_urls]


async def _download_urls(
    font_name: str,
    urls: list[str],
    session: aiohttp.ClientSession,
) -> list[str]:
    saved: list[str] = []
    for url in urls:
        safe = re.sub(r"[^\w\-.]", "_", url.split("/")[-1].split("?")[0])
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


async def _fetch_one(
    font_name: str,
    scripts: list[str],
    session: aiohttp.ClientSession,
    registry: dict[str, list[str]],
    status_cb,
) -> tuple[str, list[str]]:
    """Try all sources for one font. Returns (font_name, saved_filenames)."""
    if font_name in registry:
        files = [f for f in registry[font_name] if (FONTS_DIR / f).exists()]
        if files:
            if status_cb:
                status_cb(font_name, "done")
            return font_name, files

    if status_cb:
        status_cb(font_name, "downloading")

    for source_fn in _SOURCES:
        urls = await source_fn(font_name, scripts, session)
        if urls:
            files = await _download_urls(font_name, urls, session)
            if files:
                if status_cb:
                    status_cb(font_name, "done")
                return font_name, files

    print(f"[fonts] Not found anywhere: {font_name!r}")
    if status_cb:
        status_cb(font_name, "failed")
    return font_name, []


async def search_and_download_fonts(
    missing_fonts: list[str],
    scripts: list[str],
    status_cb=None,
) -> dict:
    """
    Download missing fonts from all available sources in parallel.
    Returns {"downloaded": [Path, ...], "not_found": [str, ...]}.
    Fonts are saved to FONTS_DIR (inside the downloads folder).
    """
    if not missing_fonts:
        return {"downloaded": [], "not_found": []}

    FONTS_DIR.mkdir(parents=True, exist_ok=True)
    registry = _load_registry()

    async with aiohttp.ClientSession() as session:
        results = await asyncio.gather(
            *[_fetch_one(name, scripts, session, registry, status_cb) for name in missing_fonts]
        )

    downloaded: list[Path] = []
    not_found: list[str] = []
    changed = False

    for font_name, files in results:
        if files:
            registry[font_name] = files
            changed = True
            for fname in files:
                p = FONTS_DIR / fname
                if p.exists():
                    downloaded.append(p)
        else:
            not_found.append(font_name)

    if changed:
        _save_registry(registry)

    return {"downloaded": downloaded, "not_found": not_found}


async def get_fonts_for_subs(subs_path: Path) -> list[Path]:
    """
    Parse an ASS subtitle file, find/download all required fonts.
    Returns font Paths for MKV attachment (only exact matches — the player
    handles fallback for any that couldn't be sourced).
    """
    try:
        content = subs_path.read_text(encoding="utf-8-sig", errors="replace")
        subtitle = ass.parse_string(content)
    except Exception as exc:
        print(f"[fonts] Failed to parse {subs_path.name}: {exc}")
        return []

    font_names = sorted({style.fontname for style in subtitle.styles})

    text_parts = [_ASS_TAG_RE.sub("", getattr(e, "text", "") or "") for e in subtitle.events]
    scripts = detect_scripts("\n".join(text_parts))

    system = _find_system_fonts(font_names)
    found = [p for p in system.values() if p is not None]
    missing = [name for name, p in system.items() if p is None]

    if missing:
        result = await search_and_download_fonts(missing, scripts)
        found.extend(result["downloaded"])

    return list(dict.fromkeys(found))  # deduplicate preserving order
