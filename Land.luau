local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimalRemoved = ReplicatedStorage.Events.BindableEvents.AnimalRemoved

local LandTraversal = {}

-- Settings
local SETTINGS = {
	maxspeed = 16,
	stucktimeout = 1,
	waypointthresh = 5,
	repathmin = 6,
	repathmax = 14,
	maxstuckcount = 5,
	idlechance = 0.5,
	postidleduration = 4,
	idlerepathmin = 2,
	idlerepathmax = 6,
	raycastdistance = 2
}

-- State
local npcStates = {}
local activeTargets = {}
local Area, areaSize, areaPos

-- Helpers
local function getRandomPoint(lastTarget, npc)
	local minDistLast, minDistOthers, maxAttempts = 20, 15, 15
	local point
	for _ = 1, maxAttempts do
		local x = areaPos.X + math.random(-areaSize.X/2, areaSize.X/2)
		local z = areaPos.Z + math.random(-areaSize.Z/2, areaSize.Z/2)
		point = Vector3.new(x, areaPos.Y + 2, z)

		local ok = not lastTarget or (point - lastTarget).Magnitude > minDistLast
		if ok then
			for other, target in pairs(activeTargets) do
				if other ~= npc and target and (point - target).Magnitude < minDistOthers then
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

local function raycastForward(npc)
	local root = npc:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {npc}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(root.Position, root.CFrame.LookVector * SETTINGS.raycastdistance, params)
	return result and result.Instance and result.Instance.Name == "Rock"
end

local function startIdle(state, duration)
	local now = os.clock()
	state.IsIdling = true
	state.IdleUntil = now + duration
	state.StuckCooldown = now + duration
	state.CanIdle = false
	state.Root.Parent:SetAttribute("State", "Idle")
end

local function initNpcState(npc)
	if npc:GetAttribute("Type") ~= "Land" then return end
	local root = npc:FindFirstChild("HumanoidRootPart")
	local humanoid = npc:FindFirstChild("Humanoid")
	if not root or not humanoid then return end

	npcStates[npc] = {
		Root = root,
		Humanoid = humanoid,
		LastTarget = nil,
		CurrentTarget = nil,
		CurrentPath = nil,
		CurrentWaypointIndex = 1,
		ReachedTarget = true,
		LastPos = root.Position,
		LastMoveTime = os.clock(),
		LastRepath = os.clock(),
		NextRepath = math.random(SETTINGS.repathmin, SETTINGS.repathmax),
		StuckCount = 0,
		IsIdling = false,
		IdleUntil = 0,
		CanIdle = true,
		UpdateSlot = math.random(1,5)
	}

	humanoid.WalkSpeed = SETTINGS.maxspeed
	startIdle(npcStates[npc], math.random(SETTINGS.idlerepathmin, SETTINGS.idlerepathmax))
	npc:SetAttribute("State", "Idle")
end

local function advanceWaypoint(state)
	local waypoints = state.CurrentPath
	if not waypoints then return nil end

	while state.CurrentWaypointIndex <= #waypoints do
		local wp = waypoints[state.CurrentWaypointIndex]
		if (state.Root.Position - wp.Position).Magnitude < SETTINGS.waypointthresh then
			state.CurrentWaypointIndex += 1
		else
			return wp.Position
		end
	end

	return nil
end


local function updateNpcAttributes(npc, isMoving)
	local stateName = isMoving and "Moving" or "Idle"
	if npc:GetAttribute("State") ~= stateName then
		npc:SetAttribute("State", stateName)
	end
end

-- Step
local frameCounter = 0
function LandTraversal.Step(dt)
	local now = os.clock()
	frameCounter += 1

	for npc, state in pairs(npcStates) do
		if not npc.Parent or state.Humanoid.Health <= 0 then
			npcStates[npc] = nil
			activeTargets[npc] = nil
		elseif frameCounter % state.UpdateSlot ~= 0 then
			continue
		else
			local root = state.Root
			local isMoving = false

			-- Idle handling
			if state.IsIdling then
				if now < state.IdleUntil then
					updateNpcAttributes(npc, false)
					continue
				else
					state.IsIdling = false
					state.CanIdle = true
				end
			end

			-- Movement/stuck check
			local moved = (root.Position - state.LastPos).Magnitude > 0.1
			if moved then
				state.LastPos = root.Position
				state.LastMoveTime = now
				state.StuckCount = 0
			elseif state.CanIdle and now - state.LastMoveTime > SETTINGS.stucktimeout then
				state.StuckCount += 1
				if state.StuckCount >= 5 then
					root.CFrame = root.CFrame * CFrame.new(0,0,5)
					state.StuckCount = 0
					state.LastMoveTime = now
				end
				startIdle(state, math.random(SETTINGS.idlerepathmin, SETTINGS.idlerepathmax))
				state.ReachedTarget = true
				continue
			end

			-- Repath
			if state.ReachedTarget or (now - state.LastRepath > state.NextRepath) or raycastForward(npc) then
				state.CurrentTarget = getRandomPoint(state.LastTarget, npc)
				state.LastTarget = state.CurrentTarget

				local path = PathfindingService:CreatePath({AgentRadius=2, AgentHeight=5, AgentCanJump=false, AgentMaxSlope=45})
				path:ComputeAsync(root.Position, state.CurrentTarget)
				local waypoints = path:GetWaypoints()
				if path.Status == Enum.PathStatus.Success and #waypoints >= 2 then
					state.CurrentPath = waypoints
					state.CurrentWaypointIndex = 1
					state.ReachedTarget = false
				else
					state.CurrentPath = nil
					state.ReachedTarget = true
				end
				state.LastRepath = now
				state.NextRepath = math.random(SETTINGS.repathmin, SETTINGS.repathmax)
			end

			-- Follow path
			if state.CurrentPath and not state.ReachedTarget then
				local nextPos = advanceWaypoint(state)
				if nextPos then
					state.Humanoid:MoveTo(nextPos)
					isMoving = true
				else
					state.ReachedTarget = true
				end
			end

			-- Post-path idle
			if state.ReachedTarget and state.CanIdle then
				if math.random() < SETTINGS.idlechance then
					startIdle(state, SETTINGS.postidleduration)
				end
			end

			updateNpcAttributes(npc, isMoving)
		end
	end
end

-- Init
function LandTraversal.Init(folder, area)
	Area = area
	areaSize = area.Size
	areaPos = area.Position

	for _, npc in ipairs(folder:GetChildren()) do
		initNpcState(npc)
	end

	folder.ChildAdded:Connect(function(npc)
		task.wait(0.1)
		initNpcState(npc)
	end)

	folder.ChildRemoved:Connect(function(npc)
		npcStates[npc] = nil
		activeTargets[npc] = nil
		AnimalRemoved:Fire(npc)
	end)
end

return LandTraversal