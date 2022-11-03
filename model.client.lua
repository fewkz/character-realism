local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RealismClient = require(script.RealismClient)

RealismClient.start({
	BindTag = "RealismHook",
	LookAnglesSyncRemoteEvent = ReplicatedStorage:WaitForChild("RealismLookAnglesSync"),
	ShouldMountMaterialSounds = true,
	ShouldMountLookAngle = true,
	SmoothRotation = true,
	BodyVisible = true,
	PlatformStandDisablesTurning = true,
	PlatformStandLocksTurning = false,
	MaterialSoundFallback = Enum.Material.Concrete,
	MaterialSounds = {
		[Enum.Material.Mud] = 178054124,
		[Enum.Material.Pebble] = 178054124,
		[Enum.Material.Ground] = 178054124,

		[Enum.Material.Sand] = 4777003964,
		[Enum.Material.Snow] = 4777003964,
		[Enum.Material.Sandstone] = 4777003964,

		[Enum.Material.Rock] = 4776998555,
		[Enum.Material.Basalt] = 4776998555,
		[Enum.Material.Asphalt] = 4776998555,
		[Enum.Material.Glacier] = 4776998555,
		[Enum.Material.Slate] = 4776998555,

		[Enum.Material.Wood] = 177940988,
		[Enum.Material.WoodPlanks] = 177940988,

		[Enum.Material.Grass] = 4776173570,
		[Enum.Material.LeafyGrass] = 4776173570,

		[Enum.Material.Concrete] = 277067660,

		[Enum.Material.Fabric] = 4776951843,

		[Enum.Material.Marble] = 4776962643,
		[Enum.Material.Ice] = 4776962643,
		[Enum.Material.Salt] = 4776962643,
		[Enum.Material.Pavement] = 4776962643,
		[Enum.Material.Limestone] = 4776962643,

		[Enum.Material.Metal] = 4790537991,
		[Enum.Material.Foil] = 4790537991,
		[Enum.Material.DiamondPlate] = 4790537991,
		[Enum.Material.CorrodedMetal] = 4790537991,
	},

	RotationFactors = {
		["Head"] = {
			Pitch = 0.75,
			Yaw = 0.8,
		},
		["UpperTorso"] = {
			Pitch = 0.5,
			Yaw = 0.5,
		},
		["LeftUpperArm"] = {
			Pitch = -0.5,
			Yaw = 0.0,
		},
		["RightUpperArm"] = {
			Pitch = -0.5,
			Yaw = 0.0,
		},
		["Torso"] = {
			Pitch = 0.2,
			Yaw = 0.4,
		},
		["Left Arm"] = {
			Pitch = -0.5,
			Yaw = 0.0,
		},
		["Right Arm"] = {
			Pitch = -0.5,
			Yaw = 0.0,
		},
		["Left Leg"] = {
			Pitch = -0.2,
			Yaw = 0.0,
		},
		["Right Leg"] = {
			Pitch = -0.2,
			Yaw = 0.0,
		},
	},
})
