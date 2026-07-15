local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local INTERACT_DISTANCE = 18
local DRAG_DISTANCE = 7
local MAX_DRAG_DISTANCE_FROM_PLAYER = 30
local INVENTORY_CAPACITY = 100
local BONE_ITEM_NAME = "Bone"

local remotes = ReplicatedStorage:FindFirstChild("SurvivalRemotes") or Instance.new("Folder")
remotes.Name = "SurvivalRemotes"
remotes.Parent = ReplicatedStorage

local function getRemote(name)
	local remote = remotes:FindFirstChild(name) or Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local interactRemote = getRemote("Interact")
local inventoryRemote = getRemote("InventoryUpdated")
local selectSlotRemote = getRemote("SelectHotbarSlot")
local moveItemRemote = getRemote("MoveInventoryItem")

local boneTemplate = ReplicatedStorage:WaitForChild("BoneModels"):WaitForChild("Rib_1")
local playerState = {}

local function makeStack(itemName, count)
	return {
		itemName = itemName,
		count = count,
	}
end

local function getStackCount(stack)
	return stack and stack.count or 0
end

local function getRoot(player)
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isNear(player, instance, distance)
	local root = getRoot(player)
	if not root or not instance or not instance:IsDescendantOf(workspace) then
		return false
	end

	return (root.Position - instance:GetPivot().Position).Magnitude <= distance
end

local function getTotalItemCount(state)
	local total = 0

	for _, count in state.inventory do
		total += count
	end

	for _, stack in state.hotbar do
		total += getStackCount(stack)
	end

	return total
end

local function setPartState(instance, anchored, canCollide, networkOwner)
	if instance:IsA("BasePart") then
		instance.Anchored = anchored
		instance.CanCollide = canCollide
		pcall(function()
			instance:SetNetworkOwner(networkOwner)
		end)
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = anchored
			descendant.CanCollide = canCollide
			pcall(function()
				descendant:SetNetworkOwner(networkOwner)
			end)
		end
	end
end

local function getMainPart(instance)
	if instance:IsA("BasePart") then
		return instance
	end

	if instance:IsA("Model") then
		return instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart", true)
	end

	return nil
end

local function weldModelParts(instance)
	local mainPart = getMainPart(instance)
	if not mainPart then
		return
	end

	if instance:IsA("Model") and not instance.PrimaryPart then
		instance.PrimaryPart = mainPart
	end

	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") and descendant ~= mainPart then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = mainPart
			weld.Part1 = descendant
			weld.Parent = mainPart
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

local function getBoundingBox(instance)
	if instance:IsA("Model") then
		return instance:GetBoundingBox()
	elseif instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	end

	return CFrame.identity, Vector3.zero
end

local function getGroundedPosition(instance, desiredPosition, player)
	local _, boxSize = getBoundingBox(instance)
	local halfHeight = math.max(boxSize.Y / 2, 0.5)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { instance, player.Character }

	local rayOrigin = desiredPosition + Vector3.new(0, 34, 0)
	local result = workspace:Raycast(rayOrigin, Vector3.new(0, -90, 0), raycastParams)
	if result then
		local minY = result.Position.Y + halfHeight + 0.15
		if desiredPosition.Y < minY then
			return Vector3.new(desiredPosition.X, minY, desiredPosition.Z)
		end
	end

	return desiredPosition
end

local function hasSupportUnder(instance, player)
	local boxCFrame, boxSize = getBoundingBox(instance)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = { instance, player.Character }

	local rayLength = math.max(boxSize.Y / 2 + 1.25, 2)
	local result = workspace:Raycast(boxCFrame.Position, Vector3.new(0, -rayLength, 0), raycastParams)
	return result ~= nil
end

local function placeOnGround(instance, position, rotation)
	instance:PivotTo(CFrame.new(position) * rotation)
	local boxCFrame, boxSize = getBoundingBox(instance)
	local bottomY = boxCFrame.Position.Y - boxSize.Y / 2
	instance:PivotTo(instance:GetPivot() + Vector3.new(0, position.Y - bottomY, 0))
end

local function makeDroppedBone(position, parent)
	local bone = boneTemplate:Clone()
	bone.Name = "DroppedBone"
	scaleProp(bone, 3)
	weldModelParts(bone)
	setPartState(bone, false, true, nil)
	bone:SetAttribute("Interactable", true)
	bone:SetAttribute("Collectible", true)
	bone:SetAttribute("Movable", true)
	bone:SetAttribute("Weldable", true)
	bone:SetAttribute("DroppedItem", true)
	bone:SetAttribute("ItemName", BONE_ITEM_NAME)
	bone:SetAttribute("Welded", false)
	placeOnGround(bone, position, CFrame.Angles(0, math.rad(math.random(0, 359)), math.rad(math.random(-18, 18))))
	bone.Parent = parent or workspace
	return bone
end

local function sendInventory(player)
	local state = playerState[player]
	if state then
		inventoryRemote:FireClient(player, state.inventory, state.hotbar, state.selectedSlot, INVENTORY_CAPACITY)
	end
end

local function equipSlot(player)
	local state = playerState[player]
	local character = player.Character
	if not state or not character then
		return
	end

	if state.equippedModel then
		state.equippedModel:Destroy()
		state.equippedModel = nil
	end

	local stack = state.hotbar[state.selectedSlot]
	if not stack or stack.itemName ~= BONE_ITEM_NAME or stack.count <= 0 then
		return
	end

	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not hand or not hand:IsA("BasePart") then
		return
	end

	local equipped = boneTemplate:Clone()
	equipped.Name = "EquippedBone"
	scaleProp(equipped, 3)
	weldModelParts(equipped)
	setPartState(equipped, false, false, nil)
	equipped.Parent = character
	equipped:PivotTo(hand.CFrame * CFrame.new(0, -0.35, -0.35) * CFrame.Angles(math.rad(75), 0, math.rad(15)))

	local handle = equipped:IsA("BasePart") and equipped or equipped:FindFirstChildWhichIsA("BasePart", true)
	if handle then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hand
		weld.Part1 = handle
		weld.Parent = handle
	end

	state.equippedModel = equipped
end

local function addItemToInventory(player, itemName)
	local state = playerState[player]
	if not state or getTotalItemCount(state) >= INVENTORY_CAPACITY then
		return false
	end

	for index = 1, 9 do
		local stack = state.hotbar[index]
		if stack and stack.itemName == itemName then
			stack.count += 1
			equipSlot(player)
			sendInventory(player)
			return true
		end
	end

	if (state.inventory[itemName] or 0) > 0 then
		state.inventory[itemName] += 1
		equipSlot(player)
		sendInventory(player)
		return true
	end

	for index = 1, 9 do
		if not state.hotbar[index] then
			state.hotbar[index] = makeStack(itemName, 1)
			equipSlot(player)
			sendInventory(player)
			return true
		end
	end

	state.inventory[itemName] = (state.inventory[itemName] or 0) + 1
	equipSlot(player)
	sendInventory(player)
	return true
end

local function harvestBone(player, target)
	if not target:GetAttribute("HarvestableBone") or not isNear(player, target, INTERACT_DISTANCE) then
		return
	end

	local dropCount = math.clamp(target:GetAttribute("BoneDropCount") or 1, 1, 12)
	local parent = target.Parent or workspace
	local origin = target:GetPivot().Position
	target:Destroy()

	for index = 1, dropCount do
		local angle = math.rad((index / dropCount) * 360 + math.random(-18, 18))
		local distance = 1.4 + math.random() * 1.8
		local dropPosition = origin + Vector3.new(math.cos(angle) * distance, 2, math.sin(angle) * distance)
		local bone = makeDroppedBone(dropPosition, parent)
		local part = bone:IsA("BasePart") and bone or bone:FindFirstChildWhichIsA("BasePart", true)
		if part then
			part.AssemblyLinearVelocity = Vector3.new(math.cos(angle) * 4, 4, math.sin(angle) * 4)
		end
	end
end

local function addHarvestPrompt(target)
	if not target:GetAttribute("HarvestableBone") or target:FindFirstChild("HarvestPrompt", true) then
		return
	end

	local attachPart = target:IsA("BasePart") and target or target:FindFirstChildWhichIsA("BasePart", true)
	if not attachPart then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HarvestPrompt"
	prompt.ActionText = "Break"
	prompt.ObjectText = "Bone"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.75
	prompt.MaxActivationDistance = INTERACT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = attachPart
	prompt.Triggered:Connect(function(player)
		harvestBone(player, target)
	end)
end

local function storeDroppedItem(player, target)
	if target:GetAttribute("DroppedItem") and isNear(player, target, INTERACT_DISTANCE) then
		if addItemToInventory(player, target:GetAttribute("ItemName") or BONE_ITEM_NAME) then
			target:Destroy()
		end
	end
end

local function setWelded(player, target)
	if not target:GetAttribute("Weldable") or not isNear(player, target, INTERACT_DISTANCE) then
		return
	end

	local welded = not target:GetAttribute("Welded")
	if welded and not hasSupportUnder(target, player) then
		return
	end

	target:SetAttribute("Welded", welded)
	setPartState(target, welded, true, nil)
end

local function dragTarget(player, target, cameraCFrame)
	if not target:GetAttribute("Movable") or target:GetAttribute("Welded") or not isNear(player, target, MAX_DRAG_DISTANCE_FROM_PLAYER) then
		return
	end

	local root = getRoot(player)
	if not root then
		return
	end

	local targetPosition = cameraCFrame.Position + cameraCFrame.LookVector * DRAG_DISTANCE + Vector3.new(0, -0.65, 0)
	if (root.Position - targetPosition).Magnitude > MAX_DRAG_DISTANCE_FROM_PLAYER then
		targetPosition = root.Position + (targetPosition - root.Position).Unit * MAX_DRAG_DISTANCE_FROM_PLAYER
	end
	targetPosition = getGroundedPosition(target, targetPosition, player)

	setPartState(target, true, false, nil)
	target:PivotTo(CFrame.new(targetPosition) * target:GetPivot().Rotation)
end

local function releaseTarget(player, target)
	if not target:GetAttribute("Movable") or target:GetAttribute("Welded") or not isNear(player, target, MAX_DRAG_DISTANCE_FROM_PLAYER) then
		return
	end

	local position = getGroundedPosition(target, target:GetPivot().Position, player)
	target:PivotTo(CFrame.new(position) * target:GetPivot().Rotation)
	setPartState(target, false, true, nil)

	for _, descendant in target:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end

	if target:IsA("BasePart") then
		target.AssemblyLinearVelocity = Vector3.zero
		target.AssemblyAngularVelocity = Vector3.zero
	end
end

local function moveItem(player, fromKind, fromIndex, toKind, toIndex)
	local state = playerState[player]
	if not state or typeof(fromKind) ~= "string" or typeof(toKind) ~= "string" then
		return
	end

	if fromKind == "bag" and toKind == "hotbar" then
		if typeof(toIndex) ~= "number" then
			return
		end

		local itemName = tostring(fromIndex)
		local bagCount = state.inventory[itemName] or 0
		if bagCount <= 0 then
			return
		end

		toIndex = math.clamp(math.floor(toIndex), 1, 9)
		local existing = state.hotbar[toIndex]
		if existing and existing.itemName ~= itemName then
			state.inventory[existing.itemName] = (state.inventory[existing.itemName] or 0) + existing.count
			existing = nil
		end

		state.hotbar[toIndex] = makeStack(itemName, bagCount + (existing and existing.count or 0))
		state.inventory[itemName] = nil
	elseif fromKind == "hotbar" and toKind == "bag" then
		if typeof(fromIndex) ~= "number" then
			return
		end

		fromIndex = math.clamp(math.floor(fromIndex), 1, 9)
		local stack = state.hotbar[fromIndex]
		if not stack then
			return
		end

		state.inventory[stack.itemName] = (state.inventory[stack.itemName] or 0) + stack.count
		state.hotbar[fromIndex] = nil
	elseif fromKind == "hotbar" and toKind == "hotbar" then
		if typeof(fromIndex) ~= "number" or typeof(toIndex) ~= "number" then
			return
		end

		fromIndex = math.clamp(math.floor(fromIndex), 1, 9)
		toIndex = math.clamp(math.floor(toIndex), 1, 9)
		if fromIndex == toIndex then
			return
		end

		local fromStack = state.hotbar[fromIndex]
		local toStack = state.hotbar[toIndex]
		if fromStack and toStack and fromStack.itemName == toStack.itemName then
			toStack.count += fromStack.count
			state.hotbar[fromIndex] = nil
		else
			state.hotbar[fromIndex] = toStack
			state.hotbar[toIndex] = fromStack
		end
	end

	equipSlot(player)
	sendInventory(player)
end

Players.PlayerAdded:Connect(function(player)
	playerState[player] = {
		inventory = {},
		hotbar = {},
		selectedSlot = 1,
		equippedModel = nil,
	}

	player.CharacterAdded:Connect(function()
		task.wait(0.25)
		equipSlot(player)
		sendInventory(player)
	end)

	sendInventory(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local state = playerState[player]
	if state and state.equippedModel then
		state.equippedModel:Destroy()
	end
	playerState[player] = nil
end)

selectSlotRemote.OnServerEvent:Connect(function(player, slotIndex)
	local state = playerState[player]
	if not state or typeof(slotIndex) ~= "number" then
		return
	end

	state.selectedSlot = math.clamp(math.floor(slotIndex), 1, 9)
	equipSlot(player)
	sendInventory(player)
end)

moveItemRemote.OnServerEvent:Connect(moveItem)

interactRemote.OnServerEvent:Connect(function(player, action, target, cameraCFrame)
	if typeof(action) ~= "string" or typeof(target) ~= "Instance" then
		return
	end

	if action == "HarvestBone" then
		harvestBone(player, target)
	elseif action == "Store" then
		storeDroppedItem(player, target)
	elseif action == "ToggleWeld" then
		setWelded(player, target)
	elseif action == "Drag" and typeof(cameraCFrame) == "CFrame" then
		dragTarget(player, target, cameraCFrame)
	elseif action == "Throw" then
		releaseTarget(player, target)
	end
end)

local function trySetupHarvestPrompt(instance)
	if instance:GetAttribute("HarvestableBone") then
		addHarvestPrompt(instance)
	end
end

workspace.DescendantAdded:Connect(function(instance)
	task.defer(trySetupHarvestPrompt, instance)
end)

task.spawn(function()
	while true do
		for _, instance in workspace:GetDescendants() do
			trySetupHarvestPrompt(instance)
		end
		task.wait(3)
	end
end)
