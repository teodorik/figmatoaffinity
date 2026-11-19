import AppKit

struct ClipboardSnapshot {
    private let items: [[(NSPasteboard.PasteboardType, Data)]]

    init?(_ sourceItems: [NSPasteboardItem]) {
        var items: [[(NSPasteboard.PasteboardType, Data)]] = []
        for item in sourceItems {
            var flavors: [(NSPasteboard.PasteboardType, Data)] = []
            for type in item.types {
                guard let data = item.data(forType: type) else { return nil }
                flavors.append((type, data))
            }
            guard !flavors.isEmpty else { return nil }
            items.append(flavors)
        }
        guard !items.isEmpty else { return nil }
        self.items = items
    }

    func pasteboardItems() -> [NSPasteboardItem] {
        items.map { flavors in
            let item = NSPasteboardItem()
            for (type, data) in flavors {
                item.setData(data, forType: type)
            }
            return item
        }
    }
}

func isFigmaLayerCopy(_ item: NSPasteboardItem) -> Bool {
    guard let html = item.data(forType: .html) else { return false }
    return html.range(of: Data("<!--(figmeta)".utf8)) != nil
        && html.range(of: Data("<!--(figma)".utf8)) != nil
}

func svgText(from item: NSPasteboardItem) -> Data? {
    guard let data = item.data(forType: .string) else { return nil }
    let prefix = String(decoding: data.prefix(8192), as: UTF8.self)
    let root = #"(?s)\A\uFEFF?\s*(?:<\?xml\s.*?\?>\s*)?(?:<!--.*?-->\s*)*<svg(?=[\s/>])"#
    return prefix.range(of: root, options: .regularExpression) == nil ? nil : data
}

struct Transfer {
    let original: ClipboardSnapshot
    let svg: Data
    var change: Int
    var showingSVG: Bool

    // Swap only while this transfer still owns the current clipboard revision.
    mutating func displaySVG(_ display: Bool, on board: NSPasteboard) -> Bool {
        guard board.changeCount == change else { return false }
        guard display != showingSVG else { return true }

        let items: [NSPasteboardItem]
        if display {
            let item = NSPasteboardItem()
            guard item.setData(svg, forType: .string) else { return false }
            items = [item]
        } else {
            items = original.pasteboardItems()
        }

        guard board.changeCount == change else { return false }
        board.prepareForNewContents(with: display ? .currentHostOnly : [])
        guard board.writeObjects(items) else { return false }
        change = board.changeCount
        showingSVG = display
        return true
    }
}
