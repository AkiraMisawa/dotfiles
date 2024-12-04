local wezterm = require "wezterm"

local config = wezterm.config_builder()

config = {
    automatically_reload_config = true,
    window_close_confirmation = "NeverPrompt",
    window_decorations = "RESIZE", -- disable the title bar but enable the resizable border
    hide_tab_bar_if_only_one_tab = true,
    window_frame = {
        inactive_titlebar_bg = "none",
        active_titlebar_bg = "none",
    },
    window_background_gradient = {
        colors = { "#000000" },
    },
    window_background_opacity = 0.85,
    show_new_tab_button_in_tab_bar = false,
    default_cursor_style = "BlinkingBar",
    color_scheme = "Tokyo Night (Gogh)",
    font = wezterm.font("JetBrains Mono", { weight = "Bold" }),
    font_size = 12.5,
    use_ime = true,
    colors = {
        tab_bar = {
            inactive_tab_edge = "none",
        },
    }
}

local mux = wezterm.mux
wezterm.on("gui-startup", function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():toggle_fullscreen()
end)

local SOLID_LEFT_ARROW = wezterm.nerdfonts.ple_lower_right_triangle
local SOLID_RIGHT_ARROW = wezterm.nerdfonts.ple_upper_left_triangle

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
    local background = "#5c6d74"
    local foreground = "#FFFFFF"
    local edge_background = "none"

    if tab.is_active then
        background = "#ae8b2d"
        foreground = "#FFFFFF"
    end
    local edge_foreground = background

    local title = "   " .. wezterm.truncate_right(tab.active_pane.title, max_width - 1) .. "   "

    return {
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_LEFT_ARROW },
        { Background = { Color = background } },
        { Foreground = { Color = foreground } },
        { Text = title },
        { Background = { Color = edge_background } },
        { Foreground = { Color = edge_foreground } },
        { Text = SOLID_RIGHT_ARROW },
    }
end)

config.keys = require("keybinds").keys
config.key_tables = require("keybinds").key_tables

return config
