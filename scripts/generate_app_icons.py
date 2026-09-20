import os
from PIL import Image, ImageDraw

def bezier_point(p0, p1, p2, p3, t):
    it = 1.0 - t
    return (
        it**3 * p0[0] + 3 * it**2 * t * p1[0] + 3 * it * t**2 * p2[0] + t**3 * p3[0],
        it**3 * p0[1] + 3 * it**2 * t * p1[1] + 3 * it * t**2 * p2[1] + t**3 * p3[1],
    )

def render_master_icon(size=2048):
    # Render at 2048x2048 with supersampling
    img = Image.new("RGBA", (size, size), (5, 5, 6, 255))
    draw = ImageDraw.Draw(img)

    # Subtle circular dial ring (Patek / Leica aesthetic)
    cx, cy = size / 2.0, size / 2.0
    dial_radius = size * 0.44
    draw.ellipse(
        [cx - dial_radius, cy - dial_radius, cx + dial_radius, cy + dial_radius],
        outline=(24, 26, 33, 255),
        width=int(size * 0.015),
    )
    
    # 48 dial notches
    import math
    for i in range(48):
        angle = (i * 2 * math.pi) / 48 - math.pi / 2
        is_major = i % 4 == 0
        r_outer = dial_radius - size * 0.01
        r_inner = r_outer - (size * 0.02 if is_major else size * 0.01)
        x1 = cx + r_outer * math.cos(angle)
        y1 = cy + r_outer * math.sin(angle)
        x2 = cx + r_inner * math.cos(angle)
        y2 = cy + r_inner * math.sin(angle)
        color = (196, 165, 116, 200) if is_major else (85, 88, 101, 140)
        draw.line([(x1, y1), (x2, y2)], fill=color, width=int(size * 0.0035))

    # Original coordinates in KALKAN.svg:
    # Top arc: (39, 165) C (77, 72) (209, 90) (295, 143) C (189, 104) (118, 120) (39, 165)
    # Bottom arc: (52, 195) C (130, 103) (247, 103) (325, 195)
    # Center is roughly (182, 145), width 286, height 123
    target_width = size * 0.62
    scale = target_width / 286.0
    ox = cx - 182.0 * scale
    oy = cy - 145.0 * scale

    def t(pt):
        return (ox + pt[0] * scale, oy + pt[1] * scale)

    # 1. Top crescent points
    crescent_pts = []
    N = 120
    # Top edge: (39, 165) -> (295, 143)
    for i in range(N + 1):
        t_val = i / float(N)
        pt = bezier_point((39, 165), (77, 72), (209, 90), (295, 143), t_val)
        crescent_pts.append(t(pt))
    # Bottom edge: (295, 143) -> (39, 165)
    for i in range(N + 1):
        t_val = i / float(N)
        pt = bezier_point((295, 143), (189, 104), (118, 120), (39, 165), t_val)
        crescent_pts.append(t(pt))

    # Gradient mask for top crescent
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.polygon(crescent_pts, fill=255)

    # Gradient image (Amber #C4A574 to Sage #7D9A92)
    grad_img = Image.new("RGBA", (size, size))
    for x in range(size):
        ratio = x / float(size)
        # Interpolate between #C4A574 (196, 165, 116) and #7D9A92 (125, 154, 146)
        r = int(196 * (1.0 - ratio) + 125 * ratio)
        g = int(165 * (1.0 - ratio) + 154 * ratio)
        b = int(116 * (1.0 - ratio) + 146 * ratio)
        # Draw vertical line
        for y_slice in range(int(cy - size * 0.25), int(cy + size * 0.25)):
            grad_img.putpixel((x, y_slice), (r, g, b, 255))

    img.paste(grad_img, (0, 0), mask)

    # 2. Bottom stroked arc: (52, 195) C (130, 103) (247, 103) (325, 195), stroke 13
    stroke_pts = []
    for i in range(N + 1):
        t_val = i / float(N)
        pt = bezier_point((52, 195), (130, 103), (247, 103), (325, 195), t_val)
        stroke_pts.append(t(pt))

    stroke_width = int(13.0 * scale)
    # Draw thick stroke with rounded segments
    for i in range(len(stroke_pts) - 1):
        p0 = stroke_pts[i]
        p1 = stroke_pts[i + 1]
        draw.line([p0, p1], fill=(226, 230, 236, 255), width=stroke_width)
        draw.ellipse([p0[0] - stroke_width/2, p0[1] - stroke_width/2, p0[0] + stroke_width/2, p0[1] + stroke_width/2], fill=(226, 230, 236, 255))
    draw.ellipse([stroke_pts[-1][0] - stroke_width/2, stroke_pts[-1][1] - stroke_width/2, stroke_pts[-1][0] + stroke_width/2, stroke_pts[-1][1] + stroke_width/2], fill=(226, 230, 236, 255))

    return img.resize((1024, 1024), Image.Resampling.LANCZOS)

def main():
    base_dir = r"c:\Users\KPK\Documents\вав\barys_biotracker"
    master = render_master_icon()

    # Save 1024 master
    master_path = os.path.join(base_dir, "assets", "images", "kalkan_app_icon_1024.png")
    os.makedirs(os.path.dirname(master_path), exist_ok=True)
    master.save(master_path, "PNG")
    print(f"Master saved: {master_path}")

    # Android Sizes
    android_res = os.path.join(base_dir, "android", "app", "src", "main", "res")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, px in android_sizes.items():
        out_dir = os.path.join(android_res, folder)
        os.makedirs(out_dir, exist_ok=True)
        icon_path = os.path.join(out_dir, "ic_launcher.png")
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(icon_path, "PNG")
        print(f"Saved Android: {icon_path} ({px}x{px})")

    # iOS Sizes
    ios_iconset = os.path.join(base_dir, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for filename, px in ios_sizes.items():
        out_path = os.path.join(ios_iconset, filename)
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        resized.save(out_path, "PNG")
        print(f"Saved iOS: {out_path} ({px}x{px})")

    print("ALL ICONS GENERATED SUCCESSFULLY!")

if __name__ == "__main__":
    main()
