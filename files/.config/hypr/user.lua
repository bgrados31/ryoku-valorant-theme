-- Valorant theme for Hyprland. Loaded last, so it wins over Ryoku Settings.
-- Sharp corners, tight gaps, and a red / cream / dark-red border that slowly rotates (no blue).

hl.config({
  decoration = { rounding = 0 },
  general = { border_size = 2, gaps_in = 5, gaps_out = 10 },
})

-- animated gradient border (fixed palette: it does not follow the wallpaper).
-- The cream stop gives the contrast that makes the rotation readable; inactive is a neutral graphite.
hl.config({ general = { ["col.active_border"] = { colors = { "rgb(ff4655)", "rgb(ece8e1)", "rgb(bd3944)", "rgb(ff4655)" }, angle = 45 },
                        ["col.inactive_border"] = "rgb(2a2c2e)" } })
-- Ryoku's generated settings.lua may turn borderangle back off, so re-enable it here.
-- speed 50 = one turn every ~5 s (same as borderAngleSpeed 6 in desktop.json: 110 - 10*6).
hl.animation({ leaf = "borderangle", enabled = true, speed = 50, bezier = "linear", style = "loop" })
