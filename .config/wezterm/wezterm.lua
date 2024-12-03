local wezterm = require "wezterm"

local config = wezterm.config_builder()

config = {
    automatically_reload_config = true,
    enable_tab_bar = false,
}

return config