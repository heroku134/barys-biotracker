import math

def mirror_points(points, cx=400):
    return [(2 * cx - x, y) for (x, y) in points]

def pts_to_str(pts):
    return " ".join(f"{round(x, 1)},{round(y, 1)}" for x, y in pts)

# =====================================================================
# EXPLORATION A: SOARING TEKE MÜYÜZ (5 ELEMENTS)
# Horns rise from center to a proud mountain peak shoulder (Ala-Too),
# then angle down and fold inward.
# Center diamond anchors the core.
# Lower blades converge to a sharp prow.
# =====================================================================

# Center diamond
ea_center = [
    (400, 230),
    (430, 390),
    (400, 550),
    (370, 390)
]

# Left Horn: rises from (384, 175) to high shoulder (190, 125)!
ea_left_horn = [
    (384, 180),
    (190, 130),
    (150, 270),
    (230, 310),
    (250, 275),
    (200, 250),
    (220, 180),
    (384, 220)
]
ea_right_horn = mirror_points(ea_left_horn)

# Left Lower Blade: starts at (170, 305), follows shield line to apex (392, 640)
ea_left_blade = [
    (175, 300),
    (260, 345),
    (352, 470),
    (384, 510),
    (384, 635),
    (280, 520),
    (160, 385)
]
ea_right_blade = mirror_points(ea_left_blade)

ea_all = [ea_center, ea_left_horn, ea_right_horn, ea_left_blade, ea_right_blade]

# =====================================================================
# EXPLORATION B: ARCHITECTURAL HERITAGE CREST (5 ELEMENTS)
# Inspired by Kyrgyz "Мүйүз" + "Түндүк"
# Symmetrical, crisp 45° angles, uniform laser gap.
# =====================================================================
eb_center = [
    (400, 160),
    (435, 380),
    (400, 600),
    (365, 380)
]

# Top-Left Wing / Horn
eb_left_horn = [
    (380, 130),
    (200, 160),
    (165, 290),
    (250, 310),
    (285, 255),
    (230, 245),
    (240, 195),
    (380, 175)
]
eb_right_horn = mirror_points(eb_left_horn)

# Lower-Left Blade
eb_left_blade = [
    (185, 325),
    (285, 345),
    (345, 470),
    (375, 500),
    (375, 595),
    (270, 500),
    (185, 405)
]
eb_right_blade = mirror_points(eb_left_blade)

eb_all = [eb_center, eb_left_horn, eb_right_horn, eb_left_blade, eb_right_blade]

# =====================================================================
# EXPLORATION C: MINIMALIST SAK-KALKAN (4 ELEMENTS)
# Exactly 4 elements. The negative space forms a clean arrow-cross.
# =====================================================================
ec_left_horn = [
    (385, 140),
    (195, 140),
    (155, 290),
    (255, 290),
    (275, 240),
    (205, 240),
    (230, 185),
    (385, 185)
]
ec_right_horn = mirror_points(ec_left_horn)

ec_left_blade = [
    (175, 325),
    (275, 325),
    (385, 460),
    (385, 640),
    (265, 515),
    (175, 410)
]
ec_right_blade = mirror_points(ec_left_blade)

ec_all = [ec_left_horn, ec_right_horn, ec_left_blade, ec_right_blade]

# =====================================================================
# EXPLORATION D: ARROW-HORN SHIELD (5 ELEMENTS)
# Razor-sharp, noble, looks like an elite athletic federation emblem.
# =====================================================================
ed_center = [
    (400, 180),
    (430, 370),
    (400, 560),
    (370, 370)
]

ed_left_horn = [
    (382, 120),
    (210, 150),
    (170, 270),
    (245, 295),
    (265, 260),
    (215, 235),
    (235, 175),
    (382, 160)
]
ed_right_horn = mirror_points(ed_left_horn)

ed_left_blade = [
    (185, 305),
    (275, 335),
    (350, 460),
    (382, 495),
    (382, 630),
    (280, 515),
    (175, 385)
]
ed_right_blade = mirror_points(ed_left_blade)

ed_all = [ed_center, ed_left_horn, ed_right_horn, ed_left_blade, ed_right_blade]

# Generate multi-exploration SVG
def make_svg(polys):
    return "".join(f'<polygon points="{pts_to_str(p)}" fill="#000000" />\n' for p in polys)

svg_exp = f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 2400 1800" width="100%" height="100%">
  <rect width="2400" height="1800" fill="#FFFFFF" />
  <g transform="translate(100, 100)">
    {make_svg(ea_all)}
  </g>
  <g transform="translate(1300, 100)">
    {make_svg(eb_all)}
  </g>
  <g transform="translate(100, 950)">
    {make_svg(ec_all)}
  </g>
  <g transform="translate(1300, 950)">
    {make_svg(ed_all)}
  </g>
</svg>'''

with open('test_explorations.svg', 'w') as f:
    f.write(svg_exp)

print("Explorations saved.")
