"""
Remove backgrounds from enemy sprite JPEGs and save as PNGs.
Handles various background colors (white, gray, dark gray, checkerboard).
Also crops watermarks from specific images.
"""

import numpy as np
from PIL import Image
import os

ENEMIES_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'assets', 'images', 'enemies')

TOLERANCE = 38


def flood_fill_bg(img_array, start_x, start_y, tolerance):
    """Flood fill from a starting point, marking matching pixels as transparent."""
    h, w = img_array.shape[:2]
    mask = np.zeros((h, w), dtype=bool)
    target_color = img_array[start_y, start_x, :3].astype(np.int16)

    stack = [(start_x, start_y)]
    while stack:
        x, y = stack.pop()
        if x < 0 or x >= w or y < 0 or y >= h:
            continue
        if mask[y, x]:
            continue

        pixel = img_array[y, x, :3].astype(np.int16)
        diff = np.abs(pixel - target_color)
        if np.all(diff <= tolerance):
            mask[y, x] = True
            stack.append((x + 1, y))
            stack.append((x - 1, y))
            stack.append((x, y + 1))
            stack.append((x, y - 1))

    return mask


def flood_fill_bg_fast(img_array, start_x, start_y, tolerance):
    """Optimized flood fill using scanline approach."""
    h, w = img_array.shape[:2]
    mask = np.zeros((h, w), dtype=bool)
    target_color = img_array[start_y, start_x, :3].astype(np.int16)

    stack = [(start_x, start_y)]
    while stack:
        x, y = stack.pop()
        if y < 0 or y >= h or x < 0 or x >= w:
            continue
        if mask[y, x]:
            continue

        pixel = img_array[y, x, :3].astype(np.int16)
        diff = np.abs(pixel - target_color)
        if not np.all(diff <= tolerance):
            continue

        # Scan left
        left = x
        while left > 0:
            pixel = img_array[y, left - 1, :3].astype(np.int16)
            if mask[y, left - 1] or not np.all(np.abs(pixel - target_color) <= tolerance):
                break
            left -= 1

        # Scan right
        right = x
        while right < w - 1:
            pixel = img_array[y, right + 1, :3].astype(np.int16)
            if mask[y, right + 1] or not np.all(np.abs(pixel - target_color) <= tolerance):
                break
            right += 1

        # Fill the scanline
        mask[y, left:right + 1] = True

        # Add pixels above and below
        for nx in range(left, right + 1):
            if y > 0 and not mask[y - 1, nx]:
                stack.append((nx, y - 1))
            if y < h - 1 and not mask[y + 1, nx]:
                stack.append((nx, y + 1))

    return mask


def remove_background(input_path, output_path, crop_bottom=0, extra_corners=None):
    """Remove background from image using flood fill from corners."""
    img = Image.open(input_path).convert('RGB')

    # Crop bottom if needed (for watermarks)
    if crop_bottom > 0:
        img = img.crop((0, 0, img.width, img.height - crop_bottom))

    img_array = np.array(img)
    h, w = img_array.shape[:2]

    # Flood fill from all 4 corners
    corners = [
        (0, 0),           # top-left
        (w - 1, 0),       # top-right
        (0, h - 1),       # bottom-left
        (w - 1, h - 1),   # bottom-right
    ]

    if extra_corners:
        corners.extend(extra_corners)

    combined_mask = np.zeros((h, w), dtype=bool)
    for cx, cy in corners:
        print(f"  Flood fill from ({cx}, {cy}), color={img_array[cy, cx, :3]}")
        mask = flood_fill_bg_fast(img_array, cx, cy, TOLERANCE)
        combined_mask |= mask

    # Also flood fill from edge midpoints for better coverage
    edge_points = [
        (w // 2, 0),       # top-center
        (w // 2, h - 1),   # bottom-center
        (0, h // 2),       # left-center
        (w - 1, h // 2),   # right-center
    ]

    for ex, ey in edge_points:
        pixel = img_array[ey, ex, :3].astype(np.int16)
        # Check if this edge point color is similar to any corner color
        for cx, cy in corners:
            corner_color = img_array[cy, cx, :3].astype(np.int16)
            if np.all(np.abs(pixel - corner_color) <= TOLERANCE):
                mask = flood_fill_bg_fast(img_array, ex, ey, TOLERANCE)
                combined_mask |= mask
                break

    # Count removed pixels
    total_pixels = h * w
    removed = np.sum(combined_mask)
    pct = removed / total_pixels * 100
    print(f"  Removed {removed}/{total_pixels} pixels ({pct:.1f}%)")

    # Create RGBA output
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = img_array
    rgba[:, :, 3] = 255

    # Apply transparency
    rgba[combined_mask, 3] = 0

    # Anti-alias edges using numpy shift comparison
    pad_mask = np.pad(combined_mask, 1, mode='constant', constant_values=False)
    edge = (
        pad_mask[:-2, 1:-1] | pad_mask[2:, 1:-1] |
        pad_mask[1:-1, :-2] | pad_mask[1:-1, 2:]
    ) & ~combined_mask
    rgba[edge, 3] = (rgba[edge, 3] * 0.5).astype(np.uint8)

    result = Image.fromarray(rgba, 'RGBA')
    result.save(output_path, 'PNG')
    print(f"  Saved: {output_path}")
    return pct


def main():
    enemies = [
        'soldier', 'cavalry', 'goblin', 'armored_giant',
        'undead', 'shield_bearer', 'healer', 'burrower',
        'troll', 'dark_knight', 'shadow_lord', 'dragon_emperor'
    ]

    # Special handling for watermarked images
    crop_settings = {
        'troll': 80,        # crop bottom 80px for watermark
        'shadow_lord': 0,   # watermark is small, flood fill should handle it
    }

    for enemy in enemies:
        jpg_path = os.path.join(ENEMIES_DIR, f'{enemy}.jpg')
        png_path = os.path.join(ENEMIES_DIR, f'{enemy}.png')

        if not os.path.exists(jpg_path):
            print(f"SKIP: {jpg_path} not found")
            continue

        print(f"\nProcessing: {enemy}")
        crop = crop_settings.get(enemy, 0)
        pct = remove_background(jpg_path, png_path, crop_bottom=crop)

        if pct < 10:
            print(f"  WARNING: Only {pct:.1f}% removed — may need manual adjustment")

    print("\n=== Done! All enemy sprites processed. ===")


if __name__ == '__main__':
    main()
