local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local existing = ReplicatedStorage:FindFirstChild("SetLookAngles")
local setLookAngles = existing or Instance.new("RemoteEvent")
assert(
	setLookAngles:IsA("RemoteEvent"),
	"SetLookAngles found in ReplicatedStorage wasn't a RemoteEvent"
)
setLookAngles.Archivable = false
setLookAngles.Name = "SetLookAngles"
setLookAngles.Parent = ReplicatedStorage

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

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

setLookAngles.OnServerEvent:Connect(function(player, pitch: unknown, yaw: unknown)
	assert(typeof(pitch) == "number" and pitch == pitch, "Invalid pitch")
	assert(typeof(yaw) == "number" and yaw == yaw, "Invalid yaw")
	setLookAngles:FireAllClients(player, math.clamp(pitch, -1, 1), math.clamp(yaw, -1, 1))
end)
