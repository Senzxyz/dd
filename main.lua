local SymbiosUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/SYMBIOSHUB/SYMBIOS-HUB/refs/heads/main/UI/Symbios-ui.lua"))()

local Window = SymbiosUI:Window({
    Title    = "SENZY HUB",
    Subtitle = "Slayers 2 - Auto Farm & Tools",
    Size     = UDim2.fromOffset(760, 520),
    Keybind  = Enum.KeyCode.RightControl,
})

local group    = Window:TabGroup()
local mainTab  = group:Tab({ Name = "Main", Image = "rbxassetid://18821914323" })

local farmSec   = mainTab:Section({ Name = "Farm Control", Side = "Left" })
local targetSec = mainTab:Section({ Name = "Target Selector", Side = "Right" })
local visualSec = mainTab:Section({ Name = "Visuals / Lighting", Side = "Right" })

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Config = {
    AutoQuest = false,
    AutoFarm = false,
    SelectedTarget = "All",
    Fullbright = false,
}

local SignalEvent = nil
pcall(function()
    SignalEvent = ReplicatedStorage.Communication.ServerAndClient.Signals.SignalEvent.Event
end)

local function getAvailableMonsters()
    local monsterOptions = { "All" }
    local addedNames = { ["All"] = true }
    
    pcall(function()
        for _, region in ipairs(workspace.Humanoids.Regions:GetChildren()) do
            local activeNpcs = region:FindFirstChild("ActiveNpcs")
            if activeNpcs then
                for _, npcFolder in ipairs(activeNpcs:GetChildren()) do
                    for _, enemy in ipairs(npcFolder:GetChildren()) do
                        if enemy:FindFirstChild("Humanoid") then
                            local name = enemy.Name
                            if not addedNames[name] then
                                addedNames[name] = true
                                table.insert(monsterOptions, name)
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return monsterOptions
end

local dropdownObj = targetSec:Dropdown({
    Name     = "Select Target",
    Options  = { "All" },
    Multi    = false,
    Required = true,
    Search   = true,
    Default  = 1,
    Callback = function(value)
        Config.SelectedTarget = value
    end,
}, "TargetDropdown")

targetSec:Button({
    Name = "Refresh Monster List",
    Callback = function()
        local newList = getAvailableMonsters()
        dropdownObj:ClearOptions()
        dropdownObj:InsertOptions(newList)
        Window:Notify({ Title = "Success", Description = "Refreshed monster list!", Lifetime = 3 })
    end,
}, "RefreshBtn")

farmSec:Toggle({
    Name    = "Auto Quest",
    Default = false,
    Callback = function(state)
        Config.AutoQuest = state
        task.spawn(function()
            while Config.AutoQuest do
                pcall(function()
                    if SignalEvent then
                        SignalEvent:FireServer("AddQuest", "Ill take 3 bandits")
                    end
                end)
                task.wait(1)
            end
        end)
    end,
}, "AutoQuestToggle")

local function getTargetBySelection()
    local target = nil
    local shortestDistance = math.huge
    local char = LocalPlayer.Character
    
    if not char or not char:FindFirstChild("HumanoidRootPart") then return nil end
    local myPos = char.HumanoidRootPart.Position

    pcall(function()
        for _, region in ipairs(workspace.Humanoids.Regions:GetChildren()) do
            local activeNpcs = region:FindFirstChild("ActiveNpcs")
            if activeNpcs then
                for _, npcFolder in ipairs(activeNpcs:GetChildren()) do
                    for _, enemy in ipairs(npcFolder:GetChildren()) do
                        if enemy:FindFirstChild("HumanoidRootPart") and enemy:FindFirstChild("Humanoid") then
                            if enemy.Humanoid.Health > 0 then
                                if Config.SelectedTarget == "All" or enemy.Name == Config.SelectedTarget then
                                    local dist = (enemy.HumanoidRootPart.Position - myPos).Magnitude
                                    if dist < shortestDistance then
                                        shortestDistance = dist
                                        target = enemy
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
    
    return target
end

farmSec:Toggle({
    Name    = "Auto Farm",
    Default = false,
    Callback = function(state)
        Config.AutoFarm = state
        task.spawn(function()
            while Config.AutoFarm do
                task.wait(0.05)
                pcall(function()
                    local enemy = getTargetBySelection()
                    if enemy and enemy:FindFirstChild("HumanoidRootPart") then
                        local char = LocalPlayer.Character
                        if char and char:FindFirstChild("HumanoidRootPart") then
                            char.HumanoidRootPart.CFrame = enemy.HumanoidRootPart.CFrame + Vector3.new(0, 4, 0)
                            if SignalEvent then
                                SignalEvent:FireServer("Combat_Service", "Combat", 1, true, 0.038, false)
                            end
                        end
                    end
                end)
            end
        end)
    end,
}, "AutoFarmToggle")

-- ระบบ Fullbright แบบลบหมอกและเคลียร์แสง
local cachedAtmosphere = {}
visualSec:Toggle({
    Name = "Fullbright (Remove Darkness & Fog)",
    Default = false,
    Callback = function(state)
        Config.Fullbright = state
        
        if Config.Fullbright then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 999999
            
            -- ซ่อนหรือลบ Atmosphere และ DepthOfField ใน Lighting ออกชั่วคราว
            for _, obj in ipairs(Lighting:GetChildren()) do
                if obj:IsA("Atmosphere") or obj:IsA("DepthOfFieldEffect") or obj:IsA("BlurEffect") then
                    table.insert(cachedAtmosphere, {obj = obj, parent = obj.Parent})
                    obj.Parent = nil
                end
            end
        else
            -- คืนค่าเดิม
            Lighting.Brightness = 1
            Lighting.ClockTime = 12
            Lighting.GlobalShadows = true
            Lighting.FogEnd = 10000
            
            for _, data in ipairs(cachedAtmosphere) do
                if data.obj then
                    data.obj.Parent = data.parent
                end
            end
            cachedAtmosphere = {}
        end
    end,
}, "FullbrightToggle")

Window.onUnloaded(function()
    print("Senzy Hub unloaded successfully")
end)

mainTab:Select()
