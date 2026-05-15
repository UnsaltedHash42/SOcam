#!/usr/bin/env python3
"""
Convert exp-312.pdf to exp-312.md with extracted images (deduplicated by content hash).

Block order follows PyMuPDF get_text("dict") stream order (closest available to PDF layout).
Tables: when find_tables() returns grids, emit markdown tables after the page body
(terminal-style regions may appear as both text and table — prefer visual fidelity via images).

Usage:
  python3 scripts/pdf_to_markdown_exp312.py [--pdf PATH] [--out PATH] [--assets DIR]
"""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path


def md_escape_line(line: str) -> str:
    """Escape markdown-sensitive line starts without mangling normal prose."""
    s = line.rstrip("\n")
    if not s:
        return ""
    # Fence-like lines
    if s.strip().startswith("```"):
        s = "`" + s[0] + "`" + s[1:]
    # ATX headings and block quotes
    if re.match(r"^#{1,6}\s", s):
        return "\\" + s
    if s.startswith(">"):
        return "\\" + s
    if re.match(r"^[-*+]\s", s):
        return "\\" + s
    if re.match(r"^\d+\.\s", s):
        return "\\" + s
    return s


def cell_md(s: str | None) -> str:
    if s is None:
        return ""
    t = str(s).replace("|", "\\|").replace("\n", " ").strip()
    return t


def table_to_markdown(rows: list[list[str | None]]) -> str:
    if not rows:
        return ""
    # Normalize row lengths
    w = max(len(r) for r in rows)
    norm = [list(r) + [None] * (w - len(r)) for r in rows]
    header = [cell_md(c) for c in norm[0]]
    lines = ["| " + " | ".join(header) + " |", "| " + " | ".join(["---"] * w) + " |"]
    for r in norm[1:]:
        lines.append("| " + " | ".join(cell_md(c) for c in r) + " |")
    return "\n".join(lines) + "\n\n"


def text_from_block(block: dict) -> str:
    parts: list[str] = []
    for line in block.get("lines", []):
        spans = line.get("spans", [])
        line_text = "".join(s.get("text", "") for s in spans)
        parts.append(md_escape_line(line_text))
    return "\n".join(parts).strip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pdf", type=Path, default=Path(__file__).resolve().parents[1] / "exp-312.pdf")
    ap.add_argument("--out", type=Path, default=Path(__file__).resolve().parents[1] / "exp-312.md")
    ap.add_argument("--assets", type=Path, default=Path(__file__).resolve().parents[1] / "exp-312-assets")
    args = ap.parse_args()

    try:
        import fitz
    except ImportError:
        print("PyMuPDF (fitz) is required: pip install pymupdf", file=sys.stderr)
        return 1

    pdf = args.pdf
    if not pdf.is_file():
        print(f"PDF not found: {pdf}", file=sys.stderr)
        return 1

    args.assets.mkdir(parents=True, exist_ok=True)

    doc = fitz.open(pdf)
    hash_to_name: dict[str, str] = {}
    img_serial = 0

    lines_out: list[str] = []
    lines_out.append(f"# exp-312 (extracted from `{pdf.name}`)\n\n")
    lines_out.append(
        "_This file was machine-generated from the PDF: block order, text, and embedded "
        "images follow PyMuPDF extraction. Some layout nuance (multi-column flow, precise "
        "spacing) cannot be represented literally in Markdown._\n\n"
    )
    lines_out.append("---\n\n")

    for pno in range(doc.page_count):
        page = doc[pno]
        page_num = pno + 1
        lines_out.append(f"## Page {page_num}\n\n")

        # Do not pass TEXT_PRESERVE_WHITESPACE — it omits image blocks from the dict.
        blocks = page.get_text("dict").get("blocks", [])

        for bi, block in enumerate(blocks):
            btype = block.get("type", 0)
            if btype == 0:
                txt = text_from_block(block)
                if txt:
                    lines_out.append(txt + "\n\n")
            elif btype == 1:
                ext = (block.get("ext") or "png").lower()
                if ext not in ("png", "jpeg", "jpg", "gif", "bmp", "tiff", "webp"):
                    ext = "png"
                raw = block.get("image")
                if not isinstance(raw, (bytes, bytearray)):
                    continue
                h = hashlib.sha256(raw).hexdigest()[:16]
                if h not in hash_to_name:
                    img_serial += 1
                    fname = f"img-{h}.{ext}"
                    fpath = args.assets / fname
                    if not fpath.exists():
                        fpath.write_bytes(raw)
                    hash_to_name[h] = fname
                rel = f"{args.assets.name}/{hash_to_name[h]}"
                lines_out.append(f"![p{page_num}-b{bi}]({rel})\n\n")

        # Detected tables (append; avoids losing grid-like terminal dumps)
        try:
            tf = page.find_tables()
            for ti, tab in enumerate(tf.tables):
                rows = tab.extract()
                if rows and any(any(c not in (None, "") for c in row) for row in rows):
                    lines_out.append(f"### Page {page_num} — detected table {ti + 1}\n\n")
                    lines_out.append(table_to_markdown(rows))
        except Exception:
            pass

        lines_out.append(f"\n<!-- end page {page_num} -->\n\n---\n\n")

    doc.close()

    args.out.write_text("".join(lines_out), encoding="utf-8")
    print(f"Wrote {args.out} ({args.out.stat().st_size} bytes)")
    print(f"Assets in {args.assets} ({len(hash_to_name)} unique images)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
