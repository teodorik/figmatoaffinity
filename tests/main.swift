import AppKit

let svg = Data(#"<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0L100 100"/></svg>"#.utf8)
let html = Data(#"<span data-metadata="<!--(figmeta)fixture(/figmeta)-->"></span><span data-buffer="<!--(figma)fixture(/figma)-->"></span>"#.utf8)
let board = NSPasteboard.withUniqueName()
let figmaItem = NSPasteboardItem()
precondition(figmaItem.setData(html, forType: .html))
precondition(figmaItem.setString("original text", forType: .string))
let secondItem = NSPasteboardItem()
precondition(secondItem.setString("second item", forType: .string))
precondition(board.writeObjects([figmaItem, secondItem]))

let contents = board.pasteboardItems!
precondition(isFigmaLayerCopy(contents[0]))
precondition(!isFigmaLayerCopy(contents[1]))
precondition(svgText(from: contents[0]) == nil)
let original = ClipboardSnapshot(contents)!
var transfer = Transfer(original: original, svg: svg, change: board.changeCount, showingSVG: false)

precondition(transfer.displaySVG(true, on: board))
precondition(board.pasteboardItems?.count == 1)
precondition(svgText(from: board.pasteboardItems![0]) == svg)

precondition(transfer.displaySVG(false, on: board))
let restored = board.pasteboardItems!
precondition(restored.count == 2)
precondition(restored[0].data(forType: .html) == html)
precondition(restored[0].string(forType: .string) == "original text")
precondition(restored[1].string(forType: .string) == "second item")

precondition(transfer.displaySVG(true, on: board))
board.clearContents()
precondition(board.setString("new copy", forType: .string))
precondition(!transfer.displaySVG(false, on: board))
precondition(board.string(forType: .string) == "new copy")
board.releaseGlobally()
print("Clipboard checks passed")
