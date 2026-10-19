import CHarfBuzz

/// Owns the native font reference, which in turn retains its face and mapped file.
/// Native handles never leave the main-actor renderer that owns this object.
final class HarfBuzzFont {
    private let handle: OpaquePointer
    private static let subpixelScale = 64.0
    private static let syntheticBoldStrength: Float = 0.03

    init?(location: FontLocation) {
        guard let blob = hb_blob_create_from_file_or_fail(location.path) else { return nil }
        defer { hb_blob_destroy(blob) }
        guard hb_face_count(blob) > 0 else { return nil }
        var selectedFace: OpaquePointer?
        for index in 0..<hb_face_count(blob) {
            guard let face = hb_face_create_or_fail(blob, index) else { continue }
            if location.postScriptName == nil || Self.postScriptName(face) == location.postScriptName {
                selectedFace = face
                break
            }
            hb_face_destroy(face)
        }
        guard let face = selectedFace ?? hb_face_create_or_fail(blob, 0) else { return nil }
        defer { hb_face_destroy(face) }
        guard hb_face_get_glyph_count(face) > 0 else { return nil }
        guard let font = hb_font_create(face) else { return nil }
        hb_ot_font_set_funcs(font)
        handle = font
    }

    deinit {
        hb_font_destroy(handle)
    }

    func layout(_ text: String, style: TextStyle) -> TextLayout? {
        let scale = (style.size * Self.subpixelScale).rounded()
        guard scale >= 1, scale <= Double(Int32.max), text.utf8.count <= Int(Int32.max) else { return nil }
        hb_font_set_scale(handle, Int32(scale), Int32(scale))
        let bold: Float = style.weight == .bold ? Self.syntheticBoldStrength : 0
        hb_font_set_synthetic_bold(handle, bold, bold, 1)
        guard let buffer = hb_buffer_create() else { return nil }
        defer { hb_buffer_destroy(buffer) }
        text.withCString { hb_buffer_add_utf8(buffer, $0, Int32(text.utf8.count), 0, Int32(text.utf8.count)) }
        hb_buffer_guess_segment_properties(buffer)
        hb_shape(handle, buffer, nil, 0)
        guard hb_buffer_allocation_successful(buffer) != 0 else { return nil }
        var count: UInt32 = 0
        guard let glyphs = hb_buffer_get_glyph_infos(buffer, &count),
            let positions = hb_buffer_get_glyph_positions(buffer, nil),
            let draw = hb_raster_draw_create_or_fail()
        else { return nil }
        defer { hb_raster_draw_destroy(draw) }

        var extents = hb_font_extents_t()
        hb_font_get_h_extents(handle, &extents)
        let baseline = Double(extents.ascender) / Self.subpixelScale
        let height =
            (Double(extents.ascender) - Double(extents.descender) + Double(extents.line_gap)) / Self.subpixelScale
        hb_raster_draw_set_scale_factor(draw, Float(Self.subpixelScale), Float(Self.subpixelScale))
        var penX = 0.0
        var penY = 0.0
        for index in 0..<Int(count) {
            let position = positions[index]
            // HarfBuzz uses a baseline origin with y upward. Canvas pixels use y downward.
            hb_raster_draw_set_transform(
                draw, 1, 0, 0, -1,
                Float(penX + Double(position.x_offset)),
                Float(baseline * Self.subpixelScale - penY - Double(position.y_offset)))
            hb_raster_draw_glyph(draw, handle, glyphs[index].codepoint)
            penX += Double(position.x_advance)
            penY += Double(position.y_advance)
        }
        guard let image = hb_raster_draw_render(draw) else { return nil }
        defer { hb_raster_image_destroy(image) }
        return TextLayout(
            width: abs(penX) / Self.subpixelScale, height: max(0, height), firstBaseline: baseline,
            bitmap: Self.bitmap(image))
    }

    private static func bitmap(_ image: OpaquePointer) -> TextBitmap {
        var bounds = hb_raster_extents_t()
        hb_raster_image_get_extents(image, &bounds)
        let width = Int(bounds.width)
        let rows = Int(bounds.height)
        var coverage: [UInt8] = []
        if width > 0, rows > 0, let bytes = hb_raster_image_get_buffer(image) {
            coverage.reserveCapacity(width * rows)
            for row in 0..<rows {
                coverage.append(contentsOf: UnsafeBufferPointer(start: bytes + row * Int(bounds.stride), count: width))
            }
        }
        return TextBitmap(
            width: width, height: rows, originX: Double(bounds.x_origin), originY: Double(bounds.y_origin),
            coverage: coverage)
    }

    private static func postScriptName(_ face: OpaquePointer) -> String? {
        var length: UInt32 = 0
        let nameID = HB_OT_NAME_ID_POSTSCRIPT_NAME.rawValue
        let count = hb_ot_name_get_utf8(face, nameID, nil, &length, nil)
        var bytes = Array(repeating: CChar(0), count: Int(count) + 1)
        length = UInt32(bytes.count)
        hb_ot_name_get_utf8(face, nameID, nil, &length, &bytes)
        return String(validating: bytes.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
