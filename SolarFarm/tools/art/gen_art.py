#!/usr/bin/env python3
"""Original vector art generator for «Солнечная ферма».

Every game sprite (match-3 pieces, boosters, helpers, farm buildings, animals,
UI icons, backgrounds) is described here as SVG and rendered to PNG by
render.js with Chromium. All art is original and released with the project.

Usage: python3 gen_art.py <svg_out_dir>
"""
import math
import os
import random
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "svg_out"
os.makedirs(OUT, exist_ok=True)

SHADOW = """
<filter id="ds" x="-30%" y="-30%" width="160%" height="160%">
  <feDropShadow dx="0" dy="{dy}" stdDeviation="{sd}" flood-color="#3b2a12" flood-opacity="0.33"/>
</filter>
<filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="{blur}"/></filter>
<filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
"""


GLOSS = """
<filter id="gloss" x="-10%" y="-10%" width="120%" height="120%">
  <feGaussianBlur in="SourceAlpha" stdDeviation="7" result="blur"/>
  <feSpecularLighting in="blur" surfaceScale="6" specularConstant="0.75" specularExponent="24"
      lighting-color="#ffffff" result="spec">
    <fePointLight x="{lx}" y="{ly}" z="{lz}"/>
  </feSpecularLighting>
  <feComposite in="spec" in2="SourceAlpha" operator="in" result="specIn"/>
  <feGaussianBlur in="SourceAlpha" stdDeviation="4" result="inner"/>
  <feComposite in="SourceAlpha" in2="inner" operator="arithmetic" k2="1" k3="-1" result="rim"/>
  <feFlood flood-color="#ffffff" flood-opacity="0.2"/>
  <feComposite in2="rim" operator="in" result="rimLight"/>
  <feMerge><feMergeNode in="SourceGraphic"/><feMergeNode in="rimLight"/></feMerge>
  <feComposite in2="specIn" operator="arithmetic" k1="0" k2="1.05" k3="0.38" k4="-0.02" result="lit"/>
  <feComposite in="lit" in2="SourceAlpha" operator="in"/>
</filter>
<filter id="ds2" x="-30%" y="-30%" width="160%" height="160%">
  <feDropShadow dx="0" dy="{dy}" stdDeviation="{sd}" flood-color="#2a1a40" flood-opacity="0.28"/>
</filter>
"""

SOFT_PREFIXES = ("tile_", "special_")


def save(name, w, h, body, out, defs="", shadow=(6, 5), blur=6):
    sd = SHADOW.format(dy=shadow[0], sd=shadow[1], blur=blur)
    if name.startswith(SOFT_PREFIXES):
        # Soft candy look: thinner outlines, specular gloss + rim light, softer shadow.
        import re
        body = body.replace('filter="url(#ds)"', '')
        body = re.sub(r'stroke-width="(\d+(?:\.\d+)?)"', lambda m: 'stroke-width="%.1f"' % (float(m.group(1)) * 0.72), body)
        sd += GLOSS.format(lx=w * 0.3, ly=h * 0.15, lz=w * 0.7, dy=w / 40, sd=w / 32)
        body = f'<g filter="url(#ds2)"><g filter="url(#gloss)">{body}</g></g>'
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
           f'viewBox="0 0 {w} {h}" data-out="{out}"><defs>{sd}{defs}</defs>{body}</svg>')
    with open(os.path.join(OUT, name + ".svg"), "w") as f:
        f.write(svg)


def rg(id_, c1, c2, cx="38%", cy="32%", r="75%"):
    return (f'<radialGradient id="{id_}" cx="{cx}" cy="{cy}" r="{r}">'
            f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></radialGradient>')


def lg(id_, c1, c2, x2="0", y2="1", mid=None):
    m = f'<stop offset="0.5" stop-color="{mid}"/>' if mid else ""
    return (f'<linearGradient id="{id_}" x1="0" y1="0" x2="{x2}" y2="{y2}">'
            f'<stop offset="0" stop-color="{c1}"/>{m}<stop offset="1" stop-color="{c2}"/></linearGradient>')


def shine(cx, cy, rx, ry, rot=-30, op=0.65):
    return (f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#fff" opacity="{op}" '
            f'transform="rotate({rot} {cx} {cy})"/>')


def leaf(x, y, l, w, ang, fill="url(#lf)", stroke="#2d6b16", sw=5):
    return (f'<path d="M0 0 Q {l*0.5} {-w} {l} 0 Q {l*0.5} {w} 0 0 Z" fill="{fill}" stroke="{stroke}" '
            f'stroke-width="{sw}" stroke-linejoin="round" transform="translate({x} {y}) rotate({ang})"/>'
            f'<path d="M{l*0.1} 0 L{l*0.8} 0" stroke="{stroke}" stroke-width="{sw*0.5}" opacity="0.5" '
            f'stroke-linecap="round" transform="translate({x} {y}) rotate({ang})"/>')


LEAF_DEF = lg("lf", "#8ee04a", "#3f9b22")

# ---------------------------------------------------------------- match-3 pieces
T = 256


def tile_strawberry():
    d = rg("b", "#ff7b7b", "#d3173a") + LEAF_DEF
    body = ('<path d="M128 228 C 66 204 34 140 46 100 C 56 66 96 60 128 74 C 160 60 200 66 210 100 '
            'C 222 140 190 204 128 228 Z" fill="url(#b)" stroke="#7d0c1e" stroke-width="7" stroke-linejoin="round"/>')
    seeds = ""
    for (x, y) in [(90, 110), (128, 104), (166, 110), (74, 142), (110, 140), (146, 140), (182, 142),
                   (94, 172), (128, 170), (162, 172), (112, 200), (144, 200)]:
        seeds += f'<ellipse cx="{x}" cy="{y}" rx="5" ry="8" fill="#ffe28a" stroke="#c9832a" stroke-width="2"/>'
    crown = ""
    for a in (-150, -110, -70, -30, -90):
        crown += leaf(128, 76, 46, 14, a)
    crown += '<rect x="122" y="30" width="12" height="30" rx="6" fill="#4f8f1f" stroke="#2d6b16" stroke-width="4"/>'
    s = shine(88, 112, 22, 12, -40)
    save("tile_red", T, T, f'<g filter="url(#ds)">{body}{seeds}{s}{crown}</g>', "assets/tiles/red.png", d)


def tile_apple():
    d = rg("b", "#d9ff8a", "#4caf26") + lg("st", "#8a5a2b", "#5b3412") + LEAF_DEF
    body = ('<path d="M128 80 C 150 58 210 58 218 124 C 224 180 186 226 152 224 C 142 223 136 218 128 218 '
            'C 120 218 114 223 104 224 C 70 226 32 180 38 124 C 46 58 106 58 128 80 Z" fill="url(#b)" '
            'stroke="#256b12" stroke-width="7" stroke-linejoin="round"/>')
    stem = '<path d="M128 84 Q 124 52 136 34" stroke="#5b3412" stroke-width="11" fill="none" stroke-linecap="round"/>'
    lf = leaf(138, 50, 58, 20, -20)
    s = shine(86, 118, 24, 14, -45) + shine(176, 182, 10, 6, -45, 0.3)
    save("tile_green", T, T, f'<g filter="url(#ds)">{body}{s}{stem}{lf}</g>', "assets/tiles/green.png", d)


def tile_corn():
    d = lg("b", "#fff27a", "#f2b20c", "1", "0") + lg("h", "#9be05a", "#3a8f1e", "1", "0") + \
        '<clipPath id="cob"><ellipse cx="128" cy="116" rx="50" ry="92"/></clipPath>'
    cob = '<ellipse cx="128" cy="116" rx="50" ry="92" fill="url(#b)" stroke="#a96d06" stroke-width="7"/>'
    kern = '<g clip-path="url(#cob)">'
    for row in range(14):
        y = 30 + row * 14
        off = 7 if row % 2 else 0
        for col in range(9):
            x = 74 + col * 14 + off
            kern += f'<rect x="{x}" y="{y}" width="12" height="12" rx="5" fill="#ffe14d" stroke="#d99708" stroke-width="2"/>'
    kern += '</g>'
    husk = ('<path d="M128 236 C 70 220 52 160 70 104 C 84 150 100 190 128 204 Z" fill="url(#h)" stroke="#256b12" '
            'stroke-width="7" stroke-linejoin="round"/>'
            '<path d="M128 236 C 186 220 204 160 186 104 C 172 150 156 190 128 204 Z" fill="url(#h)" stroke="#256b12" '
            'stroke-width="7" stroke-linejoin="round"/>')
    s = shine(104, 70, 12, 30, 10, 0.55)
    save("tile_yellow", T, T, f'<g filter="url(#ds)">{cob}{kern}{s}{husk}</g>', "assets/tiles/yellow.png", d)


def tile_carrot():
    d = lg("b", "#ffb347", "#ef6a10", "1", "0") + LEAF_DEF
    tops = leaf(128, 74, 60, 16, -120) + leaf(128, 74, 66, 16, -90) + leaf(128, 74, 60, 16, -60)
    body = ('<path d="M84 82 Q 128 62 172 82 Q 172 150 136 226 Q 128 238 120 226 Q 84 150 84 82 Z" '
            'fill="url(#b)" stroke="#a03d05" stroke-width="7" stroke-linejoin="round"/>')
    ridges = ""
    for (x1, y1, x2) in [(96, 112, 116), (150, 130, 170), (104, 160, 124), (140, 180, 156), (118, 204, 132)]:
        ridges += f'<path d="M{x1} {y1} L{x2} {y1+4}" stroke="#c2500a" stroke-width="5" stroke-linecap="round"/>'
    s = shine(106, 104, 10, 26, 15, 0.55)
    save("tile_orange", T, T, f'<g filter="url(#ds)" transform="rotate(-18 128 140)">{tops}{body}{ridges}{s}</g>',
         "assets/tiles/orange.png", d)


def berry(cx, cy, r, grad="b", stroke="#16367d"):
    star = ""
    for i in range(5):
        a = math.radians(i * 72 - 90)
        star += f'<path d="M{cx} {cy-r*0.72} L{cx+math.cos(a)*r*0.2:.1f} {cy-r*0.72+math.sin(a)*r*0.2:.1f}" ' \
                f'stroke="{stroke}" stroke-width="4" stroke-linecap="round"/>'
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="url(#{grad})" stroke="{stroke}" stroke-width="7"/>'
            f'{shine(cx - r*0.35, cy - r*0.1, r*0.28, r*0.17, -40, 0.6)}{star}')


def tile_blue():
    d = rg("b", "#9fd0ff", "#2558d0") + LEAF_DEF
    body = leaf(118, 70, 60, 18, -150) + leaf(138, 70, 60, 18, -30)
    body += berry(88, 150, 50) + berry(170, 150, 50) + berry(128, 104, 48) + berry(128, 186, 46)
    save("tile_blue", T, T, f'<g filter="url(#ds)">{body}</g>', "assets/tiles/blue.png", d)


def tile_grape():
    d = rg("b", "#e2b2ff", "#7224b8") + LEAF_DEF
    pts = [(96, 92), (128, 88), (160, 92), (80, 122), (112, 120), (144, 120), (176, 122), (96, 152), (128, 152),
           (160, 152), (112, 182), (144, 182), (128, 210)]
    g = '<path d="M128 84 Q 126 50 144 30" stroke="#5b3412" stroke-width="10" fill="none" stroke-linecap="round"/>'
    g += leaf(132, 52, 62, 22, -160)
    for (x, y) in sorted(pts, key=lambda p: p[1]):
        g += (f'<circle cx="{x}" cy="{y}" r="24" fill="url(#b)" stroke="#45107a" stroke-width="6"/>'
              f'{shine(x-8, y-8, 7, 4, -40, 0.7)}')
    save("tile_purple", T, T, f'<g filter="url(#ds)">{g}</g>', "assets/tiles/purple.png", d)


def tile_rocket():
    d = lg("b", "#ffffff", "#c9d6e6") + lg("n", "#ff6b6b", "#c4102e") + rg("w", "#c9f1ff", "#2e8fd6") + \
        lg("f", "#fff36b", "#ff7a00", "1", "0")
    flame = ('<path d="M70 128 Q 40 100 14 128 Q 40 156 70 128 Z" fill="url(#f)" stroke="#e05a00" stroke-width="5"/>'
             '<path d="M66 128 Q 48 114 34 128 Q 48 142 66 128 Z" fill="#fff8c0"/>')
    body = ('<path d="M66 100 L 176 100 Q 226 106 240 128 Q 226 150 176 156 L 66 156 Q 56 128 66 100 Z" '
            'fill="url(#b)" stroke="#5a1a24" stroke-width="7" stroke-linejoin="round"/>')
    nose = ('<path d="M176 100 Q 226 106 240 128 Q 226 150 176 156 Q 186 128 176 100 Z" fill="url(#n)" '
            'stroke="#5a1a24" stroke-width="7" stroke-linejoin="round"/>')
    fins = ('<path d="M74 100 L 52 62 L 108 100 Z" fill="url(#n)" stroke="#5a1a24" stroke-width="7" stroke-linejoin="round"/>'
            '<path d="M74 156 L 52 194 L 108 156 Z" fill="url(#n)" stroke="#5a1a24" stroke-width="7" stroke-linejoin="round"/>')
    win = '<circle cx="138" cy="128" r="18" fill="url(#w)" stroke="#5a1a24" stroke-width="6"/>' + shine(132, 122, 6, 4)
    stripe = '<rect x="94" y="100" width="12" height="56" fill="#ff5a5a" opacity="0.85"/>'
    s = shine(120, 110, 40, 6, 0, 0.7)
    save("special_rocket", T, T, f'<g filter="url(#ds)">{flame}{body}{stripe}{nose}{fins}{win}{s}</g>',
         "assets/tiles/rocket.png", d)


def tile_basket():
    d = lg("b", "#e7a75a", "#9b5a1e") + rg("g", "#fff7b0", "#ffd23f00", "50%", "50%", "50%") + \
        rg("r", "#ff7b7b", "#d3173a") + rg("a", "#d9ff8a", "#4caf26") + rg("o", "#ffcf6b", "#ef6a10") + \
        '<clipPath id="bk"><path d="M42 120 L 214 120 L 194 222 Q 128 238 62 222 Z"/></clipPath>'
    glow = '<circle cx="128" cy="128" r="124" fill="url(#g)"/>'
    handle = '<path d="M60 124 Q 128 10 196 124" stroke="#7a4214" stroke-width="18" fill="none" stroke-linecap="round"/>' \
             '<path d="M60 124 Q 128 10 196 124" stroke="#e7a75a" stroke-width="8" fill="none" stroke-linecap="round"/>'
    fruits = (f'<circle cx="92" cy="110" r="30" fill="url(#r)" stroke="#7d0c1e" stroke-width="6"/>'
              f'<circle cx="164" cy="108" r="30" fill="url(#a)" stroke="#256b12" stroke-width="6"/>'
              f'<circle cx="128" cy="96" r="30" fill="url(#o)" stroke="#a03d05" stroke-width="6"/>'
              + shine(84, 100, 8, 5) + shine(156, 98, 8, 5) + shine(120, 86, 8, 5))
    basket = '<path d="M42 120 L 214 120 L 194 222 Q 128 238 62 222 Z" fill="url(#b)" stroke="#5e3008" stroke-width="7" stroke-linejoin="round"/>'
    weave = '<g clip-path="url(#bk)" stroke="#7a4214" stroke-width="5" opacity="0.8">'
    for y in range(140, 240, 22):
        weave += f'<path d="M30 {y} Q 128 {y+10} 226 {y}" fill="none"/>'
    for x in range(56, 220, 26):
        weave += f'<path d="M{x} 120 L {x + (128 - x) * 0.12} 236" fill="none"/>'
    weave += '</g>'
    rim = '<rect x="34" y="112" width="188" height="24" rx="12" fill="#c98035" stroke="#5e3008" stroke-width="7"/>'
    save("special_basket", T, T, f'{glow}<g filter="url(#ds)">{handle}{fruits}{basket}{weave}{rim}'
         f'{shine(80, 122, 30, 4, 0, 0.5)}</g>', "assets/tiles/basket.png", d)


def tile_rainbow():
    cols = ["#ff4d6d", "#ff9f1c", "#ffe14d", "#5ed16a", "#4cc9f0", "#9b5de5"]
    d = '<clipPath id="c"><circle cx="128" cy="134" r="84"/></clipPath>' + \
        rg("hl", "#ffffffcc", "#ffffff00", "35%", "30%", "60%") + rg("g", "#ffffff", "#ffffff00", "50%", "50%", "50%") + LEAF_DEF
    wedges = '<g clip-path="url(#c)">'
    for i, c in enumerate(cols):
        a1 = math.radians(i * 60 - 90)
        a2 = math.radians((i + 1) * 60 - 90)
        wedges += (f'<path d="M128 134 L {128 + 200*math.cos(a1):.1f} {134 + 200*math.sin(a1):.1f} '
                   f'L {128 + 200*math.cos(a2):.1f} {134 + 200*math.sin(a2):.1f} Z" fill="{c}"/>')
    wedges += '<circle cx="128" cy="134" r="84" fill="url(#hl)"/></g>'
    ring = '<circle cx="128" cy="134" r="84" fill="none" stroke="#5a2a7a" stroke-width="7"/>'
    glow = '<circle cx="128" cy="134" r="124" fill="url(#g)" opacity="0.8"/>'
    sp = ""
    for (x, y, r) in [(46, 50, 16), (212, 70, 12), (206, 210, 14), (40, 200, 10)]:
        sp += (f'<path d="M{x} {y-r} Q {x} {y} {x+r} {y} Q {x} {y} {x} {y+r} Q {x} {y} {x-r} {y} Q {x} {y} {x} {y-r} Z" '
               f'fill="#fff" stroke="#ffd23f" stroke-width="2"/>')
    crown = leaf(128, 54, 44, 14, -130) + leaf(128, 54, 44, 14, -50)
    face = '<circle cx="104" cy="128" r="9" fill="#3a1a4a"/><circle cx="152" cy="128" r="9" fill="#3a1a4a"/>' \
           '<circle cx="107" cy="125" r="3" fill="#fff"/><circle cx="155" cy="125" r="3" fill="#fff"/>' \
           '<path d="M110 152 Q 128 168 146 152" stroke="#3a1a4a" stroke-width="6" fill="none" stroke-linecap="round"/>'
    save("special_rainbow", T, T, f'{glow}<g filter="url(#ds)">{wedges}{ring}{crown}{face}'
         f'{shine(92, 92, 22, 12, -35, 0.7)}</g>{sp}', "assets/tiles/rainbow.png", d)


def tile_weed():
    d = rg("dirt", "#a8743f", "#6b4220", "50%", "40%", "60%") + lg("w1", "#7fcf3a", "#2f7a14") + lg("w2", "#5aa828", "#21580c")
    mound = '<ellipse cx="128" cy="190" rx="104" ry="48" fill="url(#dirt)" stroke="#4a2c12" stroke-width="7"/>'
    clods = "".join(f'<ellipse cx="{x}" cy="{y}" rx="12" ry="7" fill="#8a5a2b" opacity="0.8"/>'
                    for x, y in [(70, 196), (180, 200), (128, 214), (96, 176), (160, 178)])
    blades = ""
    random.seed(7)
    for i, (x, ang, ln, g) in enumerate([(80, -130, 120, "w2"), (100, -110, 150, "w1"), (128, -92, 170, "w1"),
                                          (156, -70, 150, "w1"), (176, -50, 120, "w2"), (114, -100, 130, "w2"),
                                          (144, -80, 135, "w2")]):
        a = math.radians(ang)
        tx, ty = x + math.cos(a) * ln, 186 + math.sin(a) * ln
        px, py = -math.sin(a) * 34, math.cos(a) * 34
        blades += (f'<path d="M{x-16} 186 Q {(x+tx)/2+px:.1f} {(186+ty)/2+py:.1f} {tx:.1f} {ty:.1f} '
                   f'Q {(x+tx)/2-px*0.6:.1f} {(186+ty)/2-py*0.6:.1f} {x+16} 186 Z" fill="url(#{g})" '
                   f'stroke="#1b4a0a" stroke-width="5" stroke-linejoin="round"/>')
    thorns = "".join(f'<circle cx="{x}" cy="{y}" r="7" fill="#b84ad8" stroke="#5a1a6a" stroke-width="4"/>'
                     for x, y in [(98, 60), (164, 70), (128, 26)])
    save("weed", T, T, f'<g filter="url(#ds)">{mound}{clods}{blades}{thorns}</g>', "assets/tiles/weed.png", d)


# ---------------------------------------------------------------- helpers (512)
H = 512


def eye(x, y, r=22):
    return (f'<ellipse cx="{x}" cy="{y}" rx="{r}" ry="{r*1.15}" fill="#fff" stroke="#2a1a10" stroke-width="5"/>'
            f'<circle cx="{x+3}" cy="{y+4}" r="{r*0.6}" fill="#2a1a10"/><circle cx="{x+8}" cy="{y-3}" r="{r*0.22}" fill="#fff"/>')


def helper_rooster():
    d = rg("b", "#ffb15c", "#d2561a") + rg("ch", "#fff1c9", "#f2c27a") + rg("cm", "#ff6b6b", "#c4102e") + \
        lg("t1", "#3fbf9f", "#14594a") + lg("t2", "#2f7fd0", "#163f7a") + lg("bk", "#ffe066", "#f29c0c")
    tail = ""
    for i, (ang, g) in enumerate([(-80, "t1"), (-55, "t2"), (-30, "t1"), (-5, "t2")]):
        tail += (f'<path d="M0 0 Q 60 -150 150 -170 Q 110 -120 90 0 Z" fill="url(#{g})" stroke="#0e2a2a" '
                 f'stroke-width="8" stroke-linejoin="round" transform="translate(150 330) rotate({ang + 50}) scale(-1 1)"/>')
    legs = ('<path d="M220 420 L 214 476 M 214 476 L 190 488 M 214 476 L 234 490 M 290 420 L 296 476 M 296 476 L 276 490 '
            'M 296 476 L 320 488" stroke="#f29c0c" stroke-width="14" stroke-linecap="round" fill="none"/>')
    body = '<ellipse cx="256" cy="330" rx="150" ry="120" fill="url(#b)" stroke="#6b2a08" stroke-width="9"/>'
    chest = '<ellipse cx="300" cy="350" rx="80" ry="80" fill="url(#ch)" opacity="0.9"/>'
    wing = ('<path d="M170 300 Q 250 270 290 330 Q 240 400 170 370 Q 150 335 170 300 Z" fill="#c24a10" stroke="#6b2a08" '
            'stroke-width="8" stroke-linejoin="round"/>'
            '<path d="M190 330 Q 230 320 260 340 M 190 352 Q 225 345 250 360" stroke="#6b2a08" stroke-width="6" fill="none" stroke-linecap="round"/>')
    neck = '<ellipse cx="320" cy="220" rx="88" ry="100" fill="url(#b)" stroke="#6b2a08" stroke-width="9"/>'
    comb = ('<path d="M268 140 Q 262 92 292 104 Q 300 64 330 92 Q 352 64 366 106 Q 396 104 386 146 Z" fill="url(#cm)" '
            'stroke="#7d0c1e" stroke-width="8" stroke-linejoin="round"/>')
    beak = ('<path d="M392 196 L 452 214 L 392 236 Z" fill="url(#bk)" stroke="#8a4a05" stroke-width="7" stroke-linejoin="round"/>')
    wattle = '<path d="M384 236 Q 404 290 376 292 Q 356 286 366 240 Z" fill="url(#cm)" stroke="#7d0c1e" stroke-width="7"/>'
    cheek = '<ellipse cx="344" cy="246" rx="18" ry="11" fill="#ff7b7b" opacity="0.6"/>'
    face = eye(350, 192, 24)
    s = shine(220, 270, 50, 22, -20, 0.35) + shine(296, 168, 22, 12, -30, 0.4)
    save("helper_rooster", H, H, f'<g filter="url(#ds)" transform="translate(52 26) scale(0.88)">{tail}{legs}{body}{chest}{wing}{neck}{comb}{wattle}{beak}'
         f'{face}{cheek}{s}</g>', "assets/helpers/rooster.png", d, (10, 8))


def helper_squirrel():
    d = rg("b", "#ffa45c", "#d0501a") + rg("bl", "#fff4dc", "#f2cf9a") + rg("t", "#ffb870", "#c2440e", "40%", "40%", "70%") + \
        rg("ac", "#c98035", "#7a4214") + lg("cap", "#8a5a2b", "#4a2c12")
    tail = ('<path d="M190 440 C 40 450 20 300 90 220 C 140 160 70 110 120 60 C 190 20 250 90 220 150 '
            'C 200 190 150 200 170 260 C 190 320 260 330 250 400 Z" fill="url(#t)" stroke="#6b2a08" stroke-width="10" stroke-linejoin="round"/>'
            '<path d="M110 300 Q 80 240 130 190 M 140 110 Q 160 80 190 100" stroke="#ffd7a8" stroke-width="12" fill="none" stroke-linecap="round" opacity="0.7"/>')
    body = '<ellipse cx="300" cy="370" rx="104" ry="110" fill="url(#b)" stroke="#6b2a08" stroke-width="9"/>'
    belly = '<ellipse cx="316" cy="384" rx="62" ry="80" fill="url(#bl)"/>'
    feet = '<ellipse cx="256" cy="472" rx="40" ry="18" fill="#d0501a" stroke="#6b2a08" stroke-width="8"/>' \
           '<ellipse cx="350" cy="472" rx="40" ry="18" fill="#d0501a" stroke="#6b2a08" stroke-width="8"/>'
    head = '<ellipse cx="316" cy="210" rx="104" ry="94" fill="url(#b)" stroke="#6b2a08" stroke-width="9"/>'
    ears = ('<path d="M236 160 L 222 64 L 282 128 Z" fill="url(#b)" stroke="#6b2a08" stroke-width="9" stroke-linejoin="round"/>'
            '<path d="M346 124 L 392 56 L 400 150 Z" fill="url(#b)" stroke="#6b2a08" stroke-width="9" stroke-linejoin="round"/>'
            '<path d="M222 64 L 214 40 M 392 56 L 404 34" stroke="#6b2a08" stroke-width="10" stroke-linecap="round"/>'
            '<path d="M244 140 L 236 96 L 266 128 Z M 362 124 L 388 86 L 390 136 Z" fill="#ffb7a0"/>')
    muzzle = '<ellipse cx="334" cy="246" rx="58" ry="40" fill="url(#bl)"/>'
    nose = '<ellipse cx="340" cy="226" rx="14" ry="10" fill="#4a1a10"/>'
    mouth = '<path d="M318 252 Q 340 270 362 252" stroke="#4a1a10" stroke-width="6" fill="none" stroke-linecap="round"/>' \
            '<rect x="330" y="258" width="18" height="16" rx="3" fill="#fff" stroke="#4a1a10" stroke-width="3"/>'
    cheeks = '<ellipse cx="270" cy="244" rx="18" ry="11" fill="#ff7b7b" opacity="0.6"/><ellipse cx="398" cy="240" rx="16" ry="10" fill="#ff7b7b" opacity="0.6"/>'
    acorn = ('<ellipse cx="320" cy="350" rx="40" ry="46" fill="url(#ac)" stroke="#4a2c12" stroke-width="8"/>'
             '<path d="M276 330 Q 320 280 364 330 Z" fill="url(#cap)" stroke="#4a2c12" stroke-width="8" stroke-linejoin="round"/>'
             '<path d="M320 300 L 324 280" stroke="#4a2c12" stroke-width="8" stroke-linecap="round"/>' + shine(306, 352, 10, 16, 0, 0.45))
    paws = '<ellipse cx="276" cy="360" rx="22" ry="18" fill="#ffa45c" stroke="#6b2a08" stroke-width="7"/>' \
           '<ellipse cx="364" cy="360" rx="22" ry="18" fill="#ffa45c" stroke="#6b2a08" stroke-width="7"/>'
    save("helper_squirrel", H, H, f'<g filter="url(#ds)">{tail}{body}{belly}{feet}{acorn}{paws}{ears}{head}{muzzle}'
         f'{eye(286, 196, 22)}{eye(366, 192, 22)}{nose}{mouth}{cheeks}{shine(270, 150, 26, 12, -30, 0.4)}</g>',
         "assets/helpers/squirrel.png", d, (10, 8))


def helper_hedgehog():
    d = rg("sp", "#a8743f", "#4a2c12", "40%", "40%", "70%") + rg("f", "#fff1d6", "#e8c08a") + rg("ap", "#ff7b7b", "#c4102e")
    spikes = ""
    for i in range(17):
        a = math.radians(170 + i * 12.5)
        x, y = 230 + math.cos(a) * 168, 320 + math.sin(a) * 150
        x2, y2 = 230 + math.cos(a) * 236, 320 + math.sin(a) * 214
        a2 = a + 0.17
        x3, y3 = 230 + math.cos(a2) * 168, 320 + math.sin(a2) * 150
        spikes += f'<path d="M{x:.1f} {y:.1f} L {x2:.1f} {y2:.1f} L {x3:.1f} {y3:.1f} Z" fill="#6b4220" stroke="#2e1a08" stroke-width="7" stroke-linejoin="round"/>'
    back = '<ellipse cx="230" cy="330" rx="180" ry="150" fill="url(#sp)" stroke="#2e1a08" stroke-width="9"/>'
    texture = "".join(f'<path d="M{x} {y} l 18 -26" stroke="#2e1a08" stroke-width="6" stroke-linecap="round" opacity="0.6"/>'
                      for x, y in [(140, 260), (200, 230), (260, 230), (120, 330), (180, 300), (240, 290), (300, 270), (160, 380), (220, 360)])
    apple = (f'<circle cx="190" cy="196" r="44" fill="url(#ap)" stroke="#7d0c1e" stroke-width="8"/>{shine(176, 182, 12, 7)}'
             '<path d="M190 156 Q 192 136 204 128" stroke="#5b3412" stroke-width="8" fill="none" stroke-linecap="round"/>')
    face = ('<path d="M300 220 Q 380 230 470 330 Q 480 350 460 360 Q 380 420 300 430 Q 260 330 300 220 Z" fill="url(#f)" '
            'stroke="#6b4220" stroke-width="9" stroke-linejoin="round"/>')
    nose = '<circle cx="466" cy="342" r="20" fill="#2a1a10"/>' + shine(460, 334, 6, 4, 0, 0.7)
    feet = '<ellipse cx="190" cy="470" rx="38" ry="18" fill="#e8c08a" stroke="#6b4220" stroke-width="8"/>' \
           '<ellipse cx="320" cy="470" rx="38" ry="18" fill="#e8c08a" stroke="#6b4220" stroke-width="8"/>'
    mouth = '<path d="M380 380 Q 400 396 424 384" stroke="#4a1a10" stroke-width="6" fill="none" stroke-linecap="round"/>'
    cheek = '<ellipse cx="350" cy="370" rx="20" ry="12" fill="#ff7b7b" opacity="0.6"/>'
    ear = '<circle cx="320" cy="250" r="22" fill="#e8c08a" stroke="#6b4220" stroke-width="7"/>'
    save("helper_hedgehog", H, H, f'<g filter="url(#ds)">{feet}{spikes}{back}{texture}{apple}{face}{ear}'
         f'{eye(390, 310, 20)}{nose}{mouth}{cheek}</g>', "assets/helpers/hedgehog.png", d, (10, 8))


def helper_bee():
    d = rg("b", "#fff27a", "#f2a60c") + rg("w", "#ffffffee", "#bfe6ffaa", "40%", "40%", "70%") + \
        '<clipPath id="bc"><ellipse cx="256" cy="300" rx="150" ry="130"/></clipPath>'
    wings = ('<ellipse cx="200" cy="150" rx="70" ry="110" fill="url(#w)" stroke="#3a6a8a" stroke-width="7" transform="rotate(-25 200 150)"/>'
             '<ellipse cx="320" cy="150" rx="70" ry="110" fill="url(#w)" stroke="#3a6a8a" stroke-width="7" transform="rotate(25 320 150)"/>')
    sting = '<path d="M100 330 L 50 350 L 104 370 Z" fill="#2a1a10"/>'
    body = '<ellipse cx="256" cy="300" rx="150" ry="130" fill="url(#b)"/>'
    stripes = '<g clip-path="url(#bc)">' + "".join(
        f'<path d="M{x} 150 Q {x-30} 300 {x} 450" stroke="#2a1a10" stroke-width="34" fill="none"/>' for x in (150, 220)) + '</g>'
    outline = '<ellipse cx="256" cy="300" rx="150" ry="130" fill="none" stroke="#2a1a10" stroke-width="9"/>'
    ant = ('<path d="M300 200 Q 300 110 260 80 M 360 210 Q 400 120 440 110" stroke="#2a1a10" stroke-width="9" fill="none" stroke-linecap="round"/>'
           '<circle cx="260" cy="80" r="16" fill="#2a1a10"/><circle cx="440" cy="110" r="16" fill="#2a1a10"/>')
    face = eye(300, 280, 24) + eye(370, 280, 24) + \
        '<path d="M310 340 Q 340 372 376 340" stroke="#2a1a10" stroke-width="8" fill="none" stroke-linecap="round"/>' \
        '<ellipse cx="282" cy="330" rx="20" ry="12" fill="#ff7b7b" opacity="0.7"/><ellipse cx="398" cy="326" rx="18" ry="11" fill="#ff7b7b" opacity="0.7"/>'
    legs = '<path d="M210 420 L 200 460 M 270 428 L 270 468 M 330 420 L 340 458" stroke="#2a1a10" stroke-width="10" stroke-linecap="round"/>'
    save("helper_bee", H, H, f'<g filter="url(#ds)">{wings}{legs}{sting}{body}{stripes}{outline}{ant}{face}'
         f'{shine(220, 220, 50, 20, -20, 0.45)}</g>', "assets/helpers/bee.png", d, (10, 8))


if __name__ == "__main__":
    for fn in list(globals().values()):
        if callable(fn) and getattr(fn, "__name__", "").startswith(("tile_", "helper_")):
            fn()
    import farm_art  # noqa: E402  (second half of the art set)
    farm_art.generate(save, globals())
    import fx_art  # noqa: E402
    fx_art.generate(save, globals())
    print("svgs written to", OUT)
