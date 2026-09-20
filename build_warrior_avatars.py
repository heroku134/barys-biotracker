import os
import cv2
import numpy as np
from PIL import Image, ImageFilter, ImageEnhance, ImageDraw, ImageColor

LANDMARKS_DIR = r"c:\Users\KPK\Documents\вав\barys_biotracker\assets\images\landmarks"
ASSETS_DIR = r"c:\Users\KPK\Documents\вав\barys_biotracker\assets\images"
CUTOUT_PATH = os.path.join(ASSETS_DIR, "warrior_cutout_clean.png")

OUTPUT_SIZE = (800, 800)

def load_and_stylize_background(bg_path, crop_box=None, blur_amount=2, color_tint=None, brightness=1.0, contrast=1.1, saturation=1.2):
    """Converts a photo into a painted anime-style background with depth-of-field."""
    img_bgr = cv2.imread(bg_path)
    if img_bgr is None:
        raise ValueError(f"Could not load {bg_path}")
    
    # 1. Edge-preserving filter for anime paint effect
    smooth = cv2.edgePreservingFilter(img_bgr, flags=1, sigma_s=40, sigma_r=0.4)
    # Detail enhancement
    detail = cv2.detailEnhance(smooth, sigma_s=10, sigma_r=0.15)
    
    # Convert BGR to RGB
    img_rgb = cv2.cvtColor(detail, cv2.COLOR_BGR2RGB)
    pil_img = Image.fromarray(img_rgb)
    
    # Crop if specified, otherwise crop center
    if crop_box:
        pil_img = pil_img.crop(crop_box)
    
    # Fit into OUTPUT_SIZE keeping aspect ratio
    w, h = pil_img.size
    scale = max(OUTPUT_SIZE[0] / w, OUTPUT_SIZE[1] / h)
    new_w, new_h = int(w * scale), int(h * scale)
    pil_img = pil_img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Center crop to exact OUTPUT_SIZE
    left = (new_w - OUTPUT_SIZE[0]) // 2
    top = (new_h - OUTPUT_SIZE[1]) // 2
    pil_img = pil_img.crop((left, top, left + OUTPUT_SIZE[0], top + OUTPUT_SIZE[1]))
    
    # Enhancements
    if brightness != 1.0:
        pil_img = ImageEnhance.Brightness(pil_img).enhance(brightness)
    if contrast != 1.0:
        pil_img = ImageEnhance.Contrast(pil_img).enhance(contrast)
    if saturation != 1.0:
        pil_img = ImageEnhance.Color(pil_img).enhance(saturation)
        
    # Depth of field blur
    if blur_amount > 0:
        pil_img = pil_img.filter(ImageFilter.GaussianBlur(radius=blur_amount))
        
    # Tint overlay
    if color_tint:
        tint_layer = Image.new("RGBA", OUTPUT_SIZE, color_tint)
        pil_img = pil_img.convert("RGBA")
        pil_img = Image.alpha_composite(pil_img, tint_layer)
        
    return pil_img

print("Background stylizer ready!")
