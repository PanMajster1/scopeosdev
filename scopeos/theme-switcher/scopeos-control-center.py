#!/usr/bin/env python3
import sys
import os
import subprocess
import threading

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, Gio, GLib

class ScopeOSControlCenter(Adw.Application):
    def __init__(self, **kwargs):
        super().__init__(application_id='com.scopeos.controlcenter',
                         flags=Gio.ApplicationFlags.FLAGS_NONE,
                         **kwargs)

    def do_activate(self):
        win = ScopeOSWindow(application=self)
        win.present()

class ScopeOSWindow(Adw.PreferencesWindow):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.set_title("ScopeOS Control Center")
        self.set_default_size(800, 600)

        # Appearance Page
        appearance_page = Adw.PreferencesPage()
        appearance_page.set_title("Appearance")
        appearance_page.set_icon_name("preferences-desktop-theme-symbolic")
        self.add(appearance_page)

        # Theme Group
        theme_group = Adw.PreferencesGroup()
        theme_group.set_title("System Theme")
        theme_group.set_description("Select the look and feel of ScopeOS")
        appearance_page.add(theme_group)

        # Theme FlowBox
        flowbox = Gtk.FlowBox()
        flowbox.set_valign(Gtk.Align.START)
        flowbox.set_max_children_per_line(3)
        flowbox.set_selection_mode(Gtk.SelectionMode.NONE)
        theme_group.add(flowbox)

        themes = [
            {"id": "macos", "name": "MacOS Like", "icon": "user-desktop"},
            {"id": "win10", "name": "Windows 10", "icon": "desktop-profiler"},
            {"id": "win11", "name": "Windows 11", "icon": "computer"},
            {"id": "ubuntu", "name": "Ubuntu Default", "icon": "distributor-logo"},
            {"id": "gnome", "name": "Pure GNOME", "icon": "gnome-logo-icon"},
        ]

        for theme in themes:
            card = ThemeCard(theme, self.on_apply_theme_clicked)
            flowbox.append(card)

        # Dark Mode Group
        dark_mode_group = Adw.PreferencesGroup()
        dark_mode_group.set_title("Color Scheme")
        appearance_page.add(dark_mode_group)

        dark_mode_row = Adw.ActionRow()
        dark_mode_row.set_title("Dark Mode")
        dark_mode_row.set_subtitle("Enable system-wide dark theme")

        switch = Gtk.Switch()
        switch.set_active(self.is_dark_mode())
        switch.connect("state-set", self.toggle_dark_mode)
        switch.set_valign(Gtk.Align.CENTER)

        dark_mode_row.add_suffix(switch)
        dark_mode_group.add(dark_mode_row)

        # Spinner for busy state
        self.spinner = Gtk.Spinner()
        self.spinner.set_size_request(32, 32)
        # We can add this to the headerbar or show a toast/overlay.
        # For simplicity, we might just use it in a toast or dialog, but here I'll leave it
        # as a potential future improvement or add it to the window content if needed.
        # Instead of a spinner, we'll rely on the Toast to show "Applying..."

    def is_dark_mode(self):
        try:
            result = subprocess.check_output(
                ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"],
                text=True
            ).strip()
            return "dark" in result
        except Exception:
            return False

    def toggle_dark_mode(self, switch, state):
        scheme = "prefer-dark" if state else "default"
        print(f"Setting color scheme to: {scheme}")
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", f"'{scheme}'"])
        return True

    def is_extension_installed(self, extension_id):
        try:
            subprocess.run(
                ["gnome-extensions", "info", extension_id],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return True
        except (subprocess.CalledProcessError, FileNotFoundError):
            return False

    def set_extension_state(self, extension_id, enable):
        if not self.is_extension_installed(extension_id):
            print(f"Extension {extension_id} is not installed.")
            return

        action = "enable" if enable else "disable"
        print(f"{action.capitalize()}ing {extension_id}...")
        try:
            subprocess.run(["gnome-extensions", action, extension_id], check=True)
        except Exception as e:
            print(f"Error {action}ing extension {extension_id}: {e}")

    def on_apply_theme_clicked(self, theme_id):
        # Show feedback immediately
        self.add_toast(Adw.Toast.new(f"Applying theme {theme_id}..."))

        # Run in a separate thread to avoid freezing the UI
        thread = threading.Thread(target=self.apply_theme_thread, args=(theme_id,))
        thread.daemon = True
        thread.start()

    def apply_theme_thread(self, theme_id):
        try:
            self.perform_theme_change(theme_id)
            GLib.idle_add(self.on_theme_applied_success, theme_id)
        except Exception as e:
            GLib.idle_add(self.on_theme_applied_error, str(e))

    def perform_theme_change(self, theme_id):
        print(f"Applying theme: {theme_id}")

        theme_configs = {
            "macos": {
                "gtk": "WhiteSur-Light",
                "icon": "WhiteSur",
                "shell": "WhiteSur-Light",
                "wallpaper": "/usr/share/backgrounds/macos-wallpaper.jpg",
                "dock": True,
                "panel": False
            },
            "win10": {
                "gtk": "Windows-10",
                "icon": "Windows-10",
                "shell": "Windows-10",
                "wallpaper": "/usr/share/backgrounds/win10-wallpaper.jpg",
                "dock": False,
                "panel": True
            },
            "win11": {
                "gtk": "Fluent-Light",
                "icon": "Fluent",
                "shell": "Fluent-Light",
                "wallpaper": "/usr/share/backgrounds/win11-wallpaper.jpg",
                "dock": False,
                "panel": True
            },
            "ubuntu": {
                "gtk": "Yaru",
                "icon": "Yaru",
                "shell": "Yaru",
                "wallpaper": "/usr/share/backgrounds/ubuntu-wallpaper.jpg",
                "dock": True,
                "panel": False
            },
            "gnome": {
                "gtk": "Adwaita",
                "icon": "Adwaita",
                "shell": "Default",
                "wallpaper": "/usr/share/backgrounds/gnome-wallpaper.jpg",
                "dock": False,
                "panel": False
            },
        }

        config = theme_configs.get(theme_id)
        if not config:
            raise ValueError("Unknown theme ID")

        commands = [
            ["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", config["gtk"]],
            ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", config["icon"]],
            ["gsettings", "set", "org.gnome.shell.extensions.user-theme", "name", config["shell"]],
            ["gsettings", "set", "org.gnome.desktop.background", "picture-uri", f"file://{config['wallpaper']}"],
            ["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", f"file://{config['wallpaper']}"]
        ]

        for cmd in commands:
            print(f"Executing: {' '.join(cmd)}")
            subprocess.run(cmd, check=False)

        dash_to_dock_id = "dash-to-dock@micxgx.gmail.com"
        dash_to_panel_id = "dash-to-panel@jderose9.github.com"

        if config.get("dock"):
            self.set_extension_state(dash_to_dock_id, True)
        else:
            self.set_extension_state(dash_to_dock_id, False)

        if config.get("panel"):
            self.set_extension_state(dash_to_panel_id, True)
        else:
            self.set_extension_state(dash_to_panel_id, False)

    def on_theme_applied_success(self, theme_id):
        dialog = Adw.MessageDialog(
            heading="Theme Applied",
            body=f"Successfully switched to {theme_id} theme.",
        )
        dialog.add_response("ok", "OK")
        dialog.set_transient_for(self)
        dialog.present()

    def on_theme_applied_error(self, error_msg):
        dialog = Adw.MessageDialog(
            heading="Error Applying Theme",
            body=f"An error occurred: {error_msg}",
        )
        dialog.add_response("ok", "OK")
        dialog.set_transient_for(self)
        dialog.present()

class ThemeCard(Gtk.Box):
    def __init__(self, theme_data, apply_callback):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.set_margin_top(12)
        self.set_margin_bottom(12)
        self.set_margin_start(12)
        self.set_margin_end(12)

        preview_widget = self._create_theme_preview(theme_data)
        self.append(preview_widget)

        label = Gtk.Label(label=theme_data["name"])
        label.set_css_classes(["heading"])
        self.append(label)

        button = Gtk.Button(label="Apply")
        button.add_css_class("suggested-action")
        button.connect("clicked", lambda x: apply_callback(theme_data["id"]))
        self.append(button)

    def _create_theme_preview(self, theme_data):
        preview_path = theme_data.get("preview")
        if preview_path and os.path.exists(preview_path):
            try:
                picture = Gtk.Picture.new_for_filename(preview_path)
                picture.set_content_fit(Gtk.ContentFit.CONTAIN)
                picture.set_size_request(64, 64)
                return picture
            except Exception as e:
                print(f"Error loading preview for {theme_data['name']}: {e}")

        icon_name = theme_data.get("icon", "image-missing")
        icon = Gtk.Image.new_from_icon_name(icon_name)
        icon.set_pixel_size(64)
        return icon

if __name__ == "__main__":
    app = ScopeOSControlCenter()
    app.run(sys.argv)
