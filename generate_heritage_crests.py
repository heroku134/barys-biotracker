import math

def mirror_points(points, cx=400):
    """Mirrors a list of (x, y) tuples across cx."""
    return [(2 * cx - x, y) for (x, y) in points]

def pts_to_str(pts):
    return " ".join(f"{round(x, 1)},{round(y, 1)}" for x, y in pts)

# =====================================================================
# MASTER FLAGSHIP: 5-ELEMENT «АРКАР-КАЛКАН»
# Symmetrical angular shield emblem inspired by Kyrgyz "кош мүйүз".
# Exactly 5 geometric elements, flat vector, single color black,
# no text, no gradient, white background.
# =====================================================================

# 1. Center Diamond Spine (Ось / Сакральный сердечник)
v1_center = [
    (400, 200),
    (430, 375),
    (400, 550),
    (370, 375)
]

# 2. Left Upper Horn (Сол мүйүз)
v1_left_horn = [
    (384, 140),
    (210, 140),
    (175, 260),
    (250, 305),
    (266, 272),
    (218, 242),
    (238, 182),
    (384, 182)
]
v1_right_horn = mirror_points(v1_left_horn)

# 4. Left Lower Blade (Сол каптал калкан)
v1_left_blade = [
    (192, 290),
    (278, 340),
    (354, 465),
    (384, 505),
    (384, 630),
    (290, 520),
    (180, 375)
]
v1_right_blade = mirror_points(v1_left_blade)

v1_all = [v1_center, v1_left_horn, v1_right_horn, v1_left_blade, v1_right_blade]

# =====================================================================
# VARIATION 2: 5-ELEMENT «НОМАД МҮЙҮЗ · СТРОГИЙ СТИЛЬ»
# High-altitude mountaineering heritage crest, sharp 45° cuts
# =====================================================================
v2_center = [
    (400, 215),
    (428, 380),
    (400, 545),
    (372, 380)
]

v2_left_horn = [
    (382, 130),
    (220, 130),
    (180, 240),
    (250, 280),
    (265, 245),
    (218, 220),
    (240, 172),
    (382, 172)
]
v2_right_horn = mirror_points(v2_left_horn)

v2_left_blade = [
    (196, 270),
    (280, 315),
    (352, 440),
    (382, 475),
    (382, 630),
    (275, 510),
    (180, 360)
]
v2_right_blade = mirror_points(v2_left_blade)

v2_all = [v2_center, v2_left_horn, v2_right_horn, v2_left_blade, v2_right_blade]

# =====================================================================
# VARIATION 3: 4-ELEMENT «КОШ МҮЙҮЗ» (EXACTLY 4 ELEMENTS)
# 2 Horns + 2 Blades. Negative space forms the spine.
# =====================================================================
v3_left_horn = [
    (384, 135),
    (210, 135),
    (170, 275),
    (265, 275),
    (280, 230),
    (215, 230),
    (235, 180),
    (384, 180)
]
v3_right_horn = mirror_points(v3_left_horn)

v3_left_blade = [
    (188, 310),
    (280, 310),
    (384, 445),
    (384, 630),
    (275, 515),
    (188, 400)
]
v3_right_blade = mirror_points(v3_left_blade)

v3_all = [v3_left_horn, v3_right_horn, v3_left_blade, v3_right_blade]

# =====================================================================
# VARIATION 4: 5-ELEMENT «ЖЕБЕ-КАЛКАН» (ARROW-HORN ALPINE CREST)
# Center lance + 4 sweeping chevron facets
# =====================================================================
v4_center = [
    (400, 130),
    (424, 360),
    (400, 630),
    (376, 360)
]

v4_left_horn = [
    (380, 150),
    (225, 200),
    (195, 295),
    (270, 285),
    (300, 235),
    (245, 245),
    (260, 205),
    (380, 180)
]
v4_right_horn = mirror_points(v4_left_horn)

v4_left_blade = [
    (210, 330),
    (310, 315),
    (362, 470),
    (380, 500),
    (380, 595),
    (285, 485),
    (210, 395)
]
v4_right_blade = mirror_points(v4_left_blade)

v4_all = [v4_center, v4_left_horn, v4_right_horn, v4_left_blade, v4_right_blade]


# ---------------------------------------------------------------------
# 1. WRITE MASTER FLAGSHIP SVG: KYRGYZ_SHIELD_MASTER.svg
# ---------------------------------------------------------------------
svg_master = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="100%" height="100%">
  <!-- Pure White Background -->
  <rect width="800" height="800" fill="#FFFFFF" />

  <!-- 
    KYRGYZ ORNAMENT HERITAGE SHIELD (АРКАР-КАЛКАН)
    - Architecture: Symmetrical Angular Shield
    - Motif: Kyrgyz "Кош Мүйүз" (Mountain Ibex Horns) + "Калкан" (Shield)
    - Elements: Exactly 5 geometric polygons
    - Style: Flat vector, single color (#000000), no text, no gradient
  -->
  <g id="kyrgyz-shield-emblem">
'''
for i, poly in enumerate(v1_all, 1):
    svg_master += f'    <!-- Element {i} of 5 -->\n'
    svg_master += f'    <polygon points="{pts_to_str(poly)}" fill="#000000" />\n'

svg_master += '''  </g>
</svg>
'''

with open('KYRGYZ_SHIELD_MASTER.svg', 'w', encoding='utf-8') as f:
    f.write(svg_master)

# ---------------------------------------------------------------------
# 2. WRITE COLLECTION ARTBOARD: KYRGYZ_SHIELD_COLLECTION.svg
# ---------------------------------------------------------------------
def render_group_svg(polys, gid):
    out = f'<g id="{gid}">\n'
    for poly in polys:
        out += f'  <polygon points="{pts_to_str(poly)}" fill="#000000" />\n'
    out += '</g>\n'
    return out

svg_coll = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2400 1800" width="100%" height="100%">
  <!-- Pure White Canvas -->
  <rect width="2400" height="1800" fill="#FFFFFF" />

  <defs>
    {render_group_svg(v1_all, "opt-1-crest")}
    {render_group_svg(v2_all, "opt-2-crest")}
    {render_group_svg(v3_all, "opt-3-crest")}
    {render_group_svg(v4_all, "opt-4-crest")}
  </defs>

  <!-- 4 Primary Marks on Pure White Background (No Gradients, Single Color) -->
  
  <!-- Option 1 (Flagship: 5 Elements) -->
  <g transform="translate(100, 100)">
    <use href="#opt-1-crest" />
  </g>

  <!-- Option 2 (Architectural 5 Elements) -->
  <g transform="translate(1300, 100)">
    <use href="#opt-2-crest" />
  </g>

  <!-- Option 3 (Pure 4 Elements) -->
  <g transform="translate(100, 950)">
    <use href="#opt-3-crest" />
  </g>

  <!-- Option 4 (Dynamic Arrow 5 Elements) -->
  <g transform="translate(1300, 950)">
    <use href="#opt-4-crest" />
  </g>

</svg>
'''

with open('KYRGYZ_SHIELD_COLLECTION.svg', 'w', encoding='utf-8') as f:
    f.write(svg_coll)

print("Generated KYRGYZ_SHIELD_MASTER.svg and KYRGYZ_SHIELD_COLLECTION.svg successfully.")
