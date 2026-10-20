extension SelectionPolicy {
    func navigationIndex<Data: BidirectionalCollection, ID: Hashable>(
        for key: KeyEvent, in data: Data, selection: ID?, id: (Data.Element) -> ID
    ) -> Data.Index? {
        guard !data.isEmpty else { return nil }
        guard var index = index(in: data, selection: selection, id: id) else {
            return edgeIndex(for: key, in: data)
        }
        switch key {
        case .arrowDown:
            let next = data.index(after: index)
            if next != data.endIndex { index = next }
        case .arrowUp:
            if index != data.startIndex { index = data.index(before: index) }
        case .home: index = data.startIndex
        case .end: index = data.index(before: data.endIndex)
        default: break
        }
        return index
    }

    private func edgeIndex<Data: BidirectionalCollection>(for key: KeyEvent, in data: Data) -> Data.Index? {
        switch key {
        case .arrowDown, .home: data.startIndex
        case .arrowUp, .end: data.index(before: data.endIndex)
        default: nil
        }
    }
}
