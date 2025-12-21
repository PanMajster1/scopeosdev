#!/usr/bin/env python3
"""
ScopeOS Welcome Application
A GTK4 + Libadwaita application shown on first login.
"""

import sys
import subprocess
import gi

gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from gi.repository import Gtk, Adw, Gio

class WelcomeWindow(Adw.Window):
    """
    Main window for the Welcome application.
    """
    def __init__(self, app):
        super().__init__(application=app, title="Welcome to ScopeOS")
        self.set_default_size(600, 450)
        self.set_resizable(False)

        # Main content box
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=24)
        content.set_margin_top(48)
        content.set_margin_bottom(48)
        content.set_margin_start(48)
        content.set_margin_end(48)
        content.set_halign(Gtk.Align.CENTER)
        content.set_valign(Gtk.Align.CENTER)

        self.set_content(content)

        # Logo
        logo_path = "/usr/share/scopeos/assets/scopeos-logo.png"
        picture = Gtk.Picture.new_for_filename(logo_path)
        picture.set_can_shrink(False)
        picture.set_size_request(128, 128)
        content.append(picture)

        # Title
        title = Gtk.Label(label="Welcome to ScopeOS")
        title.add_css_class("title-1")
        content.append(title)

        # Description
        desc = Gtk.Label(label="ScopeOS is ready to go. You can try it out or install it to your computer.")
        desc.set_wrap(True)
        desc.set_max_width_chars(40)
        desc.add_css_class("body")
        content.append(desc)

        # Buttons Box
        btn_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        btn_box.set_halign(Gtk.Align.CENTER)
        content.append(btn_box)

        # Try Button
        try_btn = Gtk.Button(label="Try ScopeOS")
        try_btn.add_css_class("pill")
        try_btn.set_size_request(140, 50)
        try_btn.connect("clicked", self.on_try_clicked)
        btn_box.append(try_btn)

        # Install Button
        install_btn = Gtk.Button(label="Install ScopeOS")
        install_btn.add_css_class("suggested-action")
        install_btn.add_css_class("pill")
        install_btn.set_size_request(140, 50)
        install_btn.connect("clicked", self.on_install_clicked)
        btn_box.append(install_btn)

    def on_try_clicked(self, _button):
        """Closes the welcome window."""
        self.close()

    def on_install_clicked(self, _button):
        """Launches the installer."""
        try:
            # Launch Calamares with pkexec
            # Note: subprocess.Popen is safe here as arguments are a list
            subprocess.Popen(["pkexec", "calamares"])
        except OSError as e:
            print(f"Failed to launch Calamares: {e}")
        self.close()

class WelcomeApp(Adw.Application):
    """
    Main Application class.
    """
    def __init__(self):
        super().__init__(application_id="com.scopeos.Welcome",
                         flags=Gio.ApplicationFlags.FLAGS_NONE)

    def do_activate(self):
        win = self.props.active_window
        if not win:
            win = WelcomeWindow(self)
        win.present()

if __name__ == "__main__":
    app = WelcomeApp()
    app.run(sys.argv)
