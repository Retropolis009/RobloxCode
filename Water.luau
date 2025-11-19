local AnimalRemoved = game:GetService("ReplicatedStorage").Events.BindableEvents.AnimalRemoved

local WaterTraversal = {}

-- SETTINGS
local Settings = {
	servertick = 0.025,
	swimspeed = 8,
	stucktimeout = 1,
	waypointthreshold = 5,
	repathmin = 6,
	repathmax = 12,
	maxstuckcount = 5,
	sendinterval = 0.05,
	lastsend = 0,
	idlechance = 0.4,
	postidleduration = 3,
	idlerepathmin = 2,
	idlerepathmax = 5,
	surfaceoffset = 0.5,
	underwateroffset = -4,
	depthvariance = 3,
	bobamount = 0.05,
}


-- STATE TRACKING
local npcStates = {}
local activeTargets = {}
local NPCFolder
local WaterArea

-- Helpers
local function getWaterTopY()
	if not WaterArea then return 0 end
	return WaterArea.Position.Y + (WaterArea.Size.Y / 2)
end

local function getWaterBottomY()
	if not WaterArea then return 0 end
	return WaterArea.Position.Y - (WaterArea.Size.Y / 2)
end

local function getAreaMinMax()
	if not WaterArea then
		return Vector3.new(), Vector3.new()
	end
	local half = WaterArea.Size * 0.5
	local min = WaterArea.Position - half
	local max = WaterArea.Position + half
	return min, max
end

local function randFloat(a, b)
	return a + math.random() * (b - a)
end

--Waypoints
local function getRandomWaterPoint(lastTarget, npc)
	if not WaterArea then return Vector3.new(0,0,0) end

	local min, max = getAreaMinMax()
	local topY = getWaterTopY()
	local bottomY = getWaterBottomY()

	local minDistFromLast = 15
	local minDistFromOthers = 10
	local maxAttempts = 20
	local point
	local subtype = "Surface"
	if npc and npc.GetAttribute then
		subtype = npc:GetAttribute("Subtype") or "Surface"
	end

	for attempt = 1, maxAttempts do
		local x = randFloat(min.X, max.X)
		local z = randFloat(min.Z, max.Z)
		local y

		if subtype == "Surface" then
			y = topY - Settings.surfaceoffset
		else
			local rawY = topY + Settings.underwateroffset + randFloat(-Settings.depthvariance, Settings.depthvariance)
			y = math.clamp(rawY, bottomY + 0.5, topY - 0.5)
		end

		point = Vector3.new(x, y, z)

		local ok = (not lastTarget) or ((point - lastTarget).Magnitude > minDistFromLast)
		if ok then
			for otherNpc, target in pairs(activeTargets) do
				if otherNpc ~= npc and target and (point - target).Magnitude < minDistFromOthers then
					ok = false
					break
				end
			end
		end

		if ok then
			activeTargets[npc] = point
			return point
		end
	end

	activeTargets[npc] = point
	return point
end

local function getOppositeRepath(npc, root)
	local min, max = getAreaMinMax()
	local cur = root.Position
	local center = (min + max) * 0.5
	local away = (center - cur).Unit * -1
	local radius = math.min((max.X-min.X), (max.Z-min.Z)) * 0.4
	local target = center + away * radius
	target = Vector3.new(
		math.clamp(target.X, min.X+2, max.X-2),
		cur.Y,
		math.clamp(target.Z, min.Z+2, max.Z-2)
	)
	return target
end

-- Initializer
local function initNpcState(npc)
	if not npc or not npc:IsA("Model") then return end
	if not (npc.GetAttribute and npc:GetAttribute("Type") == "Water") then return end

	local root = npc:FindFirstChild("HumanoidRootPart")
	local humanoid = npc:FindFirstChild("Humanoid")
	if not root or not humanoid then return end

	local subtype = npc:GetAttribute("Subtype") or "Surface"

	local surfaceY
	if subtype == "Surface" then
		surfaceY = getWaterTopY() - Settings.surfaceoffset
	end

	local targetDepth = nil
	if subtype == "Underwater" then
		local topY = getWaterTopY()
		local bottomY = getWaterBottomY()
		targetDepth = math.clamp(topY + Settings.underwateroffset + randFloat(- Settings.depthvariance, Settings.depthvariance),
			bottomY + 0.5, topY - 0.5)

		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	local curPos = root.Position
	local look = root.CFrame.LookVector
	local placeY = subtype == "Surface" and surfaceY or (targetDepth or curPos.Y)
	local forward = Vector3.new(curPos.X + look.X, placeY, curPos.Z + look.Z)
	root.CFrame = CFrame.new(Vector3.new(curPos.X, placeY, curPos.Z), forward)

	npcStates[npc] = {
		Root = root,
		Humanoid = humanoid,
		Subtype = subtype,
		TargetDepth = targetDepth,
		SurfaceY = surfaceY,
		LastTarget = nil,
		CurrentTarget = nil,
		ReachedTarget = true,
		LastPos = root.Position,
		LastMoveTime = os.clock(),
		LastRepath = os.clock(),
		NextRepath = math.random(Settings.repathmin, Settings.repathmax),
		StuckCount = 0,
		IsIdling = false,
		IdleUntil = 0,
		StuckCooldown = 0,
		HasIdledAfterPath = false,
		CanIdle = true,
		UpdateSlot = math.random(1,5)
	}

	if subtype == "Underwater" then
		if not root:FindFirstChild("WaterBV") then
			local bv = Instance.new("BodyVelocity")
			bv.Name = "WaterBV"
			bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
			bv.P = 1e4
			bv.Velocity = Vector3.new(0,0,0)
			bv.Parent = root
		end
		local density = npc:GetAttribute("Density")
		if density then
			local grav = Instance.new("BodyForce")
			grav.Name = "WaterDensityForce"
			grav.Force = Vector3.new(0, -workspace.Gravity * density, 0)
			grav.Parent = root
		end
	end

	npc:SetAttribute("State", "Idle")
end

--Helpers
local function updateNpcAttributes(npc, isMoving)
	if not npc or not npc.GetAttribute then return end
	local currentState = npc:GetAttribute("State")
	if isMoving and currentState ~= "Swimming" then
		npc:SetAttribute("State", "Swimming")
	elseif (not isMoving) and currentState ~= "Idle" then
		npc:SetAttribute("State", "Idle")
	end
end

local function startIdle(state, duration)
	if not state or not state.Root then return end
	state.IsIdling = true
	state.IdleUntil = os.clock() + duration
	state.CanIdle = false
	updateNpcAttributes(state.Root.Parent, false)
end

--Movement Logic 
local frameCounter = 0
local function updateNPCs()
	if not WaterArea then return end
	frameCounter += 1

	local min, max = getAreaMinMax()
	local now = os.clock()

	for npc, state in pairs(npcStates) do
		if not npc or not npc.Parent or not state.Root or not state.Humanoid or state.Humanoid.Health <= 0 then
			npcStates[npc] = nil
			activeTargets[npc] = nil
		else
			if frameCounter % state.UpdateSlot ~= 0 then continue end

			local root = state.Root
			local pos = root.Position
			local isMoving = false

			local outsideXZ = (pos.X < min.X+1) or (pos.X > max.X-1) or (pos.Z < min.Z+1) or (pos.Z > max.Z-1)
			if state.Subtype == "Surface" and outsideXZ then
				state.CurrentTarget = getOppositeRepath(npc, root)
				state.LastTarget = state.CurrentTarget
				state.ReachedTarget = false
				state.HasIdledAfterPath = false
				state.LastRepath = now
				state.NextRepath = math.random(Settings.repathmin, Settings.repathmax)
			end

			if state.IsIdling and now < state.IdleUntil then
				updateNpcAttributes(npc, false)
				continue
			elseif state.IsIdling then
				state.IsIdling = false
			end

			if state.ReachedTarget or (now - state.LastRepath > state.NextRepath) then
				state.CurrentTarget = getRandomWaterPoint(state.LastTarget, npc)
				state.LastTarget = state.CurrentTarget
				state.ReachedTarget = false
				state.LastRepath = now
				state.NextRepath = math.random(Settings.repathmin, Settings.repathmax)
			end

			if state.CurrentTarget and not state.ReachedTarget then
				local dir = state.CurrentTarget - root.Position
				if dir.Magnitude < 0.1 then
					state.ReachedTarget = true
					dir = Vector3.new()
				end

				local flatDir = Vector3.new(dir.X, 0, dir.Z)
				local distance = flatDir.Magnitude

				if distance > Settings.waypointthreshold then
					isMoving = true
					local moveVec = dir.Magnitude > 0.001 and dir.Unit * Settings.swimspeed or Vector3.new()

					local bg = root:FindFirstChild("WaterBG")
					if not bg then
						bg = Instance.new("BodyGyro")
						bg.Name = "WaterBG"
						bg.MaxTorque = Vector3.new(1e5,1e5,1e5)
						bg.P = 5000
						bg.D = 100
						bg.CFrame = root.CFrame
						bg.Parent = root
					end

					-- Surface vs Underwater
					if state.Subtype == "Surface" then
						local bv = root:FindFirstChild("SurfaceBV")
						if not bv then
							bv = Instance.new("BodyVelocity")
							bv.Name = "SurfaceBV"
							bv.MaxForce = Vector3.new(1e5,1e5,1e5)
							bv.P = 1e4
							bv.Parent = root
						end

						local flatVelocity = Vector3.new(moveVec.X, 0, moveVec.Z)
						bv.Velocity = bv.Velocity:Lerp(flatVelocity, 0.15)

						if flatDir.Magnitude > 0.01 then
							bg.CFrame = CFrame.new(root.Position, root.Position + flatDir)
						end

						local bob = math.sin(os.clock() * math.random(1,3)) * Settings.bobamount
						local targetY = state.SurfaceY + bob
						local newY = root.Position.Y + (targetY - root.Position.Y) * 0.1
						local newPos = Vector3.new(pos.X, newY, pos.Z)
						root.CFrame = CFrame.new(newPos, root.Position + flatDir)
					else
						local bv = root:FindFirstChild("WaterBV")
						if bv then
							bv.Velocity = bv.Velocity:Lerp(moveVec, 0.15)
						end
						if dir.Magnitude > 0.01 then
							bg.CFrame = CFrame.new(root.Position, root.Position + dir)
						end
					end
				else
					state.ReachedTarget = true
					local bv = root:FindFirstChild("WaterBV") or root:FindFirstChild("SurfaceBV")
					if bv then
						bv.Velocity = bv.Velocity:Lerp(Vector3.new(), 0.3)
					end
				end
			end

			if state.ReachedTarget and state.CanIdle and not state.IsIdling then
				if math.random() < Settings.idlechance then
					startIdle(state, Settings.postidleduration)
				end
			end

			updateNpcAttributes(npc, isMoving)
		end
	end
end

-- API
function WaterTraversal.Init(petsFolder, waterBlock)
	NPCFolder = petsFolder
	WaterArea = waterBlock

	for _, npc in ipairs(NPCFolder:GetChildren()) do
		initNpcState(npc)
	end

	NPCFolder.ChildAdded:Connect(function(npc)
		task.wait(0.1)
		initNpcState(npc)
	end)

	NPCFolder.ChildRemoved:Connect(function(npc)
		npcStates[npc] = nil
		activeTargets[npc] = nil
		AnimalRemoved:Fire(npc)
	end)
end

function WaterTraversal.Step(dt)
	updateNPCs()
end

return WaterTraversal