import os
import cv2
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw

LANDMARKS_DIR = r"c:\Users\KPK\Documents\вав\barys_biotracker\assets\images\landmarks"
ASSETS_DIR = r"c:\Users\KPK\Documents\вав\barys_biotracker\assets\images"
CUTOUT_PATH = os.path.join(ASSETS_DIR, "warrior_cutout_clean.png")

OUTPUT_SIZE = (800, 800)

def pil_to_cv(pil_img):
    return cv2.cvtColor(np.array(pil_img), cv2.COLOR_RGB2BGR)

def cv_to_pil(cv_img):
    return Image.fromarray(cv2.cvtColor(cv_img, cv2.COLOR_BGR2RGB))

def stylize_anime_background(pil_img, crop_box=None, blur_radius=2.0, brightness=1.0, contrast=1.1, saturation=1.2):
    """Transforms photographic background into painterly anime concept art style."""
    if crop_box:
        pil_img = pil_img.crop(crop_box)
    
    w, h = pil_img.size
    scale = max(OUTPUT_SIZE[0] / w, OUTPUT_SIZE[1] / h)
    new_w, new_h = int(w * scale), int(h * scale)
    pil_img = pil_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    left = (new_w - OUTPUT_SIZE[0]) // 2
    top = (new_h - OUTPUT_SIZE[1]) // 2
    pil_img = pil_img.crop((left, top, left + OUTPUT_SIZE[0], top + OUTPUT_SIZE[1]))
    
    # Anime edge-preserving painterly filter
    cv_img = pil_to_cv(pil_img)
    smooth = cv2.edgePreservingFilter(cv_img, flags=1, sigma_s=40, sigma_r=0.35)
    detail = cv2.detailEnhance(smooth, sigma_s=10, sigma_r=0.15)
    
    res_pil = cv_to_pil(detail)
    if brightness != 1.0:
        res_pil = ImageEnhance.Brightness(res_pil).enhance(brightness)
    if contrast != 1.0:
        res_pil = ImageEnhance.Contrast(res_pil).enhance(contrast)
    if saturation != 1.0:
        res_pil = ImageEnhance.Color(res_pil).enhance(saturation)
        
    if blur_radius > 0:
        res_pil = res_pil.filter(ImageFilter.GaussianBlur(radius=blur_radius))
        
    return res_pil

def load_warrior():
    return Image.open(CUTOUT_PATH).convert('RGBA')

# ==============================================================================
# 1. SLEEP: BURANA TOWER (Night, starry sky, peaceful closed eyes)
# ==============================================================================
def create_sleep_avatar():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "burana.jpg"))
    # In burana.jpg (4804 x 2975), the tower is centered at x: 2100..2700, y: 700..1900
    # Crop so tower is positioned on the left side of background
    crop_box = (1500, 400, 3700, 2600)
    bg = stylize_anime_background(bg_raw, crop_box=crop_box, blur_radius=2.5, brightness=0.5, contrast=1.2, saturation=0.9)
    
    # Deep night palette
    bg_arr = np.array(bg).astype(float)
    bg_arr = bg_arr * np.array([0.35, 0.45, 0.75]) # Midnight blue tint
    
    # Add stars and soft lunar glow
    np.random.seed(42)
    star_mask = (np.random.rand(800, 800) > 0.996) & (np.arange(800)[:, None] < 350)
    bg_arr[star_mask] = [240, 245, 255]
    
    # Ethereal sky gradient
    y_coords = np.arange(800)[:, None, None]
    night_glow = np.exp(-((y_coords - 80) / 220)**2) * np.array([25, 40, 85])
    bg_arr = np.clip(bg_arr + night_glow, 0, 255).astype(np.uint8)
    bg_img = Image.fromarray(bg_arr)
    
    # Warrior with sleeping eyes
    warrior = load_warrior()
    w_arr = np.array(warrior)
    
    # Eyelid fill with natural skin tone
    skin_left = w_arr[205, 350, :3].astype(int).tolist()
    skin_right = w_arr[205, 395, :3].astype(int).tolist()
    cv2.ellipse(w_arr, (355, 178), (12, 6), 0, 0, 360, skin_left, -1)
    cv2.ellipse(w_arr, (396, 179), (12, 6), 5, 0, 360, skin_right, -1)
    
    # Gentle closed lash lines
    pts_l = np.array([[343, 179], [349, 183], [356, 184], [362, 183], [368, 179]], np.int32).reshape((-1, 1, 2))
    cv2.polylines(w_arr, [pts_l], False, (35, 26, 24), 2, cv2.LINE_AA)
    pts_r = np.array([[384, 180], [390, 184], [397, 185], [403, 184], [409, 180]], np.int32).reshape((-1, 1, 2))
    cv2.polylines(w_arr, [pts_r], False, (35, 26, 24), 2, cv2.LINE_AA)
    
    # Nighttime lighting and lunar rim light on warrior
    w_rgb = w_arr[:, :, :3].astype(float) * np.array([0.72, 0.78, 0.94])
    alpha_img = Image.fromarray(w_arr[:, :, 3])
    edge_map = np.array(alpha_img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.5))).astype(float) / 255.0
    rim_color = np.array([55, 105, 175]) # Lunar blue
    w_rgb = np.clip(w_rgb + edge_map[:, :, None] * rim_color, 0, 255)
    
    warrior_mod = Image.fromarray(np.dstack([w_rgb.astype(np.uint8), w_arr[:, :, 3]]))
    
    # Scale warrior and place on canvas (shifted slightly right so Burana is visible on left)
    target_h = 770
    target_w = int(warrior_mod.width * (target_h / warrior_mod.height))
    warrior_scaled = warrior_mod.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2 + 55
    pos_y = 800 - target_h + 30
    bg_img.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    # Subtle floating dream particles
    draw = ImageDraw.Draw(bg_img)
    # Draw soft Zzz or dream orbs
    orbs = [(480, 180, 5), (510, 150, 7), (545, 120, 10)]
    for ox, oy, r in orbs:
        draw.ellipse([ox - r, oy - r, ox + r, oy + r], fill=(180, 210, 255, 160), outline=(220, 240, 255, 220))
        
    return bg_img

# ==============================================================================
# 2. TIRED: ALA-TOO MOUNTAINS (Dusk, mountain mist, weary face, sweat beads)
# ==============================================================================
def create_tired_avatar():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "ala_too.jpg"))
    # (4032, 2268), snowy peaks at upper right and center
    crop_box = (1000, 100, 3600, 2100)
    bg = stylize_anime_background(bg_raw, crop_box=crop_box, blur_radius=2.0, brightness=0.75, contrast=1.05, saturation=0.85)
    
    # Dusk slate-rose mountain mist
    bg_arr = np.array(bg).astype(float)
    dusk_mult = np.array([0.80, 0.72, 0.85]) # Cool dusk
    bg_arr = bg_arr * dusk_mult
    # Fog layer across middle
    y_coords = np.arange(800)[:, None, None]
    fog = np.exp(-((y_coords - 450) / 180)**2) * np.array([45, 45, 55])
    bg_arr = np.clip(bg_arr + fog, 0, 255).astype(np.uint8)
    bg_img = Image.fromarray(bg_arr)
    
    # Warrior with tired expression
    warrior = load_warrior()
    w_arr = np.array(warrior)
    
    # Half-lidded weary eyes: lower upper eyelid by drawing skin fold over top half of eyes
    # Left eye: cover upper 40% with skin shadow
    skin_shadow = (165, 135, 110)
    cv2.ellipse(w_arr, (355, 175), (12, 4), 0, 0, 360, skin_shadow, -1)
    cv2.ellipse(w_arr, (396, 176), (12, 4), 5, 0, 360, skin_shadow, -1)
    
    # Drooping heavy lash line
    cv2.line(w_arr, (342, 177), (368, 178), (35, 28, 26), 2, cv2.LINE_AA)
    cv2.line(w_arr, (384, 178), (409, 179), (35, 28, 26), 2, cv2.LINE_AA)
    
    # Sweat droplets on forehead and temple (authentic exhaustion detail)
    sweat_drops = [(335, 160), (342, 195), (410, 190), (370, 155)]
    for sx, sy in sweat_drops:
        cv2.circle(w_arr, (sx, sy), 3, (210, 235, 255), -1, cv2.LINE_AA)
        cv2.circle(w_arr, (sx - 1, sy - 1), 1, (255, 255, 255), -1, cv2.LINE_AA)
        # Drop tail
        cv2.line(w_arr, (sx, sy), (sx, sy + 4), (180, 220, 245), 1, cv2.LINE_AA)
        
    # Recovery slate-rose tone on warrior
    w_rgb = w_arr[:, :, :3].astype(float) * np.array([0.82, 0.78, 0.88])
    # Mild red accent on cheeks/brow (exertion flush)
    cv2.ellipse(w_rgb, (330, 205), (15, 8), 0, 0, 360, (20, -5, -5), -1)
    cv2.ellipse(w_rgb, (410, 205), (15, 8), 0, 0, 360, (20, -5, -5), -1)
    w_rgb = np.clip(w_rgb, 0, 255)
    
    warrior_mod = Image.fromarray(np.dstack([w_rgb.astype(np.uint8), w_arr[:, :, 3]]))
    
    target_h = 770
    target_w = int(warrior_mod.width * (target_h / warrior_mod.height))
    warrior_scaled = warrior_mod.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2 - 30 # slightly left so Ala-Too snowy peak is seen on right
    pos_y = 800 - target_h + 30
    bg_img.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    return bg_img

# ==============================================================================
# 3. CHARGED: SULAIMAN-TOO (Golden sunrise, peak readiness, sunbeams, heroic aura)
# ==============================================================================
def create_charged_avatar():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "sulaiman_too_viewpoint.jpg"))
    # (5472, 3648), iconic sacred rocky peak in center
    crop_box = (800, 200, 4800, 3400)
    bg = stylize_anime_background(bg_raw, crop_box=crop_box, blur_radius=2.0, brightness=1.1, contrast=1.15, saturation=1.35)
    
    # Golden dawn sunrise grading
    bg_arr = np.array(bg).astype(float)
    gold_mult = np.array([1.18, 1.08, 0.88]) # Golden morning warmth
    bg_arr = bg_arr * gold_mult
    
    # Radiant sunrise sunburst behind mountain peak (top right)
    y_grid, x_grid = np.ogrid[:800, :800]
    dist = np.sqrt((x_grid - 650)**2 + (y_grid - 120)**2)
    sunburst = np.exp(-dist / 280)[:, :, None] * np.array([75, 55, 10])
    bg_arr = np.clip(bg_arr + sunburst, 0, 255).astype(np.uint8)
    bg_img = Image.fromarray(bg_arr)
    
    # Warrior with sharp heroic expression and golden rim light
    warrior = load_warrior()
    w_arr = np.array(warrior)
    
    # Sharpen and illuminate eyes with golden/cyber-mint glint
    cv2.circle(w_arr, (355, 178), 2, (0, 255, 163), -1, cv2.LINE_AA)
    cv2.circle(w_arr, (396, 179), 2, (0, 255, 163), -1, cv2.LINE_AA)
    cv2.circle(w_arr, (356, 177), 1, (255, 255, 255), -1, cv2.LINE_AA)
    cv2.circle(w_arr, (397, 178), 1, (255, 255, 255), -1, cv2.LINE_AA)
    
    # Confident heroic slight smirk at mouth corner
    cv2.line(w_arr, (380, 222), (388, 220), (32, 24, 22), 2, cv2.LINE_AA)
    
    # Heroic golden rim-light on hair, Ak-Kalpak, and chapan shoulders
    w_rgb = w_arr[:, :, :3].astype(float) * np.array([1.06, 1.02, 0.95])
    alpha_img = Image.fromarray(w_arr[:, :, 3])
    edge_map = np.array(alpha_img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.8))).astype(float) / 255.0
    gold_rim = np.array([140, 110, 30]) # Brilliant gold rim
    w_rgb = np.clip(w_rgb + edge_map[:, :, None] * gold_rim, 0, 255)
    
    warrior_mod = Image.fromarray(np.dstack([w_rgb.astype(np.uint8), w_arr[:, :, 3]]))
    
    target_h = 770
    target_w = int(warrior_mod.width * (target_h / warrior_mod.height))
    warrior_scaled = warrior_mod.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2 - 40 # Sulaiman-Too peak rises magnificently on right
    pos_y = 800 - target_h + 30
    bg_img.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    # Golden power sparks / aura particles
    draw = ImageDraw.Draw(bg_img)
    sparks = [(220, 280), (260, 210), (520, 240), (560, 310), (380, 110), (450, 90)]
    for sx, sy in sparks:
        draw.ellipse([sx - 3, sy - 3, sx + 3, sy + 3], fill=(255, 225, 100, 220))
        draw.ellipse([sx - 1, sy - 1, sx + 1, sy + 1], fill=(255, 255, 255, 255))
        
    return bg_img

# ==============================================================================
# 4. WORKOUT: BISHKEK ARENA (Stadium lights, post-workout strain, athletic sweat)
# ==============================================================================
def create_workout_avatar():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "bishkek_arena.jpg"))
    # (5036, 3777), pitch and illuminated stands
    crop_box = (500, 400, 4500, 3400)
    bg = stylize_anime_background(bg_raw, crop_box=crop_box, blur_radius=2.5, brightness=0.9, contrast=1.2, saturation=1.3)
    
    # Stadium amber/cyan electric contrast
    bg_arr = np.array(bg).astype(float)
    # Bright stadium floodlight glare across top
    y_coords = np.arange(800)[:, None, None]
    floodlight = np.exp(-((y_coords - 50) / 160)**2) * np.array([60, 70, 75])
    bg_arr = np.clip(bg_arr + floodlight, 0, 255).astype(np.uint8)
    bg_img = Image.fromarray(bg_arr)
    
    # Warrior with post-workout sweat and intense athletic drive
    warrior = load_warrior()
    w_arr = np.array(warrior)
    
    # Glistening athletic sweat drops across brow, cheek, and neck
    sweat_coords = [
        (340, 160), (350, 163), (380, 162), (405, 168), # Forehead
        (330, 210), (415, 215), # Cheeks
        (375, 255), (385, 260)  # Neck
    ]
    for sx, sy in sweat_coords:
        cv2.circle(w_arr, (sx, sy), 3, (210, 240, 255), -1, cv2.LINE_AA)
        cv2.circle(w_arr, (sx - 1, sy - 1), 1, (255, 255, 255), -1, cv2.LINE_AA)
        cv2.line(w_arr, (sx, sy), (sx, sy + 5), (170, 220, 250), 1, cv2.LINE_AA)
        
    # Glowing smart wristband on character's right wrist (x ~ 410..435, y ~ 540..560)
    cv2.rectangle(w_arr, (412, 545), (432, 560), (15, 20, 30), -1)
    cv2.rectangle(w_arr, (412, 545), (432, 560), (0, 255, 163), 1)
    # Smartwatch screen pulse indicator
    cv2.line(w_arr, (416, 552), (428, 552), (0, 255, 163), 1, cv2.LINE_AA)
    
    # Dynamic amber/workout rim-light on warrior
    w_rgb = w_arr[:, :, :3].astype(float) * np.array([1.04, 0.98, 0.92])
    alpha_img = Image.fromarray(w_arr[:, :, 3])
    edge_map = np.array(alpha_img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.6))).astype(float) / 255.0
    amber_rim = np.array([160, 95, 20]) # Amber heat rim
    w_rgb = np.clip(w_rgb + edge_map[:, :, None] * amber_rim, 0, 255)
    
    warrior_mod = Image.fromarray(np.dstack([w_rgb.astype(np.uint8), w_arr[:, :, 3]]))
    
    target_h = 770
    target_w = int(warrior_mod.width * (target_h / warrior_mod.height))
    warrior_scaled = warrior_mod.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2
    pos_y = 800 - target_h + 30
    bg_img.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    return bg_img

# ==============================================================================
# 5. NORMAL / IN TONE: BISHKEK & ALA-TOO PANORAMA (Clear day, pristine warrior)
# ==============================================================================
def create_normal_avatar():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "ala_too.jpg"))
    # Fresh mountain morning view
    crop_box = (400, 200, 3400, 2200)
    bg = stylize_anime_background(bg_raw, crop_box=crop_box, blur_radius=2.0, brightness=1.02, contrast=1.12, saturation=1.2)
    
    # Warrior in pristine, optimal form
    warrior = load_warrior()
    
    target_h = 770
    target_w = int(warrior.width * (target_h / warrior.height))
    warrior_scaled = warrior.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2 - 20
    pos_y = 800 - target_h + 30
    bg.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    return bg

# ==============================================================================
# 6. MEDITATION: SONG-KUL LAKE (Alpine serenity, closed eyes, zen breathing)
# ==============================================================================
def create_meditation_avatar():
    bg_raw = Image.open(os.path.join(LANDMARKS_DIR, "song_kul.jpg"))
    # (1620, 1080), serene lake, mountain reflection, yurts
    crop_box = (100, 100, 1550, 1050)
    bg = stylize_anime_background(bg_raw, crop_box=crop_box, blur_radius=2.2, brightness=1.05, contrast=1.08, saturation=1.25)
    
    # Sage/emerald zen grading
    bg_arr = np.array(bg).astype(float)
    zen_mult = np.array([0.92, 1.08, 1.02])
    bg_arr = np.clip(bg_arr * zen_mult, 0, 255).astype(np.uint8)
    bg_img = Image.fromarray(bg_arr)
    
    # Warrior with peaceful zen closed eyes
    warrior = load_warrior()
    w_arr = np.array(warrior)
    
    skin_left = w_arr[205, 350, :3].astype(int).tolist()
    skin_right = w_arr[205, 395, :3].astype(int).tolist()
    cv2.ellipse(w_arr, (355, 178), (12, 6), 0, 0, 360, skin_left, -1)
    cv2.ellipse(w_arr, (396, 179), (12, 6), 5, 0, 360, skin_right, -1)
    
    # Closed zen eyelashes
    pts_l = np.array([[343, 179], [349, 183], [356, 184], [362, 183], [368, 179]], np.int32).reshape((-1, 1, 2))
    cv2.polylines(w_arr, [pts_l], False, (35, 26, 24), 2, cv2.LINE_AA)
    pts_r = np.array([[384, 180], [390, 184], [397, 185], [403, 184], [409, 180]], np.int32).reshape((-1, 1, 2))
    cv2.polylines(w_arr, [pts_r], False, (35, 26, 24), 2, cv2.LINE_AA)
    
    # Serene mindful smile
    cv2.line(w_arr, (365, 222), (385, 222), (40, 28, 25), 2, cv2.LINE_AA)
    cv2.line(w_arr, (365, 222), (362, 220), (40, 28, 25), 1, cv2.LINE_AA)
    cv2.line(w_arr, (385, 222), (388, 220), (40, 28, 25), 1, cv2.LINE_AA)
    
    # Soft sage/emerald zen rim light
    w_rgb = w_arr[:, :, :3].astype(float) * np.array([0.94, 1.04, 0.98])
    alpha_img = Image.fromarray(w_arr[:, :, 3])
    edge_map = np.array(alpha_img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.GaussianBlur(1.8))).astype(float) / 255.0
    sage_rim = np.array([50, 150, 110]) # Sage/emerald tranquility
    w_rgb = np.clip(w_rgb + edge_map[:, :, None] * sage_rim, 0, 255)
    
    warrior_mod = Image.fromarray(np.dstack([w_rgb.astype(np.uint8), w_arr[:, :, 3]]))
    
    target_h = 770
    target_w = int(warrior_mod.width * (target_h / warrior_mod.height))
    warrior_scaled = warrior_mod.resize((target_w, target_h), Image.Resampling.LANCZOS)
    
    pos_x = (800 - target_w) // 2
    pos_y = 800 - target_h + 30
    bg_img.paste(warrior_scaled, (pos_x, pos_y), warrior_scaled)
    
    # Concentric biofeedback breathing rings (zen calmness visualization)
    draw = ImageDraw.Draw(bg_img)
    center_zen = (400, 320)
    for radius in [140, 180, 220]:
        draw.ellipse([center_zen[0] - radius, center_zen[1] - radius, center_zen[0] + radius, center_zen[1] + radius],
                     outline=(120, 210, 170, 70), width=1)
                     
    return bg_img

# ==============================================================================
# MAIN EXECUTION: Generate and save all 6 states
# ==============================================================================
if __name__ == "__main__":
    print("Generating 1/6: Sleep (Burana Tower)...")
    sleep_img = create_sleep_avatar()
    sleep_img.save(os.path.join(ASSETS_DIR, "hero_barys_sleep.jpg"), quality=96)
    
    print("Generating 2/6: Tired (Ala-Too Mountains)...")
    tired_img = create_tired_avatar()
    tired_img.save(os.path.join(ASSETS_DIR, "hero_barys_tired.jpg"), quality=96)
    
    print("Generating 3/6: Charged (Sulaiman-Too)...")
    charged_img = create_charged_avatar()
    charged_img.save(os.path.join(ASSETS_DIR, "hero_barys_charged.jpg"), quality=96)
    
    print("Generating 4/6: Workout (Bishkek Arena)...")
    workout_img = create_workout_avatar()
    workout_img.save(os.path.join(ASSETS_DIR, "hero_barys_workout.jpg"), quality=96)
    
    print("Generating 5/6: Normal / In Tone (Ala-Too Panorama)...")
    normal_img = create_normal_avatar()
    normal_img.save(os.path.join(ASSETS_DIR, "hero_barys_normal.jpg"), quality=96)
    
    print("Generating 6/6: Meditation (Song-Kul Lake)...")
    meditation_img = create_meditation_avatar()
    meditation_img.save(os.path.join(ASSETS_DIR, "hero_barys_meditation.jpg"), quality=96)
    
    print("ALL 6 WARRIOR AVATAR STATES CREATED SUCCESSFULLY!")
