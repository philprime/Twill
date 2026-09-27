import Twill

private let customBorder = Border.custom(
    BorderGlyphs(
        topLeft: "+", top: "-", topRight: "+", left: "|", right: "|",
        bottomLeft: "+", bottom: "-", bottomRight: "+"))

struct BorderGallery: View {
    var body: some View {
        VStack(spacing: 1) {
            Text("Borders")
            HStack(spacing: 2) {
                Text("single").frame(width: 16).border(.single, color: Color.white)
                Text("double").frame(width: 16).border(.double, color: Color.white)
                Text("thick").frame(width: 16).border(.thick, color: Color.white)
                Text("custom").frame(width: 16).border(customBorder, color: Color.white)
            }
        }
        .border(.single, color: Color.white)
    }
}
