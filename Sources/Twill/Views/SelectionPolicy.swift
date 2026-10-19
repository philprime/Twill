/// Resolves externally owned selection against the currently visible collection.
/// Resolution is pure: it never normalizes or writes the selection binding.
public enum SelectionPolicy: Sendable {
    /// Nil, missing, and hidden IDs display the first visible row, if any.
    case firstVisible
    /// Nil, missing, and hidden IDs have no effective selection.
    case allowEmpty

    /// Returns the selected visible element, or the policy's fallback.
    public func resolve<Data: Collection, ID: Hashable>(
        in data: Data, selection: ID?, id: KeyPath<Data.Element, ID>
    ) -> Data.Element? {
        index(in: data, selection: selection, id: { $0[keyPath: id] }).map { data[$0] }
    }

    /// Resolves visible elements using their stable identities.
    public func resolve<Data: Collection>(in data: Data, selection: Data.Element.ID?) -> Data.Element?
    where Data.Element: Identifiable {
        resolve(in: data, selection: selection, id: \.id)
    }

    /// Resolves a hierarchy using the same expansion visibility as an outline.
    public func resolve<Data: RandomAccessCollection, ID: Hashable>(
        in data: Data, selection: ID?, id: KeyPath<Data.Element, ID>, children: KeyPath<Data.Element, Data?>,
        expandedIDs: Set<ID>
    ) -> Data.Element? {
        let rows = OutlineRow.visibleRows(in: data, id: id, children: children, expandedIDs: expandedIDs)
        return resolve(in: rows, selection: selection, id: \.id)?.element
    }

    /// Resolves an identifiable hierarchy, considering only currently visible rows.
    public func resolve<Data: RandomAccessCollection>(
        in data: Data, selection: Data.Element.ID?, children: KeyPath<Data.Element, Data?>,
        expandedIDs: Set<Data.Element.ID>
    ) -> Data.Element? where Data.Element: Identifiable {
        resolve(in: data, selection: selection, id: \.id, children: children, expandedIDs: expandedIDs)
    }

    // Projection closures avoid generic key-path metadata failures in pack-based tables.
    func index<Data: Collection, ID: Hashable>(
        in data: Data, selection: ID?, id: (Data.Element) -> ID
    ) -> Data.Index? {
        if let selection, let index = data.firstIndex(where: { id($0) == selection }) { return index }
        return self == .firstVisible && !data.isEmpty ? data.startIndex : nil
    }

}
