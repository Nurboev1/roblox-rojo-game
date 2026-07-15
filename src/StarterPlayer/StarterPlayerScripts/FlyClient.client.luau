
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local flyEvent = ReplicatedStorage:WaitForChild("FlyEvent")

local keys = {W = false, A = false, S = false, D = false}
local isFlying = false

flyEvent.OnClientEvent:Connect(function(status)
    isFlying = status
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.W then keys.W = true end
    if input.KeyCode == Enum.KeyCode.A then keys.A = true end
    if input.KeyCode == Enum.KeyCode.S then keys.S = true end
    if input.KeyCode == Enum.KeyCode.D then keys.D = true end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.W then keys.W = false end
    if input.KeyCode == Enum.KeyCode.A then keys.A = false end
    if input.KeyCode == Enum.KeyCode.S then keys.S = false end
    if input.KeyCode == Enum.KeyCode.D then keys.D = false end
end)

RunService.RenderStepped:Connect(function()
    if not player.Character then return end
    local humanoid = player.Character:FindFirstChild("Humanoid")
    local hrp = player.Character:FindFirstChild("HumanoidRootPart")
    if not humanoid or not hrp then return end

    local camera = workspace.CurrentCamera
    
    if isFlying then
        humanoid.AutoRotate = false
        hrp.CFrame = CFrame.new(hrp.Position, hrp.Position + camera.CFrame.LookVector)
        
        local dir = Vector3.new(0, 0, 0)
        if keys.W then dir = dir + camera.CFrame.LookVector end
        if keys.S then dir = dir - camera.CFrame.LookVector end
        if keys.A then dir = dir - camera.CFrame.RightVector end
        if keys.D then dir = dir + camera.CFrame.RightVector end
        
        flyEvent:FireServer(dir.Unit.Magnitude > 0 and dir.Unit or Vector3.new(0, 0, 0), camera.CFrame)
    else
        humanoid.AutoRotate = true
    end
end)
