#!/usr/bin/env python3
"""Generate a DMG background image with a curved arrow (Docker-style)"""
import math
import struct
import zlib

WIDTH = 660
HEIGHT = 400

def create_png(width, height, pixels):
    def chunk(ct, data):
        c = ct + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    raw = b''
    for y in range(height):
        raw += b'\x00'
        for x in range(width):
            i = (y * width + x) * 4
            raw += bytes(pixels[i:i+4])
    return (b'\x89PNG\r\n\x1a\n'
            + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(raw, 9))
            + chunk(b'IEND', b''))

def set_pixel_blend(px, x, y, r, g, b, a=255):
    if 0 <= x < WIDTH and 0 <= y < HEIGHT:
        i = (y * WIDTH + x) * 4
        sa = a / 255.0
        da = px[i+3] / 255.0
        oa = sa + da * (1 - sa)
        if oa > 0:
            px[i]   = int((r * sa + px[i]   * da * (1-sa)) / oa)
            px[i+1] = int((g * sa + px[i+1] * da * (1-sa)) / oa)
            px[i+2] = int((b * sa + px[i+2] * da * (1-sa)) / oa)
            px[i+3] = int(oa * 255)

def draw_dot(px, cx, cy, radius, r, g, b, a=255):
    for y in range(max(0, int(cy-radius-2)), min(HEIGHT, int(cy+radius+2))):
        for x in range(max(0, int(cx-radius-2)), min(WIDTH, int(cx+radius+2))):
            dist = math.hypot(x - cx, y - cy)
            if dist <= radius + 0.7:
                alpha = min(1.0, max(0, radius + 0.7 - dist))
                set_pixel_blend(px, x, y, r, g, b, int(a * alpha))

def bezier(t, p0, p1, p2, p3):
    u = 1 - t
    return (u**3*p0[0] + 3*u**2*t*p1[0] + 3*u*t**2*p2[0] + t**3*p3[0],
            u**3*p0[1] + 3*u**2*t*p1[1] + 3*u*t**2*p2[1] + t**3*p3[1])

def fill_triangle(px, ax, ay, bx, by, cx, cy, r, g, b, a):
    min_y = max(0, int(min(ay, by, cy)))
    max_y = min(HEIGHT - 1, int(max(ay, by, cy)))
    for y in range(min_y, max_y + 1):
        xs = []
        for (x0, y0, x1, y1) in [(ax,ay,bx,by),(bx,by,cx,cy),(cx,cy,ax,ay)]:
            if abs(y1 - y0) < 0.001:
                if abs(y - y0) < 1: xs.extend([x0, x1])
            elif (y0 <= y <= y1) or (y1 <= y <= y0):
                t = (y - y0) / (y1 - y0)
                xs.append(x0 + t * (x1 - x0))
        if len(xs) >= 2:
            xs.sort()
            for x in range(max(0, int(xs[0])), min(WIDTH, int(xs[-1]) + 1)):
                set_pixel_blend(px, x, y, r, g, b, a)

def main():
    px = [0] * (WIDTH * HEIGHT * 4)

    # Background: clean white with very subtle gradient
    for y in range(HEIGHT):
        for x in range(WIDTH):
            i = (y * WIDTH + x) * 4
            v = int(255 - (y / HEIGHT) * 10)
            px[i] = v; px[i+1] = v; px[i+2] = v; px[i+3] = 255

    # Arrow color
    cr, cg, cb = 30, 30, 55

    # DMG icon positions (Finder coords, top-left origin):
    #   ClipStash.app center: (170, 220)
    #   Applications center:  (490, 220)
    # Icon size: 128px, so edges are ±64px from center
    #
    # Arrow: start from right of app icon, end at left of Applications
    # In background image coords (same as Finder: top-left origin):
    start_x = 250    # right edge of ClipStash icon area
    start_y = 210    # slightly above center
    end_x   = 420    # left edge of Applications icon area
    end_y   = 210

    # Bezier control points: gentle downward swoop
    p0 = (start_x, start_y)
    p1 = (start_x + 50, start_y + 90)   # pull down
    p2 = (end_x - 50,   end_y + 90)     # pull down
    p3 = (end_x, end_y)

    # Draw curve with thick anti-aliased line
    steps = 300
    for i in range(steps):
        t = i / steps
        x0, y0 = bezier(t, p0, p1, p2, p3)
        x1, y1 = bezier((i+1)/steps, p0, p1, p2, p3)
        draw_dot(px, x0, y0, 2.5, cr, cg, cb, 210)

    # Arrowhead at end pointing right-upward
    near = bezier(0.95, p0, p1, p2, p3)
    tip = bezier(1.0, p0, p1, p2, p3)
    angle = math.atan2(tip[1] - near[1], tip[0] - near[0])

    head_len = 18
    spread = math.radians(30)
    lx = tip[0] - head_len * math.cos(angle - spread)
    ly = tip[1] - head_len * math.sin(angle - spread)
    rx = tip[0] - head_len * math.cos(angle + spread)
    ry = tip[1] - head_len * math.sin(angle + spread)

    fill_triangle(px, tip[0], tip[1], lx, ly, rx, ry, cr, cg, cb, 210)

    with open('dmg-background.png', 'wb') as f:
        f.write(create_png(WIDTH, HEIGHT, px))
    print("Created dmg-background.png")

if __name__ == '__main__':
    main()
