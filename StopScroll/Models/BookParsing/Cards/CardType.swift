enum CardType {
    case text
    case chapterStart(title: String, chapterNumber: Int)
    case sectionStart(title: String)
    case timer
    case completion(isArticle: Bool)
}
