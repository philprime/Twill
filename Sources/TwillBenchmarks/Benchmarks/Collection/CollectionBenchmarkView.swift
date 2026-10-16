import Twill

/// A bounded viewport over keyed rows, with fixture construction outside the timed SDK work.
struct CollectionBenchmarkView: View {
    let identifiers: [Int]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(identifiers, id: \.self) { identifier in
                    HStack {
                        Text(String(identifier)).frame(width: 8, alignment: .leading)
                        Text("Synthetic record \(identifier)")
                    }
                }
            }
        }
        .frame(width: 120, height: 40, alignment: .topLeading)
    }
}
