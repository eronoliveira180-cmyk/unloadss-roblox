-- // ========== INICIALIZAÇÃO ==========
if not game:IsLoaded() then game.Loaded:Wait() end
if not syn or not protectgui then getgenv().protectgui = function() end end

getgenv().SniperArenaConfig = {
    -- Modo Geral
    UseSilentAim = true,          -- Ativa motor de Silent Aim (Raycast/Mouse.Hit)
    UseClassicAimbot = true,      -- Ativa aimbot clássico (suavização/FOV)
    UseESP = true,                -- Ativa ESP
    UseTracers = false,           -- Ativa traços
    
    -- Silent Aim
    SilentMethod = "Raycast",     -- Raycast, Mouse.Hit, FindPartOnRay...
    TeamCheckSilent = false,
    VisibleCheckSilent = false,
    TargetPart = "Head",          -- Head, HumanoidRootPart, Random
    Prediction = true,
    PredictionAmount = 0.165,
    HitChance = 100,
    
    -- Classic Aimbot
    FOVSize = 140,
    Smoothness = 0.12,
    AimbotKey = Enum.KeyCode.E,
    AimbotKeyType = Enum.UserInputType.Keyboard,
    AimbotBindMode = false,
    
    -- Visual
    FOVVisible = true,
    FOVColor = Color3.fromRGB(54, 57, 241),
    ShowMouseTarget = true,
    
    -- GUI
    Visible = true
}

-- // ========== SERVIÇOS ==========
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local RenderStepped = RunService.RenderStepped

-- // ========== FUNÇÕES AUXILIARES ==========
local function RandomNew() return Random.new() end
local function CalculateChance(Percentage)
    Percentage = math.floor(Percentage or 100)
    local chance = math.floor(RandomNew().NextNumber(RandomNew(), 0, 1) * 100) / 100
    return chance <= Percentage / 100
end

local function GetPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

-- // ========== DETECÇÃO DE ALVO ==========
local function IsEnemy(player)
    if not player or player == LocalPlayer then return false end
    if SniperArenaConfig.TeamCheckSilent and player.Team and LocalPlayer.Team then
        return player.Team ~= LocalPlayer.Team
    end
    return true
end

local function GetCharacterFromTarget(target)
    if target and target:IsA("Player") then return target.Character
    elseif target and target:IsA("Model") then return target end
    return nil
end

local function IsPlayerVisible(Player)
    local Char = Player.Character
    local LocalChar = LocalPlayer.Character
    if not Char or not LocalChar then return false end
    local HRP = Char:FindFirstChild("HumanoidRootPart")
    if not HRP then return false end
    local CastPoints = {HRP.Position, LocalChar, Char}
    local IgnoreList = {LocalChar, Char}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    return ObscuringObjects == 0
end

local ValidTargetParts = {"Head", "HumanoidRootPart"}

local function GetClosestPlayer()
    local Closest, Dist
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsEnemy(p) then
            local Char = p.Character
            if Char then
                local Hum = Char:FindFirstChild("Humanoid")
                if Hum and Hum.Health > 0 then
                    if SniperArenaConfig.VisibleCheckSilent and not IsPlayerVisible(p) then continue end
                    local PartName = SniperArenaConfig.TargetPart
                    local TargetPart
                    if PartName == "Random" then
                        TargetPart = Char[ValidTargetParts[math.random(1, #ValidTargetParts)]]
                    else
                        TargetPart = Char:FindFirstChild(PartName)
                    end
                    if TargetPart then
                        local ScreenPos, OnScr = GetPositionOnScreen(TargetPart.Position)
                        if OnScr then
                            local MousePos = UserInputService:GetMouseLocation()
                            local D = (MousePos - ScreenPos).Magnitude
                            if D <= (SniperArenaConfig.FOVSize or 140) and (not Dist or D < Dist) then
                                Dist = D
                                Closest = p
                            end
                        end
                    end
                end
            end
        end
    end
    return Closest
end

-- // ========== SILENT AIM ENGINE ==========
local function GetSilentAimDirection(Target)
    local Char = GetCharacterFromTarget(Target)
    local Part = Char and (SniperArenaConfig.TargetPart == "Random" and Char[ValidTargetParts[math.random(1, #ValidTargetParts)]] or Char:FindFirstChild(SniperArenaConfig.TargetPart))
    if not Part then return nil end
    local Pos = Part.Position
    if SniperArenaConfig.Prediction and Target.PrimaryPart and Target.PrimaryPart.Velocity then
        Pos = Pos + Target.PrimaryPart.Velocity * SniperArenaConfig.PredictionAmount
    end
    return (Pos - Camera.CFrame.Position).Unit * 1000
end

local function ApplySilentAim()
    if not SniperArenaConfig.UseSilentAim then return end
    local Target = GetClosestPlayer()
    if not Target or not CalculateChance(SniperArenaConfig.HitChance) then return end
    local Dir = GetSilentAimDirection(Target)
    if not Dir then return end
    
    local Method = SniperArenaConfig.SilentMethod
    if Method == "Mouse.Hit" then
        local CF = CFrame.new(Camera.CFrame.Position, Camera.CFrame.Position + Dir)
        Mouse.Hit = CF
        Mouse.Target = Target.Character or Target.PrimaryPart
    end
end

-- // ========== DESENHOS (Drawing) ==========
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1.5
FOVCircle.Filled = false
FOVCircle.ZIndex = 999
FOVCircle.Visible = false

local MouseBox = Drawing.new("Square")
MouseBox.Size = Vector2.new(20, 20)
MouseBox.Color = Color3.fromRGB(54, 57, 241)
MouseBox.Thickness = 2
MouseBox.Filled = false
MouseBox.ZIndex = 999
MouseBox.Visible = false

local ESPObjects = {}

local function CreateESP(plr)
    if ESPObjects[plr] then return end
    local data = {
        Box = Drawing.new("Square"),
        Tracer = Drawing.new("Line")
    }
    data.Box.Thickness = 1.5
    data.Box.Filled = false
    data.Tracer.Thickness = 1
    ESPObjects[plr] = data
end

local function RemoveESP(plr)
    if ESPObjects[plr] then
        ESPObjects[plr].Box:Remove()
        ESPObjects[plr].Tracer:Remove()
        ESPObjects[plr] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do
    if p ~= LocalPlayer then CreateESP(p) end
end
Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

-- // ========== AIMBOT CLÁSSICO ==========
local AimTarget = nil
local AimTargetLostTime = 0

local function GetAimbotTarget()
    local Best, BestDist
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and IsEnemy(p) then
            local Char = p.Character
            if Char then
                local HRP = Char:FindFirstChild("HumanoidRootPart")
                if HRP then
                    local ScreenPos, OnScr = GetPositionOnScreen(HRP.Position)
                    if OnScr then
                        local MousePos = UserInputService:GetMouseLocation()
                        local D = (MousePos - ScreenPos).Magnitude
                        if D <= SniperArenaConfig.FOVSize and (not BestDist or D < BestDist) then
                            BestDist = D
                            Best = p
                        end
                    end
                end
            end
        end
    end
    return Best
end

local AimbotKeyDown = false

-- // ========== GUI ==========
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
local UICorner = Instance.new("UICorner", MainFrame)
local Title = Instance.new("TextButton", MainFrame)
local ControlFrame = Instance.new("ScrollingFrame", MainFrame)
local UIListLayout = Instance.new("UIListLayout", ControlFrame)

MainFrame.Size = UDim2.new(0, 220, 0, 380)
MainFrame.Position = UDim2.new(0.5, -110, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
UICorner.CornerRadius = UDim.new(0, 8)

Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "SniperArena [▼]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18

ControlFrame.Name = "Controls"
ControlFrame.Size = UDim2.new(1, 0, 1, -40)
ControlFrame.Position = UDim2.new(0, 0, 0, 40)
ControlFrame.BackgroundTransparency = 1
ControlFrame.ClipsDescendants = true
ControlFrame.Active = true
ControlFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ControlFrame.ScrollBarThickness = 6
ControlFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
UIListLayout.Padding = UDim.new(0, 6)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local Expanded = true
Title.MouseButton1Click:Connect(function()
    Expanded = not Expanded
    if Expanded then
        MainFrame:TweenSize(UDim2.new(0, 220, 0, 380), "Out", "Quad", 0.3, true)
        ControlFrame.Visible = true
        Title.Text = "SniperArena [▼]"
    else
        MainFrame:TweenSize(UDim2.new(0, 220, 0, 40), "Out", "Quad", 0.3, true)
        task.wait(0.3)
        ControlFrame.Visible = false
        Title.Text = "SniperArena [▲]"
    end
end)

local function MakeBtn(name, def, colorOn)
    local btn = Instance.new("TextButton", ControlFrame)
    btn.Size = UDim2.new(0, 200, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = def and (name .. ": ON") or (name .. ": OFF")
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    Instance.new("UICorner", btn)
    return btn
end

-- Toggle callbacks
local function Toggle(key, btn, name, color)
    return function()
        SniperArenaConfig[key] = not SniperArenaConfig[key]
        btn.Text = SniperArenaConfig[key] and (name .. ": ON") or (name .. ": OFF")
        btn.BackgroundColor3 = SniperArenaConfig[key] and color or Color3.fromRGB(45, 45, 45)
    end
end

local SilentBtn = MakeBtn("Silent Aim", true, Color3.fromRGB(180, 0, 0))
SilentBtn.MouseButton1Click:Connect(Toggle("UseSilentAim", SilentBtn, "Silent Aim", Color3.fromRGB(180, 0, 0)))

local ClassicBtn = MakeBtn("Classic Aimbot", true, Color3.fromRGB(0, 120, 255))
ClassicBtn.MouseButton1Click:Connect(Toggle("UseClassicAimbot", ClassicBtn, "Classic Aimbot", Color3.fromRGB(0, 120, 255)))

local EspBtn = MakeBtn("ESP", true, Color3.fromRGB(0, 200, 50))
EspBtn.MouseButton1Click:Connect(Toggle("UseESP", EspBtn, "ESP", Color3.fromRGB(0, 200, 50)))

local TrBtn = MakeBtn("Tracers", false, Color3.fromRGB(200, 150, 0))
TrBtn.MouseButton1Click:Connect(Toggle("UseTracers", TrBtn, "Tracers", Color3.fromRGB(200, 150, 0)))

local FovVisBtn = MakeBtn("Show FOV", true, Color3.fromRGB(120, 0, 180))
FovVisBtn.MouseButton1Click:Connect(Toggle("FOVVisible", FovVisBtn, "Show FOV", Color3.fromRGB(120, 0, 180)))

local MouseVisBtn = MakeBtn("Show MouseTarget", true, Color3.fromRGB(220, 100, 0))
MouseVisBtn.MouseButton1Click:Connect(Toggle("ShowMouseTarget", MouseVisBtn, "Show MouseTarget", Color3.fromRGB(220, 100, 0)))

local function MakeSlider(text, key, min, max, dec)
    local frame = Instance.new("Frame", ControlFrame)
    frame.Size = UDim2.new(0, 200, 0, 35)
    frame.BackgroundTransparency = 1
    local lbl = Instance.new("TextLabel", frame)
    lbl.Size = UDim2.new(1, 0, 0, 14)
    lbl.BackgroundTransparency = 1
    lbl.Text = text .. ": " .. SniperArenaConfig[key]
    lbl.TextColor3 = Color3.new(1, 1, 1)
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 11
    local slider = Instance.new("TextButton", frame)
    slider.Size = UDim2.new(1, 0, 0, 16)
    slider.Position = UDim2.new(0, 0, 0, 16)
    slider.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    slider.Text = ""
    slider.AutoButtonColor = false
    Instance.new("UICorner", slider)
    local function update()
        lbl.Text = text .. ": " .. SniperArenaConfig[key]
    end
    local dragging = false
    slider.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true end end)
    slider.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    UserInputService.InputChanged:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseMovement and dragging then
            local rel = math.clamp(i.Position.X - slider.AbsolutePosition.X, 0, 200)
            local perc = rel / 200
            SniperArenaConfig[key] = math.round((min + (max - min) * perc) * (10^dec)) / (10^dec)
            update()
        end
    end)
    return frame, update
end

local FovSlider, UpdFov = MakeSlider("FOV Size", "FOVSize", 30, 500, 0)
local SmoothSlider, UpdSm = MakeSlider("Smoothness", "Smoothness", 0.01, 0.5, 3)
local PredSlider, UpdPred = MakeSlider("Prediction", "PredictionAmount", 0.01, 1, 3)

local function MakeBindBtn()
    local btn = Instance.new("TextButton", ControlFrame)
    btn.Size = UDim2.new(0, 200, 0, 32)
    btn.BackgroundColor3 = Color3.fromRGB(60, 40, 100)
    btn.Text = "Bind: " .. tostring(SniperArenaConfig.AimbotKey or "E")
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 12
    Instance.new("UICorner", btn)
    btn.MouseButton1Click:Connect(function()
        SniperArenaConfig.AimbotBindMode = true
        btn.Text = "Press key..."
        btn.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    end)
    return btn
end
local BindBtn = MakeBindBtn()

local UnloadBtn = Instance.new("TextButton", ControlFrame)
UnloadBtn.Size = UDim2.new(0, 200, 0, 32)
UnloadBtn.BackgroundColor3 = Color3.fromRGB(160, 0, 0)
UnloadBtn.Text = "Unload"
UnloadBtn.TextColor3 = Color3.new(1, 1, 1)
UnloadBtn.Font = Enum.Font.GothamBold
UnloadBtn.TextSize = 12
Instance.new("UICorner", UnloadBtn)
UnloadBtn.MouseButton1Click:Connect(function()
    for _, v in pairs(ESPObjects) do if v.Box then v.Box:Remove() v.Tracer:Remove() end end
    if FOVCircle then FOVCircle:Remove() end
    if MouseBox then MouseBox:Remove() end
    if ScreenGui then ScreenGui:Destroy() end
    pcall(function() RenderStepped:Disconnect() end)
    pcall(function() UserInputService.InputBegan:Disconnect() end)
    pcall(function() UserInputService.InputEnded:Disconnect() end)
end)

-- ========== LOOP PRINCIPAL ==========
local AimbotTarget = nil

RunService.RenderStepped:Connect(function(dt)
    -- INPUT BIND
    if SniperArenaConfig.AimbotBindMode then
        -- captura será no InputBegan
    end

    -- FOV CIRCLE
    if SniperArenaConfig.FOVVisible then
        FOVCircle.Visible = true
        FOVCircle.Radius = SniperArenaConfig.FOVSize
        FOVCircle.Position = UserInputService:GetMouseLocation()
        FOVCircle.Color = SniperArenaConfig.FOVColor
    else
        FOVCircle.Visible = false
    end

    -- MOUSE TARGET VIS
    if SniperArenaConfig.ShowMouseTarget then
        local Target = GetClosestPlayer()
        if Target then
            local C = Target.Character
            if C then
                local Part = SniperArenaConfig.TargetPart == "Random" and C[ValidTargetParts[math.random(1, #ValidTargetParts)]] or C:FindFirstChild(SniperArenaConfig.TargetPart)
                if Part then
                    local sp, ok = GetPositionOnScreen(Part.Position)
                    MouseBox.Visible = ok
                    MouseBox.Position = Vector2.new(sp.X - 10, sp.Y - 10)
                else
                    MouseBox.Visible = false
                end
            else
                MouseBox.Visible = false
            end
        else
            MouseBox.Visible = false
        end
    else
        MouseBox.Visible = false
    end

    -- ESP
    if SniperArenaConfig.UseESP then
        for plr, data in pairs(ESPObjects) do
            local C = plr.Character
            local alive = C and C:FindFirstChild("Humanoid") and C.Humanoid.Health > 0
            if alive and C:FindFirstChild("HumanoidRootPart") then
                local pos, on = GetPositionOnScreen(C.HumanoidRootPart.Position)
                data.Box.Visible = on
                data.Tracer.Visible = on and SniperArenaConfig.UseTracers
                if on then
                    local hrp = C.HumanoidRootPart
                    local top = (C:FindFirstChild("Head") and C.Head.Position + Vector3.new(0, 0.5, 0)) or hrp.Position + Vector3.new(0, 1.5, 0)
                    local bot = hrp.Position - Vector3.new(0, 2, 0)
                    local left = hrp.Position - Camera.CFrame.RightVector
                    local right = hrp.Position + Camera.CFrame.RightVector
                    local tS, tO = GetPositionOnScreen(top)
                    local bS, bO = GetPositionOnScreen(bot)
                    if tO and bO then
                        local h = math.max(15, math.abs(tS.Y - bS.Y))
                        local w = math.max(12, h * 0.6)
                        data.Box.Size = Vector2.new(w, h)
                        data.Box.Position = Vector2.new(tS.X - w / 2, tS.Y)
                    else
                        local d = 2000 / pos.Z
                        data.Box.Size = Vector2.new(d, d)
                        data.Box.Position = Vector2.new(pos.X - d / 2, pos.Y - d / 2)
                    end
                    data.Box.Color = (plr.Team == LocalPlayer.Team) and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 50, 50)
                    if SniperArenaConfig.UseTracers then
                        data.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                        data.Tracer.To = Vector2.new(pos.X, pos.Y)
                        data.Tracer.Color = data.Box.Color
                    end
                else
                    data.Box.Visible = false
                    data.Tracer.Visible = false
                end
            else
                data.Box.Visible = false
                data.Tracer.Visible = false
            end
        end
    else
        for _, data in pairs(ESPObjects) do
            data.Box.Visible = false
            data.Tracer.Visible = false
        end
    end

    -- AIMBOT CLÁSSICO
    if SniperArenaConfig.UseClassicAimbot and AimbotKeyDown then
        local Target = GetAimbotTarget()
        if Target and Target.Character and Target.Character:FindFirstChild("HumanoidRootPart") then
            local HRP = Target.Character.HumanoidRootPart
            local Current = Camera.CFrame
            local Goal = CFrame.new(Camera.CFrame.Position, HRP.Position)
            local New = Current:Lerp(Goal, SniperArenaConfig.Smoothness)
            Camera.CFrame = New
        end
    end

    -- SILENT AIM
    if SniperArenaConfig.UseSilentAim then
        ApplySilentAim()
    end
end)

-- ========== INPUTS ==========
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    -- BIND MODE
    if SniperArenaConfig.AimbotBindMode then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            SniperArenaConfig.AimbotKey = input.KeyCode
            BindBtn.Text = "Bind: " .. tostring(input.KeyCode.Name)
            BindBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            SniperArenaConfig.AimbotBindMode = false
        end
        return
    end

    -- AIMBOT KEY
    if input.KeyCode == SniperArenaConfig.AimbotKey then
        AimbotKeyDown = true
    end

    -- GUI TOGGLE
    if input.KeyCode == Enum.KeyCode.LeftControl then
        SniperArenaConfig.Visible = not SniperArenaConfig.Visible
        MainFrame.Visible = SniperArenaConfig.Visible
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if input.KeyCode == SniperArenaConfig.AimbotKey then
        AimbotKeyDown = false
    end
end)
