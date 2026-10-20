/// A vertically scrolling collection of keyed rows, optionally selectable.
///
/// With a selection binding, the list is one control-level Tab stop. Up/Down and Home/End change selection,
/// and Enter activates the effective element through `.onActivate`, or invokes
/// the nearest `.onSubmit` action when no activation callback is supplied. Selection stays visible
/// when another control has focus. Row content describes presentation, not
/// independently focusable controls. Without a binding, rows use ordinary view
/// interaction and a static viewport scrolls without selecting or activating items.
public struct List<Data: RandomAccessCollection, ID: Hashable, RowContent: View>: View {
    /// Primitive content rendered directly by the runtime rather than through a composed body.
    public typealias Body = Never
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let selection: Binding<ID?>?
    private let selectionPolicy: SelectionPolicy
    private let rowContent: @MainActor (Data.Element) -> RowContent
    private var activation: (@MainActor (Data.Element) -> Void)?

    /// Creates keyed rows with optional externally owned selection. Without a binding,
    /// row controls use ordinary focus traversal and the collection does not activate rows.
    /// The policy resolves nil or missing IDs without changing the binding.
    /// By default the first visible row is selected; allow-empty retains no selection.
    public init(
        _ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<ID?>? = nil,
        selectionPolicy: SelectionPolicy = .firstVisible,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.data = data
        self.id = id
        self.selection = selection
        self.selectionPolicy = selectionPolicy
        self.rowContent = rowContent
    }

    /// Activates the effective element on Enter after committing its selection.
    /// This callback consumes Enter instead of also invoking `.onSubmit`.
    /// Apply it before general view modifiers; a later callback replaces an earlier one.
    public func onActivate(_ action: @escaping @MainActor (Data.Element) -> Void) -> Self {
        var view = self
        view.activation = action
        return view
    }

    private var selectedIndex: Data.Index? {
        selection.flatMap { selectionPolicy.index(in: data, selection: $0.wrappedValue, id: { $0[keyPath: id] }) }
    }

    private func handle(_ key: KeyEvent, selection: Binding<ID?>) -> KeyPressResult {
        guard [.arrowDown, .arrowUp, .home, .end, .enter].contains(key) else { return .ignored }
        guard
            let index = selectionPolicy.navigationIndex(
                for: key, in: data, selection: selection.wrappedValue, id: { $0[keyPath: id] })
        else { return .handled }
        let element = data[index]
        selection.wrappedValue = element[keyPath: id]
        if key == .enter, let activation {
            activation(element)
            return .handled
        }
        // Submission routes through the existing enclosing action after selecting
        // the effective row. Without an effective row, Enter is consumed without submitting.
        return key == .enter ? .ignored : .handled
    }
}

extension List where Data.Element: Identifiable, ID == Data.Element.ID {
    /// Creates a list using stable element identities. Omitting the binding keeps rows nonselectable.
    public init(
        _ data: Data, selection: Binding<ID?>? = nil, selectionPolicy: SelectionPolicy = .firstVisible,
        @ViewBuilder rowContent: @escaping @MainActor (Data.Element) -> RowContent
    ) {
        self.init(data, id: \.id, selection: selection, selectionPolicy: selectionPolicy, rowContent: rowContent)
    }
}

extension List: PrimitiveView {
    func makeDescription() -> ViewDescription {
        guard let selection else {
            return .scroll(
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(data, id: id, content: rowContent)
                })
        }
        let selectedID = selectedIndex.map { data[$0][keyPath: id] }
        return .pane(
            ScrollView {
                ListSelectionContent(
                    content: VStack(alignment: .leading, spacing: 0) {
                        ForEach(data, id: id) { element in
                            ListRow(content: rowContent(element), isSelected: element[keyPath: id] == selectedID)
                        }
                    },
                    selection: selectedID.map(AnyHashable.init), handle: { handle($0, selection: selection) })
            })
    }
}

struct ListSelectionContent<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let selection: AnyHashable?
    let handle: @MainActor (KeyEvent) -> KeyPressResult

    func makeDescription() -> ViewDescription { .listSelection(content, selection, handle) }
}

struct ListRow<Content: View>: View, PrimitiveView {
    typealias Body = Never
    let content: Content
    let isSelected: Bool?

    func makeDescription() -> ViewDescription {
        if let isSelected { return .listRow(content, isSelected: isSelected) }
        return .body(content)
    }
}
