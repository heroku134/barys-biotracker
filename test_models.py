import math

def mirror_points(points, cx=400):
    return [(2 * cx - x, y) for (x, y) in points]

def pts_to_str(pts):
    return " ".join(f"{round(x, 1)},{round(y, 1)}" for x, y in pts)

CX = 400.0
GAP = 12.0
HALF_GAP = GAP / 2.0  # 6.0

# =====================================================================
# MODEL 1: «АРКАР-КАЛКАН» (5 ELEMENTS) - HERITAGE V-CROWN (ALPINE)
# Horns rise to high alpine shoulders, bold muscular horn stroke.
# =====================================================================
m1_center = [
    (CX, 215.0),
    (CX + 34.0, 385.0),
    (CX, 555.0),
    (CX - 34.0, 385.0)
]

m1_left_horn = [
    (CX - HALF_GAP, 175.0),       # (394, 175)
    (210.0, 130.0),               # High shoulder
    (165.0, 275.0),               # Outer shield flank
    (245.0, 320.0),               # Outer horn tip
    (265.0, 280.0),               # Inner horn return
    (215.0, 252.0),               # Inner crook
    (245.0, 182.0),               # Inner body
    (CX - HALF_GAP, 220.0)        # Center return
]
m1_right_horn = mirror_points(m1_left_horn, CX)

m1_left_blade = [
    (180.0, 305.0),
    (260.0, 350.0),
    (346.0, 470.0),
    (CX - HALF_GAP, 520.0),
    (CX - HALF_GAP, 640.0),
    (280.0, 530.0),
    (168.0, 395.0)
]
m1_right_blade = mirror_points(m1_left_blade, CX)

m1_all = [m1_center, m1_left_horn, m1_right_horn, m1_left_blade, m1_right_blade]

# =====================================================================
# MODEL 2: «БАЙРАК-КАЛКАН» (5 ELEMENTS) - CLASSIC CREST ROOF
# Top slopes down from center to shoulders (classic noble shield roof).
# =====================================================================
m2_center = [
    (CX, 200.0),
    (CX + 35.0, 380.0),
    (CX, 560.0),
    (CX - 35.0, 380.0)
]

m2_left_horn = [
    (CX - HALF_GAP, 125.0),       # (394, 125) - Highest point at center
    (210.0, 155.0),               # Dropping slightly to shoulder
    (165.0, 280.0),               # Outer flank
    (240.0, 320.0),               # Horn tip
    (260.0, 280.0),               # Return
    (215.0, 255.0),               # Crook
    (245.0, 195.0),               # Inner body
    (CX - HALF_GAP, 170.0)        # Center return
]
m2_right_horn = mirror_points(m2_left_horn, CX)

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

m2_all = [m2_center, m2_left_horn, m2_right_horn, m2_left_blade, m2_right_blade]

# =====================================================================
# MODEL 3: «ТҮНДҮК-КАЛКАН» (5 ELEMENTS) - FLAT HORIZONTAL BROW
# Pure horizontal top brow, extremely architectural & restrained.
# =====================================================================
m3_center = [
    (CX, 210.0),
    (CX + 32.0, 380.0),
    (CX, 550.0),
    (CX - 32.0, 380.0)
]

m3_left_horn = [
    (CX - HALF_GAP, 140.0),
    (200.0, 140.0),
    (160.0, 270.0),
    (245.0, 315.0),
    (268.0, 275.0),
    (215.0, 250.0),
    (235.0, 185.0),
    (CX - HALF_GAP, 185.0)
]
m3_right_horn = mirror_points(m3_left_horn, CX)

m3_left_blade = [
    (178.0, 302.0),
    (260.0, 348.0),
    (348.0, 465.0),
    (CX - HALF_GAP, 515.0),
    (CX - HALF_GAP, 635.0),
    (275.0, 525.0),
    (165.0, 390.0)
]
m3_right_blade = mirror_points(m3_left_blade, CX)

m3_all = [m3_center, m3_left_horn, m3_right_horn, m3_left_blade, m3_right_blade]

# =====================================================================
# MODEL 4: «КОШ МҮЙҮЗ» (4 ELEMENTS) - RADICAL PURITY
# Exactly 4 elements. The negative space forms the sacred arrow-cross.
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

m4_all = [m4_left_horn, m4_right_horn, m4_left_blade, m4_right_blade]

# Render grid
def make_svg_group(polys):
    return "".join(f'<polygon points="{pts_to_str(p)}" fill="#000000" />\n' for p in polys)

svg_grid = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2400 1800" width="100%" height="100%">
  <!-- Pure White Background -->
  <rect width="2400" height="1800" fill="#FFFFFF" />

  <!-- Model 1 (V-Crown Alpine, 5 Elements) -->
  <g transform="translate(100, 100)">
    {make_svg_group(m1_all)}
  </g>

  <!-- Model 2 (Classic Crest Roof, 5 Elements) -->
  <g transform="translate(1300, 100)">
    {make_svg_group(m2_all)}
  </g>

  <!-- Model 3 (Horizontal Brow, 5 Elements) -->
  <g transform="translate(100, 950)">
    {make_svg_group(m3_all)}
  </g>

  <!-- Model 4 (Pure 4 Elements) -->
  <g transform="translate(1300, 950)">
    {make_svg_group(m4_all)}
  </g>
</svg>'''

with open('test_models_grid.svg', 'w') as f:
    f.write(svg_grid)

print("Saved test_models_grid.svg")
