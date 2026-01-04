-- ROBLOX ESP SCRIPT v2.0 by Plutana-eng
-- Complete ESP with Boxes, Names, Health, Distance, and Team Colors
-- Works with any executor (Synapse, Krnl, Fluxus, etc.)

-- =================== CONFIGURATION ===================
local ESP_SETTINGS = {
    -- Toggle Features
    ENABLED = true,
    SHOW_BOX = true,
    SHOW_NAME = true,
    SHOW_DISTANCE = true,
    SHOW_HEALTH = true,
    SHOW_TRACER = false,  -- Line from bottom to player
    SHOW_HEALTH_BAR = true,
    
    -- Colors
    TEAM_COLOR = Color3.fromRGB(0, 255, 0),      -- Green for teammates
    ENEMY_COLOR = Color3.fromRGB(255, 0, 0),     -- Red for enemies
    DEAD_COLOR = Color3.fromRGB(128, 128, 128),  -- Gray for dead players
    TEXT_COLOR = Color3.fromRGB(255, 255, 255),  -- White text
    
    -- Visual Settings
    BOX_THICKNESS = 1,
    BOX_TRANSPARENCY = 0.3,
    TEXT_SIZE = 14,
    TEXT_FONT = Enum.Font.SourceSansBold,
    MAX_DISTANCE = 2000,  -- Max distance to show ESP (in studs)
    
    -- Health Bar Settings
    HEALTH_BAR_WIDTH = 50,
    HEALTH_BAR_HEIGHT = 4,
    
    -- Tracer Settings
    TRACER_COLOR = Color3.fromRGB(255, 255, 255),
    TRACER_THICKNESS = 1,
    
    -- Advanced
    CHECK_VISIBILITY = true,  -- Only show visible players (raycast check)
    UPDATE_RATE = 0.1,        -- Update interval in seconds
    FADE_DISTANCE = true,     -- Fade ESP based on distance
}

-- =================== SERVICES ===================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- =================== ESP MANAGEMENT ===================
local ESP_Objects = {}
local ESP_Folders = {}

-- Create drawing objects
function CreateDrawing(type, properties)
    local drawing = Drawing.new(type)
    for prop, value in pairs(properties) do
        drawing[prop] = value
    end
    return drawing
end

-- Create ESP for a player
function CreatePlayerESP(player)
    if player == LocalPlayer then return end
    if ESP_Objects[player] then return end
    
    local esp = {
        player = player,
        drawings = {},
        connections = {},
        visible = false
    }
    
    -- Create drawings
    if ESP_SETTINGS.SHOW_BOX then
        esp.drawings.box = CreateDrawing("Square", {
            Thickness = ESP_SETTINGS.BOX_THICKNESS,
            Filled = false,
            Transparency = 1,
            Visible = false
        })
    end
    
    if ESP_SETTINGS.SHOW_NAME then
        esp.drawings.name = CreateDrawing("Text", {
            Size = ESP_SETTINGS.TEXT_SIZE,
            Center = true,
            Outline = true,
            OutlineColor = Color3.new(0, 0, 0),
            Visible = false
        })
    end
    
    if ESP_SETTINGS.SHOW_DISTANCE then
        esp.drawings.distance = CreateDrawing("Text", {
            Size = ESP_SETTINGS.TEXT_SIZE - 2,
            Center = true,
            Outline = true,
            OutlineColor = Color3.new(0, 0, 0),
            Visible = false
        })
    end
    
    if ESP_SETTINGS.SHOW_HEALTH_BAR then
        esp.drawings.healthBarBG = CreateDrawing("Square", {
            Thickness = 1,
            Filled = true,
            Transparency = 0.5,
            Color = Color3.new(0, 0, 0),
            Visible = false
        })
        
        esp.drawings.healthBar = CreateDrawing("Square", {
            Thickness = 1,
            Filled = true,
            Transparency = 0.8,
            Visible = false
        })
    end
    
    if ESP_SETTINGS.SHOW_TRACER then
        esp.drawings.tracer = CreateDrawing("Line", {
            Thickness = ESP_SETTINGS.TRACER_THICKNESS,
            Visible = false
        })
    end
    
    ESP_Objects[player] = esp
    
    -- Setup connections
    esp.connections.heartbeat = RunService.Heartbeat:Connect(function()
        UpdatePlayerESP(player)
    end)
    
    esp.connections.characterAdded = player.CharacterAdded:Connect(function(character)
        wait(1)  -- Wait for character to load
        UpdatePlayerESP(player)
    end)
    
    esp.connections.characterRemoving = player.CharacterRemoving:Connect(function()
        RemovePlayerESP(player)
    end)
    
    if player.Character then
        UpdatePlayerESP(player)
    end
end

-- Update player ESP
function UpdatePlayerESP(player)
    local esp = ESP_Objects[player]
    if not esp or not ESP_SETTINGS.ENABLED then return end
    
    local character = player.Character
    if not character then
        HideESP(player)
        return
    end
    
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local head = character:FindFirstChild("Head")
    
    if not humanoid or not rootPart or not head then
        HideESP(player)
        return
    end
    
    -- Check if player is alive
    local isAlive = humanoid.Health > 0
    if not isAlive then
        HideESP(player)
        return
    end
    
    -- Get screen position
    local rootPos, rootOnScreen = Camera:WorldToViewportPoint(rootPart.Position)
    local headPos, headOnScreen = Camera:WorldToViewportPoint(head.Position)
    
    if not rootOnScreen and not headOnScreen then
        HideESP(player)
        return
    end
    
    -- Calculate box dimensions
    local height = math.abs(headPos.Y - rootPos.Y)
    local width = height / 2
    local boxY = headPos.Y - height * 0.1
    local boxX = headPos.X - width / 2
    
    -- Check distance
    local localRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local distance = 0
    if localRoot then
        distance = (rootPart.Position - localRoot.Position).Magnitude
    end
    
    if distance > ESP_SETTINGS.MAX_DISTANCE then
        HideESP(player)
        return
    end
    
    -- Check visibility (raycast)
    if ESP_SETTINGS.CHECK_VISIBILITY then
        local ray = Ray.new(Camera.CFrame.Position, (rootPart.Position - Camera.CFrame.Position).Unit * distance)
        local hit, position = Workspace:FindPartOnRayWithIgnoreList(ray, {Camera, LocalPlayer.Character, character})
        
        if hit and hit:IsDescendantOf(character) then
            -- Player is visible
        else
            HideESP(player)
            return
        end
    end
    
    -- Determine color based on team
    local teamColor = ESP_SETTINGS.ENEMY_COLOR
    if player.Team == LocalPlayer.Team then
        teamColor = ESP_SETTINGS.TEAM_COLOR
    end
    
    -- Apply fade based on distance if enabled
    local alpha = 1
    if ESP_SETTINGS.FADE_DISTANCE then
        alpha = math.clamp(1 - (distance / ESP_SETTINGS.MAX_DISTANCE), 0.3, 1)
    end
    
    -- Update box
    if esp.drawings.box then
        esp.drawings.box.Visible = ESP_SETTINGS.SHOW_BOX and rootOnScreen
        esp.drawings.box.Size = Vector2.new(width, height)
        esp.drawings.box.Position = Vector2.new(boxX, boxY)
        esp.drawings.box.Color = teamColor
        esp.drawings.box.Transparency = 1 - (ESP_SETTINGS.BOX_TRANSPARENCY * alpha)
    end
    
    -- Update name
    if esp.drawings.name then
        esp.drawings.name.Visible = ESP_SETTINGS.SHOW_NAME and rootOnScreen
        esp.drawings.name.Text = player.Name
        esp.drawings.name.Position = Vector2.new(headPos.X, boxY - 20)
        esp.drawings.name.Color = ESP_SETTINGS.TEXT_COLOR
    end
    
    -- Update distance
    if esp.drawings.distance then
        esp.drawings.distance.Visible = ESP_SETTINGS.SHOW_DISTANCE and rootOnScreen
        esp.drawings.distance.Text = string.format("[%dm]", math.floor(distance))
        esp.drawings.distance.Position = Vector2.new(headPos.X, boxY + height + 5)
        esp.drawings.distance.Color = ESP_SETTINGS.TEXT_COLOR
    end
    
    -- Update health bar
    if esp.drawings.healthBarBG and esp.drawings.healthBar then
        local healthPercent = humanoid.Health / humanoid.MaxHealth
        local healthBarWidth = ESP_SETTINGS.HEALTH_BAR_WIDTH
        local healthBarHeight = ESP_SETTINGS.HEALTH_BAR_HEIGHT
        
        esp.drawings.healthBarBG.Visible = ESP_SETTINGS.SHOW_HEALTH_BAR and rootOnScreen
        esp.drawings.healthBarBG.Size = Vector2.new(healthBarWidth, healthBarHeight)
        esp.drawings.healthBarBG.Position = Vector2.new(headPos.X - healthBarWidth/2, boxY + height + 20)
        
        esp.drawings.healthBar.Visible = ESP_SETTINGS.SHOW_HEALTH_BAR and rootOnScreen
        esp.drawings.healthBar.Size = Vector2.new(healthBarWidth * healthPercent, healthBarHeight)
        esp.drawings.healthBar.Position = Vector2.new(headPos.X - healthBarWidth/2, boxY + height + 20)
        
        -- Health bar color (green to red)
        esp.drawings.healthBar.Color = Color3.new(
            1 - healthPercent,
            healthPercent,
            0
        )
    end
    
    -- Update tracer
    if esp.drawings.tracer then
        esp.drawings.tracer.Visible = ESP_SETTINGS.SHOW_TRACER and rootOnScreen
        esp.drawings.tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
        esp.drawings.tracer.To = Vector2.new(rootPos.X, rootPos.Y)
        esp.drawings.tracer.Color = ESP_SETTINGS.TRACER_COLOR
    end
    
    esp.visible = true
end

-- Hide ESP
function HideESP(player)
    local esp = ESP_Objects[player]
    if not esp then return end
    
    for _, drawing in pairs(esp.drawings) do
        if drawing then
            drawing.Visible = false
        end
    end
    
    esp.visible = false
end

-- Remove ESP completely
function RemovePlayerESP(player)
    local esp = ESP_Objects[player]
    if not esp then return end
    
    -- Disconnect connections
    for _, connection in pairs(esp.connections) do
        if connection then
            connection:Disconnect()
        end
    end
    
    -- Remove drawings
    for _, drawing in pairs(esp.drawings) do
        if drawing then
            drawing:Remove()
        end
    end
    
    ESP_Objects[player] = nil
end

-- Clean up all ESP
function ClearAllESP()
    for player, esp in pairs(ESP_Objects) do
        RemovePlayerESP(player)
    end
    ESP_Objects = {}
end

-- =================== INITIALIZATION ===================
function InitializeESP()
    -- Clear any existing ESP
    ClearAllESP()
    
    -- Create ESP for existing players
    for _, player in pairs(Players:GetPlayers()) do
        CreatePlayerESP(player)
    end
    
    -- Handle new players
    Players.PlayerAdded:Connect(function(player)
        CreatePlayerESP(player)
    end)
    
    -- Handle leaving players
    Players.PlayerRemoving:Connect(function(player)
        RemovePlayerESP(player)
    end)
    
    -- Handle LocalPlayer team changes
    LocalPlayer:GetPropertyChangedSignal("Team"):Connect(function()
        for player, esp in pairs(ESP_Objects) do
            if esp.visible then
                UpdatePlayerESP(player)
            end
        end
    end)
    
    print("[ESP] ESP by Plutana-eng initialized successfully!")
    print("[ESP] Features: Box, Name, Distance, Health Bar")
    print("[ESP] Distance limit: " .. ESP_SETTINGS.MAX_DISTANCE .. " studs")
end

-- =================== COMMANDS & UI ===================
-- Toggle ESP
function ToggleESP()
    ESP_SETTINGS.ENABLED = not ESP_SETTINGS.ENABLED
    if ESP_SETTINGS.ENABLED then
        print("[ESP] ESP ENABLED")
        for player, esp in pairs(ESP_Objects) do
            if esp.visible then
                UpdatePlayerESP(player)
            end
        end
    else
        print("[ESP] ESP DISABLED")
        for player, esp in pairs(ESP_Objects) do
            HideESP(player)
        end
    end
end

-- Toggle specific features
function ToggleFeature(feature)
    if ESP_SETTINGS[feature] ~= nil then
        ESP_SETTINGS[feature] = not ESP_SETTINGS[feature]
        print("[ESP] " .. feature .. ": " .. tostring(ESP_SETTINGS[feature]))
        for player, esp in pairs(ESP_Objects) do
            if esp.visible then
                UpdatePlayerESP(player)
            end
        end
    end
end

-- Change color
function ChangeColor(colorType, r, g, b)
    if colorType == "team" then
        ESP_SETTINGS.TEAM_COLOR = Color3.fromRGB(r, g, b)
    elseif colorType == "enemy" then
        ESP_SETTINGS.ENEMY_COLOR = Color3.fromRGB(r, g, b)
    elseif colorType == "text" then
        ESP_SETTINGS.TEXT_COLOR = Color3.fromRGB(r, g, b)
    end
    print("[ESP] Color updated")
end

-- Set max distance
function SetMaxDistance(distance)
    ESP_SETTINGS.MAX_DISTANCE = distance
    print("[ESP] Max distance set to: " .. distance .. " studs")
end

-- Help command
function ShowHelp()
    print("\n=== ESP COMMANDS ===")
    print("ToggleESP() - Toggle ESP on/off")
    print("ToggleFeature('SHOW_BOX') - Toggle boxes")
    print("ToggleFeature('SHOW_NAME') - Toggle names")
    print("ToggleFeature('SHOW_DISTANCE') - Toggle distance")
    print("ToggleFeature('SHOW_HEALTH_BAR') - Toggle health bars")
    print("ChangeColor('team', 0, 255, 0) - Change team color")
    print("ChangeColor('enemy', 255, 0, 0) - Change enemy color")
    print("SetMaxDistance(1000) - Set max render distance")
    print("ClearAllESP() - Remove all ESP")
    print("ShowHelp() - Show this menu")
    print("====================\n")
end

-- Add commands to global namespace
getgenv().ToggleESP = ToggleESP
getgenv().ToggleFeature = ToggleFeature
getgenv().ChangeColor = ChangeColor
getgenv().SetMaxDistance = SetMaxDistance
getgenv().ClearAllESP = ClearAllESP
getgenv().ShowHelp = ShowHelp

-- =================== EXECUTION ===================
-- Wait for game to load
if not LocalPlayer or not Camera then
    repeat wait() until LocalPlayer and Camera
end

-- Initialize ESP
InitializeESP()

-- Auto-cleanup on script re-execution
if _G.PlutanaESP then
    _G.PlutanaESP:Disconnect()
end

_G.PlutanaESP = game:GetService("LogService").MessageOut:Connect(function(message, messageType)
    if message:find("ESP by Plutana-eng initialized") then
        -- Script was re-executed, cleanup old instances
        ClearAllESP()
        _G.PlutanaESP:Disconnect()
    end
end)

-- Success message
print("\n" .. string.rep("=", 50))
print("ESP v2.0 by Plutana-eng")
print("Loaded Successfully!")
print("Type 'ShowHelp()' for commands")
print(string.rep("=", 50) .. "\n")
