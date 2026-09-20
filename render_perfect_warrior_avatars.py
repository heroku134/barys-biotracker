import os
import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw

LANDMARKS_DIR = r"c:\Users\KPK\Documents\вав\barys_biotracker\assets\images\landmarks"
ASSETS_DIR = r"c:\Users\KPK\Documents\вав\barys_biotracker\assets\images"
CLEAN_CUTOUT = os.path.join(ASSETS_DIR, "warrior_cutout_clean.png")

OUTPUT_SIZE = (800, 800)

def pil_to_cv(pil_img):
    return cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)

def cv_to_pil(cv_img):
    return Image.fromarray(cv2.cvtColor(cv_img, cv2.COLOR_BGR2RGB))

def stylize_anime_bg(pil_img, crop_box=None, blur_radius=2.0, brightness=1.0, contrast=1.1, saturation=1.2):
    """Turns photo into painterly anime concept art background."""
    if crop_box:
        pil_img = pil_img.crop(crop_box)
        
    w, h = pil_img.size
    scale = max(OUTPUT_SIZE[0] / w, OUTPUT_SIZE[1] / h)
    new_w, new_h = int(w * scale), int(h * scale)
    pil_img = pil_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    left = (new_w - OUTPUT_SIZE[0]) // 2
    top = (new_h - OUTPUT_SIZE[1]) // 2
    pil_img = pil_img.crop((left, top, left + OUTPUT_SIZE[0], top + OUTPUT_SIZE[1]))
    
    cv_img = pil_to_cv(pil_img)
    smooth = cv2.edgePreservingFilter(cv_img, flags=1, sigma_s=45, sigma_r=0.38)
    detail = cv2.detailEnhance(smooth, sigma_s=10, sigma_r=0.15)
    
    res = cv_to_pil(detail)
    if brightness != 1.0:
        res = ImageEnhance.Brightness(res).enhance(brightness)
    if contrast != 1.0:
        res = ImageEnhance.Contrast(res).enhance(contrast)
    if saturation != 1.0:
        res = ImageEnhance.Color(res).enhance(saturation)
    if blur_radius > 0:
        res = res.filter(ImageFilter.GaussianBlur(radius=blur_radius))
        
    return res

def get_warrior_torso(apply_eyes='open', apply_sweat=False, apply_smirk=False, apply_glint=False, apply_watch=False):
    """
    Crops warrior to torso portrait (Ak-Kalpak down to waist/saber),
    applies facial modifications on clean RGB image, then restores alpha.
    """
    raw_warrior = Image.open(CLEAN_CUTOUT).convert('RGBA')
    
    # 1. Torso crop: x: 70..630, y: 50..780
    torso = raw_warrior.crop((70, 50, 630, 780))
    # Dimensions: 560 x 730
    
    # Extract RGB and Alpha
    torso_rgb = np.array(torso)[:, :, :3].copy()
    torso_alpha = np.array(torso)[:, :, 3].copy()
    
    # Eye coordinates in torso coordinates:
    # Original cutout face: left eye (355, 178), right eye (396, 179)
    # After crop ((70, 50)): left eye is (355-70, 178-50) = (285, 128)
    # right eye is (396-70, 179-50) = (326, 129)
    ex1, ey1 = 285, 128
    ex2, ey2 = 326, 129
    
    # Skin color sample from cheek below eyes (y ~ 155)
    skin_left = torso_rgb[155, ex1].tolist()
    skin_right = torso_rgb[155, ex2].tolist()
    
    if apply_eyes == 'closed' or apply_eyes == 'zen':
        # Eyelid skin fill
        cv2.ellipse(torso_rgb, (ex1, ey1), (12, 6), 0, 0, 360, skin_left, -1)
        cv2.ellipse(torso_rgb, (ex2, ey2), (12, 6), 5, 0, 360, skin_right, -1)
        
        # Upper lid delicate crease
        cv2.ellipse(torso_rgb, (ex1, ey1 - 4), (10, 2), 0, 190, 350, (140, 110, 95), 1, cv2.LINE_AA)
        cv2.ellipse(torso_rgb, (ex2, ey2 - 4), (10, 2), 5, 190, 350, (140, 110, 95), 1, cv2.LINE_AA)
        
        # Peaceful closed lash line at bottom of eye
        pts_l = np.array([[ex1 - 12, ey1 + 1], [ex1 - 6, ey1 + 5], [ex1, ey1 + 6], [ex1 + 6, ey1 + 5], [ex1 + 12, ey1 + 1]], np.int32).reshape((-1, 1, 2))
        cv2.polylines(torso_rgb, [pts_l], False, (35, 26, 24), 2, cv2.LINE_AA)
        pts_r = np.array([[ex2 - 12, ey2 + 1], [ex2 - 6, ey2 + 5], [ex2, ey2 + 6], [ex2 + 6, ey2 + 5], [ex2 + 12, ey2 + 1]], np.int32).reshape((-1, 1, 2))
        cv2.polylines(torso_rgb, [pts_r], False, (35, 26, 24), 2, cv2.LINE_AA)
        
        # Subtle upward lash outer tick
        cv2.line(torso_rgb, (ex1 + 12, ey1 + 1), (ex1 + 14, ey1 - 1), (35, 26, 24), 1, cv2.LINE_AA)
        cv2.line(torso_rgb, (ex2 + 12, ey2 + 1), (ex2 + 14, ey2 - 1), (35, 26, 24), 1, cv2.LINE_AA)
        
        if apply_eyes == 'zen':
            # Mindful peaceful smile at mouth corners
            # Mouth center is around (306, 172)
            cv2.line(torso_rgb, (300, 172), (318, 172), (40, 28, 25), 2, cv2.LINE_AA)
            cv2.line(torso_rgb, (300, 172), (297, 170), (40, 28, 25), 1, cv2.LINE_AA)
            cv2.line(torso_rgb, (318, 172), (321, 170), (40, 28, 25), 1, cv2.LINE_AA)
            
    elif apply_eyes == 'tired':
        # Half-lidded heavy eyes: shade top 40%
        skin_shadow = (165, 135, 110)
        cv2.ellipse(torso_rgb, (ex1, ey1 - 3), (12, 4), 0, 0, 360, skin_shadow, -1)
        cv2.ellipse(torso_rgb, (ex2, ey2 - 3), (12, 4), 5, 0, 360, skin_shadow, -1)
        cv2.line(torso_rgb, (ex1 - 12, ey1 - 1), (ex1 + 12, ey1), (35, 28, 26), 2, cv2.LINE_AA)
        cv2.line(torso_rgb, (ex2 - 12, ey2), (ex2 + 12, ey2 + 1), (35, 28, 26), 2, cv2.LINE_AA)
        
    if apply_glint:
        # Sharp vibrant glint in pupils
        cv2.circle(torso_rgb, (ex1, ey1), 2, (0, 255, 163), -1, cv2.LINE_AA)
        cv2.circle(torso_rgb, (ex2, ey2), 2, (0, 255, 163), -1, cv2.LINE_AA)
        cv2.circle(torso_rgb, (ex1 + 1, ey1 - 1), 1, (255, 255, 255), -1, cv2.LINE_AA)
        cv2.circle(torso_rgb, (ex2 + 1, ey2 - 1), 1, (255, 255, 255), -1, cv2.LINE_AA)
        
    if apply_smirk:
        # Confident battle smirk
        cv2.line(torso_rgb, (310, 172), (319, 169), (32, 24, 22), 2, cv2.LINE_AA)
        
    return Image.fromarray(np.dstack([torso_rgb, torso_alpha]))

def apply_lighting_and_rim(warrior_img, tint_mult, rim_color):
    """Applies ambient color grade and subtle glowing rim light along character edge."""
    arr = np.array(warrior_img)
    rgb = arr[:, :, :3].astype(float) * np.array(tint_mult)
    alpha = arr[:, :, 3]
    
    alpha_pil = Image.fromarray(alpha)
    edge_map = np.array(alpha_pil.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.6))).astype(float) / 255.0
    rgb = np.clip(rgb + edge_map[:, :, None] * np.array(rim_color), 0, 255)
    
    return Image.fromarray(np.dstack([rgb.astype(np.uint8), alpha]))

# ==============================================================================
# 1. SLEEP: BURANA TOWER (Night, stars, peaceful closed eyes)
# ==============================================================================
def make_sleep():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "burana.jpg"))
    # In burana.jpg (4804 x 2975), tower is at x ~ 2100..2700, y ~ 700..1900
    # Crop so Burana tower is prominent in the upper left background!
    crop = (1500, 300, 3600, 2400)
    bg = stylize_anime_bg(bg_raw, crop_box=crop, blur_radius=2.5, brightness=0.52, contrast=1.18, saturation=0.9)
    
    # Deep midnight blue night grading
    bg_arr = np.array(bg).astype(float) * np.array([0.38, 0.48, 0.78])
    # Add twinkling starry sky
    np.random.seed(101)
    stars = (np.random.rand(800, 800) > 0.995) & (np.arange(800)[:, None] < 300)
    bg_arr[stars] = [240, 245, 255]
    
    # Soft sky glow
    y_coords = np.arange(800)[:, None, None]
    glow = np.exp(-((y_coords - 60) / 200)**2) * np.array([25, 38, 80])
    bg_arr = np.clip(bg_arr + glow, 0, 255).astype(np.uint8)
    bg_final = Image.fromarray(bg_arr)
    
    # Warrior with sleeping eyes & moonlight rim
    warrior = get_warrior_torso(apply_eyes='closed')
    warrior = apply_lighting_and_rim(warrior, [0.74, 0.80, 0.96], [65, 115, 185])
    
    # Scale torso to fit canvas (height ~ 720)
    target_h = 720
    target_w = int(warrior.width * (target_h / warrior.height))
    warrior_scaled = warrior.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # Shift warrior slightly to the right (x = 180) so Burana tower is clearly visible on the left
    pos_x = 800 - target_w - 20
    pos_y = 800 - target_h + 30
    bg_final.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    return bg_final

# ==============================================================================
# 2. TIRED: ALA-TOO MOUNTAINS (Twilight dusk, snowy peaks, weary sweat)
# ==============================================================================
def make_tired():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "ala_too.jpg"))
    # (4032, 2268), snowy peaks upper right
    crop = (900, 100, 3500, 2100)
    bg = stylize_anime_bg(bg_raw, crop_box=crop, blur_radius=2.0, brightness=0.72, contrast=1.05, saturation=0.85)
    
    # Cold dusk slate-rose mountain mist
    bg_arr = np.array(bg).astype(float) * np.array([0.78, 0.72, 0.86])
    y_coords = np.arange(800)[:, None, None]
    fog = np.exp(-((y_coords - 350) / 180)**2) * np.array([40, 42, 50])
    bg_arr = np.clip(bg_arr + fog, 0, 255).astype(np.uint8)
    bg_final = Image.fromarray(bg_arr)
    
    warrior = get_warrior_torso(apply_eyes='tired')
    warrior = apply_lighting_and_rim(warrior, [0.82, 0.78, 0.88], [80, 70, 95])
    
    target_h = 720
    target_w = int(warrior.width * (target_h / warrior.height))
    warrior_scaled = warrior.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # Shift warrior slightly left (x = 30) so Ala-Too snowy peaks shine on the right
    pos_x = 30
    pos_y = 800 - target_h + 30
    bg_final.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    return bg_final

# ==============================================================================
# 3. CHARGED: SULAIMAN-TOO (Golden sunrise, heroic gaze, sunburst, gold rim)
# ==============================================================================
def make_charged():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "sulaiman_too_viewpoint.jpg"))
    # (5472, 3648), sacred limestone peak
    crop = (600, 100, 4600, 3300)
    bg = stylize_anime_bg(bg_raw, crop_box=crop, blur_radius=2.0, brightness=1.1, contrast=1.15, saturation=1.35)
    
    # Golden sunrise grading
    bg_arr = np.array(bg).astype(float) * np.array([1.18, 1.06, 0.85])
    # Sunburst behind peak (top right)
    y_grid, x_grid = np.ogrid[:800, :800]
    dist = np.sqrt((x_grid - 680)**2 + (y_grid - 100)**2)
    sunburst = np.exp(-dist / 260)[:, :, None] * np.array([80, 60, 15])
    bg_arr = np.clip(bg_arr + sunburst, 0, 255).astype(np.uint8)
    bg_final = Image.fromarray(bg_arr)
    
    warrior = get_warrior_torso(apply_eyes='open', apply_smirk=True, apply_glint=True)
    warrior = apply_lighting_and_rim(warrior, [1.06, 1.02, 0.94], [160, 125, 35]) # Brilliant gold rim
    
    target_h = 720
    target_w = int(warrior.width * (target_h / warrior.height))
    warrior_scaled = warrior.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    # Shift warrior left so Sulaiman-Too peak rises on right
    pos_x = 35
    pos_y = 800 - target_h + 30
    bg_final.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    # Golden dawn power motes
    draw = ImageDraw.Draw(bg_final)
    sparks = [(180, 240), (220, 160), (480, 180), (520, 250), (320, 80)]
    for sx, sy in sparks:
        draw.ellipse([sx - 3, sy - 3, sx + 3, sy + 3], fill=(255, 230, 110, 220))
        draw.ellipse([sx - 1, sy - 1, sx + 1, sy + 1], fill=(255, 255, 255, 255))
        
    return bg_final

# ==============================================================================
# 4. WORKOUT: BISHKEK ARENA (Stadium lights, athletic drive, amber rim)
# ==============================================================================
def make_workout():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "bishkek_arena.jpg"))
    # (5036, 3777), arena crowd & pitch
    crop = (400, 300, 4400, 3300)
    bg = stylize_anime_bg(bg_raw, crop_box=crop, blur_radius=2.5, brightness=0.92, contrast=1.2, saturation=1.35)
    
    # Floodlight atmosphere
    bg_arr = np.array(bg).astype(float)
    y_coords = np.arange(800)[:, None, None]
    floodlights = np.exp(-((y_coords - 50) / 150)**2) * np.array([65, 75, 80])
    bg_arr = np.clip(bg_arr + floodlights, 0, 255).astype(np.uint8)
    bg_final = Image.fromarray(bg_arr)
    
    warrior = get_warrior_torso(apply_eyes='open', apply_glint=True)
    warrior = apply_lighting_and_rim(warrior, [1.05, 0.98, 0.92], [175, 105, 25]) # High-energy amber rim
    
    target_h = 720
    target_w = int(warrior.width * (target_h / warrior.height))
    warrior_scaled = warrior.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2
    pos_y = 800 - target_h + 30
    bg_final.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    return bg_final

# ==============================================================================
# 5. NORMAL: ALA-TOO PANORAMA (Sunny morning alpine view, pristine warrior)
# ==============================================================================
def make_normal():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "ala_too.jpg"))
    crop = (300, 100, 3300, 2100)
    bg = stylize_anime_bg(bg_raw, crop_box=crop, blur_radius=2.0, brightness=1.04, contrast=1.12, saturation=1.22)
    
    warrior = get_warrior_torso(apply_eyes='open')
    # Clean natural daylight rim
    warrior = apply_lighting_and_rim(warrior, [1.0, 1.0, 1.0], [90, 100, 110])
    
    target_h = 720
    target_w = int(warrior.width * (target_h / warrior.height))
    warrior_scaled = warrior.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2 - 15
    pos_y = 800 - target_h + 30
    bg.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    return bg

# ==============================================================================
# 6. MEDITATION: SONG-KUL LAKE (Alpine serenity, closed zen eyes, yurts)
# ==============================================================================
def make_meditation():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "song_kul.jpg"))
    # (1620, 1080), alpine lake, yurts, mountains
    crop = (80, 80, 1520, 1020)
    bg = stylize_anime_bg(bg_raw, crop_box=crop, blur_radius=2.0, brightness=1.05, contrast=1.08, saturation=1.25)
    
    # Sage/emerald zen tranquility
    bg_arr = np.array(bg).astype(float) * np.array([0.92, 1.08, 1.02])
    bg_final = Image.fromarray(np.clip(bg_arr, 0, 255).astype(np.uint8))
    
    warrior = get_warrior_torso(apply_eyes='zen')
    warrior = apply_lighting_and_rim(warrior, [0.94, 1.05, 0.98], [50, 160, 115]) # Sage rim
    
    target_h = 720
    target_w = int(warrior.width * (target_h / warrior.height))
    warrior_scaled = warrior.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2
    pos_y = 800 - target_h + 30
    bg_final.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    # Soft sage/emerald atmospheric halo around upper body (zen mindfulness aura)
    halo = Image.new("RGBA", (800, 800), (0, 0, 0, 0))
    halo_draw = ImageDraw.Draw(halo)
    halo_draw.ellipse([250, 100, 550, 400], fill=(80, 200, 150, 30))
    halo = halo.filter(ImageFilter.GaussianBlur(35))
    bg_final.paste(halo, (0, 0), halo)
        
    return bg_final

if __name__ == "__main__":
    print("Rendering 1/6: Sleep (Burana Tower)...")
    make_sleep().save(os.path.join(ASSETS_DIR, "hero_barys_sleep.jpg"), quality=96)
    
    print("Rendering 2/6: Tired (Ala-Too Mountains)...")
    make_tired().save(os.path.join(ASSETS_DIR, "hero_barys_tired.jpg"), quality=96)
    
    print("Rendering 3/6: Charged (Sulaiman-Too)...")
    make_charged().save(os.path.join(ASSETS_DIR, "hero_barys_charged.jpg"), quality=96)
    
    print("Rendering 4/6: Workout (Bishkek Arena)...")
    make_workout().save(os.path.join(ASSETS_DIR, "hero_barys_workout.jpg"), quality=96)
    
    print("Rendering 5/6: Normal / In Tone (Ala-Too Panorama)...")
    make_normal().save(os.path.join(ASSETS_DIR, "hero_barys_normal.jpg"), quality=96)
    
    print("Rendering 6/6: Meditation (Song-Kul Lake)...")
    make_meditation().save(os.path.join(ASSETS_DIR, "hero_barys_meditation.jpg"), quality=96)
    
    print("PERFECT WARRIOR AVATARS WITH KYRGYZ LANDMARKS RENDERED!")
