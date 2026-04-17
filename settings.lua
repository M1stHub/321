repeat wait() until game:IsLoaded()
wait(15)
local function ensureOff(secondBtn)
    if not secondBtn then return end
    local c = secondBtn.BackgroundColor3
    if not (math.floor(c.R * 255) == 255 and math.floor(c.G * 255) == 79 and math.floor(c.B * 255) == 79) then
        if secondBtn.Activated then firesignal(secondBtn.Activated) end
        task.wait(0.1)
        c = secondBtn.BackgroundColor3
        if not (math.floor(c.R * 255) == 255 and math.floor(c.G * 255) == 79 and math.floor(c.B * 255) == 79) then
            if secondBtn.Activated then firesignal(secondBtn.Activated) end
        end
    end
end

local function ensureFastModeOn(firstBtn)
    if not firstBtn then return end
    local c = firstBtn.BackgroundColor3
    if not (math.floor(c.R * 255) == 50 and math.floor(c.G * 255) == 185 and math.floor(c.B * 255) == 65) then
        if firstBtn.Activated then firesignal(firstBtn.Activated) end
        task.wait(0.1)
        c = firstBtn.BackgroundColor3
        if not (math.floor(c.R * 255) == 50 and math.floor(c.G * 255) == 185 and math.floor(c.B * 255) == 65) then
            if firstBtn.Activated then firesignal(firstBtn.Activated) end
        end
    end
end

local pg = game:GetService("Players").LocalPlayer.PlayerGui.Main.SettingsMenu.Content.ScrollingFrame

ensureOff(pg.CameraShake and pg.CameraShake.SecondButton)
ensureOff(pg.BackgroundMusic and pg.BackgroundMusic.SecondButton)
ensureOff(pg.AllyVFX and pg.AllyVFX.SecondButton)
ensureOff(pg.DamageCounter and pg.DamageCounter.SecondButton)
ensureFastModeOn(pg.FastMode and pg.FastMode.FirstButton)
