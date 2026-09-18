local SymbiosUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/SYMBIOSHUB/SYMBIOS-HUB/refs/heads/main/UI/Symbios-ui.lua"))()

local Window = SymbiosUI:Window({
    Title    = "SENZY HUB",
    Subtitle = "Slayers 2 - Auto Farm",
    Size     = UDim2.fromOffset(760, 520),
    Keybind  = Enum.KeyCode.RightControl,
})

local group    = Window:TabGroup()
local mainTab  = group:Tab({ Name = "Main", Image = "rbxassetid://18821914323" })

-- สร้าง Section ด้านซ้ายและขวา
local farmSec   = mainTab:Section({ Name = "Farm Control", Side = "Left" })
local targetSec = mainTab:Section({ Name = "Target Selector", Side = "Right" })

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local Config = {
    AutoQuest = false,
    AutoFarm = false,
    SelectedTarget = "All",
}

local SignalEvent = nil
pcall(function()
    SignalEvent = ReplicatedStorage.Communication.ServerAndClient.Signals.SignalEvent.Event
end)

-- ฟังก์ชันสแกนหารายชื่อมอนสเตอร์พร้อมเลเวลและเช็ค Boss
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
                                
                                -- ดึงเลเวลจากค่า MaxHealth หรือ Attribute (ปรับตามเกมจริง)
                                local maxHp = enemy.Humanoid.MaxHealth
                                local estimatedLevel = math.clamp(math.floor(maxHp / 100), 1, 999)
                                
                                -- เช็คว่าเป็น Boss หรือไม่
                                local isBoss = string.find(string.lower(name), "boss") or (maxHp > 5000)
                                local tag = isBoss and " [BOSS]" or ""
                                
                                local displayName = string.format("%s (Lv. %d)%s", name, estimatedLevel, tag)
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

-- Dropdown สำหรับเลือกมอนสเตอร์
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

-- ปุ่มรีเฟรชรายชื่อมอนสเตอร์ใน Dropdown
targetSec:Button({
    Name = "Refresh Monster List",
    Callback = function()
        local newList = getAvailableMonsters()
        dropdownObj:ClearOptions()
        dropdownObj:InsertOptions(newList)
        Window:Notify({ Title = "Success", Description = "Refreshed monster list!", Lifetime = 3 })
    end,
}, "RefreshBtn")

-- Toggle เปิด-ปิด Auto Quest
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

-- ฟังก์ชันหาเป้าหมายมอนสเตอร์ตามที่เลือก
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

-- Toggle เปิด-ปิด Auto Farm
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
                            -- วาร์ปเกาะติดเหนือหัวมอนสเตอร์
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

Window.onUnloaded(function()
    print("Senzy Hub unloaded successfully")
end)

mainTab:Select()
