-- WezTerm configuration
local wezterm = require 'wezterm'
local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Font
config.font = wezterm.font('Berkeley Mono Variable NNIX')
config.font_size = 14

-- Default Terminal Size
config.initial_cols = 120
config.initial_rows = 50

-- Transparency
config.window_background_opacity = 0.7
config.macos_window_background_blur = 20

-- Color Scheme
config.colors = {
  foreground = '#d0d0d0',
  background = '#000000',
  cursor_bg = '#d0d0d0',
  cursor_border = '#d0d0d0',
  cursor_fg = '#000000',
  selection_bg = '#404040',
  selection_fg = '#d0d0d0',

  ansi = {
    '#1a1a1a',  -- black
    '#808080',  -- red (gray)
    '#a0a0a0',  -- green (light gray)
    '#909090',  -- yellow (gray)
    '#707070',  -- blue (gray)
    '#888888',  -- magenta (gray)
    '#959595',  -- cyan (light gray)
    '#d0d0d0',  -- white (light gray)
  },

  brights = {
    '#404040',  -- bright black
    '#a0a0a0',  -- bright red (light gray)
    '#c0c0c0',  -- bright green (lighter gray)
    '#b0b0b0',  -- bright yellow (light gray)
    '#909090',  -- bright blue (gray)
    '#a8a8a8',  -- bright magenta (light gray)
    '#b5b5b5',  -- bright cyan (light gray)
    '#e0e0e0',  -- bright white (almost white)
  },
}

-- Performance
config.front_end = 'WebGpu'
config.max_fps = 120
config.animation_fps = 60

-- Window
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}
config.window_decorations = 'RESIZE'
config.window_close_confirmation = 'NeverPrompt'
config.adjust_window_size_when_changing_font_size = false

-- Tab bar
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.tab_bar_at_bottom = true
config.tab_max_width = 32

-- Scrollback
config.scrollback_lines = 10000

-- Cursor
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 500

-- Misc
config.check_for_updates = false
config.automatically_reload_config = true
config.audible_bell = 'Disabled'

-- Key bindings
config.keys = {
  -- Split panes
  { key = 'd', mods = 'CMD', action = wezterm.action.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'd', mods = 'CMD|SHIFT', action = wezterm.action.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- Navigate panes
  { key = 'h', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Left' },
  { key = 'j', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Down' },
  { key = 'k', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Up' },
  { key = 'l', mods = 'CMD', action = wezterm.action.ActivatePaneDirection 'Right' },

  -- Close pane
  { key = 'w', mods = 'CMD', action = wezterm.action.CloseCurrentPane { confirm = false } },

  -- Zoom pane
  { key = 'z', mods = 'CMD', action = wezterm.action.TogglePaneZoomState },

  -- Clear scrollback
  { key = 'k', mods = 'CMD|SHIFT', action = wezterm.action.ClearScrollback 'ScrollbackAndViewport' },
}

return config
