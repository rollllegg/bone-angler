"""Run the pinned local PerfectPixel OpenCV backend without changing originals."""

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import sys
from datetime import datetime, timezone
from pathlib import Path


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_backend():
    import cv2
    import numpy as np
    from PIL import Image, ImageOps

    project = Path(__file__).resolve().parents[1]
    config = json.loads((project / 'tools/toolchain.json').read_text(encoding='utf-8'))['perfect_pixel']
    source = project / '.tools/perfect-pixel' / ('perfectPixel-' + config['revision'])
    module_path = source / 'src/perfect_pixel/perfect_pixel.py'
    if not module_path.is_file():
        raise RuntimeError('PerfectPixel is missing. Run game/tools/Install-PerfectPixel.ps1 first.')
    spec = importlib.util.spec_from_file_location('gameoff_perfect_pixel', module_path)
    backend = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(backend)
    return backend, config, cv2, np, Image, ImageOps


def process(path, args, runtime):
    backend, config, cv2, np, Image, ImageOps = runtime
    source = path.expanduser().resolve(strict=True)
    target = args.output.expanduser().resolve() if args.output else source.with_name(source.stem + '.perfect.png')
    record_path = target.with_suffix('.json')
    if target == source or record_path == source:
        raise ValueError('The output must be different from the original image.')
    if target.suffix.lower() != '.png':
        raise ValueError('The output must be a PNG file.')
    if target.exists() or record_path.exists():
        raise FileExistsError('Output already exists; choose another path with --output: ' + str(target))
    with Image.open(source) as opened:
        if getattr(opened, 'n_frames', 1) != 1:
            raise ValueError('Export animated images as separate frames before processing.')
        has_alpha = 'A' in opened.getbands() or 'transparency' in opened.info
        image = ImageOps.exif_transpose(opened).convert('RGBA' if has_alpha else 'RGB')
    if args.grid and (args.grid[0] > image.width or args.grid[1] > image.height):
        raise ValueError('The requested grid cannot exceed the input image dimensions.')
    pixels = np.array(image)
    if not args.grid and np.all(pixels == pixels[0, 0]):
        raise ValueError('A solid-color image has no detectable grid. Specify --grid WIDTH HEIGHT.')
    cv2.setRNGSeed(42)
    # OpenCV accepts RGB/RGBA here; cell sampling keeps the original alpha channel.
    # Disable upstream's automatic row/column additions and removals for game art.
    log = io.StringIO()
    with contextlib.redirect_stdout(log):
        width, height, result = backend.get_perfect_pixel(
            pixels,
            sample_method=args.sample,
            grid_size=tuple(args.grid) if args.grid else None,
            refine_intensity=args.refine,
            fix_square=False,
        )
    if width is None or height is None or result.size == 0:
        raise RuntimeError('Grid detection failed. Retry with --grid WIDTH HEIGHT. ' + log.getvalue().strip())
    expected_channels = 4 if has_alpha else 3
    if result.ndim != 3 or result.shape[2] != expected_channels:
        raise RuntimeError('PerfectPixel did not preserve the expected color/alpha channels.')
    output = Image.fromarray(result)
    if args.scale != 1:
        output = output.resize((width * args.scale, height * args.scale), Image.Resampling.NEAREST)
    target.parent.mkdir(parents=True, exist_ok=True)
    output.save(target, format='PNG')
    record = {
        'tool': 'PerfectPixel',
        'repository': config['repository'],
        'revision': config['revision'],
        'processed_at_utc': datetime.now(timezone.utc).isoformat(),
        'input': str(source),
        'input_sha256': sha256(source),
        'input_size': list(image.size),
        'output': str(target),
        'output_sha256': sha256(target),
        'output_size': list(output.size),
        'pixel_grid': [width, height],
        'requested_grid': args.grid,
        'sampling': args.sample,
        'refine_intensity': args.refine,
        'fix_square': False,
        'export_scale': args.scale,
        'mode': output.mode,
        'backend': 'opencv',
        'dependencies': {'numpy': np.__version__, 'opencv': cv2.__version__, 'pillow': Image.__version__},
        'algorithm_log': log.getvalue().splitlines(),
    }
    record_path.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print('Processed: {} -> {} (grid {}x{}, {})'.format(source.name, target, width, height, output.mode))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('images', type=Path, nargs='*')
    parser.add_argument('-o', '--output', type=Path, help='Output PNG, for a single input only.')
    parser.add_argument('--grid', type=int, nargs=2, metavar=('WIDTH', 'HEIGHT'))
    parser.add_argument('--sample', choices=['center', 'median', 'majority'], default='center')
    parser.add_argument('--refine', type=float, default=0.25)
    parser.add_argument('--scale', type=int, default=1, help='Nearest-neighbor export scale.')
    parser.add_argument('--check', action='store_true', help='Verify the local backend and dependencies.')
    args = parser.parse_args()
    if args.output and len(args.images) != 1:
        parser.error('--output requires exactly one input image.')
    if args.grid and any(value < 1 for value in args.grid):
        parser.error('--grid dimensions must be positive.')
    if args.scale < 1 or not 0 <= args.refine <= 0.5:
        parser.error('--scale must be positive and --refine must be between 0 and 0.5.')
    if not args.images and not args.check:
        parser.error('Provide one or more images, or use --check.')
    try:
        runtime = load_backend()
    except Exception as exc:
        print('Setup error: ' + str(exc), file=sys.stderr)
        return 1
    if args.check:
        print('PerfectPixel ready: OpenCV backend, commit ' + runtime[1]['revision'])
    failures = 0
    for path in args.images:
        try:
            process(path, args, runtime)
        except Exception as exc:
            print('Failed: {}: {}'.format(path, exc), file=sys.stderr)
            failures += 1
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
