#!/usr/bin/env python3
"""Generate speedometer + SPEED text icon matching SVG"""

from PIL import Image, ImageDraw, ImageFont
import math

def main():
    size = 512
    img = Image.new('RGB', (size, size), (0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Colors matching SVG
    blue_start = (21, 101, 192)    # #1565C0
    blue_end = (66, 165, 245)      # #42A5F5
    arc_blue = (100, 181, 246)     # #64B5F6
    arc_light = (144, 202, 249)    # #90CAF9
    white = (255, 255, 255)

    # Draw rounded rect background with gradient
    rx = 80
    rect_x, rect_y = 48, 48
    rect_w, rect_h = 416, 416

    for y in range(size):
        for x in range(size):
            inside = True
            if x < rect_x or x >= rect_x + rect_w or y < rect_y or y >= rect_y + rect_h:
                inside = False
            else:
                corners = []
                if x - rect_x < rx and y - rect_y < rx:
                    corners.append((rect_x + rx, rect_y + rx))
                if x - rect_x < rx and size - 1 - y - rect_y < rx:
                    corners.append((rect_x + rx, rect_y + rect_h - rx))
                if size - 1 - x - rect_x < rx and y - rect_y < rx:
                    corners.append((rect_x + rect_w - rx, rect_y + rx))
                if size - 1 - x - rect_x < rx and size - 1 - y - rect_y < rx:
                    corners.append((rect_x + rect_w - rx, rect_y + rect_h - rx))

                for cx, cy in corners:
                    if math.sqrt((x - cx)**2 + (y - cy)**2) > rx:
                        inside = False
                        break

            if inside:
                t = y / size
                r = int(blue_start[0] * (1 - t) + blue_end[0] * t)
                g = int(blue_start[1] * (1 - t) + blue_end[1] * t)
                b = int(blue_start[2] * (1 - t) + blue_end[2] * t)
                img.putpixel((x, y), (r, g, b))

    # Speedometer arc (180 degree semi-circle from 128,280 to 384,280)
    arc_center_x, arc_center_y = 256, 280
    arc_radius = 128
    arc_stroke = 16

    # Draw arc using angle from 180 to 360 degrees
    for angle in range(180, 361):
        rad = math.radians(angle)
        for w in range(-arc_stroke // 2, arc_stroke // 2):
            r = arc_radius + w
            x = int(arc_center_x + r * math.cos(rad))
            y = int(arc_center_y - r * math.sin(rad))  # Negative sin for upward arc
            if 0 <= x < size and 0 <= y < size:
                img.putpixel((x, y), arc_blue)

    # Tick marks (5 circles along the arc)
    ticks = [
        (128, 280, 10, arc_light),      # Left
        (170, 200, 10, arc_light),      # Upper-left
        (256, 160, 12, white),          # Top (white - highest)
        (342, 200, 10, arc_light),      # Upper-right
        (384, 280, 10, arc_light),      # Right
    ]

    for tx, ty, tr, color in ticks:
        for y in range(ty - tr, ty + tr + 1):
            for x in range(tx - tr, tx + tr + 1):
                if (x - tx)**2 + (y - ty)**2 <= tr**2:
                    if 0 <= x < size and 0 <= y < size:
                        img.putpixel((x, y), color)

    # Needle line (from 256,280 to 310,200)
    needle_start_x, needle_start_y = 256, 280
    needle_end_x, needle_end_y = 310, 200
    needle_stroke = 12

    # Bresenham's line algorithm with thickness
    dx = abs(needle_end_x - needle_start_x)
    dy = abs(needle_end_y - needle_start_y)
    sx = 1 if needle_start_x < needle_end_x else -1
    sy = 1 if needle_start_y < needle_end_y else -1
    err = dx - dy

    while True:
        for w in range(-needle_stroke // 2, needle_stroke // 2 + 1):
            # Perpendicular offset
            if dx > dy:
                px, py = 0, w
            else:
                px, py = w if sx > 0 else -w, 0

            nx = needle_start_x + px
            ny = needle_start_y + py
            if 0 <= nx < size and 0 <= ny < size:
                img.putpixel((nx, ny), white)

        if needle_start_x == needle_end_x and needle_start_y == needle_end_y:
            break
        e2 = 2 * err
        if e2 > -dy:
            err -= dy
            needle_start_x += sx
        if e2 < dx:
            err += dx
            needle_start_y += sy

    # Center dot (r=16)
    center_x, center_y = 256, 280
    center_radius = 16
    for y in range(size):
        for x in range(size):
            if (x - center_x)**2 + (y - center_y)**2 <= center_radius**2:
                img.putpixel((x, y), white)

    # SPEED text
    try:
        font_size = 58
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            try:
                font = ImageFont.truetype("/System/Library/Fonts/CoreUI/Avenir Next.ttc", font_size)
            except:
                font = ImageFont.load_default()
    except:
        font = ImageFont.load_default()

    text = "SPEED"
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_x = (size - text_width) // 2
    text_y = 360

    draw.text((text_x, text_y), text, fill=white, font=font)

    # Save
    img.save('app_icon.png', 'PNG')
    print('Icon generated: app_icon.png')

if __name__ == '__main__':
    main()
