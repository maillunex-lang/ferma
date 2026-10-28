"""Farm buildings, decorations, animals, UI icons and backgrounds.

Every upgradable farm object is drawn once per upgrade level so each upgrade
visibly changes the farm (abandoned -> repaired -> painted -> deluxe).
"""
import math
import random

OL = "#4a3216"  # common outline colour for farm objects


def generate(save, g):
    rg, lg, shine, leaf, LEAF_DEF = g["rg"], g["lg"], g["shine"], g["leaf"], g["LEAF_DEF"]

    def gshadow(cx, cy, rx, ry, op=0.28):
        return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="#2a3a10" opacity="{op}" filter="url(#soft)"/>'

    def planks(x, y, w, h, color, line, step=22, op=0.55):
        s = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'
        yy = y + step
        while yy < y + h:
            s += f'<path d="M{x} {yy} L{x+w} {yy}" stroke="{line}" stroke-width="3" opacity="{op}"/>'
            yy += step
        return s

    def window(x, y, w, h, lvl, glow=False):
        if lvl == 0:
            return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#2b2420" stroke="{OL}" stroke-width="6"/>'
                    f'<path d="M{x-6} {y+10} L{x+w+6} {y+h-14} M{x-6} {y+h-10} L{x+w+6} {y+14}" stroke="#8a6a44" '
                    f'stroke-width="12" stroke-linecap="round"/>')
        glass = "url(#glow_win)" if glow else "url(#glass)"
        s = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="6" fill="{glass}" stroke="{OL}" stroke-width="6"/>'
             f'<path d="M{x+w/2} {y} L{x+w/2} {y+h} M{x} {y+h/2} L{x+w} {y+h/2}" stroke="#fff8e6" stroke-width="6"/>'
             f'<path d="M{x+8} {y+h/2-8} L{x+w/2-10} {y+8}" stroke="#fff" stroke-width="5" opacity="0.6" stroke-linecap="round"/>')
        if lvl >= 2:
            s += (f'<rect x="{x-24}" y="{y-2}" width="20" height="{h+4}" rx="4" fill="#58b368" stroke="{OL}" stroke-width="5"/>'
                  f'<rect x="{x+w+4}" y="{y-2}" width="20" height="{h+4}" rx="4" fill="#58b368" stroke="{OL}" stroke-width="5"/>'
                  f'<rect x="{x-8}" y="{y+h}" width="{w+16}" height="18" rx="5" fill="#a0612a" stroke="{OL}" stroke-width="5"/>')
            for i in range(4):
                c = ["#ff6b8b", "#ffd23f", "#ff9f1c", "#c77dff"][i]
                s += f'<circle cx="{x + 6 + i * (w - 12) / 3:.0f}" cy="{y+h-2}" r="9" fill="{c}" stroke="{OL}" stroke-width="3"/>'
        return s

    common_defs = (lg("glass", "#d6f3ff", "#6fb8e6") + lg("glow_win", "#fff8b0", "#ffb340") + LEAF_DEF +
                   rg("tree", "#9be05a", "#3c8f20", "40%", "35%", "70%") + rg("treed", "#7cc040", "#2f7a14", "40%", "35%", "70%"))

    def bush(cx, cy, r, flowers=False, dry=False):
        f = "#b7a25a" if dry else "url(#tree)"
        st = "#6b5a20" if dry else "#235c10"
        s = ""
        for dx, dy, rr in [(-r * 0.6, 0, r * 0.7), (r * 0.6, 0, r * 0.7), (0, -r * 0.35, r * 0.8)]:
            s += f'<circle cx="{cx+dx:.0f}" cy="{cy+dy:.0f}" r="{rr:.0f}" fill="{f}" stroke="{st}" stroke-width="6"/>'
        if flowers:
            for dx, dy, c in [(-r * 0.5, -r * 0.1, "#ff6b8b"), (r * 0.4, -r * 0.4, "#ffd23f"), (r * 0.1, r * 0.2, "#fff")]:
                s += f'<circle cx="{cx+dx:.0f}" cy="{cy+dy:.0f}" r="{r*0.14:.0f}" fill="{c}" stroke="{OL}" stroke-width="3"/>'
        return s

    def flower(x, y, c, r=10):
        s = ""
        for i in range(5):
            a = math.radians(i * 72)
            s += f'<circle cx="{x+math.cos(a)*r:.1f}" cy="{y+math.sin(a)*r:.1f}" r="{r*0.75:.1f}" fill="{c}" stroke="{OL}" stroke-width="2.5"/>'
        return s + f'<circle cx="{x}" cy="{y}" r="{r*0.6:.1f}" fill="#ffd23f" stroke="{OL}" stroke-width="2.5"/>'

    def weeds(x, y, s=1.0):
        return (f'<path d="M{x} {y} q {-6*s} {-24*s} {-14*s} {-30*s} M{x} {y} q 0 {-30*s} {4*s} {-40*s} M{x} {y} q {8*s} {-20*s} {18*s} {-26*s}" '
                f'stroke="#7a8a2a" stroke-width="{6*s}" fill="none" stroke-linecap="round"/>')

    def grass_tuft(x, y, s=1.0, c="#4f9f2a"):
        out = ""
        for dx, h, lean in [(-8, 26, -10), (0, 36, 2), (8, 28, 12), (-3, 20, -16), (5, 22, 16)]:
            out += (f'<path d="M{x+dx*s-4*s:.1f} {y} Q {x+dx*s+lean*0.3*s:.1f} {y-h*0.6*s:.1f} {x+dx*s+lean*s:.1f} {y-h*s:.1f} '
                    f'Q {x+dx*s+lean*0.2*s+2*s:.1f} {y-h*0.5*s:.1f} {x+dx*s+4*s:.1f} {y} Z" fill="{c}" stroke="#2d6b16" stroke-width="{1.6*s:.1f}"/>')
        return out

    # ------------------------------------------------------------- house
    for lvl in range(4):
        W, Hh = 600, 540
        d = common_defs + lg("roof", ["#6d6058", "#b8553a", "#e84a3a", "#e84a3a"][lvl], ["#4a3f38", "#8a3a22", "#b52a20", "#b52a20"][lvl])
        b = gshadow(300, 470, 260, 40)
        wall_c = ["#a3937c", "#dca66b", "#fff1d0", "#fff1d0"][lvl]
        if lvl == 3:  # chimney with smoke
            b += ('<rect x="390" y="70" width="56" height="110" fill="#c46a4a" stroke="#4a3216" stroke-width="7"/>'
                  '<rect x="382" y="60" width="72" height="22" rx="6" fill="#a0503a" stroke="#4a3216" stroke-width="7"/>')
            for i, (x, y, r) in enumerate([(420, 40, 22), (440, 14, 16), (458, -4, 12)]):
                b += f'<circle cx="{x}" cy="{y+20}" r="{r}" fill="#ffffff" opacity="{0.8 - i*0.2}"/>'
        b += f'<g>{planks(130, 250, 340, 210, wall_c, "#7a5a34" if lvl < 2 else "#e6cfa0")}</g>'
        b += f'<rect x="130" y="250" width="340" height="210" fill="none" stroke="{OL}" stroke-width="8"/>'
        if lvl >= 2:  # timber frame
            b += (f'<path d="M130 300 L470 300 M200 250 L200 460 M400 250 L400 460" stroke="#a0612a" stroke-width="12"/>'
                  f'<rect x="130" y="250" width="340" height="210" fill="none" stroke="{OL}" stroke-width="8"/>')
        if lvl == 0:  # cracks
            b += '<path d="M150 270 l 20 30 l -10 20 l 16 24 M440 380 l -18 20 l 8 26" stroke="#4a3216" stroke-width="5" fill="none"/>'
        # roof
        roof = '<path d="M80 270 L300 70 L520 270 Z" fill="url(#roof)" stroke="#4a3216" stroke-width="9" stroke-linejoin="round"/>'
        b += roof
        if lvl >= 2:  # tiles
            for row in range(5):
                y = 130 + row * 30
                half = (y - 70) * 220 / 200
                x = 300 - half + 14
                while x < 300 + half - 14:
                    b += f'<path d="M{x:.0f} {y} q 14 18 28 0" stroke="#9a2018" stroke-width="4" fill="none" opacity="0.6"/>'
                    x += 30
        elif lvl == 1:
            for row in range(5):
                y = 120 + row * 30
                half = (y - 70) * 220 / 200
                b += f'<path d="M{300-half+10:.0f} {y} L{300+half-10:.0f} {y}" stroke="#6a2a14" stroke-width="4" opacity="0.6"/>'
        else:  # holes
            b += ('<path d="M220 180 l 30 -10 l 20 24 l -26 22 l -30 -8 Z" fill="#2b2420" stroke="#4a3216" stroke-width="5"/>'
                  '<path d="M340 210 l 40 0 l 6 26 l -40 6 Z" fill="#2b2420" stroke="#4a3216" stroke-width="5"/>'
                  '<path d="M170 240 l 80 -14" stroke="#8a6a44" stroke-width="14" stroke-linecap="round"/>')
        b += '<path d="M80 270 L300 70 L520 270" fill="none" stroke="#4a3216" stroke-width="9" stroke-linejoin="round"/>'
        b += shine(230, 150, 50, 10, -42, 0.25)
        # attic window
        if lvl >= 1:
            b += f'<circle cx="300" cy="190" r="30" fill="url(#{"glow_win" if lvl == 3 else "glass"})" stroke="{OL}" stroke-width="7"/>' \
                 f'<path d="M300 160 L300 220 M270 190 L330 190" stroke="#fff8e6" stroke-width="5"/>'
        # windows & door
        b += window(160, 320, 80, 70, lvl, lvl == 3) + window(360, 320, 80, 70, lvl, lvl == 3)
        door_c = ["#5a4430", "#8a5a2b", "#c0392b", "#c0392b"][lvl]
        if lvl == 0:
            b += f'<path d="M268 350 L332 346 L338 460 L262 460 Z" fill="{door_c}" stroke="{OL}" stroke-width="7"/>'
        else:
            b += (f'<path d="M262 460 L262 360 Q300 320 338 360 L338 460 Z" fill="{door_c}" stroke="{OL}" stroke-width="7"/>'
                  f'<circle cx="326" cy="410" r="6" fill="#ffd23f" stroke="{OL}" stroke-width="3"/>')
        if lvl == 3:  # porch & steps & bushes & lamp
            b += ('<rect x="240" y="456" width="120" height="16" rx="4" fill="#c98035" stroke="#4a3216" stroke-width="5"/>'
                  '<rect x="226" y="470" width="148" height="16" rx="4" fill="#a0612a" stroke="#4a3216" stroke-width="5"/>'
                  '<path d="M236 300 L364 300 L380 330 L220 330 Z" fill="#e84a3a" stroke="#4a3216" stroke-width="6" stroke-linejoin="round"/>'
                  '<rect x="236" y="330" width="10" height="130" fill="#fff1d0" stroke="#4a3216" stroke-width="4"/>'
                  '<rect x="354" y="330" width="10" height="130" fill="#fff1d0" stroke="#4a3216" stroke-width="4"/>')
            b += bush(120, 450, 44, True) + bush(482, 450, 44, True)
            b += '<circle cx="300" cy="346" r="12" fill="#fff6a0" stroke="#4a3216" stroke-width="4"/>'
        elif lvl == 2:
            b += bush(118, 452, 36) + bush(484, 452, 36)
        elif lvl == 0:
            b += weeds(140, 466, 1.3) + weeds(460, 466, 1.2) + weeds(220, 470, 1.0)
        save(f"farm_house_{lvl}", W, Hh, b, f"assets/farm/house_{lvl}.png", d)

    # ------------------------------------------------------------- barn
    for lvl in range(4):
        W, Hh = 660, 560
        red = ["#9a6a5a", "#d8423a", "#e0453c", "#e0453c"][lvl]
        dred = ["#6a4a3e", "#a02a24", "#a82c24", "#a82c24"][lvl]
        d = common_defs + lg("wall", red, dred) + lg("silo", "#e8e8f0", "#9aa4b8", "1", "0") + lg("hay", "#ffe680", "#d9a520")
        b = gshadow(330, 500, 300, 40)
        if lvl == 3:
            b += ('<rect x="500" y="160" width="110" height="320" fill="url(#silo)" stroke="#4a3216" stroke-width="8"/>'
                  '<path d="M500 160 Q 555 90 610 160 Z" fill="#e84a3a" stroke="#4a3216" stroke-width="8"/>'
                  + "".join(f'<path d="M500 {y} L610 {y}" stroke="#7a8498" stroke-width="4"/>' for y in range(200, 480, 40)))
        body = (f'<path d="M80 260 L140 140 L290 80 L440 140 L500 260 L500 480 L80 480 Z" fill="url(#wall)" '
                f'stroke="#4a3216" stroke-width="9" stroke-linejoin="round"/>')
        b += body
        for x in range(100, 500, 30):
            b += f'<path d="M{x} {200 if 140 < x < 440 else 260} L{x} 478" stroke="#000" stroke-width="3" opacity="0.15"/>'
        roof = (f'<path d="M60 270 L130 136 L290 66 L450 136 L520 270 L490 270 L432 150 L290 92 L148 150 L90 270 Z" '
                f'fill="{["#5a5048", "#6a4a3e", "#4a5a6a", "#4a5a6a"][lvl]}" stroke="#4a3216" stroke-width="8" stroke-linejoin="round"/>')
        b += roof
        if lvl >= 2:  # white trims
            b += ('<path d="M92 268 L148 152 L290 94 L432 152 L488 268" fill="none" stroke="#fff" stroke-width="10"/>'
                  '<rect x="84" y="470" width="412" height="12" fill="#fff"/>')
        # loft
        b += ('<rect x="255" y="150" width="70" height="70" fill="#4a2a1a" stroke="#4a3216" stroke-width="7"/>' if lvl > 0 else
              '<rect x="255" y="150" width="70" height="70" fill="#2b2420" stroke="#4a3216" stroke-width="7"/>')
        if lvl >= 1:
            b += '<path d="M262 200 Q 290 170 318 200 L318 218 L262 218 Z" fill="url(#hay)" stroke="#a07010" stroke-width="4"/>'
        # door
        if lvl == 0:
            b += ('<rect x="200" y="300" width="180" height="180" fill="#2b2420" stroke="#4a3216" stroke-width="7"/>'
                  '<path d="M206 300 L280 312 L270 480 L196 476 Z" fill="#7a5a4a" stroke="#4a3216" stroke-width="7"/>'
                  '<path d="M150 340 l 0 30 M 440 300 l 0 40 M 120 400 l 30 0" stroke="#2b2420" stroke-width="18"/>')
            b += weeds(110, 486, 1.4) + weeds(460, 486, 1.2)
        else:
            trim = "#fff" if lvl >= 2 else "#8a3a22"
            b += (f'<rect x="200" y="300" width="180" height="180" fill="{dred}" stroke="#4a3216" stroke-width="7"/>'
                  f'<path d="M200 300 L290 390 L380 300 M200 480 L290 390 L380 480 M290 300 L290 480" stroke="{trim}" stroke-width="10" fill="none"/>'
                  f'<rect x="200" y="300" width="180" height="180" fill="none" stroke="{trim}" stroke-width="10"/>')
        if lvl >= 2:
            b += ('<rect x="40" y="420" width="90" height="64" rx="10" fill="url(#hay)" stroke="#a07010" stroke-width="6"/>'
                  '<path d="M50 440 L120 440 M50 462 L120 462" stroke="#c08a10" stroke-width="4"/>')
        if lvl == 3:
            b += ('<path d="M290 66 L290 20 M270 34 L310 34" stroke="#4a3216" stroke-width="6"/>'
                  '<path d="M290 20 l 26 8 l -26 8 Z" fill="#ffd23f" stroke="#4a3216" stroke-width="4"/>'
                  '<ellipse cx="450" cy="470" rx="30" ry="22" fill="#e8d0a0" stroke="#4a3216" stroke-width="5"/>')
        b += shine(200, 160, 60, 10, -24, 0.2)
        save(f"farm_barn_{lvl}", W, Hh, b, f"assets/farm/barn_{lvl}.png", d)

    # ------------------------------------------------------------- beds
    for lvl in range(4):
        W, Hh = 580, 400
        d = common_defs + lg("soil", "#9a6a3a" if lvl else "#a8906a", "#6b4220" if lvl else "#8a7454") + rg("cab", "#c8f08a", "#4caf26") + \
            rg("pump", "#ffb347", "#e0620c")
        b = gshadow(290, 340, 270, 40)
        b += f'<rect x="40" y="60" width="500" height="290" rx="40" fill="url(#soil)" stroke="#4a3216" stroke-width="8"/>'
        if lvl >= 3:
            b += f'<rect x="30" y="50" width="520" height="310" rx="46" fill="none" stroke="#c98035" stroke-width="14"/>' \
                 f'<rect x="30" y="50" width="520" height="310" rx="46" fill="none" stroke="#4a3216" stroke-width="3"/>'
        if lvl == 0:
            random.seed(3)
            for i in range(18):
                b += weeds(70 + random.random() * 440, 100 + random.random() * 240, 1.0 + random.random() * 0.6)
            for x, y in [(140, 200), (400, 140), (320, 290)]:
                b += f'<ellipse cx="{x}" cy="{y}" rx="22" ry="14" fill="#9a9a9a" stroke="#4a3216" stroke-width="4"/>'
        else:
            for r in range(4):
                y = 110 + r * 64
                b += f'<rect x="70" y="{y-18}" width="440" height="36" rx="18" fill="#5a3416" stroke="#3a2008" stroke-width="4"/>'
                b += f'<path d="M84 {y-10} L496 {y-10}" stroke="#8a5a2b" stroke-width="5" opacity="0.6"/>'
                if lvl == 2:
                    for x in range(96, 500, 44):
                        b += leaf(x, y, 22, 8, -120, sw=3) + leaf(x, y, 22, 8, -60, sw=3)
                elif lvl == 3:
                    for i, x in enumerate(range(100, 500, 56)):
                        kind = (r + i) % 3
                        if kind == 0:
                            b += f'<circle cx="{x}" cy="{y-10}" r="22" fill="url(#cab)" stroke="#256b12" stroke-width="4"/>' \
                                 f'<path d="M{x-10} {y-12} q 10 -10 20 0" stroke="#256b12" stroke-width="3" fill="none"/>'
                        elif kind == 1:
                            b += leaf(x, y - 4, 30, 9, -110, sw=3) + leaf(x, y - 4, 30, 9, -70, sw=3) + \
                                 f'<path d="M{x-8} {y-2} L{x+8} {y-2} L{x} {y+14} Z" fill="#ff8a1c" stroke="#a03d05" stroke-width="3"/>'
                        else:
                            b += f'<ellipse cx="{x}" cy="{y-8}" rx="24" ry="18" fill="url(#pump)" stroke="#a03d05" stroke-width="4"/>' \
                                 f'<path d="M{x} {y-26} l 2 -8" stroke="#4f8f1f" stroke-width="5" stroke-linecap="round"/>'
        if lvl == 3:
            b += '<rect x="480" y="10" width="12" height="80" fill="#a0612a" stroke="#4a3216" stroke-width="4"/>' \
                 '<rect x="440" y="16" width="92" height="40" rx="8" fill="#e7a75a" stroke="#4a3216" stroke-width="5"/>' \
                 '<circle cx="486" cy="36" r="10" fill="#ff8a1c" stroke="#4a3216" stroke-width="3"/>'
        save(f"farm_beds_{lvl}", W, Hh, b, f"assets/farm/beds_{lvl}.png", d)

    # ------------------------------------------------------------- orchard
    def tree(cx, base, size, kind):
        # kind: 0 stump, 1 sapling, 2 green, 3 fruit
        s = gshadow(cx, base, size * 0.8, size * 0.18)
        if kind == 0:
            return s + (f'<path d="M{cx-26} {base} L{cx-20} {base-40} L{cx+20} {base-40} L{cx+26} {base} Z" fill="#8a5a2b" stroke="{OL}" stroke-width="6"/>'
                        f'<ellipse cx="{cx}" cy="{base-40}" rx="20" ry="8" fill="#e7c08a" stroke="{OL}" stroke-width="5"/>')
        if kind == 1:
            return s + (f'<path d="M{cx} {base} L{cx} {base-90}" stroke="#8a5a2b" stroke-width="10" stroke-linecap="round"/>'
                        f'<path d="M{cx+24} {base} L{cx+24} {base-70}" stroke="#c98035" stroke-width="6"/>'
                        f'<path d="M{cx} {base-40} L{cx+24} {base-46}" stroke="#e7c08a" stroke-width="4"/>'
                        + leaf(cx, base - 90, 40, 14, -150, sw=4) + leaf(cx, base - 90, 40, 14, -30, sw=4) + leaf(cx, base - 70, 36, 12, -170, sw=4))
        r = size * (0.75 if kind == 2 else 0.9)
        s += f'<path d="M{cx-16} {base} L{cx-10} {base-r} L{cx+10} {base-r} L{cx+16} {base} Z" fill="#8a5a2b" stroke="{OL}" stroke-width="6"/>'
        cy = base - r - r * 0.6
        for dx, dy, rr in [(-r * 0.55, r * 0.15, r * 0.6), (r * 0.55, r * 0.15, r * 0.6), (0, -r * 0.25, r * 0.75)]:
            s += f'<circle cx="{cx+dx:.0f}" cy="{cy+dy:.0f}" r="{rr:.0f}" fill="url(#tree)" stroke="#235c10" stroke-width="7"/>'
        s += shine(cx - r * 0.3, cy - r * 0.4, r * 0.3, r * 0.15, -30, 0.3)
        if kind == 3:
            random.seed(int(cx))
            for i in range(9):
                a = random.random() * math.pi * 2
                rr = random.random() * r * 0.8
                c = "url(#appr)" if i % 3 else "url(#appg)"
                x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.7
                s += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="{size*0.11:.0f}" fill="{c}" stroke="#5a0a10" stroke-width="3"/>'
        return s

    for lvl in range(4):
        W, Hh = 620, 480
        d = common_defs + rg("appr", "#ff7b7b", "#c4102e") + rg("appg", "#d9ff8a", "#4caf26")
        b = f'<ellipse cx="310" cy="380" rx="290" ry="90" fill="{["#b8a86a", "#8ccf50", "#7cc848", "#7cc848"][lvl]}" opacity="0.7"/>'
        b += tree(160, 300, 110, lvl) + tree(460, 300, 110, lvl) + tree(310, 420, 130, lvl)
        if lvl == 0:
            b += bush(480, 420, 40, dry=True) + weeds(100, 420, 1.4) + weeds(540, 360, 1.2)
        if lvl == 3:
            b += ('<path d="M470 400 L560 400 L550 450 L480 450 Z" fill="#c98035" stroke="#4a3216" stroke-width="6"/>'
                  '<circle cx="496" cy="396" r="14" fill="url(#appr)" stroke="#5a0a10" stroke-width="3"/>'
                  '<circle cx="524" cy="392" r="14" fill="url(#appg)" stroke="#256b12" stroke-width="3"/>'
                  '<circle cx="546" cy="398" r="13" fill="url(#appr)" stroke="#5a0a10" stroke-width="3"/>')
        save(f"farm_orchard_{lvl}", W, Hh, b, f"assets/farm/orchard_{lvl}.png", d)

    # ------------------------------------------------------------- pond
    for lvl in range(3):
        W, Hh = 620, 420
        water = ("#7a8a4a", "#4a5a2a") if lvl == 0 else ("#8fe0ff", "#2e8fd6")
        d = common_defs + rg("water", water[0], water[1], "45%", "40%", "65%")
        b = '<ellipse cx="310" cy="220" rx="290" ry="170" fill="#a8743f" stroke="#4a3216" stroke-width="8"/>'
        if lvl >= 1:
            for i in range(26):
                a = i / 26 * math.pi * 2
                b += f'<ellipse cx="{310+math.cos(a)*286:.0f}" cy="{220+math.sin(a)*166:.0f}" rx="26" ry="18" fill="#b8b8c0" stroke="#4a3216" stroke-width="4"/>'
        b += '<ellipse cx="310" cy="220" rx="260" ry="146" fill="url(#water)" stroke="#2a5a7a" stroke-width="5"/>'
        b += shine(220, 160, 90, 14, -8, 0.35) + shine(400, 270, 60, 8, -8, 0.25)
        if lvl == 0:
            b += ('<path d="M220 240 l 50 -10 l 10 20 l -50 8 Z" fill="#6a5a4a" stroke="#4a3216" stroke-width="4"/>'
                  '<ellipse cx="400" cy="200" rx="30" ry="10" fill="#5a6a3a"/>')
            for x in (80, 110, 520, 548):
                b += f'<path d="M{x} 260 q -6 -60 4 -110" stroke="#9a8a4a" stroke-width="7" fill="none" stroke-linecap="round"/>'
        else:
            for x, y in [(190, 260), (420, 170), (360, 290)]:
                b += f'<path d="M{x} {y} m -30 0 a 30 18 0 1 0 60 0 l -30 0 Z" fill="#5ec04a" stroke="#256b12" stroke-width="4"/>'
            b += flower(420, 168, "#ffb3d1", 9)
            for x in (70, 96, 530, 556):
                b += (f'<path d="M{x} 270 q -4 -70 6 -120" stroke="#4f8f1f" stroke-width="7" fill="none" stroke-linecap="round"/>'
                      f'<rect x="{x+1}" y="140" width="12" height="34" rx="6" fill="#8a5a2b"/>')
        if lvl == 2:
            b += ('<rect x="430" y="300" width="160" height="56" fill="#c98035" stroke="#4a3216" stroke-width="6"/>'
                  + "".join(f'<path d="M{x} 300 L{x} 356" stroke="#8a5a2b" stroke-width="4"/>' for x in range(460, 590, 30))
                  + '<rect x="440" y="352" width="14" height="40" fill="#8a5a2b" stroke="#4a3216" stroke-width="4"/>'
                  '<rect x="566" y="352" width="14" height="40" fill="#8a5a2b" stroke="#4a3216" stroke-width="4"/>'
                  + flower(240, 180, "#fff", 10) + flower(300, 250, "#ffb3d1", 10))
        save(f"farm_pond_{lvl}", W, Hh, b, f"assets/farm/pond_{lvl}.png", d)

    # ------------------------------------------------------------- meadow
    for lvl in range(3):
        W, Hh = 580, 400
        d = common_defs + rg("mead", ["#d8c878", "#9be05a", "#8fe05a"][lvl], ["#a8984a", "#5aa828", "#4ca024"][lvl], "50%", "45%", "60%") + \
            lg("hive", "#ffe680", "#e0a020")
        b = '<ellipse cx="290" cy="220" rx="270" ry="160" fill="url(#mead)" stroke="#5a7a2a" stroke-width="6"/>'
        random.seed(11 + lvl)
        if lvl == 0:
            for i in range(16):
                b += weeds(80 + random.random() * 420, 120 + random.random() * 220, 1.2)
            for i in range(10):
                b += grass_tuft(80 + random.random() * 420, 120 + random.random() * 220, 1.0, "#b8a85a")
        else:
            n = 14 if lvl == 1 else 40
            for i in range(10):
                b += grass_tuft(80 + random.random() * 420, 110 + random.random() * 230, 1.0)
            for i in range(n):
                a = random.random() * math.pi * 2
                rr = random.random() ** 0.5
                x, y = 290 + math.cos(a) * 230 * rr, 220 + math.sin(a) * 130 * rr
                c = random.choice(["#ff6b8b", "#ffd23f", "#fff", "#c77dff", "#ff9f1c", "#4cc9f0"])
                b += flower(x, y, c, 9 if lvl == 1 else 11)
        if lvl == 2:  # beehive
            b += ('<path d="M420 120 Q 470 40 520 120 L520 180 L420 180 Z" fill="url(#hive)" stroke="#4a3216" stroke-width="7"/>'
                  '<path d="M424 100 L516 100 M420 130 L520 130 M420 156 L520 156" stroke="#b07a10" stroke-width="5"/>'
                  '<ellipse cx="470" cy="166" rx="12" ry="9" fill="#4a3216"/>'
                  '<rect x="410" y="176" width="120" height="16" rx="5" fill="#a0612a" stroke="#4a3216" stroke-width="5"/>')
        save(f"farm_meadow_{lvl}", W, Hh, b, f"assets/farm/meadow_{lvl}.png", d)

    # ------------------------------------------------------------- shed (сарай / склад)
    for lvl in range(3):
        W, Hh = 440, 380
        d = common_defs + lg("wood", ["#9a8a74", "#d09a5a", "#7fb0d8"][lvl], ["#6a5a44", "#9a6a34", "#4a7aa8"][lvl])
        b = gshadow(220, 330, 200, 30)
        if lvl == 0:
            b += ('<path d="M70 330 L120 200 L330 230 L370 330 Z" fill="url(#wood)" stroke="#4a3216" stroke-width="7" stroke-linejoin="round"/>'
                  '<path d="M90 200 L300 150 L340 200" fill="none" stroke="#6a5a44" stroke-width="18" stroke-linecap="round"/>'
                  '<path d="M150 320 l 120 -60 M 120 300 l 180 10" stroke="#5a4430" stroke-width="12" stroke-linecap="round"/>')
            b += weeds(80, 336, 1.3) + weeds(360, 336, 1.2) + weeds(220, 340, 1.0)
        else:
            b += '<rect x="90" y="160" width="260" height="170" fill="url(#wood)" stroke="#4a3216" stroke-width="8"/>'
            for x in range(110, 350, 26):
                b += f'<path d="M{x} 162 L{x} 328" stroke="#000" stroke-width="3" opacity="0.15"/>'
            b += ('<path d="M66 172 L220 70 L374 172 Z" fill="#8a4a2a" stroke="#4a3216" stroke-width="8" stroke-linejoin="round"/>'
                  '<rect x="180" y="220" width="80" height="110" fill="#6a4020" stroke="#4a3216" stroke-width="7"/>'
                  '<path d="M180 220 L260 330 M260 220 L180 330" stroke="#a0612a" stroke-width="7"/>')
            if lvl == 2:
                b += ('<rect x="10" y="260" width="74" height="70" fill="#c98035" stroke="#4a3216" stroke-width="6"/>'
                      '<path d="M10 260 L84 330 M84 260 L10 330" stroke="#8a5a2b" stroke-width="5"/>'
                      '<rect x="30" y="200" width="56" height="60" fill="#d8a050" stroke="#4a3216" stroke-width="6"/>'
                      '<ellipse cx="390" cy="300" rx="36" ry="40" fill="#a0612a" stroke="#4a3216" stroke-width="6"/>'
                      '<path d="M356 286 L424 286 M356 314 L424 314" stroke="#4a3216" stroke-width="5"/>'
                      '<path d="M200 100 l 40 0 l 0 24 l -40 0 Z" fill="#fff8e6" stroke="#4a3216" stroke-width="4"/>')
        save(f"farm_shed_{lvl}", W, Hh, b, f"assets/farm/shed_{lvl}.png", d)

    # ------------------------------------------------------------- decor: lanterns & flowerbeds
    def lantern(x, base, lit, broken=False):
        if broken:
            return (f'<path d="M{x-60} {base-10} L{x+50} {base-30}" stroke="#4a4a52" stroke-width="12" stroke-linecap="round"/>'
                    f'<rect x="{x+40}" y="{base-50}" width="30" height="34" fill="#5a5a62" stroke="{OL}" stroke-width="4" transform="rotate(30 {x+55} {base-33})"/>')
        s = f'<rect x="{x-6}" y="{base-170}" width="12" height="170" fill="#3a3a48" stroke="{OL}" stroke-width="4"/>'
        if lit:
            s += f'<circle cx="{x}" cy="{base-170}" r="46" fill="#fff6a0" opacity="0.55" filter="url(#glow)"/>'
        s += (f'<path d="M{x-20} {base-190} L{x+20} {base-190} L{x+16} {base-150} L{x-16} {base-150} Z" '
              f'fill="{"#fff3a0" if lit else "#c8d8e0"}" stroke="{OL}" stroke-width="5"/>'
              f'<path d="M{x-26} {base-190} L{x} {base-212} L{x+26} {base-190} Z" fill="#3a3a48" stroke="{OL}" stroke-width="5"/>')
        return s

    for lvl in range(3):
        W, Hh = 460, 320
        d = common_defs
        b = gshadow(230, 280, 200, 30)
        b += f'<ellipse cx="230" cy="250" rx="130" ry="56" fill="#8a5a2b" stroke="{OL}" stroke-width="7"/>'
        if lvl >= 1:
            b += f'<ellipse cx="230" cy="250" rx="130" ry="56" fill="none" stroke="#c8c8d0" stroke-width="14"/>'
            random.seed(5 + lvl)
            n = 9 if lvl == 1 else 22
            for i in range(n):
                a = random.random() * math.pi * 2
                rr = random.random() ** 0.5
                b += flower(230 + math.cos(a) * 100 * rr, 248 + math.sin(a) * 38 * rr,
                            random.choice(["#ff6b8b", "#ffd23f", "#fff", "#c77dff", "#ff9f1c"]), 10)
            if lvl == 2:
                b += bush(230, 236, 34, True)
            b += lantern(60, 290, lvl == 2) + lantern(400, 290, lvl == 2)
        else:
            b += lantern(80, 290, False, True) + weeds(200, 250, 1.3) + weeds(260, 256, 1.1)
        save(f"farm_decor_{lvl}", W, Hh, b, f"assets/farm/decor_{lvl}.png", d)

    # ------------------------------------------------------------- fence segment
    for lvl in range(3):
        W, Hh = 240, 130
        col = ["#8a7a64", "#c98035", "#ffffff"][lvl]
        d = ""
        b = ""
        if lvl == 0:
            b += (f'<rect x="0" y="62" width="150" height="14" fill="{col}" stroke="{OL}" stroke-width="4" transform="rotate(6 0 62)"/>'
                  f'<rect x="20" y="40" width="20" height="80" fill="{col}" stroke="{OL}" stroke-width="4" transform="rotate(-8 30 120)"/>'
                  f'<rect x="130" y="56" width="20" height="64" fill="{col}" stroke="{OL}" stroke-width="4" transform="rotate(12 140 120)"/>'
                  f'<rect x="200" y="96" width="40" height="14" fill="{col}" stroke="{OL}" stroke-width="4"/>')
        else:
            b += (f'<rect x="0" y="50" width="240" height="14" fill="{col}" stroke="{OL}" stroke-width="4"/>'
                  f'<rect x="0" y="86" width="240" height="14" fill="{col}" stroke="{OL}" stroke-width="4"/>')
            for x in ([10, 130] if lvl == 1 else [6, 46, 86, 126, 166, 206]):
                if lvl == 1:
                    b += f'<rect x="{x}" y="30" width="24" height="94" rx="4" fill="#a0612a" stroke="{OL}" stroke-width="4"/>'
                else:
                    b += f'<path d="M{x} 124 L{x} 40 L{x+14} 24 L{x+28} 40 L{x+28} 124 Z" fill="#fff" stroke="{OL}" stroke-width="4"/>'
        save(f"farm_fence_{lvl}", W, Hh, b, f"assets/farm/fence_{lvl}.png", d, (3, 2))

    # ------------------------------------------------------------- windmill (expansion plot)
    d = common_defs + lg("mill", "#fff1d0", "#d8c098", "1", "0") + lg("sail", "#ffffff", "#e0e8f0")
    b = gshadow(220, 540, 180, 30)
    b += ('<path d="M120 540 L160 220 L280 220 L320 540 Z" fill="url(#mill)" stroke="#4a3216" stroke-width="8" stroke-linejoin="round"/>'
          '<path d="M140 230 L220 130 L300 230 Z" fill="#c0392b" stroke="#4a3216" stroke-width="8" stroke-linejoin="round"/>'
          '<path d="M190 540 L190 460 Q 220 430 250 460 L250 540 Z" fill="#8a5a2b" stroke="#4a3216" stroke-width="7"/>'
          '<circle cx="220" cy="330" r="22" fill="url(#glass)" stroke="#4a3216" stroke-width="6"/>'
          '<path d="M140 380 L300 380" stroke="#c8b088" stroke-width="5"/>')
    save("farm_windmill_1", 440, 580, b, "assets/farm/windmill_1.png", d)
    b = ""
    for ang in (0, 90, 180, 270):
        b += (f'<g transform="rotate({ang} 200 200)"><rect x="192" y="20" width="16" height="180" fill="#8a5a2b" stroke="#4a3216" stroke-width="5"/>'
              f'<rect x="208" y="30" width="54" height="150" fill="url(#sail)" stroke="#4a3216" stroke-width="5"/>'
              + "".join(f'<path d="M208 {y} L262 {y}" stroke="#b0b8c8" stroke-width="3"/>' for y in range(60, 180, 30)) + '</g>')
    b += '<circle cx="200" cy="200" r="22" fill="#c0392b" stroke="#4a3216" stroke-width="6"/>'
    save("farm_windmill_blades", 400, 400, b, "assets/farm/windmill_blades.png", d, (4, 3))
    b = gshadow(220, 540, 180, 30)
    b += ('<ellipse cx="220" cy="500" rx="150" ry="50" fill="#a8906a" stroke="#4a3216" stroke-width="7"/>'
          + "".join(f'<ellipse cx="{x}" cy="{y}" rx="30" ry="20" fill="#9a9aa4" stroke="#4a3216" stroke-width="5"/>'
                    for x, y in [(110, 490), (170, 520), (250, 524), (320, 496), (200, 470), (280, 470)])
          + weeds(150, 500, 1.4) + weeds(300, 520, 1.3)
          + '<rect x="210" y="330" width="16" height="170" fill="#8a5a2b" stroke="#4a3216" stroke-width="5"/>'
          '<rect x="130" y="300" width="180" height="90" rx="12" fill="#e7a75a" stroke="#4a3216" stroke-width="7"/>'
          '<circle cx="150" cy="320" r="6" fill="#4a3216"/><circle cx="290" cy="320" r="6" fill="#4a3216"/>')
    save("farm_windmill_0", 440, 580, b, "assets/farm/windmill_0.png", d)

    # ------------------------------------------------------------- animal pen
    for lvl in range(2):
        W, Hh = 620, 400
        d = common_defs + lg("hay", "#ffe680", "#d9a520")
        b = f'<rect x="30" y="80" width="560" height="280" rx="30" fill="{["#b8a86a", "#8fd85a"][lvl]}" stroke="#5a7a2a" stroke-width="6"/>'
        col = "#8a7a64" if lvl == 0 else "#c98035"
        for (x1, y1, x2, y2) in [(30, 80, 590, 80), (30, 360, 590, 360), (30, 80, 30, 360), (590, 80, 590, 360)]:
            if lvl == 0 and y1 == 360:
                x2 = 300
            b += f'<path d="M{x1} {y1-20} L{x2} {y2-20} M{x1} {y1} L{x2} {y2}" stroke="{col}" stroke-width="12" stroke-linecap="round"/>'
        for x in range(30, 600, 80):
            for y in (80, 360):
                if lvl == 0 and y == 360 and x > 300:
                    continue
                b += f'<rect x="{x-9}" y="{y-44}" width="18" height="56" rx="4" fill="#a0612a" stroke="{OL}" stroke-width="4"/>'
        if lvl == 1:
            b += ('<rect x="430" y="120" width="120" height="46" rx="10" fill="#a0612a" stroke="#4a3216" stroke-width="6"/>'
                  '<rect x="440" y="124" width="100" height="18" rx="6" fill="#6fb8e6"/>'
                  '<rect x="70" y="270" width="100" height="70" rx="12" fill="url(#hay)" stroke="#a07010" stroke-width="6"/>'
                  '<path d="M80 292 L160 292 M80 316 L160 316" stroke="#c08a10" stroke-width="4"/>')
        else:
            b += weeds(200, 240, 1.4) + weeds(420, 200, 1.3) + weeds(320, 300, 1.2)
        save(f"farm_pen_{lvl}", W, Hh, b, f"assets/farm/pen_{lvl}.png", d, (3, 2))

    # ------------------------------------------------------------- festival scarecrow (level 10 reward)
    d = common_defs + rg("pump", "#ffb347", "#e0620c") + lg("hat", "#ffe680", "#c89a20")
    b = gshadow(160, 380, 130, 22)
    b += ('<path d="M150 380 L150 120 M90 200 L230 200" stroke="#8a5a2b" stroke-width="14" stroke-linecap="round"/>'
          '<path d="M110 180 L210 180 L224 300 L96 300 Z" fill="#4c8fd6" stroke="#4a3216" stroke-width="7" stroke-linejoin="round"/>'
          '<rect x="140" y="200" width="40" height="40" fill="#e84a3a" stroke="#4a3216" stroke-width="5"/>'
          '<path d="M86 196 L60 230 M234 196 L260 230" stroke="#ffe680" stroke-width="10" stroke-linecap="round"/>'
          '<circle cx="160" cy="132" r="48" fill="url(#pump)" stroke="#a03d05" stroke-width="7"/>'
          '<path d="M140 124 l 10 -12 l 10 12 Z M170 124 l 10 -12 l 10 12 Z M140 150 Q 160 166 180 150" fill="#4a1a10" stroke="#4a1a10" stroke-width="4"/>'
          '<path d="M96 96 L224 96 L196 80 L180 40 L140 40 L124 80 Z" fill="url(#hat)" stroke="#4a3216" stroke-width="6" stroke-linejoin="round"/>'
          '<rect x="138" y="70" width="44" height="10" fill="#e84a3a"/>'
          '<ellipse cx="60" cy="356" rx="44" ry="32" fill="url(#pump)" stroke="#a03d05" stroke-width="6"/>'
          '<ellipse cx="262" cy="362" rx="36" ry="26" fill="url(#pump)" stroke="#a03d05" stroke-width="6"/>'
          '<path d="M60 324 l 4 -12 M262 336 l 4 -12" stroke="#4f8f1f" stroke-width="6" stroke-linecap="round"/>')
    flags = ""
    for i in range(7):
        x = 20 + i * 44
        y = 20 + abs(3 - i) * 8
        c = ["#ff4d6d", "#ffd23f", "#4cc9f0", "#5ed16a", "#ff9f1c", "#c77dff", "#ff4d6d"][i]
        flags += f'<path d="M{x} {y} L{x+36} {y+4} L{x+16} {y+36} Z" fill="{c}" stroke="#4a3216" stroke-width="3"/>'
    b = '<path d="M14 20 Q 160 70 320 20" stroke="#4a3216" stroke-width="3" fill="none"/>' + flags + b
    save("farm_festival", 330, 410, b, "assets/farm/festival.png", d)

    # ------------------------------------------------------------- nature props
    d = common_defs
    save("prop_tree", 300, 340, tree(150, 320, 120, 2), "assets/farm/prop_tree.png", d + rg("appr", "#f00", "#a00"))
    save("prop_tree_dry", 300, 340, f'{gshadow(150, 320, 90, 20)}<path d="M150 320 L150 150 M150 220 L100 160 M150 190 L200 130 M150 250 L190 220" '
         f'stroke="#7a5a34" stroke-width="16" stroke-linecap="round"/>' + bush(150, 140, 50, dry=True), "assets/farm/prop_tree_dry.png", d)
    save("prop_bush", 200, 150, gshadow(100, 130, 80, 14) + bush(100, 100, 44), "assets/farm/prop_bush.png", d)
    save("prop_bush_flowers", 200, 150, gshadow(100, 130, 80, 14) + bush(100, 100, 44, True), "assets/farm/prop_bush_flowers.png", d)
    save("prop_rock", 160, 110, gshadow(80, 92, 64, 12) + '<path d="M20 90 Q 30 30 80 26 Q 136 30 140 90 Z" fill="#b8b8c4" stroke="#4a3216" stroke-width="6"/>'
         + shine(60, 50, 20, 8, -20, 0.5), "assets/farm/prop_rock.png", d)
    fl = "".join(flower(30 + i * 30, 50 + (i % 2) * 14, c, 9) for i, c in enumerate(["#ff6b8b", "#ffd23f", "#fff", "#c77dff"]))
    save("prop_flowers", 150, 90, grass_tuft(40, 86) + grass_tuft(110, 86) + fl, "assets/farm/prop_flowers.png", d, (2, 1))
    save("prop_grass", 100, 60, grass_tuft(50, 58, 1.4), "assets/farm/prop_grass.png", d, (2, 1))
    save("prop_sign", 240, 240, gshadow(120, 226, 70, 12) +
         '<rect x="112" y="110" width="16" height="120" fill="#8a5a2b" stroke="#4a3216" stroke-width="5"/>'
         '<rect x="30" y="40" width="180" height="100" rx="14" fill="#e7a75a" stroke="#4a3216" stroke-width="7"/>'
         '<rect x="96" y="70" width="48" height="42" rx="8" fill="#ffd23f" stroke="#4a3216" stroke-width="6"/>'
         '<path d="M104 72 L104 58 Q 120 36 136 58 L136 72" fill="none" stroke="#4a3216" stroke-width="7"/>',
         "assets/farm/prop_sign.png", d)

    # ------------------------------------------------------------- animals
    d = common_defs + rg("hen", "#ffffff", "#e0d8cc") + rg("cow", "#ffffff", "#ddd8d0") + rg("pig", "#ffd0dc", "#f08aa8") + \
        rg("wool", "#ffffff", "#e8e4dc") + rg("duck", "#fff6a0", "#ffd23f")
    save("animal_chicken", 140, 140,
         gshadow(70, 128, 44, 8) + '<path d="M58 118 L56 132 M80 118 L82 132" stroke="#f29c0c" stroke-width="6" stroke-linecap="round"/>'
         '<ellipse cx="66" cy="88" rx="44" ry="34" fill="url(#hen)" stroke="#4a3216" stroke-width="5"/>'
         '<path d="M24 80 Q 10 56 30 50 Q 30 70 40 74 Z" fill="#fff" stroke="#4a3216" stroke-width="5"/>'
         '<circle cx="98" cy="58" r="22" fill="url(#hen)" stroke="#4a3216" stroke-width="5"/>'
         '<path d="M88 38 q 4 -14 12 -4 q 6 -12 12 2 Z" fill="#ff4d4d" stroke="#7d0c1e" stroke-width="3"/>'
         '<path d="M118 56 L132 62 L118 68 Z" fill="#ffb020" stroke="#8a4a05" stroke-width="3"/>'
         '<circle cx="104" cy="54" r="4" fill="#2a1a10"/><path d="M114 70 q 4 10 -2 12" stroke="#ff4d4d" stroke-width="5" fill="none"/>',
         "assets/farm/animal_chicken.png", d, (3, 2))
    save("animal_duck", 130, 110,
         '<ellipse cx="62" cy="76" rx="46" ry="26" fill="url(#hen)" stroke="#4a3216" stroke-width="5"/>'
         '<path d="M18 70 Q 6 56 24 54 Z" fill="#fff" stroke="#4a3216" stroke-width="4"/>'
         '<circle cx="94" cy="44" r="20" fill="url(#hen)" stroke="#4a3216" stroke-width="5"/>'
         '<path d="M110 42 Q 128 44 126 52 Q 116 56 108 52 Z" fill="#ff9f1c" stroke="#8a4a05" stroke-width="3"/>'
         '<circle cx="98" cy="40" r="4" fill="#2a1a10"/><path d="M40 72 Q 60 64 78 74" stroke="#d8d0c4" stroke-width="5" fill="none"/>',
         "assets/farm/animal_duck.png", d, (2, 2))
    cow = (gshadow(110, 172, 90, 12) +
           '<path d="M50 140 L50 172 M80 146 L80 172 M140 146 L140 172 M170 140 L170 172" stroke="#4a3216" stroke-width="12" stroke-linecap="round"/>'
           '<ellipse cx="110" cy="110" rx="80" ry="48" fill="url(#cow)" stroke="#4a3216" stroke-width="6"/>'
           '<path d="M70 72 Q 90 100 60 120 Q 44 100 50 80 Z M130 90 Q 160 80 160 110 Q 140 130 126 112 Z" fill="#3a3030"/>'
           '<ellipse cx="190" cy="80" rx="34" ry="30" fill="url(#cow)" stroke="#4a3216" stroke-width="6"/>'
           '<ellipse cx="204" cy="98" rx="24" ry="16" fill="#ffb3c6" stroke="#4a3216" stroke-width="4"/>'
           '<circle cx="198" cy="98" r="3" fill="#4a3216"/><circle cx="212" cy="98" r="3" fill="#4a3216"/>'
           '<circle cx="182" cy="72" r="5" fill="#2a1a10"/><circle cx="202" cy="70" r="5" fill="#2a1a10"/>'
           '<path d="M168 56 l -10 -16 M208 52 l 8 -16" stroke="#e7c08a" stroke-width="7" stroke-linecap="round"/>'
           '<path d="M30 100 Q 16 120 24 140" stroke="#4a3216" stroke-width="5" fill="none"/>')
    save("animal_cow", 240, 190, cow, "assets/farm/animal_cow.png", d, (2, 2))
    sheep = (gshadow(100, 150, 74, 10) +
             '<path d="M60 120 L60 150 M140 120 L140 150" stroke="#3a3030" stroke-width="10" stroke-linecap="round"/>'
             + "".join(f'<circle cx="{x}" cy="{y}" r="26" fill="url(#wool)" stroke="#4a3216" stroke-width="5"/>'
                       for x, y in [(60, 80), (96, 66), (132, 80), (70, 108), (112, 110), (140, 104), (90, 92)])
             + '<ellipse cx="166" cy="78" rx="22" ry="26" fill="#3a3030" stroke="#4a3216" stroke-width="4"/>'
             '<circle cx="160" cy="72" r="4" fill="#fff"/><circle cx="174" cy="72" r="4" fill="#fff"/>'
             '<ellipse cx="150" cy="62" rx="12" ry="6" fill="#3a3030" transform="rotate(-30 150 62)"/>')
    save("animal_sheep", 200, 166, sheep, "assets/farm/animal_sheep.png", d, (2, 2))
    pig = (gshadow(90, 128, 70, 10) +
           '<path d="M50 104 L50 128 M120 104 L120 128" stroke="#e07a98" stroke-width="12" stroke-linecap="round"/>'
           '<ellipse cx="86" cy="84" rx="64" ry="40" fill="url(#pig)" stroke="#8a3a52" stroke-width="5"/>'
           '<ellipse cx="148" cy="74" rx="28" ry="26" fill="url(#pig)" stroke="#8a3a52" stroke-width="5"/>'
           '<ellipse cx="166" cy="82" rx="12" ry="10" fill="#f08aa8" stroke="#8a3a52" stroke-width="4"/>'
           '<circle cx="162" cy="82" r="2.5" fill="#8a3a52"/><circle cx="170" cy="82" r="2.5" fill="#8a3a52"/>'
           '<circle cx="146" cy="66" r="4" fill="#2a1a10"/><path d="M134 50 l -6 -14 l 16 6 Z" fill="#f08aa8" stroke="#8a3a52" stroke-width="3"/>'
           '<path d="M22 80 q -12 -6 -6 -16 q 10 4 2 10" stroke="#8a3a52" stroke-width="4" fill="none"/>')
    save("animal_pig", 190, 140, pig, "assets/farm/animal_pig.png", d, (2, 2))

    # ------------------------------------------------------------- UI icons (white glyphs + coloured)
    d = rg("coin", "#fff3a0", "#f2a60c") + rg("star", "#fff6a0", "#ffb000") + rg("stare", "#e8e8f0", "#a8acbc")
    save("ui_coin", 128, 128, '<circle cx="64" cy="64" r="54" fill="url(#coin)" stroke="#a0620a" stroke-width="8"/>'
         '<circle cx="64" cy="64" r="36" fill="none" stroke="#d98a0a" stroke-width="6"/>'
         '<path d="M64 40 L70 56 L88 58 L74 70 L78 88 L64 78 L50 88 L54 70 L40 58 L58 56 Z" fill="#ffe680" stroke="#d98a0a" stroke-width="4" stroke-linejoin="round"/>'
         + shine(44, 40, 16, 8, -40, 0.7), "assets/ui/coin.png", d, (4, 3))

    def star_path(cx, cy, R, r):
        pts = []
        for i in range(10):
            a = math.radians(-90 + i * 36)
            rr = R if i % 2 == 0 else r
            pts.append(f"{cx + math.cos(a) * rr:.1f},{cy + math.sin(a) * rr:.1f}")
        return "M" + " L".join(pts) + " Z"
    save("ui_star", 128, 128, f'<path d="{star_path(64, 68, 58, 26)}" fill="url(#star)" stroke="#b86a00" stroke-width="8" stroke-linejoin="round"/>'
         + shine(46, 52, 12, 7, -40, 0.7), "assets/ui/star.png", d, (4, 3))
    save("ui_star_empty", 128, 128, f'<path d="{star_path(64, 68, 58, 26)}" fill="url(#stare)" stroke="#6a6e80" stroke-width="8" stroke-linejoin="round"/>',
         "assets/ui/star_empty.png", d, (4, 3))
    W = 'fill="#fff" stroke="#fff"'
    icons = {
        "pause": '<rect x="34" y="28" width="22" height="72" rx="8" fill="#fff"/><rect x="72" y="28" width="22" height="72" rx="8" fill="#fff"/>',
        "play": '<path d="M42 26 L104 64 L42 102 Z" fill="#fff" stroke="#fff" stroke-width="10" stroke-linejoin="round"/>',
        "home": '<path d="M20 62 L64 22 L108 62" fill="none" stroke="#fff" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>'
                '<path d="M34 60 L34 104 L56 104 L56 78 L72 78 L72 104 L94 104 L94 60" fill="#fff"/>',
        "back": '<path d="M78 24 L36 64 L78 104" fill="none" stroke="#fff" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/>',
        "close": '<path d="M32 32 L96 96 M96 32 L32 96" stroke="#fff" stroke-width="18" stroke-linecap="round"/>',
        "check": '<path d="M26 66 L54 94 L104 36" fill="none" stroke="#fff" stroke-width="18" stroke-linecap="round" stroke-linejoin="round"/>',
        "lock": '<rect x="28" y="56" width="72" height="56" rx="12" fill="#fff"/><path d="M42 58 L42 44 Q 64 10 86 44 L86 58" fill="none" stroke="#fff" stroke-width="12"/>',
        "music": '<path d="M48 92 L48 30 L100 20 L100 82" fill="none" stroke="#fff" stroke-width="10" stroke-linejoin="round"/>'
                 '<ellipse cx="36" cy="94" rx="18" ry="14" fill="#fff"/><ellipse cx="88" cy="84" rx="18" ry="14" fill="#fff"/>',
        "sound": '<path d="M20 48 L42 48 L70 24 L70 104 L42 80 L20 80 Z" fill="#fff" stroke="#fff" stroke-width="6" stroke-linejoin="round"/>'
                 '<path d="M84 44 Q 100 64 84 84 M94 30 Q 122 64 94 98" fill="none" stroke="#fff" stroke-width="9" stroke-linecap="round"/>',
        "gear": "".join(f'<rect x="56" y="10" width="16" height="28" rx="4" fill="#fff" transform="rotate({a} 64 64)"/>' for a in range(0, 360, 45))
                + '<circle cx="64" cy="64" r="34" fill="#fff"/><circle cx="64" cy="64" r="14" fill="#000" opacity="0.25"/>',
        "shop": '<path d="M26 46 L102 46 L94 110 L34 110 Z" fill="#fff"/><path d="M44 52 L44 36 Q 64 6 84 36 L84 52" fill="none" stroke="#fff" stroke-width="10" stroke-linecap="round"/>',
        "hammer": '<g transform="rotate(-40 64 64)"><rect x="56" y="44" width="16" height="78" rx="7" fill="#fff"/>'
                  '<rect x="26" y="14" width="76" height="36" rx="9" fill="#fff"/></g>',
        "map": '<path d="M16 34 L44 22 L84 36 L112 24 L112 98 L84 110 L44 96 L16 108 Z" fill="#fff"/>'
               '<path d="M44 22 L44 96 M84 36 L84 110" stroke="#000" stroke-width="5" opacity="0.25"/>',
        "paw": '<ellipse cx="64" cy="82" rx="28" ry="24" fill="#fff"/>' + "".join(
            f'<ellipse cx="{x}" cy="{y}" rx="12" ry="15" fill="#fff"/>' for x, y in [(30, 52), (50, 32), (78, 32), (98, 52)]),
        "plus": '<path d="M64 24 L64 104 M24 64 L104 64" stroke="#fff" stroke-width="20" stroke-linecap="round"/>',
        "refresh": '<path d="M96 64 A 32 32 0 1 1 82 38" fill="none" stroke="#fff" stroke-width="14" stroke-linecap="round"/>'
                   '<path d="M70 20 L100 30 L84 58 Z" fill="#fff"/>',
        "trophy": '<path d="M36 22 L92 22 L88 62 Q 64 84 40 62 Z" fill="#fff"/><rect x="56" y="76" width="16" height="20" fill="#fff"/>'
                  '<rect x="38" y="96" width="52" height="14" rx="5" fill="#fff"/>'
                  '<path d="M36 30 Q 14 30 22 50 Q 28 60 40 60 M92 30 Q 114 30 106 50 Q 100 60 88 60" fill="none" stroke="#fff" stroke-width="8"/>',
    }
    for k, v in icons.items():
        save(f"icon_{k}", 128, 128, v, f"assets/ui/icon_{k}.png", "", (3, 2))

    # ------------------------------------------------------------- FX
    save("fx_sparkle", 64, 64, '<path d="M32 2 Q 34 30 62 32 Q 34 34 32 62 Q 30 34 2 32 Q 30 30 32 2 Z" fill="#fff"/>',
         "assets/fx/sparkle.png", "", (0, 0.1))
    save("fx_circle", 64, 64, '<circle cx="32" cy="32" r="30" fill="url(#c)"/>', "assets/fx/soft_circle.png",
         rg("c", "#ffffff", "#ffffff00", "50%", "50%", "50%"), (0, 0.1))
    save("fx_leaf", 48, 48, leaf(6, 24, 36, 12, 0, fill="#7cd040", stroke="#2d6b16", sw=3), "assets/fx/leaf.png", LEAF_DEF, (0, 0.1))
    save("fx_puff", 128, 128, '<circle cx="44" cy="70" r="30" fill="#fff"/><circle cx="80" cy="64" r="36" fill="#fff"/><circle cx="62" cy="44" r="28" fill="#fff"/>',
         "assets/fx/puff.png", "", (0, 0.1))

    # ------------------------------------------------------------- backgrounds
    def scene_bg(name, out, w, h, house=True):
        d = lg("sky", "#7fd4ff", "#d8f3ff") + lg("h1", "#9be05a", "#5cb030") + lg("h2", "#7ccf48", "#3f9b22") + \
            lg("h3", "#b6ea6a", "#78c840") + rg("sun", "#fffbe0", "#ffd23f", "50%", "50%", "50%") + common_defs + \
            rg("sunglow", "#fff6c0", "#fff6c000", "50%", "50%", "50%")
        s = f'<rect width="{w}" height="{h}" fill="url(#sky)"/>'
        s += f'<circle cx="{w*0.8}" cy="{h*0.12}" r="{w*0.32}" fill="url(#sunglow)"/>'
        for i in range(12):
            a = i * 30
            s += (f'<path d="M{w*0.8} {h*0.12} L{w*0.8 + w*0.5*math.cos(math.radians(a)):.0f} {h*0.12 + w*0.5*math.sin(math.radians(a)):.0f} '
                  f'L{w*0.8 + w*0.5*math.cos(math.radians(a+10)):.0f} {h*0.12 + w*0.5*math.sin(math.radians(a+10)):.0f} Z" fill="#fff" opacity="0.12"/>')
        s += f'<circle cx="{w*0.8}" cy="{h*0.12}" r="{w*0.09}" fill="url(#sun)" stroke="#ffb000" stroke-width="6"/>'
        for cx, cy, sc in [(w * 0.18, h * 0.1, 1.0), (w * 0.55, h * 0.2, 0.7), (w * 0.3, h * 0.27, 0.55)]:
            s += f'<g transform="translate({cx} {cy}) scale({sc})" opacity="0.95">' \
                 '<circle cx="-60" cy="10" r="46" fill="#fff"/><circle cx="0" cy="-10" r="60" fill="#fff"/><circle cx="64" cy="12" r="44" fill="#fff"/>' \
                 '<rect x="-100" y="10" width="200" height="46" rx="23" fill="#fff"/></g>'
        s += f'<path d="M0 {h*0.42} Q {w*0.25} {h*0.33} {w*0.55} {h*0.4} T {w} {h*0.36} L{w} {h} L0 {h} Z" fill="url(#h3)"/>'
        s += f'<path d="M0 {h*0.5} Q {w*0.35} {h*0.4} {w*0.7} {h*0.48} T {w} {h*0.46} L{w} {h} L0 {h} Z" fill="url(#h1)"/>'
        if house:
            s += f'<g transform="translate({w*0.08} {h*0.33}) scale({w/1600})">' + \
                 '<rect x="60" y="120" width="160" height="110" fill="#fff1d0" stroke="#4a3216" stroke-width="8"/>' \
                 '<path d="M40 130 L140 50 L240 130 Z" fill="#e84a3a" stroke="#4a3216" stroke-width="8" stroke-linejoin="round"/>' \
                 '<rect x="120" y="170" width="40" height="60" fill="#c0392b" stroke="#4a3216" stroke-width="6"/>' \
                 '<rect x="270" y="90" width="150" height="140" fill="#d8423a" stroke="#4a3216" stroke-width="8"/>' \
                 '<path d="M256 100 L290 50 L345 30 L400 50 L434 100 Z" fill="#4a5a6a" stroke="#4a3216" stroke-width="8" stroke-linejoin="round"/></g>'
            s += f'<g transform="translate({w*0.7} {h*0.30}) scale({w/1800})">' + tree(100, 300, 110, 3) + '</g>'
            s += f'<g transform="translate({w*0.48} {h*0.36}) scale({w/2400})">' + tree(100, 300, 110, 2) + '</g>'
        s += f'<path d="M0 {h*0.6} Q {w*0.3} {h*0.52} {w*0.6} {h*0.58} T {w} {h*0.55} L{w} {h} L0 {h} Z" fill="url(#h2)"/>'
        random.seed(len(name))
        for i in range(40):
            x = random.random() * w
            y = h * 0.62 + random.random() * h * 0.38
            s += grass_tuft(x, y, 1.0 + random.random(), "#5aa828")
        for i in range(26):
            x = random.random() * w
            y = h * 0.6 + random.random() * h * 0.4
            s += flower(x, y, random.choice(["#ff6b8b", "#ffd23f", "#fff", "#c77dff"]), 8 + random.random() * 6)
        save(name, w, h, s, out, d + rg("appr", "#ff7b7b", "#c4102e") + rg("appg", "#d9ff8a", "#4caf26"))

    scene_bg("bg_menu", "assets/bg/menu.png", 1080, 1920, True)
    scene_bg("bg_puzzle", "assets/bg/puzzle.png", 1080, 1920, False)

    # tileable grass texture for farm ground and level map
    random.seed(42)
    s = '<rect width="512" height="512" fill="#7cc848"/>'
    blobs = ""
    for i in range(70):
        x, y, r = random.random() * 512, random.random() * 512, 20 + random.random() * 60
        c = random.choice(["#86d050", "#72be40", "#8ad656", "#6cb83c"])
        for ox in (-512, 0, 512):
            for oy in (-512, 0, 512):
                blobs += f'<circle cx="{x+ox:.0f}" cy="{y+oy:.0f}" r="{r:.0f}" fill="{c}" opacity="0.5"/>'
    s += f'<g filter="url(#soft)">{blobs}</g>'
    for i in range(140):
        x, y = random.random() * 512, random.random() * 512
        for ox in (-512, 0, 512):
            for oy in (-512, 0, 512):
                xx, yy = x + ox, y + oy
                if -20 < xx < 532 and -20 < yy < 532:
                    s += f'<path d="M{xx:.0f} {yy:.0f} l -3 -12 M{xx:.0f} {yy:.0f} l 3 -14 M{xx:.0f} {yy:.0f} l 7 -9" stroke="#5aa830" stroke-width="2.5" stroke-linecap="round"/>'
    save("tex_grass", 512, 512, s, "assets/bg/grass.png", "", blur=14)

    # path textures (tile along a Line2D: x is along the path)
    random.seed(9)
    s = '<rect width="128" height="64" fill="#d8b07a"/>'
    for i in range(40):
        x, y = random.random() * 128, 6 + random.random() * 52
        s += f'<ellipse cx="{x:.0f}" cy="{y:.0f}" rx="{2+random.random()*4:.1f}" ry="{1.5+random.random()*2:.1f}" fill="#b88a50" opacity="0.7"/>'
    save("tex_path_dirt", 128, 64, s, "assets/bg/path_dirt.png", "", (0, 0.1))
    s = '<rect width="128" height="64" fill="#c8b490"/>'
    for (x, y, w, h) in [(2, 3, 40, 26), (46, 3, 36, 26), (86, 3, 40, 26), (-18, 33, 40, 28), (26, 33, 42, 28), (72, 33, 36, 28), (112, 33, 40, 28)]:
        s += f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" fill="#d8d4cc" stroke="#9a8a74" stroke-width="3"/>'
        s += f'<rect x="{x+5}" y="{y+4}" width="{w*0.5:.0f}" height="5" rx="2" fill="#fff" opacity="0.5"/>'
    save("tex_path_stone", 128, 64, s, "assets/bg/path_stone.png", "", (0, 0.1))

    # app icon
    d2 = rg("ib", "#ffe680", "#ffb000", "50%", "35%", "75%") + rg("b", "#ff7b7b", "#d3173a") + LEAF_DEF
    body = ('<path d="M256 452 C 150 410 96 300 116 236 C 132 180 200 170 256 194 C 312 170 380 180 396 236 '
            'C 416 300 362 410 256 452 Z" fill="url(#b)" stroke="#7d0c1e" stroke-width="12" stroke-linejoin="round"/>')
    seeds = "".join(f'<ellipse cx="{x}" cy="{y}" rx="8" ry="13" fill="#ffe28a" stroke="#c9832a" stroke-width="3"/>'
                    for x, y in [(190, 260), (256, 252), (322, 260), (170, 316), (230, 312), (290, 312), (346, 316), (206, 370), (256, 372), (306, 370)])
    crown = "".join(leaf(256, 200, 80, 24, a, sw=8) for a in (-155, -115, -65, -25, -90))
    rays = "".join(f'<path d="M256 256 L{256+400*math.cos(math.radians(a)):.0f} {256+400*math.sin(math.radians(a)):.0f} '
                   f'L{256+400*math.cos(math.radians(a+12)):.0f} {256+400*math.sin(math.radians(a+12)):.0f} Z" fill="#fff" opacity="0.2"/>'
                   for a in range(0, 360, 24))
    save("app_icon", 512, 512, f'<rect width="512" height="512" fill="url(#ib)"/>{rays}<g filter="url(#ds)">{body}{seeds}'
         f'{shine(190, 270, 40, 22, -40)}{crown}</g>', "assets/ui/app_icon.png", d2, (10, 8))
