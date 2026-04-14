struct BookCard: Identifiable {
    let id: Int
    let text: String
    let cardNumber: Int
    let totalCards: Int
    let page: Int
    let chapter: Int
    let type: CardType
    let chapterTitle: String
    let cardIndexInPage: Int
    var isBookmarked: Bool = false
}
