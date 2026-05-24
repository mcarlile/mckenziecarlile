#!/usr/bin/env python3
"""Generate all case study and field report HTML pages from scraped content."""

import json, os, shutil, html, textwrap

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# ── helpers ───────────────────────────────────────────────────────────────────

NAV_NOISE = {
    "McKenzie Carlile", "Design work", "Field reports", "Contact",
    "Want to get in touch?", "Send me an email",
    "Email Icon Twitter Icon LinkedIn Icon Instagram Icon Dribbble Icon",
}

def esc(s): return html.escape(s)

def skip_block(b):
    t = b["text"].strip()
    if t in NAV_NOISE: return True
    if t.startswith("©"): return True
    if "Email Icon" in t: return True
    return False

def nav_html(active=""):
    return """
<nav>
  <a href="/" class="nav-logo">McKenzie Carlile</a>
  <ul class="nav-links">
    <li><a href="/field-reports/">Field reports</a></li>
    <li><a href="/contact/">Contact</a></li>
  </ul>
</nav>"""

def footer_html():
    return """
<footer>
  <span>© 2025 McKenzie Carlile</span>
  <span>Lake Tahoe, California</span>
</footer>"""

def head_html(title, depth=2):
    dots = "../" * depth
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{esc(title)} — McKenzie Carlile</title>
  <link href="https://fonts.googleapis.com/css2?family=EB+Garamond:ital,wght@0,400;0,500;1,400;1,500&family=Geist:wght@300;400;500&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="{dots}assets/style.css">
</head>
<body>"""

def img_tag(src, alt="", loading="lazy", extra_style=""):
    style = f' style="{extra_style}"' if extra_style else ""
    return f'<img src="{esc(src)}" alt="{esc(alt)}" loading="{loading}" decoding="async"{style}>'

def gallery_html(imgs, base_path, depth=2):
    """Render a 2-col gallery. First image is full-width if there are 3+ images."""
    if not imgs: return ""
    dots = "../" * depth
    lines = ['  <div class="report-gallery">']
    for i, img in enumerate(imgs):
        css_class = ' class="full-width"' if (i == 0 and len(imgs) >= 3) else ""
        lines.append(f'    <img{css_class} src="{dots}{base_path}/{esc(img)}" alt="" loading="lazy" decoding="async">')
    lines.append("  </div>")
    return "\n".join(lines)


# ── CASE STUDY GENERATOR ──────────────────────────────────────────────────────

def render_case_blocks(blocks, images, img_base, depth=2, skip_count=2):
    """
    Render case study body HTML. skip_count: how many blocks at the start to skip
    (h1 and subtitle are used in the hero, not re-rendered here).
    Images are distributed in galleries after h2 sections.
    """
    dots = "../" * depth

    # Filter blocks
    body_blocks = [b for b in blocks[skip_count:] if not skip_block(b)]

    # Find positions of h2s to use as image gallery insertion points
    h2_positions = [i for i, b in enumerate(body_blocks) if b["tag"] == "h2"]

    # Distribute images across sections
    section_count = len(h2_positions) if h2_positions else 1
    imgs_per_section = max(1, len(images) // max(1, section_count))

    # Build image batches keyed by h2 index
    img_batches = {}
    img_idx = 0
    for sec_idx in range(section_count):
        batch_size = imgs_per_section
        if sec_idx == section_count - 1:
            batch_size = len(images) - img_idx  # give remaining to last section
        batch = images[img_idx:img_idx + batch_size]
        img_idx += batch_size
        # We'll insert after the h2 at h2_positions[sec_idx]
        target_block_idx = h2_positions[sec_idx] if sec_idx < len(h2_positions) else len(body_blocks) - 1
        img_batches[target_block_idx] = batch

    # If no h2s and we have images, put them at the top
    if not h2_positions and images:
        img_batches[-1] = images

    lines = ["<div class=\"case-body\">", ""]

    # Insert top-of-body images (before any h2) if flagged as -1
    if -1 in img_batches:
        for im in img_batches[-1][:1]:
            lines.append(f'  {img_tag(f"{dots}{img_base}/{im}", loading="eager", extra_style="width:100%;border-radius:var(--radius-card);margin-bottom:40px;")}')
        rest = img_batches[-1][1:]
        if rest:
            lines.append(gallery_html(rest, img_base, depth))

    # First image at top if it exists and no h2 batches
    elif images and not h2_positions:
        im = images[0]
        lines.append(f'  {img_tag(f"{dots}{img_base}/{im}", loading="eager", extra_style="width:100%;border-radius:var(--radius-card);margin-bottom:40px;")}')
        if len(images) > 1:
            lines.append(gallery_html(images[1:], img_base, depth))

    prev_was_h4 = False
    for i, b in enumerate(body_blocks):
        tag, text = b["tag"], esc(b["text"])

        if tag == "h1":
            continue  # already in hero
        elif tag in ("h2",):
            # Insert a full-width image from first batch before this section heading
            if i in img_batches and img_batches[i]:
                batch = img_batches[i]
                first_img = batch[0]
                lines.append(f'  {img_tag(f"{dots}{img_base}/{first_img}", loading="lazy", extra_style="width:100%;border-radius:var(--radius-card);margin:48px 0 32px;")}')
                if len(batch) > 1:
                    lines.append(gallery_html(batch[1:], img_base, depth))
            lines.append(f"  <h2>{text}</h2>")
        elif tag == "h3":
            lines.append(f"  <h3>{text}</h3>")
        elif tag == "h4":
            lines.append(f"  <h3>{text}</h3>")
            prev_was_h4 = True
            continue
        elif tag == "blockquote":
            lines.append(f"  <blockquote><p>{text}</p></blockquote>")
        elif tag == "li":
            lines.append(f"  <ul><li>{text}</li></ul>")
        elif tag in ("p", "div", "span"):
            lines.append(f"  <p>{text}</p>")

        prev_was_h4 = False

    lines.append("</div>")
    return "\n".join(lines)


def build_case_study(slug, title, subtitle, meta_items, blocks, images, img_base):
    """Generate a complete case study HTML page."""
    # Skip first 2 blocks (h1 title + first p subtitle) in body
    body_html = render_case_blocks(blocks, images, img_base)

    meta_html = ""
    if meta_items:
        meta_html = '\n      <div class="case-meta">'
        for label, val in meta_items:
            meta_html += f"""
        <div class="case-meta-item">
          <span class="case-meta-label">{esc(label)}</span>
          <span class="case-meta-value">{esc(val)}</span>
        </div>"""
        meta_html += "\n      </div>"

    return f"""{head_html(title)}
{nav_html()}

<div class="case-hero">
  <div class="case-hero-inner">
    <a href="/" class="case-back">← Work</a>
    <div class="case-hero-label">Product Design</div>
    <h1>{esc(title)}</h1>
    <p class="case-hero-sub">{esc(subtitle)}</p>{meta_html}
  </div>
</div>

{body_html}
{footer_html()}

</body>
</html>
"""


# ── FIELD REPORT GENERATOR ────────────────────────────────────────────────────

def build_field_report(title, tagline, blocks, images, img_base, depth=2):
    """Generate a complete field report HTML page."""
    dots = "../" * depth

    # First image is hero
    hero_img = images[0] if images else None
    gallery_imgs = images[1:]  # All remaining images

    # Filter body blocks: skip nav noise, skip h3 nav items at top
    body_blocks = []
    skip_tags = {"McKenzie Carlile", "Design work", "Field reports", "Contact"}
    for b in blocks:
        if b["text"] in skip_tags: continue
        if skip_block(b): continue
        body_blocks.append(b)

    # Identify h2 section positions to chunk images
    h2_positions = [i for i, b in enumerate(body_blocks) if b["tag"] == "h2"]

    # Build section image batches
    if h2_positions and gallery_imgs:
        imgs_per_section = max(2, len(gallery_imgs) // len(h2_positions))
        section_img_map = {}
        img_idx = 0
        for sec_num, h2_pos in enumerate(h2_positions):
            if sec_num == len(h2_positions) - 1:
                batch = gallery_imgs[img_idx:]
            else:
                batch = gallery_imgs[img_idx:img_idx + imgs_per_section]
            img_idx += len(batch)
            section_img_map[h2_pos] = batch
    else:
        section_img_map = {}
        if gallery_imgs:
            section_img_map[-1] = gallery_imgs  # put all at end

    # Build body HTML
    lines = ['<div class="report-body">', ""]

    # If no h2s and we have gallery images, put them after the first few paragraphs
    body_line_count = 0
    for i, b in enumerate(body_blocks):
        tag, text = b["tag"], esc(b["text"])

        if i in section_img_map and section_img_map[i]:
            # Insert image gallery before this section heading
            batch = section_img_map[i]
            lines.append(gallery_html(batch, img_base, depth))

        if tag == "h2":
            lines.append(f"  <h2>{text}</h2>")
        elif tag in ("p", "div", "span"):
            lines.append(f"  <p>{text}</p>")
            body_line_count += 1
            # If no h2 sections, insert images after first 3 paragraphs
            if not h2_positions and body_line_count == 3 and -1 in section_img_map:
                mid = len(section_img_map[-1]) // 2
                lines.append(gallery_html(section_img_map[-1][:mid], img_base, depth))
                section_img_map[-1] = section_img_map[-1][mid:]

    # Any remaining images at the end
    if -1 in section_img_map and section_img_map[-1]:
        lines.append(gallery_html(section_img_map[-1], img_base, depth))

    lines.append("</div>")
    body_content = "\n".join(lines)

    hero_style = "background:#2a3a32;"
    hero_img_tag = ""
    if hero_img:
        hero_img_tag = f'\n  <img src="{dots}{img_base}/{esc(hero_img)}" alt="{esc(title)}" loading="eager" decoding="async">'

    return f"""{head_html(title)}
{nav_html()}

<div class="report-hero" style="{hero_style}">{hero_img_tag}
  <div class="report-hero-overlay"></div>
  <div class="report-hero-meta">
    <h1>{esc(title)}</h1>
    <div class="report-date">{esc(tagline)}</div>
  </div>
</div>

{body_content}
{footer_html()}

</body>
</html>
"""


# ── MAIN ──────────────────────────────────────────────────────────────────────

def main():
    www_path = os.path.join(REPO, "scripts/scraped/www.mckenziecarlile.com/content.json")
    photos_path = os.path.join(REPO, "scripts/scraped/photos.mckenziecarlile.com/content.json")

    with open(www_path) as f:
        www = {p["path"]: p for p in json.load(f)["pages"]}
    with open(photos_path) as f:
        photos = {p["path"]: p for p in json.load(f)["pages"]}

    generated = []

    # ── UX CASE STUDIES ───────────────────────────────────────────────────────

    case_studies = [
        {
            "page_path": "/wdp.html",
            "slug": "watson-data-platform",
            "title": "IBM Watson Data Platform",
            "meta": [("Role", "UX Designer"), ("Timeline", "2017–2018"), ("Team", "IBM Design Studio, Austin")],
            "img_base": "assets/images",
        },
        {
            "page_path": "/ibm.html",
            "slug": "storediq-for-legal",
            "title": "IBM StoredIQ for Legal",
            "meta": [("Role", "UX Designer"), ("Timeline", "Fall 2015 – Summer 2016"), ("Team", "IBM Analytics Platform")],
            "img_base": "assets/images",
        },
        {
            "page_path": "/disney.html",
            "slug": "disney",
            "title": "Disney Interactive",
            "meta": [("Role", "UX Design Intern"), ("Timeline", "Summer 2013"), ("Team", "Disney Interactive")],
            "img_base": "assets/images",
        },
        {
            "page_path": "/elementerra.html",
            "slug": "elementerra",
            "title": "ElemenTerra",
            "meta": [("Role", "Lead Designer & Programmer"), ("Timeline", "2012–2013"), ("Team", "USC Games")],
            "img_base": "assets/images",
        },
        {
            "page_path": "/thesis.html",
            "slug": "thesis",
            "title": "USC Media Arts Honors Thesis",
            "meta": [("Role", "Designer & Researcher"), ("Timeline", "2014–2015"), ("Team", "USC School of Cinematic Arts")],
            "img_base": "assets/images",
        },
        {
            "page_path": "/mini.html",
            "slug": "mini-cooper",
            "title": "MINI Cooper Research Project",
            "meta": [("Role", "Design Researcher"), ("Timeline", "Spring 2014"), ("Team", "USC Interaction Design Lab")],
            "img_base": "assets/images",
        },
        {
            "page_path": "/beingbroody.html",
            "slug": "being-broody",
            "title": "Being Broody",
            "meta": [("Role", "Design Lead"), ("Timeline", "2015"), ("Team", "Side Project")],
            "img_base": "assets/images",
        },
    ]

    for cs in case_studies:
        p = www.get(cs["page_path"])
        if not p:
            print(f"  SKIP: {cs['page_path']} not found in scraped data")
            continue

        blocks = p["blocks"]
        images = [i["local"] for i in p["images"] if i.get("local")]

        # Extract title and subtitle from blocks
        title = cs["title"]
        subtitle_blocks = [b for b in blocks if b["tag"] == "p" and not skip_block(b)]
        subtitle = subtitle_blocks[0]["text"] if subtitle_blocks else ""

        out_dir = os.path.join(REPO, "design-work", cs["slug"])
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "index.html")

        html_out = build_case_study(cs["slug"], title, subtitle, cs["meta"], blocks, images, cs["img_base"])
        with open(out_path, "w") as f:
            f.write(html_out)
        print(f"  ✓ design-work/{cs['slug']}/index.html  ({len(blocks)} blocks, {len(images)} imgs)")
        generated.append(f"design-work/{cs['slug']}/index.html")

    # ── FIELD REPORTS ─────────────────────────────────────────────────────────

    field_reports = [
        {
            "page_path": "/miter-basin",
            "slug": "miter-basin",
            "title": "Miter Basin",
            "tagline": "Sierra Nevada · Backpacking & Fly Fishing · July 4–8, 2021",
            "img_base": "assets/images/field-reports/miter-basin",
        },
        {
            "page_path": "/mt-langley",
            "slug": "ne-couloir-mt-langley",
            "title": "N.E. Couloir of Mt. Langley",
            "tagline": "Sierra Nevada · Ski Mountaineering",
            "img_base": "assets/images/field-reports/ne-couloir-mt-langley",
        },
        {
            "page_path": "/south-fork-of-the-flathead",
            "slug": "south-fork-flathead",
            "title": "South Fork of the Flathead",
            "tagline": "Montana · Packrafting · August 4–10, 2022",
            "img_base": "assets/images/field-reports/south-fork-flathead",
        },
    ]

    for fr in field_reports:
        p = photos.get(fr["page_path"])
        if not p:
            print(f"  SKIP: {fr['page_path']} not found in scraped photos data")
            continue

        blocks = p["blocks"]
        images = [i["local"] for i in p["images"] if i.get("local")]

        out_dir = os.path.join(REPO, "field-reports", fr["slug"])
        os.makedirs(out_dir, exist_ok=True)
        out_path = os.path.join(out_dir, "index.html")

        html_out = build_field_report(fr["title"], fr["tagline"], blocks, images, fr["img_base"])
        with open(out_path, "w") as f:
            f.write(html_out)
        print(f"  ✓ field-reports/{fr['slug']}/index.html  ({len(blocks)} blocks, {len(images)} imgs)")
        generated.append(f"field-reports/{fr['slug']}/index.html")

    print(f"\n  Generated {len(generated)} pages total")
    return generated


if __name__ == "__main__":
    main()
