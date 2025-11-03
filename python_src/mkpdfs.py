#!/usr/bin/env python3
# mkpdfs.py — ディレクトリごとに画像をPDF化（Python版）
#
# 使い方:
#   python3 mkpdfs.py [探索ルート] [出力ルート]
#     探索ルート: 省略時はカレントディレクトリ
#     出力ルート: 省略時は各フォルダ内に <フォルダ名>.pdf を生成
#   例:
#     python3 mkpdfs.py
#     python3 mkpdfs.py ~/Pictures ~/PDFs
#   依存:
#     pip install pillow img2pdf
#     HEIC等を扱う場合は pip install pillow-heif も追加

from __future__ import annotations

import argparse
import logging
import os
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, List, Sequence

try:
    import img2pdf  # type: ignore
except ImportError:  # pragma: no cover
    img2pdf = None  # type: ignore[assignment]

from PIL import Image, ImageFile, ImageOps, UnidentifiedImageError

ImageFile.LOAD_TRUNCATED_IMAGES = True
Image.MAX_IMAGE_PIXELS = None

LOGGER = logging.getLogger("mkpdfs")

IMAGE_EXTENSIONS = {
    ".jpg",
    ".jpeg",
    ".png",
    ".gif",
    ".bmp",
    ".tif",
    ".tiff",
    ".webp",
    ".heic",
    ".heif",
}


@dataclass(frozen=True)
class Config:
    root: Path
    out_root: Path | None


def parse_args(argv: Sequence[str]) -> Config:
    parser = argparse.ArgumentParser(
        description="指定ディレクトリ以下の各フォルダをPDF化します（Python版）"
    )
    parser.add_argument("root", nargs="?", default=".", help="探索するルートディレクトリ")
    parser.add_argument(
        "out_root",
        nargs="?",
        default=None,
        help="出力先のルートディレクトリ（省略時は各フォルダ内に作成）",
    )
    args = parser.parse_args(argv)

    root = Path(args.root).expanduser().resolve()
    if not root.exists():
        parser.error(f"ルートディレクトリにアクセスできません: {root}")
    out_root = (
        Path(args.out_root).expanduser().resolve()
        if args.out_root is not None
        else None
    )
    return Config(root=root, out_root=out_root)


def iter_dirs(root: Path) -> Iterable[Path]:
    for current_dir, dirnames, _ in os.walk(root):
        dirnames.sort()
        yield Path(current_dir)


def find_images(directory: Path) -> List[Path]:
    images = [
        entry
        for entry in sorted(directory.iterdir())
        if entry.is_file() and entry.suffix.lower() in IMAGE_EXTENSIONS
    ]
    return images


def resolve_outfile(directory: Path, cfg: Config) -> Path:
    if cfg.out_root:
        try:
            rel = directory.relative_to(cfg.root)
            if rel == Path("."):
                rel_parts = [cfg.root.name or cfg.root.resolve().name]
            else:
                rel_parts = list(rel.parts)
        except ValueError:
            rel_parts = [directory.name]
        name = "_".join(part for part in rel_parts if part)
        return cfg.out_root / f"{name or directory.name}.pdf"

    base = directory.name
    if not base or directory == directory.anchor:
        base = cfg.root.name or cfg.root.resolve().name
    if base in (".", "/"):
        base = cfg.root.name or cfg.root.resolve().name
    return directory / f"{base}.pdf"


def is_up_to_date(images: List[Path], outfile: Path) -> bool:
    if not outfile.exists():
        return False
    newest_img_mtime = max(img.stat().st_mtime for img in images)
    pdf_mtime = outfile.stat().st_mtime
    return pdf_mtime >= newest_img_mtime


def prepare_page(source: Path, tmpdir: Path, index: int) -> Path:
    tmp_path = tmpdir / f"{index:05d}.jpg"
    try:
        with Image.open(source) as img:
            img = ImageOps.exif_transpose(img)
            if img.mode not in ("RGB", "L"):
                img = img.convert("RGB")
            elif img.mode != "RGB":
                img = img.convert("RGB")
            img.save(tmp_path, format="JPEG", quality=95, subsampling=0)
    except UnidentifiedImageError as exc:
        raise RuntimeError(f"画像を開けませんでした: {source}") from exc
    return tmp_path


def write_pdf_from_images(processed_images: Sequence[Path], outfile: Path) -> None:
    if not processed_images:
        return

    if img2pdf is not None:
        try:
            with open(outfile, "wb") as fp:
                fp.write(
                    img2pdf.convert(
                        [str(path) for path in processed_images],
                        rotation=img2pdf.Rotation.ifvalid,
                    )
                )
            return
        except Exception as exc:  # pragma: no cover - fallback path
            LOGGER.warning("img2pdfの変換に失敗したのでPillowで再試行します: %s", exc)

    images: List[Image.Image] = []
    try:
        for path in processed_images:
            img = Image.open(path).convert("RGB")
            images.append(img)
        head, *tail = images
        head.save(outfile, format="PDF", save_all=True, append_images=tail)
    finally:
        for img in images:
            img.close()


def process_directory(directory: Path, cfg: Config) -> None:
    images = find_images(directory)
    if not images:
        return

    outfile = resolve_outfile(directory, cfg)
    outfile.parent.mkdir(parents=True, exist_ok=True)

    if is_up_to_date(images, outfile):
        LOGGER.info("skip: %s up to date", outfile)
        return

    LOGGER.info("making: %s", outfile)
    with tempfile.TemporaryDirectory(prefix="mkpdfs_") as tmpdir_str:
        tmpdir = Path(tmpdir_str)
        processed: List[Path] = []
        for idx, image in enumerate(images):
            processed.append(prepare_page(image, tmpdir, idx))
        write_pdf_from_images(processed, outfile)


def configure_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(logging.Formatter("%(message)s"))
    LOGGER.addHandler(handler)
    LOGGER.setLevel(logging.INFO)


def main(argv: Sequence[str]) -> int:
    configure_logging()
    cfg = parse_args(argv)

    if cfg.out_root:
        cfg.out_root.mkdir(parents=True, exist_ok=True)

    for directory in iter_dirs(cfg.root):
        try:
            process_directory(directory, cfg)
        except Exception as exc:  # pragma: no cover
            LOGGER.error("ERROR: %s の処理に失敗しました: %s", directory, exc)
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main(sys.argv[1:]))
