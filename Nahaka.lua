-- ==========================================================
-- NURHUB v1.8 | Delta Executor Compatible | без Drawing API
-- + Ключи, Profile, Aimbot (модель тела)
-- + Skeleton, Spin, Show FPS, Angel mode, World (шейдеры)
-- + Config (5 слотов), Settings (PC, размер, прозрачность,
--   цвет меню, язык RU/EN)
-- ==========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- ==========================================================
-- 0. ОЧИСТКА ПРИ ПОВТОРНОМ ЗАПУСКЕ + ТРЕКЕР СОЕДИНЕНИЙ
-- ==========================================================
local ENV = (getgenv and getgenv()) or _G
if ENV.NurHubCleanup then pcall(ENV.NurHubCleanup) end

local Conns = {}     -- постоянные соединения
local UIConns = {}   -- соединения интерфейса (сбрасываются при пересборке меню)
local function track(conn)
    table.insert(Conns, conn)
    return conn
end
local function utrack(conn)
    table.insert(UIConns, conn)
    return conn
end

local function getGuiParent()
    local ok, result = pcall(function()
        return (gethui and gethui()) or game:GetService("CoreGui")
    end)
    if ok and result then return result end
    return LocalPlayer:WaitForChild("PlayerGui")
end

ENV.NurHubCleanup = function()
    if ENV.NurHubSilentState then
        ENV.NurHubSilentState.Enabled = false
        ENV.NurHubSilentState.Target = nil
    end
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    Conns = {}
    for _, c in ipairs(UIConns) do pcall(function() c:Disconnect() end) end
    UIConns = {}
    pcall(function() RunService:UnbindFromRenderStep("NurHubLoop") end)
    if ENV.NurHubWorldCleanup then pcall(ENV.NurHubWorldCleanup) end
    local gp = getGuiParent()
    for _, n in ipairs({"NurHubGui", "NurHubESPGui", "NurHubKeyGui"}) do
        local g = gp:FindFirstChild(n)
        if g then g:Destroy() end
    end
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    if myHrp then
        for _, d in ipairs(myHrp:GetChildren()) do
            if d.Name == "NurHub_Fly" then d:Destroy() end
        end
    end
    local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
    if myHum then myHum.PlatformStand = false end
    if myHum and ENV.NurHubSpinOn then myHum.AutoRotate = true end
    ENV.NurHubSpinOn = false
    if myChar then
        for _, d in ipairs(myChar:GetChildren()) do
            if d.Name == "NurHub_Wings" then d:Destroy() end
        end
    end
    local m = ENV.NurHubModded
    if m and myHum then
        if m.speed then myHum.WalkSpeed = 16 end
        if m.jump then myHum.JumpPower = 50 end
    end
    if myHrp then myHrp.CanCollide = true end
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            for _, d in ipairs(p.Character:GetChildren()) do
                if d.Name == "NurHub_ESP" or d.Name == "NurHub_Box3D" then d:Destroy() end
            end
            local head = p.Character:FindFirstChild("Head")
            local bb = head and head:FindFirstChild("NurHub_Billboard")
            if bb then bb:Destroy() end
        end
    end
end

track(workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    Camera = workspace.CurrentCamera
end))

-- ==========================================================
-- 0.5 СЕРИАЛИЗАЦИЯ, ФАЙЛЫ, НАСТРОЙКИ МЕНЮ, ЯЗЫК
-- ==========================================================

-- Color3 -> {__c={r,g,b}}, таблицы рекурсивно
local function ser(v)
    if typeof(v) == "Color3" then
        return {__c = {math.floor(v.R * 255 + 0.5), math.floor(v.G * 255 + 0.5), math.floor(v.B * 255 + 0.5)}}
    elseif type(v) == "table" then
        local o = {}
        for k, x in pairs(v) do o[k] = ser(x) end
        return o
    end
    return v
end

-- Применяет сохранённые данные в существующую таблицу (только известные ключи и совпадающие типы)
local function applyInto(target, saved)
    if type(saved) ~= "table" then return end
    for k, cur in pairs(target) do
        local sv = saved[k]
        if sv ~= nil then
            if typeof(cur) == "Color3" then
                if type(sv) == "table" and type(sv.__c) == "table" then
                    target[k] = Color3.fromRGB(sv.__c[1] or 255, sv.__c[2] or 255, sv.__c[3] or 255)
                end
            elseif type(cur) == "table" then
                if type(sv) == "table" then applyInto(cur, sv) end
            elseif type(sv) == type(cur) then
                target[k] = sv
            end
        end
    end
end

local function readJson(file, memKey)
    local res
    pcall(function()
        if isfile and readfile and isfile(file) then
            res = HttpService:JSONDecode(readfile(file))
        end
    end)
    if type(res) == "table" then return res end
    if type(ENV[memKey]) == "table" then return ENV[memKey] end
    return nil
end

local function writeJson(file, memKey, data)
    ENV[memKey] = data
    pcall(function()
        if writefile then writefile(file, HttpService:JSONEncode(data)) end
    end)
end

local SETTINGS_FILE = "NurHub_settings.json"
local CONFIGS_FILE = "NurHub_configs.json"

local Settings = {
    Lang = "ru",
    Scale = 100,
    Transparency = 0,
    PCMode = false,
    MenuKey = "RightShift",
    HideLauncher = false,
    Colors = {
        Grad1 = Color3.fromRGB(255, 214, 10),
        Grad2 = Color3.fromRGB(255, 140, 0),
    },
}

do
    local saved = readJson(SETTINGS_FILE, "NurHubSettingsMem")
    if saved then applyInto(Settings, saved) end
    if Settings.Lang ~= "ru" and Settings.Lang ~= "en" then Settings.Lang = "ru" end
    Settings.Scale = math.clamp(Settings.Scale, 50, 150)
    Settings.Transparency = math.clamp(Settings.Transparency, 0, 70)
    if not pcall(function() return Enum.KeyCode[Settings.MenuKey] end) then Settings.MenuKey = "RightShift" end
end

local function saveSettings()
    writeJson(SETTINGS_FILE, "NurHubSettingsMem", ser(Settings))
end

local saveToken = 0
local function saveSettingsSoon()
    saveToken = saveToken + 1
    local my = saveToken
    task.delay(0.5, function()
        if my == saveToken then saveSettings() end
    end)
end

-- Словарь перевода (ключ = русский текст). Нет перевода -> показывается как есть.
local EN = {
    -- вкладки
    ["Визуал"] = "Visual", ["Бой"] = "Combat", ["Игрок"] = "Player", ["Мир"] = "World",
    ["Конфиг"] = "Config", ["Настройки"] = "Settings", ["Профиль"] = "Profile",
    -- окно ключа
    ["Активация ключа"] = "Key activation", ["Введите ключ..."] = "Enter key...",
    ["Активировать"] = "Activate", ["Проверка..."] = "Checking...", ["Проверка ключа..."] = "Checking key...",
    ["! Добро пожаловать"] = "! Welcome", ["Введите ключ"] = "Enter a key", ["Неверный ключ"] = "Invalid key",
    ["Срок этого ключа уже истёк"] = "This key has already expired", ["Ключ принят"] = "Key accepted",
    ["Найден сохранённый ключ..."] = "Saved key found...",
    ["Срок ключа истёк. Введите новый"] = "Key expired. Enter a new one",
    ["Введите ключ для активации"] = "Enter a key to activate", ["Введите новый ключ"] = "Enter a new key",
    ["Срок действия ключа истёк. Введите новый"] = "Your key has expired. Enter a new one",
    ["Скрипт загружен! Введите ключ."] = "Script loaded! Enter your key.",
    ["Silent Aim не поддерживается этим экзекутором"] = "Silent Aim is not supported by this executor",
    -- Visual
    ["Элементы ESP"] = "ESP elements", ["ESP (включить всё)"] = "ESP (enable all)", ["Дистанция ESP"] = "ESP distance",
    ["Контур (Outline)"] = "Outline", ["Экран"] = "Screen", ["Персонаж"] = "Character",
    ["Свой FPS"] = "Custom FPS", ["Перетащите значок по экрану"] = "Drag the badge across the screen",
    -- Combat
    ["Зажим ПКМ (только ПК)"] = "Hold RMB (PC only)", ["Общие"] = "General",
    ["Проверка видимости"] = "Visibility check", ["ЦЕЛЬ АИМБОТА"] = "AIMBOT TARGET",
    ["Голова"] = "Head", ["Торс"] = "Torso", ["Левая рука"] = "Left arm", ["Правая рука"] = "Right arm",
    ["Левая нога"] = "Left leg", ["Правая нога"] = "Right leg",
    ["Точная цель, маленький хитбокс"] = "Precise target, small hitbox",
    ["Самая большая площадь, наведение стабильнее"] = "Largest area, more stable aim",
    ["Запасная цель сбоку"] = "Backup side target", ["Нижняя цель, удобна вблизи"] = "Low target, handy up close",
    ["Скорость наводки %"] = "Aim speed %", ["Упреждение (сотые сек)"] = "Prediction (1/100 s)",
    ["Показывать круг FOV"] = "Show FOV circle", ["Цвет круга FOV"] = "FOV circle color",
    -- Player
    ["Движение"] = "Movement", ["Скорость полёта"] = "Fly speed", ["Скорость вращения (°/сек)"] = "Spin speed (°/s)",
    ["Камера"] = "Camera",
    -- World
    ["Шейдеры"] = "Shaders", ["Интенсивность %"] = "Intensity %", ["Небо и свет"] = "Sky & light",
    ["Чёрное небо"] = "Black sky", ["Затемнение экрана"] = "Screen darkening", ["Сила затемнения %"] = "Darkness %",
    ["Свечение экрана"] = "Screen glow", ["Сила свечения %"] = "Glow %", ["Цветокоррекция"] = "Color grading",
    ["Насыщенность"] = "Saturation", ["Контраст"] = "Contrast", ["Время суток"] = "Time of day", ["Час"] = "Hour",
    ["Сакура"] = "Sakura", ["Кровь"] = "Blood", ["Закат"] = "Sunset", ["Неон"] = "Neon", ["Океан"] = "Ocean",
    -- Config
    ["Конфиги"] = "Configs", ["Новый конфиг"] = "New config", ["Имя конфига..."] = "Config name...",
    ["Сохранить"] = "Save", ["Слоты"] = "Slots", ["Сохранённые"] = "Saved", ["— пусто —"] = "— empty —",
    ["Введите имя"] = "Enter a name", ["Максимум 5 конфигов"] = "Max 5 configs",
    ["Конфиг сохранён"] = "Config saved", ["Конфиг обновлён"] = "Config updated",
    ["Сохраните текущие настройки под своим именем"] = "Save your current settings under a name",
    ["Нажмите на конфиг, чтобы загрузить"] = "Tap a config to load it",
    -- Settings
    ["Управление"] = "Controls", ["PC режим"] = "PC mode", ["Клавиша меню"] = "Menu key",
    ["Нажмите клавишу..."] = "Press a key...", ["Скрыть кнопку N"] = "Hide N button",
    ["Внешний вид"] = "Appearance", ["Размер меню"] = "Menu size", ["Масштаб %"] = "Scale %",
    ["Прозрачность меню"] = "Menu transparency", ["Прозрачность %"] = "Transparency %",
    ["Цвет меню (градиент)"] = "Menu color (gradient)", ["Цвет 1"] = "Color 1", ["Цвет 2"] = "Color 2",
    ["Язык"] = "Language", ["Язык интерфейса"] = "Interface language",
    -- Profile
    ["АКТИВЕН"] = "ACTIVE", ["Лицензия"] = "License", ["Активный ключ"] = "Active key",
    ["Срок ключа"] = "Key duration", ["Осталось"] = "Remaining", ["Действует до"] = "Valid until",
    ["Сменить ключ"] = "Change key",
    ["ДНИ"] = "DAYS", ["ЧАСЫ"] = "HOURS", ["МИН"] = "MIN", ["СЕК"] = "SEC", ["ИСТЕКАЕТ"] = "EXPIRING",
    ["Ключ"] = "Key", ["Активирован"] = "Activated", ["Показать"] = "Show", ["Скрыть"] = "Hide",
    ["Скопировать"] = "Copy", ["Скопировано"] = "Copied", ["Недоступно"] = "Unavailable",
    ["Аккаунт"] = "Account", ["Игроков"] = "Players", ["ПРЕМИУМ"] = "PREMIUM", ["Превью"] = "Preview", ["Настройки Aimbot"] = "Aimbot settings", ["дн."] = "d", ["ч."] = "h", ["мин."] = "min", ["сек."] = "s",
}

local function L(s)
    if Settings.Lang == "en" then return EN[s] or s end
    return s
end

local TabRU = {
    Visual = "Визуал", Combat = "Бой", Player = "Игрок", World = "Мир",
    Config = "Конфиг", Settings = "Настройки", Profile = "Профиль",
}

-- ==========================================================
-- НАСТРОЙКИ ФУНКЦИЙ (по умолчанию всё выключено)
-- ==========================================================
local WHITE = Color3.fromRGB(255, 255, 255)

local Config = {
    Visual = {
        ESP = false,
        Outline = false,
        ShowNickname = false,
        ShowDistance = false,
        Line = false,
        Box = false,
        Box3D = false,
        Skeleton = false,
        DistanceLimit = 500,
        ShowFPS = false,
        FPSCustom = false,
        FPSValue = 999,
        FPSX = 0,
        FPSY = 0,
        Angel = false,
        Colors = {
            Outline = WHITE, Nickname = WHITE, Distance = WHITE, Line = WHITE,
            Box = WHITE, Box3D = WHITE, Skeleton = WHITE, FPS = WHITE,
        }
    },
    Combat = {
        Aimbot = false,
        AimbotFOV = 200,
        AimbotSmoothness = 0.2,
        Prediction = 0,
        HoldToAim = false,
        Sticky = false,
        ShowFOV = false,
        SilentAim = false,
        SilentFOV = 150,
        HitChance = 100,
        ShowSilentFOV = false,
        TargetPart = "Head",
        TeamCheck = false,
        VisibleCheck = false,
        Colors = {
            AimbotFOV = Color3.fromRGB(255, 214, 10),
            SilentFOV = Color3.fromRGB(255, 69, 58),
        }
    },
    Player = {
        WalkSpeed = 16,
        JumpPower = 50,
        Noclip = false,
        Fly = false,
        FlySpeed = 50,
        Spin = false,
        SpinSpeed = 360,
        ThirdPerson = false
    },
    World = {
        Shader = false,
        ShaderName = "Sakura",
        Intensity = 100,
        BlackSky = false,
        Dark = false,
        DarkAmount = 40,
        Glow = false,
        GlowAmount = 50,
        Grade = false,
        Saturation = 30,
        Contrast = 10,
        Time = false,
        TimeValue = 12,
        Fullbright = false,
    }
}

local espObjects = {}
local isMenuOpen = false
local flyBodyVelocity, flyBodyGyro
local UI -- текущий интерфейс (пересобирается при смене языка/конфига/темы)
local Store = {binding = false, themeDirty = false, cfgActive = nil, tp = false}

local function applyThirdPerson(on)
    pcall(function()
        if on then
            LocalPlayer.CameraMode = Enum.CameraMode.Classic
            LocalPlayer.CameraMaxZoomDistance = 128
            LocalPlayer.CameraMinZoomDistance = 0.5
        else
            LocalPlayer.CameraMaxZoomDistance = 0.5
        end
    end)
end

-- ==========================================================
-- 1. ТЕМА И ХЕЛПЕРЫ
-- ==========================================================

local THEME = {
    Bg = Color3.fromRGB(16, 16, 22),
    Side = Color3.fromRGB(20, 20, 28),
    Card = Color3.fromRGB(28, 28, 38),
    CardHover = Color3.fromRGB(35, 35, 48),
    Stroke = Color3.fromRGB(48, 48, 62),
    Text = Color3.fromRGB(240, 240, 248),
    Dim = Color3.fromRGB(142, 142, 160),
    Accent = Settings.Colors.Grad1,
    Accent2 = Settings.Colors.Grad2,
    Off = Color3.fromRGB(58, 58, 74),
}

local RED = Color3.fromRGB(255, 69, 58)
local GREEN = Color3.fromRGB(48, 209, 88)

local PALETTE = {
    Color3.fromRGB(255, 255, 255),
    Color3.fromRGB(255, 214, 10),
    Color3.fromRGB(255, 69, 58),
    Color3.fromRGB(48, 209, 88),
    Color3.fromRGB(64, 200, 224),
    Color3.fromRGB(10, 132, 255),
    Color3.fromRGB(191, 90, 242),
}

local GradReg = {} -- все градиенты темы (обновляются вживую)

local function tween(obj, props, time, style, dir)
    local info = TweenInfo.new(time or 0.25, style or Enum.EasingStyle.Quint, dir or Enum.EasingDirection.Out)
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

local function corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function accentGradient(parent, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(THEME.Accent, THEME.Accent2)
    g.Rotation = rotation or 0
    g.Parent = parent
    table.insert(GradReg, g)
    return g
end

local function refreshGradients()
    for i = #GradReg, 1, -1 do
        local g = GradReg[i]
        if g and g.Parent then
            g.Color = ColorSequence.new(THEME.Accent, THEME.Accent2)
        else
            table.remove(GradReg, i)
        end
    end
end

-- текст автоматически переводится через L()
local function makeLabel(parent, text, size, color, font)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text = L(text)
    l.TextSize = size
    l.TextColor3 = color
    l.Font = font or Enum.Font.Gotham
    l.Parent = parent
    return l
end

local function isPress(input)
    return input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input)
    return input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch
end

local function makeDraggable(handle, target)
    local dragging, dragStart, startPos = false, nil, nil
    local state = {moved = false}

    handle.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            state.moved = false
            dragStart = input.Position
            startPos = target.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    utrack(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            local delta = input.Position - dragStart
            if delta.Magnitude > 6 then state.moved = true end
            target.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end))

    return state
end

-- Перетаскивание по области: onPos(Vector3 позиции курсора/пальца)
local function bindDrag(hit, scroller, onPos)
    local dragging = false
    hit.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            if scroller then scroller.ScrollingEnabled = false end
            onPos(input.Position)
        end
    end)
    utrack(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = false
            if scroller then scroller.ScrollingEnabled = true end
        end
    end))
    utrack(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then onPos(input.Position) end
    end))
end

local function sameColor(a, b)
    return math.abs(a.R - b.R) < 0.006 and math.abs(a.G - b.G) < 0.006 and math.abs(a.B - b.B) < 0.006
end

-- ==========================================================
-- 1.5 СИСТЕМА КЛЮЧЕЙ
-- ==========================================================

local KEYS = {
    ["OCTOBER"] = 7,     -- 7 дней
    ["MAGA761"] = 999,   -- 999 дней
}
local KEY_FILE = "NurHub_key.json"

local Lic = {
    Active = false,
    Key = nil,
    Days = 0,
    Activated = 0,
    Expires = 0,
    OnUnlock = nil,
    OnLock = nil,
}

local function loadData()
    local data = readJson(KEY_FILE, "NurHubKeyMem") or {}
    if type(data.used) ~= "table" then data.used = {} end
    return data
end

local function saveData(data)
    writeJson(KEY_FILE, "NurHubKeyMem", data)
end

local function applyLicense(key, activated)
    Lic.Key = key
    Lic.Days = KEYS[key]
    Lic.Activated = activated
    Lic.Expires = activated + KEYS[key] * 86400
    Lic.Active = true
end

local function tryKey(input)
    local key = string.upper((tostring(input or ""):gsub("%s+", "")))
    if key == "" then return false, "Введите ключ" end

    local days = KEYS[key]
    if not days then return false, "Неверный ключ" end

    local data = loadData()
    local rec = data.used[key]
    local now = os.time()

    if type(rec) == "table" and type(rec.activated) == "number" then
        if rec.activated > now then rec.activated = now end
        if rec.activated + days * 86400 <= now then
            return false, "Срок этого ключа уже истёк"
        end
    else
        rec = {activated = now}
    end

    rec.expires = rec.activated + days * 86400
    data.used[key] = rec
    data.current = key
    saveData(data)

    applyLicense(key, rec.activated)
    return true, "Ключ принят"
end

function Lic.FormatLeft(sec)
    sec = math.max(0, math.floor(sec))
    local d = math.floor(sec / 86400)
    local h = math.floor((sec % 86400) / 3600)
    local m = math.floor((sec % 3600) / 60)
    if d > 0 then return d .. " " .. L("дн.") .. " " .. h .. " " .. L("ч.") end
    if h > 0 then return h .. " " .. L("ч.") .. " " .. m .. " " .. L("мин.") end
    return m .. " " .. L("мин.") .. " " .. (sec % 60) .. " " .. L("сек.")
end

local keyGui, keyAnimConn

local function showKeyWindow(presetKey, presetMsg, presetColor, autoSubmit)
    if keyGui then keyGui:Destroy() keyGui = nil end
    if keyAnimConn then keyAnimConn:Disconnect() keyAnimConn = nil end

    local gui = Instance.new("ScreenGui")
    gui.Name = "NurHubKeyGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 50
    gui.Parent = getGuiParent()
    keyGui = gui

    local dim = Instance.new("Frame")
    dim.Size = UDim2.new(1, 0, 1, 0)
    dim.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    dim.BackgroundTransparency = 1
    dim.BorderSizePixel = 0
    dim.Active = true
    dim.Parent = gui
    tween(dim, {BackgroundTransparency = 0.4}, 0.5)

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0, 380, 0, 280)
    holder.AnchorPoint = Vector2.new(0.5, 0.5)
    holder.Position = UDim2.new(0.5, 0, 0.5, 0)
    holder.BackgroundTransparency = 1
    holder.Parent = gui

    local vp = Camera.ViewportSize
    local fit = math.max(math.min(1, (vp.X - 20) / 380, (vp.Y - 20) / 280), 0.4)
    local scale = Instance.new("UIScale")
    scale.Scale = fit * 0.8
    scale.Parent = holder

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -6)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 1
    shadow.BorderSizePixel = 0
    shadow.Parent = holder
    corner(shadow, 24)
    tween(shadow, {BackgroundTransparency = 0.6}, 0.5)

    local card = Instance.new("CanvasGroup")
    card.Size = UDim2.new(1, 0, 1, 0)
    card.BackgroundColor3 = THEME.Bg
    card.BorderSizePixel = 0
    card.GroupTransparency = 1
    card.Parent = holder
    corner(card, 16)
    addStroke(card, THEME.Stroke, 1)

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 3)
    topBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    topBar.BorderSizePixel = 0
    topBar.Parent = card
    local barGrad = Instance.new("UIGradient")
    barGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, THEME.Accent2),
        ColorSequenceKeypoint.new(0.5, THEME.Accent),
        ColorSequenceKeypoint.new(1, THEME.Accent2),
    })
    barGrad.Parent = topBar

    local logo = Instance.new("Frame")
    logo.Size = UDim2.new(0, 54, 0, 54)
    logo.AnchorPoint = Vector2.new(0.5, 0)
    logo.Position = UDim2.new(0.5, 0, 0, 22)
    logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    logo.BorderSizePixel = 0
    logo.Parent = card
    corner(logo, 27)
    accentGradient(logo, 45)
    local logoScale = Instance.new("UIScale")
    logoScale.Parent = logo
    local logoText = makeLabel(logo, "N", 26, Color3.fromRGB(20, 20, 20), Enum.Font.GothamBlack)
    logoText.Size = UDim2.new(1, 0, 1, 0)

    local title = makeLabel(card, 'Nur<font color="rgb(255,214,10)">Hub</font>', 22, THEME.Text, Enum.Font.GothamBold)
    title.RichText = true
    title.Size = UDim2.new(1, 0, 0, 28)
    title.Position = UDim2.new(0, 0, 0, 84)

    local sub = makeLabel(card, "Активация ключа", 13, THEME.Dim, Enum.Font.Gotham)
    sub.Size = UDim2.new(1, 0, 0, 18)
    sub.Position = UDim2.new(0, 0, 0, 112)

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -48, 0, 42)
    box.Position = UDim2.new(0, 24, 0, 142)
    box.BackgroundColor3 = THEME.Card
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 15
    box.TextColor3 = THEME.Text
    box.PlaceholderText = L("Введите ключ...")
    box.PlaceholderColor3 = THEME.Dim
    box.Text = presetKey or ""
    box.ClearTextOnFocus = false
    box.Parent = card
    corner(box, 10)
    local boxStroke = addStroke(box, THEME.Stroke, 1.5)

    track(box.Focused:Connect(function()
        tween(boxStroke, {Color = THEME.Accent}, 0.2)
    end))
    track(box.FocusLost:Connect(function()
        tween(boxStroke, {Color = THEME.Stroke}, 0.2)
    end))

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -48, 0, 42)
    btn.Position = UDim2.new(0, 24, 0, 194)
    btn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    btn.BorderSizePixel = 0
    btn.Text = L("Активировать")
    btn.TextSize = 15
    btn.TextColor3 = Color3.fromRGB(20, 20, 20)
    btn.Font = Enum.Font.GothamBold
    btn.AutoButtonColor = false
    btn.Parent = card
    corner(btn, 10)
    accentGradient(btn, 0)
    local btnScale = Instance.new("UIScale")
    btnScale.Parent = btn

    track(btn.MouseEnter:Connect(function() tween(btnScale, {Scale = 1.03}, 0.15) end))
    track(btn.MouseLeave:Connect(function() tween(btnScale, {Scale = 1}, 0.15) end))
    track(btn.MouseButton1Down:Connect(function() tween(btnScale, {Scale = 0.96}, 0.1) end))
    track(btn.MouseButton1Up:Connect(function() tween(btnScale, {Scale = 1}, 0.2, Enum.EasingStyle.Back) end))

    local status = makeLabel(card, presetMsg or "", 13, presetColor or THEME.Dim, Enum.Font.GothamMedium)
    status.Size = UDim2.new(1, -40, 0, 20)
    status.Position = UDim2.new(0, 20, 0, 248)

    local function setStatus(text, color)
        status.Text = text
        status.TextTransparency = 1
        status.TextColor3 = color
        tween(status, {TextTransparency = 0}, 0.25)
    end

    local function slideIn(obj, delay)
        local p = obj.Position
        obj.Position = p + UDim2.fromOffset(0, 14)
        task.delay(delay, function()
            if obj.Parent then tween(obj, {Position = p}, 0.45) end
        end)
    end
    slideIn(title, 0.05)
    slideIn(sub, 0.1)
    slideIn(box, 0.15)
    slideIn(btn, 0.22)
    slideIn(status, 0.28)

    tween(scale, {Scale = fit}, 0.55, Enum.EasingStyle.Back)
    tween(card, {GroupTransparency = 0}, 0.35)

    keyAnimConn = track(RunService.Heartbeat:Connect(function()
        local t = os.clock()
        barGrad.Offset = Vector2.new(math.sin(t * 1.5) * 0.5, 0)
        logoScale.Scale = 1 + 0.06 * math.sin(t * 3)
    end))

    local function shake()
        task.spawn(function()
            for _, dx in ipairs({-12, 12, -8, 8, -4, 0}) do
                tween(holder, {Position = UDim2.new(0.5, dx, 0.5, 0)}, 0.05, Enum.EasingStyle.Sine)
                task.wait(0.05)
            end
        end)
        tween(boxStroke, {Color = RED}, 0.1)
        task.delay(0.6, function()
            if boxStroke.Parent then tween(boxStroke, {Color = THEME.Stroke}, 0.3) end
        end)
    end

    local function closeWindow(after)
        tween(card, {GroupTransparency = 1}, 0.4)
        tween(scale, {Scale = fit * 1.06}, 0.4)
        tween(dim, {BackgroundTransparency = 1}, 0.45)
        tween(shadow, {BackgroundTransparency = 1}, 0.4)
        task.delay(0.5, function()
            if keyAnimConn then keyAnimConn:Disconnect() keyAnimConn = nil end
            gui:Destroy()
            if keyGui == gui then keyGui = nil end
            if after then after() end
        end)
    end

    local busy = false
    local function submit()
        if busy then return end
        busy = true
        btn.Text = L("Проверка...")
        setStatus(L("Проверка ключа..."), THEME.Dim)
        task.wait(0.6)

        local ok, msg = tryKey(box.Text)
        btn.Text = L("Активировать")
        if ok then
            setStatus(L(msg) .. L("! Добро пожаловать"), GREEN)
            task.wait(0.7)
            closeWindow(function()
                if Lic.OnUnlock then pcall(Lic.OnUnlock) end
            end)
        else
            setStatus(L(msg), RED)
            shake()
            busy = false
        end
    end

    track(btn.MouseButton1Click:Connect(submit))
    track(box.FocusLost:Connect(function(enter)
        if enter then submit() end
    end))

    if autoSubmit then
        task.delay(1.2, function()
            if gui.Parent and not busy then submit() end
        end)
    end
end

function Lic.Lock(msg)
    Lic.Active = false
    if Lic.OnLock then pcall(Lic.OnLock) end
    showKeyWindow("", msg or "Введите ключ для активации", RED, false)
end

function Lic.Logout()
    local data = loadData()
    data.current = nil
    saveData(data)
    Lic.Active = false
    Lic.Key = nil
    if Lic.OnLock then pcall(Lic.OnLock) end
    showKeyWindow("", "Введите новый ключ", THEME.Dim, false)
end

function Lic.Start()
    local data = loadData()
    local key = data.current
    local rec = key and data.used[key]
    if type(key) == "string" and KEYS[key] and type(rec) == "table" and type(rec.activated) == "number" then
        if rec.activated + KEYS[key] * 86400 > os.time() then
            showKeyWindow(key, "Найден сохранённый ключ...", THEME.Dim, true)
        else
            showKeyWindow("", "Срок ключа истёк. Введите новый", RED, false)
        end
    else
        showKeyWindow("", "Введите ключ для активации", THEME.Dim, false)
    end
end

do
    local acc = 0
    track(RunService.Heartbeat:Connect(function(dt)
        acc = acc + dt
        if acc < 1 then return end
        acc = 0
        if Lic.Active and os.time() >= Lic.Expires then
            Lic.Lock("Срок действия ключа истёк. Введите новый")
        end
    end))
end

-- ==========================================================
-- 2. ИНТЕРФЕЙС: БАЗОВЫЕ ЭЛЕМЕНТЫ
-- ==========================================================

-- линия между двумя точками экрана (через Frame)
local function setLine(f, a, b, color, thick)
    local d = b - a
    f.BackgroundColor3 = color
    f.Size = UDim2.fromOffset(d.Magnitude, thick)
    f.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
    f.Rotation = math.deg(math.atan2(d.Y, d.X))
    f.Visible = true
end

local layoutCounter = 0
local function nextOrder()
    layoutCounter = layoutCounter + 1
    return layoutCounter
end

local function createSlider(parent, y, label, tbl, key, minV, maxV, onChange, scroller)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -28, 0, 38)
    row.Position = UDim2.new(0, 14, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent

    local lbl = makeLabel(row, label, 13, THEME.Dim, Enum.Font.Gotham)
    lbl.Size = UDim2.new(0.65, 0, 0, 18)
    lbl.TextXAlignment = Enum.TextXAlignment.Left

    local valLbl = makeLabel(row, tostring(tbl[key]), 13, THEME.Accent, Enum.Font.GothamBold)
    valLbl.Size = UDim2.new(0.35, 0, 0, 18)
    valLbl.Position = UDim2.new(0.65, 0, 0, 0)
    valLbl.TextXAlignment = Enum.TextXAlignment.Right

    local track_ = Instance.new("Frame")
    track_.Size = UDim2.new(1, 0, 0, 6)
    track_.Position = UDim2.new(0, 0, 0, 27)
    track_.BackgroundColor3 = THEME.Off
    track_.BorderSizePixel = 0
    track_.Parent = row
    corner(track_, 3)

    local pct = math.clamp((tbl[key] - minV) / (maxV - minV), 0, 1)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(pct, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    fill.BorderSizePixel = 0
    fill.Parent = track_
    corner(fill, 3)
    accentGradient(fill, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(pct, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = track_
    corner(knob, 7)
    addStroke(knob, THEME.Accent, 2)

    local knobScale = Instance.new("UIScale")
    knobScale.Parent = knob

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 0, 26)
    hit.Position = UDim2.new(0, 0, 0, 16)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 2
    hit.Parent = row

    local dragging = false

    local function setVisual(val)
        local p = math.clamp((val - minV) / (maxV - minV), 0, 1)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, -7, 0.5, -7)
        valLbl.Text = tostring(val)
    end

    local function updateFromX(x)
        local p = math.clamp((x - track_.AbsolutePosition.X) / track_.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(p, 0, 1, 0)
        knob.Position = UDim2.new(p, -7, 0.5, -7)
        local val = math.floor(minV + (maxV - minV) * p + 0.5)
        tbl[key] = val
        valLbl.Text = tostring(val)
        if onChange then onChange(val) end
    end

    hit.InputBegan:Connect(function(input)
        if isPress(input) then
            dragging = true
            if scroller then scroller.ScrollingEnabled = false end
            tween(knobScale, {Scale = 1.3}, 0.15)
            updateFromX(input.Position.X)
        end
    end)
    utrack(UserInputService.InputEnded:Connect(function(input)
        if dragging and isPress(input) then
            dragging = false
            if scroller then scroller.ScrollingEnabled = true end
            tween(knobScale, {Scale = 1}, 0.2)
        end
    end))
    utrack(UserInputService.InputChanged:Connect(function(input)
        if dragging and isMove(input) then
            updateFromX(input.Position.X)
        end
    end))

    return {set = setVisual}
end

local function createSection(parent, text)
    local l = makeLabel(parent, text, 12, THEME.Dim, Enum.Font.GothamBold)
    l.Name = "NHSection"
    l.Size = UDim2.new(1, 0, 0, 20)
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.LayoutOrder = nextOrder()
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 4)
    pad.Parent = l
    return l
end

-- Мини-переключатель
local function miniSwitch(parent, pos, tbl, key, onChange)
    local sw = Instance.new("TextButton")
    sw.Size = UDim2.fromOffset(38, 20)
    sw.Position = pos
    sw.Text = ""
    sw.AutoButtonColor = false
    sw.Parent = parent
    corner(sw, 10)
    local kn = Instance.new("Frame")
    kn.Size = UDim2.fromOffset(14, 14)
    kn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    kn.BorderSizePixel = 0
    kn.Parent = sw
    corner(kn, 7)
    local function paint(animate)
        local on = tbl[key]
        local t = animate and 0.2 or 0
        tween(sw, {BackgroundColor3 = on and THEME.Accent or THEME.Off}, t)
        tween(kn, {Position = on and UDim2.new(0, 21, 0.5, -7) or UDim2.new(0, 3, 0.5, -7)}, t, Enum.EasingStyle.Back)
    end
    paint(false)
    sw.MouseButton1Click:Connect(function()
        tbl[key] = not tbl[key]
        paint(true)
        if onChange then onChange(tbl[key]) end
    end)
    return sw
end

-- ==========================================================
-- ВЫБОР ЦВЕТА: пресеты + палитра оттенков (SV) + полоса Hue (+ RGB)
-- p = {tbl, key, label = "текст", rgb = true, onChange = fn}
-- ==========================================================

local function pickerHeight(p)
    return (p.label and 20 or 0) + 158 + (p.rgb and 134 or 0)
end

local function createColorPicker(parent, y, p, scroller)
    local tbl, key = p.tbl, p.key
    local h, s, v = tbl[key]:ToHSV()

    if p.label then
        local lb = makeLabel(parent, p.label, 12, THEME.Dim, Enum.Font.GothamBold)
        lb.Size = UDim2.new(1, -28, 0, 16)
        lb.Position = UDim2.new(0, 14, 0, y + 2)
        lb.TextXAlignment = Enum.TextXAlignment.Left
        y = y + 20
    end

    local swatches = {}
    local svBase, svCur, hueCur, rgbSl
    local proxy = {r = 0, g = 0, b = 0}
    local commit

    -- пресеты
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -28, 0, 28)
    row.Position = UDim2.new(0, 14, 0, y)
    row.BackgroundTransparency = 1
    row.Parent = parent
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.Padding = UDim.new(0, 8)
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Parent = row

    for _, col in ipairs(PALETTE) do
        local sw = Instance.new("TextButton")
        sw.Size = UDim2.new(0, 24, 0, 24)
        sw.BackgroundColor3 = col
        sw.Text = ""
        sw.AutoButtonColor = false
        sw.Parent = row
        corner(sw, 12)
        local ring = addStroke(sw, Color3.fromRGB(255, 255, 255), 2, 1)
        table.insert(swatches, {color = col, ring = ring})
        sw.MouseButton1Click:Connect(function()
            h, s, v = col:ToHSV()
            commit()
        end)
    end

    -- палитра оттенков: насыщенность (X) и яркость (Y)
    svBase = Instance.new("Frame")
    svBase.Size = UDim2.new(1, -28, 0, 90)
    svBase.Position = UDim2.new(0, 14, 0, y + 36)
    svBase.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
    svBase.BorderSizePixel = 0
    svBase.ClipsDescendants = true
    svBase.Parent = parent
    corner(svBase, 8)

    local white = Instance.new("Frame")
    white.Size = UDim2.new(1, 0, 1, 0)
    white.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    white.BorderSizePixel = 0
    white.Parent = svBase
    corner(white, 8)
    local g1 = Instance.new("UIGradient")
    g1.Transparency = NumberSequence.new(0, 1)
    g1.Parent = white

    local black = Instance.new("Frame")
    black.Size = UDim2.new(1, 0, 1, 0)
    black.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    black.BorderSizePixel = 0
    black.Parent = svBase
    corner(black, 8)
    local g2 = Instance.new("UIGradient")
    g2.Transparency = NumberSequence.new(1, 0)
    g2.Rotation = 90
    g2.Parent = black

    svCur = Instance.new("Frame")
    svCur.Size = UDim2.fromOffset(14, 14)
    svCur.AnchorPoint = Vector2.new(0.5, 0.5)
    svCur.BackgroundTransparency = 1
    svCur.Active = false
    svCur.Parent = svBase
    corner(svCur, 7)
    addStroke(svCur, Color3.fromRGB(255, 255, 255), 2)

    local svHit = Instance.new("TextButton")
    svHit.Size = UDim2.new(1, 0, 1, 0)
    svHit.BackgroundTransparency = 1
    svHit.Text = ""
    svHit.Parent = svBase

    -- полоса цвета (Hue)
    local hueBar = Instance.new("Frame")
    hueBar.Size = UDim2.new(1, -28, 0, 14)
    hueBar.Position = UDim2.new(0, 14, 0, y + 134)
    hueBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueBar.BorderSizePixel = 0
    hueBar.Parent = parent
    corner(hueBar, 7)
    local hg = Instance.new("UIGradient")
    hg.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
        ColorSequenceKeypoint.new(1 / 6, Color3.fromRGB(255, 255, 0)),
        ColorSequenceKeypoint.new(2 / 6, Color3.fromRGB(0, 255, 0)),
        ColorSequenceKeypoint.new(3 / 6, Color3.fromRGB(0, 255, 255)),
        ColorSequenceKeypoint.new(4 / 6, Color3.fromRGB(0, 0, 255)),
        ColorSequenceKeypoint.new(5 / 6, Color3.fromRGB(255, 0, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 0)),
    })
    hg.Parent = hueBar

    hueCur = Instance.new("Frame")
    hueCur.Size = UDim2.fromOffset(8, 20)
    hueCur.AnchorPoint = Vector2.new(0.5, 0.5)
    hueCur.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    hueCur.BorderSizePixel = 0
    hueCur.Active = false
    hueCur.Parent = hueBar
    corner(hueCur, 4)
    addStroke(hueCur, Color3.fromRGB(20, 20, 20), 1.5)

    local hueHit = Instance.new("TextButton")
    hueHit.Size = UDim2.new(1, 0, 0, 26)
    hueHit.Position = UDim2.new(0, 0, 0.5, -13)
    hueHit.BackgroundTransparency = 1
    hueHit.Text = ""
    hueHit.Parent = hueBar

    local function paint(skipRGB)
        local c = tbl[key]
        svBase.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
        svCur.Position = UDim2.new(s, 0, 1 - v, 0)
        hueCur.Position = UDim2.new(h, 0, 0.5, 0)
        for _, sw in ipairs(swatches) do
            sw.ring.Transparency = sameColor(sw.color, c) and 0 or 1
        end
        if rgbSl and not skipRGB then
            proxy.r = math.floor(c.R * 255 + 0.5)
            proxy.g = math.floor(c.G * 255 + 0.5)
            proxy.b = math.floor(c.B * 255 + 0.5)
            rgbSl[1].set(proxy.r)
            rgbSl[2].set(proxy.g)
            rgbSl[3].set(proxy.b)
        end
    end

    commit = function(skipRGB)
        local c = Color3.fromHSV(h, s, v)
        tbl[key] = c
        paint(skipRGB)
        if p.onChange then p.onChange(c) end
    end

    bindDrag(svHit, scroller, function(pos)
        local ap, as = svBase.AbsolutePosition, svBase.AbsoluteSize
        s = math.clamp((pos.X - ap.X) / as.X, 0, 1)
        v = 1 - math.clamp((pos.Y - ap.Y) / as.Y, 0, 1)
        commit()
    end)

    bindDrag(hueHit, scroller, function(pos)
        local ap, as = hueBar.AbsolutePosition, hueBar.AbsoluteSize
        h = math.clamp((pos.X - ap.X) / as.X, 0, 0.999)
        commit()
    end)

    -- RGB ползунки
    if p.rgb then
        local c0 = tbl[key]
        proxy.r = math.floor(c0.R * 255 + 0.5)
        proxy.g = math.floor(c0.G * 255 + 0.5)
        proxy.b = math.floor(c0.B * 255 + 0.5)
        rgbSl = {}
        local names = {"R", "G", "B"}
        local keys = {"r", "g", "b"}
        for i = 1, 3 do
            rgbSl[i] = createSlider(parent, y + 156 + (i - 1) * 44, names[i], proxy, keys[i], 0, 255, function()
                h, s, v = Color3.fromRGB(proxy.r, proxy.g, proxy.b):ToHSV()
                commit(true)
            end, scroller)
        end
    end

    paint(true)
end

-- opts: {sliders = {{label, tbl, key, min, max, onChange}},
--        pickers = {{tbl, key, label, rgb, onChange}},
--        custom = fn(body, y, scroller), customH = число,
--        onChange = fn, onClose = fn, noToggle = bool}
local function createToggleCard(parent, title, tbl, key, opts)
    opts = opts or {}
    local sliders = opts.sliders or {}
    local pickers = opts.pickers or {}
    local customH = opts.customH or 0
    local bodyH = customH + #sliders * 44
    for _, p in ipairs(pickers) do bodyH = bodyH + pickerHeight(p) end
    local hasBody = bodyH > 0
    if hasBody then bodyH = bodyH + 8 end
    local HEAD = 42

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, HEAD)
    card.BackgroundColor3 = THEME.Card
    card.ClipsDescendants = true
    card.LayoutOrder = nextOrder()
    card.Parent = parent
    corner(card, 10)
    addStroke(card, THEME.Stroke, 1)

    local head = Instance.new("TextButton")
    head.Size = UDim2.new(1, 0, 0, HEAD)
    head.BackgroundTransparency = 1
    head.Text = ""
    head.AutoButtonColor = false
    head.Parent = card

    local titleLbl = makeLabel(head, title, 14, THEME.Text, Enum.Font.GothamMedium)
    titleLbl.Size = UDim2.new(1, -110, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local chevron
    if hasBody then
        chevron = makeLabel(head, "›", 22, THEME.Dim, Enum.Font.GothamBold)
        chevron.Size = UDim2.new(0, 20, 1, 0)
        chevron.Position = UDim2.new(1, opts.noToggle and -34 or -84, 0, 0)
    end

    if not opts.noToggle then
        local toggle = Instance.new("TextButton")
        toggle.Size = UDim2.new(0, 42, 0, 22)
        toggle.Position = UDim2.new(1, -54, 0.5, -11)
        toggle.Text = ""
        toggle.AutoButtonColor = false
        toggle.Parent = head
        corner(toggle, 11)

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Parent = toggle
        corner(knob, 8)

        local function paint(animate)
            local on = tbl[key]
            local t = animate and 0.22 or 0
            tween(toggle, {BackgroundColor3 = on and THEME.Accent or THEME.Off}, t)
            tween(knob, {Position = on and UDim2.new(0, 23, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, t, Enum.EasingStyle.Back)
        end
        paint(false)

        toggle.MouseButton1Click:Connect(function()
            tbl[key] = not tbl[key]
            paint(true)
            if opts.onChange then opts.onChange(tbl[key]) end
        end)
    end

    head.MouseEnter:Connect(function() tween(card, {BackgroundColor3 = THEME.CardHover}, 0.15) end)
    head.MouseLeave:Connect(function() tween(card, {BackgroundColor3 = THEME.Card}, 0.15) end)

    if hasBody then
        local body = Instance.new("Frame")
        body.Size = UDim2.new(1, 0, 0, bodyH)
        body.Position = UDim2.new(0, 0, 0, HEAD)
        body.BackgroundTransparency = 1
        body.Parent = card

        local y = 0
        if opts.custom then
            opts.custom(body, y, parent)
            y = y + customH
        end

        for _, s in ipairs(sliders) do
            createSlider(body, y, s.label, s.tbl, s.key, s.min, s.max, s.onChange, parent)
            y = y + 44
        end

        for _, pk in ipairs(pickers) do
            createColorPicker(body, y, pk, parent)
            y = y + pickerHeight(pk)
        end

        local open = false
        head.MouseButton1Click:Connect(function()
            open = not open
            tween(card, {Size = UDim2.new(1, 0, 0, open and (HEAD + bodyH) or HEAD)}, 0.32)
            if chevron then
                tween(chevron, {Rotation = open and 90 or 0, TextColor3 = open and THEME.Accent or THEME.Dim}, 0.25)
            end
            if not open and opts.onClose then opts.onClose() end
        end)
    end

    return card
end

local function createSliderCard(parent, label, tbl, key, minV, maxV, onChange)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, 54)
    card.BackgroundColor3 = THEME.Card
    card.LayoutOrder = nextOrder()
    card.Parent = parent
    corner(card, 10)
    addStroke(card, THEME.Stroke, 1)
    createSlider(card, 9, label, tbl, key, minV, maxV, onChange, parent)
    return card
end

-- ==========================================================
-- ШТОРКА AIMBOT (Combat): 2D модель игрока + цвет FOV circle
-- ==========================================================

local PART_MAP = {
    Head     = {"Head"},
    Torso    = {"UpperTorso", "Torso"},
    LeftArm  = {"LeftUpperArm", "Left Arm"},
    RightArm = {"RightUpperArm", "Right Arm"},
    LeftLeg  = {"LeftUpperLeg", "Left Leg"},
    RightLeg = {"RightUpperLeg", "Right Leg"},
}

local BODY_PARTS = {
    {key = "Head",     name = "Голова",      desc = "Точная цель, маленький хитбокс",
     pos = Vector2.new(53, 4),   size = Vector2.new(34, 34), radius = 17},
    {key = "Torso",    name = "Торс",        desc = "Самая большая площадь, наведение стабильнее",
     pos = Vector2.new(45, 42),  size = Vector2.new(50, 70), radius = 10},
    {key = "LeftArm",  name = "Левая рука",  desc = "Запасная цель сбоку",
     pos = Vector2.new(25, 44),  size = Vector2.new(16, 64), radius = 8},
    {key = "RightArm", name = "Правая рука", desc = "Запасная цель сбоку",
     pos = Vector2.new(99, 44),  size = Vector2.new(16, 64), radius = 8},
    {key = "LeftLeg",  name = "Левая нога",  desc = "Нижняя цель, удобна вблизи",
     pos = Vector2.new(47, 116), size = Vector2.new(20, 76), radius = 9},
    {key = "RightLeg", name = "Правая нога", desc = "Нижняя цель, удобна вблизи",
     pos = Vector2.new(73, 116), size = Vector2.new(20, 76), radius = 9},
}

local function createAimbotDrawer(parent)
    local CB = Config.Combat
    CB.TargetPart = CB.TargetPart or "Head"
    if not PART_MAP[CB.TargetPart] then CB.TargetPart = "Head" end

    local SEL          = Color3.fromRGB(255, 69, 58)
    local SEL_STROKE   = Color3.fromRGB(255, 150, 140)
    local IDLE         = Color3.fromRGB(70, 70, 92)
    local IDLE_STROKE  = Color3.fromRGB(100, 100, 126)
    local HOVER        = Color3.fromRGB(98, 98, 128)

    local HEAD = 42
    local STAGE_H = 210
    local SLIDERS_Y = STAGE_H + 24
    local bodyH = SLIDERS_Y + 3 * 44 + 90

    local card = Instance.new("Frame")
    card.Size = UDim2.new(1, 0, 0, HEAD)
    card.BackgroundColor3 = THEME.Card
    card.ClipsDescendants = true
    card.LayoutOrder = nextOrder()
    card.Parent = parent
    corner(card, 10)
    addStroke(card, THEME.Stroke, 1)

    local head = Instance.new("TextButton")
    head.Size = UDim2.new(1, 0, 0, HEAD)
    head.BackgroundTransparency = 1
    head.Text = ""
    head.AutoButtonColor = false
    head.Parent = card

    local titleLbl = makeLabel(head, "Aimbot", 14, THEME.Text, Enum.Font.GothamMedium)
    titleLbl.Size = UDim2.new(1, -110, 1, 0)
    titleLbl.Position = UDim2.new(0, 14, 0, 0)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local chevron = makeLabel(head, "›", 22, THEME.Dim, Enum.Font.GothamBold)
    chevron.Size = UDim2.new(0, 20, 1, 0)
    chevron.Position = UDim2.new(1, -84, 0, 0)

    local toggle = Instance.new("TextButton")
    toggle.Size = UDim2.new(0, 42, 0, 22)
    toggle.Position = UDim2.new(1, -54, 0.5, -11)
    toggle.Text = ""
    toggle.AutoButtonColor = false
    toggle.Parent = head
    corner(toggle, 11)

    local tKnob = Instance.new("Frame")
    tKnob.Size = UDim2.new(0, 16, 0, 16)
    tKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    tKnob.BorderSizePixel = 0
    tKnob.Parent = toggle
    corner(tKnob, 8)

    local function paintToggle(animate)
        local on = CB.Aimbot
        local t = animate and 0.22 or 0
        tween(toggle, {BackgroundColor3 = on and THEME.Accent or THEME.Off}, t)
        tween(tKnob, {Position = on and UDim2.new(0, 23, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, t, Enum.EasingStyle.Back)
    end
    paintToggle(false)
    toggle.MouseButton1Click:Connect(function()
        CB.Aimbot = not CB.Aimbot
        paintToggle(true)
    end)

    head.MouseEnter:Connect(function() tween(card, {BackgroundColor3 = THEME.CardHover}, 0.15) end)
    head.MouseLeave:Connect(function() tween(card, {BackgroundColor3 = THEME.Card}, 0.15) end)

    local body = Instance.new("Frame")
    body.Size = UDim2.new(1, 0, 0, bodyH)
    body.Position = UDim2.new(0, 0, 0, HEAD)
    body.BackgroundTransparency = 1
    body.Parent = card

    local stage = Instance.new("Frame")
    stage.Size = UDim2.new(1, -28, 0, STAGE_H)
    stage.Position = UDim2.new(0, 14, 0, 8)
    stage.BackgroundTransparency = 1
    stage.Parent = body

    local info = Instance.new("Frame")
    info.Size = UDim2.new(0, 150, 1, 0)
    info.BackgroundTransparency = 1
    info.Parent = stage

    local cap = makeLabel(info, "ЦЕЛЬ АИМБОТА", 11, THEME.Dim, Enum.Font.GothamBold)
    cap.Size = UDim2.new(1, 0, 0, 14)
    cap.TextXAlignment = Enum.TextXAlignment.Left

    local nameLbl = makeLabel(info, "", 20, SEL, Enum.Font.GothamBold)
    nameLbl.Size = UDim2.new(1, 0, 0, 26)
    nameLbl.Position = UDim2.new(0, 0, 0, 16)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left

    local descLbl = makeLabel(info, "", 11, THEME.Dim, Enum.Font.Gotham)
    descLbl.Size = UDim2.new(1, 0, 0, 30)
    descLbl.Position = UDim2.new(0, 0, 0, 44)
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextYAlignment = Enum.TextYAlignment.Top
    descLbl.TextWrapped = true

    local glow = Instance.new("Frame")
    glow.Size = UDim2.new(0, 160, 0, 160)
    glow.AnchorPoint = Vector2.new(0.5, 0.5)
    glow.Position = UDim2.new(1, -74, 0, 105)
    glow.BackgroundColor3 = SEL
    glow.BackgroundTransparency = 0.92
    glow.BorderSizePixel = 0
    glow.Parent = stage
    corner(glow, 80)

    local shadow = Instance.new("Frame")
    shadow.Size = UDim2.fromOffset(80, 10)
    shadow.AnchorPoint = Vector2.new(0.5, 0)
    shadow.Position = UDim2.new(1, -74, 0, 198)
    shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    shadow.BackgroundTransparency = 0.6
    shadow.BorderSizePixel = 0
    shadow.Parent = stage
    corner(shadow, 5)

    local model = Instance.new("Frame")
    model.Size = UDim2.fromOffset(140, 200)
    model.AnchorPoint = Vector2.new(1, 0)
    model.Position = UDim2.new(1, -4, 0, 5)
    model.BackgroundTransparency = 1
    model.Parent = stage

    local partUI, rowUI = {}, {}

    for _, p in ipairs(BODY_PARTS) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(p.size.X, p.size.Y)
        b.Position = UDim2.fromOffset(p.pos.X, p.pos.Y)
        b.BackgroundColor3 = IDLE
        b.BorderSizePixel = 0
        b.Text = ""
        b.AutoButtonColor = false
        b.ZIndex = 2
        b.Parent = model
        corner(b, p.radius)
        local st = addStroke(b, IDLE_STROKE, 1.5)
        local sc = Instance.new("UIScale")
        sc.Parent = b

        partUI[p.key] = {
            btn = b, stroke = st, scale = sc,
            center = Vector2.new(p.pos.X + p.size.X / 2, p.pos.Y + p.size.Y / 2),
        }

        if p.key == "Head" then
            for _, ex in ipairs({10, 22}) do
                local eye = Instance.new("Frame")
                eye.Size = UDim2.fromOffset(4, 4)
                eye.Position = UDim2.fromOffset(ex, 14)
                eye.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                eye.BackgroundTransparency = 0.35
                eye.BorderSizePixel = 0
                eye.Active = false
                eye.ZIndex = 3
                eye.Parent = b
                corner(eye, 2)
            end
        end
    end

    local marker = Instance.new("Frame")
    marker.Size = UDim2.fromOffset(26, 26)
    marker.AnchorPoint = Vector2.new(0.5, 0.5)
    marker.BackgroundTransparency = 1
    marker.Active = false
    marker.ZIndex = 5
    marker.Parent = model
    corner(marker, 13)
    local markerStroke = addStroke(marker, Color3.fromRGB(255, 255, 255), 2)
    local markerScale = Instance.new("UIScale")
    markerScale.Parent = marker
    local markerDot = Instance.new("Frame")
    markerDot.Size = UDim2.fromOffset(4, 4)
    markerDot.AnchorPoint = Vector2.new(0.5, 0.5)
    markerDot.Position = UDim2.new(0.5, 0, 0.5, 0)
    markerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    markerDot.BorderSizePixel = 0
    markerDot.Active = false
    markerDot.ZIndex = 5
    markerDot.Parent = marker
    corner(markerDot, 2)

    local token = 0

    local function setText(label, text, myToken)
        tween(label, {TextTransparency = 1}, 0.1)
        task.delay(0.1, function()
            if token ~= myToken then return end
            label.Text = text
            tween(label, {TextTransparency = 0}, 0.2)
        end)
    end

    local function selectPart(key, animate)
        CB.TargetPart = key
        token = token + 1
        local myToken = token
        local t = animate and 0.25 or 0

        for _, p in ipairs(BODY_PARTS) do
            local on = (p.key == key)
            local ui, row = partUI[p.key], rowUI[p.key]

            tween(ui.btn, {BackgroundColor3 = on and SEL or IDLE}, t)
            tween(ui.stroke, {Color = on and SEL_STROKE or IDLE_STROKE}, t)
            tween(row.dot, {BackgroundColor3 = on and SEL or THEME.Off}, t)
            tween(row.txt, {TextColor3 = on and THEME.Text or THEME.Dim}, t)

            if on then
                if animate then
                    setText(nameLbl, L(p.name), myToken)
                    setText(descLbl, L(p.desc), myToken)
                    ui.scale.Scale = 0.88
                    tween(ui.scale, {Scale = 1}, 0.4, Enum.EasingStyle.Back)
                else
                    nameLbl.Text = L(p.name)
                    descLbl.Text = L(p.desc)
                end
                tween(marker, {Position = UDim2.fromOffset(ui.center.X, ui.center.Y)}, t, Enum.EasingStyle.Back)
            end
        end
    end

    for i, p in ipairs(BODY_PARTS) do
        local rb = Instance.new("TextButton")
        rb.Size = UDim2.new(1, 0, 0, 20)
        rb.Position = UDim2.new(0, 0, 0, 82 + (i - 1) * 21)
        rb.BackgroundTransparency = 1
        rb.Text = ""
        rb.AutoButtonColor = false
        rb.Parent = info

        local dotF = Instance.new("Frame")
        dotF.Size = UDim2.fromOffset(8, 8)
        dotF.Position = UDim2.new(0, 2, 0.5, -4)
        dotF.BackgroundColor3 = THEME.Off
        dotF.BorderSizePixel = 0
        dotF.Parent = rb
        corner(dotF, 4)

        local txt = makeLabel(rb, p.name, 13, THEME.Dim, Enum.Font.GothamMedium)
        txt.Size = UDim2.new(1, -18, 1, 0)
        txt.Position = UDim2.new(0, 18, 0, 0)
        txt.TextXAlignment = Enum.TextXAlignment.Left

        rowUI[p.key] = {dot = dotF, txt = txt}

        rb.MouseButton1Click:Connect(function() selectPart(p.key, true) end)
        rb.MouseEnter:Connect(function()
            if CB.TargetPart ~= p.key then tween(txt, {TextColor3 = Color3.fromRGB(200, 200, 215)}, 0.12) end
        end)
        rb.MouseLeave:Connect(function()
            if CB.TargetPart ~= p.key then tween(txt, {TextColor3 = THEME.Dim}, 0.12) end
        end)
    end

    for _, p in ipairs(BODY_PARTS) do
        local ui = partUI[p.key]
        ui.btn.MouseButton1Click:Connect(function() selectPart(p.key, true) end)
        ui.btn.MouseEnter:Connect(function()
            if CB.TargetPart ~= p.key then tween(ui.btn, {BackgroundColor3 = HOVER}, 0.12) end
        end)
        ui.btn.MouseLeave:Connect(function()
            if CB.TargetPart ~= p.key then tween(ui.btn, {BackgroundColor3 = IDLE}, 0.12) end
        end)
    end

    selectPart(CB.TargetPart, false)

    local smoothProxy = {v = math.floor(CB.AimbotSmoothness * 100 + 0.5)}
    local predProxy = {v = math.floor(CB.Prediction * 100 + 0.5)}

    createSlider(body, SLIDERS_Y, "FOV", CB, "AimbotFOV", 30, 500, nil, parent)
    createSlider(body, SLIDERS_Y + 44, "Скорость наводки %", smoothProxy, "v", 1, 100,
        function(v) CB.AimbotSmoothness = v / 100 end, parent)
    createSlider(body, SLIDERS_Y + 88, "Упреждение (сотые сек)", predProxy, "v", 0, 30,
        function(v) CB.Prediction = v / 100 end, parent)

    local fovY = SLIDERS_Y + 132 + 4

    local fovLbl = makeLabel(body, "Показывать круг FOV", 13, THEME.Dim, Enum.Font.Gotham)
    fovLbl.Size = UDim2.new(1, -80, 0, 30)
    fovLbl.Position = UDim2.new(0, 14, 0, fovY)
    fovLbl.TextXAlignment = Enum.TextXAlignment.Left

    miniSwitch(body, UDim2.new(1, -52, 0, fovY + 5), CB, "ShowFOV")

    local colLbl = makeLabel(body, "Цвет круга FOV", 12, THEME.Dim, Enum.Font.Gotham)
    colLbl.Size = UDim2.new(1, -28, 0, 16)
    colLbl.Position = UDim2.new(0, 14, 0, fovY + 34)
    colLbl.TextXAlignment = Enum.TextXAlignment.Left

    local palRow = Instance.new("Frame")
    palRow.Size = UDim2.new(1, -28, 0, 26)
    palRow.Position = UDim2.new(0, 14, 0, fovY + 52)
    palRow.BackgroundTransparency = 1
    palRow.Parent = body

    local palList = Instance.new("UIListLayout")
    palList.FillDirection = Enum.FillDirection.Horizontal
    palList.Padding = UDim.new(0, 8)
    palList.VerticalAlignment = Enum.VerticalAlignment.Center
    palList.Parent = palRow

    local swatches = {}
    local function refreshRings()
        for _, s in ipairs(swatches) do
            tween(s.ring, {Transparency = sameColor(s.color, CB.Colors.AimbotFOV) and 0 or 1}, 0.2)
        end
    end
    for _, col in ipairs(PALETTE) do
        local s = Instance.new("TextButton")
        s.Size = UDim2.fromOffset(24, 24)
        s.BackgroundColor3 = col
        s.Text = ""
        s.AutoButtonColor = false
        s.Parent = palRow
        corner(s, 12)
        local ring = addStroke(s, Color3.fromRGB(255, 255, 255), 2,
            sameColor(col, CB.Colors.AimbotFOV) and 0 or 1)
        table.insert(swatches, {color = col, ring = ring})
        s.MouseButton1Click:Connect(function()
            CB.Colors.AimbotFOV = col
            refreshRings()
        end)
    end

    local opened, isOpen = false, false

    local function playIntro()
        for i, p in ipairs(BODY_PARTS) do
            local sc = partUI[p.key].scale
            sc.Scale = 0
            task.delay(0.05 * i, function()
                tween(sc, {Scale = 1}, 0.5, Enum.EasingStyle.Back)
            end)
        end
        markerStroke.Transparency = 1
        markerDot.BackgroundTransparency = 1
        task.delay(0.4, function()
            tween(markerStroke, {Transparency = 0}, 0.3)
            tween(markerDot, {BackgroundTransparency = 0}, 0.3)
        end)
        local labels = {cap, nameLbl, descLbl}
        for _, r in pairs(rowUI) do table.insert(labels, r.txt) end
        for i, l in ipairs(labels) do
            l.TextTransparency = 1
            task.delay(0.04 * i, function() tween(l, {TextTransparency = 0}, 0.3) end)
        end
    end

    head.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        tween(card, {Size = UDim2.new(1, 0, 0, isOpen and (HEAD + bodyH + 6) or HEAD)}, 0.36)
        tween(chevron, {Rotation = isOpen and 90 or 0, TextColor3 = isOpen and THEME.Accent or THEME.Dim}, 0.25)
        if isOpen then
            opened = true
            playIntro()
        else
            task.delay(0.4, function() if not isOpen then opened = false end end)
        end
    end)

    utrack(RunService.Heartbeat:Connect(function()
        if not opened then return end
        local t = os.clock()
        model.Position = UDim2.new(1, -4, 0, 5 + math.sin(t * 2) * 2)
        markerScale.Scale = 1 + 0.12 * math.sin(t * 5)
        glow.BackgroundTransparency = 0.91 + 0.03 * math.sin(t * 2)
        shadow.Size = UDim2.fromOffset(80 - math.sin(t * 2) * 4, 10)
    end))

    return card
end

-- ==========================================================
-- SHOW FPS: блок «экран» с перетаскиваемым значком
-- ==========================================================

local function buildFpsCustom(body, y, scroller)
    local V = Config.Visual

    local cap = makeLabel(body, "Свой FPS", 13, THEME.Dim, Enum.Font.Gotham)
    cap.Size = UDim2.new(1, -80, 0, 20)
    cap.Position = UDim2.new(0, 14, 0, y + 8)
    cap.TextXAlignment = Enum.TextXAlignment.Left
    miniSwitch(body, UDim2.new(1, -52, 0, y + 9), V, "FPSCustom")

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, 104, 0, 32)
    box.Position = UDim2.new(0, 14, 0, y + 38)
    box.BackgroundColor3 = THEME.Bg
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamBold
    box.TextSize = 14
    box.TextColor3 = THEME.Accent
    box.PlaceholderText = "999"
    box.PlaceholderColor3 = THEME.Dim
    box.Text = tostring(V.FPSValue)
    box.ClearTextOnFocus = false
    box.Parent = body
    corner(box, 8)
    local bs = addStroke(box, THEME.Stroke, 1.5)
    box.Focused:Connect(function() tween(bs, {Color = THEME.Accent}, 0.2) end)
    box.FocusLost:Connect(function()
        tween(bs, {Color = THEME.Stroke}, 0.2)
        local digits = box.Text:gsub("%D", "")
        local n = tonumber(digits)
        if n then n = math.clamp(math.floor(n), 0, 99999) else n = V.FPSValue end
        V.FPSValue = n
        box.Text = tostring(n)
    end)

    local hint = makeLabel(body, "Перетащите значок по экрану", 11, THEME.Dim, Enum.Font.Gotham)
    hint.Size = UDim2.new(1, -140, 0, 32)
    hint.Position = UDim2.new(0, 126, 0, y + 38)
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Center
    hint.TextWrapped = true

    -- 2D «экран»
    local mock = Instance.new("Frame")
    mock.Size = UDim2.new(1, -28, 0, 100)
    mock.Position = UDim2.new(0, 14, 0, y + 78)
    mock.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    mock.BorderSizePixel = 0
    mock.ClipsDescendants = true
    mock.Parent = body
    corner(mock, 8)
    addStroke(mock, THEME.Stroke, 1.5)
    local mg = Instance.new("UIGradient")
    mg.Color = ColorSequence.new(Color3.fromRGB(46, 52, 84), Color3.fromRGB(16, 18, 30))
    mg.Rotation = 90
    mg.Parent = mock

    local ground = Instance.new("Frame")
    ground.Size = UDim2.new(1, 0, 0.28, 0)
    ground.Position = UDim2.new(0, 0, 0.72, 0)
    ground.BackgroundColor3 = Color3.fromRGB(28, 32, 50)
    ground.BorderSizePixel = 0
    ground.Parent = mock

    local badge = makeLabel(mock, "60 FPS", 11, V.Colors.FPS, Enum.Font.GothamBold)
    badge.AutomaticSize = Enum.AutomaticSize.XY
    badge.Size = UDim2.fromOffset(0, 0)
    badge.TextStrokeTransparency = 0.5
    badge.ZIndex = 3

    local function placeBadge()
        badge.AnchorPoint = Vector2.new(V.FPSX, V.FPSY)
        badge.Position = UDim2.new(V.FPSX, 4 - 8 * V.FPSX, V.FPSY, 4 - 8 * V.FPSY)
    end
    placeBadge()

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.new(1, 0, 1, 0)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 4
    hit.Parent = mock

    bindDrag(hit, scroller, function(pos)
        local ap, as = mock.AbsolutePosition, mock.AbsoluteSize
        V.FPSX = math.clamp((pos.X - ap.X) / as.X, 0, 1)
        V.FPSY = math.clamp((pos.Y - ap.Y) / as.Y, 0, 1)
        placeBadge()
    end)

    utrack(RunService.Heartbeat:Connect(function()
        if not badge.Parent then return end
        badge.TextColor3 = V.Colors.FPS
        badge.Text = (V.FPSCustom and V.FPSValue or 60) .. " FPS"
    end))
end

-- ==========================================================
-- СТРАНИЦЫ: World / Config / Settings
-- ==========================================================

local SHADERS = {
    {id = "Sakura", name = "Сакура", p1 = Color3.fromRGB(255, 143, 190), p2 = Color3.fromRGB(255, 228, 240),
     tint = Color3.fromRGB(255, 214, 232), sat = 0.25, con = 0.08, bri = 0.03,
     bloom = 0.9, bloomSize = 40, bloomT = 0.9, rays = 0.12, top = Color3.fromRGB(255, 170, 200), exp = 0.1,
     particle = {color = Color3.fromRGB(255, 183, 213), rate = 22}},
    {id = "Blood", name = "Кровь", p1 = Color3.fromRGB(110, 0, 10), p2 = Color3.fromRGB(255, 45, 55),
     tint = Color3.fromRGB(255, 150, 150), sat = 0.1, con = 0.25, bri = -0.08,
     bloom = 0.6, bloomSize = 36, bloomT = 0.9, rays = 0, top = Color3.fromRGB(255, 50, 50), exp = -0.3,
     particle = {color = Color3.fromRGB(200, 10, 20), rate = 16}},
    {id = "4K", name = "4K", p1 = Color3.fromRGB(20, 26, 44), p2 = Color3.fromRGB(90, 205, 255),
     tint = Color3.fromRGB(245, 250, 255), sat = 0.3, con = 0.2, bri = 0,
     bloom = 0.4, bloomSize = 24, bloomT = 1, rays = 0.08, top = Color3.fromRGB(255, 255, 255), exp = 0},
    {id = "Sunset", name = "Закат", p1 = Color3.fromRGB(255, 96, 60), p2 = Color3.fromRGB(255, 210, 95),
     tint = Color3.fromRGB(255, 200, 150), sat = 0.3, con = 0.1, bri = 0,
     bloom = 0.8, bloomSize = 40, bloomT = 0.9, rays = 0.2, top = Color3.fromRGB(255, 150, 80), exp = 0.05},
    {id = "Neon", name = "Неон", p1 = Color3.fromRGB(140, 40, 255), p2 = Color3.fromRGB(0, 230, 255),
     tint = Color3.fromRGB(205, 185, 255), sat = 0.6, con = 0.25, bri = -0.02,
     bloom = 1.4, bloomSize = 48, bloomT = 0.8, rays = 0, top = Color3.fromRGB(170, 100, 255), exp = 0},
    {id = "Ocean", name = "Океан", p1 = Color3.fromRGB(0, 80, 165), p2 = Color3.fromRGB(95, 225, 225),
     tint = Color3.fromRGB(170, 220, 255), sat = 0.2, con = 0.1, bri = 0,
     bloom = 0.5, bloomSize = 30, bloomT = 0.95, rays = 0.1, top = Color3.fromRGB(120, 200, 255), exp = 0},
}

local function buildShaderTiles(body, y, scroller)
    local W = Config.World
    local grid = Instance.new("Frame")
    grid.Size = UDim2.new(1, -28, 0, 122)
    grid.Position = UDim2.new(0, 14, 0, y + 4)
    grid.BackgroundTransparency = 1
    grid.Parent = body

    local layout = Instance.new("UIGridLayout")
    layout.CellSize = UDim2.new(0.3333, -4, 0, 58)
    layout.CellPadding = UDim2.fromOffset(6, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = grid

    local strokes = {}
    for i, sh in ipairs(SHADERS) do
        local tile = Instance.new("TextButton")
        tile.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        tile.BorderSizePixel = 0
        tile.Text = ""
        tile.AutoButtonColor = false
        tile.LayoutOrder = i
        tile.Parent = grid
        corner(tile, 8)

        local g = Instance.new("UIGradient")
        g.Color = ColorSequence.new(sh.p1, sh.p2)
        g.Rotation = 45
        g.Parent = tile

        local st = addStroke(tile, Color3.fromRGB(255, 255, 255), 2, (sh.id == W.ShaderName) and 0 or 1)
        strokes[sh.id] = st

        local nm = makeLabel(tile, sh.name, 12, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBold)
        nm.Size = UDim2.new(1, 0, 0, 18)
        nm.Position = UDim2.new(0, 0, 1, -21)
        nm.TextStrokeTransparency = 0.4

        tile.MouseButton1Click:Connect(function()
            W.ShaderName = sh.id
            for id, s in pairs(strokes) do
                tween(s, {Transparency = (id == sh.id) and 0 or 1}, 0.2)
            end
        end)
    end
end

local function buildWorldPage(page)
    local W = Config.World
    createSection(page, "Шейдеры")
    createToggleCard(page, "Шейдеры", W, "Shader", {
        customH = 134,
        custom = buildShaderTiles,
        sliders = {{label = "Интенсивность %", tbl = W, key = "Intensity", min = 10, max = 100}},
    })
    createSection(page, "Небо и свет")
    createToggleCard(page, "Чёрное небо", W, "BlackSky")
    createToggleCard(page, "Затемнение экрана", W, "Dark", {
        sliders = {{label = "Сила затемнения %", tbl = W, key = "DarkAmount", min = 5, max = 90}}
    })
    createToggleCard(page, "Свечение экрана", W, "Glow", {
        sliders = {{label = "Сила свечения %", tbl = W, key = "GlowAmount", min = 5, max = 100}}
    })
    createToggleCard(page, "Цветокоррекция", W, "Grade", {
        sliders = {
            {label = "Насыщенность", tbl = W, key = "Saturation", min = -100, max = 100},
            {label = "Контраст", tbl = W, key = "Contrast", min = -50, max = 100},
        }
    })
    createToggleCard(page, "Время суток", W, "Time", {
        sliders = {{label = "Час", tbl = W, key = "TimeValue", min = 0, max = 24}}
    })
    createToggleCard(page, "Fullbright", W, "Fullbright")
end

-- ----- Config -----
local function getConfigs()
    local d = readJson(CONFIGS_FILE, "NurHubCfgMem")
    local list = {}
    if d and type(d.list) == "table" then
        for _, e in ipairs(d.list) do
            if type(e) == "table" and type(e.name) == "string" and type(e.data) == "table" and #list < 5 then
                table.insert(list, e)
            end
        end
    end
    return list
end

local function putConfigs(list)
    writeJson(CONFIGS_FILE, "NurHubCfgMem", {list = list})
end

local function buildConfigPage(page)
    createSection(page, "Конфиги")

    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 236)
    wrap.BackgroundTransparency = 1
    wrap.LayoutOrder = nextOrder()
    wrap.Parent = page

    local function panel(pos, size)
        local f = Instance.new("Frame")
        f.Position = pos
        f.Size = size
        f.BackgroundColor3 = THEME.Card
        f.BorderSizePixel = 0
        f.Parent = wrap
        corner(f, 10)
        addStroke(f, THEME.Stroke, 1)
        return f
    end

    local left = panel(UDim2.new(0, 0, 0, 0), UDim2.new(0.42, -4, 1, 0))
    local right = panel(UDim2.new(0.42, 4, 0, 0), UDim2.new(0.58, -4, 1, 0))

    -- ЛЕВАЯ ЧАСТЬ: новый конфиг
    local t1 = makeLabel(left, "Новый конфиг", 14, THEME.Text, Enum.Font.GothamBold)
    t1.Size = UDim2.new(1, -24, 0, 20)
    t1.Position = UDim2.new(0, 12, 0, 10)
    t1.TextXAlignment = Enum.TextXAlignment.Left

    local hint = makeLabel(left, "Сохраните текущие настройки под своим именем", 11, THEME.Dim, Enum.Font.Gotham)
    hint.Size = UDim2.new(1, -24, 0, 44)
    hint.Position = UDim2.new(0, 12, 0, 32)
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.TextYAlignment = Enum.TextYAlignment.Top
    hint.TextWrapped = true

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -24, 0, 34)
    box.Position = UDim2.new(0, 12, 0, 82)
    box.BackgroundColor3 = THEME.Bg
    box.BorderSizePixel = 0
    box.Font = Enum.Font.GothamMedium
    box.TextSize = 13
    box.TextColor3 = THEME.Text
    box.PlaceholderText = L("Имя конфига...")
    box.PlaceholderColor3 = THEME.Dim
    box.Text = ""
    box.ClearTextOnFocus = false
    box.Parent = left
    corner(box, 8)
    local bs = addStroke(box, THEME.Stroke, 1.5)
    box.Focused:Connect(function() tween(bs, {Color = THEME.Accent}, 0.2) end)
    box.FocusLost:Connect(function() tween(bs, {Color = THEME.Stroke}, 0.2) end)

    local save = Instance.new("TextButton")
    save.Size = UDim2.new(1, -24, 0, 34)
    save.Position = UDim2.new(0, 12, 0, 124)
    save.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    save.BorderSizePixel = 0
    save.Text = L("Сохранить")
    save.TextSize = 14
    save.TextColor3 = Color3.fromRGB(20, 20, 20)
    save.Font = Enum.Font.GothamBold
    save.AutoButtonColor = false
    save.Parent = left
    corner(save, 8)
    accentGradient(save, 0)
    local saveScale = Instance.new("UIScale")
    saveScale.Parent = save
    save.MouseEnter:Connect(function() tween(saveScale, {Scale = 1.03}, 0.15) end)
    save.MouseLeave:Connect(function() tween(saveScale, {Scale = 1}, 0.15) end)
    save.MouseButton1Down:Connect(function() tween(saveScale, {Scale = 0.96}, 0.1) end)
    save.MouseButton1Up:Connect(function() tween(saveScale, {Scale = 1}, 0.2, Enum.EasingStyle.Back) end)

    local counter = makeLabel(left, "", 12, THEME.Dim, Enum.Font.GothamMedium)
    counter.Size = UDim2.new(1, -24, 0, 18)
    counter.Position = UDim2.new(0, 12, 0, 166)
    counter.TextXAlignment = Enum.TextXAlignment.Left

    local status = makeLabel(left, "", 12, THEME.Dim, Enum.Font.GothamMedium)
    status.Size = UDim2.new(1, -24, 0, 40)
    status.Position = UDim2.new(0, 12, 0, 188)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.TextYAlignment = Enum.TextYAlignment.Top
    status.TextWrapped = true

    local function setStatus(text, color)
        status.Text = L(text)
        status.TextColor3 = color
        status.TextTransparency = 1
        tween(status, {TextTransparency = 0}, 0.25)
    end

    -- ПРАВАЯ ЧАСТЬ: сохранённые
    local t2 = makeLabel(right, "Сохранённые", 14, THEME.Text, Enum.Font.GothamBold)
    t2.Size = UDim2.new(1, -24, 0, 20)
    t2.Position = UDim2.new(0, 12, 0, 10)
    t2.TextXAlignment = Enum.TextXAlignment.Left

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -16, 1, -40)
    holder.Position = UDim2.new(0, 8, 0, 34)
    holder.BackgroundTransparency = 1
    holder.Parent = right

    local refresh

    local function loadConfig(e)
        local d = e.data
        applyInto(Config.Visual, d.Visual)
        applyInto(Config.Combat, d.Combat)
        applyInto(Config.Player, d.Player)
        applyInto(Config.World, d.World)
        Store.cfgActive = e.name
        if Config.Player.ThirdPerson ~= Store.tp then
            Store.tp = Config.Player.ThirdPerson
            applyThirdPerson(Store.tp)
        end
        Store.rebuild("Config")
    end

    refresh = function()
        for _, c in ipairs(holder:GetChildren()) do c:Destroy() end
        local list = getConfigs()
        counter.Text = L("Слоты") .. ": " .. #list .. " / 5"

        for i = 1, 5 do
            local item = list[i]
            local active = item ~= nil and item.name == Store.cfgActive

            local b = Instance.new("TextButton")
            b.Size = UDim2.new(1, 0, 0, 35)
            b.Position = UDim2.new(0, 0, 0, (i - 1) * 39)
            b.BackgroundColor3 = THEME.Bg
            b.BorderSizePixel = 0
            b.Text = ""
            b.AutoButtonColor = false
            b.Parent = holder
            corner(b, 8)
            addStroke(b, active and THEME.Accent or THEME.Stroke, 1.5)

            local num = makeLabel(b, tostring(i), 12, THEME.Dim, Enum.Font.GothamBold)
            num.Size = UDim2.new(0, 20, 1, 0)
            num.Position = UDim2.new(0, 6, 0, 0)

            if item then
                local nm = makeLabel(b, item.name, 13, active and THEME.Accent or THEME.Text, Enum.Font.GothamMedium)
                nm.Size = UDim2.new(1, -66, 1, 0)
                nm.Position = UDim2.new(0, 28, 0, 0)
                nm.TextXAlignment = Enum.TextXAlignment.Left
                nm.TextTruncate = Enum.TextTruncate.AtEnd

                local del = Instance.new("TextButton")
                del.Size = UDim2.new(0, 26, 0, 26)
                del.Position = UDim2.new(1, -30, 0.5, -13)
                del.BackgroundColor3 = THEME.Card
                del.Text = "×"
                del.TextSize = 18
                del.TextColor3 = THEME.Dim
                del.Font = Enum.Font.GothamBold
                del.AutoButtonColor = false
                del.Parent = b
                corner(del, 6)
                del.MouseEnter:Connect(function()
                    tween(del, {BackgroundColor3 = RED, TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.15)
                end)
                del.MouseLeave:Connect(function()
                    tween(del, {BackgroundColor3 = THEME.Card, TextColor3 = THEME.Dim}, 0.15)
                end)
                del.MouseButton1Click:Connect(function()
                    local cur = getConfigs()
                    table.remove(cur, i)
                    putConfigs(cur)
                    if Store.cfgActive == item.name then Store.cfgActive = nil end
                    refresh()
                end)

                b.MouseEnter:Connect(function() tween(b, {BackgroundColor3 = THEME.CardHover}, 0.15) end)
                b.MouseLeave:Connect(function() tween(b, {BackgroundColor3 = THEME.Bg}, 0.15) end)
                b.MouseButton1Click:Connect(function() loadConfig(item) end)
            else
                local em = makeLabel(b, "— пусто —", 12, THEME.Off, Enum.Font.Gotham)
                em.Size = UDim2.new(1, -40, 1, 0)
                em.Position = UDim2.new(0, 28, 0, 0)
                em.TextXAlignment = Enum.TextXAlignment.Left
            end
        end
    end

    save.MouseButton1Click:Connect(function()
        local name = box.Text:gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" then setStatus("Введите имя", RED) return end
        local len = utf8.len(name)
        if len and len > 16 then name = name:sub(1, utf8.offset(name, 17) - 1) end

        local list = getConfigs()
        local data = ser({
            Visual = Config.Visual, Combat = Config.Combat,
            Player = Config.Player, World = Config.World,
        })

        local idx
        for i, e in ipairs(list) do
            if e.name == name then idx = i break end
        end

        if idx then
            list[idx].data = data
            setStatus("Конфиг обновлён", GREEN)
        elseif #list >= 5 then
            setStatus("Максимум 5 конфигов", RED)
            return
        else
            table.insert(list, {name = name, data = data})
            setStatus("Конфиг сохранён", GREEN)
        end
        putConfigs(list)
        Store.cfgActive = name
        box.Text = ""
        refresh()
    end)

    refresh()
end

-- ----- Settings -----
local function applyLookSafe()
    if UI and UI.applyLook then UI.applyLook() end
end

local function buildSettingsPage(page)
    createSection(page, "Управление")

    createToggleCard(page, "PC режим", Settings, "PCMode", {
        customH = 84,
        custom = function(body, y)
            local kb = Instance.new("TextButton")
            kb.Size = UDim2.new(1, -28, 0, 32)
            kb.Position = UDim2.new(0, 14, 0, y + 6)
            kb.BackgroundColor3 = THEME.Bg
            kb.BorderSizePixel = 0
            kb.TextSize = 13
            kb.TextColor3 = THEME.Text
            kb.Font = Enum.Font.GothamMedium
            kb.AutoButtonColor = false
            kb.Parent = body
            corner(kb, 8)
            addStroke(kb, THEME.Stroke, 1.5)

            local function kbText()
                kb.Text = L("Клавиша меню") .. ": " .. Settings.MenuKey
            end
            kbText()

            kb.MouseButton1Click:Connect(function()
                if Store.binding then return end
                Store.binding = true
                kb.Text = L("Нажмите клавишу...")
                local conn
                conn = UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Keyboard then
                        conn:Disconnect()
                        if input.KeyCode ~= Enum.KeyCode.Escape and input.KeyCode ~= Enum.KeyCode.Unknown then
                            Settings.MenuKey = input.KeyCode.Name
                            saveSettings()
                        end
                        kbText()
                        task.delay(0.15, function() Store.binding = false end)
                    end
                end)
                utrack(conn)
            end)

            local hl = makeLabel(body, "Скрыть кнопку N", 13, THEME.Dim, Enum.Font.Gotham)
            hl.Size = UDim2.new(1, -80, 0, 30)
            hl.Position = UDim2.new(0, 14, 0, y + 44)
            hl.TextXAlignment = Enum.TextXAlignment.Left
            miniSwitch(body, UDim2.new(1, -52, 0, y + 49), Settings, "HideLauncher", function()
                saveSettings()
                applyLookSafe()
            end)
        end,
        onChange = function()
            saveSettings()
            applyLookSafe()
        end,
    })

    createSection(page, "Внешний вид")

    createToggleCard(page, "Размер меню", nil, nil, {
        noToggle = true,
        sliders = {{label = "Масштаб %", tbl = Settings, key = "Scale", min = 50, max = 150,
            onChange = function() saveSettingsSoon() applyLookSafe() end}},
    })

    createToggleCard(page, "Прозрачность меню", nil, nil, {
        noToggle = true,
        sliders = {{label = "Прозрачность %", tbl = Settings, key = "Transparency", min = 0, max = 70,
            onChange = function() saveSettingsSoon() applyLookSafe() end}},
    })

    local function themeChanged()
        THEME.Accent = Settings.Colors.Grad1
        THEME.Accent2 = Settings.Colors.Grad2
        Store.themeDirty = true
        refreshGradients()
        saveSettingsSoon()
    end

    createToggleCard(page, "Цвет меню (градиент)", nil, nil, {
        noToggle = true,
        pickers = {
            {tbl = Settings.Colors, key = "Grad1", label = "Цвет 1", rgb = true, onChange = themeChanged},
            {tbl = Settings.Colors, key = "Grad2", label = "Цвет 2", rgb = true, onChange = themeChanged},
        },
        onClose = function()
            if Store.themeDirty then
                Store.themeDirty = false
                Store.rebuild("Settings")
            end
        end,
    })

    createSection(page, "Язык")

    local lc = Instance.new("Frame")
    lc.Size = UDim2.new(1, 0, 0, 50)
    lc.BackgroundColor3 = THEME.Card
    lc.LayoutOrder = nextOrder()
    lc.Parent = page
    corner(lc, 10)
    addStroke(lc, THEME.Stroke, 1)

    local ll = makeLabel(lc, "Язык интерфейса", 14, THEME.Text, Enum.Font.GothamMedium)
    ll.Size = UDim2.new(1, -190, 1, 0)
    ll.TextSize = 13
    ll.TextWrapped = true
    ll.Position = UDim2.new(0, 14, 0, 0)
    ll.TextXAlignment = Enum.TextXAlignment.Left

    local function langButton(code, text, posX)
        local active = (Settings.Lang == code)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(0, 80, 0, 30)
        b.Position = UDim2.new(1, posX, 0.5, -15)
        b.BackgroundColor3 = active and Color3.fromRGB(255, 255, 255) or THEME.Off
        b.BorderSizePixel = 0
        b.Text = text
        b.TextSize = 13
        b.TextColor3 = active and Color3.fromRGB(20, 20, 20) or THEME.Dim
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.Parent = lc
        corner(b, 8)
        if active then accentGradient(b, 0) end
        b.MouseButton1Click:Connect(function()
            if Settings.Lang ~= code then
                Settings.Lang = code
                saveSettings()
                Store.rebuild("Settings")
            end
        end)
    end
    langButton("ru", "Русский", -176)
    langButton("en", "English", -90)
end

-- ==========================================================
-- 2.5 ИНТЕРФЕЙС: ОКНО
-- ==========================================================

local WIN_W, WIN_H = 860, 400

-- Делит страницу на две колонки. Элементы с атрибутом NHFull остаются сверху на всю ширину.
local function splitColumns(scroll)
    local items = {}
    for _, c in ipairs(scroll:GetChildren()) do
        if c:IsA("GuiObject") then table.insert(items, c) end
    end
    table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)

    local groups, cur = {}, nil
    for _, it in ipairs(items) do
        if it:GetAttribute("NHFull") then
            cur = nil
        else
            if it.Name == "NHSection" or not cur then
                cur = {h = 0, items = {}}
                table.insert(groups, cur)
            end
            table.insert(cur.items, it)
            cur.h = cur.h + it.Size.Y.Offset + 8
        end
    end
    if #groups == 0 then return end

    local cols = Instance.new("Frame")
    cols.Name = "NHColumns"
    cols.BackgroundTransparency = 1
    cols.Size = UDim2.new(1, 0, 0, 0)
    cols.AutomaticSize = Enum.AutomaticSize.Y
    cols.LayoutOrder = 100000
    cols.Parent = scroll

    local function makeCol(pos)
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.Position = pos
        f.Size = UDim2.new(0.5, -6, 0, 0)
        f.AutomaticSize = Enum.AutomaticSize.Y
        f.Parent = cols
        local l = Instance.new("UIListLayout")
        l.Padding = UDim.new(0, 8)
        l.SortOrder = Enum.SortOrder.LayoutOrder
        l.Parent = f
        return f
    end
    local colL = makeCol(UDim2.new(0, 0, 0, 0))
    local colR = makeCol(UDim2.new(0.5, 6, 0, 0))

    local hL, hR = 0, 0
    for _, g in ipairs(groups) do
        local target
        if hL <= hR then
            target = colL
            hL = hL + g.h
        else
            target = colR
            hR = hR + g.h
        end
        for _, it in ipairs(g.items) do it.Parent = target end
    end
end

local function createGUI(openTab)
    local guiParent = getGuiParent()
    local old = guiParent:FindFirstChild("NurHubGui")
    if old then old:Destroy() end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "NurHubGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.DisplayOrder = 10
    screenGui.Parent = guiParent

    local root = Instance.new("Frame")
    root.Name = "Root"
    root.Size = UDim2.new(0, WIN_W, 0, WIN_H)
    root.AnchorPoint = Vector2.new(0.5, 0.5)
    root.Position = Store.rootPos or UDim2.new(0.5, 0, 0.5, 0)
    root.BackgroundTransparency = 1
    root.Visible = false
    root.Parent = screenGui

    local rootScale = Instance.new("UIScale")
    rootScale.Parent = root

    local window = Instance.new("CanvasGroup")
    window.Name = "Window"
    window.Size = UDim2.new(1, 0, 1, 0)
    window.BackgroundTransparency = 1
    window.BorderSizePixel = 0
    window.Parent = root

    local function panel(pos, size, radius)
        local f = Instance.new("Frame")
        f.Position = pos
        f.Size = size
        f.BackgroundColor3 = THEME.Bg
        f.BorderSizePixel = 0
        f.Parent = window
        corner(f, radius or 16)
        addStroke(f, THEME.Stroke, 1)
        return f
    end

    -- ===== ЛЕВАЯ КОЛОНКА: логотип + рейка разделов =====
    local logo = panel(UDim2.fromOffset(8, 8), UDim2.fromOffset(46, 46), 14)
    logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    accentGradient(logo, 45)
    local logoTxt = makeLabel(logo, "N", 22, Color3.fromRGB(20, 20, 20), Enum.Font.GothamBlack)
    logoTxt.Size = UDim2.new(1, 0, 1, 0)

    local rail = panel(UDim2.fromOffset(8, 62), UDim2.fromOffset(46, 330), 16)
    local railList = Instance.new("Frame")
    railList.Size = UDim2.new(1, 0, 1, -12)
    railList.Position = UDim2.new(0, 0, 0, 6)
    railList.BackgroundTransparency = 1
    railList.Parent = rail
    local railLayout = Instance.new("UIListLayout")
    railLayout.Padding = UDim.new(0, 6)
    railLayout.SortOrder = Enum.SortOrder.LayoutOrder
    railLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    railLayout.Parent = railList

    -- ===== ВЕРХНЯЯ ПАНЕЛЬ ВКЛАДОК =====
    local bar = panel(UDim2.fromOffset(64, 8), UDim2.fromOffset(590, 46), 16)
    local barList = Instance.new("Frame")
    barList.Size = UDim2.new(1, -16, 1, 0)
    barList.Position = UDim2.new(0, 8, 0, 0)
    barList.BackgroundTransparency = 1
    barList.Parent = bar
    local barLayout = Instance.new("UIListLayout")
    barLayout.FillDirection = Enum.FillDirection.Horizontal
    barLayout.Padding = UDim.new(0, 4)
    barLayout.SortOrder = Enum.SortOrder.LayoutOrder
    barLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    barLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    barLayout.Parent = barList

    -- ===== ОСНОВНАЯ ПАНЕЛЬ =====
    local main = panel(UDim2.fromOffset(64, 62), UDim2.fromOffset(590, 330), 16)

    local titleLbl = makeLabel(main, "", 15, THEME.Text, Enum.Font.GothamBold)
    titleLbl.RichText = true
    titleLbl.Size = UDim2.new(1, -32, 0, 28)
    titleLbl.Position = UDim2.new(0, 16, 0, 8)
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -46)
    content.Position = UDim2.new(0, 8, 0, 40)
    content.BackgroundTransparency = 1
    content.ClipsDescendants = true
    content.Parent = main

    -- ===== ПРАВАЯ ПАНЕЛЬ: ПРЕВЬЮ =====
    local pv = panel(UDim2.fromOffset(WIN_W - 198, 8), UDim2.fromOffset(190, 384), 16)

    local pvTitle = makeLabel(pv, "Превью", 15, THEME.Text, Enum.Font.GothamBold)
    pvTitle.Size = UDim2.new(1, -60, 0, 28)
    pvTitle.Position = UDim2.new(0, 14, 0, 8)
    pvTitle.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -38, 0, 8)
    closeBtn.BackgroundColor3 = THEME.Card
    closeBtn.Text = "×"
    closeBtn.TextSize = 20
    closeBtn.TextColor3 = THEME.Dim
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.AutoButtonColor = false
    closeBtn.Parent = pv
    corner(closeBtn, 8)
    closeBtn.MouseEnter:Connect(function()
        tween(closeBtn, {BackgroundColor3 = Color3.fromRGB(255, 69, 58), TextColor3 = Color3.fromRGB(255, 255, 255)}, 0.15)
    end)
    closeBtn.MouseLeave:Connect(function()
        tween(closeBtn, {BackgroundColor3 = THEME.Card, TextColor3 = THEME.Dim}, 0.15)
    end)

    local stage = Instance.new("Frame")
    stage.Size = UDim2.fromOffset(170, 290)
    stage.Position = UDim2.fromOffset(10, 42)
    stage.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
    stage.BorderSizePixel = 0
    stage.ClipsDescendants = true
    stage.Parent = pv
    corner(stage, 10)
    addStroke(stage, THEME.Stroke, 1)

    local fig = Instance.new("Frame")
    fig.Size = UDim2.fromOffset(140, 200)
    fig.Position = UDim2.fromOffset(15, 52)
    fig.BackgroundTransparency = 1
    fig.Parent = stage

    -- крылья (Angel mode)
    local wings = {}
    for i, d in ipairs({{-14, -22}, {120, 22}}) do
        local w = Instance.new("Frame")
        w.Size = UDim2.fromOffset(34, 86)
        w.Position = UDim2.fromOffset(d[1], 26)
        w.Rotation = d[2]
        w.BackgroundColor3 = Color3.fromRGB(255, 140, 190)
        w.BackgroundTransparency = 0.1
        w.BorderSizePixel = 0
        w.Visible = false
        w.Parent = fig
        corner(w, 17)
        wings[i] = w
    end

    -- части тела
    local pvParts = {}
    for _, p in ipairs(BODY_PARTS) do
        local f = Instance.new("Frame")
        f.Size = UDim2.fromOffset(p.size.X, p.size.Y)
        f.Position = UDim2.fromOffset(p.pos.X, p.pos.Y)
        f.BackgroundColor3 = Color3.fromRGB(104, 84, 72)
        f.BorderSizePixel = 0
        f.Parent = fig
        corner(f, p.radius)
        local s = Instance.new("UIStroke")
        s.Thickness = 1.5
        s.Transparency = 1
        s.Parent = f
        table.insert(pvParts, {f = f, s = s})
    end

    local function rectStroke(pos, size)
        local f = Instance.new("Frame")
        f.BackgroundTransparency = 1
        f.BorderSizePixel = 0
        f.Position = UDim2.fromOffset(pos.X, pos.Y)
        f.Size = UDim2.fromOffset(size.X, size.Y)
        f.Visible = false
        f.Parent = fig
        local s = Instance.new("UIStroke")
        s.Thickness = 1.5
        s.Parent = f
        return f, s
    end
    local function lineFrame()
        local f = Instance.new("Frame")
        f.AnchorPoint = Vector2.new(0.5, 0.5)
        f.BorderSizePixel = 0
        f.Visible = false
        f.Parent = fig
        return f
    end

    local box, boxS = rectStroke(Vector2.new(8, -4), Vector2.new(124, 208))
    local b3f, b3fS = rectStroke(Vector2.new(14, 4), Vector2.new(112, 194))
    local b3b, b3bS = rectStroke(Vector2.new(24, -6), Vector2.new(112, 194))
    local c3 = {Vector2.new(14, 4), Vector2.new(126, 4), Vector2.new(14, 198), Vector2.new(126, 198)}
    local b3Lines = {}
    for i = 1, 4 do b3Lines[i] = lineFrame() end

    local SK = {
        {Vector2.new(70, 22), Vector2.new(70, 46)}, {Vector2.new(70, 46), Vector2.new(70, 110)},
        {Vector2.new(70, 52), Vector2.new(34, 52)}, {Vector2.new(34, 52), Vector2.new(34, 106)},
        {Vector2.new(70, 52), Vector2.new(106, 52)}, {Vector2.new(106, 52), Vector2.new(106, 106)},
        {Vector2.new(70, 110), Vector2.new(57, 118)}, {Vector2.new(57, 118), Vector2.new(57, 190)},
        {Vector2.new(70, 110), Vector2.new(83, 118)}, {Vector2.new(83, 118), Vector2.new(83, 190)},
    }
    local skLines = {}
    for i = 1, #SK do skLines[i] = lineFrame() end
    local tgLine = lineFrame()

    local barG = Instance.new("Frame")
    barG.Size = UDim2.fromOffset(3, 208)
    barG.Position = UDim2.fromOffset(2, -4)
    barG.BackgroundColor3 = GREEN
    barG.BorderSizePixel = 0
    barG.Visible = false
    barG.Parent = fig
    local barB = Instance.new("Frame")
    barB.Size = UDim2.fromOffset(3, 208)
    barB.Position = UDim2.fromOffset(135, -4)
    barB.BackgroundColor3 = Color3.fromRGB(10, 132, 255)
    barB.BorderSizePixel = 0
    barB.Visible = false
    barB.Parent = fig

    local nameL = makeLabel(fig, "player", 12, WHITE, Enum.Font.GothamBold)
    nameL.Size = UDim2.new(1, 0, 0, 14)
    nameL.Position = UDim2.fromOffset(0, -22)
    nameL.TextStrokeTransparency = 0.5
    nameL.Visible = false
    local distL = makeLabel(fig, "42 studs", 11, WHITE, Enum.Font.Gotham)
    distL.Size = UDim2.new(1, 0, 0, 14)
    distL.Position = UDim2.fromOffset(0, 206)
    distL.TextStrokeTransparency = 0.5
    distL.Visible = false

    local fpsB = makeLabel(stage, "60 FPS", 11, WHITE, Enum.Font.GothamBold)
    fpsB.AutomaticSize = Enum.AutomaticSize.XY
    fpsB.Size = UDim2.fromOffset(0, 0)
    fpsB.TextStrokeTransparency = 0.5
    fpsB.Visible = false

    -- T / CT
    local PV_BASE = {T = Color3.fromRGB(104, 84, 72), CT = Color3.fromRGB(70, 82, 110)}
    local pvTeam = "T"
    local teamBtns = {}
    local function paintTeam()
        for k, b in pairs(teamBtns) do
            local sel = (k == pvTeam)
            tween(b, {BackgroundColor3 = sel and THEME.Card or THEME.Side, TextColor3 = sel and THEME.Accent or THEME.Dim}, 0.15)
        end
    end
    for i, k in ipairs({"T", "CT"}) do
        local b = Instance.new("TextButton")
        b.Size = UDim2.fromOffset(80, 32)
        b.Position = UDim2.fromOffset(10 + (i - 1) * 90, 342)
        b.BackgroundColor3 = THEME.Side
        b.BorderSizePixel = 0
        b.Text = k
        b.TextSize = 14
        b.TextColor3 = THEME.Dim
        b.Font = Enum.Font.GothamBold
        b.AutoButtonColor = false
        b.Parent = pv
        corner(b, 10)
        addStroke(b, THEME.Stroke, 1)
        teamBtns[k] = b
        b.MouseButton1Click:Connect(function()
            pvTeam = k
            paintTeam()
        end)
    end
    paintTeam()

    -- живое превью: отражает настройки Visual
    utrack(RunService.Heartbeat:Connect(function()
        if not isMenuOpen then return end
        local V = Config.Visual
        local C = V.Colors
        local base = PV_BASE[pvTeam]
        for _, pp in ipairs(pvParts) do
            pp.f.BackgroundColor3 = base
            pp.s.Color = C.Outline
            pp.s.Transparency = V.Outline and 0 or 1
        end
        for _, w in ipairs(wings) do w.Visible = V.Angel end

        box.Visible = V.Box
        boxS.Color = C.Box
        barG.Visible = V.Box
        barB.Visible = V.Box

        b3f.Visible = V.Box3D
        b3b.Visible = V.Box3D
        b3fS.Color = C.Box3D
        b3bS.Color = C.Box3D
        for i, c in ipairs(c3) do
            setLine(b3Lines[i], c, c + Vector2.new(10, -10), C.Box3D, 1.5)
            b3Lines[i].Visible = V.Box3D
        end

        for i, sk in ipairs(SK) do
            setLine(skLines[i], sk[1], sk[2], C.Skeleton, 2)
            skLines[i].Visible = V.Skeleton
        end

        setLine(tgLine, Vector2.new(70, 238), Vector2.new(70, 224), C.Line, 2)
        tgLine.Visible = V.Line

        nameL.Visible = V.ShowNickname
        nameL.TextColor3 = C.Nickname
        distL.Visible = V.ShowDistance
        distL.TextColor3 = C.Distance

        fpsB.Visible = V.ShowFPS
        if V.ShowFPS then
            fpsB.Text = (V.FPSCustom and V.FPSValue or 60) .. " FPS"
            fpsB.TextColor3 = C.FPS
            fpsB.AnchorPoint = Vector2.new(V.FPSX, V.FPSY)
            fpsB.Position = UDim2.new(V.FPSX, 4 - 8 * V.FPSX, V.FPSY, 4 - 8 * V.FPSY)
        end
    end))

    -- ===== СТРАНИЦЫ =====
    local pages, scrolls, splitFlags, tabButtons = {}, {}, {}, {}

    local function createPage(name, noSplit)
        local page = Instance.new("CanvasGroup")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.Visible = false
        page.Parent = content

        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, 0, 1, 0)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ScrollBarThickness = 3
        scroll.ScrollBarImageColor3 = THEME.Accent
        scroll.ScrollingDirection = Enum.ScrollingDirection.Y
        scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
        scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
        scroll.Parent = page

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 8)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = scroll

        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 4)
        pad.PaddingBottom = UDim.new(0, 12)
        pad.PaddingLeft = UDim.new(0, 4)
        pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = scroll

        pages[name] = page
        scrolls[name] = scroll
        splitFlags[name] = not noSplit
        return scroll
    end

    local tabNames = {"Visual", "Combat", "Player", "World", "Config", "Settings", "Profile"}
    local currentTab
    local refreshProfile = function() end

    local function setTitle(name, sub)
        titleLbl.Text = L(TabRU[name]) .. ' <font color="rgb(142,142,160)">· ' .. (sub or "") .. '</font>'
    end

    -- рейка слева: быстрые переходы по разделам страницы
    local function buildRail(name)
        for _, c in ipairs(railList:GetChildren()) do
            if c:IsA("GuiObject") then c:Destroy() end
        end
        local scroll = scrolls[name]
        local secs = {}
        for _, c in ipairs(scroll:GetDescendants()) do
            if c.Name == "NHSection" then table.insert(secs, c) end
        end
        table.sort(secs, function(a, b) return a.LayoutOrder < b.LayoutOrder end)

        local btns = {}
        for i, sec in ipairs(secs) do
            local txt = sec.Text
            local ch = "•"
            if txt ~= "" then ch = txt:sub(1, (utf8.offset(txt, 2) or (#txt + 1)) - 1) end

            local b = Instance.new("TextButton")
            b.Size = UDim2.fromOffset(34, 34)
            b.BackgroundColor3 = THEME.Card
            b.BackgroundTransparency = 1
            b.BorderSizePixel = 0
            b.Text = ch
            b.TextSize = 14
            b.TextColor3 = THEME.Dim
            b.Font = Enum.Font.GothamBold
            b.AutoButtonColor = false
            b.LayoutOrder = i
            b.Parent = railList
            corner(b, 10)
            btns[i] = b

            b.MouseButton1Click:Connect(function()
                for j, bb in ipairs(btns) do
                    tween(bb, {BackgroundTransparency = (j == i) and 0 or 1,
                        TextColor3 = (j == i) and THEME.Accent or THEME.Dim}, 0.15)
                end
                setTitle(name, sec.Text)
                local y = (sec.AbsolutePosition.Y - scroll.AbsolutePosition.Y) / rootScale.Scale
                    + scroll.CanvasPosition.Y - 4
                scroll.CanvasPosition = Vector2.new(0, math.max(0, y))
            end)
        end
        if btns[1] then
            btns[1].BackgroundTransparency = 0
            btns[1].TextColor3 = THEME.Accent
        end
        setTitle(name, secs[1] and secs[1].Text or "")
    end

    local function selectTab(name, animate)
        if currentTab == name then return end
        currentTab = name
        Store.tab = name
        local t = animate and 0.25 or 0

        for n, b in pairs(tabButtons) do
            local sel = (n == name)
            tween(b, {BackgroundTransparency = sel and 0 or 1, TextColor3 = sel and THEME.Accent or THEME.Dim}, t)
        end

        for n, p in pairs(pages) do
            if n == name then
                p.Visible = true
                if animate then
                    p.GroupTransparency = 1
                    p.Position = UDim2.new(0, 0, 0, 14)
                    tween(p, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}, 0.3)
                else
                    p.GroupTransparency = 0
                    p.Position = UDim2.new(0, 0, 0, 0)
                end
            else
                p.Visible = false
            end
        end

        buildRail(name)
        if name == "Profile" then refreshProfile() end
    end

    for i, name in ipairs(tabNames) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 76, 0, 32)
        btn.BackgroundColor3 = THEME.Card
        btn.BackgroundTransparency = 1
        btn.BorderSizePixel = 0
        btn.Text = L(TabRU[name])
        btn.TextSize = 12
        btn.TextColor3 = THEME.Dim
        btn.Font = Enum.Font.GothamMedium
        btn.AutoButtonColor = false
        btn.LayoutOrder = i
        btn.Parent = barList
        corner(btn, 10)
        tabButtons[name] = btn
        btn.MouseButton1Click:Connect(function() selectTab(name, true) end)
    end

    -- ===== Страница Visual =====
    local V = Config.Visual
    local vis = createPage("Visual")
    createSection(vis, "ESP")
    createToggleCard(vis, "ESP (включить всё)", V, "ESP", {
        sliders = {
            {label = "Дистанция ESP", tbl = V, key = "DistanceLimit", min = 50, max = 2000}
        }
    })
    createSection(vis, "Элементы ESP")
    createToggleCard(vis, "Контур (Outline)", V, "Outline",
        {pickers = {{tbl = V.Colors, key = "Outline"}}})
    createToggleCard(vis, "Show Nickname", V, "ShowNickname",
        {pickers = {{tbl = V.Colors, key = "Nickname"}}})
    createToggleCard(vis, "Show Distance", V, "ShowDistance",
        {pickers = {{tbl = V.Colors, key = "Distance"}}})
    createToggleCard(vis, "Line", V, "Line",
        {pickers = {{tbl = V.Colors, key = "Line"}}})
    createToggleCard(vis, "Box", V, "Box",
        {pickers = {{tbl = V.Colors, key = "Box"}}})
    createToggleCard(vis, "3D Box", V, "Box3D",
        {pickers = {{tbl = V.Colors, key = "Box3D"}}})
    createToggleCard(vis, "Skeleton", V, "Skeleton",
        {pickers = {{tbl = V.Colors, key = "Skeleton"}}})
    createSection(vis, "Экран")
    createToggleCard(vis, "Show FPS", V, "ShowFPS", {
        customH = 190,
        custom = buildFpsCustom,
        pickers = {{tbl = V.Colors, key = "FPS"}},
    })
    createSection(vis, "Персонаж")
    createToggleCard(vis, "Angel mode", V, "Angel")

    -- ===== Страница Combat =====
    local com = createPage("Combat")
    local CB = Config.Combat

    createSection(com, "Aimbot"):SetAttribute("NHFull", true)
    createAimbotDrawer(com):SetAttribute("NHFull", true)

    createSection(com, "Настройки Aimbot")
    createToggleCard(com, "Зажим ПКМ (только ПК)", CB, "HoldToAim")
    createToggleCard(com, "Sticky lock", CB, "Sticky")

    createSection(com, "Silent Aim")
    createToggleCard(com, "Silent Aim", CB, "SilentAim", {
        sliders = {
            {label = "FOV", tbl = CB, key = "SilentFOV", min = 30, max = 500},
            {label = "Hit chance %", tbl = CB, key = "HitChance", min = 1, max = 100},
        }
    })
    createToggleCard(com, "FOV circle (Silent)", CB, "ShowSilentFOV",
        {pickers = {{tbl = CB.Colors, key = "SilentFOV"}}})

    createSection(com, "Общие")
    createToggleCard(com, "Team check", CB, "TeamCheck")
    createToggleCard(com, "Проверка видимости", CB, "VisibleCheck")

    -- ===== Страница Player =====
    local plr = createPage("Player")
    createSection(plr, "Движение")
    createSliderCard(plr, "WalkSpeed", Config.Player, "WalkSpeed", 16, 200)
    createSliderCard(plr, "JumpPower", Config.Player, "JumpPower", 50, 300)
    createToggleCard(plr, "Noclip", Config.Player, "Noclip")
    createToggleCard(plr, "Fly", Config.Player, "Fly", {
        sliders = {
            {label = "Скорость полёта", tbl = Config.Player, key = "FlySpeed", min = 10, max = 200}
        }
    })
    createToggleCard(plr, "Spin", Config.Player, "Spin", {
        sliders = {
            {label = "Скорость вращения (°/сек)", tbl = Config.Player, key = "SpinSpeed", min = 30, max = 1080}
        }
    })
    createSection(plr, "Камера")
    createToggleCard(plr, "Third Person", Config.Player, "ThirdPerson", {
        onChange = function(on)
            Store.tp = on
            applyThirdPerson(on)
        end
    })

    -- ===== World / Config / Settings =====
    buildWorldPage(createPage("World"))
    buildConfigPage(createPage("Config", true))
    buildSettingsPage(createPage("Settings"))

    -- ===== Страница Profile =====
    local prof = createPage("Profile")
    createSection(prof, "Игрок")

    local ORANGE = Color3.fromRGB(255, 159, 10)
    local statusPills = {}

    -- карточка игрока (баннер + аватар + ник + статистика)
    local hero = Instance.new("CanvasGroup")
    hero.Size = UDim2.new(1, 0, 0, 188)
    hero.BackgroundColor3 = THEME.Card
    hero.BorderSizePixel = 0
    hero.LayoutOrder = nextOrder()
    hero.Parent = prof
    corner(hero, 12)
    addStroke(hero, THEME.Stroke, 1)

    local banner = Instance.new("Frame")
    banner.Size = UDim2.new(1, 0, 0, 62)
    banner.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    banner.BackgroundTransparency = 0.3
    banner.BorderSizePixel = 0
    banner.Parent = hero
    accentGradient(banner, 20)

    local fade = Instance.new("Frame")
    fade.Size = UDim2.new(1, 0, 0, 34)
    fade.Position = UDim2.new(0, 0, 0, 28)
    fade.BackgroundColor3 = THEME.Card
    fade.BorderSizePixel = 0
    fade.Parent = hero
    local fadeGrad = Instance.new("UIGradient")
    fadeGrad.Transparency = NumberSequence.new(1, 0)
    fadeGrad.Rotation = 90
    fadeGrad.Parent = fade

    local ring = Instance.new("Frame")
    ring.Size = UDim2.new(0, 80, 0, 80)
    ring.Position = UDim2.new(0, 14, 0, 22)
    ring.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    ring.BorderSizePixel = 0
    ring.Parent = hero
    corner(ring, 40)
    addStroke(ring, THEME.Card, 3)
    local ringGrad = accentGradient(ring, 0)

    local avatar = Instance.new("ImageLabel")
    avatar.Size = UDim2.new(0, 72, 0, 72)
    avatar.Position = UDim2.new(0, 4, 0, 4)
    avatar.BackgroundColor3 = THEME.Bg
    avatar.BorderSizePixel = 0
    avatar.ImageTransparency = 1
    avatar.Parent = ring
    corner(avatar, 36)

    task.spawn(function()
        local ok, img = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
        end)
        if not (ok and img) then
            img = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=150&h=150"
        end
        if avatar.Parent then
            avatar.Image = img
            tween(avatar, {ImageTransparency = 0}, 0.5)
        end
    end)

    local statusDot = Instance.new("Frame")
    statusDot.Size = UDim2.new(0, 16, 0, 16)
    statusDot.Position = UDim2.new(0, 78, 0, 84)
    statusDot.BackgroundColor3 = GREEN
    statusDot.BorderSizePixel = 0
    statusDot.Parent = hero
    corner(statusDot, 8)
    addStroke(statusDot, THEME.Card, 3)
    local dotScale = Instance.new("UIScale")
    dotScale.Parent = statusDot

    local nameLbl = makeLabel(hero, LocalPlayer.DisplayName, 20, THEME.Text, Enum.Font.GothamBold)
    nameLbl.Size = UDim2.new(1, -116, 0, 26)
    nameLbl.Position = UDim2.new(0, 106, 0, 66)
    nameLbl.TextXAlignment = Enum.TextXAlignment.Left
    nameLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local userLbl = makeLabel(hero, "@" .. LocalPlayer.Name, 13, THEME.Dim, Enum.Font.Gotham)
    userLbl.Size = UDim2.new(1, -116, 0, 18)
    userLbl.Position = UDim2.new(0, 106, 0, 92)
    userLbl.TextXAlignment = Enum.TextXAlignment.Left
    userLbl.TextTruncate = Enum.TextTruncate.AtEnd

    local function mkPill(parent, text, color, x, y, w)
        local p = Instance.new("Frame")
        p.Size = UDim2.new(0, w, 0, 20)
        p.Position = UDim2.new(0, x, 0, y)
        p.BackgroundColor3 = color
        p.BackgroundTransparency = 0.82
        p.BorderSizePixel = 0
        p.Parent = parent
        corner(p, 10)
        local l = makeLabel(p, text, 10, color, Enum.Font.GothamBold)
        l.Size = UDim2.new(1, 0, 1, 0)
        return p, l
    end

    local heroPill, heroPillLbl = mkPill(hero, "АКТИВЕН", GREEN, 106, 114, 78)
    table.insert(statusPills, {f = heroPill, l = heroPillLbl})

    local isPremium = false
    pcall(function() isPremium = (LocalPlayer.MembershipType == Enum.MembershipType.Premium) end)
    if isPremium then
        mkPill(hero, "ПРЕМИУМ", Color3.fromRGB(255, 214, 10), 190, 114, 70)
    end

    -- мини-статистика
    local statRow = Instance.new("Frame")
    statRow.Size = UDim2.new(1, -28, 0, 38)
    statRow.Position = UDim2.new(0, 14, 0, 142)
    statRow.BackgroundTransparency = 1
    statRow.Parent = hero
    local statLayout = Instance.new("UIListLayout")
    statLayout.FillDirection = Enum.FillDirection.Horizontal
    statLayout.Padding = UDim.new(0, 6)
    statLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statLayout.Parent = statRow

    local function mkStat(i, caption)
        local t = Instance.new("Frame")
        t.Size = UDim2.new(1 / 3, -4, 1, 0)
        t.BackgroundColor3 = THEME.Bg
        t.BorderSizePixel = 0
        t.LayoutOrder = i
        t.Parent = statRow
        corner(t, 8)
        addStroke(t, THEME.Stroke, 1)
        local c = makeLabel(t, caption, 10, THEME.Dim, Enum.Font.GothamBold)
        c.Size = UDim2.new(1, 0, 0, 14)
        c.Position = UDim2.new(0, 0, 0, 4)
        local v = makeLabel(t, "—", 12, THEME.Accent, Enum.Font.GothamBold)
        v.Size = UDim2.new(1, -8, 0, 16)
        v.Position = UDim2.new(0, 4, 0, 18)
        v.TextTruncate = Enum.TextTruncate.AtEnd
        return v
    end
    local idV = mkStat(1, "ID")
    local ageV = mkStat(2, "Аккаунт")
    local plV = mkStat(3, "Игроков")

    -- лицензия
    createSection(prof, "Лицензия")

    local lic = Instance.new("Frame")
    lic.Size = UDim2.new(1, 0, 0, 238)
    lic.BackgroundColor3 = THEME.Card
    lic.BorderSizePixel = 0
    lic.LayoutOrder = nextOrder()
    lic.Parent = prof
    corner(lic, 12)
    addStroke(lic, THEME.Stroke, 1)

    local keyCap = makeLabel(lic, "Ключ", 11, THEME.Dim, Enum.Font.GothamBold)
    keyCap.Size = UDim2.new(0.5, 0, 0, 20)
    keyCap.Position = UDim2.new(0, 14, 0, 10)
    keyCap.TextXAlignment = Enum.TextXAlignment.Left

    local licPill, licPillLbl = mkPill(lic, "АКТИВЕН", GREEN, 0, 10, 82)
    licPill.AnchorPoint = Vector2.new(1, 0)
    licPill.Position = UDim2.new(1, -14, 0, 10)
    table.insert(statusPills, {f = licPill, l = licPillLbl})

    local keyChip = Instance.new("Frame")
    keyChip.Size = UDim2.new(1, -28, 0, 36)
    keyChip.Position = UDim2.new(0, 14, 0, 34)
    keyChip.BackgroundColor3 = THEME.Bg
    keyChip.BorderSizePixel = 0
    keyChip.Parent = lic
    corner(keyChip, 8)
    addStroke(keyChip, THEME.Accent, 1.5)

    local keyTxt = makeLabel(keyChip, "—", 15, THEME.Accent, Enum.Font.GothamBold)
    keyTxt.Size = UDim2.new(1, -88, 1, 0)
    keyTxt.Position = UDim2.new(0, 12, 0, 0)
    keyTxt.TextXAlignment = Enum.TextXAlignment.Left

    local eyeBtn = Instance.new("TextButton")
    eyeBtn.Size = UDim2.new(0, 66, 0, 26)
    eyeBtn.Position = UDim2.new(1, -72, 0.5, -13)
    eyeBtn.BackgroundColor3 = THEME.Card
    eyeBtn.BorderSizePixel = 0
    eyeBtn.Text = L("Показать")
    eyeBtn.TextSize = 11
    eyeBtn.TextColor3 = THEME.Dim
    eyeBtn.Font = Enum.Font.GothamBold
    eyeBtn.AutoButtonColor = false
    eyeBtn.Parent = keyChip
    corner(eyeBtn, 6)

    -- обратный отсчёт: дни / часы / минуты / секунды
    local tileRow = Instance.new("Frame")
    tileRow.Size = UDim2.new(1, -28, 0, 56)
    tileRow.Position = UDim2.new(0, 14, 0, 82)
    tileRow.BackgroundTransparency = 1
    tileRow.Parent = lic
    local tileLayout = Instance.new("UIListLayout")
    tileLayout.FillDirection = Enum.FillDirection.Horizontal
    tileLayout.Padding = UDim.new(0, 6)
    tileLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tileLayout.Parent = tileRow

    local tileNums = {}
    for i, cap in ipairs({"ДНИ", "ЧАСЫ", "МИН", "СЕК"}) do
        local t = Instance.new("Frame")
        t.Size = UDim2.new(0.25, -5, 1, 0)
        t.BackgroundColor3 = THEME.Bg
        t.BorderSizePixel = 0
        t.LayoutOrder = i
        t.Parent = tileRow
        corner(t, 8)
        addStroke(t, THEME.Stroke, 1)
        local n = makeLabel(t, "0", 20, THEME.Text, Enum.Font.GothamBlack)
        n.Size = UDim2.new(1, 0, 0, 30)
        n.Position = UDim2.new(0, 0, 0, 5)
        local c = makeLabel(t, cap, 9, THEME.Dim, Enum.Font.GothamBold)
        c.Size = UDim2.new(1, 0, 0, 14)
        c.Position = UDim2.new(0, 0, 0, 35)
        tileNums[i] = n
    end

    -- прогресс оставшегося времени
    local leftCap = makeLabel(lic, "Осталось", 12, THEME.Dim, Enum.Font.Gotham)
    leftCap.Size = UDim2.new(0.5, 0, 0, 16)
    leftCap.Position = UDim2.new(0, 14, 0, 148)
    leftCap.TextXAlignment = Enum.TextXAlignment.Left

    local pctLbl = makeLabel(lic, "100%", 12, THEME.Accent, Enum.Font.GothamBold)
    pctLbl.Size = UDim2.new(0.5, -14, 0, 16)
    pctLbl.Position = UDim2.new(0.5, 0, 0, 148)
    pctLbl.TextXAlignment = Enum.TextXAlignment.Right

    local barBg = Instance.new("Frame")
    barBg.Size = UDim2.new(1, -28, 0, 8)
    barBg.Position = UDim2.new(0, 14, 0, 168)
    barBg.BackgroundColor3 = THEME.Off
    barBg.BorderSizePixel = 0
    barBg.Parent = lic
    corner(barBg, 4)

    local barFill = Instance.new("Frame")
    barFill.Size = UDim2.new(1, 0, 1, 0)
    barFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    barFill.BorderSizePixel = 0
    barFill.Parent = barBg
    corner(barFill, 4)
    local barFillGrad = accentGradient(barFill, 0)

    local function infoRow(captionText, y)
        local c = makeLabel(lic, captionText, 12, THEME.Dim, Enum.Font.Gotham)
        c.Size = UDim2.new(0.4, 0, 0, 18)
        c.Position = UDim2.new(0, 14, 0, y)
        c.TextXAlignment = Enum.TextXAlignment.Left
        local v = makeLabel(lic, "—", 12, THEME.Text, Enum.Font.GothamMedium)
        v.Size = UDim2.new(0.6, -14, 0, 18)
        v.Position = UDim2.new(0.4, 0, 0, y)
        v.TextXAlignment = Enum.TextXAlignment.Right
        return v
    end
    local actVal = infoRow("Активирован", 190)
    local untilVal = infoRow("Действует до", 210)

    -- кнопки
    local btnRow = Instance.new("Frame")
    btnRow.Size = UDim2.new(1, 0, 0, 38)
    btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder = nextOrder()
    btnRow.Parent = prof

    local swapBtn = Instance.new("TextButton")
    swapBtn.Size = UDim2.new(0.5, -4, 1, 0)
    swapBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    swapBtn.BorderSizePixel = 0
    swapBtn.Text = L("Сменить ключ")
    swapBtn.TextSize = 13
    swapBtn.TextColor3 = Color3.fromRGB(20, 20, 20)
    swapBtn.Font = Enum.Font.GothamBold
    swapBtn.AutoButtonColor = false
    swapBtn.Parent = btnRow
    corner(swapBtn, 10)
    accentGradient(swapBtn, 0)
    local swapScale = Instance.new("UIScale")
    swapScale.Parent = swapBtn
    swapBtn.MouseEnter:Connect(function() tween(swapScale, {Scale = 1.03}, 0.15) end)
    swapBtn.MouseLeave:Connect(function() tween(swapScale, {Scale = 1}, 0.15) end)
    swapBtn.MouseButton1Down:Connect(function() tween(swapScale, {Scale = 0.96}, 0.1) end)
    swapBtn.MouseButton1Up:Connect(function() tween(swapScale, {Scale = 1}, 0.2, Enum.EasingStyle.Back) end)
    swapBtn.MouseButton1Click:Connect(function() Lic.Logout() end)

    local copyBtn = Instance.new("TextButton")
    copyBtn.Size = UDim2.new(0.5, -4, 1, 0)
    copyBtn.Position = UDim2.new(0.5, 4, 0, 0)
    copyBtn.BackgroundColor3 = THEME.Card
    copyBtn.BorderSizePixel = 0
    copyBtn.Text = L("Скопировать")
    copyBtn.TextSize = 13
    copyBtn.TextColor3 = THEME.Dim
    copyBtn.Font = Enum.Font.GothamMedium
    copyBtn.AutoButtonColor = false
    copyBtn.Parent = btnRow
    corner(copyBtn, 10)
    addStroke(copyBtn, THEME.Stroke, 1)
    copyBtn.MouseEnter:Connect(function()
        tween(copyBtn, {BackgroundColor3 = THEME.CardHover, TextColor3 = THEME.Text}, 0.15)
    end)
    copyBtn.MouseLeave:Connect(function()
        tween(copyBtn, {BackgroundColor3 = THEME.Card, TextColor3 = THEME.Dim}, 0.15)
    end)
    copyBtn.MouseButton1Click:Connect(function()
        local msg = "Недоступно"
        if setclipboard and Lic.Key then
            if pcall(setclipboard, Lic.Key) then msg = "Скопировано" end
        end
        copyBtn.Text = L(msg)
        task.delay(1.5, function()
            if copyBtn.Parent then copyBtn.Text = L("Скопировать") end
        end)
    end)

    local keyShown = false
    local function maskKey(k)
        if not k or k == "" then return "—" end
        if #k <= 4 then return string.rep("*", #k) end
        return k:sub(1, 2) .. string.rep("*", #k - 3) .. k:sub(-1)
    end

    refreshProfile = function()
        local rem = math.max(0, Lic.Expires - os.time())
        local col, st = GREEN, "АКТИВЕН"
        if rem < 3600 then
            col, st = RED, "ИСТЕКАЕТ"
        elseif rem < 86400 then
            col, st = ORANGE, "ИСТЕКАЕТ"
        end

        for _, sp in ipairs(statusPills) do
            sp.f.BackgroundColor3 = col
            sp.l.TextColor3 = col
            sp.l.Text = L(st)
        end
        statusDot.BackgroundColor3 = col

        keyTxt.Text = keyShown and (Lic.Key or "—") or maskKey(Lic.Key)

        local d = math.floor(rem / 86400)
        local h = math.floor((rem % 86400) / 3600)
        local m = math.floor((rem % 3600) / 60)
        local s = math.floor(rem % 60)
        tileNums[1].Text = tostring(d)
        tileNums[2].Text = string.format("%02d", h)
        tileNums[3].Text = string.format("%02d", m)
        tileNums[4].Text = string.format("%02d", s)
        local numCol = (col == GREEN) and THEME.Text or col
        for _, n in ipairs(tileNums) do n.TextColor3 = numCol end

        local total = math.max(1, Lic.Days * 86400)
        local frac = math.clamp(rem / total, 0, 1)
        tween(barFill, {Size = UDim2.new(frac, 0, 1, 0)}, 0.4)
        pctLbl.Text = math.floor(frac * 100 + 0.5) .. "%"
        pctLbl.TextColor3 = (col == GREEN) and THEME.Accent or col
        barFillGrad.Color = (col == GREEN) and ColorSequence.new(THEME.Accent, THEME.Accent2)
            or ColorSequence.new(col, THEME.Accent2)

        actVal.Text = Lic.Activated > 0 and os.date("%d.%m.%Y %H:%M", Lic.Activated) or "—"
        untilVal.Text = Lic.Expires > 0 and os.date("%d.%m.%Y %H:%M", Lic.Expires) or "—"

        idV.Text = tostring(LocalPlayer.UserId)
        ageV.Text = LocalPlayer.AccountAge .. " " .. L("дн.")
        plV.Text = tostring(#Players:GetPlayers())
    end

    eyeBtn.MouseButton1Click:Connect(function()
        keyShown = not keyShown
        eyeBtn.Text = L(keyShown and "Скрыть" or "Показать")
        refreshProfile()
    end)

    do
        local acc = 0
        utrack(RunService.Heartbeat:Connect(function(dt)
            if not (isMenuOpen and pages.Profile.Visible) then return end
            local t = os.clock()
            ringGrad.Rotation = (t * 120) % 360
            dotScale.Scale = 1 + 0.18 * math.sin(t * 4)
            acc = acc + dt
            if acc >= 1 then
                acc = 0
                refreshProfile()
            end
        end))
    end

    -- делим страницы на две колонки
    for name, scroll in pairs(scrolls) do
        if splitFlags[name] then splitColumns(scroll) end
    end

    selectTab(openTab or "Visual", false)

    -- ===== Кнопка-лаунчер =====
    local launcher = Instance.new("TextButton")
    launcher.Name = "Launcher"
    launcher.Size = UDim2.new(0, 48, 0, 48)
    launcher.Position = Store.launcherPos or UDim2.new(0.06, 0, 0.5, 0)
    launcher.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    launcher.Text = "N"
    launcher.TextSize = 24
    launcher.TextColor3 = Color3.fromRGB(20, 20, 20)
    launcher.Font = Enum.Font.GothamBlack
    launcher.AutoButtonColor = false
    launcher.Parent = screenGui
    corner(launcher, 24)
    accentGradient(launcher, 45)
    addStroke(launcher, Color3.fromRGB(255, 255, 255), 2, 0.6)

    local launcherScale = Instance.new("UIScale")
    launcherScale.Parent = launcher

    launcher.MouseEnter:Connect(function() tween(launcherScale, {Scale = 1.1}, 0.15) end)
    launcher.MouseLeave:Connect(function() tween(launcherScale, {Scale = 1}, 0.15) end)
    launcher.MouseButton1Down:Connect(function() tween(launcherScale, {Scale = 0.92}, 0.1) end)
    launcher.MouseButton1Up:Connect(function() tween(launcherScale, {Scale = 1}, 0.15, Enum.EasingStyle.Back) end)

    local launcherDrag = makeDraggable(launcher, launcher)
    makeDraggable(bar, root)
    makeDraggable(logo, root)

    local function computeScale()
        local vp = Camera.ViewportSize
        local fit = math.min(1, (vp.X - 20) / WIN_W, (vp.Y - 20) / WIN_H)
        fit = math.max(fit, 0.3)
        return fit * (Settings.Scale / 100)
    end

    local function setMenu(open)
        if open and not Lic.Active then return end
        isMenuOpen = open
        if open then
            root.Visible = true
            rootScale.Scale = computeScale() * 0.85
            window.GroupTransparency = 1

            tween(rootScale, {Scale = computeScale()}, 0.4, Enum.EasingStyle.Back)
            tween(window, {GroupTransparency = Settings.Transparency / 100}, 0.25)
        else
            tween(rootScale, {Scale = rootScale.Scale * 0.92}, 0.2)
            tween(window, {GroupTransparency = 1}, 0.2)
            task.delay(0.22, function()
                if not isMenuOpen then root.Visible = false end
            end)
        end
    end

    local function applyLook()
        if isMenuOpen then
            tween(rootScale, {Scale = computeScale()}, 0.12)
            tween(window, {GroupTransparency = Settings.Transparency / 100}, 0.12)
        end
        launcher.Visible = not (Settings.PCMode and Settings.HideLauncher)
    end
    applyLook()

    launcher.MouseButton1Click:Connect(function()
        if launcherDrag.moved then launcherDrag.moved = false return end
        setMenu(not isMenuOpen)
    end)
    closeBtn.MouseButton1Click:Connect(function() setMenu(false) end)

    utrack(UserInputService.InputBegan:Connect(function(input, processed)
        if processed or Store.binding then return end
        if Settings.PCMode and input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode.Name == Settings.MenuKey then
            setMenu(not isMenuOpen)
        end
    end))

    return {
        gui = screenGui,
        root = root,
        launcher = launcher,
        setMenu = setMenu,
        applyLook = applyLook,
        refreshProfile = function() refreshProfile() end,
    }
end

-- Пересборка меню (смена языка, загрузка конфига, применение темы)
local function buildUI(tab, reopen)
    if UI then
        pcall(function()
            Store.launcherPos = UI.launcher.Position
            Store.rootPos = UI.root.Position
        end)
        for _, c in ipairs(UIConns) do pcall(function() c:Disconnect() end) end
        UIConns = {}
        pcall(function() UI.gui:Destroy() end)
    end
    layoutCounter = 0
    UI = createGUI(tab or "Visual")
    UI.gui.Enabled = Lic.Active
    if reopen and Lic.Active then UI.setMenu(true) end
end

Store.rebuild = function(tab)
    task.defer(buildUI, tab, true)
end

buildUI("Visual", false)
UI.gui.Enabled = false -- меню скрыто, пока не введён верный ключ

Lic.OnUnlock = function()
    UI.gui.Enabled = true
    UI.refreshProfile()
    UI.setMenu(true)
end

Lic.OnLock = function()
    UI.setMenu(false)
    UI.gui.Enabled = false
end

-- ==========================================================
-- 3. ВИЗУАЛЬНАЯ ЧАСТЬ (ESP без Drawing)
-- ==========================================================

local espGui = Instance.new("ScreenGui")
espGui.Name = "NurHubESPGui"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
espGui.DisplayOrder = 1
espGui.Parent = getGuiParent()

local R15_BONES = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local R6_BONES = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

local function clearESP(player)
    local obj = espObjects[player]
    if obj then
        for _, k in ipairs({"Highlight", "Billboard", "Selection", "BoxFrame", "LineFrame"}) do
            if obj[k] then pcall(function() obj[k]:Destroy() end) end
        end
        if obj.Skel then
            for _, f in ipairs(obj.Skel) do pcall(function() f:Destroy() end) end
        end
        espObjects[player] = nil
    end
end

local function createESP(player, char, head)
    local highlight = Instance.new("Highlight")
    highlight.Name = "NurHub_ESP"
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 0
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.Adornee = char
    highlight.Enabled = false
    highlight.Parent = char

    local selection = Instance.new("SelectionBox")
    selection.Name = "NurHub_Box3D"
    selection.LineThickness = 0.04
    selection.SurfaceTransparency = 1
    selection.Adornee = nil
    selection.Parent = char

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "NurHub_Billboard"
    billboard.Size = UDim2.new(0, 200, 0, 40)
    billboard.StudsOffset = Vector3.new(0, 3, 0)
    billboard.AlwaysOnTop = true
    billboard.Enabled = false
    billboard.Parent = head

    local list = Instance.new("UIListLayout")
    list.SortOrder = Enum.SortOrder.LayoutOrder
    list.Parent = billboard

    local nickname = Instance.new("TextLabel")
    nickname.Name = "Nickname"
    nickname.Size = UDim2.new(1, 0, 0, 20)
    nickname.LayoutOrder = 1
    nickname.BackgroundTransparency = 1
    nickname.Text = player.DisplayName
    nickname.TextStrokeTransparency = 0
    nickname.Font = Enum.Font.GothamBold
    nickname.TextSize = 14
    nickname.Parent = billboard

    local distance = Instance.new("TextLabel")
    distance.Name = "Distance"
    distance.Size = UDim2.new(1, 0, 0, 20)
    distance.LayoutOrder = 2
    distance.BackgroundTransparency = 1
    distance.TextStrokeTransparency = 0
    distance.Font = Enum.Font.Gotham
    distance.TextSize = 13
    distance.Parent = billboard

    local boxFrame = Instance.new("Frame")
    boxFrame.BackgroundTransparency = 1
    boxFrame.BorderSizePixel = 0
    boxFrame.Visible = false
    boxFrame.Parent = espGui
    local boxStroke = Instance.new("UIStroke")
    boxStroke.Thickness = 1.5
    boxStroke.Parent = boxFrame

    local lineFrame = Instance.new("Frame")
    lineFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    lineFrame.BorderSizePixel = 0
    lineFrame.Visible = false
    lineFrame.Parent = espGui

    local obj = {
        Char = char, Highlight = highlight, Selection = selection,
        Billboard = billboard, Nickname = nickname, Distance = distance,
        BoxFrame = boxFrame, BoxStroke = boxStroke, LineFrame = lineFrame,
        Skel = {},
    }
    espObjects[player] = obj
    return obj
end

local function hideSkeleton(obj)
    for _, f in ipairs(obj.Skel) do f.Visible = false end
end

local function hideAll(obj)
    obj.Highlight.Enabled = false
    obj.Billboard.Enabled = false
    obj.Selection.Adornee = nil
    obj.BoxFrame.Visible = false
    obj.LineFrame.Visible = false
    hideSkeleton(obj)
end

local function updateSkeleton(obj, char, hum, color)
    local bones = (hum.RigType == Enum.HumanoidRigType.R15) and R15_BONES or R6_BONES
    local n = 0
    for _, bone in ipairs(bones) do
        local p1 = char:FindFirstChild(bone[1])
        local p2 = char:FindFirstChild(bone[2])
        if p1 and p2 then
            n = n + 1
            local f = obj.Skel[n]
            if not f then
                f = Instance.new("Frame")
                f.AnchorPoint = Vector2.new(0.5, 0.5)
                f.BorderSizePixel = 0
                f.Visible = false
                f.Parent = espGui
                obj.Skel[n] = f
            end
            local a = Camera:WorldToViewportPoint(p1.Position)
            local b = Camera:WorldToViewportPoint(p2.Position)
            if a.Z > 0 and b.Z > 0 then
                setLine(f, Vector2.new(a.X, a.Y), Vector2.new(b.X, b.Y), color, 2)
            else
                f.Visible = false
            end
        end
    end
    for i = n + 1, #obj.Skel do obj.Skel[i].Visible = false end
end

local function updateESP()
    local V = Config.Visual
    local C = V.Colors
    local myChar = LocalPlayer.Character
    local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local vp = Camera.ViewportSize

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local char = player.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local obj = espObjects[player]

            if not (hrp and head and hum) or (not V.ESP and not obj) then
                if obj and not (hrp and head and hum) then clearESP(player) end
            else
                if obj and (obj.Char ~= char or not obj.Highlight.Parent or not obj.Billboard.Parent) then
                    clearESP(player)
                    obj = nil
                end
                if not obj then obj = createESP(player, char, head) end

                local origin = myHrp and myHrp.Position or Camera.CFrame.Position
                local dist = (hrp.Position - origin).Magnitude
                local show = V.ESP and hum.Health > 0 and dist <= V.DistanceLimit

                if not show then
                    hideAll(obj)
                else
                    obj.Highlight.Enabled = V.Outline
                    obj.Highlight.OutlineColor = C.Outline

                    obj.Billboard.Enabled = V.ShowNickname or V.ShowDistance
                    obj.Nickname.Visible = V.ShowNickname
                    obj.Nickname.TextColor3 = C.Nickname
                    obj.Distance.Visible = V.ShowDistance
                    obj.Distance.TextColor3 = C.Distance
                    if V.ShowDistance then
                        obj.Distance.Text = math.floor(dist) .. " studs"
                    end

                    if V.Box3D then
                        obj.Selection.Color3 = C.Box3D
                        obj.Selection.Adornee = char
                    else
                        obj.Selection.Adornee = nil
                    end

                    local boxOn, lineOn = false, false

                    if V.Box then
                        local cf, size = char:GetBoundingBox()
                        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                        local allFront = true
                        for i = 0, 7 do
                            local sx = (i % 2 == 0) and 1 or -1
                            local sy = (math.floor(i / 2) % 2 == 0) and 1 or -1
                            local sz = (math.floor(i / 4) % 2 == 0) and 1 or -1
                            local wp = (cf * CFrame.new(size.X / 2 * sx, size.Y / 2 * sy, size.Z / 2 * sz)).Position
                            local p = Camera:WorldToViewportPoint(wp)
                            if p.Z <= 0 then allFront = false break end
                            minX = math.min(minX, p.X); maxX = math.max(maxX, p.X)
                            minY = math.min(minY, p.Y); maxY = math.max(maxY, p.Y)
                        end
                        if allFront then
                            boxOn = true
                            obj.BoxFrame.Position = UDim2.fromOffset(minX, minY)
                            obj.BoxFrame.Size = UDim2.fromOffset(maxX - minX, maxY - minY)
                            obj.BoxStroke.Color = C.Box
                        end
                    end

                    if V.Line then
                        local sp = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3, 0))
                        if sp.Z > 0 then
                            lineOn = true
                            setLine(obj.LineFrame, Vector2.new(vp.X / 2, vp.Y), Vector2.new(sp.X, sp.Y), C.Line, 2)
                        end
                    end

                    obj.BoxFrame.Visible = boxOn
                    if not lineOn then obj.LineFrame.Visible = false end

                    if V.Skeleton then
                        updateSkeleton(obj, char, hum, C.Skeleton)
                    else
                        hideSkeleton(obj)
                    end
                end
            end
        end
    end
end

-- ===== Счётчик FPS =====
local fpsLabel = Instance.new("TextLabel")
fpsLabel.Name = "NurHubFPS"
fpsLabel.BackgroundTransparency = 1
fpsLabel.AutomaticSize = Enum.AutomaticSize.XY
fpsLabel.Size = UDim2.fromOffset(0, 0)
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 18
fpsLabel.TextStrokeTransparency = 0.4
fpsLabel.Text = "60 FPS"
fpsLabel.Visible = false
fpsLabel.Parent = espGui

local FPS = {acc = 0, frames = 0, value = 60}

local function updateFPS(dt)
    local V = Config.Visual
    fpsLabel.Visible = V.ShowFPS
    if not V.ShowFPS then return end

    FPS.acc = FPS.acc + dt
    FPS.frames = FPS.frames + 1
    if FPS.acc >= 0.3 then
        FPS.value = math.floor(FPS.frames / FPS.acc + 0.5)
        FPS.acc = 0
        FPS.frames = 0
    end

    local shown = V.FPSCustom and V.FPSValue or FPS.value
    fpsLabel.Text = shown .. " FPS"
    fpsLabel.TextColor3 = V.Colors.FPS
    fpsLabel.AnchorPoint = Vector2.new(V.FPSX, V.FPSY)
    fpsLabel.Position = UDim2.new(V.FPSX, 8 - 16 * V.FPSX, V.FPSY, 8 - 16 * V.FPSY)
end

-- ===== Angel mode (розовые крылья) =====
local Wing = {model = nil, char = nil, bases = {}}
local WING_ANGLES = {78, 60, 42, 24, 6, -12}
local WING_LEN = {1.4, 1.7, 1.95, 1.95, 1.7, 1.4}
local PINK = Color3.fromRGB(255, 140, 190)
local LIGHT_PINK = Color3.fromRGB(255, 205, 228)

local function mkFeather(base, model, len, wid, ang, off, z, color, mat)
    local p = Instance.new("Part")
    p.Size = Vector3.new(len, wid, 0.1)
    p.Color = color
    p.Material = mat
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.Massless = true
    p.CastShadow = false
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth

    local m = Instance.new("SpecialMesh")
    m.MeshType = Enum.MeshType.Sphere
    m.Parent = p

    local a = math.rad(ang)
    local d = off + len / 2
    local w = Instance.new("Weld")
    w.Part0 = base
    w.Part1 = p
    w.C0 = CFrame.new(math.cos(a) * d, math.sin(a) * d, z) * CFrame.Angles(0, 0, a)
    w.Parent = p
    p.Parent = model
end

local function destroyWings()
    if Wing.model then pcall(function() Wing.model:Destroy() end) end
    Wing.model = nil
    Wing.bases = {}
end

local function buildWings(char)
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if not torso then return false end

    local model = Instance.new("Model")
    model.Name = "NurHub_Wings"
    Wing.bases = {}

    for _, side in ipairs({1, -1}) do
        local base = Instance.new("Part")
        base.Name = "WingBase"
        base.Size = Vector3.new(0.2, 0.2, 0.2)
        base.Transparency = 1
        base.CanCollide = false
        base.CanTouch = false
        base.CanQuery = false
        base.Massless = true
        base.CastShadow = false
        base.Parent = model

        local weld = Instance.new("Weld")
        weld.Part0 = torso
        weld.Part1 = base
        weld.Parent = base
        table.insert(Wing.bases, {weld = weld, side = side})

        for i, ang in ipairs(WING_ANGLES) do
            local len = WING_LEN[i]
            mkFeather(base, model, len, 0.62, ang, 0.15, 0, PINK, Enum.Material.SmoothPlastic)
            mkFeather(base, model, len * 0.55, 0.46, ang, 0.1, 0.07, LIGHT_PINK, Enum.Material.Neon)
        end
    end

    model.Parent = char
    Wing.model = model
    return true
end

local function updateWings()
    local char = LocalPlayer.Character
    if Config.Visual.Angel and char then
        if Wing.char ~= char or not Wing.model or not Wing.model.Parent then
            destroyWings()
            Wing.char = char
            buildWings(char)
        end
        if Wing.model then
            local a = 0.5 + math.sin(os.clock() * 2.2) * 0.18
            for _, b in ipairs(Wing.bases) do
                local yaw = (b.side == 1) and -a or (math.pi + a)
                b.weld.C0 = CFrame.new(b.side * 0.4, 0.35, 0.55) * CFrame.Angles(0, yaw, 0)
            end
        end
    elseif Wing.model then
        destroyWings()
    end
end

-- ==========================================================
-- 3.5 МИР (World): шейдеры, небо, свет
-- ==========================================================

local WorldFX = {orig = {}, hiddenSky = {}, atmo = {}, black = false, dirty = false, part = nil, emitter = nil}
local LIGHT_PROPS = {"ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "GlobalShadows",
    "FogEnd", "ColorShift_Top", "ExposureCompensation"}

local function getFX(class, name)
    local e = Lighting:FindFirstChild(name)
    if not e then
        e = Instance.new(class)
        e.Name = name
        e.Parent = Lighting
    end
    return e
end

local function ensureFXPart()
    if WorldFX.part and WorldFX.part.Parent then return end
    local p = Instance.new("Part")
    p.Name = "NurHub_FX"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Transparency = 1
    p.Size = Vector3.new(80, 1, 80)

    local e = Instance.new("ParticleEmitter")
    e.EmissionDirection = Enum.NormalId.Bottom
    e.Lifetime = NumberRange.new(7, 10)
    e.Speed = NumberRange.new(3, 6)
    e.SpreadAngle = Vector2.new(12, 12)
    e.Acceleration = Vector3.new(3, 0, 1.5)
    e.Rotation = NumberRange.new(0, 360)
    e.RotSpeed = NumberRange.new(-80, 80)
    e.Size = NumberSequence.new(0.4)
    e.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.1, 0.15),
        NumberSequenceKeypoint.new(0.9, 0.15),
        NumberSequenceKeypoint.new(1, 1),
    })
    e.LightEmission = 0.35
    e.LockedToPart = false
    e.Parent = p

    p.Parent = workspace.CurrentCamera
    WorldFX.part = p
    WorldFX.emitter = e
end

local function restoreSky()
    local s = Lighting:FindFirstChild("NurHub_Sky")
    if s then s:Destroy() end
    for _, o in ipairs(WorldFX.hiddenSky) do
        pcall(function() o.Parent = Lighting end)
    end
    WorldFX.hiddenSky = {}
    for o, t in pairs(WorldFX.atmo) do
        pcall(function()
            o.Density = t[1]
            o.Haze = t[2]
            o.Glare = t[3]
        end)
    end
    WorldFX.atmo = {}
    WorldFX.black = false
end

local function worldCleanup()
    for _, n in ipairs({"NurHub_CCShader", "NurHub_CCGrade", "NurHub_Bloom", "NurHub_Rays"}) do
        local o = Lighting:FindFirstChild(n)
        if o then o:Destroy() end
    end
    if WorldFX.part then pcall(function() WorldFX.part:Destroy() end) end
    WorldFX.part, WorldFX.emitter = nil, nil
    for p, v in pairs(WorldFX.orig) do
        pcall(function() Lighting[p] = v end)
    end
    WorldFX.orig = {}
    restoreSky()
    WorldFX.dirty = false
end
ENV.NurHubWorldCleanup = worldCleanup

local function applyWorld()
    local W = Config.World
    WorldFX.dirty = true

    local shader
    if W.Shader then
        for _, s in ipairs(SHADERS) do
            if s.id == W.ShaderName then shader = s break end
        end
    end
    local k = math.clamp(W.Intensity, 10, 100) / 100
    local white = Color3.new(1, 1, 1)

    -- свойства Lighting
    local want = {}
    if W.Time then want.ClockTime = W.TimeValue end
    if shader then
        want.ColorShift_Top = white:Lerp(shader.top, k * 0.6)
        want.ExposureCompensation = shader.exp * k
    end
    if W.Fullbright then
        want.Brightness = 2
        want.Ambient = Color3.fromRGB(190, 190, 190)
        want.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
        want.GlobalShadows = false
        want.FogEnd = 100000
    end
    for _, prop in ipairs(LIGHT_PROPS) do
        local w = want[prop]
        if w ~= nil then
            if WorldFX.orig[prop] == nil then WorldFX.orig[prop] = Lighting[prop] end
            if Lighting[prop] ~= w then Lighting[prop] = w end
        elseif WorldFX.orig[prop] ~= nil then
            Lighting[prop] = WorldFX.orig[prop]
            WorldFX.orig[prop] = nil
        end
    end

    -- цветокоррекция шейдера
    local cc = Lighting:FindFirstChild("NurHub_CCShader")
    if shader then
        cc = cc or getFX("ColorCorrectionEffect", "NurHub_CCShader")
        cc.Enabled = true
        cc.TintColor = white:Lerp(shader.tint, k)
        cc.Saturation = shader.sat * k
        cc.Contrast = shader.con * k
        cc.Brightness = shader.bri * k
    elseif cc and cc.Enabled then
        cc.Enabled = false
    end

    -- затемнение + цветокоррекция
    local gr = Lighting:FindFirstChild("NurHub_CCGrade")
    if W.Dark or W.Grade then
        gr = gr or getFX("ColorCorrectionEffect", "NurHub_CCGrade")
        gr.Enabled = true
        gr.Brightness = W.Dark and -(W.DarkAmount / 100) * 0.6 or 0
        gr.Saturation = W.Grade and (W.Saturation / 100) or 0
        gr.Contrast = W.Grade and (W.Contrast / 100) or 0
    elseif gr and gr.Enabled then
        gr.Enabled = false
    end

    -- свечение
    local bI, bS, bT = 0, 24, 1
    if shader then bI, bS, bT = shader.bloom * k, shader.bloomSize, shader.bloomT end
    if W.Glow then
        bI = math.max(bI, W.GlowAmount / 100 * 2.5)
        bS = math.max(bS, 40)
        bT = math.min(bT, 0.8)
    end
    local bl = Lighting:FindFirstChild("NurHub_Bloom")
    if bI > 0 then
        bl = bl or getFX("BloomEffect", "NurHub_Bloom")
        bl.Enabled = true
        bl.Intensity = bI
        bl.Size = bS
        bl.Threshold = bT
    elseif bl and bl.Enabled then
        bl.Enabled = false
    end

    -- лучи солнца
    local sr = Lighting:FindFirstChild("NurHub_Rays")
    if shader and shader.rays > 0 then
        sr = sr or getFX("SunRaysEffect", "NurHub_Rays")
        sr.Enabled = true
        sr.Intensity = shader.rays * k
        sr.Spread = 0.8
    elseif sr and sr.Enabled then
        sr.Enabled = false
    end

    -- чёрное небо
    if W.BlackSky then
        if not WorldFX.black then
            WorldFX.black = true
            for _, o in ipairs(Lighting:GetChildren()) do
                if o:IsA("Sky") and o.Name ~= "NurHub_Sky" then
                    table.insert(WorldFX.hiddenSky, o)
                    o.Parent = nil
                elseif o:IsA("Atmosphere") then
                    WorldFX.atmo[o] = {o.Density, o.Haze, o.Glare}
                    o.Density = 0
                    o.Haze = 0
                    o.Glare = 0
                end
            end
            local sky = Instance.new("Sky")
            sky.Name = "NurHub_Sky"
            sky.SkyboxBk, sky.SkyboxDn, sky.SkyboxFt = "", "", ""
            sky.SkyboxLf, sky.SkyboxRt, sky.SkyboxUp = "", "", ""
            sky.StarCount = 0
            sky.CelestialBodiesShown = false
            sky.Parent = Lighting
        end
    elseif WorldFX.black then
        restoreSky()
    end

    -- частицы шейдера (лепестки сакуры, кровавый дождь)
    local pd = shader and shader.particle
    if pd then
        ensureFXPart()
        local cam = workspace.CurrentCamera
        if WorldFX.part.Parent ~= cam then WorldFX.part.Parent = cam end
        WorldFX.part.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 22, 0))
        WorldFX.emitter.Color = ColorSequence.new(pd.color)
        WorldFX.emitter.Rate = pd.rate * k
        WorldFX.emitter.Enabled = true
    elseif WorldFX.part then
        pcall(function() WorldFX.part:Destroy() end)
        WorldFX.part, WorldFX.emitter = nil, nil
    end
end

-- ==========================================================
-- 4. БОЕВАЯ ЧАСТЬ (COMBAT)
-- ==========================================================

local AimState = {Aiming = false, Locked = nil}

local SilentState = ENV.NurHubSilentState or {}
ENV.NurHubSilentState = SilentState
SilentState.Mouse = LocalPlayer:GetMouse()
SilentState.Enabled = false
SilentState.Target = nil
SilentState.Pos = Vector3.zero
SilentState.Chance = 100

local function touchOnly()
    return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

local function getAimPoint()
    if touchOnly() then return Camera.ViewportSize / 2 end
    return UserInputService:GetMouseLocation()
end

-- Цепочки частей: центр выбранного типа тела (R15). Для R6 берётся сама часть.
local LIMB_CHAIN = {
    Torso    = {"UpperTorso", "LowerTorso"},
    LeftArm  = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},
    RightArm = {"RightUpperArm", "RightLowerArm", "RightHand"},
    LeftLeg  = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
    RightLeg = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
}

-- Точная мировая позиция выбранной части тела (центр торса / конечности / голова)
local function aimPos(part)
    local char = part.Parent
    local chain = LIMB_CHAIN[Config.Combat.TargetPart]
    if chain and char then
        local sum, n = Vector3.zero, 0
        for _, nm in ipairs(chain) do
            local p = char:FindFirstChild(nm)
            if p and p:IsA("BasePart") then
                sum = sum + p.Position
                n = n + 1
            end
        end
        if n > 0 then return sum / n end
    end
    return part.Position
end

local function isVisible(targetPart)
    if not Config.Combat.VisibleCheck then return true end
    local ignore = {targetPart.Parent}
    if LocalPlayer.Character then table.insert(ignore, LocalPlayer.Character) end

    local params = RaycastParams.new()
    params.FilterDescendantsInstances = ignore
    params.FilterType = Enum.RaycastFilterType.Exclude

    local origin = Camera.CFrame.Position
    local pos = aimPos(targetPart)
    return workspace:Raycast(origin, pos - origin, params) == nil
end

local function getTargetPart(char)
    local list = PART_MAP[Config.Combat.TargetPart] or PART_MAP.Head
    for _, name in ipairs(list) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then return p end
    end
    return nil -- строго выбранная часть: если её нет, игрок пропускается
end

local function isEnemy(player)
    if not Config.Combat.TeamCheck then return true end
    if LocalPlayer.Team == nil or player.Team == nil then return true end
    return player.Team ~= LocalPlayer.Team
end

local function predictedPos(part)
    return aimPos(part) + part.AssemblyLinearVelocity * Config.Combat.Prediction
end

local function getTarget(fov)
    local closest, shortest = nil, fov
    local aimPoint = getAimPoint()

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and isEnemy(player) then
            local part = getTargetPart(player.Character)
            local hum = player.Character:FindFirstChildOfClass("Humanoid")
            if part and hum and hum.Health > 0 then
                local sp, onScreen = Camera:WorldToViewportPoint(aimPos(part))
                if onScreen then
                    local d = (Vector2.new(sp.X, sp.Y) - aimPoint).Magnitude
                    if d < shortest and isVisible(part) then
                        shortest = d
                        closest = part
                    end
                end
            end
        end
    end
    return closest
end

local function stillValid(part, fov)
    if not part or not part.Parent then return false end
    local hum = part.Parent:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    local sp, onScreen = Camera:WorldToViewportPoint(aimPos(part))
    if not onScreen then return false end
    if (Vector2.new(sp.X, sp.Y) - getAimPoint()).Magnitude > fov * 1.25 then return false end
    return isVisible(part)
end

track(UserInputService.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then AimState.Aiming = true end
end))
track(UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        AimState.Aiming = false
        AimState.Locked = nil
    end
end))

local function updateAimbot(dt)
    local C = Config.Combat
    if not C.Aimbot then AimState.Locked = nil return end

    local holding = (not C.HoldToAim) or touchOnly() or AimState.Aiming
    if not holding then AimState.Locked = nil return end

    local target
    if C.Sticky and AimState.LockedKey == C.TargetPart and stillValid(AimState.Locked, C.AimbotFOV) then
        target = AimState.Locked
    else
        target = getTarget(C.AimbotFOV)
        AimState.Locked = target
        AimState.LockedKey = C.TargetPart
    end

    if target then
        local cur = Camera.CFrame
        local goal = CFrame.new(cur.Position, predictedPos(target))
        local alpha = 1 - (1 - C.AimbotSmoothness) ^ (math.clamp(dt, 0, 0.1) * 60)
        if cur.LookVector:Dot(goal.LookVector) > 0.99998 then
            Camera.CFrame = goal -- почти навелись: ставим ровно в центр части тела
        else
            Camera.CFrame = cur:Lerp(goal, alpha)
        end
    end
end

local function updateSilent()
    local C = Config.Combat
    SilentState.Enabled = C.SilentAim
    SilentState.Chance = C.HitChance
    if C.SilentAim then
        local t = getTarget(C.SilentFOV)
        SilentState.Target = t
        if t then SilentState.Pos = predictedPos(t) end
    else
        SilentState.Target = nil
    end
end

if not ENV.NurHubHooked then
    ENV.NurHubHooked = true
    local ok = pcall(function()
        assert(hookmetamethod and getnamecallmethod and checkcaller)
        local S = SilentState
        local function roll() return math.random(1, 100) <= S.Chance end

        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(self, key)
            if S.Enabled and S.Target and self == S.Mouse and not checkcaller()
                and (key == "Hit" or key == "Target") and roll() then
                if key == "Hit" then return CFrame.new(S.Pos) end
                return S.Target
            end
            return oldIndex(self, key)
        end)

        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if S.Enabled and S.Target and self == workspace and not checkcaller() then
                local method = getnamecallmethod()
                if method == "Raycast" then
                    local origin, dir, params = ...
                    if typeof(origin) == "Vector3" and typeof(dir) == "Vector3" and roll() then
                        return oldNamecall(self, origin, (S.Pos - origin).Unit * dir.Magnitude, params)
                    end
                elseif method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList"
                    or method == "FindPartOnRayWithWhitelist" then
                    local ray, a, b, c = ...
                    if typeof(ray) == "Ray" and roll() then
                        local o = ray.Origin
                        return oldNamecall(self, Ray.new(o, (S.Pos - o).Unit * ray.Direction.Magnitude), a, b, c)
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
    end)
    if not ok then
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "NurHub", Text = L("Silent Aim не поддерживается этим экзекутором"), Duration = 6
            })
        end)
    end
end

local function makeCircle()
    local f = Instance.new("Frame")
    f.AnchorPoint = Vector2.new(0.5, 0.5)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    f.Visible = false
    f.Parent = espGui
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(1, 0)
    c.Parent = f
    local s = Instance.new("UIStroke")
    s.Thickness = 1.5
    s.Parent = f
    return f, s
end
local aimCircle, aimStroke = makeCircle()
local silentCircle, silentStroke = makeCircle()

local function updateCircles()
    local C = Config.Combat
    local ap = getAimPoint()

    aimCircle.Visible = C.Aimbot and C.ShowFOV
    if aimCircle.Visible then
        aimCircle.Size = UDim2.fromOffset(C.AimbotFOV * 2, C.AimbotFOV * 2)
        aimCircle.Position = UDim2.fromOffset(ap.X, ap.Y)
        aimStroke.Color = C.Colors.AimbotFOV
        aimStroke.Thickness = AimState.Locked and 2.5 or 1.5
    end

    silentCircle.Visible = C.SilentAim and C.ShowSilentFOV
    if silentCircle.Visible then
        silentCircle.Size = UDim2.fromOffset(C.SilentFOV * 2, C.SilentFOV * 2)
        silentCircle.Position = UDim2.fromOffset(ap.X, ap.Y)
        silentStroke.Color = C.Colors.SilentFOV
        silentStroke.Thickness = SilentState.Target and 2.5 or 1.5
    end
end

-- ==========================================================
-- 5. ИГРОК (PLAYER)
-- ==========================================================

local modded = {speed = false, jump = false}
ENV.NurHubModded = modded

local function applyPlayerMods()
    local char = LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    if Config.Player.WalkSpeed ~= 16 then
        modded.speed = true
        if humanoid.WalkSpeed ~= Config.Player.WalkSpeed then
            humanoid.WalkSpeed = Config.Player.WalkSpeed
        end
    elseif modded.speed then
        modded.speed = false
        humanoid.WalkSpeed = 16
    end

    if Config.Player.JumpPower ~= 50 then
        modded.jump = true
        humanoid.UseJumpPower = true
        if humanoid.JumpPower ~= Config.Player.JumpPower then
            humanoid.JumpPower = Config.Player.JumpPower
        end
    elseif modded.jump then
        modded.jump = false
        humanoid.UseJumpPower = true
        humanoid.JumpPower = 50
    end
end

local wasNoclip = false
track(RunService.Stepped:Connect(function()
    local char = LocalPlayer.Character
    if not char then return end
    if Config.Player.Noclip and Lic.Active then
        wasNoclip = true
        for _, part in ipairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    elseif wasNoclip then
        wasNoclip = false
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CanCollide = true end
    end
end))

local function stopFly()
    if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
    if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = false end
end

local function updateFly()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    if Config.Player.Fly then
        if not flyBodyVelocity or flyBodyVelocity.Parent ~= hrp then
            stopFly()
            flyBodyVelocity = Instance.new("BodyVelocity")
            flyBodyVelocity.Name = "NurHub_Fly"
            flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
            flyBodyVelocity.Velocity = Vector3.zero
            flyBodyVelocity.Parent = hrp

            flyBodyGyro = Instance.new("BodyGyro")
            flyBodyGyro.Name = "NurHub_Fly"
            flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
            flyBodyGyro.P = 1000
            flyBodyGyro.Parent = hrp
        end

        hum.PlatformStand = true
        local moveLocal = Camera.CFrame:VectorToObjectSpace(hum.MoveDirection)
        local dir = Camera.CFrame:VectorToWorldSpace(Vector3.new(moveLocal.X, 0, moveLocal.Z))
        if dir.Magnitude > 0 then dir = dir.Unit end

        flyBodyVelocity.Velocity = dir * Config.Player.FlySpeed
        flyBodyGyro.CFrame = Camera.CFrame
    elseif flyBodyVelocity or flyBodyGyro then
        stopFly()
    end
end

-- Spin: вращение персонажа вокруг своей оси
local Spin = {on = false}

local function stopSpin()
    if Spin.on then
        Spin.on = false
        ENV.NurHubSpinOn = false
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
    end
end

local function updateSpin(dt)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not (hrp and hum) then return end

    if Config.Player.Spin then
        Spin.on = true
        ENV.NurHubSpinOn = true
        hum.AutoRotate = false
        if not Config.Player.Fly then
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(Config.Player.SpinSpeed) * math.clamp(dt, 0, 0.1), 0)
        end
    else
        stopSpin()
    end
end

track(LocalPlayer.CharacterAdded:Connect(function()
    flyBodyVelocity, flyBodyGyro = nil, nil
    modded.speed, modded.jump = false, false
    Spin.on = false
    ENV.NurHubSpinOn = false
end))

-- ==========================================================
-- 5.5 ОТКЛЮЧЕНИЕ ФУНКЦИЙ БЕЗ ЛИЦЕНЗИИ
-- ==========================================================

local function suspendAll()
    espGui.Enabled = false
    for _, obj in pairs(espObjects) do pcall(hideAll, obj) end

    SilentState.Enabled = false
    SilentState.Target = nil
    AimState.Locked = nil

    if flyBodyVelocity or flyBodyGyro then stopFly() end
    stopSpin()
    if Wing.model then destroyWings() end
    if WorldFX.dirty then worldCleanup() end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        if modded.speed then modded.speed = false hum.WalkSpeed = 16 end
        if modded.jump then modded.jump = false hum.JumpPower = 50 end
    end
end

-- ==========================================================
-- 6. ГЛАВНЫЙ ЦИКЛ
-- ==========================================================

RunService:BindToRenderStep("NurHubLoop", Enum.RenderPriority.Camera.Value + 1, function(dt)
    if not Lic.Active then
        pcall(suspendAll)
        return
    end

    espGui.Enabled = true
    pcall(updateESP)
    pcall(updateAimbot, dt)
    pcall(updateSilent)
    pcall(updateCircles)
    pcall(applyPlayerMods)
    pcall(updateFly)
    pcall(updateSpin, dt)
    pcall(updateWings)
    pcall(applyWorld)
    pcall(updateFPS, dt)
end)

track(Players.PlayerRemoving:Connect(clearESP))

-- Запуск системы ключей (окно с анимацией)
Lic.Start()

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "NurHub",
        Text = L("Скрипт загружен! Введите ключ."),
        Duration = 5
    })
end)
