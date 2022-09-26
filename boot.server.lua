local ReplicatedStorage = game:GetService("ReplicatedStorage")

local existing = ReplicatedStorage:FindFirstChild("RealismLookAnglesSync")
local lookAnglesSync = existing or Instance.new("RemoteEvent")
assert(
	lookAnglesSync:IsA("RemoteEvent"),
	"SetLookAngles found in ReplicatedStorage wasn't a RemoteEvent"
)
lookAnglesSync.Archivable = false
lookAnglesSync.Name = "RealismLookAnglesSync"
lookAnglesSync.Parent = ReplicatedStorage

local RealismServer = require(script.RealismServer)

RealismServer.start({
	BindTag = "RealismHook",
	LookAnglesSyncRemoteEvent = lookAnglesSync,
})
