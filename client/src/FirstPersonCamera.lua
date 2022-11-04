local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local XZ_VECTOR3 = Vector3.new(1, 0, 1)

local DONT_ROTATE_STATES = {
	[Enum.HumanoidStateType.Swimming] = true,
	[Enum.HumanoidStateType.Climbing] = true,
	[Enum.HumanoidStateType.Dead] = true,
}

local getSubjectPosition: () -> (Vector3)

local function isHeadAttachment(attachment: Attachment)
	return attachment.Name == "FaceCenterAttachment"
		or attachment.Name == "FaceFrontAttachment"
		or attachment.Name == "HairAttachment"
		or attachment.Name == "HatAttachment"
end

local function isInFirstPerson(camera: Camera)
	return if camera.CameraType ~= Enum.CameraType.Scriptable
		then (camera.Focus.Position - camera.CFrame.Position).Magnitude <= 1
		else false
end

-- Wraps BaseCamera:GetSubjectPosition() to offset the camera
-- to the head when you're in first person.
local function wrapGetSubjectPosition(getSubjectPosition)
	return function()
		local subject = workspace.CurrentCamera.CameraSubject
		if
			isInFirstPerson(workspace.CurrentCamera)
			and typeof(subject) == "Instance"
			and subject:IsA("Humanoid")
			and subject.Health > 0
			and subject.Parent
		then
			local head = subject.Parent:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				return head.CFrame * Vector3.new(0, head.Size.Y / 3, 0)
			end
		end
		return getSubjectPosition()
	end
end

-- This is an overload function for TransparencyController:IsValidPartToModify(part)
-- You may call it directly if you'd like, as it does not have any external dependencies.
-- This function is used to determine which parts should be transparent in first person.
local function isValidPartToModify(config: Config, part: Instance)
	if part:FindFirstAncestorOfClass("Tool") then
		return false
	end
	if not config.BodyVisible and part:IsA("BasePart") then
		return true
	end
	if part:IsA("Decal") and part.Parent then
		part = part.Parent
	end
	if part:IsA("BasePart") then
		local accessory = part:FindFirstAncestorWhichIsA("Accoutrement")

		if accessory then
			if part.Name ~= "Handle" then
				local handle = accessory:FindFirstChild("Handle", true)

				if handle and handle:IsA("BasePart") then
					part = handle
				end
			end

			for _, child in part:GetChildren() do
				if child:IsA("Attachment") then
					if isHeadAttachment(child) then
						return true
					end
				end
			end
		elseif part.Name == "Head" then
			local model = part.Parent
			local camera = workspace.CurrentCamera
			local humanoid = if model
				then model:FindFirstChildOfClass("Humanoid")
				else nil

			if humanoid and camera.CameraSubject == humanoid then
				return true
			end
		end
	end

	return false
end

local forceTransparencyRefresh = false
-- This is an overload function for TransparencyController:Update()
local function wrapUpdateTransparency(updateTransparency)
	return function(self: any, ...)
		updateTransparency(self, ...)

		-- Hack to refresh the camera. This is neccessary since
		-- SetSubject() is a object method
		if forceTransparencyRefresh then
			forceTransparencyRefresh = false
			if self.SetSubject then
				local camera = workspace.CurrentCamera
				self:SetSubject(camera.CameraSubject)
			end
		end
	end
end

-- This is an overloaded function for TransparencyController:SetupTransparency(character)
local function wrapSetupTransparency(setupTransparency)
	return function(self: any, character: Model, ...)
		setupTransparency(self, character, ...)

		if self.AttachmentListener then
			self.AttachmentListener:Disconnect()
		end

		self.AttachmentListener = character.DescendantAdded:Connect(function(obj)
			if obj:IsA("Attachment") and isHeadAttachment(obj) then
				if typeof(self.cachedParts) == "table" then
					self.cachedParts[obj.Parent] = true
				end

				if self.transparencyDirty ~= nil then
					self.transparencyDirty = true
				end
			end
		end)
	end
end

local function setupSmoothRotation(camera: Camera, config: Config)
	local humanoid: Humanoid?

	local function setupCameraSubject()
		local cameraSubject: Instance? = camera.CameraSubject
		if cameraSubject and cameraSubject:IsA("Humanoid") then
			humanoid = cameraSubject

			local rotationType = UserGameSettings.RotationType
			cameraSubject.AutoRotate = rotationType ~= Enum.RotationType.CameraRelative
		elseif cameraSubject and cameraSubject:IsA("VehicleSeat") then
			-- CameraSubject gets set to VehicleSeat when you sit on a VehicleSeat.
			-- We want to set the CameraSubject to use the Humanoid instead.
			camera.CameraSubject = cameraSubject.Occupant
		else
			humanoid = nil
		end
	end
	local conn1 =
		camera:GetPropertyChangedSignal("CameraSubject"):Connect(setupCameraSubject)
	setupCameraSubject()

	local conn2 = UserGameSettings:GetPropertyChangedSignal("RotationType")
		:Connect(function()
			local rotationType = UserGameSettings.RotationType
			if humanoid then
				humanoid.AutoRotate = rotationType ~= Enum.RotationType.CameraRelative
			end
		end)
	local rotationType = UserGameSettings.RotationType
	if humanoid then
		humanoid.AutoRotate = rotationType ~= Enum.RotationType.CameraRelative
	end

	RunService:BindToRenderStep("FirstPersonCamera", 1000, function(delta: number)
		local rotationType = UserGameSettings.RotationType
		if
			not humanoid
			or rotationType ~= Enum.RotationType.CameraRelative
			or not humanoid:IsDescendantOf(game)
			or camera.CameraType == Enum.CameraType.Scriptable
		then
			return
		end
		assert(humanoid)

		local rootPart: BasePart? = humanoid.RootPart
		local isGrounded = rootPart and rootPart:IsGrounded()

		if rootPart and not isGrounded then
			local state = humanoid:GetState()
			local canRotate = true

			if DONT_ROTATE_STATES[state] then
				canRotate = false
			end

			if humanoid.Sit and not humanoid.SeatPart or humanoid.PlatformStand then
				canRotate = false
			elseif humanoid.Sit and humanoid.SeatPart then
				local root = rootPart:GetRootPart()

				if root ~= rootPart then
					canRotate = false
				end
			end

			if canRotate then
				local pos = rootPart.Position
				local step = math.min(0.2, (delta * 40) / 3)

				local cameraDirection = (camera.CFrame.LookVector * XZ_VECTOR3).Unit

				local moveDirection
				local xzVelocity = rootPart.AssemblyLinearVelocity * XZ_VECTOR3
				if xzVelocity.Magnitude > 0.1 then
					local invDot = 1 - math.abs(cameraDirection:Dot(xzVelocity.Unit))
					moveDirection = (
						cameraDirection * (1 - invDot) + xzVelocity.Unit * invDot
					)
				else
					moveDirection = cameraDirection
				end

				local look = (
					cameraDirection * (1 - config.MoveDirectionFactor)
					+ moveDirection * config.MoveDirectionFactor
				).Unit

				local cf = CFrame.new(pos, pos + look)
				rootPart.CFrame = rootPart.CFrame:Lerp(cf, step)
			end
		end

		if isInFirstPerson(camera) then
			local cf = camera.CFrame
			local headPos = getSubjectPosition()
			if headPos then
				local offset = (headPos - cf.Position)
				cf += offset

				camera.CFrame = cf
				camera.Focus += offset
			end
		end
	end)
	return function()
		if humanoid then
			humanoid.AutoRotate = true
		end
		conn1:Disconnect()
		conn2:Disconnect()
		RunService:UnbindFromRenderStep("FirstPersonCamera")
	end
end

local FirstPersonCamera = {}

-- Called once to start the FirstPersonCamera logic.
-- Binds and overloads everything necessary.
export type Config = {
	SmoothRotation: boolean,
	BodyVisible: boolean,
	MoveDirectionFactor: number,
}
export type Modifications = {
	SmoothRotation: boolean?,
	BodyVisible: boolean?,
	MoveDirectionFactor: number?,
}
local running: Running?
function FirstPersonCamera.start(config: Config)
	if running then
		return running
	end

	local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	local PlayerModule = PlayerScripts:WaitForChild("PlayerModule")

	local baseCamera = (require :: any)(
		assert(PlayerModule:FindFirstChild("BaseCamera", true), "Couldn't get BaseCamera")
	)

	local transparencyControllerScript =
		PlayerModule:FindFirstChild("TransparencyController", true)
	local transparencyController = (require :: any)(
		assert(transparencyControllerScript, "Couldn't get TransparencyController")
	)

	local baseBaseCameraGetSubjectPosition = baseCamera.GetSubjectPosition
	local baseTransparencyControllerUpdate = transparencyController.Update
	local baseTransparencyControllerIsValidPartToModify =
		transparencyController.IsValidPartToModify
	local baseTransparencyControllerSetupTransparency =
		transparencyController.SetupTransparency

	local cleanupSmoothRotation
	local function setSmoothRotation(new, old)
		if new and not old then
			-- Overrides for BaseCamera
			getSubjectPosition = wrapGetSubjectPosition(function()
				return baseBaseCameraGetSubjectPosition(baseCamera)
			end)
			baseCamera.GetSubjectPosition = getSubjectPosition
			cleanupSmoothRotation = setupSmoothRotation(workspace.CurrentCamera, config)
		elseif old and not new then
			cleanupSmoothRotation()
			baseCamera.GetSubjectPosition = baseBaseCameraGetSubjectPosition
		end
	end
	setSmoothRotation(config.SmoothRotation, false)

	local function setBodyVisible(new, old)
		if new and not old then
			-- Overrides for TransparencyController
			transparencyController.Update =
				wrapUpdateTransparency(baseTransparencyControllerUpdate)
			transparencyController.IsValidPartToModify = function(_self, ...)
				return isValidPartToModify(config, ...)
			end
			transparencyController.SetupTransparency =
				wrapSetupTransparency(baseTransparencyControllerSetupTransparency)
		elseif old and not new then
			transparencyController.IsValidPartToModify =
				baseTransparencyControllerIsValidPartToModify
			transparencyController.SetupTransparency =
				baseTransparencyControllerSetupTransparency
			-- This is required so that it can detect that forceTransparencyRefresh changed.
			-- It has to schuled last on the next heartbeat. It's kind of hacky, but having
			-- to use forceTransparencyRefresh at all is hacky.
			task.delay(nil, task.defer, function()
				transparencyController.Update = baseTransparencyControllerUpdate
			end)
		end
		forceTransparencyRefresh = true -- ideally we shouldn't need this
	end
	setBodyVisible(config.BodyVisible, false)

	local function stop()
		cleanupSmoothRotation()
		setSmoothRotation(false, config.SmoothRotation)
		setBodyVisible(false, config.BodyVisible)
	end

	local function editConfig(modifications: Modifications)
		if modifications.SmoothRotation ~= nil then
			setSmoothRotation(modifications.SmoothRotation, config.SmoothRotation)
			config.SmoothRotation = modifications.SmoothRotation
		end
		if modifications.BodyVisible ~= nil then
			setBodyVisible(modifications.BodyVisible, config.BodyVisible)
			config.BodyVisible = modifications.BodyVisible
		end
		if modifications.MoveDirectionFactor ~= nil then
			config.MoveDirectionFactor = modifications.MoveDirectionFactor
		end
	end

	running = { stop = stop, editConfig = editConfig }
	assert(running)
	return running
end
type Running = typeof(FirstPersonCamera.start({} :: any))

function FirstPersonCamera.edit(modifications)
	if running then
		running.editConfig(modifications)
	end
end

function FirstPersonCamera.stop()
	if running then
		running.stop()
	end
end

return FirstPersonCamera
