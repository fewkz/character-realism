local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local function onCharacterAdded(character: Model, config: Config)
	local humanoid = character:WaitForChild("Humanoid", 4)
	assert(humanoid, "Humanoid for " .. character.Name .. " couldn't be found")
	CollectionService:AddTag(humanoid, config.BindTag)
end

local function onPlayerAdded(player: Player, config: Config)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(character, config)
	end)
	if player.Character then
		onCharacterAdded(player.Character, config)
	end
end

local RealismServer = {}

export type Config = { LookAnglesSyncRemoteEvent: RemoteEvent, BindTag: string }
local stop
function RealismServer.start(config: Config)
	if stop then
		return
	end

	local conn1 = Players.PlayerAdded:Connect(function(player)
		onPlayerAdded(player, config)
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player, config)
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
