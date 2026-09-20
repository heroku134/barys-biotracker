import math

def mirror_points(points, cx=400):
    return [(2 * cx - x, y) for (x, y) in points]

def pts_to_str(pts):
    return " ".join(f"{round(x, 1)},{round(y, 1)}" for x, y in pts)

# =====================================================================
# MATHEMATICAL PRECISION HERITAGE SHIELD (АРКАР-КАЛКАН)
# Symmetrical Angular Shield Emblem, 5 Geometric Elements
# Flat vector, Single Color Black (#000000), White Background
# Strict 14px parallel negative-space channels
# =====================================================================

GAP = 14.0
HALF_GAP = GAP / 2.0  # 7.0
CX = 400.0

# 1. CENTRAL DIAMOND (ӨЗӨК / ЖҮРӨК)
diamond_top_y = 205.0
diamond_bot_y = 545.0
diamond_w = 34.0  # half width
diamond_mid_y = 375.0

diamond = [
    (CX, diamond_top_y),
    (CX + diamond_w, diamond_mid_y),
    (CX, diamond_bot_y),
    (CX - diamond_w, diamond_mid_y)
]

# 2. LEFT UPPER HORN (СОЛ МҮЙҮЗ)
# Master architectural horn with sweeping top ridge and crisp 45/60 cuts
left_horn = [
    (CX - HALF_GAP, 150.0),       # Top center start (393, 150)
    (205.0, 125.0),               # High athletic shoulder peak
    (165.0, 260.0),               # Outer shield flank
    (245.0, 310.0),               # Bottom horn corner
    (268.0, 275.0),               # Inner horn return (tip of horn curl)
    (218.0, 244.0),               # Inner hollow crook
    (238.0, 180.0),               # Horn spine
    (CX - HALF_GAP, 195.0)        # Back to center line (393, 195)
]
right_horn = mirror_points(left_horn, CX)

# 4. LEFT LOWER BLADE (СОЛ КАПТАЛ КАЛКАН)
# Perfectly parallel to the horn above (14px gap) and diamond to the right (14px gap)
left_blade = [
    (180.0, 298.0),               # Upper outer corner (below horn with 14px gap)
    (262.0, 348.0),               # Upper inner corner (parallel to horn bottom)
    (348.0, 460.0),               # Hugs diamond flank
    (CX - HALF_GAP, 508.0),       # Below diamond mid, parallel to lower diamond
    (CX - HALF_GAP, 630.0),       # Bottom apex point
    (280.0, 520.0),               # Outer lower keel
    (168.0, 385.0)                # Outer flank waist
]
right_blade = mirror_points(left_blade, CX)

master_5_elements = [
    ("Center Spine", diamond),
    ("Top-Left Horn", left_horn),
    ("Top-Right Horn", right_horn),
    ("Bottom-Left Blade", left_blade),
    ("Bottom-Right Blade", right_blade)
]

# =====================================================================
# VARIATION B: 4-ELEMENT «КОШ МҮЙҮЗ КАЛКАН» (EXACTLY 4 ELEMENTS)
# 2 Horns + 2 Blades, central negative space forms the arrow-cross
# =====================================================================
left_horn_4 = [
    (CX - HALF_GAP, 140.0),
    (200.0, 140.0),
    (160.0, 280.0),
    (255.0, 280.0),
    (275.0, 235.0),
    (208.0, 235.0),
    (228.0, 184.0),
    (CX - HALF_GAP, 184.0)
]
right_horn_4 = mirror_points(left_horn_4, CX)

left_blade_4 = [
    (178.0, 316.0),
    (270.0, 316.0),
    (CX - HALF_GAP, 450.0),
    (CX - HALF_GAP, 630.0),
    (270.0, 515.0),
    (178.0, 410.0)
]
right_blade_4 = mirror_points(left_blade_4, CX)

master_4_elements = [
    ("Top-Left Horn", left_horn_4),
    ("Top-Right Horn", right_horn_4),
    ("Bottom-Left Blade", left_blade_4),
    ("Bottom-Right Blade", right_blade_4)
]

# Write standalone master SVG
def write_standalone(polys, filename):
    content = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="100%" height="100%">
  <!-- Pure White Background -->
  <rect width="800" height="800" fill="#FFFFFF" />

  <!-- 
    KYRGYZ ORNAMENT HERITAGE EMBLEM
    Architecture: Symmetrical Angular Shield
    Elements: Exactly {len(polys)} geometric elements
    Palette: Single color (#000000), white background, no text, no gradient
  -->
  <g id="kyrgyz-heritage-shield">
'''
    for i, p in enumerate(polys, 1):
        content += f'    <polygon points="{pts_to_str(p)}" fill="#000000" />\n'
    content += '''  </g>
</svg>
'''
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(content)

write_standalone([p for _, p in master_5_elements], 'KYRGYZ_SHIELD_MASTER_5.svg')
write_standalone([p for _, p in master_4_elements], 'KYRGYZ_SHIELD_MASTER_4.svg')

print("Generated KYRGYZ_SHIELD_MASTER_5.svg and KYRGYZ_SHIELD_MASTER_4.svg")
