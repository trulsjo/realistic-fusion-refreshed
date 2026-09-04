"""Probe, not a gate: measures where a sprite sheet's opaque pixels land on the tile grid.

For each body/shadow pair below it prints the alpha bounding box and alpha-weighted centroid in
tiles relative to the entity origin (shift applied, 64 px per tile at scale 0.5), the shadow
sheet's RGB and alpha statistics, and the mean luminance of the body's left and right thirds.
Findings are read in docs/research/factorio-render-camera.md (#239). Needs pillow and numpy; run
from the repository root. Reads vanilla 2.0.77 sheets from $FACTORIO_DATA (default: the Steam
install on this machine) and Krastorio 2 sheets from the assets mod.
Exit 0 means it ran, not that any number is the hoped-for one.
"""
import os, numpy as np
from PIL import Image
K2 = os.path.join("realistic-fusion-refreshed-assets", "graphics", "krastorio-2", "buildings")
VAN = os.path.join(os.environ.get("FACTORIO_DATA", r"D:\SteamLibrary\steamapps\common\Factorio\data"), "base", "graphics", "entity")
def frame(path, w, h, idx=0, line_length=None):
    im = np.asarray(Image.open(path).convert("RGBA"))
    ll = line_length or max(1, im.shape[1] // w)
    x0 = (idx % ll) * w; y0 = (idx // ll) * h
    return im[y0:y0+h, x0:x0+w]
def stats(name, path, w, h, shift, scale=0.5, idx=0, ll=None, shadow=False, thr=8):
    f = frame(path, w, h, idx, ll)
    a = f[..., 3]
    m = a > thr
    ys, xs = np.nonzero(m)
    if len(xs) == 0: print(name, "empty"); return
    def tx(px): return (px - w/2) * scale / 32 + shift[0]
    def ty(py): return (py - h/2) * scale / 32 + shift[1]
    wts = a[m].astype(float)
    cx = (xs*wts).sum()/wts.sum(); cy = (ys*wts).sum()/wts.sum()
    line = f"{name:34s} bbox tiles x[{tx(xs.min()):+.2f},{tx(xs.max()+1):+.2f}] y[{ty(ys.min()):+.2f},{ty(ys.max()+1):+.2f}]  centroid ({tx(cx):+.2f},{ty(cy):+.2f})"
    if shadow:
        rgb = f[..., :3][m]
        line += f"  | rgb mean {rgb.mean(axis=0).round(1)} max {rgb.max(axis=0)}  alpha max {a.max()} p50 {np.percentile(a[m],50):.0f} p95 {np.percentile(a[m],95):.0f}"
    else:
        # brightness of left vs right third of bbox (lit side hint)
        lum = f[..., :3].mean(axis=2)
        x1, x2 = xs.min(), xs.max()
        third = (x2-x1)//3
        L = lum[m & (np.arange(w)[None,:] < x1+third)].mean(); R = lum[m & (np.arange(w)[None,:] > x2-third)].mean()
        line += f"  | lum left {L:.0f} right {R:.0f}"
    print(line)
def bp(x, y): return (x/32, y/32)
print("== vanilla 2.0.77 (all scale 0.5)")
stats("steel-chest body 1x1", VAN+r"\steel-chest\steel-chest.png", 64, 80, bp(-0.25,-0.5))
stats("steel-chest shadow", VAN+r"\steel-chest\steel-chest-shadow.png", 110, 46, bp(12.25,8), shadow=True)
for d in range(4):
    stats(f"big-pole body dir{d}", VAN+r"\big-electric-pole\big-electric-pole.png", 148, 312, bp(0,-51), idx=d, ll=4)
    stats(f"big-pole shadow dir{d}", VAN+r"\big-electric-pole\big-electric-pole-shadow.png", 374, 94, bp(60,0), idx=d, ll=4, shadow=True)
stats("steam-turbine H body 5x3", VAN+r"\steam-turbine\steam-turbine-H.png", 320, 245, bp(0,-2.75), ll=4)
stats("steam-turbine H shadow", VAN+r"\steam-turbine\steam-turbine-H-shadow.png", 435, 150, bp(28.5,18), ll=4, shadow=True)
stats("steam-turbine V body 3x5", VAN+r"\steam-turbine\steam-turbine-V.png", 217, 374, bp(4.75,0), ll=4)
stats("steam-turbine V shadow", VAN+r"\steam-turbine\steam-turbine-V-shadow.png", 302, 260, bp(39.5,24.5), ll=4, shadow=True)
for d,(bw,bh,bs,sw,sh,ss) in dict(N=(269,221,bp(-1.25,5.25),274,164,bp(20.5,9)), E=(216,301,bp(-3,1.25),184,194,bp(30,9.5)),
                                  S=(260,192,bp(4,13),311,131,bp(29.75,15.75)), W=(196,273,bp(1.5,7.75),206,218,bp(19.5,6.5))).items():
    stats(f"boiler {d} body", VAN+rf"\boiler\boiler-{d}-idle.png", bw, bh, bs)
    stats(f"boiler {d} shadow", VAN+rf"\boiler\boiler-{d}-shadow.png", sw, sh, ss, shadow=True)
print("== Krastorio 2 sheets in repo (all scale 0.5)")
stats("reactor body 15x15", K2+r"\reactor\reactor.png", 1100, 1100, (1.01,0))
stats("reactor shadow", K2+r"\reactor\reactor-shadow.png", 1100, 1100, (1.01,0), shadow=True)
stats("aneutronic body 10x10", K2+r"\aneutronic-reactor\aneutronic-reactor.png", 660, 706, (0,-0.5))
stats("aneutronic shadow", K2+r"\aneutronic-reactor\aneutronic-reactor-shadow.png", 724, 630, (0.57,0.27), shadow=True)
stats("brine body 5x5", K2+r"\brine-concentrator\brine-concentrator.png", 460, 520, (0,-0.2))
stats("brine shadow", K2+r"\brine-concentrator\brine-concentrator-shadow.png", 498, 438, (0.33,0.32), shadow=True)
stats("composite-tank body 3x3", K2+r"\composite-tank\composite-tank.png", 256, 256, (0,0))
stats("composite-tank shadow", K2+r"\composite-tank\composite-tank-shadow.png", 256, 256, (0.152,0), shadow=True)
stats("deut-extractor body 5x5", K2+r"\deuterium-extractor\deuterium-extractor.png", 380, 380, (0,0))
stats("deut-extractor shadow", K2+r"\deuterium-extractor\deuterium-extractor-shadow.png", 380, 380, (0,0), shadow=True)
stats("electrolyser body 5x5", K2+r"\electrolyser\electrolyser.png", 380, 380, (0,0))
stats("electrolyser shadow", K2+r"\electrolyser\electrolyser-shadow.png", 380, 380, (0,0), shadow=True)
stats("gas-mixer body 5x5", K2+r"\gas-mixer\gas-mixer.png", 451, 535, (0,-0.48))
stats("gas-mixer shadow", K2+r"\gas-mixer\gas-mixer-shadow.png", 516, 458, (0.33,0.32), shadow=True)
stats("hc-exchanger body 7x7", K2+r"\hc-exchanger\hc-exchanger.png", 462, 500, (-0.1,-0.2))
stats("hc-exchanger shadow", K2+r"\hc-exchanger\hc-exchanger-shadow.png", 504, 444, (0.23,0.24), shadow=True)
stats("hc-turbine H body 7x5", K2+r"\hc-turbine\hc-turbine-H.png", 469, 270, (0,-0.2), ll=2)
stats("hc-turbine H shadow", K2+r"\hc-turbine\hc-turbine-shadow-H.png", 514, 225, (0.575,0.25), ll=3, shadow=True)
stats("hc-turbine V body 5x7", K2+r"\hc-turbine\hc-turbine-V.png", 330, 500, (0.26,0), ll=6)
stats("hc-turbine V shadow", K2+r"\hc-turbine\hc-turbine-shadow-V.png", 350, 425, (0.48,0.36), ll=6, shadow=True)
stats("heater body 3x3", K2+r"\heater\heater.png", 244, 268, (-5/32,-4.5/32), ll=4)
stats("heater shadow", K2+r"\heater\heater-shadow.png", 350, 219, (31.5/32,10.75/32), ll=4, shadow=True)
stats("lithium body 7x7?", K2+r"\lithium-extractor\lithium-extractor.png", 512, 512, (0,0), ll=6)
stats("lithium shadow", K2+r"\lithium-extractor\lithium-extractor-shadow.png", 512, 512, (0,0), shadow=True)
