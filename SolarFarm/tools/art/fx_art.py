"""Effect textures (glows, rings, stars, confetti, beams) and the ice tile."""
import math


def generate(save, g):
    rg = g["rg"]

    def radial(id_, stops):
        s = "".join(f'<stop offset="{o}" stop-color="{c}" stop-opacity="{a}"/>' for o, c, a in stops)
        return f'<radialGradient id="{id_}" cx="50%" cy="50%" r="50%">{s}</radialGradient>'

    save("fx_glow", 128, 128, '<circle cx="64" cy="64" r="64" fill="url(#g)"/>', "assets/fx/glow.png",
         radial("g", [(0, "#fff", 1), (0.25, "#fff", 0.75), (0.6, "#fff", 0.22), (1, "#fff", 0)]), (0, 0.1))
    save("fx_ring", 256, 256, '<circle cx="128" cy="128" r="128" fill="url(#g)"/>', "assets/fx/ring.png",
         radial("g", [(0, "#fff", 0), (0.62, "#fff", 0), (0.8, "#fff", 1), (0.88, "#fff", 0.6), (1, "#fff", 0)]), (0, 0.1))
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = 30 if i % 2 == 0 else 13
        pts.append(f"{32 + math.cos(a) * r:.1f},{33 + math.sin(a) * r:.1f}")
    save("fx_star", 64, 64, f'<path d="M{" L".join(pts)} Z" fill="#fff" stroke="#fff" stroke-width="3" stroke-linejoin="round"/>',
         "assets/fx/star.png", "", (0, 0.1))
    save("fx_confetti", 24, 40, '<rect x="2" y="2" width="20" height="36" rx="6" fill="#fff"/>', "assets/fx/confetti.png", "", (0, 0.1))
    save("fx_beam", 256, 64, '<rect x="0" y="0" width="256" height="64" fill="url(#b)"/>', "assets/fx/beam.png",
         '<linearGradient id="b" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity="0"/>'
         '<stop offset="0.38" stop-color="#fff" stop-opacity="0.55"/><stop offset="0.5" stop-color="#fff" stop-opacity="1"/>'
         '<stop offset="0.62" stop-color="#fff" stop-opacity="0.55"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>',
         (0, 0.1))
    save("fx_shard", 32, 32, '<path d="M4 16 L16 2 L28 14 L14 30 Z" fill="#fff"/>', "assets/fx/shard.png", "", (0, 0.1))
    # Light motes floating over the puzzle background.
    save("fx_mote", 48, 48, '<circle cx="24" cy="24" r="24" fill="url(#g)"/>', "assets/fx/mote.png",
         radial("g", [(0, "#fffbe0", 0.95), (0.4, "#fff3b0", 0.5), (1, "#fff3b0", 0)]), (0, 0.1))

    # Ice layer under pieces: frosted rounded tile, translucent.
    for hp, op in [(1, 0.5), (2, 0.72)]:
        d = ('<linearGradient id="ice" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#e8fbff"/>'
             '<stop offset="0.5" stop-color="#9fe3ff"/><stop offset="1" stop-color="#5cc2f2"/></linearGradient>')
        cracks = ""
        if hp == 2:
            cracks = ('<path d="M40 60 L90 100 L80 150 M170 40 L150 110 L200 160 M60 200 L120 170 L190 210" '
                      'stroke="#ffffff" stroke-width="6" fill="none" stroke-linecap="round" opacity="0.8"/>')
        body = (f'<rect x="8" y="8" width="240" height="240" rx="44" fill="url(#ice)" opacity="{op}" '
                f'stroke="#ffffff" stroke-width="12" stroke-opacity="0.95"/>'
                '<rect x="20" y="20" width="216" height="216" rx="36" fill="none" stroke="#7fd3f7" stroke-width="5" opacity="0.9"/>'
                '<path d="M30 70 Q 40 30 80 26" stroke="#fff" stroke-width="14" fill="none" stroke-linecap="round" opacity="0.85"/>'
                '<circle cx="200" cy="200" r="10" fill="#fff" opacity="0.7"/><circle cx="215" cy="175" r="5" fill="#fff" opacity="0.7"/>'
                f'{cracks}')
        save(f"ice_{hp}", 256, 256, body, f"assets/tiles/ice_{hp}.png", d, (0, 0.1))
