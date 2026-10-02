-- Valorant theme for Hyprland. Loaded last, so it wins over Ryoku Settings.
-- Sharp corners, tight gaps, and a red <-> teal border that slowly rotates.

hl.config({
  decoration = { rounding = 0 },
  general = { border_size = 2, gaps_in = 5, gaps_out = 10 },
})

-- animated gradient border (fixed palette: it does not follow the wallpaper)
hl.config({ general = { ["col.active_border"] = { colors = { "rgb(ff4655)", "rgb(3dd6c6)", "rgb(ff4655)" }, angle = 45 },
                        ["col.inactive_border"] = "rgb(1f2a36)" } })
-- Ryoku's generated settings.lua turns borderangle back off after the animated-border switch
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })
