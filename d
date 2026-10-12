-- [[ Rscripts Risk Notice ]]
-- This script is not verified by rscripts.net. Deal with caution.
--
-- Stay safe:
--   • Never log in on unofficial Roblox sites or lookalike domains.
--   • Real Roblox links use roblox.com (check the .com ending).
--   • Treat fake Roblox login / "claim reward" pages as phishing.
-- [[ End Rscripts Risk Notice ]]

--[[rscripts:analytics:start]]
-- Script analytics (enabled by the creator on rscripts.net).
-- Runs in its own thread and cannot affect the script below.
task.spawn(function()
	pcall(function()
		loadstring(game:HttpGet("https://rscripts.net/api/telemetry/v2/client.lua?s=6acc5bc1a62b0dbc5c2a2a58"))()
	end)
end)
--[[rscripts:analytics:end]]

-- PrivateAimAssist v3
-- LocalScript:
-- StarterPlayer > StarterPlayerScripts
--
-- Controls:
-- Q             = Toggle aim system
-- Right mouse   = Hold to acquire and track a target
-- RightShift    = Hide / reopen menu
--
-- ESP Team Check:
-- ON  = Hide teammates from ESP
-- OFF = Show teammates in ESP
--
-- Through-wall ESP is intended for private-game debugging.

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local CONFIG = {
    Enabled = false,
    Mode = "Aim Assist",

    AimKey = Enum.KeyCode.Q,
    MenuKey = Enum.KeyCode.RightShift,

    FOV = 150,
    Smoothness = 8,

    TeamCheck = true,
    WallCheck = true,
    DebugThroughWalls = false,
}

-- ESP settings
local ESPEnabled = true
local ESPNamesEnabled = true
local ESPDistanceEnabled = true
local ESPTeamCheck = true

local holdingAim = false
local capturingKey = false
local targetModel = nil
local targetHighlight = nil

local candidates = {}
local connections = {}
local espObjects = {}

local camera = Workspace.CurrentCamera
local alive = true
local RENDER_NAME = "PrivateAimAssist_Render"

-- Forward declarations
local validRig
local getHead
local addESP
local removeESP
local updateESP

--==================================================
-- Cleanup helpers
--==================================================

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local oldGui = PlayerGui:FindFirstChild("PrivateAimUI")
if oldGui then
    oldGui:Destroy()
end

--==================================================
-- User interface
--==================================================

local gui = Instance.new("ScreenGui")
gui.Name = "PrivateAimUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = PlayerGui

local main = Instance.new("Frame")
main.Name = "Window"
main.Size = UDim2.fromOffset(350, 490)
main.Position = UDim2.new(0, 25, 0.5, -245)
main.BackgroundColor3 = Color3.fromRGB(19, 22, 30)
main.BorderSizePixel = 0
main.Parent = gui

Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(77, 112, 255)
outline.Thickness = 1.5
outline.Parent = main

local topbar = Instance.new("Frame")
topbar.Name = "TitleBar"
topbar.Size = UDim2.new(1, 0, 0, 43)
topbar.BackgroundColor3 = Color3.fromRGB(31, 35, 48)
topbar.BorderSizePixel = 0
topbar.Active = true
topbar.Parent = main

Instance.new("UICorner", topbar).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(13, 0)
title.Size = UDim2.new(1, -55, 1, 0)
title.BackgroundTransparency = 1
title.Text = "PRIVATE AIM LAB  /  V3"
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextColor3 = Color3.fromRGB(237, 240, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = topbar

local closeButton = Instance.new("TextButton")
closeButton.Position = UDim2.new(1, -38, 0, 7)
closeButton.Size = UDim2.fromOffset(30, 28)
closeButton.Text = "×"
closeButton.Font = Enum.Font.Gotham
closeButton.TextSize = 22
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.BackgroundColor3 = Color3.fromRGB(170, 55, 67)
closeButton.Parent = topbar

Instance.new("UICorner", closeButton).CornerRadius = UDim.new(0, 6)

local function makeLabel(text, x, y, w, h)
    local object = Instance.new("TextLabel")
    object.Position = UDim2.fromOffset(x, y)
    object.Size = UDim2.fromOffset(w, h or 22)
    object.BackgroundTransparency = 1
    object.Text = text
    object.Font = Enum.Font.Gotham
    object.TextSize = 12
    object.TextColor3 = Color3.fromRGB(202, 208, 225)
    object.TextXAlignment = Enum.TextXAlignment.Left
    object.Parent = main
    return object
end

local function makeButton(text, x, y, w, h)
    local object = Instance.new("TextButton")
    object.Position = UDim2.fromOffset(x, y)
    object.Size = UDim2.fromOffset(w, h or 32)
    object.BackgroundColor3 = Color3.fromRGB(41, 46, 62)
    object.BorderSizePixel = 0
    object.Text = text
    object.TextColor3 = Color3.fromRGB(242, 244, 255)
    object.Font = Enum.Font.GothamMedium
    object.TextSize = 12
    object.Parent = main

    Instance.new("UICorner", object).CornerRadius = UDim.new(0, 6)
    return object
end

local function makeInput(value, y)
    local object = Instance.new("TextBox")
    object.Position = UDim2.new(1, -104, 0, y)
    object.Size = UDim2.fromOffset(86, 26)
    object.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    object.BorderSizePixel = 0
    object.Text = tostring(value)
    object.TextColor3 = Color3.new(1, 1, 1)
    object.Font = Enum.Font.Gotham
    object.TextSize = 12
    object.ClearTextOnFocus = false
    object.Parent = main

    Instance.new("UICorner", object).CornerRadius = UDim.new(0, 5)
    return object
end

makeLabel("TARGETING", 15, 52, 200)

local aimButton = makeButton("AIM: OFF", 15, 76, 153, 32)
local modeButton = makeButton("MODE: ASSIST", 182, 76, 153, 32)

makeLabel("Activation key", 15, 117, 180)
local keyButton = makeButton("Q / CHANGE", 221, 112, 114, 29)

makeLabel("FOV radius (pixels)", 15, 151, 200)
local fovInput = makeInput(CONFIG.FOV, 147)

makeLabel("Smoothness (1 = fast, 30 = slow)", 15, 184, 245)
local smoothInput = makeInput(CONFIG.Smoothness, 180)

makeLabel("FILTERS AND VISUALS", 15, 218, 220)

local teamButton = makeButton("TEAM CHECK: ON", 15, 243, 153, 31)
local wallButton = makeButton("WALL CHECK: ON", 182, 243, 153, 31)
local debugButton = makeButton("DEBUG HIGHLIGHT: OFF", 15, 282, 320, 31)

local espButton = makeButton("ESP: ON", 15, 320, 153, 29)
local espNamesButton = makeButton("ESP NAMES: ON", 182, 320, 153, 29)
local espDistanceButton = makeButton("ESP DISTANCE: ON", 15, 355, 320, 29)
local espTeamButton = makeButton("ESP TEAM CHECK: ON", 15, 390, 320, 29)

local statusLabel = makeLabel("Status: disabled", 15, 426, 320, 20)
statusLabel.TextColor3 = Color3.fromRGB(130, 185, 255)

local targetLabel = makeLabel("Target: none", 15, 446, 320, 19)
local reasonLabel = makeLabel("Ready", 15, 466, 320, 19)

-- FOV circle
local circle = Instance.new("Frame")
circle.Name = "FOVCircle"
circle.AnchorPoint = Vector2.new(0.5, 0.5)
circle.Size = UDim2.fromOffset(CONFIG.FOV * 2, CONFIG.FOV * 2)
circle.BackgroundTransparency = 1
circle.BorderSizePixel = 0
circle.Parent = gui

Instance.new("UICorner", circle).CornerRadius = UDim.new(1, 0)

local circleStroke = Instance.new("UIStroke")
circleStroke.Color = Color3.fromRGB(91, 140, 255)
circleStroke.Thickness = 1.5
circleStroke.Parent = circle

--==================================================
-- Dragging: title bar only
--==================================================

do
    local dragging = false
    local dragStart
    local startPosition

    connect(topbar.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPosition = main.Position
        end
    end)

    connect(UIS.InputChanged, function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart

            main.Position = UDim2.new(
                startPosition.X.Scale,
                startPosition.X.Offset + delta.X,
                startPosition.Y.Scale,
                startPosition.Y.Offset + delta.Y
            )
        end
    end)

    connect(UIS.InputEnded, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--==================================================
-- Rig validation and team-aware ESP
--==================================================

validRig = function(model)
    if not model or not model:IsA("Model") then
        return false
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local head = model:FindFirstChild("Head")

    return humanoid ~= nil
        and head ~= nil
        and head:IsA("BasePart")
end

getHead = function(model)
    if not model or not model.Parent then
        return nil
    end

    local head = model:FindFirstChild("Head")

    if head and head:IsA("BasePart") then
        return head
    end

    return nil
end

local function shouldShowESP(model)
    if not ESPTeamCheck then
        return true
    end

    local player = Players:GetPlayerFromCharacter(model)

    -- NPCs remain visible.
    if not player then
        return true
    end

    -- Neutral players remain visible.
    if LocalPlayer.Neutral or player.Neutral then
        return true
    end

    -- Hide players on the local player's team.
    return not (
        LocalPlayer.Team ~= nil
        and player.Team ~= nil
        and LocalPlayer.Team == player.Team
    )
end

removeESP = function(model)
    local data = espObjects[model]
    if not data then
        return
    end

    for _, object in ipairs(data) do
        if object and object.Parent then
            object:Destroy()
        end
    end

    espObjects[model] = nil
end

addESP = function(model)
    if not ESPEnabled
        or espObjects[model]
        or not validRig(model)
        or not shouldShowESP(model) then
        return
    end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    local head = getHead(model)

    if not humanoid or humanoid.Health <= 0 or not head then
        return
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "PrivateAimESP"
    highlight.Adornee = model
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillColor = Color3.fromRGB(75, 125, 255)
    highlight.OutlineColor = Color3.fromRGB(190, 220, 255)
    highlight.FillTransparency = 0.75
    highlight.OutlineTransparency = 0
    highlight.Parent = gui

    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrivateAimESPLabel"
    billboard.Adornee = head
    billboard.Size = UDim2.fromOffset(220, 30)
    billboard.StudsOffset = Vector3.new(0, 2.5, 0)
    billboard.AlwaysOnTop = true
    billboard.Parent = gui

    local label = Instance.new("TextLabel")
    label.Name = "ESPText"
    label.Size = UDim2.fromScale(1, 1)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(235, 240, 255)
    label.TextStrokeTransparency = 0.15
    label.TextStrokeColor3 = Color3.new(0, 0, 0)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = billboard

    espObjects[model] = {highlight, billboard, label}
end

updateESP = function()
    camera = Workspace.CurrentCamera

    for model, data in pairs(espObjects) do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        local head = getHead(model)

        if not model.Parent or not humanoid
            or humanoid.Health <= 0 or not head then
            removeESP(model)
        elseif not shouldShowESP(model) then
            removeESP(model)
        else
            local nameText = ESPNamesEnabled and model.Name or ""
            local distanceText = ""

            if ESPDistanceEnabled and camera then
                local distance = (
                    camera.CFrame.Position - head.Position
                ).Magnitude

                distanceText = string.format(
                    " [%d studs]",
                    math.floor(distance + 0.5)
                )
            end

            data[1].Enabled = ESPEnabled
            data[2].Enabled = ESPEnabled
            data[3].Visible = ESPEnabled
            data[3].Text = nameText .. distanceText
        end
    end

    -- Add ESP for newly eligible models, including when a player changes teams.
    if ESPEnabled then
        for model in pairs(candidates) do
            if not espObjects[model] and shouldShowESP(model) then
                addESP(model)
            end
        end
    end
end

local function refreshESP()
    if ESPEnabled then
        for model in pairs(candidates) do
            addESP(model)
        end
    else
        local models = {}

        for model in pairs(espObjects) do
            table.insert(models, model)
        end

        for _, model in ipairs(models) do
            removeESP(model)
        end
    end

    updateESP()
end

--==================================================
-- Candidate registration
--==================================================

local function unregisterModel(model)
    candidates[model] = nil
    removeESP(model)

    if targetModel == model then
        targetModel = nil

        if targetHighlight then
            targetHighlight:Destroy()
            targetHighlight = nil
        end
    end
end

local function registerModel(model)
    if validRig(model) then
        candidates[model] = true
        addESP(model)
    end
end

local function registerCharacter(character)
    if not character then
        return
    end

    task.defer(registerModel, character)

    connect(character.ChildAdded, function(child)
        if child.Name == "Head" or child:IsA("Humanoid") then
            task.defer(registerModel, character)
        end
    end)

    connect(character.ChildRemoved, function(child)
        if child.Name == "Head" or child:IsA("Humanoid") then
            task.defer(function()
                if validRig(character) then
                    registerModel(character)
                else
                    unregisterModel(character)
                end
            end)
        end
    end)
end

local function registerPlayer(player)
    if player.Character then
        registerCharacter(player.Character)
    end

    connect(player.CharacterAdded, registerCharacter)

    connect(player.CharacterRemoving, function(character)
        unregisterModel(character)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        registerPlayer(player)
    end
end

connect(Players.PlayerAdded, function(player)
    if player ~= LocalPlayer then
        registerPlayer(player)
    end
end)

connect(Players.PlayerRemoving, function(player)
    if player.Character then
        unregisterModel(player.Character)
    end
end)

-- Initial scan for existing NPCs.
for _, object in ipairs(Workspace:GetDescendants()) do
    if object:IsA("Humanoid")
        and object.Parent:IsA("Model") then
        registerModel(object.Parent)
    end
end

-- Track new NPCs as they appear.
connect(Workspace.DescendantAdded, function(object)
    if object:IsA("Humanoid")
        and object.Parent:IsA("Model") then
        task.defer(registerModel, object.Parent)
    elseif object.Name == "Head"
        and object:IsA("BasePart")
        and object.Parent:IsA("Model") then
        task.defer(registerModel, object.Parent)
    end
end)

connect(Workspace.DescendantRemoving, function(object)
    if object:IsA("Model") and candidates[object] then
        unregisterModel(object)
    end
end)

--==================================================
-- Target filtering
--==================================================

local function isFriendly(model)
    local player = Players:GetPlayerFromCharacter(model)

    if not player then
        return false
    end

    if LocalPlayer.Neutral or player.Neutral then
        return false
    end

    return LocalPlayer.Team ~= nil
        and player.Team ~= nil
        and LocalPlayer.Team == player.Team
end

local function getViewportMouse()
    local mouse = UIS:GetMouseLocation()
    local insetTopLeft = GuiService:GetGuiInset()

    return Vector2.new(
        mouse.X - insetTopLeft.X,
        mouse.Y - insetTopLeft.Y
    )
end

local function hasLineOfSight(head, model)
    if not CONFIG.WallCheck then
        return true
    end

    camera = Workspace.CurrentCamera
    if not camera then
        return false
    end

    local origin = camera.CFrame.Position
    local direction = head.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character,
        camera
    }
    params.IgnoreWater = true

    local result = Workspace:Raycast(origin, direction, params)

    return result == nil
        or result.Instance:IsDescendantOf(model)
end

local function getTargetDistance(model)
    camera = Workspace.CurrentCamera

    if not camera then
        return nil
    end

    local head = getHead(model)
    local humanoid = model:FindFirstChildOfClass("Humanoid")

    if not head or not humanoid or humanoid.Health <= 0 then
        return nil
    end

    if CONFIG.TeamCheck and isFriendly(model) then
        return nil
    end

    if not hasLineOfSight(head, model) then
        return nil
    end

    local point, onScreen = camera:WorldToViewportPoint(head.Position)

    if not onScreen or point.Z <= 0 then
        return nil
    end

    local distance = (
        Vector2.new(point.X, point.Y) - getViewportMouse()
    ).Magnitude

    if distance > CONFIG.FOV then
        return nil
    end

    return distance
end

local function selectTarget()
    local bestModel = nil
    local bestDistance = CONFIG.FOV

    for model in pairs(candidates) do
        if model.Parent then
            local distance = getTargetDistance(model)

            if distance and distance < bestDistance then
                bestDistance = distance
                bestModel = model
            end
        else
            candidates[model] = nil
            removeESP(model)
        end
    end

    return bestModel
end

--==================================================
-- Lock and target highlight
--==================================================

local function clearTarget()
    targetModel = nil

    if targetHighlight then
        targetHighlight:Destroy()
        targetHighlight = nil
    end

    targetLabel.Text = "Target: none"
end

local function setTarget(model)
    if targetModel == model then
        return
    end

    clearTarget()

    if not model then
        return
    end

    targetModel = model

    local highlight = Instance.new("Highlight")
    highlight.Name = "PrivateAimTarget"
    highlight.Adornee = model
    highlight.FillColor = Color3.fromRGB(75, 125, 255)
    highlight.OutlineColor = Color3.fromRGB(190, 220, 255)
    highlight.FillTransparency = 0.8
    highlight.OutlineTransparency = 0

    highlight.DepthMode = CONFIG.DebugThroughWalls
        and Enum.HighlightDepthMode.AlwaysOnTop
        or Enum.HighlightDepthMode.Occluded

    highlight.Parent = gui
    targetHighlight = highlight

    targetLabel.Text = "Target: " .. model.Name
end

local function updateHighlight()
    if targetHighlight then
        targetHighlight.DepthMode = CONFIG.DebugThroughWalls
            and Enum.HighlightDepthMode.AlwaysOnTop
            or Enum.HighlightDepthMode.Occluded
    end
end

--==================================================
-- Settings UI
--==================================================

local function updateButtons()
    aimButton.Text = CONFIG.Enabled and "AIM: ON" or "AIM: OFF"

    aimButton.BackgroundColor3 = CONFIG.Enabled
        and Color3.fromRGB(35, 125, 83)
        or Color3.fromRGB(41, 46, 62)

    modeButton.Text = CONFIG.Mode == "Aim Assist"
        and "MODE: ASSIST"
        or "MODE: AIMBOT"

    keyButton.Text = capturingKey
        and "PRESS KEY..."
        or (CONFIG.AimKey.Name .. " / CHANGE")

    teamButton.Text = "TEAM CHECK: "
        .. (CONFIG.TeamCheck and "ON" or "OFF")

    wallButton.Text = "WALL CHECK: "
        .. (CONFIG.WallCheck and "ON" or "OFF")

    debugButton.Text = "DEBUG HIGHLIGHT: "
        .. (CONFIG.DebugThroughWalls and "ON" or "OFF")

    espButton.Text = "ESP: " .. (ESPEnabled and "ON" or "OFF")

    espNamesButton.Text = "ESP NAMES: "
        .. (ESPNamesEnabled and "ON" or "OFF")

    espDistanceButton.Text = "ESP DISTANCE: "
        .. (ESPDistanceEnabled and "ON" or "OFF")

    espTeamButton.Text = "ESP TEAM CHECK: "
        .. (ESPTeamCheck and "ON" or "OFF")
end

local function setEnabled(enabled)
    CONFIG.Enabled = enabled

    if not enabled then
        holdingAim = false
        clearTarget()
    end

    updateButtons()
end

connect(aimButton.Activated, function()
    setEnabled(not CONFIG.Enabled)
end)

connect(modeButton.Activated, function()
    CONFIG.Mode = CONFIG.Mode == "Aim Assist"
        and "Aimbot"
        or "Aim Assist"

    updateButtons()
end)

connect(keyButton.Activated, function()
    capturingKey = true
    updateButtons()
end)

connect(teamButton.Activated, function()
    CONFIG.TeamCheck = not CONFIG.TeamCheck

    if CONFIG.TeamCheck
        and targetModel
        and isFriendly(targetModel) then
        clearTarget()
    end

    updateButtons()
end)

connect(wallButton.Activated, function()
    CONFIG.WallCheck = not CONFIG.WallCheck

    if CONFIG.WallCheck and targetModel then
        local head = getHead(targetModel)

        if not head or not hasLineOfSight(head, targetModel) then
            clearTarget()
        end
    end

    updateButtons()
end)

connect(debugButton.Activated, function()
    CONFIG.DebugThroughWalls = not CONFIG.DebugThroughWalls
    updateHighlight()
    updateButtons()
end)

connect(espButton.Activated, function()
    ESPEnabled = not ESPEnabled
    refreshESP()
    updateButtons()
end)

connect(espNamesButton.Activated, function()
    ESPNamesEnabled = not ESPNamesEnabled
    updateESP()
    updateButtons()
end)

connect(espDistanceButton.Activated, function()
    ESPDistanceEnabled = not ESPDistanceEnabled
    updateESP()
    updateButtons()
end)

connect(espTeamButton.Activated, function()
    ESPTeamCheck = not ESPTeamCheck

    if ESPEnabled then
        if ESPTeamCheck then
            -- Remove ESP from teammates immediately.
            local toRemove = {}

            for model in pairs(espObjects) do
                if not shouldShowESP(model) then
                    table.insert(toRemove, model)
                end
            end

            for _, model in ipairs(toRemove) do
                removeESP(model)
            end
        else
            -- Restore ESP for all eligible characters and NPCs.
            for model in pairs(candidates) do
                addESP(model)
            end
        end
    end

    updateButtons()
    updateESP()
end)

connect(fovInput.FocusLost, function()
    local value = tonumber(fovInput.Text)

    if value then
        CONFIG.FOV = math.clamp(math.floor(value), 25, 600)
    end

    fovInput.Text = tostring(CONFIG.FOV)
end)

connect(smoothInput.FocusLost, function()
    local value = tonumber(smoothInput.Text)

    if value then
        CONFIG.Smoothness = math.clamp(value, 1, 30)
    end

    smoothInput.Text = tostring(CONFIG.Smoothness)
end)

connect(closeButton.Activated, function()
    main.Visible = false
    circle.Visible = false
end)

--==================================================
-- Keyboard and mouse handling
--==================================================

connect(UIS.InputBegan, function(input, processed)
    if capturingKey then
        if input.UserInputType == Enum.UserInputType.Keyboard
            and input.KeyCode ~= Enum.KeyCode.Unknown then

            CONFIG.AimKey = input.KeyCode
            capturingKey = false
            updateButtons()
        end

        return
    end

    if input.UserInputType == Enum.UserInputType.Keyboard then
        if input.KeyCode == CONFIG.MenuKey then
            main.Visible = not main.Visible
            circle.Visible = main.Visible
            return
        end

        if input.KeyCode == CONFIG.AimKey and not processed then
            setEnabled(not CONFIG.Enabled)
        end
    end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        holdingAim = true

        if CONFIG.Enabled then
            setTarget(selectTarget())
        end
    end
end)

connect(UIS.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        holdingAim = false
        clearTarget()
    end
end)

--==================================================
-- Main camera update
--==================================================

RunService:BindToRenderStep(
    RENDER_NAME,
    Enum.RenderPriority.Camera.Value + 1,
    function(dt)
        if not alive then
            return
        end

        camera = Workspace.CurrentCamera

        if not camera then
            statusLabel.Text = "Status: camera unavailable"
            return
        end

        updateESP()

        local mouse = getViewportMouse()

        circle.Position = UDim2.fromOffset(mouse.X, mouse.Y)
        circle.Size = UDim2.fromOffset(CONFIG.FOV * 2, CONFIG.FOV * 2)

        if not CONFIG.Enabled then
            statusLabel.Text = "Status: disabled"
            return
        end

        if not holdingAim
            or not UIS:IsMouseButtonPressed(
                Enum.UserInputType.MouseButton2
            ) then
            statusLabel.Text = "Status: hold RMB to lock"
            return
        end

        local humanoid = targetModel
            and targetModel:FindFirstChildOfClass("Humanoid")

        local head = getHead(targetModel)

        local invalid = not targetModel
            or not targetModel.Parent
            or not humanoid
            or humanoid.Health <= 0
            or not head
            or (CONFIG.TeamCheck and isFriendly(targetModel))
            or (CONFIG.WallCheck
                and head
                and not hasLineOfSight(head, targetModel))

        if invalid then
            setTarget(nil)
            setTarget(selectTarget())
        end

        if not targetModel then
            statusLabel.Text = "Status: no visible target in FOV"
            reasonLabel.Text = "Check team, FOV, and line of sight"
            return
        end

        head = getHead(targetModel)

        if not head then
            clearTarget()
            statusLabel.Text = "Status: target head missing"
            return
        end

        local point, onScreen = camera:WorldToViewportPoint(head.Position)

        local distance = (
            Vector2.new(point.X, point.Y) - mouse
        ).Magnitude

        if not onScreen or point.Z <= 0 or distance > CONFIG.FOV then
            setTarget(nil)
            setTarget(selectTarget())

            if not targetModel then
                statusLabel.Text = "Status: no target in FOV"
                return
            end

            head = getHead(targetModel)

            if not head then
                clearTarget()
                return
            end
        end

        statusLabel.Text = "Status: tracking head"
        targetLabel.Text = "Target: " .. targetModel.Name
        reasonLabel.Text = "Release RMB to unlock"

        local smoothing = CONFIG.Mode == "Aimbot"
            and 1
            or CONFIG.Smoothness

        local alpha = 1 - math.exp(-dt * (30 / smoothing))

        local desired = CFrame.lookAt(
            camera.CFrame.Position,
            head.Position
        )

        camera.CFrame = camera.CFrame:Lerp(desired, alpha)
    end
)

-- Respawn support.
connect(LocalPlayer.CharacterAdded, function()
    holdingAim = false
    clearTarget()
end)

-- Cleanup when the GUI is destroyed.
connect(gui.Destroying, function()
    alive = false
    RunService:UnbindFromRenderStep(RENDER_NAME)

    for _, connection in ipairs(connections) do
        if connection.Connected then
            connection:Disconnect()
        end
    end

    local models = {}

    for model in pairs(espObjects) do
        table.insert(models, model)
    end

    for _, model in ipairs(models) do
        removeESP(model)
    end

    if targetHighlight then
        targetHighlight:Destroy()
        targetHighlight = nil
    end
end)

updateButtons()
refreshESP()
