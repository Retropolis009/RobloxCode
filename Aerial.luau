-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimalRemoved = ReplicatedStorage.Events.BindableEvents.AnimalRemoved

local AirTraversal = {}

-- Settings
local SETTINGS = {
	servertick = 0.05,
	flyspeed = 12,
	waypointthreshold = 5,
	repathmin = 4,
	repathmax = 8,
	idlechance = 0.3,
	postidleduration = 2,
	hoveramplitude = 2,
	hoverspeed = 3,
	randomoscscale = 0.5
}

-- States
local npcStates = {}
local activeTargets = {}
local NPCFolder
local AirArea
local startTime = os.clock()
local seedCounter = 0

-- Utility
local function getRandomPoint(lastTarget, npc)
	local areaPos, areaSize = AirArea.Position, AirArea.Size
	local minDistFromLast = 15
	local minDistFromOthers = 10
	local maxAttempts = 15
	local point

	for _ = 1, maxAttempts do
		local x = areaPos.X + math.random(-areaSize.X/2, areaSize.X/2)
		local y = areaPos.Y + math.random(-areaSize.Y/2, areaSize.Y/2)
		local z = areaPos.Z + math.random(-areaSize.Z/2, areaSize.Z/2)
		point = Vector3.new(x, y, z)

		local ok = not lastTarget or (point - lastTarget).Magnitude > minDistFromLast
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

-- Initialize pet state
local function initializeNpcState(npc)
	if not npc or npc:GetAttribute("Type") ~= "Air" then return end
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- Ensure BodyVelocity and BodyGyro exist
	local bv = root:FindFirstChild("AirBV") or Instance.new("BodyVelocity")
	bv.Name = "AirBV"
	bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bv.P = 1e4
	bv.Velocity = Vector3.zero
	bv.Parent = root

	local bg = root:FindFirstChild("AirBG") or Instance.new("BodyGyro")
	bg.Name = "AirBG"
	bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bg.P = 1e4
	bg.CFrame = root.CFrame
	bg.Parent = root

	seedCounter += 1
	local seed = (seedCounter * 997) % 1000

	npcStates[npc] = {
		Root = root,
		LastTarget = nil,
		CurrentTarget = nil,
		ReachedTarget = true,
		LastRepath = os.clock(),
		NextRepath = math.random(SETTINGS.repathmin, SETTINGS.repathmax),
		IsIdling = false,
		IdleUntil = 0,
		CanIdle = true,
		UpdateSlot = math.random(1,5),
		IdleBaseY = root.Position.Y,
		LastFacingDir = Vector3.new(0,0,1),
		Seed = seed
	}

	npc:SetAttribute("State", "Idle")
end

-- Helper for Idle
local function getOscillation(t, seed, amplitude)
	local noise = math.noise(t * 0.7, seed * 0.13)
	local sine = math.sin(t * SETTINGS.hoverspeed + seed) * 0.5
	return (sine + noise * SETTINGS.randomoscscale) * amplitude
end

-- Update pets per frame
local function updatePets()
	local now = os.clock()
	local elapsed = now - startTime

	for npc, state in pairs(npcStates) do
		if not npc.Parent then
			npcStates[npc] = nil
			activeTargets[npc] = nil
		elseif state.UpdateSlot and (math.random(1, state.UpdateSlot) ~= 1) then
			continue
		else
			local root, bv, bg = state.Root, state.Root:FindFirstChild("AirBV"), state.Root:FindFirstChild("AirBG")
			if not bv or not bg then
				initializeNpcState(npc)
				continue
			end

			-- Idling
			if state.IsIdling and now < state.IdleUntil then
				bv.Velocity = Vector3.new(0, getOscillation(elapsed, state.Seed, SETTINGS.hoveramplitude), 0)
				bg.CFrame = CFrame.lookAt(root.Position, root.Position + (state.LastFacingDir or Vector3.new(0,0,1)))
				npc:SetAttribute("State", "Idle")
				continue
			elseif state.IsIdling then
				state.IsIdling = false
				state.CanIdle = true
			end

			-- Repath 
			if state.ReachedTarget or (now - state.LastRepath > state.NextRepath) then
				state.CurrentTarget = getRandomPoint(state.LastTarget, npc)
				state.LastTarget = state.CurrentTarget
				state.ReachedTarget = false
				state.LastRepath = now
				state.NextRepath = math.random(SETTINGS.repathmin, SETTINGS.repathmax)
			end

			-- Movement
			local isMoving = false
			if state.CurrentTarget and not state.ReachedTarget then
				local dir = state.CurrentTarget - root.Position
				local distance = dir.Magnitude
				if distance > SETTINGS.waypointthreshold then
					isMoving = true
					local desiredVelocity = dir.Unit * SETTINGS.flyspeed
					desiredVelocity += Vector3.new(0, getOscillation(elapsed, state.Seed, SETTINGS.hoveramplitude * 0.4), 0)
					bv.Velocity = bv.Velocity:Lerp(desiredVelocity, 0.2)

					state.LastFacingDir = dir.Unit
					bg.CFrame = CFrame.lookAt(root.Position, root.Position + dir.Unit)
				else
					state.ReachedTarget = true
					bv.Velocity = bv.Velocity:Lerp(Vector3.zero, 0.2)
				end
			end

			-- Post-target idle
			if state.ReachedTarget and state.CanIdle and not state.IsIdling then
				if math.random() < SETTINGS.idlechance then
					state.IsIdling = true
					state.IdleUntil = now + SETTINGS.postidleduration
					state.IdleBaseY = root.Position.Y
				end
			end

			npc:SetAttribute("State", isMoving and "Flying" or "Idle")
		end
	end
end

-- API
function AirTraversal.Init(petsFolder, airArea)
	NPCFolder = petsFolder
	AirArea = airArea

	for _, npc in ipairs(NPCFolder:GetChildren()) do
		initializeNpcState(npc)
	end

	NPCFolder.ChildAdded:Connect(function(npc)
		task.wait(0.1)
		initializeNpcState(npc)
	end)

	NPCFolder.ChildRemoved:Connect(function(npc)
		npcStates[npc] = nil
		activeTargets[npc] = nil
		AnimalRemoved:Fire(npc)
	end)
end

function AirTraversal.Step(dt)
	updatePets()
end

return AirTraversal