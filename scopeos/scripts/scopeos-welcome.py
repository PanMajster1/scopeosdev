#!/usr/bin/env python3
"""
ScopeOS Welcome
A GTK4 + Libadwaita welcome application for ScopeOS.
"""

import sys
import subprocess
import gi

# pylint: disable=wrong-import-position
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')

from gi.repository import Gtk, Adw, Gio


class WelcomeWindow(Adw.Window):
    """
    Main window for the Welcome application.
    """
    def __init__(self, application):
        super().__init__(application=application, title="Welcome to ScopeOS")
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
        logo_path = "/opt/scopeos/assets/scopeos-logo.png"
        picture = Gtk.Picture.new_for_filename(logo_path)
        picture.set_can_shrink(False)
        picture.set_size_request(128, 128)
        content.append(picture)

        # Title
        title = Gtk.Label(label="Welcome to ScopeOS")
        title.add_css_class("title-1")
        content.append(title)

        # Description
        desc_label = "ScopeOS is ready to go. You can try it out or install it to your computer."
        desc = Gtk.Label(label=desc_label)
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
        """Handler for the 'Try' button."""
        self.close()

    def on_install_clicked(self, _button):
        """Handler for the 'Install' button."""
        try:
            # Launch Calamares with pkexec
            # subprocess.Popen is used here to fire and forget without blocking the UI thread
            # or needing to wait for the process.
            # pylint: disable=consider-using-with
            subprocess.Popen(["pkexec", "calamares"])
        except subprocess.SubprocessError as e:
            print(f"Failed to launch Calamares: {e}")
        self.close()


class WelcomeApp(Adw.Application):
    """
    Application class for ScopeOS Welcome.
    """
    def __init__(self):
        super().__init__(application_id="com.scopeos.Welcome",
                         flags=Gio.ApplicationFlags.FLAGS_NONE)

    def do_activate(self):
        """Activates the application."""
        win = self.props.active_window
        if not win:
            win = WelcomeWindow(self)
        win.present()


if __name__ == "__main__":
    welcome_app = WelcomeApp()
    welcome_app.run(sys.argv)
