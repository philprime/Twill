"""Build the original, unhinted OpenType fixture using only Python's standard library."""
import math
import pathlib
import struct


def u16(*values):
    return struct.pack(">" + "H" * len(values), *values)


def i16(*values):
    return struct.pack(">" + "h" * len(values), *values)


def u32(*values):
    return struct.pack(">" + "I" * len(values), *values)


def polygon(points):
    if not points:
        return b""
    xs, ys = zip(*points)
    result = i16(1, min(xs), min(ys), max(xs), max(ys))
    result += u16(len(points) - 1, 0) + bytes([1] * len(points))
    result += i16(xs[0], *(xs[i] - xs[i - 1] for i in range(1, len(xs))))
    result += i16(ys[0], *(ys[i] - ys[i - 1] for i in range(1, len(ys))))
    return result


def padded(data):
    return data + bytes((-len(data)) % 4)


def checksum(data):
    data = padded(data)
    return sum(struct.unpack(">" + "I" * (len(data) // 4), data)) & 0xFFFFFFFF


# Missing glyph, space, A, B, f, i, and the fi ligature.
glyphs = [
    [(0, 0), (500, 0), (500, 700), (0, 700)],
    [],
    [(50, 0), (550, 0), (300, 700)],
    [(0, 0), (500, 0), (500, 700), (0, 700)],
    [(-50, -200), (250, -200), (250, 700), (-50, 700)],
    [(200, 0), (350, 0), (350, 500), (200, 500)],
    [(0, 0), (800, 0), (800, 700), (0, 700)],
]
glyf = b""
locations = []
for points in glyphs:
    locations.append(len(glyf))
    glyf += padded(polygon(points))
locations.append(len(glyf))

head = u32(0x10000, 0x10000, 0, 0x5F0F3CF5) + u16(0, 1000)
head += bytes(16) + i16(-50, -200, 800, 700) + u16(0, 8) + i16(2, 1, 0)
assert len(head) == 54
hhea = u32(0x10000) + i16(800, -200, 200) + u16(900)
hhea += i16(-50, 0, 800, 1, 0, 0) + bytes(8) + i16(0) + u16(len(glyphs))
assert len(hhea) == 36

characters = [(32, 1), (65, 2), (66, 3), (102, 4), (105, 5), (65535, 0)]
count = len(characters)
power = 2 ** int(math.log2(count))
cmap = u16(4, 16 + count * 8, 0, count * 2, power * 2, int(math.log2(power)), count * 2 - power * 2)
cmap += u16(*(character for character, _ in characters)) + u16(0)
cmap += u16(*(character for character, _ in characters))
cmap += u16(*((glyph - character) % 65536 for character, glyph in characters)) + bytes(count * 2)
cmap = u16(0, 1, 3, 1) + u32(12) + cmap

# Standard liga feature: f + i -> fi, with a narrower advance than two characters.
script = u16(1) + b"DFLT" + u16(8) + u16(4, 0, 0, 65535, 1, 0)
feature = u16(1) + b"liga" + u16(8) + u16(0, 1, 0)
substitution = u16(1, 18, 1, 8, 1, 4, 6, 2, 5, 1, 1, 4)
lookup = u16(1, 4, 4, 0, 1, 8) + substitution
name = "TwillTest-Regular".encode("utf-16-be")
tables = {
    b"GSUB": u32(0x10000) + u16(10, 10 + len(script), 10 + len(script) + len(feature)) + script + feature + lookup,
    b"cmap": cmap,
    b"glyf": glyf,
    b"head": head,
    b"hhea": hhea,
    b"hmtx": b"".join(u16(900 if i == 6 else 600) + i16(min((x for x, _ in points), default=0)) for i, points in enumerate(glyphs)),
    b"loca": u32(*locations),
    b"maxp": u32(0x10000) + u16(len(glyphs), 4, 1) + bytes(24),
    b"name": u16(0, 1, 18, 3, 1, 0x409, 6, len(name), 0) + name,
    b"post": u32(0x30000) + bytes(28),
}
count = len(tables)
power = 2 ** int(math.log2(count))
header = u32(0x10000) + u16(count, power * 16, int(math.log2(power)), count * 16 - power * 16)
directory = b""
body = b""
head_offset = 0
for tag, data in sorted(tables.items()):
    offset = len(header) + 16 * count + len(body)
    directory += tag + u32(checksum(data), offset, len(data))
    if tag == b"head":
        head_offset = offset
    body += padded(data)
font = bytearray(header + directory + body)
struct.pack_into(">I", font, head_offset + 8, (0xB1B0AFBA - checksum(font)) & 0xFFFFFFFF)
pathlib.Path(__file__).with_name("TwillTest.ttf").write_bytes(font)
