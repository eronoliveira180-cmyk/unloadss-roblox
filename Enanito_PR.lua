--// Servicios
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Variables de Control
local Settings = {
    ESP = false,
    Tracers = false,
    Aimbot = false,
    FOVSize = 100,
    Smoothness = 0.18,
    AimbotBindKey = Enum.KeyCode.E,
    AimbotBindMode = false,
    AimbotKeyDown = false,
    AimbotTarget = nil,
    Visible = true
}

local ESPData = {}

--// Lógica de Colores y Equipos Corregida
local function GetPlayerColor(player)
    local char = player.Character
    local backpack = player:FindFirstChild("Backpack")

    -- 1. Detección específica para MM2
    if char or backpack then
        local hasKnife = (char and char:FindFirstChild("Knife")) or (backpack and backpack:FindFirstChild("Knife"))
        local hasGun = (char and char:FindFirstChild("Gun")) or (backpack and backpack:FindFirstChild("Gun"))
        
        if hasKnife then return Color3.fromRGB(255, 0, 0) end -- Rojo: Asesino
        if hasGun then return Color3.fromRGB(0, 0, 255) end   -- Azul: Sheriff
    end

    -- 2. Detección de Equipos (Juegos con equipos oficiales)
    if player.Team ~= nil then
        if player.Team == LocalPlayer.Team then
            return Color3.fromRGB(0, 255, 0) -- Verde: Aliado
        else
            return player.TeamColor.Color    -- Color del equipo enemigo
        end
    end

    -- 3. Default: Si no hay equipos ni roles especiales
    return Color3.fromRGB(0, 255, 0) -- Verde (Inocente/Neutral)
end

--// Filtro de Aimbot: No apuntar a aliados
local function IsEnemy(player)
    if player.Team ~= nil and LocalPlayer.Team ~= nil then
        return player.Team ~= LocalPlayer.Team
    end
    -- En juegos sin equipos (como MM2), todos son objetivos potenciales
    return true 
end

--// Funciones ESP
local function CreateESP(player)
    local data = {
        Box = Drawing.new("Square"),
        Tracer = Drawing.new("Line")
    }
    data.Box.Thickness = 1.5
    data.Box.Filled = false
    data.Tracer.Thickness = 1
    ESPData[player] = data
end

local function RemoveESP(player)
    if ESPData[player] then
        ESPData[player].Box:Remove()
        ESPData[player].Tracer:Remove()
        ESPData[player] = nil
    end
end

for _, p in pairs(Players:GetPlayers()) do if p ~= LocalPlayer then CreateESP(p) end end
Players.PlayerAdded:Connect(CreateESP)
Players.PlayerRemoving:Connect(RemoveESP)

--// Interfaz GUI: Vortex-Aim (Colapsable)
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local MainFrame = Instance.new("Frame", ScreenGui)
local UICorner = Instance.new("UICorner", MainFrame)
local Title = Instance.new("TextButton", MainFrame) 
local ControlFrame = Instance.new("Frame", MainFrame) 
local UIListLayout = Instance.new("UIListLayout", ControlFrame)

MainFrame.Size = UDim2.new(0, 200, 0, 260)
MainFrame.Position = UDim2.new(0.5, -100, 0.5, -130)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.Active = true
MainFrame.Draggable = true
UICorner.CornerRadius = UDim.new(0, 8)

Title.Size = UDim2.new(1, 0, 0, 40)
Title.BackgroundTransparency = 1
Title.Text = "Vortex-Aim [▼]"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18

ControlFrame.Name = "Controls"
ControlFrame.Size = UDim2.new(1, 0, 1, -40)
ControlFrame.Position = UDim2.new(0, 0, 0, 40)
ControlFrame.BackgroundTransparency = 1
ControlFrame.ClipsDescendants = true 
UIListLayout.Padding = UDim.new(0, 7)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

-- Animación de colapsar controles hacia arriba
local expanded = true
Title.MouseButton1Click:Connect(function()
    expanded = not expanded
    if expanded then
        MainFrame:TweenSize(UDim2.new(0, 200, 0, 260), "Out", "Quad", 0.3, true)
        ControlFrame.Visible = true
        Title.Text = "Vortex-Aim [▼]"
    else
        MainFrame:TweenSize(UDim2.new(0, 200, 0, 40), "Out", "Quad", 0.3, true)
        task.wait(0.3)
        if not expanded then ControlFrame.Visible = false end
        Title.Text = "Vortex-Aim [▲]"
    end
end)

local function CreateButton(settingKey, textOn, textOff, colorOn)
    local btn = Instance.new("TextButton", ControlFrame)
    btn.Size = UDim2.new(0, 180, 0, 35)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = textOff
    btn.TextColor3 = Color3.new(1, 1, 1)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    Instance.new("UICorner", btn)
    
    btn.MouseButton1Click:Connect(function()
        Settings[settingKey] = not Settings[settingKey]
        btn.Text = Settings[settingKey] and textOn or textOff
        btn.BackgroundColor3 = Settings[settingKey] and colorOn or Color3.fromRGB(45, 45, 45)
    end)
end

CreateButton("ESP", "ESP: ON", "ESP: OFF", Color3.fromRGB(0, 120, 255))
CreateButton("Tracers", "Tracers: ON", "Tracers: OFF", Color3.fromRGB(0, 120, 255))
CreateButton("Aimbot", "Aimbot: ON", "Aimbot: OFF", Color3.fromRGB(255, 0, 0))

local AimbotBindButton = Instance.new("TextButton", ControlFrame)
AimbotBindButton.Size = UDim2.new(0, 180, 0, 35)
AimbotBindButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
AimbotBindButton.Text = "Bind Key: " .. Settings.AimbotBindKey.Name
AimbotBindButton.TextColor3 = Color3.new(1, 1, 1)
AimbotBindButton.Font = Enum.Font.GothamBold
AimbotBindButton.TextSize = 13
Instance.new("UICorner", AimbotBindButton)
AimbotBindButton.MouseButton1Click:Connect(function()
    Settings.AimbotBindMode = true
    AimbotBindButton.Text = "Press key..."
    AimbotBindButton.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
end)

local FOVInput = Instance.new("TextBox", ControlFrame)
FOVInput.Size = UDim2.new(0, 180, 0, 30)
FOVInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
FOVInput.PlaceholderText = "FOV Size: " .. Settings.FOVSize
FOVInput.Text = ""
FOVInput.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", FOVInput)
FOVInput.FocusLost:Connect(function()
    Settings.FOVSize = tonumber(FOVInput.Text) or Settings.FOVSize
    FOVInput.PlaceholderText = "FOV Size: " .. Settings.FOVSize
    FOVInput.Text = ""
end)

local SmoothInput = Instance.new("TextBox", ControlFrame)
SmoothInput.Size = UDim2.new(0, 180, 0, 30)
SmoothInput.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
SmoothInput.PlaceholderText = "Smoothness: " .. Settings.Smoothness
SmoothInput.Text = ""
SmoothInput.TextColor3 = Color3.new(1, 1, 1)
Instance.new("UICorner", SmoothInput)
SmoothInput.FocusLost:Connect(function()
    local value = tonumber(SmoothInput.Text)
    if value then
        Settings.Smoothness = math.clamp(value, 0, 1)
    end
    SmoothInput.PlaceholderText = "Smoothness: " .. string.format("%.2f", Settings.Smoothness)
    SmoothInput.Text = ""
end)

--// BUCLE DE RENDERIZADO
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Color = Color3.new(1, 1, 1)
FOVCircle.Transparency = 0.5

RunService.RenderStepped:Connect(function()
    FOVCircle.Radius = Settings.FOVSize
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    FOVCircle.Visible = Settings.Aimbot 

    for player, drawings in pairs(ESPData) do
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
            local pos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen then
                local playerColor = GetPlayerColor(player) -- Detección dinámica de color
                
                drawings.Box.Visible = Settings.ESP
                if Settings.ESP then
                    local head = char:FindFirstChild("Head")
                    local topPosition = head and head.Position + Vector3.new(0, 0.4, 0) or hrp.Position + Vector3.new(0, 1.5, 0)
                    local bottomPosition = hrp.Position - Vector3.new(0, 2, 0)
                    local leftPosition = hrp.Position - Camera.CFrame.RightVector * 1.2
                    local rightPosition = hrp.Position + Camera.CFrame.RightVector * 1.2

                    local topPos, topOnScreen = Camera:WorldToViewportPoint(topPosition)
                    local bottomPos, bottomOnScreen = Camera:WorldToViewportPoint(bottomPosition)
                    local leftPos, leftOnScreen = Camera:WorldToViewportPoint(leftPosition)
                    local rightPos, rightOnScreen = Camera:WorldToViewportPoint(rightPosition)

                    if topOnScreen and bottomOnScreen and leftOnScreen and rightOnScreen then
                        local height = math.max(20, math.abs(topPos.Y - bottomPos.Y))
                        local width = math.max(15, math.abs(leftPos.X - rightPos.X))
                        drawings.Box.Size = Vector2.new(width, height)
                        drawings.Box.Position = Vector2.new((leftPos.X + rightPos.X) / 2 - width / 2, topPos.Y)
                    else
                        local sizeX, sizeY = 2200 / pos.Z, 3200 / pos.Z
                        drawings.Box.Size = Vector2.new(sizeX, sizeY)
                        drawings.Box.Position = Vector2.new(pos.X - sizeX / 2, pos.Y - sizeY / 2)
                    end

                    drawings.Box.Color = playerColor
                end
                
                drawings.Tracer.Visible = Settings.Tracers
                if Settings.Tracers then
                    drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                    drawings.Tracer.To = Vector2.new(pos.X, pos.Y)
                    drawings.Tracer.Color = playerColor
                end
            else drawings.Box.Visible, drawings.Tracer.Visible = false, false end
        else drawings.Box.Visible, drawings.Tracer.Visible = false, false end
    end

    if Settings.Aimbot and Settings.AimbotKeyDown then
        local function isValidTarget(player)
            if player == LocalPlayer or not IsEnemy(player) then return false end
            local char = player.Character
            local head = char and char:FindFirstChild("Head")
            local hum = char and char:FindFirstChild("Humanoid")
            return head and hum and hum.Health > 0
        end

        local function isInFOV(player)
            local pos, onScreen = Camera:WorldToViewportPoint(player.Character.Head.Position)
            if not onScreen then return false end
            local mag = (Vector2.new(pos.X, pos.Y) - FOVCircle.Position).Magnitude
            return mag <= Settings.FOVSize
        end

        local target = Settings.AimbotTarget
        if target and not isValidTarget(target) then
            target = nil
        end

        if not target then
            local shortestDistance = Settings.FOVSize
            for _, player in pairs(Players:GetPlayers()) do
                if isValidTarget(player) and isInFOV(player) then
                    local pos, _ = Camera:WorldToViewportPoint(player.Character.Head.Position)
                    local mag = (Vector2.new(pos.X, pos.Y) - FOVCircle.Position).Magnitude
                    if mag < shortestDistance then
                        target = player
                        shortestDistance = mag
                    end
                end
            end
        end

        Settings.AimbotTarget = target
        if target and target.Character and target.Character:FindFirstChild("Head") then
            local targetHead = target.Character.Head.Position
            local camCFrame = Camera.CFrame
            local desiredDirection = (targetHead - camCFrame.Position).Unit
            local smoothedDirection = camCFrame.LookVector:Lerp(desiredDirection, Settings.Smoothness)
            Camera.CFrame = CFrame.new(camCFrame.Position, camCFrame.Position + smoothedDirection)
        end
    else
        Settings.AimbotTarget = nil
    end
end)

UserInputService.InputBegan:Connect(function(input, processed)
    -- Allow bind capture even if the game already processed the input,
    -- but ignore when a text box is focused.
    if UserInputService:GetFocusedTextBox() then return end

    if Settings.AimbotBindMode and input.UserInputType == Enum.UserInputType.Keyboard then
        Settings.AimbotBindMode = false
        Settings.AimbotBindKey = input.KeyCode
        AimbotBindButton.Text = "Bind Key: " .. input.KeyCode.Name
        AimbotBindButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Settings.AimbotBindKey then
        Settings.AimbotKeyDown = true
    end

    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Enum.KeyCode.LeftControl then
        Settings.Visible = not Settings.Visible
        MainFrame.Visible = Settings.Visible
    end
end)

UserInputService.InputEnded:Connect(function(input, processed)
    if UserInputService:GetFocusedTextBox() then return end
    if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == Settings.AimbotBindKey then
        Settings.AimbotKeyDown = false
    end
end)
