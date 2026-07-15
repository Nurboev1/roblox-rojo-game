
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CHUNK_SIZE = 400
local GRID_RESOLUTION = 50
local RENDER_DISTANCE = 1
local generatedChunks = {}
local NOISE_SCALE = 0.005
local SMART_HEIGHT = 30
local BASE_THICKNESS = 50
local CACTUS_CHANCE = 0.003
local SPAWN_CHUNK_X = 0
local SPAWN_CHUNK_Z = 0
local SPAWN_CHUNK_HEIGHT = 0
local SPAWN_FLAT_RADIUS = CHUNK_SIZE / 2
local SPAWN_BLEND_RADIUS = CHUNK_SIZE * 1.5

local cactusModels = ReplicatedStorage:WaitForChild("CactusModels"):GetChildren()

local function smoothstep(alpha)
    alpha = math.clamp(alpha, 0, 1)
    return alpha * alpha * (3 - 2 * alpha)
end

-- Balandlikni juda uzoq masofalarda o'zgartirish uchun Perlin shovqinini ishlatamiz
local function getElevation(x, z)
    local nx = x * NOISE_SCALE
    local nz = z * NOISE_SCALE
    
    -- Katta to'lqinlar uchun past chastotali shovqin
    local n1 = math.noise(nx, nz, 1337)
    local n2 = math.noise(nx * 0.5, nz * 0.5, 999) * 0.5
    
    -- Balandlikni hisoblash
    local height = (n1 + n2) * SMART_HEIGHT
    local distanceFromSpawn = math.max(
        math.abs(x - SPAWN_CHUNK_X * CHUNK_SIZE),
        math.abs(z - SPAWN_CHUNK_Z * CHUNK_SIZE)
    )

    if distanceFromSpawn <= SPAWN_FLAT_RADIUS then
        return SPAWN_CHUNK_HEIGHT
    end

    local blendAlpha = smoothstep((distanceFromSpawn - SPAWN_FLAT_RADIUS) / (SPAWN_BLEND_RADIUS - SPAWN_FLAT_RADIUS))
    return SPAWN_CHUNK_HEIGHT + (height - SPAWN_CHUNK_HEIGHT) * blendAlpha
end

local function generateChunk(cx, cz)
    local chunkKey = cx .. "," .. cz
    if generatedChunks[chunkKey] then return end
    
    local chunk = Instance.new("Model")
    chunk.Name = "Chunk_" .. chunkKey
    chunk.Parent = workspace
    
    local cellW = CHUNK_SIZE / GRID_RESOLUTION
    local cellD = CHUNK_SIZE / GRID_RESOLUTION
    local startX = cx * CHUNK_SIZE - CHUNK_SIZE / 2
    local startZ = cz * CHUNK_SIZE - CHUNK_SIZE / 2
    
    for i = 0, GRID_RESOLUTION - 1 do
        for j = 0, GRID_RESOLUTION - 1 do
            local x = startX + i * cellW
            local z = startZ + j * cellD
            local y = getElevation(x, z)
            
            local part = Instance.new("Part")
            part.Size = Vector3.new(cellW + 2, BASE_THICKNESS, cellD + 2)
            part.Position = Vector3.new(x, y - (BASE_THICKNESS / 2) - 5, z)
            part.Anchored = true
            -- Tepaliklar baland bo'lgani uchun rangni biroz o'zgartirish mumkin
            part.Color = y > 20 and Color3.fromRGB(180, 100, 50) or Color3.fromRGB(205, 115, 60)
            part.Material = Enum.Material.Sand
            part.Parent = chunk
            
            if math.random() < CACTUS_CHANCE then
                local model = cactusModels[math.random(1, #cactusModels)]:Clone()
                -- Kaktuslarni kichraytirish va rangini o'zgartirish shart emas, 
                -- chunki siz CactusModels ichidagi modellarni o'zingiz xohlagandek tayyorlab qo'ygansiz.
                local randomRotation = CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
                model:PivotTo(CFrame.new(x, y - 5, z) * randomRotation)
                model.Parent = chunk
            end
        end
    end
    
    generatedChunks[chunkKey] = true
end

local function updateChunks()
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local pos = player.Character.HumanoidRootPart.Position
            local chunkX_clamped = math.floor(pos.X / CHUNK_SIZE + 0.5)
            local chunkZ_clamped = math.floor(pos.Z / CHUNK_SIZE + 0.5)
            
            for x = -RENDER_DISTANCE, RENDER_DISTANCE do
                for z = -RENDER_DISTANCE, RENDER_DISTANCE do
                    generateChunk(chunkX_clamped + x, chunkZ_clamped + z)
                end
            end
        end
    end
end

task.spawn(function()
    while true do
        updateChunks()
        task.wait(1)
    end
end)
