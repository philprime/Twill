import Twill

private let customBorder = Border.custom(
    Border.Glyphs(
        topLeft: "+", top: "-", topRight: "+", left: "|", right: "|",
        bottomLeft: "+", bottom: "-", bottomRight: "+"))

struct BorderGallery: View {
    var body: some View {
        VStack(spacing: 1) {
            Text("Borders")
            HStack(spacing: 2) {
                Text("single").frame(width: 16).border(.single, color: Color.white)
                Text("double").frame(width: 16).border(.double, color: Color.white)
                Text("rounded").frame(width: 16).border(.rounded, color: Color.white)
                Text("heavy").frame(width: 16).border(.heavy, color: Color.white)
            }
            HStack(spacing: 2) {
                Text("dashed").frame(width: 16).border(.dashed, color: Color.white)
                Text("custom").frame(width: 16).border(customBorder, color: Color.white)
            }
        }
        .border(.single, color: Color.white)
    }
}
