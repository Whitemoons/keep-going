// Gives a file a custom Finder icon: set-icon <icon.icns> <file>.
// Used for the .dmg itself; the icon of the mounted volume comes from dmg-settings.py.
import AppKit

let arguments = CommandLine.arguments
guard let icon = NSImage(contentsOfFile: arguments[1]),
  NSWorkspace.shared.setIcon(icon, forFile: arguments[2])
else {
  FileHandle.standardError.write(Data("could not set the file icon\n".utf8))
  exit(1)
}
