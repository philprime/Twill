/// Tree participation is separate from mounting lifetime: hidden destinations retain
/// identity and deadlines, while modal interaction follows only the selected branch.
@MainActor
extension ViewRenderer {
    var retainedChildren: [ViewRenderer] { childStorage.nodes }

    /// Excludes inactive tab branches, including modifiers surrounding a destination.
    /// Sheet bases remain available for drawing underneath their presented layers.
    var presentationChildren: [ViewRenderer] {
        // Modal content draws in a separate overlay layer, not in its base's layout slot.
        if case .sheet = description { return Array(retainedChildren.prefix(1)) }
        if case .tab = description, !tabState.isActive { return [] }
        guard !descendantTabNodes.isEmpty else { return retainedChildren }
        return retainedChildren.filter { child in
            let destinations = child.tabNodes
            return destinations.isEmpty || destinations.contains(where: \.tabState.isActive)
        }
    }

    /// Focus discovery enters a sheet's active branch rather than its retained base.
    var interactionChildren: [ViewRenderer] {
        if case .sheet = description { return sheetBranch.map { [$0] } ?? [] }
        return presentationChildren
    }

    var sheetBranch: ViewRenderer? {
        guard case .sheet(let sheet) = description else { return nil }
        return sheet.isPresented.wrappedValue ? retainedChildren.dropFirst().first : retainedChildren.first
    }

    /// Resolves the topmost modal boundary without entering inactive tab destinations.
    func activeModalScope() -> ViewRenderer? {
        if case .sheet(let sheet) = description {
            guard let branch = sheetBranch else { return nil }
            return branch.activeModalScope() ?? (sheet.isPresented.wrappedValue ? self : nil)
        }
        for child in presentationChildren.reversed() {
            if let sheet = child.activeModalScope() { return sheet }
        }
        return nil
    }
}
