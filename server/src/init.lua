local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 4)
	assert(humanoid, "Humanoid for " .. character.Name .. " couldn't be found")
	CollectionService:AddTag(humanoid, "RealismHook")
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

local RealismServer = {}

local stop
function RealismServer.start(config: { LookAnglesSyncRemoteEvent: RemoteEvent })
	if stop then
		return
	end

	local conn1 = Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	local conn2 = config.LookAnglesSyncRemoteEvent.OnServerEvent:Connect(
		function(player, pitch: unknown, yaw: unknown)
			assert(typeof(pitch) == "number" and pitch == pitch, "Invalid pitch")
			assert(typeof(yaw) == "number" and yaw == yaw, "Invalid yaw")
			config.LookAnglesSyncRemoteEvent:FireAllClients(
				player,
				math.clamp(pitch, -1, 1),
				math.clamp(yaw, -1, 1)
			)
		end
	)

	stop = function()
		conn1:Disconnect()
		conn2:Disconnect()
	end
end

function RealismServer.stop()
	if stop then
		stop()
	end
end

return RealismServer
