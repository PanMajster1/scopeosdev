#!/usr/bin/env python3
import sys
import gi
import os
import subprocess

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
            card = ThemeCard(theme, self.apply_theme)
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

    def is_dark_mode(self):
        # Check current setting via gsettings
        try:
            result = subprocess.check_output(
                ["gsettings", "get", "org.gnome.desktop.interface", "color-scheme"],
                text=True
            ).strip()
            return "dark" in result
        except Exception:
            return False # Default assumption

    def toggle_dark_mode(self, switch, state):
        scheme = "prefer-dark" if state else "default"
        print(f"Setting color scheme to: {scheme}")
        # In real env:
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", f"'{scheme}'"])
        return True # Enable the switch change

    def is_extension_installed(self, extension_id):
        try:
            # 'gnome-extensions info' returns exit code 0 if found, non-zero if not.
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

    def apply_theme(self, theme_id):
        print(f"Applying theme: {theme_id}")

        # Configuration mapping for themes
        # Configured to match themes installed by scopeos/scripts/download_themes.sh
        theme_configs = {
            "macos": {
                "gtk": "WhiteSur-Light",
                "icon": "WhiteSur",
                "shell": "WhiteSur-Light",
                "wallpaper": "/usr/share/backgrounds/macos-wallpaper.jpg",
                "dock": True, # Enable dash-to-dock
                "panel": False
            },
            "win10": {
                "gtk": "Windows-10",
                "icon": "Windows-10",
                "shell": "Windows-10",
                "wallpaper": "/usr/share/backgrounds/win10-wallpaper.jpg",
                "dock": False,
                "panel": True # Bottom panel style (requires Dash to Panel extension)
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
                "shell": "Default", # or empty
                "wallpaper": "/usr/share/backgrounds/gnome-wallpaper.jpg",
                "dock": False,
                "panel": False
            },
        }

        config = theme_configs.get(theme_id)
        if not config:
            return

        # Commands to execute
        commands = [
            ["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", config["gtk"]],
            ["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", config["icon"]],
            ["gsettings", "set", "org.gnome.shell.extensions.user-theme", "name", config["shell"]],
            ["gsettings", "set", "org.gnome.desktop.background", "picture-uri", f"file://{config['wallpaper']}"],
            ["gsettings", "set", "org.gnome.desktop.background", "picture-uri-dark", f"file://{config['wallpaper']}"]
        ]

        for cmd in commands:
            print(f"Executing: {' '.join(cmd)}")
            try:
                subprocess.run(cmd, check=False)
            except Exception as e:
                print(f"Error executing command: {e}")

        # Handle Extensions (Dock vs Panel)
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

        # Show success message (simple dialog)
        dialog = Adw.MessageDialog(
            heading="Theme Applied",
            body=f"Successfully switched to {theme_id} theme.",
        )
        dialog.add_response("ok", "OK")
        dialog.present(self)

class ThemeCard(Gtk.Box):
    def __init__(self, theme_data, apply_callback):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.set_margin_top(12)
        self.set_margin_bottom(12)
        self.set_margin_start(12)
        self.set_margin_end(12)

        # Placeholder Icon/Image
        icon = Gtk.Image.new_from_icon_name(theme_data.get("icon", "image-missing"))
        icon.set_pixel_size(64)
        self.append(icon)

        # Label
        label = Gtk.Label(label=theme_data["name"])
        label.set_css_classes(["heading"])
        self.append(label)

        # Apply Button
        button = Gtk.Button(label="Apply")
        button.add_css_class("suggested-action")
        button.connect("clicked", lambda x: apply_callback(theme_data["id"]))
        self.append(button)

if __name__ == "__main__":
    app = ScopeOSControlCenter()
    app.run(sys.argv)
