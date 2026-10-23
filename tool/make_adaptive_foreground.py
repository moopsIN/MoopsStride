"""Cut the round badge out of the square icon and place it in the adaptive
icon safe zone, on transparency. Pure stdlib (no Pillow available)."""
import sys, zlib, struct, math

src, dst = sys.argv[1], sys.argv[2]

def read_png(path):
    d = open(path, 'rb').read(); i = 8; idat = b''
    while i < len(d):
        n, t = struct.unpack('>I4s', d[i:i+8]); c = d[i+8:i+8+n]; i += 12 + n
        if t == b'IHDR': w, h, bd, ct = struct.unpack('>IIBB', c[:10])
        if t == b'IDAT': idat += c
    bpp = {2: 3, 6: 4}[ct]; raw = zlib.decompress(idat); stride = w * bpp
    out = bytearray(w * h * bpp); prev = bytearray(stride); p = 0
    for y in range(h):
        f = raw[p]; line = bytearray(raw[p+1:p+1+stride]); p += 1 + stride
        for x in range(stride):
            a = line[x-bpp] if x >= bpp else 0; b = prev[x]; c = prev[x-bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa = abs(b - c); pb = abs(a - c); pc = abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        out[y*stride:(y+1)*stride] = line; prev = line
    return w, h, bpp, out

def write_png(path, w, h, rgba):
    raw = b''.join(b'\x00' + bytes(rgba[y*w*4:(y+1)*w*4]) for y in range(h))
    def chunk(t, data): return struct.pack('>I', len(data)) + t + data + struct.pack('>I', zlib.crc32(t + data) & 0xffffffff)
    png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) \
        + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(png)

w, h, bpp, px = read_png(src)
bg = px[0:3]
def is_bg(x, y):
    i = (y * w + x) * bpp
    return all(abs(px[i+k] - bg[k]) < 24 for k in range(3))

# Circle extent from the non-background bounding box.
xs = [x for x in range(0, w, 2) for y in range(0, h, 8) if not is_bg(x, y)]
ys = [y for y in range(0, h, 2) for x in range(0, w, 8) if not is_bg(x, y)]
cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
r = max(max(xs) - min(xs), max(ys) - min(ys)) / 2 + 1
print(f'source bg={tuple(bg)} centre=({cx:.0f},{cy:.0f}) radius={r:.0f}')

OUT = 1024
# flutter_launcher_icons insets the foreground by 16% per side (it spans 68%
# of the 108 dp layer), so 0.88 here lands at ~60%: inside the 66 dp safe zone.
target_d = OUT * 0.88
scale = (2 * r) / target_d     # source px per output px
out = bytearray(OUT * OUT * 4)
for oy in range(OUT):
    sy = cy + (oy + 0.5 - OUT / 2) * scale
    for ox in range(OUT):
        sx = cx + (ox + 0.5 - OUT / 2) * scale
        dist = math.hypot(sx - cx, sy - cy)
        alpha = max(0.0, min(1.0, (r - dist) / (1.5 * scale) + 0.5))
        if alpha <= 0: continue
        # Bilinear sample.
        x0 = min(max(int(sx - 0.5), 0), w - 2); y0 = min(max(int(sy - 0.5), 0), h - 2)
        fx = min(max(sx - 0.5 - x0, 0), 1); fy = min(max(sy - 0.5 - y0, 0), 1)
        o = (oy * OUT + ox) * 4
        for k in range(3):
            def p(x, y): return px[(y * w + x) * bpp + k]
            top = p(x0, y0) * (1 - fx) + p(x0 + 1, y0) * fx
            bot = p(x0, y0 + 1) * (1 - fx) + p(x0 + 1, y0 + 1) * fx
            out[o + k] = int(top * (1 - fy) + bot * fy + 0.5)
        out[o + 3] = int(alpha * 255 + 0.5)
write_png(dst, OUT, OUT, out)
print('wrote', dst, f'#{bg[0]:02X}{bg[1]:02X}{bg[2]:02X}')
