--[[
    NightScript.lua
    Night Rider [TESTING] - Auto Lane prototype
    Version: 0.1.0

    PC prototype:
      A = steer left
      D = steer right

    The script waits for the motorcycle to be moving before attempting
    a lane change. It alternates directions and checks the adjacent lane
    with short forward raycasts before sending an input.

    IMPORTANT:
      - This is an independent, clean implementation; it does not copy
        the obfuscated NightRider.lua source.
      - LaneOffset and SteerDuration may need tuning for the active bike.
      - Use only where permitted by the game/platform rules.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    EnabledOnStart = false,

    -- Fixed delay between successful lane changes.
    IntervalSeconds = 10,

    -- Do not steer unless horizontal speed is above this value (studs/sec).
    MinSpeed = 28,

    -- Distance from the bike to the center of the neighboring lane.
    -- Adjust this if the bike does not line up with the next lane.
    LaneOffset = 10,

    -- How far ahead to check for traffic in the target lane.
    LookAhead = 65,

    -- Short steering pulses are used to reach the adjacent lane center.
    SteerDuration = 0.10,
    CenterTolerance = 1.0,
    CenterTimeout = 3.0,
    CenterSettleTime = 0.05,

    -- Retry sooner when both neighboring lanes appear blocked.
    BlockedRetry = 8,

    -- Small delay after a lane change before another input is considered.
    PostChangeDelay = 1.25,
}

local running = true
local enabled = CONFIG.EnabledOnStart
local preferredDirection = (math.random(0, 1) == 0) and -1 or 1
local nextChangeAt = os.clock() + CONFIG.IntervalSeconds

local function getCharacterParts()
    local character = LocalPlayer.Character
    if not character then
        return nil, nil, nil
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return character, humanoid, nil
    end

    return character, humanoid, root
end

local function getVehicleAndSpeed()
    local character, humanoid, root = getCharacterParts()
    if not character or not humanoid or not root then
        return character, humanoid, root, 0
    end

    local velocitySource = humanoid.SeatPart or root
    local velocity = velocitySource.AssemblyLinearVelocity
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)

    return character, humanoid, root, horizontalVelocity.Magnitude
end

local function getFlatDirections(root)
    local look = root.CFrame.LookVector
    local forward = Vector3.new(look.X, 0, look.Z)

    if forward.Magnitude < 0.001 then
        return nil, nil
    end

    forward = forward.Unit
    local right = Vector3.new(-forward.Z, 0, forward.X)

    return forward, right
end

local function makeRaycastParams(character, humanoid)
    local ignored = { character }

    if humanoid and humanoid.SeatPart then
        local bikeModel = humanoid.SeatPart:FindFirstAncestorOfClass("Model")
        if bikeModel then
            table.insert(ignored, bikeModel)
        end
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignored
    params.IgnoreWater = true

    return params
end

local function isAdjacentLaneClear(root, character, humanoid, direction)
    local forward, right = getFlatDirections(root)
    if not forward or not right then
        return false
    end

    local params = makeRaycastParams(character, humanoid)
    local lateralOffset = right * (CONFIG.LaneOffset * direction)
    local startPoint = root.Position + lateralOffset + forward * 7

    -- Three rays help detect cars at different body heights.
    local heights = { -0.5, 0.8, 2.0 }

    for _, height in ipairs(heights) do
        local origin = startPoint + Vector3.new(0, height, 0)
        local hit = Workspace:Raycast(
            origin,
            forward * CONFIG.LookAhead,
            params
        )

        if hit then
            return false, hit.Instance
        end
    end

    return true
end

local function tapSteeringKey(direction)
    local keyCode = (direction < 0) and Enum.KeyCode.A or Enum.KeyCode.D
    local virtualKey = (direction < 0) and 0x41 or 0x44

    -- Prefer executor keypress/keyrelease when available.
    if type(keypress) == "function" and type(keyrelease) == "function" then
        local pressed = pcall(keypress, virtualKey)
        if pressed then
            task.wait(CONFIG.SteerDuration)
            pcall(keyrelease, virtualKey)
            return true
        end
    end

    -- Fallback for environments that expose VirtualInputManager.
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(CONFIG.SteerDuration)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)

    return ok
end

-- Change lanes in short pulses and stop once the bike reaches the target
-- lateral offset. The starting right-vector is kept as the lane reference
-- while the bike completes this short maneuver.
local function centerAdjacentLane(root, direction)
    local _, right = getFlatDirections(root)
    if not right then
        return false
    end

    local startPosition = root.Position
    local targetOffset = CONFIG.LaneOffset * direction
    local deadline = os.clock() + CONFIG.CenterTimeout

    while root.Parent and os.clock() < deadline do
        local displacement = root.Position - startPosition
        local horizontalDisplacement = Vector3.new(
            displacement.X, 0, displacement.Z
        )
        local currentOffset = horizontalDisplacement:Dot(right)
        local remaining = targetOffset - currentOffset

        if math.abs(remaining) <= CONFIG.CenterTolerance then
            return true
        end

        local correction = remaining > 0 and 1 or -1
        if not tapSteeringKey(correction) then
            return false
        end
        task.wait(CONFIG.CenterSettleTime)
    end

    if not root.Parent then
        return false
    end

    local displacement = root.Position - startPosition
    local horizontalDisplacement = Vector3.new(
        displacement.X, 0, displacement.Z
    )
    local finalOffset = horizontalDisplacement:Dot(right)
    return math.abs(targetOffset - finalOffset) <= CONFIG.CenterTolerance * 1.5
end

-- Minimal movable-feeling control panel.
local gui = Instance.new("ScreenGui")
gui.Name = "NightScriptUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 900

local guiParent
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then
        guiParent = result
    end
end
gui.Parent = guiParent or LocalPlayer:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "Main"
frame.Size = UDim2.fromOffset(250, 132)
frame.Position = UDim2.new(0, 22, 0.5, -66)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 31)
frame.BorderSizePixel = 0
frame.Parent = gui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 10)
frameCorner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 145, 220)
stroke.Thickness = 1
stroke.Transparency = 0.25
stroke.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -18, 0, 27)
title.Position = UDim2.fromOffset(10, 7)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.Text = "NIGHT SCRIPT  |  AUTO LANE"
title.TextColor3 = Color3.fromRGB(230, 240, 255)
title.TextSize = 12
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -20, 0, 34)
toggleButton.Position = UDim2.fromOffset(10, 39)
toggleButton.BackgroundColor3 = Color3.fromRGB(37, 105, 170)
toggleButton.BorderSizePixel = 0
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 12
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Parent = frame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 7)
buttonCorner.Parent = toggleButton

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -20, 0, 35)
statusLabel.Position = UDim2.fromOffset(10, 82)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.TextColor3 = Color3.fromRGB(185, 198, 215)
statusLabel.TextWrapped = true
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Parent = frame

local unloadButton = Instance.new("TextButton")
unloadButton.Size = UDim2.fromOffset(22, 22)
unloadButton.Position = UDim2.new(1, -28, 0, 5)
unloadButton.BackgroundColor3 = Color3.fromRGB(55, 61, 73)
unloadButton.BorderSizePixel = 0
unloadButton.Font = Enum.Font.GothamBold
unloadButton.Text = "×"
unloadButton.TextSize = 16
unloadButton.TextColor3 = Color3.fromRGB(255, 255, 255)
unloadButton.Parent = frame

local unloadCorner = Instance.new("UICorner")
unloadCorner.CornerRadius = UDim.new(0, 6)
unloadCorner.Parent = unloadButton

local function setStatus(message)
    if statusLabel and statusLabel.Parent then
        statusLabel.Text = message
    end
end

local function refreshButton()
    if not toggleButton or not toggleButton.Parent then
        return
    end

    if enabled then
        toggleButton.Text = "AUTO LANE: ON"
        toggleButton.BackgroundColor3 = Color3.fromRGB(34, 139, 91)
    else
        toggleButton.Text = "AUTO LANE: OFF"
        toggleButton.BackgroundColor3 = Color3.fromRGB(37, 105, 170)
    end
end

local function setEnabled(value)
    enabled = value
    nextChangeAt = os.clock() + CONFIG.IntervalSeconds
    refreshButton()

    if enabled then
        setStatus("Activo. Esperando velocidad de autopista...")
    else
        setStatus("Pausado. Pulsa el botón para activar.")
    end
end

toggleButton.MouseButton1Click:Connect(function()
    setEnabled(not enabled)
end)

-- RightShift shows/hides the panel.
local inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == Enum.KeyCode.RightShift then
        frame.Visible = not frame.Visible
    end
end)

local function unload()
    running = false
    enabled = false

    if inputConnection then
        inputConnection:Disconnect()
    end

    if gui then
        gui:Destroy()
    end
end

unloadButton.MouseButton1Click:Connect(unload)
refreshButton()
setStatus("Pausado. Actívalo cuando estés conduciendo.")

task.spawn(function()
    while running do
        if enabled then
            local character, humanoid, root, speed = getVehicleAndSpeed()

            if not character or not humanoid or not root then
                setStatus("Esperando a que aparezca la moto/personaje...")
            elseif speed < CONFIG.MinSpeed then
                setStatus(string.format(
                    "Esperando velocidad...  %.0f studs/s",
                    speed
                ))
            elseif os.clock() >= nextChangeAt then
                local firstDirection = preferredDirection
                local secondDirection = -preferredDirection

                local firstClear = isAdjacentLaneClear(
                    root, character, humanoid, firstDirection
                )

                local chosenDirection

                if firstClear then
                    chosenDirection = firstDirection
                else
                    local secondClear = isAdjacentLaneClear(
                        root, character, humanoid, secondDirection
                    )

                    if secondClear then
                        chosenDirection = secondDirection
                    end
                end

                if chosenDirection then
                    local sent = centerAdjacentLane(root, chosenDirection)

                    if sent then
                        preferredDirection = -chosenDirection
                        setStatus(
                            (chosenDirection < 0 and "Carril izquierdo" or "Carril derecho")
                            .. " | Centrado | Próximo cambio en "
                            .. tostring(CONFIG.IntervalSeconds)
                            .. " s"
                        )
                        task.wait(CONFIG.PostChangeDelay)
                        nextChangeAt = os.clock() + CONFIG.IntervalSeconds
                    else
                        setStatus("No se pudo enviar A/D en este executor.")
                        nextChangeAt = os.clock() + CONFIG.BlockedRetry
                    end
                else
                    setStatus("Carriles cercanos ocupados. Reintentando...")
                    nextChangeAt = os.clock() + CONFIG.BlockedRetry
                end
            else
                local remaining = math.max(0, math.floor(nextChangeAt - os.clock()))
                setStatus(string.format(
                    "Conduciendo | %.0f studs/s | Cambio en %ds",
                    speed,
                    remaining
                ))
            end
        end

        task.wait(0.25)
    end
end)

