local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Plasma = require(ReplicatedStorage.Plasma)
local RealismClient = require(script.RealismClient)

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true)

local bodyVisible = true
local smoothRotation = true
local firstPersonShadows = true

local function start()
	RealismClient.start({
		BindTag = "RealismHook",
		LookAnglesSyncRemoteEvent = ReplicatedStorage.RealismLookAnglesSync,
		ShouldMountMaterialSounds = true,
		ShouldMountLookAngle = true,
		SmoothRotation = smoothRotation,
		MoveDirectionFactor = 0.25,
		BodyVisible = bodyVisible,
		FirstPersonShadowsBeta = firstPersonShadows,
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
				Pitch = 0.2,
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
end

start()

local running = true

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RealismConfigUI"
screenGui.Parent = Players.LocalPlayer.PlayerGui

local root = Plasma.new(screenGui)

local oldAccessories = {}

local function removeRandomAccessory()
	local humanoid: Humanoid? = if Players.LocalPlayer.Character
		then Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
		else nil
	if humanoid then
		local accessories = humanoid:GetAccessories()
		if #accessories > 0 then
			local accessory = accessories[math.random(1, #accessories)]
			table.insert(oldAccessories, accessory)
			accessory.Parent = nil
		end
	end
end

local function addRandomAccessory()
	if #oldAccessories > 0 then
		local accessory =
			assert(table.remove(oldAccessories, math.random(1, #oldAccessories)))
		accessory.Parent = Players.LocalPlayer.Character
	end
end

RunService.Heartbeat:Connect(function()
	Plasma.start(root, function()
		Plasma.window({ title = "Realism Config", resizable = false }, function()
			if Plasma.checkbox("Running", { checked = running }):clicked() then
				running = not running
				if running then
					start()
				else
					RealismClient.stop()
				end
			end
			Plasma.space()
			if Plasma.checkbox("Body Visible", { checked = bodyVisible }):clicked() then
				bodyVisible = not bodyVisible
				RealismClient.edit({ BodyVisible = bodyVisible })
			end
			if
				Plasma.checkbox("Smooth Rotation", { checked = smoothRotation }):clicked()
			then
				smoothRotation = not smoothRotation
				RealismClient.edit({ SmoothRotation = smoothRotation })
			end
			if
				Plasma.checkbox("First Person Shadows", { checked = firstPersonShadows })
					:clicked()
			then
				firstPersonShadows = not firstPersonShadows
				RealismClient.edit({
					FirstPersonShadowsBeta = firstPersonShadows,
				})
			end
		end)
		Plasma.window({ title = "Accessory Tester", resizable = false }, function()
			Plasma.label(
				"First Person Shadows are designed to work"
					.. "\nwith accessories being added or removed."
					.. "\nUse this window for testing out adding and"
					.. "\nremoving accessories."
			)
			local everRemoved, setEverRemoved = Plasma.useState(false)
			if Plasma.button("Remove random accessory"):clicked() then
				setEverRemoved(true)
				removeRandomAccessory()
			end
			if everRemoved then
				if Plasma.button("Add back accessory"):clicked() then
					addRandomAccessory()
				end
			end
		end)
	end)
end)
