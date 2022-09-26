--!strict
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FirstPersonCamera = require(script.FirstPersonCamera)

local XZ_VECTOR3 = Vector3.new(1, 0, 1)

type Motor =
	{ Motor: Motor6D, C0: CFrame, Origin: nil }
	| { Motor: Motor6D, C0: nil, Origin: Attachment }
type Rotator = {
	Motors: { [string]: Motor },
	Pitch: { Goal: number, Current: number },
	Yaw: { Goal: number, Current: number },
}

local rotators: { [Model]: Rotator } = {}

local function isInFirstPerson()
	return FirstPersonCamera.isInFirstPerson()
end

local function round(number: number, factor: number)
	local mult = 10 ^ factor
	return math.round(number * mult) / mult
end

local function roundNearestInterval(number: number, factor)
	return round(number / factor, 0) * factor
end

local function stepTowards(value: number, goal, rate): number
	if math.abs(value - goal) < rate then
		return goal
	elseif value > goal then
		return value - rate
	elseif value < goal then
		return value + rate
	else
		return value
	end
end

-- Register's a newly added Motor6D
-- into the provided joint rotator.
local function addMotor(rotator: Rotator, motor: Motor6D, rigType: Enum.HumanoidRigType)
	local parent = motor.Parent
	assert(parent and parent:IsA("BasePart"))
	parent.CanCollide = false -- why

	-- Wait until this motor is marked as active
	-- before attempting to use it in the rotator.
	while not motor.Active do
		-- Motor becomes active upon parent changing.
		motor.Changed:Wait()
	end
	local data: Motor
	if rigType == Enum.RigType.R15 then
		local origin = motor.Part0:WaitForChild(motor.Name .. "RigAttachment", 4)
		assert(origin, "Couldn't get " .. motor.Name .. "RigAttachment")
		data = { Motor = motor, Origin = origin }
	else
		data = { Motor = motor, C0 = motor.C0 }
	end

	-- Add this motor to the rotator
	-- by the name of its Part1 value.
	rotator.Motors[motor.Part1.Name] = data
end

-- Called when the client receives a new look-angle
-- value from the server. This is also called continuously
-- on the client to update the player's view with no latency.
local function onLookReceive(player, pitch, yaw)
	local character = player.Character
	local rotator = rotators[character]

	if rotator then
		rotator.Pitch.Goal = pitch
		rotator.Yaw.Goal = yaw
	end
end

-- Computes the look-angle to be used by the client.
-- If no lookVector is provided, the camera's lookVector is used instead.
-- useDir (-1 or 1) can be given to force whether the direction is flipped or not.
local function computeLookAngle(lookVector: Vector3?, useDir: number?)
	local inFirstPerson = isInFirstPerson()
	local yaw, pitch, dir = 0, 0, 1

	if not lookVector then
		local camera = workspace.CurrentCamera
		lookVector = camera.CFrame.LookVector
	end

	local character = Players.LocalPlayer.Character
	if lookVector and character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = if humanoid then humanoid.RootPart else nil
		if rootPart then
			assert(typeof(rootPart) == "Instance" and rootPart:IsA("BasePart"))
			local cf = rootPart.CFrame
			yaw = -cf.RightVector:Dot(lookVector)

			if not inFirstPerson then
				dir = math.clamp(cf.LookVector:Dot(lookVector) * 10, -1, 1)
			end
		end

		pitch = lookVector.Y
	end

	if useDir then
		dir = useDir
	end

	yaw *= dir
	pitch *= dir

	return pitch, yaw
end

-- Interpolates the current value of a rotator
-- state (pitch/yaw) towards its goal value.
local function stepValue(state, delta: number)
	local current: number = state.Current
	local goal: number = state.Goal

	local pan = 5 / (delta * 60)
	local rate = math.min(1, (delta * 20) / 3)

	local step = math.min(rate, math.abs(goal - current) / pan)
	state.Current = stepTowards(current, goal, step)

	return state.Current
end

local lastPitch, lastYaw
local lastUpdate = 0
local function updateServer(remoteEvent: RemoteEvent, pitch, yaw)
	local now = os.clock()
	if (now - lastUpdate) > 0.5 then
		pitch = roundNearestInterval(pitch, 0.05)
		yaw = roundNearestInterval(yaw, 0.05)
		if pitch ~= lastPitch or yaw ~= lastYaw then
			lastPitch = pitch
			lastYaw = yaw
			lastUpdate = now
			remoteEvent:FireServer(pitch, yaw)
		end
	end
end

-- Runs every frame for each character that has a rotator, and updates their motors smoothly.
local function updateCharacter(delta, config: Config, character, rotator: Rotator)
	local camera = workspace.CurrentCamera
	local camPos = camera.CFrame.Position

	local owner = Players:GetPlayerFromCharacter(character)
	local dist = owner and owner:DistanceFromCharacter(camPos) or 0

	if owner ~= Players.LocalPlayer and dist > 30 then
		return
	end

	local rootPart = character.PrimaryPart
	if not rootPart then
		return
	end
	assert(rootPart)

	local pitchState = rotator.Pitch
	stepValue(pitchState, delta)

	local yawState = rotator.Yaw
	stepValue(yawState, delta)

	local motors = rotator.Motors

	for name, factors in pairs(config.RotationFactors) do
		local data: Motor? = if motors then motors[name] else nil
		if not data then
			continue
		end
		assert(data)

		local motor = data.Motor

		local origin
		if data.Origin then
			local part0 = motor.Part0
			local setPart0 = data.Origin.Parent

			if part0 and part0 ~= setPart0 then
				local newOrigin = part0:FindFirstChild(data.Origin.Name)

				if newOrigin and newOrigin:IsA("Attachment") then
					data.Origin = newOrigin
				end
			end

			origin = data.Origin.CFrame
		elseif data.C0 then
			origin = data.C0
		end

		local pitch = pitchState.Current
		local yaw = yawState.Current

		if character == Players.LocalPlayer.Character and name == "Head" then
			if isInFirstPerson() then
				pitch = pitchState.Goal
				yaw = yawState.Goal
			end
		end

		local fPitch = pitch * factors.Pitch
		local fYaw = yaw * factors.Yaw

		-- HACK: Make the arms rotate with a tool.
		if string.sub(name, -4) == " Arm" or string.sub(name, -8) == "UpperArm" then
			local tool = character:FindFirstChildOfClass("Tool")

			if tool and not CollectionService:HasTag(tool, "NoArmRotation") then
				if
					string.sub(name, 1, 5) == "Right"
					and rootPart:GetRootPart() ~= rootPart
				then
					fPitch = pitch * 1.3
					fYaw = yaw * 1.3
				else
					fPitch = pitch * 0.8
				end
			end
		end

		local rot = origin - origin.Position
		local cf = CFrame.Angles(0, fYaw, 0) * CFrame.Angles(fPitch, 0, 0)
		motor.C0 = origin * rot:Inverse() * cf * rot
	end
end

-- Called to update all of the look-angles being tracked
-- on the client, as well as our own client look-angles.
-- This is called during every RunService Heartbeat.
local function updateLookAngles(delta, config: Config)
	-- Update our own look-angles with no latency
	local pitch, yaw = computeLookAngle()
	onLookReceive(Players.LocalPlayer, pitch, yaw)

	updateServer(config.LookAnglesSyncRemoteEvent, pitch, yaw)

	-- Update all of the character look-angles
	for character, rotator in rotators do
		task.spawn(updateCharacter, delta, config, character, rotator)
	end
end

-- Mounts the provided humanoid into the look-angle
-- update system, binding all of its current and
-- future Motor6D joints into the rotator.
local function mountLookAngle(humanoid: Humanoid)
	local char = humanoid.Parent
	assert(char and char:IsA("Model"), "Could not find humanoid's character")
	if rotators[char] then
		return rotators[char]
	else
		local rotator: Rotator = {
			Motors = {},
			Pitch = { Goal = 0, Current = 0 },
			Yaw = { Goal = 0, Current = 0 },
		}
		rotators[char] = rotator
		-- Record all existing Motor6D joints
		-- and begin recording newly added ones.
		local function onDescendantAdded(instance: Instance)
			if instance:IsA("Motor6D") then
				addMotor(rotator, instance, humanoid.RigType)
			end
		end
		local listener = char.DescendantAdded:Connect(onDescendantAdded)
		for _, instance in char:GetDescendants() do
			onDescendantAdded(instance)
		end
		char.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				listener:Disconnect()
				rotators[char] = nil
			end
		end)
		return rotator
	end
end

local warnedMaterials = {}

-- Mounts the custom material walking sounds into the provided
-- humanoid. This mounting assumes the HumanoidRootPart is the
-- part that will be storing the character's "Running" sound.
local function mountMaterialSounds(humanoid: Humanoid, config: Config)
	local char = humanoid.Parent
	assert(char and char:IsA("Model"), "Could not find humanoid's character")
	while not humanoid.RootPart do
		char.ChildAdded:Wait()
	end
	local rootPart = humanoid.RootPart
	assert(rootPart and rootPart:IsA("BasePart"), "Character had no root part")
	local running = rootPart:WaitForChild("Running", 4)
	assert(running and running:IsA("Sound"), "Couldn't get running sound")

	local conn = RunService.Heartbeat:Connect(function()
		if
			humanoid:GetState() ~= Enum.HumanoidStateType.Running
			and humanoid:GetState() ~= Enum.HumanoidStateType.RunningNoPhysics
		then
			return
		end
		local hipHeight = if humanoid.RigType.Name == "R6"
			then 2.8
			else humanoid.HipHeight

		local scale = hipHeight / 3
		local speed = (rootPart.AssemblyLinearVelocity * XZ_VECTOR3).Magnitude

		local volume = ((speed - 4) / 12) * scale
		running.Volume = math.clamp(volume, 0, 1)

		local pitch = 1 / ((scale * 15) / speed)
		running.PlaybackSpeed = pitch
	end)

	humanoid.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			conn:Disconnect()
		end
	end)

	local function updateRunningSoundId()
		local material = humanoid.FloorMaterial
		if config.MaterialSounds[material] then
			running.SoundId = "rbxassetid://" .. config.MaterialSounds[material]
		else
			if not warnedMaterials[material] then
				local msg = string.format(
					"Material for material %s not defined, falling back to %s",
					humanoid.FloorMaterial.Name,
					config.MaterialSoundFallback.Name
				)
				warn(msg)
				warnedMaterials[material] = true
			end
			running.SoundId = "rbxassetid://"
				.. config.MaterialSounds[config.MaterialSoundFallback]
		end
	end

	local floorListener = humanoid:GetPropertyChangedSignal("FloorMaterial")
	floorListener:Connect(updateRunningSoundId)
	updateRunningSoundId()

	running.RollOffMinDistance = 1
	running.RollOffMaxDistance = 50
end

type RotationFactor = { Pitch: number, Yaw: number }
export type Config = FirstPersonCamera.Config & {
	BindTag: string,
	LookAnglesSyncRemoteEvent: RemoteEvent,
	ShouldMountMaterialSounds: boolean,
	ShouldMountLookAngle: boolean,
	-- A dictionary mapping materials to walking sound ids.
	MaterialSounds: { [Enum.Material]: number },
	MaterialSoundFallback: Enum.Material,
	-- Multiplier values (in radians) for each
	-- joint, based on the pitch/yaw look angles
	RotationFactors: {
		-- R6 & R15
		["Head"]: RotationFactor?,
		-- R15
		["UpperTorso"]: RotationFactor?,
		["LeftUpperArm"]: RotationFactor?,
		["RightUpperArm"]: RotationFactor?,
		-- R6
		["Torso"]: RotationFactor?,
		["Left Arm"]: RotationFactor?,
		["Right Arm"]: RotationFactor?,
		["Left Leg"]: RotationFactor?,
		["Right Leg"]: RotationFactor?,
	},
}

local RealismClient = {}

local running: Running?
function RealismClient.start(config: Config)
	if running then
		return running
	end
	FirstPersonCamera.start({ SmoothRotation = config.SmoothRotation })
	local function onHumanoid(humanoid)
		if config.ShouldMountLookAngle then
			task.spawn(mountLookAngle, humanoid)
		end
		if config.ShouldMountMaterialSounds then
			task.spawn(mountMaterialSounds, humanoid, config)
		end
	end
	local conn1 = CollectionService:GetInstanceAddedSignal(config.BindTag)
		:Connect(onHumanoid)
	for _, humanoid in CollectionService:GetTagged(config.BindTag) do
		onHumanoid(humanoid)
	end

	local conn2 = RunService.Heartbeat:Connect(function(delta)
		updateLookAngles(delta, config)
	end)
	config.LookAnglesSyncRemoteEvent.OnClientEvent:Connect(onLookReceive)

	local function stop()
		conn1:Disconnect()
		conn2:Disconnect()
		running = nil
	end

	local function editConfig(modifications)
		config.ShouldMountLookAngle = modifications.ShouldMountLookAngle
		config.ShouldMountMaterialSounds = modifications.ShouldMountMaterialSounds
	end

	running = { stop = stop, editConfig = editConfig }
	assert(running)
	return running
end
type Running = typeof(RealismClient.start({} :: any))

function RealismClient.edit(modifications)
	if running then
		running.editConfig(modifications)
	end
end

function RealismClient.stop()
	if running then
		running.stop()
	end
end

return RealismClient
