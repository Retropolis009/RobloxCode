--Main UI Handler Responsible For Setting Up Sounds Pages Buttons 
--For additions to UI add them inside the Types ={}
--Init,CloseFrames,SetupButtons,PlaySound Helpers To Be Used In The Pages
--Handles Inventory Selling Settings UpdateLog and Cosmetic 

local MainUI = {}
local Connections = {}
local BaseSettings = require(game.ReplicatedStorage:WaitForChild("GameSettings"):WaitForChild("BaseSettings"))
function MainUI.Init(Player : Player)
	local myUI = Player.PlayerGui:WaitForChild("Main")
	MainUI.SetupButtons(Player,myUI)
	warn("[Client] Initializing Main UI")
end
function MainUI.CloseFrames(UI : ScreenGui)
	local Pages = UI:WaitForChild("Pages")
	for _,Page in pairs(Pages:GetChildren()) do
		if Page:IsA("ImageLabel") and Page.Name ~= "Information" then
			Page.Visible = false
			Page.Position = UDim2.fromScale(0.5,2)
		end
	end
	task.wait()
end
function MainUI.SetupButtons(Player: Player,UI : ScreenGui)
	local Buttons = UI:WaitForChild("Buttons")
	local Pages = UI:WaitForChild("Pages")
	local Tweening 
	task.wait(.1)
	MainUI.CloseFrames(UI)
	for _, Button in pairs(Buttons:GetChildren()) do
		if Button:IsA("TextButton") then
			warn("FOUND!")
			local myFrame = Button.Name
			Button.MouseButton1Down:Connect(function()
				if not Pages:FindFirstChild(myFrame) then warn("FAILED TO FIND PAGE") return end
				if Tweening then return end
				BaseSettings.CleanTable(Connections)
				Connections = {}
				if Pages:FindFirstChild(myFrame).Visible then return MainUI.CloseFrames(UI) end
				MainUI.PlaySound(15675059323,.4)
				MainUI.CloseFrames(UI)
				Pages:FindFirstChild(myFrame).Visible = true
				local Page : ImageLabel = 	Pages:FindFirstChild(myFrame)
				Page:TweenPosition(UDim2.fromScale(0.5,.5),Enum.EasingDirection.In,Enum.EasingStyle.Bounce,.6)
				Tweening = true
				task.delay(.61,function()
					Tweening = false
				end)
				MainUI.Setup(Player,myFrame)
			end)

		end
	end
	for _, Spots in pairs(game.Workspace:WaitForChild("Shop"):GetChildren()) do
		if Spots and Spots.Name == "Sell" then
			local Base : BasePart = Spots:WaitForChild("Base")
			Base.Touched:Connect(function(hit)
				if hit:IsDescendantOf(game.Workspace.Live) and hit.Parent and game.Players:GetPlayerFromCharacter(hit.Parent) then
					local FoundPlayer = game.Players:GetPlayerFromCharacter(hit.Parent)
					if FoundPlayer ~= Player then return end
					if Tweening then return end
					local myFrame = "Sell"
					BaseSettings.CleanTable(Connections)
					Connections = {}
					if Pages:FindFirstChild("Sell").Visible then return MainUI.CloseFrames(UI) end
					MainUI.PlaySound(15675059323,.4)
					MainUI.CloseFrames(UI)
					Pages:FindFirstChild(myFrame).Visible = true
					local Page : ImageLabel = 	Pages:FindFirstChild(myFrame)
					Page:TweenPosition(UDim2.fromScale(0.5,.5),Enum.EasingDirection.In,Enum.EasingStyle.Bounce,.6)
					Tweening = true
					task.delay(.61,function()
						Tweening = false
					end)
					MainUI.Setup(Player,myFrame)
				end
			end)
		end
	end
	warn("[Client] Initialized Main UI")
end
function MainUI.PlaySound(SoundID : number, Volume : number)
	local Sound : Sound = Instance.new("Sound",game.ReplicatedStorage)
	Sound.SoundId = "rbxassetid://"..SoundID
	Sound.Volume = Volume or .5
	Sound:Play()
	print(Sound.TimeLength)
	game.Debris:AddItem(Sound,4)
end

function MainUI.Setup(Player : Player , Type : string)
	local GetInvoke = game.ReplicatedStorage.Events.RemoteFunctions.Retrieve
	local Types = {
		["Inventory"] = function() 
			local InventoryUI = Player.PlayerGui.Main.Pages.Inventory
			local Yield = false
			local InventoryCache = {}

			local function EmptyInv()
				for _, Buttons in pairs(InventoryUI.Inv:GetChildren()) do
					if Buttons and Buttons:IsA("TextButton") and Buttons.Name ~= "Template" then
						Buttons:Destroy()
					end
				end
			end

			local LockedItems = {}
			local SelectedItem = nil
			local isGridSmall = false
			local Current = "Crops"

			local LockButton = InventoryUI:WaitForChild("Lock")
			local GridButton = InventoryUI:WaitForChild("UiGrid")
			local SearchBox = InventoryUI:WaitForChild("SearchBox")
			local SearchButton = InventoryUI:WaitForChild("Search")

			local success, savedLocks = pcall(function()
				return GetInvoke:InvokeServer("GetLocks")
			end)

			if success and typeof(savedLocks) == "table" then
				for name, state in pairs(savedLocks) do
					LockedItems[name] = state
				end
				print("[Inventory] Loaded & merged LockedItems from server:")
				print(LockedItems)
			else
				warn("[Inventory] Failed to load locks or received invalid table — preserving any local locks.")
			end

			Connections["Close"] = InventoryUI.Close.MouseButton1Down:Connect(function()
				BaseSettings.CleanTable(Connections)
				Connections = {}
				MainUI.CloseFrames(Player.PlayerGui.Main)
				EmptyInv()
				print("[Inventory] Saving LockedItems on close:")
				print(LockedItems)
				game.ReplicatedStorage.Events.RemoteEvents.BaseCast:FireServer("SaveLocks", LockedItems)
			end)

			local function FilterInventory(searchText)
				searchText = string.lower(searchText)
				for _, item in pairs(InventoryUI.Inv:GetChildren()) do
					if item:IsA("TextButton") and item.Name ~= "Template" then
						local label = item:FindFirstChild("TextLabel")
						local itemText = string.lower(label and label.Text or item.Name)
						item.Visible = searchText == "" or string.find(itemText, searchText)
					end
				end
			end

			Connections["SearchButton"] = SearchButton.MouseButton1Down:Connect(function()
				MainUI.PlaySound(15675059323, 0.4)
				local text = SearchBox.Text or ""
				FilterInventory(text)
			end)

			Connections["SearchBoxEnter"] = SearchBox.FocusLost:Connect(function(enterPressed)
				if enterPressed then
					MainUI.PlaySound(15675059323, 0.4)
					local text = SearchBox.Text or ""
					FilterInventory(text)
				end
			end)

			local function CreateFormat(myType : string)
				if Yield then return end
				Yield = true	
				task.delay(1,function() Yield = false end)

				local DataTypes = {
					["Crops"] = {"Crops","Seeds"},
					["Items"] = {"Items"},
					["Pets"] = {"Pets","Eggs"},
				}

				local GetDataType = DataTypes[myType]
				if not GetDataType then
					EmptyInv()
					CreateFormat("Crops")
					return
				end

				local function CreateTemplate(TemplateName : string , TemplateAmount : number, DataType : string, Data)
					local RealNameCast = string.split(TemplateName,"|")[1] or TemplateName

					if InventoryUI.Inv:FindFirstChild(TemplateName) then
						local GetFrame = InventoryUI.Inv:FindFirstChild(TemplateName)
						local GetAmount = GetFrame:GetAttribute("Amount")
						GetFrame.Text = TemplateName.." | "..GetAmount + TemplateAmount .."x"
						return
					end

					local Template = InventoryUI.Template:Clone()
					Template.Name = TemplateName
					Template:SetAttribute("Amount",TemplateAmount)
					Template:SetAttribute("Type",DataType)
					local xAmount = if TemplateAmount > 1 then TemplateAmount.."x" else "1x"
					Template.TextLabel.Text = RealNameCast.." | "..xAmount
					Template.Parent = InventoryUI.Inv
					Template.Visible = true
					Template:SetAttribute("DefaultSize", Template.Size)

					local isLocked = LockedItems[TemplateName] == true
					Template.LockLabel.Visible = isLocked
					Template.LayoutOrder = isLocked and -1 or 0

					Connections[TemplateName.."Select"] = Template.MouseButton1Down:Connect(function()
						MainUI.PlaySound(15675059323, .4)
						SelectedItem = Template
						print("[Inventory] Selected:", TemplateName, "Locked =", LockedItems[TemplateName])
					end)
					Connections[TemplateName.."HoverEnter"] = Template.MouseEnter:Connect(function()
						MainUI.PlaySound(542332175, 0.5)

						local itemType = Template:GetAttribute("Type")
						local data = nil

						
						if itemType ~= "Items" then
							for mainType, subGroups in pairs(InventoryCache) do
								if typeof(subGroups) == "table" then
									for subType, group in pairs(subGroups) do
										if subType == itemType and group[TemplateName] then
											data = group[TemplateName]
											break
										end
									end
								end
								if data then break end
							end
						end

						if itemType == "Items" then
							local CoreInformation = require(game:GetService("ReplicatedStorage").Classes.Server.Shared:WaitForChild("CoreInformation"))
							local itemInfo = CoreInformation.TypesToData.Items[TemplateName]

							if not itemInfo then
								warn("[Inventory] Missing CoreInformation entry for item:", TemplateName)
								return
							end

							local itemPage = Player.PlayerGui.Main.Pages:FindFirstChild("ItemsInfo")
							local defaultInfoPage = Player.PlayerGui.Main.Pages:FindFirstChild("Information")

							if defaultInfoPage then
								defaultInfoPage.Visible = false
							end

							if itemPage then
								itemPage.Visible = true
								local targetPos = UDim2.new(0.874, 0, 0.516, 0)
								if itemPage.Position ~= targetPos then
									itemPage.Position = targetPos
								end

								local frame = itemPage:FindFirstChildWhichIsA("Frame")
								if frame then
									local function SetField(labelName, prefix, value)
										local label = frame:FindFirstChild(labelName)
										if label and label:IsA("TextLabel") then
											label.Text = prefix .. tostring(value or "N/A")
										end
									end

									SetField("Name", "Name: ", itemInfo.Name)
									SetField("Rarity", "Rarity: ", itemInfo.Rarity)
									SetField("Description", "Description: ", itemInfo.Description)
								end
							end
						else
							if not data then return end

							local infoPage = Player.PlayerGui.Main.Pages:FindFirstChild("Information")
							if not infoPage then return end

							infoPage.Visible = true
							local infoFrame = infoPage:FindFirstChildWhichIsA("Frame")
							if not infoFrame then return end

							local function SetLabel(frame, labelName, prefix, value)
								local lbl = frame:FindFirstChild(labelName)
								if lbl and lbl:IsA("TextLabel") then
									lbl.Text = prefix .. tostring(value or "N/A")
								end
							end

							SetLabel(infoFrame, "Money", "Money: ", data.Money)
							SetLabel(infoFrame, "Mutations", "Mutation: ", data.Mutation)
							SetLabel(infoFrame, "Name", "Name: ", data.Name)
							SetLabel(infoFrame, "Rarity", "Rarity: ", data.Rarity)
							SetLabel(infoFrame, "Size", "Size: ", data.Size)
						end
					end)

					Connections[TemplateName.."HoverLeave"] = Template.MouseLeave:Connect(function()
						local infoPage = Player.PlayerGui.Main.Pages:FindFirstChild("Information")
						local itemPage = Player.PlayerGui.Main.Pages:FindFirstChild("ItemsInfo")

						if infoPage then infoPage.Visible = false end
						if itemPage then itemPage.Visible = false end
					end)

				end

				local GetInventoryInformation = GetInvoke:InvokeServer("Data", GetDataType)
				if GetInventoryInformation then
					InventoryCache[myType] = GetInventoryInformation
					for TypeData, DataTable in pairs(GetInventoryInformation) do
						if DataTable then
							for DataName, DataValue in pairs(DataTable) do
								if DataValue then
									CreateTemplate(DataName, DataValue.Quantity, TypeData, DataValue)
								end
							end
						end
					end
				end

				print("[Inventory] Inventory created for", myType)
				print("[Inventory] Current LockedItems:")
				print(LockedItems)
				print("This is the cache",InventoryCache)
			end

			EmptyInv()
			CreateFormat("Crops")

			
			for _, Button in pairs(InventoryUI.Buttons:GetChildren()) do
				if Button and Button:IsA("TextButton") then
					Connections[Button] = Button.MouseButton1Down:Connect(function()
						if Yield then return end
						MainUI.PlaySound(15675059323, .4)
						Current = Button.Name
						EmptyInv()
						CreateFormat(Button.Name)
					end)
				end
			end

		
			Connections["GridButton"] = GridButton.MouseButton1Down:Connect(function()
				MainUI.PlaySound(15675059323, 0.4)
				isGridSmall = not isGridSmall

				local gridLayout = InventoryUI.Inv:FindFirstChildOfClass("UIGridLayout")
				if not gridLayout then
					warn("[Grid] No UIGridLayout found in Inventory.Inv")
					return
				end

				if not gridLayout:GetAttribute("DefaultCellSize") then
					gridLayout:SetAttribute("DefaultCellSize", gridLayout.CellSize)
				end

				local baseCell = gridLayout:GetAttribute("DefaultCellSize")

				if isGridSmall then
					local newSize = UDim2.new(
						baseCell.X.Scale * 0.6, baseCell.X.Offset * 0.6,
						baseCell.Y.Scale * 0.6, baseCell.Y.Offset * 0.6
					)
					gridLayout.CellSize = newSize
				else
					gridLayout.CellSize = baseCell
				end
			end)

			Connections["LockButton"] = LockButton.MouseButton1Down:Connect(function()
				if not SelectedItem then return end
				MainUI.PlaySound(15675059323, 0.4)

				local itemName = SelectedItem.Name
				local newState = not (LockedItems[itemName] or false)
				LockedItems[itemName] = newState

				local lockLabel = SelectedItem:FindFirstChild("LockLabel")
				if lockLabel then
					lockLabel.Visible = newState
				end
				SelectedItem.LayoutOrder = newState and -1 or 0

				print(string.format("[Inventory] %s now %s", itemName, newState and "LOCKED" or "UNLOCKED"))
				print("[Inventory] Updated LockedItems:")
				print(LockedItems)
			end)
			
			Connections["Handle"] = game.ReplicatedStorage.Events.RemoteEvents.UIHandlers.MainUIRefresh.OnClientEvent:Connect(function()
				Yield = false
				EmptyInv()
				CreateFormat(Current)
			end)
			
		end,
		["Sell"] = function()
			local SellUI = Player.PlayerGui.Main.Pages.Sell
			local Yield = false
			local function EmptyInv()
				for _, Buttons in pairs(SellUI.Inv:GetChildren()) do
					if Buttons and Buttons:IsA("TextButton") then
						Buttons:Destroy()
					end
				end
			end
			Connections["Close"] = SellUI.Close.MouseButton1Down:Connect(function()
				BaseSettings.CleanTable(Connections)
				Connections = {}
				MainUI.CloseFrames(Player.PlayerGui.Main)
				EmptyInv()
			end)
			local Current = "Crops"
			local Selected = {}
			local function CreateFormat(myType : string)
				if Yield then return end
				Yield  = true	
				task.delay(1,function()
					Yield  = false
				end)
				local DataTypes = {
					["Crops"] = {"Crops","Seeds"},
					["Items"] = {"Items"},
					["Pets"] = {"Pets","Eggs"},
				}
				local GetDataType = DataTypes[myType]
				if not GetDataType then
					EmptyInv()
					CreateFormat("Crops")
				else
					warn("GOT DATA TYPE CREATING!")
					local function CreateTemplate(TemplateName : string , TemplateAmount : number,DataType : string,Data)
						local RealNameCast,Key
						if string.find(TemplateName,"|") then
							RealNameCast, Key =	string.split(TemplateName,"|")[1],string.split(TemplateName,"|")[2]
						end
						if not RealNameCast then RealNameCast = TemplateName end

						if SellUI.Inv:FindFirstChild(TemplateName) then
							local GetFrame = SellUI.Inv:FindFirstChild(TemplateName)
							local GetAmount = GetFrame:GetAttribute("Amount")
							GetFrame.Text = TemplateName.." | "..GetAmount+TemplateAmount.."x"
							return
						end
						local Template = SellUI.Template:Clone()
						Template.Name = TemplateName

						Template:SetAttribute("Amount",TemplateAmount)
						Template:SetAttribute("Type",DataType)
						local xAmount = if TemplateAmount > 1 then TemplateAmount.."x" else "1x"
						Template.TextLabel.Text = RealNameCast.." | "..xAmount
						Template.Parent = SellUI.Inv
						Template.Visible = true
						if DataType == "Seeds" then
							local RealName = string.split(TemplateName,"] ")[2]
							print(RealName)
							local GetReplicated = game.ReplicatedStorage.Assets.Seeds:FindFirstChild(RealName)
							if GetReplicated then
								local Replicate = GetReplicated.Handle:Clone()
								Replicate.CFrame = CFrame.new(0,0,0)
								Replicate.Anchored = true
								Replicate.Parent = Template.ViewportFrame
								local CreateCamera = Instance.new("Camera")
								CreateCamera.CFrame = CFrame.new(Vector3.new(0,-0.05,2))
								Template.ViewportFrame.CurrentCamera = CreateCamera
								local function CreateSpin()
									Connections[TemplateName..TemplateAmount..DataType.."Spin"] = game:GetService("RunService").PreRender:Connect(function(dt)
										local Part = Replicate
										local Speed = math.rad(50)
										Part.CFrame = Part.CFrame * CFrame.Angles(0, Speed * dt, 0)
									end)
								end
								CreateSpin()
							end
						elseif DataType == "Crops" then		
							local RealName = string.split(RealNameCast,"] ")[2]
							local GetReplicated = game.ReplicatedStorage.Assets.Planters:FindFirstChild(RealName)
							if GetReplicated then
								local Replicate = GetReplicated:Clone()
								Replicate:PivotTo(CFrame.new(0,0,0))
								Replicate.Parent = Template.ViewportFrame

								local cf, size = Replicate:GetBoundingBox()
								local longest = math.max(size.X, size.Y, size.Z)
								local dist = longest * 1.8
								local focus = cf.Position + Vector3.new(0, size.Y * 0.15, 0)

								local CreateCamera = Instance.new("Camera")
								CreateCamera.CFrame = CFrame.new(focus + Vector3.new(0, 0, dist), focus)
								CreateCamera.Parent = Template.ViewportFrame
								Template.ViewportFrame.CurrentCamera = CreateCamera
								local function CreateSpin()
									Connections[TemplateName..TemplateAmount..DataType.."Spin"] = game:GetService("RunService").PreRender:Connect(function(dt)
										local speed = math.rad(50)
										local pivot = Replicate:GetPivot()
										Replicate:PivotTo(pivot * CFrame.Angles(0, speed * dt, 0))
									end)
								end
								CreateSpin()
							end
						elseif DataType == "Pets" then

							local GetReplicated = game.ReplicatedStorage.Assets.PetRepStorage:FindFirstChild(RealNameCast)
							if GetReplicated then
								local Replicate = GetReplicated:Clone()
								Replicate:PivotTo(CFrame.new(0,0,0) * CFrame.Angles(math.rad(-90),math.rad(-180),math.rad(0)))
								Replicate.Parent = Template.ViewportFrame

								local cf, size = Replicate:GetBoundingBox()
								local longest = math.max(size.X, size.Y, size.Z)
								local dist = longest * 1.8
								local focus = cf.Position + Vector3.new(0, size.Y * 0.15, 0)

								local CreateCamera = Instance.new("Camera")
								CreateCamera.CFrame = CFrame.new(focus + Vector3.new(0, 0, dist), focus)
								CreateCamera.Parent = Template.ViewportFrame
								Template.ViewportFrame.CurrentCamera = CreateCamera
								local function CreateSpin()
									Connections[TemplateName..TemplateAmount..DataType.."Spin"] = game:GetService("RunService").PreRender:Connect(function(dt)
										local speed = math.rad(50)
										local pivot = Replicate:GetPivot()
										Replicate:PivotTo(pivot * CFrame.Angles(0, speed * dt, 0))
									end)
								end
								CreateSpin()
							end
						end
						Connections[TemplateName..TemplateAmount..DataType] = Template.MouseButton1Down:Connect(function()
							MainUI.PlaySound(15675059323,.4)
							if not table.find(Selected,TemplateName) then
								table.insert(Selected,TemplateName)
								Template.UIStroke.Color = Color3.fromRGB(0,255,0)
								Template.UIStroke.Thickness = 1
							else
								table.remove(Selected,table.find(Selected,TemplateName))
								Template.UIStroke.Color = Color3.fromRGB(156, 94, 55)
								Template.UIStroke.Thickness = 4

							end
						end)
						Connections[TemplateName..TemplateAmount..DataType.."Hover"] = Template.MouseEnter:Connect(function()
							MainUI.PlaySound(542332175,.5)
							if DataType == "Crops" then
								local Information = Player.PlayerGui.Main.Pages.Information
								Information.Visible = true
								for dataName,dataValue in pairs(Data) do
									if dataValue then
										if Information.Frame:FindFirstChild(dataName) then
											local myText = Information.Frame:FindFirstChild(dataName)
											if dataName ~= "Buffs" then
												myText.Text = myText.Name..": "..dataValue
											else
												myText.Text = "Mutations: "..table.concat(dataValue,",")
											end
										end
									end
								end
							end
						end)
						Connections[TemplateName..TemplateAmount..DataType.."Exit"] = Template.MouseLeave:Connect(function()
							local Information = Player.PlayerGui.Main.Pages.Information
							Information.Visible = false

						end)
					end
					local GetInventoryInformation = GetInvoke:InvokeServer("Data",GetDataType)
					if GetInventoryInformation then
						for TypeData, DataTable in pairs(GetInventoryInformation) do
							if DataTable and TypeData == "Crops" then
								for DataName , DataValue in pairs(DataTable) do
									if DataValue then
										CreateTemplate(DataName,DataValue.Quantity,TypeData,DataValue)
									end
								end
							end
						end
					end
				end
			end
			EmptyInv()
			CreateFormat("Crops")
			for _, Button in pairs(SellUI.Buttons:GetChildren()) do
				if Button and Button:IsA("TextButton") then
					Connections[Button] = Button.MouseButton1Down:Connect(function()
						if Yield then return end
						MainUI.PlaySound(15675059323,.4)
						if Button.Name == "Selected" then
							game.ReplicatedStorage.Events.RemoteEvents.BaseCast:FireServer("SellCrops",Selected)
						else
							game.ReplicatedStorage.Events.RemoteEvents.BaseCast:FireServer("SellCrops")
						end
					end)
				end
			end
			Connections["Handle"] = game.ReplicatedStorage.Events.RemoteEvents.UIHandlers.MainUIRefresh.OnClientEvent:Connect(function()
				Yield = false
				EmptyInv()
				CreateFormat(Current)
			end)
		end,
		["Settings"] = function()
			local SettingsUI = Player.PlayerGui.Main.Pages.Settings

			Connections["Close"] = SettingsUI.Close.MouseButton1Down:Connect(function()
				MainUI.PlaySound(15675059323, 0.4)
				BaseSettings.CleanTable(Connections)
				Connections = {}
				MainUI.CloseFrames(Player.PlayerGui.Main)
			end)
			local AudioButton = SettingsUI.Scroll.Audio:FindFirstChild("Button")
			if AudioButton then
				Connections["AudioButton"] = AudioButton.MouseButton1Down:Connect(function()
					MainUI.PlaySound(15675059323, 0.4)
				end)
			end
			local VFXButton = SettingsUI.Scroll.VFX:FindFirstChild("Button")
			if VFXButton then
				Connections["VFXButton"] = VFXButton.MouseButton1Down:Connect(function()
					MainUI.PlaySound(15675059323, 0.4)
				end)
			end
		end,
		["UpdateLog"] = function()
			local UpdateLog = Player.PlayerGui.Main.Pages.UpdateLog

			Connections["Close"] = UpdateLog.Close.MouseButton1Down:Connect(function()
				local News = UpdateLog:WaitForChild("Release")
				for _, child in ipairs(News:GetChildren()) do
					if child:IsA("TextLabel") then
						child.Visible = false
					end
				end
				MainUI.PlaySound(15675059323, 0.4)
				BaseSettings.CleanTable(Connections)
				Connections = {}
				MainUI.CloseFrames(Player.PlayerGui.Main)
			end)
			local ReleaseButton = UpdateLog.Scroll.Release:FindFirstChild("Button")
			if ReleaseButton then
				Connections["ReleaseButton"] = ReleaseButton.MouseButton1Down:Connect(function()
					MainUI.PlaySound(15675059323, 0.4)
				end)
			end
		end,
		["Cosmetics"] = function()
			local Players = game:GetService("Players")
			local Player = Players.LocalPlayer
			local ReplicatedStorage = game:GetService("ReplicatedStorage")
			local Viewport = Player.PlayerGui.Main.Pages.Cosmetics:WaitForChild("ViewportFrame")
			local rotationY = 0
			local rotating = false
			local lastMouseX = 0
			local UserInputService = game:GetService("UserInputService")


			local function ViewportCleanUp()
				for _, obj in ipairs(Viewport:GetChildren()) do
					if obj:IsA("Model") or obj:IsA("Camera") then
						obj:Destroy()
					end
				end
			end

			local function CreateViewportCharacter()
				ViewportCleanUp()

				local character = Player.Character or Player.CharacterAdded:Wait()

				local clone = Instance.new("Model")
				clone.Name = "ViewportCharacter"
				clone.Parent = Viewport

				
				for _, child in ipairs(character:GetChildren()) do
					local ok, childClone = pcall(function() return child:Clone() end)
					if ok and childClone then
						childClone.Parent = clone
					end
				end

				
				for _, desc in ipairs(clone:GetDescendants()) do
					if desc:IsA("Script") or desc:IsA("LocalScript") then
						desc:Destroy()
					end
				end

				
				for _, part in ipairs(clone:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Anchored = true
					end
				end

				
				clone.PrimaryPart = clone:FindFirstChild("HumanoidRootPart") or clone:FindFirstChild("Torso")
				clone:SetPrimaryPartCFrame(CFrame.new(Vector3.new(0,20,0)) * CFrame.Angles(0, math.rad(180), 0))

				local cam = Instance.new("Camera")
				cam.Parent = Viewport
				Viewport.CurrentCamera = cam

				local cf, size = clone:GetBoundingBox()
				local largest = math.max(size.X, size.Y, size.Z)
				local distance = largest * 1.5
				local modelOffset = Vector3.new(0,-3,0)
				local focus = cf.Position + Vector3.new(0, size.Y * 0.25, 0) + modelOffset
				cam.CFrame = CFrame.new(focus + Vector3.new(0, 0, distance), focus)

				return clone
			end

			local ViewportCharacter = CreateViewportCharacter()
			
			Viewport.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					rotating = true
					lastMouseX = input.Position.X
				end
			end)

			Viewport.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					rotating = false
				end
			end)

			Viewport.InputChanged:Connect(function(input)
				if rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
					local deltaX = input.Position.X - lastMouseX
					lastMouseX = input.Position.X

					local rotationSpeed = 0.01

					rotationY = rotationY + deltaX * rotationSpeed

					if ViewportCharacter and ViewportCharacter.PrimaryPart then
						local rootCFrame = ViewportCharacter.PrimaryPart.CFrame
						local pos = rootCFrame.Position
						ViewportCharacter:PivotTo(CFrame.new(pos) * CFrame.Angles(0, rotationY, 0))
					end
				end
			end)

			local GetInvoke = ReplicatedStorage.Events.RemoteFunctions.Retrieve
			local success, CosmeticData = pcall(function()
				return GetInvoke:InvokeServer("Data", {"Cosmetics"})
			end)

			if not success or not CosmeticData then
				warn("[Cosmetics] Failed to retrieve data.")
				CosmeticData = { Cosmetics = {} }
			end

			local CosmeticsFolder = ReplicatedStorage.Assets.Cosmetics
			local Inv = Player.PlayerGui.Main.Pages.Cosmetics:WaitForChild("Inv")
			local buttons = {}

			for _, obj in ipairs(Inv:GetChildren()) do
				if obj:IsA("TextButton") then
					table.insert(buttons, obj)
				end
			end

			local function UpdateEquippedButtons(cosmeticData)
				local ButtonFrame = Player.PlayerGui.Main.Pages.Cosmetics:WaitForChild("ButtonFrame")
				local buttonMap = {
					Head = ButtonFrame:WaitForChild("Head"),
					Torso = ButtonFrame:WaitForChild("Torso"),
					Legs = ButtonFrame:WaitForChild("Legs"),
				}

				print("[UpdateEquippedButtons] called")
				print("[UpdateEquippedButtons] buttonMap:", "Head=", tostring(buttonMap.Head),
					"Torso=", tostring(buttonMap.Torso), "Legs=", tostring(buttonMap.Legs))

				for typeName, button in pairs(buttonMap) do
					print(("[UpdateEquippedButtons] clearing button %s"):format(typeName))
					button.Text = typeName .. ": None"
					for _, child in ipairs(button:GetChildren()) do
						if child:IsA("ViewportFrame") then
							child:Destroy()
						end
					end
				end

				if not cosmeticData or type(cosmeticData) ~= "table" then
					print("[UpdateEquippedButtons] cosmeticData is nil or not a table:", cosmeticData)
					return
				end

				local cosmetics = cosmeticData.Cosmetics or {}

				for cosmeticName, data in pairs(cosmetics) do
					if type(data) == "table" then
						local isEquipped = data.Equipped
						local cType = data.Type

						if isEquipped and cType and buttonMap[cType] then
							local button = buttonMap[cType]
							button.Text = cType .. ": " .. cosmeticName

							local cosmeticModel = CosmeticsFolder:FindFirstChild(cosmeticName)
							if cosmeticModel then
								local viewport = Instance.new("ViewportFrame")
								viewport.Name = "EquippedViewport"
								viewport.Size = UDim2.new(1, 0, 1, 0)
								viewport.BackgroundTransparency = 1
								viewport.BorderSizePixel = 0
								viewport.Parent = button

								local clone = cosmeticModel:Clone()
								clone.Parent = viewport

								local cam = Instance.new("Camera")
								cam.Parent = viewport
								viewport.CurrentCamera = cam

								local cf, size = clone:GetBoundingBox()
								local dist = math.max(size.X, size.Y, size.Z) * 1.5
								local focus = cf.Position
								cam.CFrame = CFrame.new(focus + Vector3.new(0, 0, dist), focus)
							else
								warn("[UpdateEquippedButtons] Missing cosmetic model:", cosmeticName)
							end
						end
					end
				end
			end
			
			local index = 1
			for cosmeticName, cosmeticInfo in pairs(CosmeticData.Cosmetics) do
				local button = buttons[index]
				if not button then break end
				index += 1

				local oldViewport = button:FindFirstChild("ItemViewport")
				if oldViewport then oldViewport:Destroy() end

				local viewport = Instance.new("ViewportFrame")
				viewport.Name = "ItemViewport"
				viewport.Size = UDim2.new(1, 0, 1, 0)
				viewport.BackgroundTransparency = 1
				viewport.BorderSizePixel = 0
				viewport.Parent = button

				local cosmeticModel = CosmeticsFolder:FindFirstChild(cosmeticName)
				if cosmeticModel then
					local cloneModel = cosmeticModel:Clone()
					cloneModel.Parent = viewport

					local cam = Instance.new("Camera")
					cam.Parent = viewport
					viewport.CurrentCamera = cam

					local cf, size = cloneModel:GetBoundingBox()
					local dist = math.max(size.X, size.Y, size.Z) * 1
					cam.CFrame = CFrame.new(cf.Position + Vector3.new(0, 0, dist), cf.Position)
				end

				button.MouseButton1Down:Connect(function()
					MainUI.PlaySound(15675059323, 0.4)
					pcall(function()
						local result = ReplicatedStorage.Events.RemoteFunctions.EquipCosmetic:InvokeServer(cosmeticName)

						task.delay(0.2, function()
							ViewportCharacter = CreateViewportCharacter()
						end)

						task.delay(0.3, function()
							local ok, newData = pcall(function()
								return GetInvoke:InvokeServer("Data", {"Cosmetics"})
							end)
							if ok and newData then
								UpdateEquippedButtons(newData)
							else
								warn("[Cosmetics] Failed to refresh equipped buttons after equip")
							end
						end)
					end)
				end)
			end

			UpdateEquippedButtons(CosmeticData)

			local closeButton = Player.PlayerGui.Main.Pages.Cosmetics:WaitForChild("Close")
			Connections["Close"] = closeButton.MouseButton1Down:Connect(function()
				MainUI.PlaySound(15675059323, 0.4)
				BaseSettings.CleanTable(Connections)
				Connections = {}
				MainUI.CloseFrames(Player.PlayerGui.Main)
				ViewportCleanUp()
			end)
		end
	}
	if Types[Type] then
		MainUI.PlaySound(18926058970,.7)
		Types[Type]()
	end
end

return MainUI