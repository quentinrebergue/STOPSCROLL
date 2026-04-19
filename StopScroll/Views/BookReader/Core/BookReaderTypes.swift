import UniformTypeIdentifiers

extension BookReaderView {
    static func resolveCurrentArticleId(appStorageValue: String, userDefaultsValue: String?) -> String {
        let fromDefaults = userDefaultsValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromDefaults.isEmpty { return fromDefaults }
        return appStorageValue
    }

    static var allowedTypes: [UTType] {
        var types: [UTType] = [.plainText]
        if let epub = UTType("org.idpf.epub-container") {
            types.append(epub)
        } else if let epub = UTType(filenameExtension: "epub") {
            types.append(epub)
        }
        types.append(.data)
        return types
    }
}
