-- ============================================================
-- nevertusukoh | Neverlose.Lua
-- repo: sorokinvova27042016-ops/Neverlose (main)
-- injector: Xeno
-- ============================================================

if _G.__nevertusukoh_loaded then
    warn("[nevertusukoh] already loaded, skipping")
    return
end
_G.__nevertusukoh_loaded = true

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local LocalPlayer      = Players.LocalPlayer
local Camera           = Workspace.CurrentCamera

-- ============================================================
-- CONFIG
-- ============================================================
local CFG_FILE = "nevertusukoh_cfg.txt"

local Defaults = {
    accent = {0, 255, 140},

    espEnabled = true,
    espBox = true,
    espName = true,
    espHealth = true,
    espDistance = true,
    espTracer = false,
    espWeapon = true,
    colorMurderer = {255, 40, 40},
    colorSheriff  = {40, 120, 255},
    colorInnocent = {220, 220, 220},
    colorWeapon   = {255, 210, 40},
    espMaxDist = 500,

    aimEnabled = false,
    aimKey = "E",
    aimFov = 120,
    aimSmooth = 6,
    aimPart = "Head",
    aimWallCheck = true,
    aimRoleFilter = "Murderer",
    targetIndicator = true,

    bhopEnabled = false,
    bhopKey = "Space",
    bhopChance = 100,
    bhopMinSpeed = 5,

    spinEnabled = false,
    spinKey = "Q",
    spinSpeed = 720,
    spinDir = 1,
    spinJitter = false,

    walkSpeed = 16,
    jumpPower = 50,
    speedEnabled = false,
    jumpEnabled = false,

    skyEnabled = false,
    skyColorR = 20,
    skyColorG = 40,
    skyColorB = 120,

    particlesEnabled = false,
    particleCount = 40,
    particleColorR = 0,
    particleColorG = 255,
    particleColorB = 140,
    particleSize = 1.0,
}

local Cfg = {}
for k, v in pairs(Defaults) do
    if type(v) == "table" then
        Cfg[k] = {v[1], v[2], v[3]}
    else
        Cfg[k] = v
    end
end

-- ============================================================
-- CONFIG IO
-- ============================================================
local function serializeCfg()
    local lines = {"-- nevertusukoh config v1"}
    for k, v in pairs(Cfg) do
        if type(v) == "table" then
            lines[#lines + 1] = string.format("%s=%d,%d,%d", k, v[1], v[2], v[3])
        else
            lines[#lines + 1] = string.format("%s=%s", k, tostring(v))
        end
    end
    return table.concat(lines, "\n")
end

local function parseValue(s)
    if s == "true" then return true end
    if s == "false" then return false end
    local n = tonumber(s)
    if n then return n end
    return s
end

local function loadCfg()
    if not (isfile and isfile(CFG_FILE)) then return end
    local ok, data = pcall(readfile, CFG_FILE)
    if not ok or not data then return end
    for line in data:gmatch("[^\r\n]+") do
        if not line:match("^%-%-") then
            local k, v = line:match("^(%w+)=(.*)$")
            if k and v then
                if v:match("^%d+,%d+,%d+$") then
                    local r, g, b = v:match("^(%d+),(%d+),(%d+)$")
                    Cfg[k] = {tonumber(r), tonumber(g), tonumber(b)}
                else
                    Cfg[k] = parseValue(v)
                end
            end
        end
    end
end

local function saveCfg()
    if writefile then
        pcall(writefile, CFG_FILE, serializeCfg())
    end
end

loadCfg()

-- ============================================================
-- DRAWING
-- ============================================================
local function newDrawing(class, props)
    local d = Drawing.new(class)
    for k, v in pairs(props) do d[k] = v end
    return d
end

local function rgb(t) return Color3.fromRGB(t[1], t[2], t[3]) end
local Accent = rgb(Cfg.accent)

local hasDrawing = pcall(function() return Drawing.new("Square") end)
if not hasDrawing then
    warn("[nevertusukoh] Drawing API недоступен")
    return
end

-- ============================================================
-- MENU STATE
-- ============================================================
local Menu = {
    open = false,
    anim = 0,
    x = 120, y = 120,
    w = 520, h = 420,
    tab = "Visuals",
    dragging = false,
    dragOffset = Vector2.new(),
    tabs = {"Visuals", "Aimbot", "Movement", "Effects", "Settings"},
    tabButtons = {},
    items = {},
    yCursor = {Visuals = 62, Aimbot = 62, Movement = 62, Effects = 62, Settings = 62},
}

local menuBg     = newDrawing("Square", {Size = Vector2.new(Menu.w, Menu.h), Filled = true, Color = Color3.fromRGB(16,16,18), Transparency = 1})
local menuBorder = newDrawing("Square", {Size = Vector2.new(Menu.w, Menu.h), Filled = false, Thickness = 1, Color = Accent, Transparency = 1})
local menuTitle  = newDrawing("Text", {Size = 18, Text = "nevertusukoh", Color = Accent, Outline = true, Font = 2, Transparency = 1})
local menuVer    = newDrawing("Text", {Size = 12, Text = "v1.1 | xeno", Color = Color3.fromRGB(140,140,140), Font = 0, Transparency = 1})
local sidebarBg  = newDrawing("Square", {Size = Vector2.new(140, Menu.h - 40), Filled = true, Color = Color3.fromRGB(22,22,25), Transparency = 1})
local watermark  = newDrawing("Text", {Size = 14, Text = "nevertusukoh", Color = Accent, Outline = true, Font = 2, Transparency = 1})

for _, name in ipairs(Menu.tabs) do
    local label = newDrawing("Text", {Size = 15, Text = name, Color = Color3.fromRGB(180,180,180), Font = 1, Transparency = 1})
    local sel   = newDrawing("Square", {Size = Vector2.new(3, 20), Filled = true, Color = Accent, Transparency = 1})
    Menu.tabButtons[name] = {label = label, sel = sel, active = (name == Menu.tab)}
end

local function baseX() return Menu.x + 156 end

local function setMenuPos(x, y)
    Menu.x, Menu.y = x, y
    menuBg.Position     = Vector2.new(x, y)
    menuBorder.Position = Vector2.new(x, y)
    menuTitle.Position  = Vector2.new(x + 14, y + 10)
    menuVer.Position    = Vector2.new(x + 14, y + 32)
    sidebarBg.Position  = Vector2.new(x, y + 52)
    for i, name in ipairs(Menu.tabs) do
        local btn = Menu.tabButtons[name]
        btn.label.Position = Vector2.new(x + 14, y + 62 + (i - 1) * 34)
        btn.sel.Position   = Vector2.new(x + 2,  y + 62 + (i - 1) * 34 + 2)
    end
    for _, item in ipairs(Menu.items) do item.refresh() end
end

local function refreshItemVisibility(item)
    local v = Menu.open and Menu.anim > 0.95 and item.tab == Menu.tab
    item.setVisible(v)
end

local function switchTab(name)
    Menu.tab = name
    for tabName, btn in pairs(Menu.tabButtons) do
        btn.active = (tabName == name)
        btn.label.Color = btn.active and Accent or Color3.fromRGB(180,180,180)
        btn.sel.Visible = Menu.open and btn.active
    end
    for _, item in ipairs(Menu.items) do refreshItemVisibility(item) end
end

local function toggleMenu()
    Menu.open = not Menu.open
end

local function updateMenuAnim(dt)
    local target = Menu.open and 1 or 0
    Menu.anim = Menu.anim + (target - Menu.anim) * math.clamp(dt * 14, 0, 1)
    if math.abs(target - Menu.anim) < 0.001 then Menu.anim = target end

    local a = Menu.anim
    local visible = a > 0.01
    local offsetY = (1 - a) * 30
    local cx, cy  = Menu.x, Menu.y + offsetY

    menuBg.Visible     = visible
    menuBorder.Visible = visible
    menuTitle.Visible  = visible
    menuVer.Visible    = visible
    sidebarBg.Visible  = visible

    menuBg.Position     = Vector2.new(cx, cy)
    menuBorder.Position = Vector2.new(cx, cy)
    menuTitle.Position  = Vector2.new(cx + 14, cy + 10)
    menuVer.Position    = Vector2.new(cx + 14, cy + 32)
    sidebarBg.Position  = Vector2.new(cx, cy + 52)

    menuBg.Transparency     = 1 - a
    menuBorder.Transparency = 1 - a * 0.6
    menuTitle.Transparency  = 1 - a
    menuVer.Transparency    = 1 - a
    sidebarBg.Transparency  = 1 - a * 0.8

    for i, name in ipairs(Menu.tabs) do
        local btn = Menu.tabButtons[name]
        btn.label.Visible = visible
        btn.sel.Visible   = visible and btn.active
        btn.label.Position = Vector2.new(cx + 14, cy + 62 + (i - 1) * 34)
        btn.sel.Position   = Vector2.new(cx + 2,  cy + 62 + (i - 1) * 34 + 2)
        btn.label.Transparency = 1 - a
        btn.sel.Transparency = 1 - a * 0.8
    end

    for _, item in ipairs(Menu.items) do refreshItemVisibility(item) end

    watermark.Visible = visible
    watermark.Transparency = 1 - a
end

-- ============================================================
-- ITEM FACTORY
-- ============================================================
local function addToggle(tab, text, key)
    local label = newDrawing("Text", {Size = 14, Text = text, Color = Color3.fromRGB(220,220,220), Font = 0, Transparency = 1})
    local box   = newDrawing("Square", {Size = Vector2.new(14,14), Filled = false, Thickness = 1, Color = Color3.fromRGB(120,120,120), Transparency = 1})
    local fill  = newDrawing("Square", {Size = Vector2.new(10,10), Filled = true, Color = Accent, Transparency = 1})

    local item = {tab = tab, kind = "toggle", key = key, label = label, box = box, fill = fill}
    item.refresh = function()
        local y = Menu.y + Menu.yCursor[tab]
        local x = baseX()
        label.Position = Vector2.new(x, y)
        box.Position   = Vector2.new(x + 300, y)
        fill.Position  = Vector2.new(x + 302, y + 2)
        fill.Visible   = Cfg[key]
    end
    item.setVisible = function(v)
        label.Visible = v; box.Visible = v; fill.Visible = v and Cfg[key]
    end
    Menu.yCursor[tab] = Menu.yCursor[tab] + 26
    Menu.items[#Menu.items + 1] = item
end

local function addSlider(tab, text, key, min, max, step)
    local label = newDrawing("Text", {Size = 14, Text = text, Color = Color3.fromRGB(220,220,220), Font = 0, Transparency = 1})
    local val   = newDrawing("Text", {Size = 14, Text = tostring(Cfg[key]), Color = Accent, Font = 0, Transparency = 1})
    local track = newDrawing("Square", {Size = Vector2.new(160,3), Filled = true, Color = Color3.fromRGB(60,60,65), Transparency = 1})
    local fill  = newDrawing("Square", {Size = Vector2.new(0,3), Filled = true, Color = Accent, Transparency = 1})
    local knob  = newDrawing("Circle", {Radius = 5, Filled = true, Color = Accent, Transparency = 1})

    local function update()
        local p = (Cfg[key] - min) / (max - min)
        fill.Size = Vector2.new(160 * p, 3)
        knob.Position = Vector2.new(track.Position.X + 160 * p, track.Position.Y + 1.5)
    end

    local item = {tab = tab, kind = "slider", key = key, min = min, max = max, step = step,
                  label = label, val = val, track = track, fill = fill, knob = knob}
    item.refresh = function()
        local y = Menu.y + Menu.yCursor[tab]
        local x = baseX()
        label.Position = Vector2.new(x, y)
        val.Position   = Vector2.new(x + 200, y)
        track.Position = Vector2.new(x + 10, y + 22)
        update()
    end
    item.setVisible = function(v)
        label.Visible = v; val.Visible = v; track.Visible = v; fill.Visible = v; knob.Visible = v
    end
    item.setValue = function(pos)
        local p = math.clamp((pos.X - track.Position.X) / 160, 0, 1)
        local raw = min + p * (max - min)
        if step then raw = math.floor(raw / step + 0.5) * step end
        Cfg[key] = raw
        val.Text = tostring(raw)
        update()
    end
    item.hit = function(pos)
        local p = track.Position
        return pos.X >= p.X - 6 and pos.X <= p.X + 166 and pos.Y >= p.Y - 8 and pos.Y <= p.Y + 14
    end
    Menu.yCursor[tab] = Menu.yCursor[tab] + 40
    Menu.items[#Menu.items + 1] = item
end

-- ============================================================
-- MM2 ROLE / ESP
-- ============================================================
local espCache = {}

local function roleColor(role)
    if role == "Murderer" then return rgb(Cfg.colorMurderer) end
    if role == "Sheriff"  then return rgb(Cfg.colorSheriff)  end
    return rgb(Cfg.colorInnocent)
end

local function getRole(player)
    local char = player.Character
    if not char then return "Innocent" end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then
        local n = tool.Name:lower()
        if n:find("knife") or n:find("sword") or n:find("blade") then return "Murderer" end
        if n:find("gun") or n:find("revolver") or n:find("pistol") then return "Sheriff" end
    end
    return "Innocent"
end

local function createEsp(player)
    local e = {
        box = newDrawing("Square", {Thickness = 1, Filled = false, Visible = false}),
        name = newDrawing("Text", {Size = 13, Center = true, Outline = true, Font = 1, Visible = false}),
        dist = newDrawing("Text", {Size = 12, Center = true, Outline = true, Font = 0, Visible = false}),
        tracer = newDrawing("Line", {Thickness = 1, Visible = false}),
        hbg = newDrawing("Square", {Filled = true, Color = Color3.fromRGB(40,40,40), Visible = false}),
        hfg = newDrawing("Square", {Filled = true, Visible = false}),
    }
    espCache[player] = e
    return e
end

local weaponEsp = {
    label = newDrawing("Text", {Size = 13, Center = true, Outline = true, Font = 1, Visible = false}),
    box   = newDrawing("Square", {Thickness = 1, Filled = false, Visible = false}),
}

local function updateEsp()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local e = espCache[player] or createEsp(player)
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local show = Cfg.espEnabled and hrp and hum and hum.Health > 0
            local dist = show and (Camera.CFrame.Position - hrp.Position).Magnitude or 0
            if show and dist > Cfg.espMaxDist then show = false end
            if show then
                local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                local bot = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                local _, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local h = math.abs(top.Y - bot.Y)
                    local w = h * 0.55
                    local x = top.X - w / 2
                    local y = top.Y
                    local role = getRole(player)
                    local col = roleColor(role)

                    e.box.Visible = Cfg.espBox
                    e.box.Position = Vector2.new(x, y)
                    e.box.Size = Vector2.new(w, h)
                    e.box.Color = col

                    e.name.Visible = Cfg.espName
                    e.name.Text = player.Name .. " [" .. role .. "]"
                    e.name.Position = Vector2.new(top.X, y - 16)
                    e.name.Color = col

                    e.dist.Visible = Cfg.espDistance
                    e.dist.Text = string.format("%d m", dist)
                    e.dist.Position = Vector2.new(top.X, y + h + 2)
                    e.dist.Color = col

                    e.tracer.Visible = Cfg.espTracer
                    e.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    e.tracer.To = Vector2.new(top.X, y + h)
                    e.tracer.Color = col

                    local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    e.hbg.Visible = Cfg.espHealth
                    e.hbg.Position = Vector2.new(x - 6, y)
                    e.hbg.Size = Vector2.new(3, h)
                    e.hfg.Visible = Cfg.espHealth
                    e.hfg.Position = Vector2.new(x - 6, y + h * (1 - frac))
                    e.hfg.Size = Vector2.new(3, h * frac)
                    e.hfg.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 0)
                else
                    for _, d in pairs(e) do d.Visible = false end
                end
            else
                for _, d in pairs(e) do d.Visible = false end
            end
        end
    end

    weaponEsp.label.Visible = false
    weaponEsp.box.Visible = false
    if Cfg.espWeapon then
        local closest, closestDist
        for _, obj in ipairs(Workspace:GetDescendants()) do
            if obj:IsA("Tool") then
                local n = obj.Name:lower()
                if n:find("knife") or n:find("gun") or n:find("revolver") or n:find("pistol") then
                    local pos = obj:GetPivot().Position
                    local d = (Camera.CFrame.Position - pos).Magnitude
                    if not closestDist or d < closestDist then closest, closestDist = obj, d end
                end
            end
        end
        if closest and closestDist <= Cfg.espMaxDist then
            local sp, on = Camera:WorldToViewportPoint(closest:GetPivot().Position)
            if on then
                local col = rgb(Cfg.colorWeapon)
                weaponEsp.label.Visible = true
                weaponEsp.label.Text = closest.Name .. string.format(" [%d m]", closestDist)
                weaponEsp.label.Position = Vector2.new(sp.X, sp.Y)
                weaponEsp.label.Color = col
                weaponEsp.box.Visible = true
                weaponEsp.box.Position = Vector2.new(sp.X - 8, sp.Y - 8)
                weaponEsp.box.Size = Vector2.new(16, 16)
                weaponEsp.box.Color = col
            end
        end
    end
end

-- ============================================================
-- AIMBOT
-- ============================================================
local fovCircle = newDrawing("Circle", {Radius = Cfg.aimFov, Thickness = 1, Filled = false, Color = Accent, Visible = false})
local aimHeld = false

local function isKeyDown(name)
    local ok, kc = pcall(function() return Enum.KeyCode[name] end)
    if ok and kc then return UserInputService:IsKeyDown(kc) end
    return false
end

local function aimTarget()
    local best, bestDist = nil, math.huge
    local camPos = Camera.CFrame.Position
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local role = getRole(player)
            local passRole = (Cfg.aimRoleFilter == "All") or (role == Cfg.aimRoleFilter)
            local hrp = player.Character:FindFirstChild("HumanoidRootPart")
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if passRole and hrp and hum and hum.Health > 0 then
                local part = player.Character:FindFirstChild(Cfg.aimPart) or hrp
                local sp, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                    local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                    if d <= Cfg.aimFov and d < bestDist then
                        if Cfg.aimWallCheck then
                            local rp = RaycastParams.new()
                            rp.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
                            rp.FilterType = Enum.RaycastFilterType.Exclude
                            local hit = Workspace:Raycast(camPos, part.Position - camPos, rp)
                            if hit and hit.Instance:IsDescendantOf(player.Character) then
                                best, bestDist = part, d
                            end
                        else
                            best, bestDist = part, d
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ============================================================
-- TARGET INDICATOR (серая линия от ног до головы + круги)
-- ============================================================
local indicator = {
    line = newDrawing("Line", {Thickness = 1.5, Color = Color3.fromRGB(180,180,180), Visible = false}),
    head = newDrawing("Circle", {Radius = 6, Thickness = 1.5, Filled = false, Color = Color3.fromRGB(200,200,200), Visible = false}),
    rings = {},
}
for i = 1, 3 do
    indicator.rings[i] = newDrawing("Circle", {Radius = 20 * i, Thickness = 1, Filled = false, Color = Color3.fromRGB(180,180,180), Visible = false})
end
local indicatorPhase = 0
local currentTargetPlayer = nil

local function updateIndicator(dt)
    if not Cfg.aimEnabled or not Cfg.targetIndicator then
        indicator.line.Visible = false
        indicator.head.Visible = false
        for i = 1, 3 do indicator.rings[i].Visible = false end
        currentTargetPlayer = nil
        return
    end

    local part = aimTarget()
    if not part then
        indicator.line.Visible = false
        indicator.head.Visible = false
        for i = 1, 3 do indicator.rings[i].Visible = false end
        currentTargetPlayer = nil
        return
    end

    -- находим игрока по part
    local targetPlayer = nil
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and part:IsDescendantOf(p.Character) then
            targetPlayer = p
            break
        end
    end
    currentTargetPlayer = targetPlayer
    if not targetPlayer then return end

    local char = targetPlayer.Character
    local headPart = char:FindFirstChild("Head")
    local footPart = char:FindFirstChild("HumanoidRootPart")
    if not headPart or not footPart then return end

    -- серая линия от ног до головы (в экранных координатах, вертикаль)
    local headScreen, headOn = Camera:WorldToViewportPoint(headPart.Position)
    local footScreen, footOn = Camera:WorldToViewportPoint(footPart.Position + Vector3.new(0, -2, 0))
    if headOn and footOn then
        indicator.line.Visible = true
        indicator.line.From = Vector2.new(headScreen.X, footScreen.Y)
        indicator.line.To   = Vector2.new(headScreen.X, headScreen.Y)
        indicator.line.Color = Color3.fromRGB(180,180,180)

        indicator.head.Visible = true
        indicator.head.Position = Vector2.new(headScreen.X, headScreen.Y)
        indicator.head.Color = Color3.fromRGB(200,200,200)
    end

    -- круги вокруг головы (вращаются)
    indicatorPhase = (indicatorPhase + dt * 180) % 360
    local baseY = (headScreen.Y + footScreen.Y) / 2
    for i = 1, 3 do
        local ring = indicator.rings[i]
        local phase = math.rad(indicatorPhase + i * 40)
        local radius = 20 + i * 10
        local rx = headScreen.X + math.cos(phase) * radius
        local ry = baseY + math.sin(phase) * radius * 0.35
        ring.Visible = headOn
        ring.Position = Vector2.new(rx, ry)
        ring.Radius = radius * 0.4
        ring.Color = Color3.fromRGB(180 - i * 20, 180 - i * 20, 180 - i * 20)
        ring.Thickness = 1
    end
end

-- ============================================================
-- EFFECTS: SKY + PARTICLES
-- ============================================================
local particlesFolder = nil
local particleEmitters = {}

local function applySky()
    if not Cfg.skyEnabled then return end
    for _, sky in ipairs(Lighting:GetChildren()) do
        if sky:IsA("Sky") then
            sky.SkyboxBk = ""
            sky.SkyboxDn = ""
            sky.SkyboxFt = ""
            sky.SkyboxLf = ""
            sky.SkyboxRt = ""
            sky.SkyboxUp = ""
            sky.StarCount = 0
            sky.CelestialBodiesShown = false
        end
    end
    Lighting.Ambient = Color3.fromRGB(Cfg.skyColorR, Cfg.skyColorG, Cfg.skyColorB)
    Lighting.OutdoorAmbient = Color3.fromRGB(Cfg.skyColorR // 2, Cfg.skyColorG // 2, Cfg.skyColorB // 2)
    Lighting.Brightness = 1.5
    Lighting.ClockTime = 0
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
end

local function resetSky()
    Lighting.Ambient = Color3.fromRGB(70, 70, 70)
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
    Lighting.FogEnd = 100000
    Lighting.FogStart = 0
    for _, sky in ipairs(Lighting:GetChildren()) do
        if sky:IsA("Sky") then
            pcall(function()
                sky.SkyboxBk = "rbxasset://textures/sky/sky512_bk.tex"
                sky.SkyboxDn = "rbxasset://textures/sky/sky512_dn.tex"
                sky.SkyboxFt = "rbxasset://textures/sky/sky512_ft.tex"
                sky.SkyboxLf = "rbxasset://textures/sky/sky512_lf.tex"
                sky.SkyboxRt = "rbxasset://textures/sky/sky512_rt.tex"
                sky.SkyboxUp = "rbxasset://textures/sky/sky512_up.tex"
            end)
        end
    end
end

local function clearParticles()
    if particlesFolder then
        particlesFolder:Destroy()
        particlesFolder = nil
    end
    particleEmitters = {}
end

local function spawnParticles()
    clearParticles()
    particlesFolder = Instance.new("Folder")
    particlesFolder.Name = "nevertusukoh_particles"
    particlesFolder.Parent = Workspace

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    for i = 1, Cfg.particleCount do
        local attach = Instance.new("Attachment")
        attach.Name = "nvk_p_" .. i
        attach.Parent = hrp

        local emit = Instance.new("ParticleEmitter")
        emit.Name = "nvk_emit_" .. i
        emit.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emit.Color = ColorSequence.new(Color3.fromRGB(Cfg.particleColorR, Cfg.particleColorG, Cfg.particleColorB))
        emit.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2 * Cfg.particleSize),
            NumberSequenceKeypoint.new(1, 0.8 * Cfg.particleSize),
        })
        emit.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2),
            NumberSequenceKeypoint.new(1, 1),
        })
        emit.Lifetime = NumberRange.new(0.6, 1.2)
        emit.Rate = 10
        emit.Speed = NumberRange.new(2, 5)
        emit.SpreadAngle = Vector2.new(180, 180)
        emit.LightEmission = 1
        emit.LightInfluence = 0
        emit.Parent = attach

        particleEmitters[i] = emit
    end
end

local function updateParticles()
    if Cfg.particlesEnabled then
        if not particlesFolder or not particlesFolder.Parent then
            spawnParticles()
        end
        local col = Color3.fromRGB(Cfg.particleColorR, Cfg.particleColorG, Cfg.particleColorB)
        for _, emit in ipairs(particleEmitters) do
            if emit.Parent then
                emit.Color = ColorSequence.new(col)
                emit.Size = NumberSequence.new({
                    NumberSequenceKeypoint.new(0, 0.2 * Cfg.particleSize),
                    NumberSequenceKeypoint.new(1, 0.8 * Cfg.particleSize),
                })
            end
        end
    else
        if particlesFolder then clearParticles() end
    end
end

-- отслеживаем респавн персонажа для частиц
LocalPlayer.CharacterAdded:Connect(function()
    clearParticles()
    if Cfg.particlesEnabled then
        task.wait(1)
        spawnParticles()
    end
end)

-- ============================================================
-- MOVEMENT: BHOP
-- ============================================================
local function doBhop()
    if not Cfg.bhopEnabled then return end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp or hum.Health <= 0 then return end
    if not isKeyDown(Cfg.bhopKey) then return end
    local speed = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
    if speed < Cfg.bhopMinSpeed then return end
    if hum.FloorMaterial ~= Enum.Material.Air then
        if math.random(1, 100) <= Cfg.bhopChance then
            hum.Jump = true
        end
    end
end

-- ============================================================
-- MOVEMENT: SPINBOT
-- ============================================================
local spinAngle = 0
local function doSpin(dt)
    if not Cfg.spinEnabled then return end
    if not isKeyDown(Cfg.spinKey) then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    if Cfg.spinJitter then
        spinAngle = math.random(0, 360)
    else
        spinAngle = (spinAngle + Cfg.spinSpeed * dt * Cfg.spinDir) % 360
    end

    local pos = hrp.Position
    local look = hrp.CFrame.LookVector
    local flat = Vector3.new(look.X, 0, look.Z)
    if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
    flat = flat.Unit
    local baseYaw = math.atan2(flat.X, -flat.Z)
    local newYaw = baseYaw + math.rad(spinAngle)
    hrp.CFrame = CFrame.new(pos) * CFrame.Angles(0, newYaw, 0)
end

-- ============================================================
-- MISC
-- ============================================================
local function applyMisc()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = Cfg.speedEnabled and Cfg.walkSpeed or 16
    hum.JumpPower = Cfg.jumpEnabled and Cfg.jumpPower or 50
    hum.UseJumpPower = true
end

-- ============================================================
-- INPUT
-- ============================================================
local function keyNameFromInput(input)
    return input.KeyCode and input.KeyCode.Name or nil
end

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    local key = keyNameFromInput(input)

    if key == "Insert" then
        toggleMenu()
        return
    end

    if not Menu.open or Menu.anim < 0.95 then return end

    if key == Cfg.aimKey then aimHeld = true end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local pos = UserInputService:GetMouseLocation()

        if pos.X >= Menu.x and pos.X <= Menu.x + Menu.w and pos.Y >= Menu.y and pos.Y <= Menu.y + 40 then
            Menu.dragging = true
            Menu.dragOffset = pos - Vector2.new(Menu.x, Menu.y)
            return
        end

        for tabName, btn in pairs(Menu.tabButtons) do
            local p = btn.label.Position
            if pos.X >= p.X - 4 and pos.X <= p.X + 100 and pos.Y >= p.Y - 2 and pos.Y <= p.Y + 18 then
                switchTab(tabName)
                return
            end
        end

        for _, item in ipairs(Menu.items) do
            if item.tab == Menu.tab then
                if item.kind == "toggle" then
                    local p = item.box.Position
                    if pos.X >= p.X and pos.X <= p.X + 16 and pos.Y >= p.Y and pos.Y <= p.Y + 16 then
                        Cfg[item.key] = not Cfg[item.key]
                        item.fill.Visible = Cfg[item.key]
                        if item.key == "skyEnabled" then
                            if Cfg.skyEnabled then applySky() else resetSky() end
                        end
                        if item.key == "particlesEnabled" then
                            if Cfg.particlesEnabled then spawnParticles() else clearParticles() end
                        end
                        saveCfg()
                        return
                    end
                elseif item.kind == "slider" and item.hit(pos) then
                    item.setValue(pos)
                    saveCfg()
                    return
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    local key = keyNameFromInput(input)
    if key == Cfg.aimKey then aimHeld = false end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        Menu.dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and Menu.dragging then
        local pos = UserInputService:GetMouseLocation()
        setMenuPos(pos.X - Menu.dragOffset.X, pos.Y - Menu.dragOffset.Y)
    end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
RunService.RenderStepped:Connect(function(dt)
    updateMenuAnim(dt)
    updateEsp()
    updateIndicator(dt)
    updateParticles()

    if watermark.Visible then
        local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
        local role = getRole(LocalPlayer)
        watermark.Text = string.format("nevertusukoh | %s | ping %d", role, ping)
        watermark.Position = Vector2.new(16, 16)
    end

    fovCircle.Visible = Cfg.aimEnabled
    fovCircle.Radius = Cfg.aimFov
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    fovCircle.Color = Accent

    if Cfg.aimEnabled and aimHeld then
        local target = aimTarget()
        if target then
            local camPos = Camera.CFrame.Position
            local desired = CFrame.new(camPos, target.Position)
            Camera.CFrame = Camera.CFrame:Lerp(desired, 1 / math.max(Cfg.aimSmooth, 1))
        end
    end

    doBhop()
    doSpin(dt)
    applyMisc()
end)

-- ============================================================
-- INIT MENU ITEMS
-- ============================================================
-- Visuals
addToggle("Visuals", "ESP Master", "espEnabled")
addToggle("Visuals", "Box", "espBox")
addToggle("Visuals", "Name", "espName")
addToggle("Visuals", "Health Bar", "espHealth")
addToggle("Visuals", "Distance", "espDistance")
addToggle("Visuals", "Tracer", "espTracer")
addToggle("Visuals", "Weapon ESP", "espWeapon")
addSlider("Visuals", "Max Distance", "espMaxDist", 50, 2000, 50)

-- Aimbot
addToggle("Aimbot", "Aimbot", "aimEnabled")
addToggle("Aimbot", "Target Indicator", "targetIndicator")
addSlider("Aimbot", "FOV", "aimFov", 20, 400, 5)
addSlider("Aimbot", "Smooth", "aimSmooth", 1, 30, 1)
addToggle("Aimbot", "Wall Check", "aimWallCheck")

-- Movement
addToggle("Movement", "Bhop", "bhopEnabled")
addSlider("Movement", "Bhop Chance %", "bhopChance", 1, 100, 1)
addSlider("Movement", "Bhop Min Speed", "bhopMinSpeed", 1, 50, 1)
addToggle("Movement", "Spinbot", "spinEnabled")
addSlider("Movement", "Spin Speed", "spinSpeed", 60, 3600, 60)
addToggle("Movement", "Spin Jitter", "spinJitter")
addToggle("Movement", "Speed Hack", "speedEnabled")
addSlider("Movement", "WalkSpeed", "walkSpeed", 16, 200, 1)
addToggle("Movement", "Jump Power", "jumpEnabled")
addSlider("Movement", "JumpPower", "jumpPower", 50, 300, 1)

-- Effects
addToggle("Effects", "Custom Sky", "skyEnabled")
addSlider("Effects", "Sky Color R", "skyColorR", 0, 255, 1)
addSlider("Effects", "Sky Color G", "skyColorG", 0, 255, 1)
addSlider("Effects", "Sky Color B", "skyColorB", 0, 255, 1)
addToggle("Effects", "Particles", "particlesEnabled")
addSlider("Effects", "Particle Count", "particleCount", 1, 200, 1)
addSlider("Effects", "Particle R", "particleColorR", 0, 255, 1)
addSlider("Effects", "Particle G", "particleColorG", 0, 255, 1)
addSlider("Effects", "Particle B", "particleColorB", 0, 255, 1)
addSlider("Effects", "Particle Size", "particleSize", 0.1, 5, 0.1)

-- Settings
addToggle("Settings", "ESP default", "espEnabled")

setMenuPos(Menu.x, Menu.y)
switchTab(Menu.tab)
saveCfg()

print("[nevertusukoh] loaded | Insert — меню")
