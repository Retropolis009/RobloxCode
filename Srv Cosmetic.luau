local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Players = game:GetService("Players")

local EquipCosmeticRF = ReplicatedStorage.Events.RemoteFunctions.EquipCosmetic
local DataManager = require(ServerScriptService.DataStore.Main.Manager)
local CoreInformation = require(game:GetService("ServerStorage").Modules.Base.CoreInformation)
local CosmeticsFolder = ReplicatedStorage.Assets.Cosmetics

local pendingSaves = {}

local function batchSave(player)
	if pendingSaves[player] then return end
	pendingSaves[player] = true
	task.defer(function()
		DataManager.Shared:Save(player)
		pendingSaves[player] = nil
	end)
end

local function HideDefaultAccessories(character, cosmeticType)
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local shouldHide = false

			if cosmeticType == "Head" and accessory.AccessoryType == Enum.AccessoryType.Hat then
				shouldHide = true
			elseif cosmeticType == "Torso" and accessory.AccessoryType == Enum.AccessoryType.Shirt then
				shouldHide = true
			elseif cosmeticType == "Legs" and accessory.AccessoryType == Enum.AccessoryType.Pants then
				shouldHide = true
			end

			if shouldHide then
				for _, part in ipairs(accessory:GetDescendants()) do
					if part:IsA("BasePart") then
						part:SetAttribute("OriginalTransparency", part.Transparency)
						part.Transparency = 1
					end
				end
			end
		end
	end
end

local function RestoreDefaultAccessories(character, cosmeticType)
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local shouldRestore = false

			if cosmeticType == "Head" and accessory.AccessoryType == Enum.AccessoryType.Hat then
				shouldRestore = true
			elseif cosmeticType == "Torso" and accessory.AccessoryType == Enum.AccessoryType.Shirt then
				shouldRestore = true
			elseif cosmeticType == "Legs" and accessory.AccessoryType == Enum.AccessoryType.Pants then
				shouldRestore = true
			end

			if shouldRestore then
				for _, part in ipairs(accessory:GetDescendants()) do
					if part:IsA("BasePart") and part:GetAttribute("OriginalTransparency") then
						part.Transparency = part:GetAttribute("OriginalTransparency")
						part:SetAttribute("OriginalTransparency", nil)
					end
				end
			end
		end
	end
end

local function RemoveCosmetic(character, cosmeticType)
	for _, child in ipairs(character:GetChildren()) do
		if (child:IsA("Model") or child:IsA("Accessory")) and child:GetAttribute("CosmeticType") == cosmeticType then
			child:Destroy()
		end
	end

	local stillHasType = false
	for _, child in ipairs(character:GetChildren()) do
		if (child:IsA("Model") or child:IsA("Accessory")) and child:GetAttribute("CosmeticType") == cosmeticType then
			stillHasType = true
			break
		end
	end

	if not stillHasType then
		RestoreDefaultAccessories(character, cosmeticType)
	end
end
local function AttachCosmeticModel(character, cosmeticName, cosmeticType)
	local cosmeticModel = CosmeticsFolder:FindFirstChild(cosmeticName)
	if not cosmeticModel then return false end
	local accessory = cosmeticModel:FindFirstChildWhichIsA("Accessory")
	if not accessory then return false end

	local clone = accessory:Clone()
	clone.Parent = character
	clone:SetAttribute("CosmeticType", cosmeticType)

	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if (cosmeticType == "Head" or cosmeticType == "Torso") and humanoid then
		humanoid:AddAccessory(clone)
		HideDefaultAccessories(character, cosmeticType)
		return true
	end
	if cosmeticType == "Legs" then
		local leftLeg = character:FindFirstChild("Left Leg")
		local rightLeg = character:FindFirstChild("Right Leg")
		if not leftLeg or not rightLeg then return false end

		
		local RightlegOffset = Vector3.new(-0.194, -0.210, -0.126)
		local LeftlegOffset = Vector3.new(0.194, -0.210, -0.126)

		for _, part in ipairs(clone:GetDescendants()) do
			if part:IsA("BasePart") or part:IsA("UnionOperation") then

				local leftAttach = part:FindFirstChild("LeftFootAttachment")
				local rightAttach = part:FindFirstChild("RightFootAttachment")

				part.CanCollide = false
				part.Anchored = false

				
				if rightAttach then
					rightAttach.Position = Vector3.zero
					rightAttach.Orientation = Vector3.zero

					
					local finalCFrame = rightLeg.CFrame * CFrame.new(RightlegOffset)

					part.CFrame = finalCFrame

					
					local weld = Instance.new("Weld")
					weld.Part0 = rightLeg
					weld.Part1 = part
					weld.C0 = rightLeg.CFrame:Inverse() * finalCFrame
					weld.Parent = part
				end

				
				if leftAttach then
					leftAttach.Position = Vector3.zero
					leftAttach.Orientation = Vector3.zero

				
					local finalCFrame = leftLeg.CFrame * CFrame.new(LeftlegOffset)

					part.CFrame = finalCFrame

					local weld = Instance.new("Weld")
					weld.Part0 = leftLeg
					weld.Part1 = part
					weld.C0 = leftLeg.CFrame:Inverse() * finalCFrame
					weld.Parent = part
				end
			end
		end

		HideDefaultAccessories(character, cosmeticType)
		return true
	end
	
	return false
end

EquipCosmeticRF.OnServerInvoke = function(player, cosmeticName)
	local coreCosmetics = CoreInformation.TypesToData.Cosmetics
	local coreInfo = coreCosmetics and coreCosmetics[cosmeticName]
	if not coreInfo then return false end

	local slot = DataManager.Shared:Get(player, "Main Player Data.Strings.Current Slot")
	if not slot then return false end

	local cosmetics = DataManager.Shared:Get(player, slot .. ".Cosmetics")
	if not cosmetics or not cosmetics[cosmeticName] then return false end

	local character = player.Character
	if not character then return false end

	local cosmeticType = coreInfo.Type 
	if not cosmeticType then return false end

	print("[EquipCosmetic] Processing type:", cosmeticType)

	
	RemoveCosmetic(character, cosmeticType)

	
	for name, data in pairs(cosmetics) do
		if data.Type == cosmeticType and name ~= cosmeticName and data.Equipped then
			local path = string.format("%s.Cosmetics.%s.Equipped", slot, name)
			DataManager.Shared:Set(player, path, false)
		end
	end

	
	local clickedPath = string.format("%s.Cosmetics.%s.Equipped", slot, cosmeticName)
	local newState = DataManager.Shared:ToggleBoolean(player, clickedPath)
	print(string.format("[EquipCosmetic] %s -> Equipped = %s", cosmeticName, tostring(newState)))

	
	if newState then
		if not AttachCosmeticModel(character, cosmeticName, cosmeticType) then
			return false
		end
	end

	
	batchSave(player)
	return true
end

local function OnCharacterAdded(player, character)
	local head = character:WaitForChild("Head", 5)
	local upperTorso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	local leftLeg = character:WaitForChild("LeftUpperLeg", 5)
	local rightLeg = character:WaitForChild("RightUpperLeg", 5)

	if not head or not upperTorso or not leftLeg or not rightLeg then
		warn("[AutoEquip] Some essential parts missing for:", player.Name)
		return
	end

	local slot = DataManager.Shared:Get(player, "Main Player Data.Strings.Current Slot")
	if not slot then
		return
	end

	local cosmetics = DataManager.Shared:Get(player, slot .. ".Cosmetics")
	if not cosmetics then
		return
	end

	for cosmeticName, data in pairs(cosmetics) do
		local coreInfo = CoreInformation.TypesToData.Cosmetics[cosmeticName]

		if data.Equipped and coreInfo then
			print(string.format("[AutoEquip] Applying cosmetic: %s (%s)", cosmeticName, coreInfo.Type))
			local success = AttachCosmeticModel(character, cosmeticName, coreInfo.Type)
			if success then
				
			else
				warn("[AutoEquip] Failed to attach cosmetic:", cosmeticName)
			end
		else
		end
	end
end


Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)
end


Players.PlayerRemoving:Connect(function(player)
	DataManager.Shared:Save(player)
end)