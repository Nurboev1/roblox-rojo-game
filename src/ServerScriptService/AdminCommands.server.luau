

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ADMINS = {
    ["Snubix_s"] = true,
    ["nurboyevn"] = true
}

local flyEvent = ReplicatedStorage:FindFirstChild("FlyEvent") or Instance.new("RemoteEvent")
flyEvent.Name = "FlyEvent"
flyEvent.Parent = ReplicatedStorage

local function handleChat(player, message)
    if not ADMINS[player.Name] then return end

    local args = string.split(message, " ")
    local command = string.lower(args[1])

    if command == "/fly" then
        local character = player.Character
        if not character then return end
        local hrp = character:FindFirstChild("HumanoidRootPart")
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not hrp or not humanoid then return end

        local flyBody = hrp:FindFirstChild("FlyBody")
        if flyBody then
            flyBody:Destroy()
            local gyro = hrp:FindFirstChild("FlyGyro")
            if gyro then gyro:Destroy() end
            humanoid.PlatformStand = false
            flyEvent:FireClient(player, false)
        else
            humanoid.PlatformStand = true
            flyBody = Instance.new("BodyVelocity")
            flyBody.Name = "FlyBody"
            flyBody.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
            flyBody.Velocity = Vector3.new(0, 0, 0)
            flyBody.Parent = hrp
            
            local gyro = Instance.new("BodyGyro")
            gyro.Name = "FlyGyro"
            gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
            gyro.CFrame = hrp.CFrame
            gyro.Parent = hrp
            flyEvent:FireClient(player, true)
        end
    elseif command == "/time" then
        local timeValue = tonumber(args[2])
        if timeValue and _G.SetTimeManually then
            _G.SetTimeManually(timeValue)
        elseif timeValue then
            Lighting.ClockTime = math.clamp(timeValue, 0, 24)
        end
    end
end

flyEvent.OnServerEvent:Connect(function(player, moveDir, cameraCFrame)
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local hrp = character.HumanoidRootPart
        local flyBody = hrp:FindFirstChild("FlyBody")
        local flyGyro = hrp:FindFirstChild("FlyGyro")
        if flyBody and flyGyro then
            flyBody.Velocity = moveDir * 50
            flyGyro.CFrame = cameraCFrame
        end
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        handleChat(player, message)
    end)
end)

