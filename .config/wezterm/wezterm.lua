local wezterm = require "wezterm"

local config = wezterm.config_builder()

config = {
    automatically_reload_config = true,
    enable_tab_bar = false,
    window_close_confirmation = "NeverPrompt",
    window_decoration = "RESIZE", -- disable the title bar but enable the resizable border
}

return config