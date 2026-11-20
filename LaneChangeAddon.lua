--[[
    NightScript - Lane Change Companion
    Target: Night Rider [TESTING] (Roblox), PC controls
    Version: 0.3.0

    Run alongside the existing farming routine.
    Start your farm first, then enable this companion with its UI button.

    Behavior:
      - Requires the character to be seated in a vehicle.
      - Requires a minimum horizontal speed.
      - Alternates A and D once per configured interval.
      - Never attempts to hide automation or bypass anti-cheat systems.

    Controls:
      - UI button: enable/disable lane changes.
      - RightShift: show/hide the small panel.
      - Close button: stop this companion.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    StartEnabled = false,

    -- Gentle left-right weaving: one small nudge about every 0.4 seconds.
    IntervalSeconds = 0.4,

    -- Tiny steering pulse to make only a slight side-to-side movement.
    SteerHoldSeconds = 0.02,

    -- Avoid steering while stationary or moving very slowly.
    MinSpeed = 15,

    TogglePanelKey = Enum.KeyCode.RightShift,
}

local enabled = CONFIG.StartEnabled
local running = true
local nextChangeAt = os.clock() + CONFIG.IntervalSeconds
local nextDirection = "A"

local function getDrivingState()
    local character = LocalPlayer.Character
    if not character then
        return false, 0, "Esperando personaje..."
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local root = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not root then
        return false, 0, "Esperando personaje..."
    end

    local seat = humanoid.SeatPart
    if not seat then
        return false, 0, "Sube a la moto para activar los cambios."
    end

    local velocityPart = seat
    local velocity = velocityPart.AssemblyLinearVelocity
    local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

    if horizontalSpeed < CONFIG.MinSpeed then
        return false, horizontalSpeed, string.format(
            "Esperando velocidad... %.0f studs/s",
            horizontalSpeed
        )
    end

    return true, horizontalSpeed, "Conduciendo", root
end

local function sendSteeringKey(keyName)
    local keyCode = keyName == "A" and Enum.KeyCode.A or Enum.KeyCode.D
    local virtualKey = keyName == "A" and 0x41 or 0x44

    -- Common executor input API.
    if type(keypress) == "function" and type(keyrelease) == "function" then
        local ok = pcall(function()
            keypress(virtualKey)
            task.wait(CONFIG.SteerHoldSeconds)
            keyrelease(virtualKey)
        end)

        if ok then
            return true
        end

        -- Make a best-effort release if the hold was interrupted.
        pcall(keyrelease, virtualKey)
    end

    -- Fallback when VirtualInputManager input is available.
    local ok = pcall(function()
        VirtualInputManager:SendKeyEvent(true, keyCode, false, game)
        task.wait(CONFIG.SteerHoldSeconds)
        VirtualInputManager:SendKeyEvent(false, keyCode, false, game)
    end)

    return ok
end

-- Send only one short input pulse; repeated corrections can make the bike
-- keep turning and overshoot its lane.
local function nudgeToAdjacentLane(root, directionKey)
    if not root or not root.Parent then
        return false
    end

    return sendSteeringKey(directionKey)
end

-- Minimal panel.
local gui = Instance.new("ScreenGui")
gui.Name = "NightScriptLaneCompanion"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 950

local guiParent
if type(gethui) == "function" then
    local ok, result = pcall(gethui)
    if ok and result then
        guiParent = result
    end
end

gui.Parent = guiParent or LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(265, 126)
panel.Position = UDim2.new(0, 24, 0.55, -63)
panel.BackgroundColor3 = Color3.fromRGB(19, 23, 32)
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local outline = Instance.new("UIStroke")
outline.Color = Color3.fromRGB(75, 145, 215)
outline.Transparency = 0.2
outline.Thickness = 1
outline.Parent = panel

local heading = Instance.new("TextLabel")
heading.BackgroundTransparency = 1
heading.Position = UDim2.fromOffset(12, 8)
heading.Size = UDim2.new(1, -48, 0, 22)
heading.Font = Enum.Font.GothamBold
heading.Text = "NIGHT SCRIPT  /  LANE CHANGE"
heading.TextSize = 11
heading.TextColor3 = Color3.fromRGB(230, 239, 250)
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = panel

local close = Instance.new("TextButton")
close.Size = UDim2.fromOffset(24, 22)
close.Position = UDim2.new(1, -30, 0, 7)
close.BackgroundColor3 = Color3.fromRGB(58, 64, 76)
close.BorderSizePixel = 0
close.Text = "×"
close.Font = Enum.Font.GothamBold
close.TextSize = 16
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.Parent = panel

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 5)
closeCorner.Parent = close

local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -24, 0, 34)
toggle.Position = UDim2.fromOffset(12, 37)
toggle.BackgroundColor3 = Color3.fromRGB(43, 105, 166)
toggle.BorderSizePixel = 0
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 12
toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
toggle.Parent = panel

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 7)
toggleCorner.Parent = toggle

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Position = UDim2.fromOffset(12, 79)
status.Size = UDim2.new(1, -24, 0, 38)
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.TextColor3 = Color3.fromRGB(186, 198, 215)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.TextWrapped = true
status.Text = "Desactivado. Inicia el farmeo y activa este complemento."
status.Parent = panel

local function refresh()
    if enabled then
        toggle.Text = "CAMBIO DE CARRIL: ON"
        toggle.BackgroundColor3 = Color3.fromRGB(34, 133, 88)
    else
        toggle.Text = "CAMBIO DE CARRIL: OFF"
        toggle.BackgroundColor3 = Color3.fromRGB(43, 105, 166)
    end
end

local function setEnabled(value)
    enabled = value
    nextChangeAt = os.clock() + CONFIG.IntervalSeconds
    refresh()

    if enabled then
        status.Text = string.format("Activo. Cambiará de carril cada %d segundos.", CONFIG.IntervalSeconds)
    else
        status.Text = "Desactivado."
    end
end

toggle.MouseButton1Click:Connect(function()
    setEnabled(not enabled)
end)

local keyConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then
        return
    end

    if input.KeyCode == CONFIG.TogglePanelKey then
        panel.Visible = not panel.Visible
    end
end)

local function stop()
    running = false
    enabled = false

    if keyConnection then
        keyConnection:Disconnect()
    end

    gui:Destroy()
end

close.MouseButton1Click:Connect(stop)
refresh()

task.spawn(function()
    while running do
        if enabled then
            local canSteer, speed, stateMessage, root = getDrivingState()

            if not canSteer then
                status.Text = stateMessage
            elseif os.clock() >= nextChangeAt then
                local direction = nextDirection
                local ok = nudgeToAdjacentLane(root, direction)

                if ok then
                    nextDirection = direction == "A" and "D" or "A"
                    nextChangeAt = os.clock() + CONFIG.IntervalSeconds
                    status.Text = string.format(
                        "Toque corto: %s | Próximo en %d s | %.0f studs/s",
                        direction == "A" and "izquierda" or "derecha",
                        CONFIG.IntervalSeconds,
                        speed
                    )
                else
                    nextChangeAt = os.clock() + 5
                    status.Text = "No se pudo enviar el toque. Reintentando..."
                end
            else
                local remaining = math.max(0, math.ceil(nextChangeAt - os.clock()))
                status.Text = string.format(
                    "Conduciendo | %.0f studs/s | Próximo cambio en %ds",
                    speed,
                    remaining
                )
            end
        end

        task.wait(0.25)
    end
end)
