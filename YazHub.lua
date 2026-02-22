-- YazHub v2 - Toggle with Y key
-- Features: Soft Aim (Wall Check), Simple Box ESP
-- Notifications on load + game detection
-- Starts DISABLED - Press Y to toggle

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local MarketplaceService = game:GetService("MarketplaceService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local YazHub = {
    Enabled = false,
    SoftAimConn = nil,
    ESPConns = {}
}

local function notify(title, text, dur)
    StarterGui:SetCore("SendNotification", {Title = title, Text = text, Duration = dur or 4})
end

-- Game detection & welcome
local function init()
    local success, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, game.PlaceId)
    local name = success and info.Name or "Unknown"
    notify("YazHub Loaded", "Detected: " .. name, 6)
    wait(1)
    notify("YazHub", "Press Y to toggle features. Enjoy!", 5)
end

-- Wall check (visible check)
local function isVisible(targetPos)
    local origin = Camera.CFrame.Position
    local dir = (targetPos - origin).Unit * 1000
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {LocalPlayer.Character or game}
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.IgnoreWater = true

    local res = Workspace:Raycast(origin, dir, params)
    if res and (res.Position - origin).Magnitude < (targetPos - origin).Magnitude then
        return false
    end
    return true
end

-- Closest enemy
local function getClosest()
    local best, dist = nil, math.huge
    for _, p in Players:GetPlayers() do
        if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
            local d = (p.Character.HumanoidRootPart.Position - Camera.CFrame.Position).Magnitude
            if d < dist then
                dist = d
                best = p
            end
        end
    end
    return best
end

-- Soft aim
local function toggleSoftAim(enable)
    if YazHub.SoftAimConn then
        YazHub.SoftAimConn:Disconnect()
        YazHub.SoftAimConn = nil
    end
    if not enable then return end

    YazHub.SoftAimConn = RunService.RenderStepped:Connect(function()
        local target = getClosest()
        if target and target.Character and target.Character:FindFirstChild("Head") then
            local head = target.Character.Head
            if isVisible(head.Position) then
                local goal = CFrame.new(Camera.CFrame.Position, head.Position)
                Camera.CFrame = Camera.CFrame:Lerp(goal, 0.08)  -- Slower = more legit-looking
            end
        end
    end)
end

-- ESP boxes
local function clearESP()
    for _, c in YazHub.ESPConns do c:Disconnect() end
    YazHub.ESPConns = {}
    for _, p in Players:GetPlayers() do
        if p ~= LocalPlayer and p.Character then
            local gui = p.Character:FindFirstChild("YazHubESP")
            if gui then gui:Destroy() end
        end
    end
end

local function createESP(plr)
    if plr == LocalPlayer or not plr.Character then return end

    local adornee = plr.Character:FindFirstChild("HumanoidRootPart")
    if not adornee then return end

    local bb = Instance.new("BillboardGui")
    bb.Name = "YazHubESP"
    bb.Adornee = adornee
    bb.AlwaysOnTop = true
    bb.Size = UDim2.new(4, 0, 6, 0)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.Parent = plr.Character

    local frame = Instance.new("Frame", bb)
    frame.Size = UDim2.new(1,0,1,0)
    frame.BackgroundTransparency = 1

    local function addBar(size, pos, color)
        local bar = Instance.new("Frame", frame)
        bar.Size = size
        bar.Position = pos
        bar.BackgroundColor3 = color
        bar.BorderSizePixel = 0
    end

    addBar(UDim2.new(1,0,0,2), UDim2.new(0,0,0,0), Color3.new(1,0,0))     -- top
    addBar(UDim2.new(1,0,0,2), UDim2.new(0,0,1,-2), Color3.new(1,0,0))   -- bottom
    addBar(UDim2.new(0,2,1,0), UDim2.new(0,0,0,0), Color3.new(1,0,0))     -- left
    addBar(UDim2.new(0,2,1,0), UDim2.new(1,-2,0,0), Color3.new(1,0,0))    -- right

    local conn = RunService.RenderStepped:Connect(function()
        if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
            bb:Destroy()
            conn:Disconnect()
            return
        end
        local d = (adornee.Position - Camera.CFrame.Position).Magnitude
        bb.Size = UDim2.new(300/d, 0, 450/d, 0)  -- Scale with distance
    end)
    table.insert(YazHub.ESPConns, conn)
end

local function toggleESP(enable)
    clearESP()
    if not enable then return end

    for _, p in Players:GetPlayers() do createESP(p) end
    table.insert(YazHub.ESPConns, Players.PlayerAdded:Connect(createESP))
end

-- Toggle handler (Y key)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Y then
        YazHub.Enabled = not YazHub.Enabled
        toggleSoftAim(YazHub.Enabled)
        toggleESP(YazHub.Enabled)
        notify("YazHub", YazHub.Enabled and "Features ENABLED" or "Features DISABLED", 3)
    end
end)

-- Init
init()

-- Optional: auto-create ESP for new players even when off (but only show when enabled)
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(function()
        if YazHub.Enabled then createESP(p) end
    end)
end)
