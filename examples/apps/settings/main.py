#!/usr/bin/env python3
"""GLITCH//CORE Settings — first GTK3 desktop application prototype.

This UI is an early frontend prototype. Controls only change this window's
preview; they do not yet modify system-wide GLITCH//CORE configuration.
"""

from __future__ import annotations

import sys

try:
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gdk, GLib
except (ImportError, ValueError) as exc:
    print(
        "GLITCH Settings requires Python 3 with PyGObject and GTK 3. "
        "These desktop dependencies are not bundled with the current rescue ISO.",
        file=sys.stderr,
    )
    raise SystemExit(2) from exc


CSS = b"""
window { background: #0b1020; color: #edf2ff; }
.header { background: #111a30; border-bottom: 1px solid #263653; padding: 16px 22px; }
.brand { color: #f4f7ff; font-size: 18px; font-weight: 800; }
.subtitle { color: #8fa5c8; font-size: 11px; }
.sidebar { background: #0e172b; padding: 18px 12px; }
.nav-button { background: transparent; color: #b8c8e6; border: 0; border-radius: 9px; padding: 11px 13px; text-align: left; }
.nav-button:hover { background: #1b2a49; color: #ffffff; }
.nav-active { background: #243a66; color: #ffffff; }
.content { padding: 28px 32px; }
.page-title { color: #f4f7ff; font-size: 25px; font-weight: 750; }
.page-description { color: #91a5c5; font-size: 13px; }
.panel { background: #121e35; border: 1px solid #263958; border-radius: 13px; padding: 18px; }
.panel-title { color: #edf2ff; font-size: 14px; font-weight: 700; }
.panel-description { color: #91a5c5; font-size: 12px; }
.accent { color: #55c8ff; }
.status { color: #8de0c0; font-size: 12px; }
button.action { background: #2858a6; color: white; border: 0; border-radius: 8px; padding: 9px 14px; }
button.action:hover { background: #3472d0; }
switch { margin: 4px; }
"""

LIGHT_CSS = b"""
window { background: #edf3ff; color: #14213a; }
.header, .sidebar { background: #ffffff; }
.brand, .page-title, .panel-title { color: #14213a; }
.subtitle, .page-description, .panel-description { color: #536987; }
.panel { background: #ffffff; border-color: #cbd8eb; }
.nav-button { color: #344a6b; }
.nav-button:hover { background: #e5edfb; color: #14213a; }
.nav-active { background: #d9e8ff; color: #164a91; }
"""

ACCENTS = {
    "Blue": "#55c8ff",
    "Purple": "#b38cff",
    "Pink": "#ff83c8",
    "Electric blue": "#287bff",
}


class SettingsWindow(Gtk.ApplicationWindow):
    def __init__(self, app: Gtk.Application):
        super().__init__(application=app, title="GLITCH//CORE Settings")
        self.set_default_size(900, 620)
        self.set_size_request(680, 480)
        self.dark = True
        self.accent = "Blue"
        self.provider = Gtk.CssProvider()
        self.display = Gdk.Display.get_default()
        Gtk.StyleContext.add_provider_for_display(
            self.display, self.provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
        self.provider.load_from_data(CSS)

        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        self.add(outer)
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        header.get_style_context().add_class("header")
        brand = Gtk.Label(label="GLITCH//CORE")
        brand.get_style_context().add_class("brand")
        header.pack_start(brand, False, False, 0)
        tagline = Gtk.Label(label="SYSTEM SETTINGS")
        tagline.get_style_context().add_class("subtitle")
        header.pack_start(tagline, False, False, 2)
        header.pack_end(Gtk.Label(label="DEVELOPER PREVIEW"), False, False, 0)
        outer.pack_start(header, False, False, 0)

        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        outer.pack_start(body, True, True, 0)
        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=7)
        sidebar.set_size_request(190, -1)
        sidebar.get_style_context().add_class("sidebar")
        body.pack_start(sidebar, False, False, 0)

        self.pages = Gtk.Stack()
        self.pages.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.pages.set_transition_duration(130)
        body.pack_start(self.pages, True, True, 0)

        for key, label in (
            ("system", "◈   System"),
            ("appearance", "◐   Appearance"),
            ("about", "ⓘ   About"),
        ):
            button = Gtk.Button(label=label)
            button.set_relief(Gtk.ReliefStyle.NONE)
            button.get_style_context().add_class("nav-button")
            button.connect("clicked", self.navigate, key)
            sidebar.pack_start(button, False, False, 0)
            if key == "system":
                button.get_style_context().add_class("nav-active")

        self.pages.add_named(self.build_system_page(), "system")
        self.pages.add_named(self.build_appearance_page(), "appearance")
        self.pages.add_named(self.build_about_page(), "about")
        self.pages.set_visible_child_name("system")

        footer = Gtk.Label(label="GLITCH//CORE • Early application preview")
        footer.get_style_context().add_class("subtitle")
        footer.set_xalign(0)
        footer.set_margin_start(18)
        footer.set_margin_top(8)
        footer.set_margin_bottom(10)
        outer.pack_end(footer, False, False, 0)

    def page_shell(self, title: str, description: str) -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        box.set_margin_top(30)
        box.set_margin_bottom(26)
        box.set_margin_start(34)
        box.set_margin_end(34)
        heading = Gtk.Label(label=title)
        heading.set_xalign(0)
        heading.get_style_context().add_class("page-title")
        box.pack_start(heading, False, False, 0)
        intro = Gtk.Label(label=description)
        intro.set_xalign(0)
        intro.set_line_wrap(True)
        intro.get_style_context().add_class("page-description")
        box.pack_start(intro, False, False, 0)
        return box

    def panel(self, title: str, description: str) -> Gtk.Box:
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.get_style_context().add_class("panel")
        heading = Gtk.Label(label=title)
        heading.set_xalign(0)
        heading.get_style_context().add_class("panel-title")
        box.pack_start(heading, False, False, 0)
        detail = Gtk.Label(label=description)
        detail.set_xalign(0)
        detail.set_line_wrap(True)
        detail.get_style_context().add_class("panel-description")
        box.pack_start(detail, False, False, 0)
        return box

    def build_system_page(self) -> Gtk.Widget:
        page = self.page_shell("System", "An overview of this GLITCH//CORE environment.")
        card = self.panel("System information", "Distribution: GLITCH//CORE\nArchitecture target: x86_64\nDesktop target: MATE\nCurrent milestone: desktop development")
        page.pack_start(card, False, False, 0)
        notice = self.panel("Development status", "This is an early UI prototype. System information is currently project metadata, not live hardware detection.")
        page.pack_start(notice, False, False, 0)
        return page

    def build_appearance_page(self) -> Gtk.Widget:
        page = self.page_shell("Appearance", "Personalise this preview window. These options are not yet saved system-wide.")
        theme = self.panel("Color scheme", "Choose a light or dark preview.")
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        row.pack_start(Gtk.Label(label="Dark appearance"), False, False, 0)
        switch = Gtk.Switch()
        switch.set_active(True)
        switch.set_halign(Gtk.Align.END)
        switch.set_hexpand(True)
        switch.connect("notify::active", self.on_theme_changed)
        row.pack_start(switch, True, True, 0)
        theme.pack_start(row, False, False, 5)
        page.pack_start(theme, False, False, 0)

        accent = self.panel("Accent color", "Choose the highlight color used by this preview.")
        choices = Gtk.ComboBoxText()
        for name in ACCENTS:
            choices.append_text(name)
        choices.set_active(0)
        choices.connect("changed", self.on_accent_changed)
        accent.pack_start(choices, False, False, 5)
        page.pack_start(accent, False, False, 0)
        return page

    def build_about_page(self) -> Gtk.Widget:
        page = self.page_shell("About", "The experimental Linux distribution and its application ecosystem.")
        card = self.panel("GLITCH//CORE", "An independent x86_64 Linux distribution project.\nPlanned base: Linux From Scratch 13.1-systemd\nPrimary desktop: MATE\nApplication package prototype: GCPKG v1")
        page.pack_start(card, False, False, 0)
        card2 = self.panel("Built for experimentation", "This application is part of the first GLITCH SDK examples. More system integration will arrive as the desktop stack becomes buildable.")
        page.pack_start(card2, False, False, 0)
        return page

    def navigate(self, _button: Gtk.Button, page: str) -> None:
        self.pages.set_visible_child_name(page)

    def on_theme_changed(self, switch: Gtk.Switch, _property: object) -> None:
        self.dark = switch.get_active()
        self.apply_theme()

    def on_accent_changed(self, combo: Gtk.ComboBoxText) -> None:
        selected = combo.get_active_text()
        if selected in ACCENTS:
            self.accent = selected
            self.apply_theme()

    def apply_theme(self) -> None:
        base = CSS if self.dark else LIGHT_CSS
        accent_css = (
            "\n.accent { color: " + ACCENTS[self.accent] + "; }"
        ).encode("utf-8")
        self.provider.load_from_data(base + accent_css)


class SettingsApp(Gtk.Application):
    def __init__(self):
        super().__init__(
            application_id="org.glitchcore.Settings",
            flags=0,
        )

    def do_activate(self) -> None:
        window = self.props.active_window
        if window is None:
            window = SettingsWindow(self)
        window.show_all()
        window.present()


def main() -> int:
    app = SettingsApp()
    return app.run(sys.argv)


if __name__ == "__main__":
    raise SystemExit(main())
