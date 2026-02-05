import Foundation

// MARK: - News Item Model

struct NewsItem: Identifiable, Sendable {
    let id: UUID
    let headline: String
    let source: String
    let link: URL?
    let publishedAt: Date?
    let isTopFromSource: Bool

    init(
        headline: String,
        source: String,
        link: URL? = nil,
        publishedAt: Date? = nil,
        isTopFromSource: Bool = false
    ) {
        self.id = UUID()
        self.headline = headline
        self.source = source
        self.link = link
        self.publishedAt = publishedAt
        self.isTopFromSource = isTopFromSource
    }

    func withTopFromSource(_ isTop: Bool) -> NewsItem {
        NewsItem(
            headline: headline,
            source: source,
            link: link,
            publishedAt: publishedAt,
            isTopFromSource: isTop
        )
    }
}

// MARK: - RSS Parser

final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [NewsItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var isInsideItem = false

    private let source: String
    private let dateFormatter: DateFormatter

    init(source: String) {
        self.source = source
        self.dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        // RFC 822 format used by RSS feeds
        dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        super.init()
    }

    func parse(data: Data) -> [NewsItem] {
        items = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    // MARK: - XMLParserDelegate

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        switch currentElement {
        case "title":
            currentTitle += string
        case "link":
            currentLink += string
        case "pubDate":
            currentPubDate += string
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "item", isInsideItem else { return }

        let headline = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let linkString = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        let pubDateString = currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !headline.isEmpty else {
            isInsideItem = false
            return
        }

        let link = URL(string: linkString)
        let publishedAt = dateFormatter.date(from: pubDateString)

        let item = NewsItem(
            headline: headline,
            source: source,
            link: link,
            publishedAt: publishedAt
        )
        items.append(item)
        isInsideItem = false
    }
}

// MARK: - News Source Configuration

enum NewsSource: String, CaseIterable {
    case yahoo
    case cnbcMarkets

    var feedURL: String {
        switch self {
        case .yahoo:
            return "https://finance.yahoo.com/news/rssindex"
        case .cnbcMarkets:
            return "https://www.cnbc.com/id/20910258/device/rss/rss.html"
        }
    }

    var displayName: String {
        switch self {
        case .yahoo:
            return "Yahoo"
        case .cnbcMarkets:
            return "CNBC"
        }
    }
}
