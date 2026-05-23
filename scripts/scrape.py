#!/usr/bin/env python3
"""
Site scraper — extracts text content and downloads images from
mckenziecarlile.com and photos.mckenziecarlile.com.

Usage:
  python3 scripts/scrape.py                        # scrape both sites
  python3 scripts/scrape.py https://example.com    # scrape a specific URL

Output:
  scripts/scraped/<domain>/content.json            # all text, structured by page
  scripts/scraped/<domain>/images/<filename>       # downloaded images
"""

import sys
import os
import json
import time
import re
import hashlib
from urllib.parse import urljoin, urlparse, urldefrag
import requests
from bs4 import BeautifulSoup

# ── CONFIG ────────────────────────────────────────────────────────────────

TARGETS = [
    "https://photos.mckenziecarlile.com",
    "https://mckenziecarlile.com",
]

OUT_DIR = os.path.join(os.path.dirname(__file__), "scraped")
DELAY   = 0.5   # seconds between requests
TIMEOUT = 15

HEADERS = {
    "User-Agent": "Mozilla/5.0 (compatible; site-scraper/1.0; personal use)",
}

# Elements whose text we skip entirely
SKIP_TAGS = {"script", "style", "noscript", "head"}

# ── HELPERS ───────────────────────────────────────────────────────────────

def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")

def domain_dir(base_url):
    host = urlparse(base_url).netloc.replace(":", "_")
    return os.path.join(OUT_DIR, host)

def same_domain(url, base):
    return urlparse(url).netloc == urlparse(base).netloc

def normalise(url, base):
    url, _ = urldefrag(url)
    return urljoin(base, url).rstrip("/")

def get(url, retries=3):
    for attempt in range(retries):
        try:
            r = requests.get(url, headers=HEADERS, timeout=TIMEOUT)
            r.raise_for_status()
            return r
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 503 and attempt < retries - 1:
                wait = 2 ** attempt
                print(f"    503 — retrying in {wait}s…")
                time.sleep(wait)
            else:
                raise
        except requests.exceptions.RequestException as e:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
            else:
                raise
    return None

# ── TEXT EXTRACTION ───────────────────────────────────────────────────────

NAV_BOILERPLATE = {"mckenzie carlile", "design work", "field reports", "contact"}

def extract_text_blocks(soup):
    """Return deduplicated, semantic text blocks — skips nav/header/footer chrome."""
    # Remove chrome regions entirely before walking the tree
    for chrome in soup.find_all(["nav", "header", "footer"]):
        chrome.decompose()

    # Semantic tags first (highest signal), then div/span as fallback
    SEMANTIC = {"h1","h2","h3","h4","h5","h6","p","li","figcaption","blockquote"}
    FALLBACK  = {"div","span"}

    blocks = []
    seen   = set()

    def add(tag_name, text):
        t = text.strip()
        if not t or len(t) < 4:
            return
        # Skip pure-nav boilerplate chunks
        words = set(t.lower().split())
        if words and words.issubset(NAV_BOILERPLATE | {""}):
            return
        if t not in seen:
            seen.add(t)
            blocks.append({"tag": tag_name, "text": t})

    # Pass 1: semantic tags
    for tag in soup.find_all(list(SEMANTIC)):
        add(tag.name, tag.get_text(" ", strip=True))

    # Pass 2: div/span — only add if they contain content not already captured
    for tag in soup.find_all(list(FALLBACK)):
        # Skip if it has semantic children (we already got those)
        if tag.find(list(SEMANTIC)):
            continue
        add(tag.name, tag.get_text(" ", strip=True))

    return blocks


def canonical_img_url(url, page_url):
    """Resolve and unwrap Next.js /_next/image optimisation URLs."""
    resolved = urljoin(page_url, url)
    parsed = urlparse(resolved)
    if parsed.path.startswith("/_next/image"):
        from urllib.parse import parse_qs
        qs = parse_qs(parsed.query)
        inner = qs.get("url", [""])[0]
        if inner:
            # inner URL is encoded; resolve it against the base
            return urljoin(resolved, inner)
    return resolved


def extract_images(soup, page_url):
    """Return deduplicated list of image dicts with canonical URLs."""
    seen = set()
    imgs = []
    for img in soup.find_all("img"):
        src = img.get("src") or img.get("data-src") or ""
        if not src or src.startswith("data:"):
            continue
        url = canonical_img_url(src, page_url)
        if url in seen:
            continue
        seen.add(url)
        imgs.append({
            "src":  url,
            "alt":  img.get("alt", "").strip(),
            "width":  img.get("width", ""),
            "height": img.get("height", ""),
        })
    return imgs


def extract_meta(soup):
    meta = {}
    title_tag = soup.find("title")
    if title_tag:
        meta["title"] = title_tag.get_text(strip=True)
    desc = soup.find("meta", attrs={"name": "description"})
    if desc:
        meta["description"] = desc.get("content", "").strip()
    og_title = soup.find("meta", property="og:title")
    if og_title:
        meta["og_title"] = og_title.get("content", "").strip()
    og_desc = soup.find("meta", property="og:description")
    if og_desc:
        meta["og_description"] = og_desc.get("content", "").strip()
    return meta


# ── IMAGE DOWNLOAD ────────────────────────────────────────────────────────

_img_cache = {}  # url -> local filename, shared across all pages in a crawl

def download_image(url, img_dir):
    """Download an image, return local filename or None on failure. Skips duplicates."""
    if url in _img_cache:
        return _img_cache[url]
    try:
        r = requests.get(url, headers=HEADERS, timeout=TIMEOUT, stream=True)
        r.raise_for_status()
        path = urlparse(url).path
        name = os.path.basename(path) or hashlib.md5(url.encode()).hexdigest()[:12]
        local = os.path.join(img_dir, name)
        counter = 1
        base, ext = os.path.splitext(local)
        while os.path.exists(local):
            local = f"{base}_{counter}{ext}"
            counter += 1
        with open(local, "wb") as f:
            for chunk in r.iter_content(8192):
                f.write(chunk)
        filename = os.path.basename(local)
        _img_cache[url] = filename
        return filename
    except Exception as e:
        print(f"    ✗ image failed: {url}  ({e})")
        _img_cache[url] = None
        return None


# ── CRAWLER ───────────────────────────────────────────────────────────────

def crawl(base_url):
    global _img_cache
    _img_cache = {}
    host      = urlparse(base_url).netloc
    out_dir   = domain_dir(base_url)
    img_dir   = os.path.join(out_dir, "images")
    os.makedirs(img_dir, exist_ok=True)

    visited = set()
    queue   = [normalise(base_url, base_url)]
    pages   = []

    print(f"\n{'─'*60}")
    print(f"  Crawling {base_url}")
    print(f"  Output → {out_dir}")
    print(f"{'─'*60}")

    while queue:
        url = queue.pop(0)
        if url in visited:
            continue
        visited.add(url)

        print(f"  GET {url}")
        try:
            r = get(url)
        except Exception as e:
            print(f"    ✗ skipping ({e})")
            continue

        if "text/html" not in r.headers.get("content-type", ""):
            continue

        soup = BeautifulSoup(r.text, "html.parser")

        # -- Extract images before text cleaning (text extractor decomposes chrome)
        raw_imgs = extract_images(soup, url)

        # -- Text & meta
        page = {
            "url":    url,
            "path":   urlparse(url).path or "/",
            "meta":   extract_meta(soup),
            "blocks": extract_text_blocks(soup),
            "images": [],
        }
        for img in raw_imgs:
            local_name = download_image(img["src"], img_dir)
            if local_name:
                img["local"] = local_name
                print(f"    ↓ {local_name}")
            page["images"].append(img)

        pages.append(page)

        # -- Discover new links
        for a in soup.find_all("a", href=True):
            href = normalise(a["href"], url)
            if same_domain(href, base_url) and href not in visited and href not in queue:
                queue.append(href)

        time.sleep(DELAY)

    # -- Write JSON
    output = {
        "site":  base_url,
        "pages": sorted(pages, key=lambda p: p["path"]),
    }
    json_path = os.path.join(out_dir, "content.json")
    with open(json_path, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    img_count = sum(1 for p in pages for img in p["images"] if img.get("local"))
    print(f"\n  ✓ {len(pages)} pages, {img_count} images")
    print(f"  ✓ content.json → {json_path}\n")

    return output


# ── SUMMARY REPORT ────────────────────────────────────────────────────────

def print_summary(results):
    print("\n" + "═"*60)
    print("  SCRAPE COMPLETE")
    print("═"*60)
    for r in results:
        host = urlparse(r["site"]).netloc
        pages = r["pages"]
        total_imgs = sum(len(p["images"]) for p in pages)
        print(f"\n  {host}")
        print(f"    {len(pages)} pages · {total_imgs} images")
        for p in pages:
            title = p["meta"].get("title") or p["path"]
            imgs  = len(p["images"])
            blks  = len(p["blocks"])
            print(f"    {p['path']:<40} {blks:>3} blocks  {imgs:>3} imgs")
    print()


# ── MAIN ──────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    targets = sys.argv[1:] if len(sys.argv) > 1 else TARGETS
    results = []
    for target in targets:
        try:
            result = crawl(target)
            results.append(result)
        except Exception as e:
            print(f"\n✗ Failed to crawl {target}: {e}\n")
    if results:
        print_summary(results)
