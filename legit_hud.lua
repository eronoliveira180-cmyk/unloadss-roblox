local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera or Workspace:WaitForChild("CurrentCamera")

local Settings = {
    MenuVisible = true,
    MenuKey = Enum.KeyCode.Insert,
    AimbotEnabled = false,
    SilentAimEnabled = false,
    ESPEnabled = true,
    ShowAllies = false,
    ShowOnlyAlive = true,
    MaxDistance = 250,
    Smoothness = 0.18,
}

local ESPEntries = {}
local silentRestoreCFrame
local menuGui

local function GetHumanoid(character)
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function GetHumanoidRootPart(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function IsTargetVisible(targetCharacter)
    if not Camera or not targetCharacter then
        return false
    end

    local localCharacter = LocalPlayer.Character
    local localHRP = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    local targetHRP = GetHumanoidRootPart(targetCharacter)

    if not localHRP or not targetHRP then
        return false
    end

    local origin = localHRP.Position + Vector3.new(0, 1.5, 0)
    local direction = targetHRP.Position - origin
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = { localCharacter }

    local result = Workspace:Raycast(origin, direction, raycastParams)
    return not result or (result.Instance and result.Instance:IsDescendantOf(targetCharacter))
end

local function IsValidTarget(player)
    if player == LocalPlayer then
        return false
    end

    local character = player.Character
    local humanoid = GetHumanoid(character)
    local hrp = GetHumanoidRootPart(character)

    if not character or not humanoid or not hrp then
        return false
    end

    if Settings.ShowOnlyAlive and humanoid.Health <= 0 then
        return false
    end

    if not Settings.ShowAllies and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
        return false
    end

    local localCharacter = LocalPlayer.Character
    local localHRP = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localHRP then
        return false
    end

    if (hrp.Position - localHRP.Position).Magnitude > Settings.MaxDistance then
        return false
    end

    return true
end

local function GetTargetPosition(targetCharacter)
    local hrp = GetHumanoidRootPart(targetCharacter)
    if not hrp then
        return nil
    end
    return hrp.Position + Vector3.new(0, 1.5, 0)
end

local function GetBestTarget()
    local localCharacter = LocalPlayer.Character
    local localHRP = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localHRP then
        return nil
    end

    local bestPlayer
    local bestDistance = math.huge

    for _, player in ipairs(Players:GetPlayers()) do
        if IsValidTarget(player) then
            local targetHRP = GetHumanoidRootPart(player.Character)
            if targetHRP and IsTargetVisible(player.Character) then
                local distance = (targetHRP.Position - localHRP.Position).Magnitude
                if distance < bestDistance then
                    bestDistance = distance
                    bestPlayer = player
                end
            end
        end
    end

    return bestPlayer
end

local function AimCameraAt(position)
    if not Camera or not position then
        return
    end

    local origin = Camera.CFrame.Position
    local direction = position - origin
    if direction.Magnitude <= 0 then
        return
    end

    local targetCFrame = CFrame.new(origin, origin + direction.Unit)
    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, math.clamp(Settings.Smoothness, 0, 1))
end

local function HandleSilentAim()
    if not Settings.SilentAimEnabled or Settings.AimbotEnabled then
        return
    end

    local target = GetBestTarget()
    if not target then
        return
    end

    local targetPosition = GetTargetPosition(target.Character)
    if not targetPosition then
        return
    end

    silentRestoreCFrame = Camera.CFrame
    AimCameraAt(targetPosition)
end

local function CreateESP(player)
    local entry = ESPEntries[player]
    if entry then
        return entry
    end

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "ESP"
    billboard.AlwaysOnTop = true
    billboard.Size = UDim2.new(0, 180, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.Parent = player.Character or Workspace

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 0.55
    label.BackgroundColor3 = Color3.fromRGB(22, 27, 36)
    label.BorderSizePixel = 0
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 12
    label.TextStrokeTransparency = 0.8
    label.Text = player.Name
    label.Parent = billboard

    entry = { Billboard = billboard, Label = label }
    ESPEntries[player] = entry
    return entry
end

local function DestroyESP(player)
    local entry = ESPEntries[player]
    if entry then
        if entry.Billboard and entry.Billboard.Parent then
            entry.Billboard:Destroy()
        end
        ESPEntries[player] = nil
    end
end

local function UpdateESP()
    if not Settings.ESPEnabled then
        for player, _ in pairs(ESPEntries) do
            DestroyESP(player)
        end
        return
    end

    local localCharacter = LocalPlayer.Character
    local localHRP = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then
            DestroyESP(player)
        else
            local character = player.Character
            local humanoid = GetHumanoid(character)
            local hrp = GetHumanoidRootPart(character)
            local valid = character and humanoid and hrp

            if valid then
                if Settings.ShowOnlyAlive and humanoid.Health <= 0 then
                    valid = false
                end
                if not Settings.ShowAllies and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                    valid = false
                end
            end

            if valid and localHRP then
                local entry = CreateESP(player)
                entry.Billboard.Adornee = hrp
                local distance = math.floor((hrp.Position - localHRP.Position).Magnitude)
                entry.Label.Text = string.format("%s | %s | %dm", player.Name, player.Team and player.Team.Name or "NoTeam", distance)
                entry.Label.TextColor3 = player.Team == LocalPlayer.Team and Color3.fromRGB(120, 200, 255) or Color3.fromRGB(255, 255, 255)
            else
                DestroyESP(player)
            end
        end
    end
end

local function ClearListFrame(frame)
    for _, child in ipairs(frame:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end

local function UpdateButtonStates(aimbotButton, silentButton, espButton)
    aimbotButton.Text = Settings.AimbotEnabled and "Aimbot: ON" or "Aimbot: OFF"
    aimbotButton.BackgroundColor3 = Settings.AimbotEnabled and Color3.fromRGB(0, 200, 60) or Color3.fromRGB(60, 65, 82)

    silentButton.Text = Settings.SilentAimEnabled and "Silent Aim: ON" or "Silent Aim: OFF"
    silentButton.BackgroundColor3 = Settings.SilentAimEnabled and Color3.fromRGB(255, 165, 0) or Color3.fromRGB(60, 65, 82)

    espButton.Text = Settings.ESPEnabled and "ESP: ON" or "ESP: OFF"
    espButton.BackgroundColor3 = Settings.ESPEnabled and Color3.fromRGB(0, 150, 255) or Color3.fromRGB(60, 65, 82)
end

local function CreateUI()
    menuGui = Instance.new("ScreenGui")
    menuGui.Name = "LegitHUD_Menu"
    menuGui.ResetOnSpawn = false
    menuGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    menuGui.Enabled = Settings.MenuVisible

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 380, 0, 340)
    mainFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(23, 28, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = menuGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 16)
    mainCorner.Parent = mainFrame

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, 50)
    topBar.Position = UDim2.new(0, 0, 0, 0)
    topBar.BackgroundColor3 = Color3.fromRGB(32, 39, 54)
    topBar.BorderSizePixel = 0
    topBar.Parent = mainFrame

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 16)
    topCorner.Parent = topBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(0.65, 0, 1, 0)
    title.Position = UDim2.new(0, 20, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Legit HUD"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextYAlignment = Enum.TextYAlignment.Center
    title.Parent = topBar

    local shortcutLabel = Instance.new("TextLabel")
    shortcutLabel.Size = UDim2.new(0.35, -24, 1, 0)
    shortcutLabel.Position = UDim2.new(0.65, 20, 0, 0)
    shortcutLabel.BackgroundTransparency = 1
    shortcutLabel.Text = "INSERT para abrir/fechar"
    shortcutLabel.TextColor3 = Color3.fromRGB(162, 170, 188)
    shortcutLabel.Font = Enum.Font.Gotham
    shortcutLabel.TextSize = 11
    shortcutLabel.TextXAlignment = Enum.TextXAlignment.Right
    shortcutLabel.TextYAlignment = Enum.TextYAlignment.Center
    shortcutLabel.Parent = topBar

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(1, -32, 0, 20)
    infoLabel.Position = UDim2.new(0, 16, 0, 64)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "ESP, Aimbot e Silent Aim em um painel leve e limpo."
    infoLabel.TextColor3 = Color3.fromRGB(165, 173, 186)
    infoLabel.Font = Enum.Font.Gotham
    infoLabel.TextSize = 12
    infoLabel.TextXAlignment = Enum.TextXAlignment.Left
    infoLabel.Parent = mainFrame

    local aimbotButton = Instance.new("TextButton")
    aimbotButton.Size = UDim2.new(0, 110, 0, 34)
    aimbotButton.Position = UDim2.new(0, 16, 0, 98)
    aimbotButton.Text = "Aimbot: OFF"
    aimbotButton.TextColor3 = Color3.new(1, 1, 1)
    aimbotButton.BackgroundColor3 = Color3.fromRGB(60, 65, 84)
    aimbotButton.Font = Enum.Font.GothamBold
    aimbotButton.TextSize = 13
    aimbotButton.Parent = mainFrame

    local silentButton = Instance.new("TextButton")
    silentButton.Size = UDim2.new(0, 110, 0, 34)
    silentButton.Position = UDim2.new(0, 138, 0, 98)
    silentButton.Text = "Silent Aim: OFF"
    silentButton.TextColor3 = Color3.new(1, 1, 1)
    silentButton.BackgroundColor3 = Color3.fromRGB(60, 65, 84)
    silentButton.Font = Enum.Font.GothamBold
    silentButton.TextSize = 13
    silentButton.Parent = mainFrame

    local espButton = Instance.new("TextButton")
    espButton.Size = UDim2.new(0, 110, 0, 34)
    espButton.Position = UDim2.new(0, 260, 0, 98)
    espButton.Text = "ESP: ON"
    espButton.TextColor3 = Color3.new(1, 1, 1)
    espButton.BackgroundColor3 = Color3.fromRGB(60, 65, 84)
    espButton.Font = Enum.Font.GothamBold
    espButton.TextSize = 13
    espButton.Parent = mainFrame

    for _, button in ipairs({aimbotButton, silentButton, espButton}) do
        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 10)
        btnCorner.Parent = button
    end

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -32, 0, 18)
    statusLabel.Position = UDim2.new(0, 16, 0, 144)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Aimbot: OFF | Silent Aim: OFF | ESP: ON"
    statusLabel.TextColor3 = Color3.fromRGB(165, 173, 186)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 12
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, -32, 1, -182)
    listFrame.Position = UDim2.new(0, 16, 0, 168)
    listFrame.BackgroundTransparency = 1
    listFrame.Parent = mainFrame

    local listBackground = Instance.new("Frame")
    listBackground.Size = UDim2.new(1, 0, 1, 0)
    listBackground.BackgroundColor3 = Color3.fromRGB(11, 16, 24)
    listBackground.BorderSizePixel = 0
    listBackground.BackgroundTransparency = 0.08
    listBackground.Parent = listFrame

    local listCorner = Instance.new("UICorner")
    listCorner.CornerRadius = UDim.new(0, 12)
    listCorner.Parent = listBackground

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 6)
    listLayout.Parent = listFrame

    local function RefreshPlayerList()
        ClearListFrame(listFrame)

        local bestTarget = GetBestTarget()
        local targetName = bestTarget and bestTarget.Name or ""
        local entries = {}

        local localCharacter = LocalPlayer.Character
        local localHRP = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        if not localHRP then
            return
        end

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local character = player.Character
                local humanoid = GetHumanoid(character)
                local hrp = GetHumanoidRootPart(character)
                if character and humanoid and hrp then
                    if Settings.ShowOnlyAlive and humanoid.Health <= 0 then
                        -- skip dead targets
                    elseif not Settings.ShowAllies and LocalPlayer.Team and player.Team and LocalPlayer.Team == player.Team then
                        -- skip teammates
                    else
                        local distance = math.floor((hrp.Position - localHRP.Position).Magnitude)
                        if distance <= Settings.MaxDistance then
                            table.insert(entries, {
                                Name = player.Name,
                                Distance = distance,
                                Health = math.floor(humanoid.Health),
                                Visible = IsTargetVisible(character),
                                Target = player.Name == targetName,
                            })
                        end
                    end
                end
            end
        end

        table.sort(entries, function(a, b)
            return a.Distance < b.Distance
        end)

        for _, info in ipairs(entries) do
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -14, 0, 20)
            label.BackgroundTransparency = 1
            label.Text = string.format("%s %s | HP:%s | Dist:%s | Vis:%s",
                info.Target and ">>" or "  ", info.Name, info.Health, info.Distance, info.Visible and "Sim" or "Nao")
            label.TextColor3 = info.Target and Color3.fromRGB(0, 255, 138) or Color3.fromRGB(220, 220, 220)
            label.Font = Enum.Font.Gotham
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = listFrame
        end
    end

    local function UpdateUI()
        UpdateButtonStates(aimbotButton, silentButton, espButton)
        statusLabel.Text = string.format("Aimbot: %s | Silent Aim: %s | ESP: %s",
            Settings.AimbotEnabled and "ON" or "OFF",
            Settings.SilentAimEnabled and "ON" or "OFF",
            Settings.ESPEnabled and "ON" or "OFF")
    end

    aimbotButton.MouseButton1Click:Connect(function()
        Settings.AimbotEnabled = not Settings.AimbotEnabled
        if Settings.AimbotEnabled then
            Settings.SilentAimEnabled = false
        end
        UpdateUI()
    end)

    silentButton.MouseButton1Click:Connect(function()
        Settings.SilentAimEnabled = not Settings.SilentAimEnabled
        if Settings.SilentAimEnabled then
            Settings.AimbotEnabled = false
        end
        UpdateUI()
    end)

    espButton.MouseButton1Click:Connect(function()
        Settings.ESPEnabled = not Settings.ESPEnabled
        UpdateUI()
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then
            return
        end

        if input.KeyCode == Settings.MenuKey and input.UserInputType == Enum.UserInputType.Keyboard then
            Settings.MenuVisible = not Settings.MenuVisible
            menuGui.Enabled = Settings.MenuVisible
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseButton1 and Settings.SilentAimEnabled then
            HandleSilentAim()
        end
    end)

    RunService.RenderStepped:Connect(function()
        if Settings.AimbotEnabled then
            local target = GetBestTarget()
            if target then
                local targetPosition = GetTargetPosition(target.Character)
                if targetPosition then
                    AimCameraAt(targetPosition)
                end
            end
        end

        if silentRestoreCFrame then
            Camera.CFrame = silentRestoreCFrame
            silentRestoreCFrame = nil
        end

        UpdateESP()
        RefreshPlayerList()
        UpdateUI()
    end)

    Players.PlayerAdded:Connect(function()
        UpdateESP()
    end)

    Players.PlayerRemoving:Connect(function(player)
        DestroyESP(player)
    end)
end

CreateUI()
