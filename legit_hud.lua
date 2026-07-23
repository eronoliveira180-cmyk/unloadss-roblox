local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Settings = {
    Enabled = true,
    ToggleKey = Enum.KeyCode.F,
    ShowAllies = false,
    ShowOnlyAlive = true,
    MaxDistance = 250,
    BindMode = false,
}

local function CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "LegitHUD"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 320, 0, 280)
    mainFrame.Position = UDim2.new(0.02, 0, 0.02, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -10, 0, 30)
    title.Position = UDim2.new(0, 5, 0, 8)
    title.BackgroundTransparency = 1
    title.Text = "Legit HUD"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(0, 140, 0, 32)
    toggleButton.Position = UDim2.new(0, 8, 0, 44)
    toggleButton.Text = "Overlay: ON"
    toggleButton.TextColor3 = Color3.new(1, 1, 1)
    toggleButton.BackgroundColor3 = Color3.fromRGB(0, 120, 255)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 13
    toggleButton.Parent = mainFrame

    local tbCorner = Instance.new("UICorner")
    tbCorner.CornerRadius = UDim.new(0, 6)
    tbCorner.Parent = toggleButton

    local bindButton = Instance.new("TextButton")
    bindButton.Size = UDim2.new(0, 140, 0, 32)
    bindButton.Position = UDim2.new(0, 156, 0, 44)
    bindButton.Text = "Bind: F"
    bindButton.TextColor3 = Color3.new(1, 1, 1)
    bindButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    bindButton.Font = Enum.Font.GothamBold
    bindButton.TextSize = 13
    bindButton.Parent = mainFrame

    local bbCorner = Instance.new("UICorner")
    bbCorner.CornerRadius = UDim.new(0, 6)
    bbCorner.Parent = bindButton

    local statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -16, 0, 24)
    statusLabel.Position = UDim2.new(0, 8, 0, 86)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Ativo | F para alternar"
    statusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 13
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.Parent = mainFrame

    local listFrame = Instance.new("Frame")
    listFrame.Size = UDim2.new(1, -16, 1, -120)
    listFrame.Position = UDim2.new(0, 8, 0, 116)
    listFrame.BackgroundTransparency = 1
    listFrame.Parent = mainFrame

    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 4)
    listLayout.Parent = listFrame

    local function UpdateButtonStates()
        toggleButton.Text = Settings.Enabled and "Overlay: ON" or "Overlay: OFF"
        toggleButton.BackgroundColor3 = Settings.Enabled and Color3.fromRGB(0, 120, 255) or Color3.fromRGB(80, 80, 80)
        bindButton.Text = "Bind: " .. tostring(Settings.ToggleKey)
    end

    toggleButton.MouseButton1Click:Connect(function()
        Settings.Enabled = not Settings.Enabled
        statusLabel.Text = Settings.Enabled and "Overlay ativado" or "Overlay desativado"
        UpdateButtonStates()
    end)

    bindButton.MouseButton1Click:Connect(function()
        Settings.BindMode = true
        statusLabel.Text = "Pressione uma tecla..."
        bindButton.Text = "Pressione..."
    end)

    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end

        if Settings.BindMode then
            if input.UserInputType == Enum.UserInputType.Keyboard then
                Settings.ToggleKey = input.KeyCode
                Settings.BindMode = false
                statusLabel.Text = "Bind definido para " .. tostring(Settings.ToggleKey)
                UpdateButtonStates()
            end
            return
        end

        if input.KeyCode == Settings.ToggleKey then
            Settings.Enabled = not Settings.Enabled
            statusLabel.Text = Settings.Enabled and "Overlay ativado" or "Overlay desativado"
            UpdateButtonStates()
        end
    end)

    local function ClearList()
        for _, child in ipairs(listFrame:GetChildren()) do
            if child:IsA("TextLabel") then
                child:Destroy()
            end
        end
    end

    local function IsTargetVisible(targetCharacter)
        if not Camera then
            return false
        end

        local localCharacter = LocalPlayer.Character
        local localHRP = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
        local targetHRP = targetCharacter and targetCharacter:FindFirstChild("HumanoidRootPart")

        if not localHRP or not targetHRP then
            return false
        end

        local origin = localHRP.Position + Vector3.new(0, 1.5, 0)
        local direction = targetHRP.Position - origin
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = { localCharacter }

        local result = Workspace:Raycast(origin, direction, raycastParams)

        if not result then
            return true
        end

        if result.Instance and result.Instance:IsDescendantOf(targetCharacter) then
            return true
        end

        return false
    end

    local function GetPlayerInfo(player)
        local character = player.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local hrp = character and character:FindFirstChild("HumanoidRootPart")

        if not character or not humanoid or not hrp then
            return nil
        end

        if Settings.ShowOnlyAlive and humanoid.Health <= 0 then
            return nil
        end

        local localHRP = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not localHRP then
            return nil
        end

        local distance = (hrp.Position - localHRP.Position).Magnitude
        if distance > Settings.MaxDistance then
            return nil
        end

        local sameTeam = LocalPlayer.Team ~= nil and player.Team ~= nil and player.Team == LocalPlayer.Team
        if not Settings.ShowAllies and sameTeam then
            return nil
        end

        return {
            Name = player.Name,
            Team = player.Team and player.Team.Name or "Nenhum",
            Health = math.floor(humanoid.Health),
            Distance = math.floor(distance),
            Visible = IsTargetVisible(character),
        }
    end

    local function RefreshList()
        if not Settings.Enabled then
            ClearList()
            return
        end

        ClearList()

        local entries = {}

        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local info = GetPlayerInfo(player)
                if info then
                    table.insert(entries, info)
                end
            end
        end

        table.sort(entries, function(a, b)
            return a.Distance < b.Distance
        end)

        for _, info in ipairs(entries) do
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -4, 0, 18)
            label.BackgroundTransparency = 1
            label.Text = string.format("%s | %s | HP:%s | Dist:%s | Vis:%s", info.Name, info.Team, info.Health, info.Distance, info.Visible and "Sim" or "Nao")
            label.TextColor3 = Color3.fromRGB(255, 255, 255)
            label.Font = Enum.Font.Gotham
            label.TextSize = 13
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = listFrame
        end
    end

    RefreshList()
    UpdateButtonStates()

    RunService.RenderStepped:Connect(function()
        RefreshList()
    end)

    Players.PlayerAdded:Connect(RefreshList)
    Players.PlayerRemoving:Connect(RefreshList)
end

CreateUI()
