import math

def mirror_points(points, cx=400.0):
    return [(2 * cx - x, y) for (x, y) in points]

def pts_to_str(pts):
    return " ".join(f"{round(x, 1)},{round(y, 1)}" for x, y in pts)

CX = 400.0
GAP = 12.0
HALF_GAP = GAP / 2.0  # 6.0

# =====================================================================
# FLAGSHIP MASTER EMBLEM: 5 GEOMETRIC ELEMENTS
# «АРКАР-КАЛКАН» (TEKE MÜYÜZ SHIELD)
# Symmetrical, angular, single color #000000, white background, no text
# =====================================================================

# 1. Central Diamond Spine (Ось / Сердечник)
m2_center = [
    (CX, 202.0),
    (CX + 35.0, 380.0),
    (CX, 558.0),
    (CX - 35.0, 380.0)
]

# 2. Left Upper Horn (Сол мүйүз)
m2_left_horn = [
    (CX - HALF_GAP, 126.0),       # (394, 126) - Center top apex
    (210.0, 156.0),               # Outer shoulder peak
    (165.0, 280.0),               # Outer flank
    (240.0, 320.0),               # Outer horn tip
    (260.0, 280.0),               # Horn return
    (215.0, 255.0),               # Horn crook
    (245.0, 195.0),               # Inner body
    (CX - HALF_GAP, 170.0)        # Back to center line (394, 170)
]
m2_right_horn = mirror_points(m2_left_horn, CX)

# 4. Left Lower Keel Blade (Сол каптал калкан)
m2_left_blade = [
    (180.0, 310.0),
    (255.0, 350.0),
    (345.0, 475.0),
    (CX - HALF_GAP, 525.0),
    (CX - HALF_GAP, 640.0),
    (280.0, 530.0),
    (168.0, 400.0)
]
m2_right_blade = mirror_points(m2_left_blade, CX)

flagship_5_elements = [
    ("Center Spine", m2_center),
    ("Top-Left Horn", m2_left_horn),
    ("Top-Right Horn", m2_right_horn),
    ("Bottom-Left Blade", m2_left_blade),
    ("Bottom-Right Blade", m2_right_blade)
]

# =====================================================================
# 4-ELEMENT MASTER VARIANT: «КОШ МҮЙҮЗ» (PURE QUAD)
# Exactly 4 elements. The negative space forms the arrow-cross.
# =====================================================================
m4_left_horn = [
    (CX - HALF_GAP, 145.0),
    (205.0, 145.0),
    (165.0, 280.0),
    (260.0, 280.0),
    (278.0, 235.0),
    (212.0, 235.0),
    (232.0, 190.0),
    (CX - HALF_GAP, 190.0)
]
m4_right_horn = mirror_points(m4_left_horn, CX)

m4_left_blade = [
    (180.0, 312.0),
    (272.0, 312.0),
    (CX - HALF_GAP, 445.0),
    (CX - HALF_GAP, 635.0),
    (270.0, 515.0),
    (180.0, 405.0)
]
m4_right_blade = mirror_points(m4_left_blade, CX)

variant_4_elements = [
    ("Top-Left Horn", m4_left_horn),
    ("Top-Right Horn", m4_right_horn),
    ("Bottom-Left Blade", m4_left_blade),
    ("Bottom-Right Blade", m4_right_blade)
]

# ---------------------------------------------------------------------
# 1. WRITE KYRGYZ_SHIELD_HERITAGE_FLAGSHIP.svg (Pure Mark, No Text)
# ---------------------------------------------------------------------
svg_flagship = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="100%" height="100%">
  <!-- Pure White Background -->
  <rect width="800" height="800" fill="#FFFFFF" />

  <!-- 
    KYRGYZ ORNAMENT HERITAGE SHIELD (АРКАР-КАЛКАН)
    - Architecture: Symmetrical Angular Shield
    - Inspiration: Kyrgyz "Кош Мүйүз" (Double Mountain Ibex Horns) + "Калкан" (Shield)
    - Count: Exactly 5 geometric elements
    - Palette: Flat vector, single color (#000000), no text, no gradient
  -->
  <g id="kyrgyz-heritage-shield-5">
    <!-- 1. Center Diamond Spine -->
    <polygon points="{pts_to_str(m2_center)}" fill="#000000" />
    <!-- 2. Top-Left Horn -->
    <polygon points="{pts_to_str(m2_left_horn)}" fill="#000000" />
    <!-- 3. Top-Right Horn -->
    <polygon points="{pts_to_str(m2_right_horn)}" fill="#000000" />
    <!-- 4. Bottom-Left Blade -->
    <polygon points="{pts_to_str(m2_left_blade)}" fill="#000000" />
    <!-- 5. Bottom-Right Blade -->
    <polygon points="{pts_to_str(m2_right_blade)}" fill="#000000" />
  </g>
</svg>
'''

with open('KYRGYZ_SHIELD_HERITAGE_FLAGSHIP.svg', 'w', encoding='utf-8') as f:
    f.write(svg_flagship)

# ---------------------------------------------------------------------
# 2. WRITE KYRGYZ_SHIELD_HERITAGE_4ELEMENTS.svg (Pure 4 Elements)
# ---------------------------------------------------------------------
svg_4elem = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 800" width="100%" height="100%">
  <!-- Pure White Background -->
  <rect width="800" height="800" fill="#FFFFFF" />

  <!-- 
    KYRGYZ ORNAMENT HERITAGE SHIELD (КОШ МҮЙҮЗ)
    - Count: Exactly 4 geometric elements
    - Palette: Flat vector, single color (#000000), no text, no gradient
  -->
  <g id="kyrgyz-heritage-shield-4">
    <!-- 1. Top-Left Horn -->
    <polygon points="{pts_to_str(m4_left_horn)}" fill="#000000" />
    <!-- 2. Top-Right Horn -->
    <polygon points="{pts_to_str(m4_right_horn)}" fill="#000000" />
    <!-- 3. Bottom-Left Blade -->
    <polygon points="{pts_to_str(m4_left_blade)}" fill="#000000" />
    <!-- 4. Bottom-Right Blade -->
    <polygon points="{pts_to_str(m4_right_blade)}" fill="#000000" />
  </g>
</svg>
'''

with open('KYRGYZ_SHIELD_HERITAGE_4ELEMENTS.svg', 'w', encoding='utf-8') as f:
    f.write(svg_4elem)

# ---------------------------------------------------------------------
# 3. WRITE KYRGYZ_HERITAGE_SHOWCASE.svg (Presentation Artboard)
# White background, single color, restrained, architectural
# ---------------------------------------------------------------------
def render_group(polys):
    return "".join(f'<polygon points="{pts_to_str(p)}" fill="#000000" />\n' for p in polys)

svg_presentation = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2400 1600" width="100%" height="100%">
  <defs>
    <style>
      @import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@500;700;800&amp;display=swap');
      .label-mono {{ font-family: 'JetBrains Mono', monospace; font-size: 13px; font-weight: 700; fill: #666666; letter-spacing: 2px; }}
      .sub-mono {{ font-family: 'JetBrains Mono', monospace; font-size: 11px; font-weight: 500; fill: #999999; letter-spacing: 1px; }}
    </style>
    
    <g id="flagship-crest">
      {render_group([p for _, p in flagship_5_elements])}
    </g>

    <g id="quad-crest">
      {render_group([p for _, p in variant_4_elements])}
    </g>
  </defs>

  <!-- Pure White Canvas -->
  <rect width="2400" height="1600" fill="#FFFFFF" />

  <!-- Outer Border Frame (Subtle, Restrained) -->
  <rect x="60" y="60" width="2280" height="1480" fill="none" stroke="#E5E5E5" stroke-width="1.5" />

  <!-- SECTION 1: PRIMARY FLAGSHIP (5 ELEMENTS) -->
  <g transform="translate(180, 140)">
    <use href="#flagship-crest" transform="scale(1.2)" />
    <text x="480" y="850" class="label-mono" text-anchor="middle">FLAGSHIP · 5 GEOMETRIC ELEMENTS</text>
    <text x="480" y="875" class="sub-mono" text-anchor="middle">«АРКАР-КАЛКАН» (TEKE MÜYÜZ HERITAGE SHIELD)</text>
  </g>

  <!-- SECTION 2: EXPLODED VIEW (SHOWING EXACTLY 5 PIECES) -->
  <g transform="translate(1250, 160)">
    <text x="450" y="30" class="label-mono" text-anchor="middle">EXPLODED GEOMETRIC ANATOMY (5 PIECES)</text>
    
    <!-- Exploded 5 Parts -->
    <!-- 1. Center Diamond -->
    <g transform="translate(200, 40) scale(0.65)">
      <polygon points="{pts_to_str(m2_center)}" fill="#000000" />
    </g>
    <!-- 2. Left Horn (exploded left & up) -->
    <g transform="translate(140, -10) scale(0.65)">
      <polygon points="{pts_to_str(m2_left_horn)}" fill="#000000" />
    </g>
    <!-- 3. Right Horn (exploded right & up) -->
    <g transform="translate(260, -10) scale(0.65)">
      <polygon points="{pts_to_str(m2_right_horn)}" fill="#000000" />
    </g>
    <!-- 4. Left Blade (exploded left & down) -->
    <g transform="translate(140, 90) scale(0.65)">
      <polygon points="{pts_to_str(m2_left_blade)}" fill="#000000" />
    </g>
    <!-- 5. Right Blade (exploded right & down) -->
    <g transform="translate(260, 90) scale(0.65)">
      <polygon points="{pts_to_str(m2_right_blade)}" fill="#000000" />
    </g>

    <!-- Scale test bar -->
    <g transform="translate(150, 520)">
      <text x="0" y="0" class="label-mono">MICRO-SCALE TEST (WATCH CROWN &amp; FABRIC):</text>
      <!-- 64px -->
      <g transform="translate(0, 30) scale(0.08)">
        <use href="#flagship-crest" />
      </g>
      <!-- 32px -->
      <g transform="translate(100, 46) scale(0.04)">
        <use href="#flagship-crest" />
      </g>
      <!-- 16px (Physical 3mm Crown) -->
      <g transform="translate(170, 54) scale(0.02)">
        <use href="#flagship-crest" />
      </g>
      <!-- 10px Micro -->
      <g transform="translate(220, 58) scale(0.0125)">
        <use href="#flagship-crest" />
      </g>
    </g>
  </g>

  <!-- SECTION 3: 4-ELEMENT VARIANT (PURE QUAD) -->
  <g transform="translate(1250, 840)">
    <line x1="0" y1="0" x2="900" y2="0" stroke="#E5E5E5" stroke-width="1" />
    
    <g transform="translate(0, 60)">
      <g transform="translate(80, 0) scale(0.7)">
        <use href="#quad-crest" />
      </g>
      <text x="560" y="240" class="label-mono">ALTERNATIVE · 4 GEOMETRIC ELEMENTS</text>
      <text x="560" y="270" class="sub-mono">«КОШ МҮЙҮЗ» (PURE QUAD HORN-SHIELD)</text>
      <text x="560" y="300" class="sub-mono">Negative space cuts the sacred arrow-cross</text>
    </g>
  </g>

</svg>
'''

with open('KYRGYZ_HERITAGE_SHOWCASE.svg', 'w', encoding='utf-8') as f:
    f.write(svg_presentation)

print("Saved all heritage assets.")
