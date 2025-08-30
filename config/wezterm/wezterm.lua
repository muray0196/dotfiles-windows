local wezterm = require 'wezterm'
local cfg = wezterm.config_builder()

-- 見た目/操作
cfg.window_decorations = 'INTEGRATED_BUTTONS'
cfg.window_background_opacity = 0.95
cfg.text_background_opacity = 0.95
cfg.animation_fps = 60
cfg.win32_system_backdrop = "Disable"
cfg.default_cursor_style = "BlinkingBar"
cfg.cursor_blink_rate = 500
cfg.cursor_blink_ease_in = 'Constant'
cfg.cursor_blink_ease_out = 'Constant'

cfg.colors = {
    tab_bar = {
        inactive_tab_edge = "None"
    }
}
cfg.inactive_pane_hsb = {
    saturation = 0.9,
    brightness = 0.8,
}

-- フォント
cfg.font = wezterm.font("JetBrainsMonoNL NF Medium")
cfg.font_size = 13

-- 既定シェル/ディレクトリ
cfg.default_prog = {'pwsh.exe','-NoLogo'}
cfg.default_cwd  = os.getenv('USERPROFILE')

cfg.launch_menu = {
  { label = 'PowerShell 7',       args = { 'pwsh.exe', '-NoLogo' },   domain = { DomainName = 'local' } },
  { label = 'Command Prompt',     args = { 'cmd.exe' },               domain = { DomainName = 'local' } },
}

cfg.check_for_updates = false

return cfg
