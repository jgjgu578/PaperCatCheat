--[[
    ========================================================================================
                                👑 PAPER CAT 👑
    ========================================================================================
    [!] VERSION: 2.1 (ENGLISH + CLEAN)
    [!] FEATURES: Anti-Kick System, FPS Booster, Memory Manager, World Controls
    ========================================================================================
]]

-- // 0. BYPASS SYSTEM (ANTI-KICK) //
local function SetupBypass()
    local success, result = pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            local old_namecall = mt.__namecall
            local old_index = mt.__index
            setreadonly(mt, false)
            
            -- Block kicks
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                if method == "Kick" then
                    return warn("[BYPASS] Kick blocked!")
                end
                return old_namecall(self, ...)
            end)
            
            -- Hide our objects
            mt.__index = newcclosure(function(self, key)
                if key == "Parent" and typeof(self) == "Instance" then
                    if self.Name:find("ULTRA_") or self.Name == "Rayfield" then
                        return nil
                    end
                end
                return old_index(self, key)
            end)
            
            setreadonly(mt, true)
            return true
        end
        return false
    end)
    
    if not success then
        warn("Bypass not available, continuing without it")
    end
end

SetupBypass()

-- // LOAD RAYFIELD //
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local LP = Players.LocalPlayer

-- // 1. CONFIGURATION //
local Config = {
    MasterSwitch = false,
    
    Students = {
        Enabled = true,
        ShowNames = true,
        ShowDistance = true,
        ShowHealth = true,
        FillColor = Color3.fromRGB(0, 255, 120),
        OutlineColor = Color3.fromRGB(255, 255, 255),
        FillAlpha = 0.5,
        OutlineAlpha = 0,
        TextSize = 14
    },
    
    Teachers = {
        Enabled = true,
        ShowNames = true,
        ShowDistance = true,
        ShowHealth = true,
        FillColor = Color3.fromRGB(255, 45, 45),
        OutlineColor = Color3.fromRGB(255, 0, 0),
        FillAlpha = 0.5,
        OutlineAlpha = 0,
        TextSize = 16
    },
    
    Movement = {
        Speed = 16,
        LerpSmoothness = 0.15,
        AntiKickEnabled = true,
        NoClip = false,
        JumpPower = {Enabled = false, Value = 50},
        Fly = false
    },
    
    World = {
        FullBright = false,
        NoFog = false,
        RemoveDecals = false,
        RemoveParticles = false,
        NoShadows = false
    },
    
    Performance = {
        FPSBoost = false,
        LowGraphics = false
    }
}

-- Save original world settings
local Backup = {
    Ambient = Lighting.Ambient,
    Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    QualityLevel = 3
}

-- // 2. MEMORY MANAGER //
local Cache = {
    Connections = {},
    RenderObjects = {},
    RenderQueue = {},
    LastUpdate = 0
}

local function ClearESP(char)
    if not char then return end
    for _, v in pairs(char:GetChildren()) do
        if v.Name:find("ULTRA_") then
            v:Destroy()
        end
    end
    local head = char:FindFirstChild("Head")
    if head then
        local bb = head:FindFirstChild("ULTRA_BILLBOARD")
        if bb then bb:Destroy() end
    end
end

local function DisableAll()
    Config.MasterSwitch = false
    for _, player in pairs(Players:GetPlayers()) do
        ClearESP(player.Character)
    end
end

-- Clean old connections
for _, connection in pairs(Cache.Connections) do
    pcall(function() connection:Disconnect() end)
end

-- // 3. TARGET ANALYZER //
local function AnalyzeTarget(player)
    if not player or not player.Character then return nil end
    
    local isTeacher = false
    
    -- Check by team
    if player.Team then
        local tName = string.lower(player.Team.Name)
        if string.find(tName, "teacher") or string.find(tName, "killer") or string.find(tName, "bad") then
            isTeacher = true
        end
    end
    
    -- Check by name
    local charName = string.lower(player.DisplayName)
    local teacherNames = {"circle", "alice", "bloomie", "teacher", "miss", "kraken", "zaytseva", "petrova", "angel"}
    for _, name in ipairs(teacherNames) do
        if string.find(charName, name) then
            isTeacher = true
            break
        end
    end
    
    -- Check by part count
    if player.Character then
        local partCount = 0
        for _, child in pairs(player.Character:GetDescendants()) do
            if child:IsA("BasePart") then
                partCount = partCount + 1
            end
        end
        if partCount > 30 then
            isTeacher = true
        end
    end
    
    return isTeacher
end

-- // 4. RENDER ENGINE //
local function DrawESP(player)
    if not Config.MasterSwitch or player == LP then return end
    
    local char = player.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") or not char:FindFirstChild("Humanoid") then return end

    local isTeacher = AnalyzeTarget(player)
    
    if (isTeacher and not Config.Teachers.Enabled) or (not isTeacher and not Config.Students.Enabled) then
        ClearESP(char)
        return
    end

    local cfg = isTeacher and Config.Teachers or Config.Students

    -- Highlight
    local hl = char:FindFirstChild("ULTRA_HIGHLIGHT")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "ULTRA_HIGHLIGHT"
        hl.Parent = char
    end
    hl.FillColor = cfg.FillColor
    hl.OutlineColor = cfg.OutlineColor
    hl.FillTransparency = cfg.FillAlpha
    hl.OutlineTransparency = cfg.OutlineAlpha
    hl.Enabled = true

    -- Info panels
    local head = char:FindFirstChild("Head")
    if head then
        local showPanel = cfg.ShowNames or cfg.ShowHealth or cfg.ShowDistance
        
        if showPanel then
            local bb = head:FindFirstChild("ULTRA_BILLBOARD")
            if not bb then
                bb = Instance.new("BillboardGui")
                bb.Name = "ULTRA_BILLBOARD"
                bb.Parent = head
                bb.Size = UDim2.new(0, 200, 0, 50)
                bb.ExtentsOffset = Vector3.new(0, 3, 0)
                bb.AlwaysOnTop = true

                local txt = Instance.new("TextLabel")
                txt.Name = "InfoLabel"
                txt.Parent = bb
                txt.Size = UDim2.new(1, 0, 1, 0)
                txt.BackgroundTransparency = 1
                txt.Font = Enum.Font.GothamBold
                txt.TextStrokeTransparency = 0.2
                txt.TextWrapped = true
            end
            
            local txt = bb.InfoLabel
            txt.TextColor3 = cfg.FillColor
            txt.TextSize = cfg.TextSize
            
            local finalText = ""
            
            if cfg.ShowNames then
                finalText = finalText .. (isTeacher and "🔴 " or "🟢 ") .. player.DisplayName .. "\n"
            end
            
            if cfg.ShowHealth then
                local hp = math.floor(char.Humanoid.Health)
                local maxHp = math.floor(char.Humanoid.MaxHealth)
                finalText = finalText .. "❤️ " .. hp .. "/" .. maxHp .. "\n"
            end
            
            if cfg.ShowDistance and LP.Character and LP.Character:FindFirstChild("HumanoidRootPart") then
                local dist = math.floor((LP.Character.HumanoidRootPart.Position - char.HumanoidRootPart.Position).Magnitude)
                finalText = finalText .. "📏 " .. dist .. "m"
            end
            
            txt.Text = finalText
            bb.Enabled = true
        else
            local bb = head:FindFirstChild("ULTRA_BILLBOARD")
            if bb then
                bb:Destroy()
            end
        end
    end
end

-- // 5. FPS BOOSTER //
local function ApplyFPSBoost(enabled)
    if enabled then
        Lighting.GlobalShadows = false
    else
        Lighting.GlobalShadows = Backup.GlobalShadows
    end
end

local function ApplyLowGraphics(enabled)
    if enabled then
        settings().Rendering.QualityLevel = 1
    else
        settings().Rendering.QualityLevel = Backup.QualityLevel
    end
end

-- // 6. INTERFACE //
local Window = Rayfield:CreateWindow({
    Name = "👑 PAPER CAT",
    LoadingTitle = "Loading modules...",
    LoadingSubtitle = "Version 2.1",
    Theme = "DarkBlue",
    ConfigurationSaving = {Enabled = true, FolderName = "PaperCat"}
})

-- Tabs
local Tab_Main = Window:CreateTab("⚙️ Main")
local Tab_Students = Window:CreateTab("🟢 Students")
local Tab_Teachers = Window:CreateTab("🔴 Teachers")
local Tab_Move = Window:CreateTab("🚀 Movement")
local Tab_World = Window:CreateTab("🌍 World")
local Tab_Perf = Window:CreateTab("⚡ Performance")

-- ===== MAIN =====
Tab_Main:CreateSection("Global Control")
Tab_Main:CreateToggle({
    Name = "Master ESP Switch",
    CurrentValue = false,
    Callback = function(v) Config.MasterSwitch = v end
})

Tab_Main:CreateButton({
    Name = "🔄 Disable All",
    Callback = function()
        DisableAll()
        Rayfield:Notify({Title = "Reset", Content = "All functions disabled", Duration = 2})
    end
})

-- ===== STUDENTS =====
Tab_Students:CreateSection("Student Visibility")
Tab_Students:CreateToggle({Name = "Show Students", CurrentValue = true, Callback = function(v) Config.Students.Enabled = v end})
Tab_Students:CreateToggle({Name = "Show Names", CurrentValue = true, Callback = function(v) Config.Students.ShowNames = v end})
Tab_Students:CreateToggle({Name = "Show Health", CurrentValue = true, Callback = function(v) Config.Students.ShowHealth = v end})
Tab_Students:CreateToggle({Name = "Show Distance", CurrentValue = true, Callback = function(v) Config.Students.ShowDistance = v end})

Tab_Students:CreateSection("Colors & Transparency")
Tab_Students:CreateColorPicker({Name = "Fill Color", Color = Config.Students.FillColor, Callback = function(v) Config.Students.FillColor = v end})
Tab_Students:CreateSlider({Name = "Fill Transparency", Range = {0, 1}, Increment = 0.05, CurrentValue = 0.5, Callback = function(v) Config.Students.FillAlpha = v end})
Tab_Students:CreateColorPicker({Name = "Outline Color", Color = Config.Students.OutlineColor, Callback = function(v) Config.Students.OutlineColor = v end})
Tab_Students:CreateSlider({Name = "Outline Transparency", Range = {0, 1}, Increment = 0.05, CurrentValue = 0, Callback = function(v) Config.Students.OutlineAlpha = v end})

-- ===== TEACHERS =====
Tab_Teachers:CreateSection("Teacher Visibility")
Tab_Teachers:CreateToggle({Name = "Show Teachers", CurrentValue = true, Callback = function(v) Config.Teachers.Enabled = v end})
Tab_Teachers:CreateToggle({Name = "Show Names", CurrentValue = true, Callback = function(v) Config.Teachers.ShowNames = v end})
Tab_Teachers:CreateToggle({Name = "Show Health", CurrentValue = true, Callback = function(v) Config.Teachers.ShowHealth = v end})
Tab_Teachers:CreateToggle({Name = "Show Distance", CurrentValue = true, Callback = function(v) Config.Teachers.ShowDistance = v end})

Tab_Teachers:CreateSection("Colors & Transparency")
Tab_Teachers:CreateColorPicker({Name = "Fill Color", Color = Config.Teachers.FillColor, Callback = function(v) Config.Teachers.FillColor = v end})
Tab_Teachers:CreateSlider({Name = "Fill Transparency", Range = {0, 1}, Increment = 0.05, CurrentValue = 0.5, Callback = function(v) Config.Teachers.FillAlpha = v end})
Tab_Teachers:CreateColorPicker({Name = "Outline Color", Color = Config.Teachers.OutlineColor, Callback = function(v) Config.Teachers.OutlineColor = v end})
Tab_Teachers:CreateSlider({Name = "Outline Transparency", Range = {0, 1}, Increment = 0.05, CurrentValue = 0, Callback = function(v) Config.Teachers.OutlineAlpha = v end})

-- ===== MOVEMENT =====
Tab_Move:CreateSection("Bypass System")
Tab_Move:CreateToggle({Name = "Anti-Kick", CurrentValue = true, Callback = function(v) Config.Movement.AntiKickEnabled = v end})
Tab_Move:CreateSlider({Name = "Target Speed", Range = {16, 120}, Increment = 1, CurrentValue = 16, Callback = function(v) Config.Movement.Speed = v end})
Tab_Move:CreateSlider({Name = "Smoothness", Range = {0.05, 0.5}, Increment = 0.01, CurrentValue = 0.15, Callback = function(v) Config.Movement.LerpSmoothness = v end})

Tab_Move:CreateSection("Extra")
Tab_Move:CreateToggle({Name = "NoClip", CurrentValue = false, Callback = function(v) Config.Movement.NoClip = v end})
Tab_Move:CreateToggle({Name = "Super Jump", CurrentValue = false, Callback = function(v) Config.Movement.JumpPower.Enabled = v end})
Tab_Move:CreateSlider({Name = "Jump Power", Range = {50, 200}, Increment = 5, CurrentValue = 50, Callback = function(v) Config.Movement.JumpPower.Value = v end})
Tab_Move:CreateToggle({Name = "Fly Mode", CurrentValue = false, Callback = function(v) Config.Movement.Fly = v end})

-- ===== WORLD =====
Tab_World:CreateSection("Light & Fog")
Tab_World:CreateToggle({Name = "FullBright", CurrentValue = false, Callback = function(v)
    Config.World.FullBright = v
    if v then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.Brightness = 2
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = Backup.Ambient
        Lighting.Brightness = Backup.Brightness
        Lighting.GlobalShadows = Backup.GlobalShadows
    end
end})

Tab_World:CreateToggle({Name = "No Fog", CurrentValue = false, Callback = function(v)
    Config.World.NoFog = v
    Lighting.FogEnd = v and 1e5 or Backup.FogEnd
end})

Tab_World:CreateSection("Cleanup")
Tab_World:CreateToggle({Name = "Remove Decals", CurrentValue = false, Callback = function(v)
    Config.World.RemoveDecals = v
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Decal") or obj:IsA("Texture") then
            obj.Transparency = v and 1 or 0
        end
    end
end})

Tab_World:CreateToggle({Name = "Remove Particles", CurrentValue = false, Callback = function(v)
    Config.World.RemoveParticles = v
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") or obj:IsA("Smoke") or obj:IsA("Fire") then
            obj.Enabled = not v
        end
    end
end})

-- ===== PERFORMANCE =====
Tab_Perf:CreateSection("FPS Booster")
Tab_Perf:CreateToggle({Name = "FPS Boost", CurrentValue = false, Callback = function(v)
    Config.Performance.FPSBoost = v
    ApplyFPSBoost(v)
end})

Tab_Perf:CreateToggle({Name = "Low Graphics", CurrentValue = false, Callback = function(v)
    Config.Performance.LowGraphics = v
    ApplyLowGraphics(v)
end})

-- // 7. MAIN LOOPS //

-- Render loop
Cache.Connections["Render"] = RunService.RenderStepped:Connect(function()
    if Config.MasterSwitch then
        for _, player in pairs(Players:GetPlayers()) do
            pcall(DrawESP, player)
        end
    else
        for _, player in pairs(Players:GetPlayers()) do
            pcall(ClearESP, player.Character)
        end
    end
end)

-- Movement loop
Cache.Connections["Movement"] = RunService.Heartbeat:Connect(function()
    local char = LP.Character
    if not char then return end
    
    local hum = char:FindFirstChild("Humanoid")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hum or not hrp then return end
    
    -- Anti-Kick Speed
    if Config.Movement.AntiKickEnabled and Config.Movement.Speed > 16 then
        if hum.MoveDirection.Magnitude > 0 then
            local calcMove = hum.MoveDirection * (Config.Movement.Speed / 70)
            hrp.CFrame = hrp.CFrame:Lerp(hrp.CFrame + calcMove, Config.Movement.LerpSmoothness)
        end
    else
        hum.WalkSpeed = Config.Movement.Speed
    end
    
    -- Jump Power
    if Config.Movement.JumpPower.Enabled then
        hum.JumpPower = Config.Movement.JumpPower.Value
    end
    
    -- NoClip
    if Config.Movement.NoClip then
        for _, part in pairs(char:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    end
    
    -- Fly
    if Config.Movement.Fly then
        local bv = hrp:FindFirstChild("FLY_BV") or Instance.new("BodyVelocity")
        bv.Name = "FLY_BV"
        bv.MaxForce = Vector3.new(4000, 4000, 4000)
        bv.Velocity = workspace.CurrentCamera.CFrame.LookVector * 50
        bv.Parent = hrp
    else
        local bv = hrp:FindFirstChild("FLY_BV")
        if bv then bv:Destroy() end
    end
end)

-- Welcome notification
Rayfield:Notify({
    Title = "PAPER CAT",
    Content = "✅ Version 2.1 ready | English",
    Duration = 5
})

print("✅ PAPER CAT 2.1 loaded | English")
