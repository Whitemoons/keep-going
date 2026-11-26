// Writes a Finder alias to /Applications that carries the folder's icon inside the file.
// A plain symlink leaves the icon up to the Finder of whoever opens the DMG, and that
// does not reliably show the Applications folder artwork.
import AppKit

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let target = URL(fileURLWithPath: "/Applications")

try? FileManager.default.removeItem(at: output)
let bookmark = try target.bookmarkData(
  options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
try URL.writeBookmarkData(bookmark, to: output)

let icon = NSWorkspace.shared.icon(forFile: target.path)
icon.size = NSSize(width: 512, height: 512)
guard NSWorkspace.shared.setIcon(icon, forFile: output.path) else {
  FileHandle.standardError.write(Data("could not set the alias icon\n".utf8))
  exit(1)
}
