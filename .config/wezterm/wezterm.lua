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
    default_cursor_style = "BlinkingBar",
    color_scheme = "Tokyo Night (Gogh)",
    font = wezterm.font("JetBrains Mono", { weight = "Bold" }),
    font_size = 12.5,
    use_ime = true,
}

local mux = wezterm.mux
wezterm.on("gui-startup", function(cmd)
    local tab, pane, window = mux.spawn_window(cmd or {})
    window:gui_window():toggle_fullscreen()
end)

return config