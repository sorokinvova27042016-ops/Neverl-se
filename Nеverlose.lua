-- ============================================================
-- nevertusukoh v2.1 | Neverlose.Lua
-- repo: sorokinvova27042016-ops/Neverlose (main)
-- injector: Xeno | password: 123
-- ============================================================

if _G.__nevertusukoh_loaded then
    warn("[nevertusukoh] already loaded")
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
    espHighlight = true,
    espName = true,
    espHealth = true,
    espDistance = true,
    espTracer = false,
    espWeapon = true,
    colorMurderer = {255, 30, 30},
    colorSheriff  = {40, 120, 255},
    colorInnocent = {200, 200, 200},
    colorWeapon   = {255, 210, 40},
    espMaxDist = 500,
    hlFillTransparency = 0.45,
    hlOutlineTransparency = 0,

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
    skyColorR = 20, skyColorG = 40, skyColorB = 120,

    particlesEnabled = false,
    particleCount = 40,
    particleColorR = 0, particleColorG = 255, particleColorB = 140,
    particleSize = 1.0,
}

local Cfg = {}
for k, v in pairs(Defaults) do
    if type(v) == "table" then Cfg[k] = {v[1], v[2], v[3]} else Cfg[k] = v end
end

-- ============================================================
-- CONFIG IO
-- ============================================================
local function serializeCfg()
    local lines = {"-- nevertusukoh config v2"}
    for k, v in pairs(Cfg) do
        if type(v) == "table" then
            lines[#lines+1] = string.format("%s=%d,%d,%d", k, v[1], v[2], v[3])
        else
            lines[#lines+1] = string.format("%s=%s", k, tostring(v))
        end
    end
    return table.concat(lines, "\n")
end

local function parseValue(s)
    if s == "true" then return true end
    if s == "false" then return false end
    local n = tonumber(s)
    return n or s
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
    if writefile then pcall(writefile, CFG_FILE, serializeCfg()) end
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
-- AUTH / PASSWORD
-- ============================================================
local Auth = {
    active = true,
    input = "",
    error = false,
    errorTime = 0,
    correct = "123",
}

local authBg     = newDrawing("Square", {Filled = true, Color = Color3.fromRGB(10,10,12), Transparency = 0.3, Visible = false})
local authBorder = newDrawing("Square", {Filled = false, Thickness = 1, Color = Accent, Transparency = 0.5, Visible = false})
local authGlow   = newDrawing("Square", {Filled = false, Thickness = 2, Color = Accent, Transparency = 0.7, Visible = false})
local authTitle  = newDrawing("Text", {Size = 26, Text = "never tusukoh", Color = Accent, Font = 2, Outline = true, Center = true, Visible = false})
local authSub    = newDrawing("Text", {Size = 12, Text = "enter password to unlock", Color = Color3.fromRGB(140,140,150), Font = 0, Outline = true, Center = true, Visible = false})
local authPrompt = newDrawing("Text", {Size = 14, Text = "password", Color = Color3.fromRGB(200,200,210), Font = 1, Outline = true, Center = true, Visible = false})
local authDots   = newDrawing("Text", {Size = 18, Text = "", Color = Accent, Font = 2, Outline = true, Center = true, Visible = false})
local authError  = newDrawing("Text", {Size = 12, Text = "", Color = Color3.fromRGB(255,60,60), Font = 1, Outline = true, Center = true, Visible = false})

local keyToChar = {
    [Enum.KeyCode.One] = "1", [Enum.KeyCode.Two] = "2", [Enum.KeyCode.Three] = "3",
    [Enum.KeyCode.Four] = "4", [Enum.KeyCode.Five] = "5", [Enum.KeyCode.Six] = "6",
    [Enum.KeyCode.Seven] = "7", [Enum.KeyCode.Eight] = "8", [Enum.KeyCode.Nine] = "9",
    [Enum.KeyCode.Zero] = "0",
    [Enum.KeyCode.KeypadOne] = "1", [Enum.KeyCode.KeypadTwo] = "2", [Enum.KeyCode.KeypadThree] = "3",
    [Enum.KeyCode.KeypadFour] = "4", [Enum.KeyCode.KeypadFive] = "5", [Enum.KeyCode.KeypadSix] = "6",
    [Enum.KeyCode.KeypadSeven] = "7", [Enum.KeyCode.KeypadEight] = "8", [Enum.KeyCode.KeypadNine] = "9",
    [Enum.KeyCode.KeypadZero] = "0",
}

local function updateAuthScreen()
    if not Auth.active then
        authBg.Visible = false
        authBorder.Visible = false
        authGlow.Visible = false
        authTitle.Visible = false
        authSub.Visible = false
        authPrompt.Visible = false
        authDots.Visible = false
        authError.Visible = false
        return
    end

    local cx = Camera.ViewportSize.X / 2
    local cy = Camera.ViewportSize.Y / 2
    local w, h = 340, 190
    local bx, by = cx - w / 2, cy - h / 2
    local pulse = 0.5 + 0.3 * math.sin(tick() * 3)

    authBg.Visible = true
    authBg.Position = Vector2.new(bx, by)
    authBg.Size = Vector2.new(w, h)
    authBg.Transparency = 0.15

    authBorder.Visible = true
    authBorder.Position = Vector2.new(bx, by)
    authBorder.Size = Vector2.new(w, h)
    authBorder.Transparency = 0.4 + 0.3 * pulse

    authGlow.Visible = true
    authGlow.Position = Vector2.new(bx - 4, by - 4)
    authGlow.Size = Vector2.new(w + 8, h + 8)
    authGlow.Transparency = 0.7 + 0.2 * pulse

    authTitle.Visible = true
    authTitle.Position = Vector2.new(cx, by + 24)

    authSub.Visible = true
    authSub.Position = Vector2.new(cx, by + 60)

    authPrompt.Visible = true
    authPrompt.Position = Vector2.new(cx, by + 92)

    local dots = ""
    for i = 1, #Auth.input do dots = dots .. "●" end
    for i = #Auth.input + 1, 6 do dots = dots .. " ○" end
    authDots.Visible = true
    authDots.Text = dots
    authDots.Position = Vector2.new(cx, by + 122)
    authDots.Color = Auth.error and Color3.fromRGB(255, 60, 60) or Accent

    authError.Visible = Auth.error
    authError.Text = Auth.error and "wrong password" or ""
    authError.Position = Vector2.new(cx, by + 158)
end

-- ============================================================
-- MENU STATE
-- ============================================================
local Menu = {
    open = false,
    anim = 0,
    x = 100, y = 100,
    w = 560, h = 440,
    tab = "Visuals",
    dragging = false,
    dragOffset = Vector2.new(),
    tabs = {"Visuals", "Aimbot", "Movement", "Effects", "Settings"},
    tabButtons = {},
    items = {},
    yCursor = {Visuals = 0, Aimbot = 0, Movement = 0, Effects = 0, Settings = 0},
    scroll = {Visuals = 0, Aimbot = 0, Movement = 0, Effects = 0, Settings = 0},
}

local glow1 = newDrawing("Square", {Size = Vector2.new(Menu.w + 8, Menu.h + 8), Filled = false, Thickness = 2, Color = Accent, Transparency = 1})
local glow2 = newDrawing("Square", {Size = Vector2.new(Menu.w + 14, Menu.h + 14), Filled = false, Thickness = 1, Color = Accent, Transparency = 1})
local menuBg     = newDrawing("Square", {Size = Vector2.new(Menu.w, Menu.h), Filled = true, Color = Color3.fromRGB(14,14,16), Transparency = 1})
local menuBorder = newDrawing("Square", {Size = Vector2.new(Menu.w, Menu.h), Filled = false, Thickness = 1, Color = Accent, Transparency = 1})
local headerBg   = newDrawing("Square", {Size = Vector2.new(Menu.w, 48), Filled = true, Color = Color3.fromRGB(20,20,24), Transparency = 1})
local headerLine = newDrawing("Line", {Thickness = 1, Color = Accent, Transparency = 1})
local menuTitle  = newDrawing("Text", {Size = 20, Text = "never tusukoh", Color = Accent, Outline = true, Font = 2, Transparency = 1})
local menuVer    = newDrawing("Text", {Size = 11, Text = "v2.1 | xeno", Color = Color3.fromRGB(130,130,140), Font = 0, Transparency = 1})
local sidebarBg  = newDrawing("Square", {Size = Vector2.new(150, Menu.h - 48), Filled = true, Color = Color3.fromRGB(18,18,22), Transparency = 1})
local sepLine    = newDrawing("Line", {Thickness = 1, Color = Color3.fromRGB(50,50,60), Transparency = 1})
local scrollBar  = newDrawing("Square", {Size = Vector2.new(3, 30), Filled = true, Color = Accent, Transparency = 1})

for _, name in ipairs(Menu.tabs) do
    local label = newDrawing("Text", {Size = 15, Text = name, Color = Color3.fromRGB(170,170,180), Font = 1, Transparency = 1})
    local sel   = newDrawing("Square", {Size = Vector2.new(3, 22), Filled = true, Color = Accent, Transparency = 1})
    local bg    = newDrawing("Square", {Size = Vector2.new(146, 28), Filled = true, Color = Color3.fromRGB(30,30,36), Transparency = 1})
    Menu.tabButtons[name] = {label = label, sel = sel, bg = bg, active = (name == Menu.tab), hover = false}
end

local function baseX() return Menu.x + 168 end

-- ============================================================
-- WATERMARK
-- ============================================================
local wmBg     = newDrawing("Square", {Filled = true, Color = Color3.fromRGB(12,12,14), Transparency = 1, Visible = false})
local wmBar    = newDrawing("Square", {Filled = true, Color = Accent, Transparency = 1, Visible = false})
local wmText   = newDrawing("Text", {Size = 14, Font = 2, Color = Color3.fromRGB(230,230,230), Outline = true, Transparency = 1, Visible = false})
local wmAccent = newDrawing("Text", {Size = 14, Font = 2, Color = Accent, Outline = true, Transparency = 1, Visible = false})

-- ============================================================
-- ITEM FACTORY
-- ============================================================
local function addToggle(tab, text, key)
    local yOff = Menu.yCursor[tab]
    Menu.yCursor[tab] = yOff + 26
    local label = newDrawing("Text", {Size = 14, Text = text, Color = Color3.fromRGB(220,220,225), Font = 0, Transparency = 1})
    local box   = newDrawing("Square", {Size = Vector2.new(16,16), Filled = false, Thickness = 1, Color = Color3.fromRGB(110,110,120), Transparency = 1})
    local fill  = newDrawing("Square", {Size = Vector2.new(12,12), Filled = true, Color = Accent, Transparency = 1})

    local item = {tab = tab, kind = "toggle", key = key, label = label, box = box, fill = fill, yOff = yOff}
    item.refresh = function()
        local y = Menu.y + 60 + yOff - Menu.scroll[tab]
        local x = baseX()
        label.Position = Vector2.new(x, y)
        box.Position   = Vector2.new(x + 320, y)
        fill.Position  = Vector2.new(x + 322, y + 2)
    end
    item.setVisible = function(v)
        local y = Menu.y + 60 + yOff - Menu.scroll[tab]
        local inBounds = y >= Menu.y + 50 and y <= Menu.y + Menu.h - 20
        local show = v and inBounds
        label.Visible = show
        box.Visible = show
        fill.Visible = show and Cfg[key]
    end
    Menu.items[#Menu.items+1] = item
end

local function addSlider(tab, text, key, min, max, step)
    local yOff = Menu.yCursor[tab]
    Menu.yCursor[tab] = yOff + 42
    local label = newDrawing("Text", {Size = 14, Text = text, Color = Color3.fromRGB(220,220,225), Font = 0, Transparency = 1})
    local val   = newDrawing("Text", {Size = 14, Text = tostring(Cfg[key]), Color = Accent, Font = 0, Transparency = 1})
    local track = newDrawing("Square", {Size = Vector2.new(170,4), Filled = true, Color = Color3.fromRGB(50,50,58), Transparency = 1})
    local fill  = newDrawing("Square", {Size = Vector2.new(0,4), Filled = true, Color = Accent, Transparency = 1})
    local knob  = newDrawing("Circle", {Radius = 6, Filled = true, Color = Accent, Transparency = 1})

    local function update()
        local p = (Cfg[key] - min) / (max - min)
        fill.Size = Vector2.new(170 * p, 4)
        knob.Position = Vector2.new(track.Position.X + 170 * p, track.Position.Y + 2)
    end

    local item = {tab = tab, kind = "slider", key = key, min = min, max = max, step = step,
                  label = label, val = val, track = track, fill = fill, knob = knob, yOff = yOff}
    item.refresh = function()
        local y = Menu.y + 60 + yOff - Menu.scroll[tab]
        local x = baseX()
        label.Position = Vector2.new(x, y)
        val.Position   = Vector2.new(x + 220, y)
        track.Position = Vector2.new(x + 10, y + 22)
        update()
    end
    item.setVisible = function(v)
        local y = Menu.y + 60 + yOff - Menu.scroll[tab]
        local inBounds = y >= Menu.y + 50 and y <= Menu.y + Menu.h - 20
        local show = v and inBounds
        label.Visible = show
        val.Visible = show
        track.Visible = show
        fill.Visible = show
        knob.Visible = show
    end
    item.setValue = function(pos)
        local p = math.clamp((pos.X - track.Position.X) / 170, 0, 1)
        local raw = min + p * (max - min)
        if step then raw = math.floor(raw / step + 0.5) * step end
        Cfg[key] = raw
        val.Text = tostring(raw)
        update()
    end
    item.hit = function(pos)
        local p = track.Position
        return pos.X >= p.X - 6 and pos.X <= p.X + 176 and pos.Y >= p.Y - 10 and pos.Y <= p.Y + 16
    end
    Menu.items[#Menu.items+1] = item
end

-- ============================================================
-- LAYOUT / ANIM
-- ============================================================
local function setMenuPos(x, y)
    Menu.x, Menu.y = x, y
    for _, item in ipairs(Menu.items) do item.refresh() end
end

local function refreshItemVisibility(item)
    local v = Menu.open and Menu.anim > 0.9 and item.tab == Menu.tab
    item.setVisible(v)
end

local function switchTab(name)
    Menu.tab = name
    for tabName, btn in pairs(Menu.tabButtons) do
        btn.active = (tabName == name)
        btn.label.Color = btn.active and Accent or Color3.fromRGB(170,170,180)
        btn.sel.Visible = btn.active
    end
    for _, item in ipairs(Menu.items) do
        item.refresh()
        refreshItemVisibility(item)
    end
end

local function toggleMenu() Menu.open = not Menu.open end

local function contentOverflow(tab)
    local total = Menu.yCursor[tab]
    local viewH = Menu.h - 60 - 10
    return total > viewH
end

local function updateMenuAnim(dt)
    local target = Menu.open and 1 or 0
    Menu.anim = Menu.anim + (target - Menu.anim) * math.clamp(dt * 16, 0, 1)
    if math.abs(target - Menu.anim) < 0.001 then Menu.anim = target end

    local a = Menu.anim
    local visible = a > 0.01
    local offsetY = (1 - a) * 24
    local x, y = Menu.x, Menu.y + offsetY
    local w, h = Menu.w, Menu.h
    local pulse = 0.5 + 0.3 * math.sin(tick() * 2)

    glow1.Visible = visible
    glow2.Visible = visible
    glow1.Position = Vector2.new(x - 4, y - 4)
    glow2.Position = Vector2.new(x - 7, y - 7)
    glow1.Transparency = (1 - a) * 1 + 0.6
    glow2.Transparency = (1 - a) * 1 + 0.8
    glow1.Thickness = 2
    glow2.Thickness = 1
    glow1.Color = Accent
    glow2.Color = Accent

    menuBg.Visible = visible
    menuBg.Position = Vector2.new(x, y)
    menuBg.Transparency = 1 - a * 0.95

    menuBorder.Visible = visible
    menuBorder.Position = Vector2.new(x, y)
    menuBorder.Transparency = 1 - a * (0.5 + 0.3 * pulse)

    headerBg.Visible = visible
    headerBg.Position = Vector2.new(x, y)
    headerBg.Transparency = 1 - a * 0.9

    headerLine.Visible = visible
    headerLine.From = Vector2.new(x, y + 48)
    headerLine.To = Vector2.new(x + w, y + 48)
    headerLine.Color = Accent
    headerLine.Transparency = 1 - a * 0.6

    menuTitle.Visible = visible
    menuTitle.Position = Vector2.new(x + 16, y + 8)
    menuTitle.Transparency = 1 - a

    menuVer.Visible = visible
    menuVer.Position = Vector2.new(x + 16, y + 32)
    menuVer.Transparency = 1 - a

    sidebarBg.Visible = visible
    sidebarBg.Position = Vector2.new(x, y + 48)
    sidebarBg.Transparency = 1 - a * 0.9

    sepLine.Visible = visible
    sepLine.From = Vector2.new(x + 150, y + 48)
    sepLine.To = Vector2.new(x + 150, y + h)
    sepLine.Transparency = 1 - a * 0.6

    for i, name in ipairs(Menu.tabs) do
        local btn = Menu.tabButtons[name]
        local ty = y + 60 + (i - 1) * 32
        btn.label.Visible = visible
        btn.label.Position = Vector2.new(x + 20, ty + 4)
        btn.label.Transparency = 1 - a
        btn.sel.Visible = visible and btn.active
        btn.sel.Position = Vector2.new(x + 4, ty + 2)
        btn.sel.Transparency = 1 - a * 0.8
        btn.bg.Visible = visible and btn.hover and not btn.active
        btn.bg.Position = Vector2.new(x + 2, ty - 2)
        btn.bg.Transparency = 1 - a * 0.8
    end

    for _, item in ipairs(Menu.items) do
        item.setVisible(Menu.open and Menu.anim > 0.9 and item.tab == Menu.tab)
    end

    local tab = Menu.tab
    local overflow = contentOverflow(tab)
    scrollBar.Visible = visible and overflow
    if overflow then
        local total = Menu.yCursor[tab]
        local viewH = Menu.h - 70
        local frac = viewH / total
        local barH = math.max(20, viewH * frac)
        local p = Menu.scroll[tab] / math.max(1, total - viewH)
        local barY = y + 60 + p * (viewH - barH)
        scrollBar.Position = Vector2.new(x + w - 6, barY)
        scrollBar.Size = Vector2.new(3, barH)
        scrollBar.Transparency = 1 - a * 0.8
    end
end

-- ============================================================
-- ROLES (cached)
-- ============================================================
local roleCache = {}

local function computeRole(player)
    local char = player.Character
    if not char then return "Innocent" end
    local function checkTool(tool)
        local n = tool.Name:lower()
        if n:find("knife") or n:find("sword") or n:find("blade") then return "Murderer" end
        if n:find("gun") or n:find("revolver") or n:find("pistol") then return "Sheriff" end
    end
    for _, obj in ipairs(char:GetChildren()) do
        if obj:IsA("Tool") then
            local r = checkTool(obj)
            if r then return r end
        end
    end
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp then
        for _, obj in ipairs(bp:GetChildren()) do
            if obj:IsA("Tool") then
                local r = checkTool(obj)
                if r then return r end
            end
        end
    end
    return "Innocent"
end

local function getRole(player) return roleCache[player] or "Innocent" end

local function refreshRoles()
    roleCache = {}
    for _, p in ipairs(Players:GetPlayers()) do
        roleCache[p] = computeRole(p)
    end
end

-- ============================================================
-- HIGHLIGHT
-- ============================================================
local hlFolder = Instance.new("Folder")
hlFolder.Name = "nvk_highlights"
hlFolder.Parent = Camera

local highlights = {}

local function roleColor(role)
    if role == "Murderer" then return rgb(Cfg.colorMurderer) end
    if role == "Sheriff"  then return rgb(Cfg.colorSheriff)  end
    return rgb(Cfg.colorInnocent)
end

local function updateHighlights()
    local enabled = Cfg.espEnabled and Cfg.espHighlight
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hl = highlights[player]
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local valid = enabled and char and hum and hum.Health > 0
            if valid then
                if not hl or hl.Parent == nil then
                    hl = Instance.new("Highlight")
                    hl.Name = "nvk_" .. player.Name
                    hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    hl.Parent = hlFolder
                    highlights[player] = hl
                end
                local col = roleColor(getRole(player))
                hl.Adornee = char
                hl.FillColor = col
                hl.OutlineColor = col
                hl.FillTransparency = Cfg.hlFillTransparency
                hl.OutlineTransparency = Cfg.hlOutlineTransparency
                hl.Enabled = true
            elseif hl then
                hl.Enabled = false
            end
        end
    end
end

-- ============================================================
-- ESP
-- ============================================================
local espCache = {}
local function createEsp()
    return {
        name = newDrawing("Text", {Size = 13, Center = true, Outline = true, Font = 1, Visible = false}),
        dist = newDrawing("Text", {Size = 12, Center = true, Outline = true, Font = 0, Visible = false}),
        tracer = newDrawing("Line", {Thickness = 1, Visible = false}),
        hbg = newDrawing("Square", {Filled = true, Color = Color3.fromRGB(35,35,40), Visible = false}),
        hfg = newDrawing("Square", {Filled = true, Visible = false}),
    }
end

local weaponEsp = {
    label = newDrawing("Text", {Size = 13, Center = true, Outline = true, Font = 1, Visible = false}),
    box   = newDrawing("Square", {Thickness = 1, Filled = false, Visible = false}),
}

local weaponCache = {}
local lastWeaponScan = 0

local function scanWeapons()
    weaponCache = {}
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("Tool") then
            local n = obj.Name:lower()
            if n:find("knife") or n:find("gun") or n:find("revolver") or n:find("pistol") then
                weaponCache[#weaponCache+1] = obj
            end
        end
    end
end

local function updateEsp()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local e = espCache[player]
            if not e then e = createEsp(); espCache[player] = e end
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local show = Cfg.espEnabled and hrp and hum and hum.Health > 0
            local dist = show and (Camera.CFrame.Position - hrp.Position).Magnitude or 0
            if show and dist > Cfg.espMaxDist then show = false end
            if show then
                local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.2, 0))
                local bot = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 2.8, 0))
                local _, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen then
                    local h = math.abs(top.Y - bot.Y)
                    local x = top.X
                    local y = top.Y
                    local role = getRole(player)
                    local col = roleColor(role)

                    e.name.Visible = Cfg.espName
                    e.name.Text = player.Name .. " | " .. role
                    e.name.Position = Vector2.new(x, y - 18)
                    e.name.Color = col

                    e.dist.Visible = Cfg.espDistance
                    e.dist.Text = string.format("[%d m]", dist)
                    e.dist.Position = Vector2.new(x, y + h + 2)
                    e.dist.Color = col

                    e.tracer.Visible = Cfg.espTracer
                    e.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    e.tracer.To = Vector2.new(x, y + h)
                    e.tracer.Color = col

                    local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                    e.hbg.Visible = Cfg.espHealth
                    e.hbg.Position = Vector2.new(x - h * 0.35 - 6, y)
                    e.hbg.Size = Vector2.new(3, h)
                    e.hfg.Visible = Cfg.espHealth
                    e.hfg.Position = Vector2.new(x - h * 0.35 - 6, y + h * (1 - frac))
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
        if tick() - lastWeaponScan > 0.4 then scanWeapons(); lastWeaponScan = tick() end
        local closest, closestDist
        for _, obj in ipairs(weaponCache) do
            if obj.Parent then
                local pos = obj:GetPivot().Position
                local d = (Camera.CFrame.Position - pos).Magnitude
                if not closestDist or d < closestDist then closest, closestDist = obj, d end
            end
        end
        if closest and closestDist <= Cfg.espMaxDist then
            local sp, on = Camera:WorldToViewportPoint(closest:GetPivot().Position)
            if on then
                local col = rgb(Cfg.colorWeapon)
                weaponEsp.label.Visible = true
                weaponEsp.label.Text = closest.Name .. string.format(" [%d m]", closestDist)
                weaponEsp.label.Position = Vector2.new(sp.X, sp.Y - 14)
                weaponEsp.label.Color = col
                weaponEsp.box.Visible = true
                weaponEsp.box.Position = Vector2.new(sp.X - 10, sp.Y - 10)
                weaponEsp.box.Size = Vector2.new(20, 20)
                weaponEsp.box.Color = col
            end
        end
    end
end

-- ============================================================
-- AIMBOT + INDICATOR
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

local indicator = {
    line = newDrawing("Line", {Thickness = 1.5, Color = Color3.fromRGB(200,200,200), Visible = false}),
    lineGlow = newDrawing("Line", {Thickness = 4, Color = Color3.fromRGB(120,120,120), Visible = false}),
    head = newDrawing("Circle", {Radius = 4, Filled = true, Color = Color3.fromRGB(220,220,220), Visible = false}),
    rings = {},
}
for i = 1, 4 do
    indicator.rings[i] = newDrawing("Circle", {Thickness = 1, Filled = false, Visible = false})
end
local indicatorPhase = 0

local function updateIndicator(dt)
    if not (Cfg.aimEnabled and Cfg.targetIndicator) then
        indicator.line.Visible = false
        indicator.lineGlow.Visible = false
        indicator.head.Visible = false
        for i = 1, 4 do indicator.rings[i].Visible = false end
        return
    end

    local part = aimTarget()
    if not part then
        indicator.line.Visible = false
        indicator.lineGlow.Visible = false
        indicator.head.Visible = false
        for i = 1, 4 do indicator.rings[i].Visible = false end
        return
    end

    local targetPlayer
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character and part:IsDescendantOf(p.Character) then
            targetPlayer = p
            break
        end
    end
    if not targetPlayer then return end

    local char = targetPlayer.Character
    local headPart = char:FindFirstChild("Head")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not headPart or not hrp then return end

    local headScr, headOn = Camera:WorldToViewportPoint(headPart.Position)
    local footPos = hrp.Position + Vector3.new(0, -2.5, 0)
    local footScr, footOn = Camera:WorldToViewportPoint(footPos)

    if headOn and footOn then
        indicator.line.Visible = true
        indicator.line.From = Vector2.new(headScr.X, footScr.Y)
        indicator.line.To   = Vector2.new(headScr.X, headScr.Y)
        indicator.line.Color = Color3.fromRGB(200,200,200)

        indicator.lineGlow.Visible = true
        indicator.lineGlow.From = indicator.line.From
        indicator.lineGlow.To = indicator.line.To
        indicator.lineGlow.Color = Color3.fromRGB(120,120,120)

        indicator.head.Visible = true
        indicator.head.Position = Vector2.new(headScr.X, headScr.Y)
    end

    indicatorPhase = (indicatorPhase + dt * 220) % 360
    local midY = (headScr.Y + footScr.Y) / 2
    for i = 1, 4 do
        local ring = indicator.rings[i]
        local phase = math.rad(indicatorPhase + i * 45)
        local radius = 18 + i * 8
        local rx = headScr.X + math.cos(phase) * radius
        local ry = midY + math.sin(phase) * radius * 0.3
        ring.Visible = headOn and footOn
        ring.Position = Vector2.new(rx, ry)
        ring.Radius = radius * 0.35
        ring.Color = Color3.fromRGB(200 - i * 20, 200 - i * 20, 200 - i * 20)
        ring.Thickness = 1
    end
end

-- ============================================================
-- EFFECTS
-- ============================================================
local particlesFolder = nil
local particleEmitters = {}

local function applySky()
    if not Cfg.skyEnabled then return end
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
    Lighting.Ambient = Color3.fromRGB(Cfg.skyColorR // 3, Cfg.skyColorG // 3, Cfg.skyColorB // 3)
    Lighting.OutdoorAmbient = Color3.fromRGB(Cfg.skyColorR, Cfg.skyColorG, Cfg.skyColorB)
    Lighting.Brightness = 1.5
    Lighting.ClockTime = 0
end

local function resetSky()
    Lighting.Ambient = Color3.fromRGB(70, 70, 70)
    Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
    Lighting.Brightness = 2
    Lighting.ClockTime = 14
end

local function clearParticles()
    if particlesFolder then
        pcall(function() particlesFolder:Destroy() end)
        particlesFolder = nil
    end
    particleEmitters = {}
end

local function spawnParticles()
    clearParticles()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    particlesFolder = Instance.new("Folder")
    particlesFolder.Name = "nvk_particles"
    particlesFolder.Parent = hrp

    for i = 1, Cfg.particleCount do
        local attach = Instance.new("Attachment")
        attach.Name = "nvk_p_" .. i
        attach.Parent = particlesFolder

        local emit = Instance.new("ParticleEmitter")
        emit.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emit.Color = ColorSequence.new(Color3.fromRGB(Cfg.particleColorR, Cfg.particleColorG, Cfg.particleColorB))
        emit.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.2 * Cfg.particleSize),
            NumberSequenceKeypoint.new(1, 0.8 * Cfg.particleSize),
        })
        emit.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 1),
        })
        emit.Lifetime = NumberRange.new(0.6, 1.2)
        emit.Rate = 8
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
        if not particlesFolder or not particlesFolder.Parent then spawnParticles() end
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
    elseif particlesFolder then
        clearParticles()
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    clearParticles()
    task.wait(1)
    if Cfg.particlesEnabled then spawnParticles() end
end)

-- ============================================================
-- MOVEMENT
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
        if math.random(1, 100) <= Cfg.bhopChance then hum.Jump = true end
    end
end

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

    -- AUTH
    if Auth.active then
        local kc = input.KeyCode
        if keyToChar[kc] then
            if #Auth.input < 16 then
                Auth.input = Auth.input .. keyToChar[kc]
            end
            Auth.error = false
            if Auth.input == Auth.correct then
                Auth.active = false
                Auth.input = ""
            end
        elseif kc == Enum.KeyCode.Backspace then
            Auth.input = Auth.input:sub(1, -2)
            Auth.error = false
        elseif kc == Enum.KeyCode.Return or kc == Enum.KeyCode.KeypadEnter then
            if Auth.input == Auth.correct then
                Auth.active = false
                Auth.input = ""
            else
                Auth.error = true
                Auth.errorTime = tick()
                Auth.input = ""
            end
        end
        return
    end

    local key = keyNameFromInput(input)

    if key == "Insert" then
        toggleMenu()
        return
    end

    if not Menu.open or Menu.anim < 0.9 then return end

    if key == Cfg.aimKey then aimHeld = true end

    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        local pos = UserInputService:GetMouseLocation()

        if pos.X >= Menu.x and pos.X <= Menu.x + Menu.w and pos.Y >= Menu.y and pos.Y <= Menu.y + 48 then
            Menu.dragging = true
            Menu.dragOffset = pos - Vector2.new(Menu.x, Menu.y)
            return
        end

        for i, tabName in ipairs(Menu.tabs) do
            local btn = Menu.tabButtons[tabName]
            local ty = Menu.y + 60 + (i - 1) * 32
            if pos.X >= Menu.x + 2 and pos.X <= Menu.x + 150 and pos.Y >= ty - 2 and pos.Y <= ty + 26 then
                switchTab(tabName)
                return
            end
        end

        for _, item in ipairs(Menu.items) do
            if item.tab == Menu.tab then
                local y = Menu.y + 60 + item.yOff - Menu.scroll[Menu.tab]
                if item.kind == "toggle" then
                    local bx = baseX() + 320
                    if pos.X >= bx and pos.X <= bx + 18 and pos.Y >= y and pos.Y <= y + 18 then
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
                    if item.key == "skyColorR" or item.key == "skyColorG" or item.key == "skyColorB" then applySky() end
                    saveCfg()
                    return
                end
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if Auth.active then return end
    local key = keyNameFromInput(input)
    if key == Cfg.aimKey then aimHeld = false end
    if input.UserInputType == Enum.UserInputType.MouseButton1 then Menu.dragging = false end
end)

UserInputService.InputChanged:Connect(function(input)
    if Auth.active then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement and Menu.dragging then
        local pos = UserInputService:GetMouseLocation()
        setMenuPos(pos.X - Menu.dragOffset.X, pos.Y - Menu.dragOffset.Y)
    end
    if input.UserInputType == Enum.UserInputType.MouseWheel and Menu.open and Menu.anim > 0.9 then
        local tab = Menu.tab
        if contentOverflow(tab) then
            Menu.scroll[tab] = math.clamp(Menu.scroll[tab] - input.Position.Z * 30, 0,
                math.max(0, Menu.yCursor[tab] - (Menu.h - 70)))
            for _, item in ipairs(Menu.items) do
                if item.tab == tab then item.refresh() end
            end
        end
    end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
local fpsFrames = 0
local fpsTime = tick()
local currentFps = 60
local lastRoleCheck = 0

RunService.RenderStepped:Connect(function(dt)
    -- AUTH
    if Auth.error and tick() - Auth.errorTime > 1.5 then Auth.error = false end
    updateAuthScreen()
    if Auth.active then return end

    -- fps
    fpsFrames = fpsFrames + 1
    if tick() - fpsTime >= 1 then
        currentFps = math.floor(fpsFrames / (tick() - fpsTime))
        fpsFrames = 0
        fpsTime = tick()
    end

    if tick() - lastRoleCheck > 0.5 then
        refreshRoles()
        lastRoleCheck = tick()
    end

    updateMenuAnim(dt)
    updateHighlights()
    updateEsp()
    updateIndicator(dt)
    updateParticles()

    if Menu.open and Menu.anim > 0.9 then
        local mp = UserInputService:GetMouseLocation()
        for i, tabName in ipairs(Menu.tabs) do
            local btn = Menu.tabButtons[tabName]
            local ty = Menu.y + 60 + (i - 1) * 32
            btn.hover = mp.X >= Menu.x + 2 and mp.X <= Menu.x + 150 and mp.Y >= ty - 2 and mp.Y <= ty + 26
        end
    end

    -- watermark
    local visibleWm = Menu.anim > 0.01
    local role = getRole(LocalPlayer)
    local ping = math.floor(LocalPlayer:GetNetworkPing() * 1000)
    local wmStr = string.format("fps %d  |  ping %d  |  %s", currentFps, ping, role)
    local nameStr = "never tusukoh"

    wmText.Text = wmStr
    wmAccent.Text = nameStr
    local pad = 10
    local barW = 3
    local txtW = wmAccent.TextBounds.X + wmText.TextBounds.X + pad * 3
    local boxW = txtW + barW + pad
    local boxH = 24

    wmBg.Visible = visibleWm
    wmBg.Position = Vector2.new(14, 14)
    wmBg.Size = Vector2.new(boxW, boxH)
    wmBg.Color = Color3.fromRGB(12,12,14)
    wmBg.Transparency = 1 - Menu.anim * 0.8

    wmBar.Visible = visibleWm
    wmBar.Position = Vector2.new(14, 14)
    wmBar.Size = Vector2.new(barW, boxH)
    wmBar.Color = Accent
    wmBar.Transparency = 1 - Menu.anim

    wmAccent.Visible = visibleWm
    wmAccent.Position = Vector2.new(14 + barW + pad, 14 + 4)
    wmAccent.Transparency = 1 - Menu.anim

    wmText.Visible = visibleWm
    wmText.Position = Vector2.new(14 + barW + pad + wmAccent.TextBounds.X + pad, 14 + 4)
    wmText.Transparency = 1 - Menu.anim

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
-- INIT ITEMS
-- ============================================================
addToggle("Visuals", "ESP Master", "espEnabled")
addToggle("Visuals", "Full Body Highlight", "espHighlight")
addToggle("Visuals", "Name + Role", "espName")
addToggle("Visuals", "Health Bar", "espHealth")
addToggle("Visuals", "Distance", "espDistance")
addToggle("Visuals", "Tracer", "espTracer")
addToggle("Visuals", "Weapon ESP", "espWeapon")
addSlider("Visuals", "Max Distance", "espMaxDist", 50, 2000, 50)
addSlider("Visuals", "HL Fill Alpha", "hlFillTransparency", 0, 1, 0.05)

addToggle("Aimbot", "Aimbot", "aimEnabled")
addToggle("Aimbot", "Target Indicator", "targetIndicator")
addSlider("Aimbot", "FOV", "aimFov", 20, 400, 5)
addSlider("Aimbot", "Smooth", "aimSmooth", 1, 30, 1)
addToggle("Aimbot", "Wall Check", "aimWallCheck")

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

addToggle("Effects", "Custom Sky", "skyEnabled")
addSlider("Effects", "Sky R", "skyColorR", 0, 255, 1)
addSlider("Effects", "Sky G", "skyColorG", 0, 255, 1)
addSlider("Effects", "Sky B", "skyColorB", 0, 255, 1)
addToggle("Effects", "Particles", "particlesEnabled")
addSlider("Effects", "Particle Count", "particleCount", 1, 200, 1)
addSlider("Effects", "Particle R", "particleColorR", 0, 255, 1)
addSlider("Effects", "Particle G", "particleColorG", 0, 255, 1)
addSlider("Effects", "Particle B", "particleColorB", 0, 255, 1)
addSlider("Effects", "Particle Size", "particleSize", 0.1, 5, 0.1)

addToggle("Settings", "ESP Default", "espEnabled")

setMenuPos(Menu.x, Menu.y)
switchTab(Menu.tab)
saveCfg()

print("[nevertusukoh] v2.1 loaded | password: 123 | Insert — menu")
