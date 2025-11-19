local LandTraversal = require(script:WaitForChild("LandPathFinder"))
local WaterTraversal = require(script:WaitForChild("WaterPathFinder"))
local AirTraversal = require(script:WaitForChild("AerialPathFinder"))
local AnimalSpawner = require(script:WaitForChild("AnimalSpawner"))
local PetFollower = require(game.ServerStorage.Modules.Base.PetFollowHandler)
-- Init traversals
local petsFolder = workspace:WaitForChild("Pets")
local area = workspace:WaitForChild("Area")
local waterBlock = workspace:WaitForChild("WaterBlock")
local air = workspace:WaitForChild("Air")

LandTraversal.Init(petsFolder, area)
WaterTraversal.Init(petsFolder, waterBlock)
AirTraversal.Init(petsFolder,air)
-- Tick rates per traversal
local FOLLOWER_TICK = 0.033
local LAND_TICK = 0.05
local WATER_TICK = 0.025
local AIR_TICK = 0.033

-- Track last update times
local lastFollower, lastLand, lastWater, lastAir = 0, 0, 0, 0

task.spawn(function()
	while true do
		local now = os.clock()

		-- Pet Follower
		if now - lastFollower >= FOLLOWER_TICK then
			PetFollower.Step(FOLLOWER_TICK)
			lastFollower = now
		end

		-- Land pets
		if now - lastLand >= LAND_TICK then
			LandTraversal.Step(LAND_TICK)
			lastLand = now
		end

		-- Water pets
		if now - lastWater >= WATER_TICK then
			WaterTraversal.Step(WATER_TICK)
			lastWater = now
		end

		-- Air pets
		if now - lastAir >= AIR_TICK then
			AirTraversal.Step(AIR_TICK)
			lastAir = now
		end

		task.wait(0.01) 
	end
end)

-- Start spawner
AnimalSpawner.Init()