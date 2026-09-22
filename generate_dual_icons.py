import os
import json
from PIL import Image
import numpy as np
from scipy.ndimage import distance_transform_edt

def generate_all():
    root = os.path.dirname(os.path.abspath(__file__))
    src_path = os.path.join(root, 'assets', 'images', 'kalkan_app_icon_1024.png')
    src = Image.open(src_path).convert('RGB')
    arr = np.array(src, dtype=np.float32)

    # 1. Background and emblem detection
    bg_dark = np.array([5.0, 5.0, 6.0], dtype=np.float32)
    diff = np.sqrt(np.sum((arr - bg_dark)**2, axis=2))
    core_mask = diff > 40.0

    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    brightness = 0.299 * r + 0.587 * g + 0.114 * b
    is_silver = (np.abs(r - g) < 18) & (np.abs(g - b) < 18) & (brightness > 90) & core_mask
    is_gold = (~is_silver) & core_mask

    # 2. Dark master
    dark_img = Image.fromarray(np.uint8(np.clip(arr, 0, 255)), mode='RGB')
    dark_master_path = os.path.join(root, 'assets', 'images', 'kalkan_app_icon_dark_1024.png')
    dark_img.save(dark_master_path, 'PNG')
    print(f'Created: {dark_master_path}')

    # 3. Light master
    target_rgb = np.zeros_like(arr)
    silver_val = 20.0 + (brightness / 255.0) * 28.0
    target_rgb[is_silver, 0] = silver_val[is_silver] * 0.95
    target_rgb[is_silver, 1] = silver_val[is_silver] * 1.00
    target_rgb[is_silver, 2] = silver_val[is_silver] * 1.10

    target_rgb[is_gold, 0] = np.clip(r[is_gold] * 1.25 + 10, 0, 218)
    target_rgb[is_gold, 1] = np.clip(g[is_gold] * 1.15 + 5, 0, 180)
    target_rgb[is_gold, 2] = np.clip(b[is_gold] * 0.85, 0, 95)

    indices = distance_transform_edt(~core_mask, return_distances=False, return_indices=True)
    extrapolated_rgb = target_rgb[indices[0], indices[1]]

    alpha = np.clip((diff - 6.0) / 45.0, 0.0, 1.0) ** 1.1
    light_bg = np.array([248.0, 249.0, 250.0], dtype=np.float32)

    light_rgb = np.zeros_like(arr)
    for c in range(3):
        light_rgb[:, :, c] = light_bg[c] * (1.0 - alpha) + extrapolated_rgb[:, :, c] * alpha

    light_img = Image.fromarray(np.uint8(np.clip(light_rgb, 0, 255)), mode='RGB')
    light_master_path = os.path.join(root, 'assets', 'images', 'kalkan_app_icon_light_1024.png')
    light_img.save(light_master_path, 'PNG')
    print(f'Created: {light_master_path}')

    # 4. Android Mipmaps (both Dark and Light)
    android_res = os.path.join(root, 'android', 'app', 'src', 'main', 'res')
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    for folder, size in android_sizes.items():
        out_dir = os.path.join(android_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        # Dark
        d_res = dark_img.resize((size, size), Image.Resampling.LANCZOS)
        d_res.save(os.path.join(out_dir, 'ic_launcher.png'), 'PNG')
        # Light
        l_res = light_img.resize((size, size), Image.Resampling.LANCZOS)
        l_res.save(os.path.join(out_dir, 'ic_launcher_light.png'), 'PNG')
        print(f'Generated Android {folder}: ic_launcher.png & ic_launcher_light.png ({size}x{size})')

    # 5. iOS AppIcon.appiconset (Dark / Default) & AppIcon-Light.appiconset (Light)
    ios_base = os.path.join(root, 'ios', 'Runner', 'Assets.xcassets')
    ios_dark_set = os.path.join(ios_base, 'AppIcon.appiconset')
    ios_light_set = os.path.join(ios_base, 'AppIcon-Light.appiconset')
    os.makedirs(ios_dark_set, exist_ok=True)
    os.makedirs(ios_light_set, exist_ok=True)

    contents_file = os.path.join(ios_dark_set, 'Contents.json')
    if os.path.exists(contents_file):
        with open(contents_file, 'r', encoding='utf-8') as f:
            data = json.load(f)

        for entry in data.get('images', []):
            fname = entry.get('filename')
            if not fname:
                continue
            size_str = entry.get('size', '0x0')
            scale_str = entry.get('scale', '1x').replace('x', '')
            w, h = map(float, size_str.split('x'))
            scale = float(scale_str)
            px_w = int(round(w * scale))
            px_h = int(round(h * scale))

            # Resize Dark
            d_out = os.path.join(ios_dark_set, fname)
            dark_img.resize((px_w, px_h), Image.Resampling.LANCZOS).save(d_out, 'PNG')

            # Resize Light
            l_out = os.path.join(ios_light_set, fname)
            light_img.resize((px_w, px_h), Image.Resampling.LANCZOS).save(l_out, 'PNG')

        # Copy Contents.json to AppIcon-Light.appiconset
        with open(os.path.join(ios_light_set, 'Contents.json'), 'w', encoding='utf-8') as f:
            json.dump(data, f, indent=2)

        print('Generated all iOS Dark and Light icon sets!')

    print('Dual Dark/Light icon generation complete!')

if __name__ == '__main__':
    generate_all()
