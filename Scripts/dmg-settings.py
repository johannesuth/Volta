# Volta · Copyright © 2026 Johannes Uth. All rights reserved.
# Source-available under the Volta License (see LICENSE). Not for redistribution.
#
# dmgbuild settings for Volta's disk image: the app on the left, an Applications
# shortcut on the right, on a designed background. Values arrive via -D.
import os.path

application = defines["app"]  # noqa: F821 (provided by dmgbuild)
appname = os.path.basename(application)

format = "ULFO"  # LZFSE compression, macOS 10.11 or later
filesystem = "HFS+"
size = None

files = [application]
symlinks = {"Applications": "/Applications"}
hide_extensions = [appname]

icon = defines.get("icon")  # noqa: F821
background = defines["background"]  # noqa: F821

window_rect = ((240, 160), (660, 422))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
arrange_by = None
label_pos = "bottom"
icon_size = 112
text_size = 13
icon_locations = {
    appname: (180, 200),
    "Applications": (480, 200),
}
