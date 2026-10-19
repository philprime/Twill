import CHarfBuzz
import Testing

@Suite("Native font dependencies")
struct NativeFontDependencyTests {
    @Test("HarfBuzz retains its built-in Unicode data without external libraries")
    func unicodeData() {
        // -- Arrange --
        let unicode = hb_unicode_funcs_get_default()

        // -- Act --
        let script = hb_unicode_script(unicode, 0x0041)
        let combiningClass = hb_unicode_combining_class(unicode, 0x0301)

        // -- Assert --
        #expect(script == HB_SCRIPT_LATIN)
        #expect(combiningClass == HB_UNICODE_COMBINING_CLASS_ABOVE)
    }

    @Test("The embedded raster module produces tightly placed alpha coverage")
    func rasterization() throws {
        // -- Arrange --
        let draw = try #require(hb_raster_draw_create_or_fail())
        defer { hb_raster_draw_destroy(draw) }
        let functions = hb_raster_draw_get_funcs(draw)
        var state = hb_draw_state_t()

        // -- Act --
        let drawData = UnsafeMutableRawPointer(draw)
        hb_draw_move_to(functions, drawData, &state, 2, 3)
        hb_draw_line_to(functions, drawData, &state, 5, 3)
        hb_draw_line_to(functions, drawData, &state, 5, 7)
        hb_draw_line_to(functions, drawData, &state, 2, 7)
        hb_draw_close_path(functions, drawData, &state)
        let image = try #require(hb_raster_draw_render(draw))
        defer { hb_raster_image_destroy(image) }
        var extents = hb_raster_extents_t()
        hb_raster_image_get_extents(image, &extents)
        let bytes = try #require(hb_raster_image_get_buffer(image))

        // -- Assert --
        #expect(hb_raster_image_get_format(image) == HB_RASTER_FORMAT_A8)
        #expect(extents.x_origin == 2)
        #expect(extents.y_origin == 3)
        #expect(extents.width == 3)
        #expect(extents.height == 4)
        for row in 0..<Int(extents.height) {
            #expect(Array(UnsafeBufferPointer(start: bytes + row * Int(extents.stride), count: 3)) == [255, 255, 255])
        }
    }
}
