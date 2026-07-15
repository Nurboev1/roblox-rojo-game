local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local IS_MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local SLOT_COUNT = IS_MOBILE and 5 or 9
local DEFAULT_SLOT_SIZE = 58
local MIN_SLOT_SIZE = 46
local DEFAULT_SLOT_GAP = 8
local selectedSlotIndex = 1
local hotbarSlots = {}
local inventoryCells = {}
local latestInventory = {}
local latestHotbar = {}
local beginGuiDrag = nil
local WALK_SPEED = 16
local SPRINT_SPEED = 24
local STAMINA_MAX = 100
local STAMINA_DRAIN_PER_SECOND = 22
local STAMINA_RECOVER_PER_SECOND = 16
local SPRINT_RESTART_THRESHOLD = 20
local stamina = STAMINA_MAX
local wantsSprint = false
local mobileSprintEnabled = false
local sprintLockedUntilRecovery = false
local currentHumanoid = nil
local cameraBobTime = 0
local cameraBobOffset = Vector3.zero
local cameraBobRoll = 0

local KEYCODE_TO_SLOT = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9,
}

local remotes = ReplicatedStorage:WaitForChild("SurvivalRemotes")
local inventoryUpdatedRemote = remotes:WaitForChild("InventoryUpdated")
local selectHotbarSlotRemote = remotes:WaitForChild("SelectHotbarSlot")
local moveInventoryItemRemote = remotes:WaitForChild("MoveInventoryItem")
local itemPreviewTemplates = {
	Bone = ReplicatedStorage:WaitForChild("BoneModels"):WaitForChild("Rib_1"),
}

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local gui = Instance.new("ScreenGui")
gui.Name = "SurvivalGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.Size = UDim2.fromOffset(6, 6)
crosshair.BackgroundColor3 = Color3.fromRGB(255, 245, 225)
crosshair.BackgroundTransparency = 0.15
crosshair.BorderSizePixel = 0
crosshair.Parent = gui

local hotbar = Instance.new("Frame")
hotbar.Name = "Hotbar"
hotbar.AnchorPoint = Vector2.new(0.5, 1)
hotbar.Position = UDim2.new(0.5, 0, 1, -22)
hotbar.Size = UDim2.fromOffset((DEFAULT_SLOT_SIZE + DEFAULT_SLOT_GAP) * (SLOT_COUNT + 1) - DEFAULT_SLOT_GAP, DEFAULT_SLOT_SIZE)
hotbar.BackgroundTransparency = 1
hotbar.ZIndex = 20
hotbar.Parent = gui

local hotbarLayout = Instance.new("UIListLayout")
hotbarLayout.FillDirection = Enum.FillDirection.Horizontal
hotbarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
hotbarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
hotbarLayout.Padding = UDim.new(0, DEFAULT_SLOT_GAP)
hotbarLayout.SortOrder = Enum.SortOrder.LayoutOrder
hotbarLayout.Parent = hotbar

local function addCorner(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Transparency = transparency or 0
	stroke.Parent = parent
	return stroke
end

local function clearPreview(viewport)
	for _, child in viewport:GetChildren() do
		child:Destroy()
	end
	viewport.CurrentCamera = nil
	viewport.Visible = false
end

local function setItemPreview(viewport, itemName)
	clearPreview(viewport)

	local template = itemName and itemPreviewTemplates[itemName]
	if not template then
		return
	end

	local worldModel = Instance.new("WorldModel")
	worldModel.Parent = viewport

	local preview = template:Clone()
	preview.Parent = worldModel

	for _, descendant in preview:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CastShadow = false
		end
	end

	if preview:IsA("BasePart") then
		preview.Anchored = true
		preview.CanCollide = false
		preview.CastShadow = false
	end

	if preview:IsA("Model") then
		preview:ScaleTo(1.8)
	else
		preview.Size *= 1.8
	end

	preview:PivotTo(CFrame.Angles(math.rad(-18), math.rad(34), math.rad(68)))
	local boxCFrame, boxSize
	if preview:IsA("Model") then
		boxCFrame, boxSize = preview:GetBoundingBox()
	else
		boxCFrame, boxSize = preview.CFrame, preview.Size
	end

	local camera = Instance.new("Camera")
	local radius = math.max(boxSize.X, boxSize.Y, boxSize.Z, 1)
	camera.CFrame = CFrame.new(boxCFrame.Position + Vector3.new(0, radius * 0.18, radius * 1.55), boxCFrame.Position)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	viewport.Visible = true
end

addCorner(crosshair, 6)
addStroke(crosshair, Color3.fromRGB(28, 25, 21), 1, 0.25)

local clockPanel = Instance.new("Frame")
clockPanel.Name = "ClockPanel"
clockPanel.AnchorPoint = Vector2.new(1, 0)
clockPanel.Position = UDim2.new(1, -18, 0, 18)
clockPanel.Size = UDim2.fromOffset(142, 42)
clockPanel.BackgroundColor3 = Color3.fromRGB(30, 24, 18)
clockPanel.BackgroundTransparency = 0.08
clockPanel.BorderSizePixel = 0
clockPanel.ZIndex = 18
clockPanel.Parent = gui
addCorner(clockPanel, 8)
addStroke(clockPanel, Color3.fromRGB(143, 107, 58), 1, 0.1)

local clockText = Instance.new("TextLabel")
clockText.Name = "ClockText"
clockText.Size = UDim2.fromScale(1, 1)
clockText.BackgroundTransparency = 1
clockText.Font = Enum.Font.SpecialElite
clockText.Text = "09:00 AM"
clockText.TextColor3 = Color3.fromRGB(255, 228, 174)
clockText.TextSize = 23
clockText.ZIndex = 19
clockText.Parent = clockPanel

local function formatClockTime(clockTime)
	local totalMinutes = math.floor((clockTime % 24) * 60 + 0.5)
	local hour24 = math.floor(totalMinutes / 60) % 24
	local minute = totalMinutes % 60
	local suffix = hour24 >= 12 and "PM" or "AM"
	local hour12 = hour24 % 12

	if hour12 == 0 then
		hour12 = 12
	end

	return string.format("%02d:%02d %s", hour12, minute, suffix)
end

local function updateClock()
	clockText.Text = formatClockTime(Lighting.ClockTime)
end

Lighting:GetPropertyChangedSignal("ClockTime"):Connect(updateClock)
updateClock()

local sprintBar = Instance.new("Frame")
sprintBar.Name = "SprintBar"
sprintBar.AnchorPoint = Vector2.new(0.5, 1)
sprintBar.Position = UDim2.new(0.5, 0, 1, -92)
sprintBar.Size = UDim2.fromOffset(310, 14)
sprintBar.BackgroundColor3 = Color3.fromRGB(27, 23, 19)
sprintBar.BackgroundTransparency = 0.08
sprintBar.BorderSizePixel = 0
sprintBar.Visible = false
sprintBar.ZIndex = 18
sprintBar.Parent = gui
addCorner(sprintBar, 8)
addStroke(sprintBar, Color3.fromRGB(109, 82, 48), 1, 0.15)

local sprintFill = Instance.new("Frame")
sprintFill.Name = "Fill"
sprintFill.Size = UDim2.fromScale(1, 1)
sprintFill.BackgroundColor3 = Color3.fromRGB(77, 191, 235)
sprintFill.BorderSizePixel = 0
sprintFill.ZIndex = 19
sprintFill.Parent = sprintBar
addCorner(sprintFill, 8)

local sprintButton = Instance.new("TextButton")
sprintButton.Name = "SprintButton"
sprintButton.AnchorPoint = Vector2.new(1, 1)
sprintButton.Position = UDim2.new(1, -24, 1, -116)
sprintButton.Size = UDim2.fromOffset(86, 48)
sprintButton.AutoButtonColor = true
sprintButton.BackgroundColor3 = Color3.fromRGB(47, 39, 31)
sprintButton.BackgroundTransparency = 0.05
sprintButton.BorderSizePixel = 0
sprintButton.Font = Enum.Font.GothamBold
sprintButton.Text = "Sprint"
sprintButton.TextColor3 = Color3.fromRGB(255, 235, 202)
sprintButton.TextSize = 15
sprintButton.Visible = IS_MOBILE
sprintButton.ZIndex = 22
sprintButton.Parent = gui
addCorner(sprintButton, 8)
addStroke(sprintButton, Color3.fromRGB(139, 107, 67), 1, 0.1)

local function getHumanoid()
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function setHumanoid(humanoid)
	currentHumanoid = humanoid
	if currentHumanoid then
		currentHumanoid.WalkSpeed = WALK_SPEED
	end
end

local function onCharacterAdded(character)
	setHumanoid(character:WaitForChild("Humanoid", 10))
end

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end

player.CharacterAdded:Connect(onCharacterAdded)

local function updateSprintButton()
	if not IS_MOBILE then
		return
	end

	sprintButton.BackgroundColor3 = mobileSprintEnabled and Color3.fromRGB(118, 50, 42) or Color3.fromRGB(47, 39, 31)
end

local function setSprintDesired(isEnabled)
	wantsSprint = isEnabled
end

local function updateSprintBar()
	local alpha = math.clamp(stamina / STAMINA_MAX, 0, 1)
	sprintFill.Size = UDim2.fromScale(alpha, 1)
	sprintBar.Visible = wantsSprint or stamina < STAMINA_MAX

	if sprintLockedUntilRecovery then
		sprintFill.BackgroundColor3 = Color3.fromRGB(95, 133, 154)
	else
		sprintFill.BackgroundColor3 = Color3.fromRGB(77, 191, 235)
	end
end

sprintButton.Activated:Connect(function()
	mobileSprintEnabled = not mobileSprintEnabled
	setSprintDesired(mobileSprintEnabled)
	updateSprintButton()
end)

updateSprintButton()
updateSprintBar()

local function selectSlot(index)
	if not hotbarSlots[index] then
		return
	end

	selectedSlotIndex = index

	for slotIndex, slotData in hotbarSlots do
		local isSelected = slotIndex == selectedSlotIndex
		slotData.button.BackgroundColor3 = isSelected and Color3.fromRGB(79, 59, 34) or Color3.fromRGB(24, 23, 21)
		slotData.stroke.Color = isSelected and Color3.fromRGB(255, 206, 126) or Color3.fromRGB(106, 98, 82)
		slotData.stroke.Thickness = isSelected and 2 or 1
		slotData.stroke.Transparency = isSelected and 0 or 0.15
	end
end

local function createSlot(index)
	local slot = Instance.new("TextButton")
	slot.Name = "Slot" .. index
	slot.LayoutOrder = index
	slot.Size = UDim2.fromOffset(DEFAULT_SLOT_SIZE, DEFAULT_SLOT_SIZE)
	slot.AutoButtonColor = false
	slot.BackgroundColor3 = Color3.fromRGB(24, 23, 21)
	slot.BackgroundTransparency = 0.12
	slot.BorderSizePixel = 0
	slot.Font = Enum.Font.GothamBold
	slot.Text = tostring(index)
	slot.TextColor3 = Color3.fromRGB(214, 207, 190)
	slot.TextSize = 18
	slot.Parent = hotbar
	addCorner(slot, 8)
	local stroke = addStroke(slot, Color3.fromRGB(106, 98, 82), 1, 0.15)

	local preview = Instance.new("ViewportFrame")
	preview.Name = "ItemPreview"
	preview.AnchorPoint = Vector2.new(0.5, 0.5)
	preview.Position = UDim2.fromScale(0.5, 0.45)
	preview.Size = UDim2.new(1, -2, 1, -6)
	preview.BackgroundTransparency = 1
	preview.BorderSizePixel = 0
	preview.LightColor = Color3.fromRGB(255, 235, 204)
	preview.Ambient = Color3.fromRGB(140, 118, 92)
	preview.Visible = false
	preview.ZIndex = 21
	preview.Parent = slot

	local itemName = Instance.new("TextLabel")
	itemName.Name = "ItemName"
	itemName.AnchorPoint = Vector2.new(0.5, 1)
	itemName.Position = UDim2.new(0.5, 0, 1, -5)
	itemName.Size = UDim2.new(1, -8, 0, 16)
	itemName.BackgroundTransparency = 1
	itemName.Font = Enum.Font.GothamMedium
	itemName.Text = ""
	itemName.TextColor3 = Color3.fromRGB(255, 247, 223)
	itemName.TextSize = 11
	itemName.TextTruncate = Enum.TextTruncate.AtEnd
	itemName.Parent = slot

	local itemCount = Instance.new("TextLabel")
	itemCount.Name = "ItemCount"
	itemCount.AnchorPoint = Vector2.new(1, 1)
	itemCount.Position = UDim2.new(1, -5, 1, -4)
	itemCount.Size = UDim2.fromOffset(26, 16)
	itemCount.BackgroundTransparency = 1
	itemCount.Font = Enum.Font.GothamBold
	itemCount.Text = ""
	itemCount.TextColor3 = Color3.fromRGB(255, 234, 188)
	itemCount.TextSize = 12
	itemCount.TextXAlignment = Enum.TextXAlignment.Right
	itemCount.Parent = slot

	hotbarSlots[index] = {
		button = slot,
		stroke = stroke,
		preview = preview,
		itemName = itemName,
		itemCount = itemCount,
	}
	slot:SetAttribute("DropKind", "hotbar")
	slot:SetAttribute("DropIndex", index)

	slot.Activated:Connect(function()
		selectSlot(index)
		selectHotbarSlotRemote:FireServer(index)
	end)

	slot.MouseButton1Down:Connect(function()
		if beginGuiDrag and latestHotbar[index] then
			beginGuiDrag("hotbar", index, latestHotbar[index])
		end
	end)

	return slot
end

for index = 1, SLOT_COUNT do
	createSlot(index)
end

local bagButton = Instance.new("TextButton")
bagButton.Name = "BagButton"
bagButton.LayoutOrder = SLOT_COUNT + 1
bagButton.Size = UDim2.fromOffset(DEFAULT_SLOT_SIZE, DEFAULT_SLOT_SIZE)
bagButton.AutoButtonColor = true
bagButton.Modal = false
bagButton.BackgroundColor3 = Color3.fromRGB(43, 35, 27)
bagButton.BackgroundTransparency = 0.05
bagButton.BorderSizePixel = 0
bagButton.Font = Enum.Font.GothamBold
bagButton.Text = "Bag"
bagButton.TextColor3 = Color3.fromRGB(255, 241, 210)
bagButton.TextSize = 15
bagButton.Parent = hotbar
addCorner(bagButton, 8)
addStroke(bagButton, Color3.fromRGB(185, 156, 96), 1, 0.05)

local bagKeyHint = Instance.new("TextLabel")
bagKeyHint.Name = "KeyHint"
bagKeyHint.AnchorPoint = Vector2.new(1, 0)
bagKeyHint.Position = UDim2.new(1, -5, 0, 5)
bagKeyHint.Size = UDim2.fromOffset(18, 18)
bagKeyHint.BackgroundColor3 = Color3.fromRGB(18, 16, 14)
bagKeyHint.BackgroundTransparency = 0.08
bagKeyHint.BorderSizePixel = 0
bagKeyHint.Font = Enum.Font.GothamBold
bagKeyHint.Text = "B"
bagKeyHint.TextColor3 = Color3.fromRGB(255, 241, 210)
bagKeyHint.TextSize = 11
bagKeyHint.Visible = not IS_MOBILE
bagKeyHint.Parent = bagButton
addCorner(bagKeyHint, 4)

local menuMouseLayer = Instance.new("TextButton")
menuMouseLayer.Name = "MenuMouseLayer"
menuMouseLayer.Size = UDim2.fromScale(1, 1)
menuMouseLayer.BackgroundTransparency = 1
menuMouseLayer.BorderSizePixel = 0
menuMouseLayer.Text = ""
menuMouseLayer.AutoButtonColor = false
menuMouseLayer.Modal = true
menuMouseLayer.Visible = false
menuMouseLayer.ZIndex = 0
menuMouseLayer.Parent = gui

local menu = Instance.new("Frame")
menu.Name = "InventoryMenu"
menu.AnchorPoint = Vector2.new(0.5, 0.5)
menu.Position = UDim2.fromScale(0.5, 0.46)
menu.Size = UDim2.fromScale(0.92, 0.78)
menu.BackgroundColor3 = Color3.fromRGB(22, 21, 19)
menu.BackgroundTransparency = 0.04
menu.BorderSizePixel = 0
menu.ClipsDescendants = true
menu.Visible = false
menu.ZIndex = 10
menu.Parent = gui
addCorner(menu, 8)
addStroke(menu, Color3.fromRGB(97, 89, 74), 1, 0.05)

local menuSizeLimit = Instance.new("UISizeConstraint")
menuSizeLimit.MaxSize = Vector2.new(760, 430)
menuSizeLimit.MinSize = Vector2.new(320, 280)
menuSizeLimit.Parent = menu

local sideTabs = Instance.new("Frame")
sideTabs.Name = "Tabs"
sideTabs.Position = UDim2.fromOffset(18, 18)
sideTabs.Size = UDim2.new(0, 150, 1, -36)
sideTabs.BackgroundTransparency = 1
sideTabs.Parent = menu

local tabsLayout = Instance.new("UIListLayout")
tabsLayout.FillDirection = Enum.FillDirection.Vertical
tabsLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabsLayout.Padding = UDim.new(0, 10)
tabsLayout.Parent = sideTabs

local content = Instance.new("Frame")
content.Name = "Content"
content.Position = UDim2.fromOffset(184, 18)
content.Size = UDim2.new(1, -202, 1, -36)
content.BackgroundColor3 = Color3.fromRGB(29, 28, 25)
content.BackgroundTransparency = 0.05
content.BorderSizePixel = 0
content.ClipsDescendants = true
content.Parent = menu
addCorner(content, 8)
addStroke(content, Color3.fromRGB(78, 72, 61), 1, 0.25)

local inventoryPage = Instance.new("Frame")
inventoryPage.Name = "InventoryPage"
inventoryPage.Size = UDim2.fromScale(1, 1)
inventoryPage.BackgroundTransparency = 1
inventoryPage.Parent = content

local capacityLabel = Instance.new("TextLabel")
capacityLabel.Name = "CapacityLabel"
capacityLabel.AnchorPoint = Vector2.new(1, 0)
capacityLabel.Position = UDim2.new(1, -18, 0, 10)
capacityLabel.Size = UDim2.fromOffset(130, 20)
capacityLabel.BackgroundTransparency = 1
capacityLabel.Font = Enum.Font.GothamBold
capacityLabel.Text = "Capacity 0/100"
capacityLabel.TextColor3 = Color3.fromRGB(225, 214, 190)
capacityLabel.TextSize = 12
capacityLabel.TextXAlignment = Enum.TextXAlignment.Right
capacityLabel.Parent = inventoryPage

local craftPage = Instance.new("Frame")
craftPage.Name = "CraftPage"
craftPage.Size = UDim2.fromScale(1, 1)
craftPage.BackgroundTransparency = 1
craftPage.Visible = false
craftPage.Parent = content

local function createTab(text, order)
	local tab = Instance.new("TextButton")
	tab.Name = text .. "Tab"
	tab.LayoutOrder = order
	tab.Size = UDim2.new(1, 0, 0, 46)
	tab.AutoButtonColor = true
	tab.BackgroundColor3 = Color3.fromRGB(38, 34, 29)
	tab.BorderSizePixel = 0
	tab.Font = Enum.Font.GothamBold
	tab.Text = text
	tab.TextColor3 = Color3.fromRGB(238, 228, 204)
	tab.TextSize = 15
	tab.Parent = sideTabs
	addCorner(tab, 8)
	addStroke(tab, Color3.fromRGB(98, 88, 70), 1, 0.2)
	return tab
end

local inventoryTab = createTab("Inventory", 1)
local craftTab = createTab("Craft", 2)

local function setPage(pageName)
	local showInventory = pageName == "Inventory"
	inventoryPage.Visible = showInventory
	craftPage.Visible = not showInventory
	inventoryTab.BackgroundColor3 = showInventory and Color3.fromRGB(74, 59, 38) or Color3.fromRGB(38, 34, 29)
	craftTab.BackgroundColor3 = showInventory and Color3.fromRGB(38, 34, 29) or Color3.fromRGB(74, 59, 38)
end

inventoryTab.Activated:Connect(function()
	setPage("Inventory")
end)

craftTab.Activated:Connect(function()
	setPage("Craft")
end)

local inventoryGrid = Instance.new("ScrollingFrame")
inventoryGrid.Name = "InventoryGrid"
inventoryGrid.Position = UDim2.fromOffset(18, 18)
inventoryGrid.Size = UDim2.new(1, -36, 1, -36)
inventoryGrid.BackgroundTransparency = 1
inventoryGrid.BorderSizePixel = 0
inventoryGrid.CanvasSize = UDim2.fromOffset(0, 0)
inventoryGrid.AutomaticCanvasSize = Enum.AutomaticSize.Y
inventoryGrid.ScrollBarThickness = 4
inventoryGrid.ScrollingDirection = Enum.ScrollingDirection.Y
inventoryGrid.Parent = inventoryPage
inventoryGrid:SetAttribute("DropKind", "bag")

local inventoryLayout = Instance.new("UIGridLayout")
inventoryLayout.CellSize = UDim2.fromOffset(64, 64)
inventoryLayout.CellPadding = UDim2.fromOffset(10, 10)
inventoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
inventoryLayout.FillDirectionMaxCells = 6
inventoryLayout.Parent = inventoryGrid

for index = 1, 30 do
	local cell = Instance.new("TextButton")
	cell.Name = "InventorySlot" .. index
	cell.LayoutOrder = index
	cell.AutoButtonColor = false
	cell.BackgroundColor3 = Color3.fromRGB(35, 34, 31)
	cell.BorderSizePixel = 0
	cell.Font = Enum.Font.GothamMedium
	cell.Text = ""
	cell.TextColor3 = Color3.fromRGB(245, 235, 210)
	cell.TextSize = 12
	cell.Parent = inventoryGrid
	inventoryCells[index] = cell
	cell:SetAttribute("DropKind", "bag")

	local preview = Instance.new("ViewportFrame")
	preview.Name = "ItemPreview"
	preview.AnchorPoint = Vector2.new(0.5, 0.5)
	preview.Position = UDim2.fromScale(0.5, 0.44)
	preview.Size = UDim2.new(1, -2, 1, -6)
	preview.BackgroundTransparency = 1
	preview.BorderSizePixel = 0
	preview.LightColor = Color3.fromRGB(255, 235, 204)
	preview.Ambient = Color3.fromRGB(140, 118, 92)
	preview.Visible = false
	preview.ZIndex = 12
	preview.Parent = cell

	local count = Instance.new("TextLabel")
	count.Name = "ItemCount"
	count.AnchorPoint = Vector2.new(1, 1)
	count.Position = UDim2.new(1, -6, 1, -5)
	count.Size = UDim2.fromOffset(30, 16)
	count.BackgroundTransparency = 1
	count.Font = Enum.Font.GothamBold
	count.Text = ""
	count.TextColor3 = Color3.fromRGB(255, 234, 188)
	count.TextSize = 12
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Parent = cell

	cell.MouseButton1Down:Connect(function()
		local itemName = cell:GetAttribute("ItemName")
		if beginGuiDrag and itemName then
			beginGuiDrag("bag", itemName, {
				itemName = itemName,
				count = latestInventory[itemName] or 0,
			})
		end
	end)

	addCorner(cell, 8)
	addStroke(cell, Color3.fromRGB(78, 72, 61), 1, 0.35)
end

local dragGhost = Instance.new("TextLabel")
dragGhost.Name = "DragGhost"
dragGhost.Size = UDim2.fromOffset(88, 30)
dragGhost.BackgroundColor3 = Color3.fromRGB(32, 30, 26)
dragGhost.BackgroundTransparency = 0.06
dragGhost.BorderSizePixel = 0
dragGhost.Font = Enum.Font.GothamBold
dragGhost.TextColor3 = Color3.fromRGB(255, 238, 205)
dragGhost.TextSize = 14
dragGhost.Visible = false
dragGhost.ZIndex = 80
dragGhost.Parent = gui
addCorner(dragGhost, 7)
addStroke(dragGhost, Color3.fromRGB(185, 156, 96), 1, 0.1)

local draggingStack = nil

beginGuiDrag = function(kind, indexOrItemName, stack)
	if not stack or (stack.count or 0) <= 0 then
		return
	end

	draggingStack = {
		kind = kind,
		indexOrItemName = indexOrItemName,
		stack = stack,
	}
	dragGhost.Text = stack.itemName .. " x" .. tostring(stack.count)
	dragGhost.Visible = true
end

local function getDropTarget()
	local mouseLocation = UserInputService:GetMouseLocation()
	local point = Vector2.new(mouseLocation.X, mouseLocation.Y)

	local function isPointInside(guiObject)
		local position = guiObject.AbsolutePosition
		local size = guiObject.AbsoluteSize
		return point.X >= position.X
			and point.X <= position.X + size.X
			and point.Y >= position.Y
			and point.Y <= position.Y + size.Y
	end

	for index, slotData in hotbarSlots do
		if slotData.button.Visible and isPointInside(slotData.button) then
			return "hotbar", index
		end
	end

	local hotbarPosition = hotbar.AbsolutePosition
	local hotbarSize = hotbar.AbsoluteSize
	local expandedHotbarTop = hotbarPosition.Y - 24
	local expandedHotbarBottom = hotbarPosition.Y + hotbarSize.Y + 24
	if point.Y >= expandedHotbarTop and point.Y <= expandedHotbarBottom then
		local closestIndex = nil
		local closestDistance = math.huge

		for index, slotData in hotbarSlots do
			local button = slotData.button
			if button.Visible then
				local centerX = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
				local distance = math.abs(point.X - centerX)
				if distance < closestDistance then
					closestDistance = distance
					closestIndex = index
				end
			end
		end

		if closestIndex and closestDistance <= (hotbarSlots[closestIndex].button.AbsoluteSize.X / 2 + DEFAULT_SLOT_GAP) then
			return "hotbar", closestIndex
		end
	end

	if menu.Visible and inventoryGrid.Visible and isPointInside(inventoryGrid) then
		return "bag", nil
	end

	local guiObjects = playerGui:GetGuiObjectsAtPosition(mouseLocation.X, mouseLocation.Y)

	for _, object in guiObjects do
		local cursor = object
		while cursor and cursor ~= gui do
			local dropKind = cursor:GetAttribute("DropKind")
			if dropKind then
				return dropKind, cursor:GetAttribute("DropIndex")
			end
			cursor = cursor.Parent
		end
	end

	return nil, nil
end

local function updateInventoryUi(inventory, hotbarItems, selectedSlot, capacity)
	inventory = inventory or {}
	hotbarItems = hotbarItems or {}
	latestInventory = inventory
	latestHotbar = hotbarItems
	capacity = capacity or 100

	local totalCount = 0
	for _, count in inventory do
		totalCount += count
	end
	for _, stack in hotbarItems do
		totalCount += stack and stack.count or 0
	end
	capacityLabel.Text = "Capacity " .. tostring(totalCount) .. "/" .. tostring(capacity)

	for index, slotData in hotbarSlots do
		local stack = hotbarItems[index]
		slotData.button.Text = stack and "" or tostring(index)
		slotData.itemName.Text = stack and stack.itemName or ""
		slotData.itemCount.Text = stack and stack.count > 1 and tostring(stack.count) or ""
		setItemPreview(slotData.preview, stack and stack.itemName or nil)
	end

	for index, cell in inventoryCells do
		cell.Text = ""
		cell:SetAttribute("ItemName", nil)
		local preview = cell:FindFirstChild("ItemPreview")
		if preview then
			clearPreview(preview)
		end
		local countLabel = cell:FindFirstChild("ItemCount")
		if countLabel then
			countLabel.Text = ""
		end
	end

	local cellIndex = 1
	local itemNames = {}
	for itemName in inventory do
		table.insert(itemNames, itemName)
	end
	table.sort(itemNames)

	for _, itemName in itemNames do
		local count = inventory[itemName]
		local cell = inventoryCells[cellIndex]
		if cell and count and count > 0 then
			cell.Text = itemName
			cell:SetAttribute("ItemName", itemName)
			local preview = cell:FindFirstChild("ItemPreview")
			if preview then
				setItemPreview(preview, itemName)
			end
			local countLabel = cell:FindFirstChild("ItemCount")
			if countLabel then
				countLabel.Text = count > 1 and tostring(count) or ""
			end
			cellIndex += 1
		end
	end

	if typeof(selectedSlot) == "number" then
		selectSlot(math.clamp(math.floor(selectedSlot), 1, SLOT_COUNT))
	end
end

inventoryUpdatedRemote.OnClientEvent:Connect(updateInventoryUi)

local recipeList = Instance.new("Frame")
recipeList.Name = "RecipeList"
recipeList.Position = UDim2.fromOffset(18, 18)
recipeList.Size = UDim2.new(1, -36, 1, -36)
recipeList.BackgroundTransparency = 1
recipeList.Parent = craftPage

local recipeLayout = Instance.new("UIListLayout")
recipeLayout.FillDirection = Enum.FillDirection.Vertical
recipeLayout.SortOrder = Enum.SortOrder.LayoutOrder
recipeLayout.Padding = UDim.new(0, 10)
recipeLayout.Parent = recipeList

local recipes = {
	{ name = "Primitive Axe", ingredients = "Bone x1  +  Dry Stick x1" },
}

for index, recipe in recipes do
	local row = Instance.new("TextButton")
	row.Name = recipe.name
	row.LayoutOrder = index
	row.Size = UDim2.new(1, 0, 0, 64)
	row.AutoButtonColor = true
	row.BackgroundColor3 = Color3.fromRGB(35, 34, 31)
	row.BorderSizePixel = 0
	row.Font = Enum.Font.GothamBold
	row.Text = recipe.name .. "\n" .. recipe.ingredients
	row.TextColor3 = Color3.fromRGB(245, 235, 210)
	row.TextSize = 15
	row.TextXAlignment = Enum.TextXAlignment.Left
	row.Parent = recipeList
	addCorner(row, 8)
	addStroke(row, Color3.fromRGB(101, 91, 69), 1, 0.2)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 16)
	padding.Parent = row
end

local function raiseMenuZIndex()
	for _, descendant in menu:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.ZIndex = 11
		elseif descendant:IsA("UIStroke") then
			descendant.ZIndex = 12
		end
	end
end

raiseMenuZIndex()

local function updateResponsiveLayout()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local viewportSize = camera.ViewportSize
	local slotCountWithBag = SLOT_COUNT + 1
	local availableWidth = math.max(viewportSize.X - 24, 240)
	local slotSize = math.clamp(
		math.floor((availableWidth - DEFAULT_SLOT_GAP * (slotCountWithBag - 1)) / slotCountWithBag),
		MIN_SLOT_SIZE,
		DEFAULT_SLOT_SIZE
	)
	local hotbarWidth = (slotSize + DEFAULT_SLOT_GAP) * slotCountWithBag - DEFAULT_SLOT_GAP
	local hotbarReservedHeight = slotSize + 42
	local menuHeight = math.clamp(math.floor(viewportSize.Y - hotbarReservedHeight - 24), 280, 430)
	local menuWidth = math.clamp(math.floor(viewportSize.X * 0.92), 320, 760)

	hotbar.Size = UDim2.fromOffset(hotbarWidth, slotSize)
	for _, slotData in hotbarSlots do
		slotData.button.Size = UDim2.fromOffset(slotSize, slotSize)
		slotData.button.TextSize = slotSize <= 48 and 15 or 18
	end
		bagButton.Size = UDim2.fromOffset(slotSize, slotSize)
		bagButton.TextSize = slotSize <= 48 and 13 or 15
		clockPanel.Size = viewportSize.X < 620 and UDim2.fromOffset(118, 36) or UDim2.fromOffset(142, 42)
		clockPanel.Position = viewportSize.X < 620 and UDim2.new(1, -12, 0, 12) or UDim2.new(1, -18, 0, 18)
		clockText.TextSize = viewportSize.X < 620 and 19 or 23
		sprintBar.Size = viewportSize.X < 620 and UDim2.fromOffset(220, 12) or UDim2.fromOffset(310, 14)
		sprintBar.Position = UDim2.new(0.5, 0, 1, -(slotSize + 52))
		sprintButton.Size = viewportSize.X < 620 and UDim2.fromOffset(76, 44) or UDim2.fromOffset(86, 48)
		sprintButton.Position = UDim2.new(1, -24, 1, -(slotSize + 54))
		sprintButton.TextSize = viewportSize.X < 620 and 13 or 15
		menu.Size = UDim2.fromOffset(menuWidth, menuHeight)
		menu.Position = UDim2.fromOffset(math.floor(viewportSize.X / 2), math.floor((viewportSize.Y - hotbarReservedHeight) / 2))

	local compactMenu = viewportSize.X < 620
	sideTabs.Size = compactMenu and UDim2.new(0, 112, 1, -36) or UDim2.new(0, 150, 1, -36)
	content.Position = compactMenu and UDim2.fromOffset(142, 18) or UDim2.fromOffset(184, 18)
	content.Size = compactMenu and UDim2.new(1, -160, 1, -36) or UDim2.new(1, -202, 1, -36)

	local cellSize = compactMenu and 52 or 64
	inventoryLayout.CellSize = UDim2.fromOffset(cellSize, cellSize)
	inventoryLayout.CellPadding = UDim2.fromOffset(compactMenu and 8 or 10, compactMenu and 8 or 10)
end

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateResponsiveLayout)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateResponsiveLayout)
end

local function setMenuOpen(isOpen)
	menuMouseLayer.Visible = isOpen
	menu.Visible = isOpen
	crosshair.Visible = not isOpen
	if isOpen and not IS_MOBILE then
		setSprintDesired(false)
	end
	player.CameraMode = isOpen and Enum.CameraMode.Classic or Enum.CameraMode.LockFirstPerson
	UserInputService.MouseIconEnabled = isOpen

	if isOpen then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		task.defer(function()
			UserInputService.MouseIconEnabled = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end)
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	end
end

local function toggleMenu()
	setMenuOpen(not menu.Visible)
end

bagButton.Activated:Connect(toggleMenu)

local function handleSprintAction(_, inputState)
	if IS_MOBILE then
		return Enum.ContextActionResult.Pass
	end

	if inputState == Enum.UserInputState.Begin then
		setSprintDesired(true)
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		setSprintDesired(false)
	end

	return Enum.ContextActionResult.Sink
end

ContextActionService:BindActionAtPriority(
	"SurvivalSprint",
	handleSprintAction,
	false,
	Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.LeftShift,
	Enum.KeyCode.RightShift
)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		setSprintDesired(true)
		return
	end

	if gameProcessed then
		return
	end

	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.Backquote then
		toggleMenu()
		return
	end

	local slotIndex = KEYCODE_TO_SLOT[input.KeyCode]
	if slotIndex and slotIndex <= SLOT_COUNT then
		selectSlot(slotIndex)
		selectHotbarSlotRemote:FireServer(slotIndex)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		if not IS_MOBILE then
			setSprintDesired(false)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseButton1 and draggingStack then
		local dropKind, dropIndex = getDropTarget()
		if dropKind then
			moveInventoryItemRemote:FireServer(draggingStack.kind, draggingStack.indexOrItemName, dropKind, dropIndex)
		end

		draggingStack = nil
		dragGhost.Visible = false
	end
end)

setPage("Inventory")
setMenuOpen(false)
selectSlot(selectedSlotIndex)
updateResponsiveLayout()

RunService.RenderStepped:Connect(function(deltaTime)
	if draggingStack then
		local mouseLocation = UserInputService:GetMouseLocation()
		dragGhost.Position = UDim2.fromOffset(mouseLocation.X + 12, mouseLocation.Y + 12)
	end

	if menu.Visible then
		player.CameraMode = Enum.CameraMode.Classic
		UserInputService.MouseIconEnabled = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	else
		UserInputService.MouseIconEnabled = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	end

	local humanoid = currentHumanoid or getHumanoid()
	if currentHumanoid ~= humanoid then
		setHumanoid(humanoid)
	end

	local isMoving = humanoid and humanoid.MoveDirection.Magnitude > 0.05
	local canSprint = wantsSprint and isMoving and not menu.Visible and not sprintLockedUntilRecovery and stamina > 0
	if canSprint then
		stamina = math.max(0, stamina - STAMINA_DRAIN_PER_SECOND * deltaTime)
		if stamina <= 0 then
			sprintLockedUntilRecovery = true
			canSprint = false
		end
	else
		stamina = math.min(STAMINA_MAX, stamina + STAMINA_RECOVER_PER_SECOND * deltaTime)
		if sprintLockedUntilRecovery and stamina >= SPRINT_RESTART_THRESHOLD then
			sprintLockedUntilRecovery = false
		end
	end

	if humanoid then
		humanoid.WalkSpeed = canSprint and SPRINT_SPEED or WALK_SPEED

		if canSprint and isMoving then
			cameraBobTime += deltaTime * 13
			local targetOffset = Vector3.new(
				math.sin(cameraBobTime * 0.5) * 0.09,
				math.abs(math.sin(cameraBobTime)) * 0.18 - 0.08,
				0
			)
			local targetRoll = math.sin(cameraBobTime * 0.5) * 0.012
			cameraBobOffset = cameraBobOffset:Lerp(targetOffset, math.clamp(deltaTime * 12, 0, 1))
			cameraBobRoll = cameraBobRoll + (targetRoll - cameraBobRoll) * math.clamp(deltaTime * 12, 0, 1)
		else
			cameraBobOffset = cameraBobOffset:Lerp(Vector3.zero, math.clamp(deltaTime * 10, 0, 1))
			cameraBobRoll = cameraBobRoll + (0 - cameraBobRoll) * math.clamp(deltaTime * 10, 0, 1)
		end

		humanoid.CameraOffset = cameraBobOffset * 0.35
	end

	updateSprintBar()
end)

RunService:BindToRenderStep("SurvivalSprintCameraBob", Enum.RenderPriority.Camera.Value + 1, function()
	local camera = workspace.CurrentCamera
	if not camera or menu.Visible then
		return
	end

	if cameraBobOffset.Magnitude < 0.001 and math.abs(cameraBobRoll) < 0.001 then
		return
	end

	camera.CFrame = camera.CFrame * CFrame.new(cameraBobOffset.X, cameraBobOffset.Y, 0) * CFrame.Angles(0, 0, cameraBobRoll)
end)
