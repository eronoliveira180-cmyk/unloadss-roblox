-- // ========== INICIALIZAÇÃO RÁPIDA ==========
if not game:IsLoaded() then game.Loaded:Wait() end
getgenv().SniperArena = {
    Silent = {Enabled = true, Method = "Raycast", Part = "Head", Prediction = 0.15, FOV = 160, Chance = 100, TeamCheck = false},
    Aimbot = {Enabled = true, Key = Enum.KeyCode.E, Smooth = 0.12, FOV = 140},
    Visual = {Skeleton = true, Tracer = false, FOVCircle = true}
}

-- // ========== SERVIÇOS ==========
local Players, RS, UIS = game:GetService("Players"), game:GetService("RunService"), game:GetService("UserInputService")
local Camera, LP, Mouse = workspace.CurrentCamera, Players.LocalPlayer, Players.LocalPlayer:GetMouse()
local WorldToViewport = Camera.WorldToViewportPoint
local Random = Random.new
local function Chance(p) return math.random() <= (p/100) end
local function IsEnemy(p) return p~=LP and (not SniperArena.Silent.TeamCheck or not p.Team or p.Team~=LP.Team) end

-- // ========== MOTOR SILENT AIM (PRIORITY 1) ==========
local oldNamecall = hookmetamethod(game, "__namecall", function(...)
    local Args, Method = {...}, getnamecallmethod()
    local Self = Args[1]
    if not SniperArena.Silent.Enabled or Self~=workspace or checkcaller() or not Chance(SniperArena.Silent.Chance) then return oldNamecall(...) end
    
    local function GetTarget()
        local Best, BestDist
        for _, p in pairs(Players:GetPlayers()) do
            if IsEnemy(p) and p.Character then
                local Part = p.Character:FindFirstChild(SniperArena.Silent.Part) or p.Character:FindFirstChild("Head")
                if Part then
                    local Pos, On = WorldToViewport(Camera, Part.Position)
                    if On then
                        local Dist = (Vector2.new(Pos.X,Pos.Y)-UIS:GetMouseLocation()).Magnitude
                        if Dist <= SniperArena.Silent.FOV and (not BestDist or Dist<BestDist) then
                            Best, BestDist = Part, Dist
                        end
                    end
                end
            end
        end
        return Best
    end
    
    local Target = GetTarget()
    if not Target then return oldNamecall(...) end
    local CF = Target.CFrame
    if SniperArena.Silent.Prediction>0 and Target.Parent and Target.Parent:FindFirstChild("HumanoidRootPart") then
        CF = CF + Target.Parent.HumanoidRootPart.Velocity * SniperArena.Silent.Prediction
    end
    
    if Method:find("Raycast") and Args[3] and Args[4] then
        Args[2], Args[3] = CF.Position-Camera.CFrame.Position, Target
        return oldNamecall(unpack(Args))
    elseif Method:find("FindPartOnRay") then
        Args[2] = Ray.new(Camera.CFrame.Position, (CF.Position-Camera.CFrame.Position).Unit*1000)
        return oldNamecall(unpack(Args))
    end
    return oldNamecall(...)
end)

-- // ========== AIMBOT FLUIDO (PRIORITY 2) ==========
local AimTarget, AimActive = nil, false
UIS.InputBegan:Connect(function(i) if i.KeyCode==SniperArena.Aimbot.Key then AimActive=true end end)
UIS.InputEnded:Connect(function(i) if i.KeyCode==SniperArena.Aimbot.Key then AimActive=false end end)

RS.RenderStepped:Connect(function(dt)
    -- AimBot Core
    if SniperArena.Aimbot.Enabled and AimActive then
        local Best, BestDist
        for _, p in pairs(Players:GetPlayers()) do
            if IsEnemy(p) and p.Character and p.Character:FindFirstChild("Head") then
                local Pos, On = WorldToViewport(Camera, p.Character.Head.Position)
                if On then
                    local Dist = (UIS:GetMouseLocation()-Vector2.new(Pos.X,Pos.Y)).Magnitude
                    if Dist <= SniperArena.Aimbot.FOV and (not BestDist or Dist<BestDist) then
                        Best, BestDist = p.Character.Head.Position, Dist
                    end
                end
            end
        end
        if Best then
            local Goal = CFrame.new(Camera.CFrame.Position, Best)
            Camera.CFrame = Camera.CFrame:Lerp(Goal, SniperArena.Aimbot.Smooth)
        end
    end
    
    -- Visuals
    if SniperArena.Visual.FOVCircle then
        if not getgenv().FOV_DRAW then
            getgenv().FOV_DRAW = Drawing.new("Circle")
            getgenv().FOV_DRAW.Thickness, getgenv().FOV_DRAW.Color = 1.5, Color3.fromRGB(255,50,50)
        end
        getgenv().FOV_DRAW.Radius = math.max(SniperArena.Aimbot.FOV, SniperArena.Silent.FOV)
        getgenv().FOV_DRAW.Position = UIS:GetMouseLocation()
        getgenv().FOV_DRAW.Visible = true
    end
end)

-- // ========== SKELETON ESP (SUBSTITUI BOX) ==========
local Bones = {
    ["Head"]={"Neck"}, ["Neck"]={"Torso"}, ["Torso"]={"Left Shoulder","Right Shoulder","Left Hip","Right Hip"},
    ["Left Shoulder"]={"Left Elbow"},["Left Elbow"]={"Left Wrist"},["Left Wrist"]={"Left Hand"},
    ["Right Shoulder"]={"Right Elbow"},["Right Elbow"]={"Right Wrist"},["Right Wrist"]={"Right Hand"},
    ["Left Hip"]={"Left Knee"},["Left Knee"]={"Left Ankle"},["Left Ankle"]={"Left Foot"},
    ["Right Hip"]={"Right Knee"},["Right Knee"]={"Right Ankle"},["Right Ankle"]={"Right Foot"}
}
local Parts = {"Head","Neck","Torso","Left Shoulder","Right Shoulder","Left Hip","Right Hip","Left Elbow","Right Elbow","Left Knee","Right Knee","Left Wrist","Right Wrist","Left Ankle","Right Ankle","Left Hand","Right Hand","Left Foot","Right Foot"}

local Skeletons = {}
local function CreateSkeleton(plr)
    if Skeletons[plr] then return end
    Skeletons[plr] = {}
    for _, bp in pairs(Parts) do
        Skeletons[plr][bp] = Drawing.new("Line")
        Skeletons[plr][bp].Thickness = 1.2
        Skeletons[plr][bp].Color = plr.Team==LP.Team and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,50,50)
        Skeletons[plr][bp].Transparency = 0.3
    end
end

local function UpdateSkeleton(plr, char)
    if not Skeletons[plr] then return end
    local Humanoid = char:FindFirstChild("Humanoid")
    if not Humanoid or Humanoid.Health<=0 then
        for _, line in pairs(Skeletons[plr]) do line.Visible=false end
        return
    end
    
    for bp, line in pairs(Skeletons[plr]) do
        local Part = char:FindFirstChild(bp) or (bp=="Neck" and char:FindFirstChild("Head"))
        local Parent = char:FindFirstChild(Bones[bp] and Bones[bp][1] or "")
        if Part and Parent then
            local sp1, on1 = WorldToViewport(Camera, Part.Position)
            local sp2, on2 = WorldToViewport(Camera, Parent.Position)
            if on1 and on2 then
                line.Visible = SniperArena.Visual.Skeleton
                line.From = sp1
                line.To = sp2
            else
                line.Visible = false
            end
        else
            line.Visible = false
        end
    end
end

Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function(c) CreateSkeleton(p) end) end)
for _, p in pairs(Players:GetPlayers()) do if p~=LP then CreateSkeleton(p) end end

RS.RenderStepped:Connect(function()
    for p, _ in pairs(Skeletons) do
        if p.Character then UpdateSkeleton(p, p.Character) end
    end
    if SniperArena.Visual.Tracer then
        -- (Opcional: Adicione traços aqui se necessário)
    end
end)

-- // ========== CONTROLES ==========
print("SniperArena Injectado | Silent:",SniperArena.Silent.Enabled,"Aimbot:",SniperArena.Aimbot.Enabled)
