
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CHUNK_SIZE = 400
local GRID_RESOLUTION = 40
local RENDER_DISTANCE = 1
local INITIAL_PRELOAD_RADIUS = 3
local generatedChunks = {}
local NOISE_SCALE = 0.005
local SMART_HEIGHT = 30
local SURFACE_OFFSET = -5
local TRIANGLE_THICKNESS = 0.12
local PROP_SPAWN_CHANCE = 0.011
local SPAWN_CLEAR_RADIUS = 90
local SPAWN_CHUNK_X = 0
local SPAWN_CHUNK_Z = 0

local worldReady = ReplicatedStorage:FindFirstChild("WorldReady") or Instance.new("BoolValue")
worldReady.Name = "WorldReady"
worldReady.Value = false
worldReady.Parent = ReplicatedStorage

local worldLoadProgress = ReplicatedStorage:FindFirstChild("WorldLoadProgress") or Instance.new("NumberValue")
worldLoadProgress.Name = "WorldLoadProgress"
worldLoadProgress.Value = 0
worldLoadProgress.Parent = ReplicatedStorage

local cactusModels = ReplicatedStorage:WaitForChild("CactusModels"):GetChildren()
local grassModels = ReplicatedStorage:WaitForChild("GrassModels"):GetChildren()
local boneModels = ReplicatedStorage:WaitForChild("BoneModels"):GetChildren()
local treeModels = ReplicatedStorage:WaitForChild("TreeModels"):GetChildren()
local rockModels = ReplicatedStorage:WaitForChild("RockModels"):GetChildren()

local bigRockModels = {}
local lowRockModels = {}

for _, model in rockModels do
    if model.Name:match("^Rock_Low") then
        table.insert(lowRockModels, model)
    else
        table.insert(bigRockModels, model)
    end
end

local propSpawnDefs = {
    {
        name = "DryGrass",
        models = grassModels,
        weight = 38,
        minScale = 6,
        maxScale = 6,
        canCollide = false,
    },
    {
        name = "Cactus",
        models = cactusModels,
        weight = 22,
        minScale = 6,
        maxScale = 6,
        canCollide = true,
    },
    {
        name = "LowRock",
        models = lowRockModels,
        weight = 18,
        minScale = 6,
        maxScale = 6,
        canCollide = true,
    },
    {
        name = "Bone",
        models = boneModels,
        weight = 9,
        minScale = 6,
        maxScale = 6,
        canCollide = true,
    },
    {
        name = "BigRock",
        models = bigRockModels,
        weight = 8,
        minScale = 6,
        maxScale = 6,
        canCollide = true,
        sinkDepth = 14,
        tiltDegrees = 12,
    },
    {
        name = "DeadTree",
        models = treeModels,
        weight = 5,
        minScale = 6,
        maxScale = 6,
        canCollide = true,
    },
}

local function choosePropSpawnDef()
    local totalWeight = 0

    for _, spawnDef in propSpawnDefs do
        if #spawnDef.models > 0 then
            totalWeight += spawnDef.weight
        end
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    local currentWeight = 0

    for _, spawnDef in propSpawnDefs do
        if #spawnDef.models > 0 then
            currentWeight += spawnDef.weight
            if roll <= currentWeight then
                return spawnDef
            end
        end
    end

    return nil
end

workspace.Terrain:Clear()
for _, child in workspace:GetChildren() do
    if child.Name:match("^Chunk_") then
        child:Destroy()
    end
end

local function setCharacterFrozen(character, isFrozen)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local hrp = character:FindFirstChild("HumanoidRootPart")

    if humanoid then
        humanoid.PlatformStand = isFrozen
    end

    if hrp then
        hrp.Anchored = isFrozen
        if isFrozen then
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        end
    end
end

local function handleCharacterAdded(character)
    if not worldReady.Value then
        setCharacterFrozen(character, true)
        worldReady:GetPropertyChangedSignal("Value"):Wait()
    end

    setCharacterFrozen(character, false)
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(handleCharacterAdded)
end)

for _, player in Players:GetPlayers() do
    if player.Character then
        task.spawn(handleCharacterAdded, player.Character)
    end
    player.CharacterAdded:Connect(handleCharacterAdded)
end

local function getSandColor(height)
    local alpha = math.clamp((height + SMART_HEIGHT) / (SMART_HEIGHT * 2), 0, 1)
    return Color3.fromRGB(194, 145, 82):Lerp(Color3.fromRGB(222, 185, 126), alpha)
end

local function createTerrainWedge(parent, color)
    local wedge = Instance.new("WedgePart")
    wedge.Name = "SandSurface"
    wedge.Anchored = true
    wedge.CanCollide = true
    wedge.CastShadow = false
    wedge.Material = Enum.Material.Sand
    wedge.Color = color
    wedge.TopSurface = Enum.SurfaceType.Smooth
    wedge.BottomSurface = Enum.SurfaceType.Smooth
    wedge.Parent = parent
    return wedge
end

local function drawTriangle(a, b, c, parent)
    local ab = b - a
    local ac = c - a
    local bc = c - b
    local abLength = ab:Dot(ab)
    local acLength = ac:Dot(ac)
    local bcLength = bc:Dot(bc)

    if abLength > acLength and abLength > bcLength then
        c, a = a, c
    elseif acLength > bcLength and acLength > abLength then
        a, b = b, a
    end

    ab = b - a
    ac = c - a
    bc = c - b

    local right = ac:Cross(ab)
    if right.Magnitude < 0.001 then
        return
    end

    right = right.Unit
    local up = bc:Cross(right).Unit
    local back = bc.Unit
    local height = math.abs(ab:Dot(up))
    local widthA = math.abs(ab:Dot(back))
    local widthB = math.abs(ac:Dot(back))
    local color = getSandColor((a.Y + b.Y + c.Y) / 3)

    local wedgeA = createTerrainWedge(parent, color)
    wedgeA.Size = Vector3.new(TRIANGLE_THICKNESS, height, widthA)
    wedgeA.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)

    local wedgeB = createTerrainWedge(parent, color)
    wedgeB.Size = Vector3.new(TRIANGLE_THICKNESS, height, widthB)
    wedgeB.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
end

-- Use Perlin noise to vary terrain height over long distances.
local function getElevation(x, z)
    local nx = x * NOISE_SCALE
    local nz = z * NOISE_SCALE
    
    -- Low-frequency noise creates broad dunes.
    local n1 = math.noise(nx, nz, 1337)
    local n2 = math.noise(nx * 0.5, nz * 0.5, 999) * 0.5
    
    -- Calculate final height.
    local height = (n1 + n2) * SMART_HEIGHT
    return height
end

local function prepareSpawnedProp(model, spawnDef)
    model:SetAttribute("GeneratedProp", true)
    model:SetAttribute("PropType", spawnDef.name)

    if spawnDef.name == "Bone" then
        local dropCount = 1
        if model.Name == "Rib_Cage_Half" then
            dropCount = 4
        elseif model.Name == "Rib_Cage" then
            dropCount = 8
        end

        model:SetAttribute("Interactable", true)
        model:SetAttribute("HarvestableBone", true)
        model:SetAttribute("BoneDropCount", dropCount)
    end

    if model:IsA("BasePart") then
        model.Anchored = true
        model.CanCollide = spawnDef.canCollide
        model.CastShadow = true
    end

    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            descendant.Anchored = true
            descendant.CanCollide = spawnDef.canCollide
            descendant.CastShadow = true
        end
    end
end

local function scaleProp(model, scale)
    if model:IsA("Model") then
        model:ScaleTo(scale)
    elseif model:IsA("BasePart") then
        model.Size *= scale
    end
end

local function getPropBoundingBox(model)
    if model:IsA("Model") then
        return model:GetBoundingBox()
    elseif model:IsA("BasePart") then
        return model.CFrame, model.Size
    end

    return CFrame.identity, Vector3.zero
end

local function placeProp(spawnDef, x, z, parent)
    if not spawnDef or #spawnDef.models <= 0 then
        return
    end

    local surfaceY = getElevation(x, z) + SURFACE_OFFSET
    local model = spawnDef.models[math.random(1, #spawnDef.models)]:Clone()
    local scale = spawnDef.minScale + math.random() * (spawnDef.maxScale - spawnDef.minScale)
    local tiltDegrees = spawnDef.tiltDegrees or 0
    local tiltX = math.rad((math.random() * 2 - 1) * tiltDegrees)
    local tiltZ = math.rad((math.random() * 2 - 1) * tiltDegrees)
    local randomRotation = CFrame.Angles(tiltX, math.rad(math.random(0, 359)), tiltZ)

    scaleProp(model, scale)

    prepareSpawnedProp(model, spawnDef)
    model:PivotTo(CFrame.new(x, surfaceY, z) * randomRotation)

    local boundingBoxCFrame, boundingBoxSize = getPropBoundingBox(model)
    local bottomY = boundingBoxCFrame.Position.Y - boundingBoxSize.Y / 2
    model:PivotTo(model:GetPivot() + Vector3.new(0, surfaceY - bottomY - (spawnDef.sinkDepth or 0), 0))
    model.Parent = parent
end

local function generateChunk(cx, cz)
    local chunkKey = cx .. "," .. cz
    if generatedChunks[chunkKey] then return end
    generatedChunks[chunkKey] = true
    
    local chunk = Instance.new("Model")
    chunk.Name = "Chunk_" .. chunkKey
    chunk.Parent = workspace
    
    local cellW = CHUNK_SIZE / GRID_RESOLUTION
    local cellD = CHUNK_SIZE / GRID_RESOLUTION
    local startX = cx * CHUNK_SIZE - CHUNK_SIZE / 2
    local startZ = cz * CHUNK_SIZE - CHUNK_SIZE / 2
    
    for i = 0, GRID_RESOLUTION - 1 do
        for j = 0, GRID_RESOLUTION - 1 do
            local x0 = startX + i * cellW
            local x1 = x0 + cellW
            local z0 = startZ + j * cellD
            local z1 = z0 + cellD

            local p00 = Vector3.new(x0, getElevation(x0, z0) + SURFACE_OFFSET, z0)
            local p10 = Vector3.new(x1, getElevation(x1, z0) + SURFACE_OFFSET, z0)
            local p01 = Vector3.new(x0, getElevation(x0, z1) + SURFACE_OFFSET, z1)
            local p11 = Vector3.new(x1, getElevation(x1, z1) + SURFACE_OFFSET, z1)

            drawTriangle(p00, p10, p11, chunk)
            drawTriangle(p00, p11, p01, chunk)
            
            local propX = x0 + math.random() * cellW
            local propZ = z0 + math.random() * cellD
            local distanceFromSpawn = Vector2.new(propX, propZ).Magnitude

            if distanceFromSpawn > SPAWN_CLEAR_RADIUS and math.random() < PROP_SPAWN_CHANCE then
                placeProp(choosePropSpawnDef(), propX, propZ, chunk)
            end
        end
    end
    
    return chunk
end

local function buildInitialChunkList(radius)
    local chunks = {}

    for x = -radius, radius do
        for z = -radius, radius do
            table.insert(chunks, {
                x = SPAWN_CHUNK_X + x,
                z = SPAWN_CHUNK_Z + z,
                distance = x * x + z * z,
            })
        end
    end

    table.sort(chunks, function(a, b)
        return a.distance < b.distance
    end)

    return chunks
end

local function preloadSpawnArea()
    local chunks = buildInitialChunkList(INITIAL_PRELOAD_RADIUS)
    local totalChunks = #chunks

    for index, chunkInfo in chunks do
        generateChunk(chunkInfo.x, chunkInfo.z)
        worldLoadProgress.Value = index / totalChunks

        if index % 2 == 0 then
            task.wait()
        end
    end

    worldLoadProgress.Value = 1
end

preloadSpawnArea()
worldReady.Value = true

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
