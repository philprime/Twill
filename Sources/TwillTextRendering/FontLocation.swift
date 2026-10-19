package struct FontLocation: Sendable {
    package let path: String
    package let postScriptName: String?

    package init(path: String, postScriptName: String? = nil) {
        self.path = path
        self.postScriptName = postScriptName
    }
}
