local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RealismServer = require(script.RealismServer)

RealismServer.start({
	BindTag = "RealismHook",
	LookAnglesSyncRemoteEvent = ReplicatedStorage.RealismLookAnglesSync,
})
