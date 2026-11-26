# dmgbuild settings: the window a user sees after opening the DMG.
# Positions are icon centers in points from the window's top-left corner and must match
# the arrow drawn by Scripts/make-assets (drawDMGBackground).
import os.path

app = defines["app"]  # noqa: F821 - injected by dmgbuild (-D app=...)

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}

background = "Resources/dmg-background.tiff"
window_rect = ((200, 200), (600, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

arrange_by = None
icon_size = 112
text_size = 13
icon_locations = {
    os.path.basename(app): (160, 185),
    "Applications": (440, 185),
}
