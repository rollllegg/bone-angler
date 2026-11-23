#!/usr/bin/env python3
"""Prepare generated story art for the game.

Pipeline: mask the platform watermark -> PerfectPixel -> flood-fill the white
background -> drop specks -> fit the target canvas with nearest-neighbour.
The script never calls the image API and never reads credentials.

Run with the PerfectPixel environment:
    game/.tools/perfect-pixel/venv/Scripts/python.exe game/tools/prepare_generated_asset.py --config game/tools/story_assets.json
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import tempfile
from collections import deque
from datetime import datetime, timezone
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError as error:  # pragma: no cover - environment check
    raise SystemExit(
        "Missing Pillow/numpy. Run with game/.tools/perfect-pixel/venv/Scripts/python.exe."
    ) from error

try:
    import cv2
except ImportError as error:  # pragma: no cover - environment check
    raise SystemExit(
        "Missing opencv-python-headless. Install it in the PerfectPixel environment."
    ) from error


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WATERMARK_BOX = [0.78, 0.90, 1.0, 1.0]


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resolve(path: str) -> Path:
    value = Path(path)
    return value if value.is_absolute() else REPO_ROOT / value


def mask_watermark(image: Image.Image, box: list[float]) -> Image.Image:
    width, height = image.size
    x0 = max(0, min(width, int(round(box[0] * width))))
    y0 = max(0, min(height, int(round(box[1] * height))))
    x1 = max(0, min(width, int(round(box[2] * width))))
    y1 = max(0, min(height, int(round(box[3] * height))))
    if x1 > x0 and y1 > y0:
        image.paste((255, 255, 255, 255), (x0, y0, x1, y1))
    return image


def pixelate(source: Path, destination: Path) -> tuple[Image.Image, list[int] | None]:
    command = [sys.executable, str(resolve("game/tools/perfect_pixel.py")), str(source), "--output", str(destination)]
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0 or not destination.exists():
        raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "PerfectPixel failed")
    sidecar = destination.with_suffix(".json")
    grid = None
    if sidecar.exists():
        try:
            grid = json.loads(sidecar.read_text(encoding="utf-8")).get("pixel_grid")
        except (OSError, json.JSONDecodeError):
            grid = None
    return Image.open(destination).convert("RGBA"), grid


def remove_background(image: Image.Image, threshold: int = 245, min_component: int = 12, erode: int = 0) -> Image.Image:
    array = np.array(image.convert("RGBA"))
    height, width = array.shape[:2]
    background = np.zeros((height, width), dtype=bool)
    visited = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))
    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= width or y >= height or visited[y, x]:
            continue
        visited[y, x] = True
        r, g, b, a = array[y, x]
        if a < 10 or (int(r) >= threshold and int(g) >= threshold and int(b) >= threshold):
            background[y, x] = True
            queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    alpha = array[:, :, 3].copy()
    alpha[background] = 0
    mask = (alpha > 16).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask, 8)
    keep = np.zeros_like(mask)
    for index in range(1, count):
        if int(stats[index, cv2.CC_STAT_AREA]) >= min_component:
            keep[labels == index] = 1
    alpha = alpha * keep
    # Remove the white halo left by the generator: only near-white pixels that
    # touch the removed background are cleared, so interior white highlights stay.
    rgb = array[:, :, :3]
    near_white = (rgb[:, :, 0] >= 235) & (rgb[:, :, 1] >= 235) & (rgb[:, :, 2] >= 235)
    fringe = cv2.dilate(background.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=1).astype(bool)
    alpha[(alpha > 0) & fringe & near_white] = 0
    # Pixel art wants hard edges, not semi-transparent antialiasing.
    alpha[alpha < 128] = 0
    alpha[alpha >= 128] = 255
    if erode > 0:
        alpha = cv2.erode(alpha, np.ones((3, 3), np.uint8), iterations=erode)
    array[:, :, 3] = alpha
    return Image.fromarray(array, "RGBA")


def fit_canvas(image: Image.Image, width: int, height: int, padding: int = 0) -> tuple[Image.Image, tuple[int, int, int, int]]:
    alpha = image.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise RuntimeError("image is empty after background removal")
    cropped = image.crop(bbox)
    inner_width = max(1, width - padding * 2)
    inner_height = max(1, height - padding * 2)
    scale = min(inner_width / cropped.width, inner_height / cropped.height)
    target_width = max(1, int(round(cropped.width * scale)))
    target_height = max(1, int(round(cropped.height * scale)))
    resized = cropped.resize((target_width, target_height), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((width - target_width) // 2, (height - target_height) // 2))
    return canvas, bbox


def parse_color(value: str) -> tuple[int, int, int]:
    text = value.lstrip("#")
    if len(text) != 6:
        return (23, 18, 31)
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16))


def remove_white_specks(image: Image.Image, max_area: int) -> Image.Image:
    if max_area <= 0:
        return image
    array = np.array(image.convert("RGBA"))
    rgb = array[:, :, :3]
    alpha = array[:, :, 3]
    near_white = ((rgb[:, :, 0] >= 230) & (rgb[:, :, 1] >= 230) & (rgb[:, :, 2] >= 230) & (alpha > 0)).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(near_white, 8)
    for index in range(1, count):
        if int(stats[index, cv2.CC_STAT_AREA]) <= max_area:
            alpha[labels == index] = 0
    array[:, :, 3] = alpha
    return Image.fromarray(array, "RGBA")


def make_shadow(image: Image.Image) -> Image.Image:
    array = np.array(image.convert("RGBA"))
    height, width = array.shape[:2]
    mask = (array[:, :, 3] > 128).astype(np.uint8)
    flood = ((1 - mask) * 255).astype(np.uint8)
    flood_mask = np.zeros((height + 2, width + 2), np.uint8)
    cv2.floodFill(flood, flood_mask, (0, 0), 128)
    outside = flood == 128
    holes = ((~outside) & (~mask.astype(bool))).astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(holes, 8)
    filled = mask.astype(bool)
    for index in range(1, count):
        if int(stats[index, cv2.CC_STAT_AREA]) <= 300:
            filled |= labels == index
    shadow = np.zeros_like(array)
    shadow[:, :, 0] = 23
    shadow[:, :, 1] = 18
    shadow[:, :, 2] = 31
    shadow[:, :, 3] = np.where(filled, 255, 0)
    return Image.fromarray(shadow, "RGBA")


def add_outline(image: Image.Image, color: tuple[int, int, int], thickness: int = 1) -> Image.Image:
    if thickness <= 0:
        return image
    alpha = np.array(image.getchannel("A"))
    mask = (alpha > 128).astype(np.uint8)
    kernel = np.ones((3, 3), np.uint8)
    dilated = cv2.dilate(mask, kernel, iterations=thickness)
    ring = (dilated > 0) & (mask == 0)
    if not ring.any():
        return image
    outline = Image.new("RGBA", image.size, (0, 0, 0, 0))
    data = np.array(outline)
    data[ring] = [color[0], color[1], color[2], 255]
    outline = Image.fromarray(data, "RGBA")
    outline.alpha_composite(image)
    return outline


def quantize(image: Image.Image, colors: int) -> Image.Image:
    if colors <= 0:
        return image
    alpha = image.getchannel("A")
    reduced = image.convert("RGB").quantize(colors=colors, method=Image.MEDIANCUT).convert("RGB")
    result = reduced.convert("RGBA")
    result.putalpha(alpha)
    return result


def process_asset(entry: dict, config: dict, keep_temp: bool) -> dict:
    asset_id = str(entry["id"])
    source = resolve(entry["input"])
    destination = resolve(entry["output"])
    if not source.exists():
        raise FileNotFoundError(f"{asset_id}: missing input {source}")
    destination.parent.mkdir(parents=True, exist_ok=True)

    watermark = str(entry.get("watermark", config.get("watermark", "crop")))
    box = entry.get("watermark_box", config.get("watermark_box", DEFAULT_WATERMARK_BOX))
    width = int(entry["width"])
    height = int(entry["height"])
    pixelate_enabled = bool(entry.get("pixelate", config.get("pixelate", True)))
    threshold = int(entry.get("threshold", config.get("threshold", 245)))
    min_component = int(entry.get("min_component", config.get("min_component", 12)))
    erode = int(entry.get("erode", config.get("erode", 0)))
    outline = int(entry.get("outline", config.get("outline", 0)))
    outline_color = str(entry.get("outline_color", config.get("outline_color", "#17121f")))
    white_specks = int(entry.get("white_specks", config.get("white_specks", 0)))
    shadow = bool(entry.get("shadow", config.get("shadow", False)))
    palette = int(entry.get("palette", config.get("palette", 0)))

    image = Image.open(source).convert("RGBA")
    input_size = list(image.size)
    if watermark == "crop":
        image = mask_watermark(image, box)
    elif watermark not in ("keep", "none"):
        raise ValueError(f"{asset_id}: unknown watermark mode {watermark}")

    temp_dir = None
    try:
        if pixelate_enabled:
            temp_dir = tempfile.TemporaryDirectory(prefix=f"story-asset-{asset_id}-")
            prepared = Path(temp_dir.name) / f"{asset_id}.png"
            image.save(prepared)
            image, grid = pixelate(prepared, Path(temp_dir.name) / f"{asset_id}-pixel.png")
        else:
            grid = None
        image = remove_background(image, threshold, min_component, erode)
        image, bbox = fit_canvas(image, width, height, 1 if outline > 0 else 0)
        image = remove_white_specks(image, white_specks)
        if outline > 0:
            image = add_outline(image, parse_color(outline_color), outline)
        image = quantize(image, palette)
        image.save(destination, optimize=True)
        if shadow:
            make_shadow(image).save(destination.with_name(destination.stem + "_shadow.png"), optimize=True)
        if keep_temp and temp_dir is not None:
            print(f"  temp: {temp_dir.name}")
    finally:
        if temp_dir is not None and not keep_temp:
            temp_dir.cleanup()

    metadata = {
        "id": asset_id,
        "kind": entry.get("kind", ""),
        "prompt": entry.get("prompt", ""),
        "source": source.relative_to(REPO_ROOT).as_posix(),
        "source_sha256": sha256(source),
        "input_size": input_size,
        "output": destination.relative_to(REPO_ROOT).as_posix(),
        "output_sha256": sha256(destination),
        "output_size": [width, height],
        "pixel_grid": grid,
        "watermark": watermark,
        "watermark_box": box if watermark == "crop" else None,
        "threshold": threshold,
        "min_component": min_component,
        "erode": erode,
        "outline": outline,
        "white_specks": white_specks,
        "shadow": shadow,
        "palette": palette,
        "bbox": list(bbox),
        "processed_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    sidecar = destination.with_suffix(".json")
    sidecar.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        f"{asset_id}: {input_size[0]}x{input_size[1]} -> {width}x{height}"
        f" | grid {grid or '-'} | bbox {bbox}"
    )
    return metadata


def run_config(path: Path, only: set[str], keep_temp: bool) -> int:
    config = json.loads(path.read_text(encoding="utf-8"))
    assets = config.get("assets", [])
    if not assets:
        raise SystemExit(f"{path}: no assets")
    failures = 0
    for entry in assets:
        if only and str(entry.get("id", "")) not in only:
            continue
        try:
            process_asset(entry, config, keep_temp)
        except Exception as error:  # keep the batch going for the remaining assets
            failures += 1
            print(f"ERROR {entry.get('id', '?')}: {error}", file=sys.stderr)
    return 1 if failures else 0


def run_single(args: argparse.Namespace) -> int:
    entry = {
        "id": args.id or Path(args.output).stem,
        "input": args.input,
        "output": args.output,
        "width": args.width,
        "height": args.height,
        "watermark": args.watermark,
        "pixelate": not args.no_pixelate,
        "threshold": args.threshold,
        "min_component": args.min_component,
        "erode": args.erode,
        "palette": args.palette,
    }
    try:
        process_asset(entry, {}, args.keep_temp)
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, help="batch asset configuration")
    parser.add_argument("--only", default="", help="comma-separated asset ids for batch mode")
    parser.add_argument("--keep-temp", action="store_true")
    parser.add_argument("--input", help="single asset input")
    parser.add_argument("--output", help="single asset output")
    parser.add_argument("--id", default="")
    parser.add_argument("--width", type=int, default=32)
    parser.add_argument("--height", type=int, default=32)
    parser.add_argument("--watermark", choices=["crop", "keep", "none"], default="crop")
    parser.add_argument("--threshold", type=int, default=245)
    parser.add_argument("--min-component", type=int, default=12)
    parser.add_argument("--erode", type=int, default=0)
    parser.add_argument("--palette", type=int, default=0)
    parser.add_argument("--no-pixelate", action="store_true")
    args = parser.parse_args()

    if args.config:
        only = {value.strip() for value in args.only.split(",") if value.strip()}
        return run_config(resolve(str(args.config)), only, args.keep_temp)
    if not args.input or not args.output:
        parser.error("use --config, or provide --input and --output")
    return run_single(args)


if __name__ == "__main__":
    raise SystemExit(main())
