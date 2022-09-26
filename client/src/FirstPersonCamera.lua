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

local function isInFirstPerson()
	local camera = workspace.CurrentCamera
	if camera and camera.CameraType ~= Enum.CameraType.Scriptable then
		local focus = camera.Focus.Position
		local origin = camera.CFrame.Position
		return (focus - origin).Magnitude <= 1
	else
		return false
	end
end

-- Wraps BaseCamera:GetSubjectPosition() to offset the camera
-- to the head when you're in first person.
local function wrapGetSubjectPosition(getSubjectPosition)
	return function(self: any)
		local subject = workspace.CurrentCamera.CameraSubject
		if
			isInFirstPerson()
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
		return getSubjectPosition(self)
	end
end

-- This is an overload function for TransparencyController:IsValidPartToModify(part)
-- You may call it directly if you'd like, as it does not have any external dependencies.
local function isValidPartToModify(part: Instance)
	if part:FindFirstAncestorOfClass("Tool") then
		return false
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
				print("Found head", part, humanoid)
				return true
			end
		end
	end

	return false
end

-- This is an overload function for TransparencyController:Update()
local function wrapUpdateTransparency(updateTransparency)
	return function(self: any, ...)
		updateTransparency(self, ...)

		-- Hack to refresh the camera. This is neccessary since
		-- SetSubject() is a object method
		if self.ForceRefresh then
			self.ForceRefresh = false
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

-- This indicates the user is in first person or shift lock
-- and needs to have its first person movement smoothened out.
local function onRotationTypeChanged()
	local camera = workspace.CurrentCamera
	if
		typeof(camera.CameraSubject) == "Instance"
		and camera.CameraSubject:IsA("Humanoid")
	then
		local humanoid = camera.CameraSubject
		humanoid.AutoRotate = UserGameSettings.RotationType
			== Enum.RotationType.CameraRelative
		if not humanoid.AutoRotate then
			RunService:BindToRenderStep("FirstPersonCamera", 1000, function(delta)
				if
					humanoid.AutoRotate
					or not humanoid:IsDescendantOf(game)
					or (humanoid.SeatPart and humanoid.SeatPart:IsA("VehicleSeat"))
				then
					RunService:UnbindFromRenderStep("FirstPersonCamera")
					return
				end

				if camera.CameraType.Name == "Scriptable" then
					return
				end

				local rootPart: BasePart? = humanoid.RootPart
				local isGrounded = rootPart and rootPart:IsGrounded()

				if rootPart and not isGrounded then
					local state = humanoid:GetState()
					local canRotate = true

					if DONT_ROTATE_STATES[state] then
						canRotate = false
					end

					if humanoid.Sit and humanoid.SeatPart then
						local root = rootPart:GetRootPart()

						if root ~= rootPart then
							canRotate = false
						end
					end

					if canRotate then
						local pos = rootPart.Position
						local step = math.min(0.2, (delta * 40) / 3)

						local look = camera.CFrame.LookVector
						look = (look * XZ_VECTOR3).Unit

						local cf = CFrame.new(pos, pos + look)
						rootPart.CFrame = rootPart.CFrame:Lerp(cf, step)
					end
				end

				if isInFirstPerson() then
					local cf = camera.CFrame

					-- I don't know what this code is for. It seems to not do anything.
					local headPos = getSubjectPosition()
					if headPos then
						local offset = (headPos - cf.Position)
						cf += offset

						camera.CFrame = cf
						camera.Focus += offset
					end
				end
			end)
		end
	end
end

local FirstPersonCamera = {}

FirstPersonCamera.isInFirstPerson = isInFirstPerson

-- Called once to start the FirstPersonCamera logic.
-- Binds and overloads everything necessary.
local started = false
function FirstPersonCamera.start(config: { SmoothRotation: boolean })
	if started then
		return
	else
		started = true
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

	local baseGetSubjectPosition = baseCamera.GetSubjectPosition
	getSubjectPosition = wrapGetSubjectPosition(baseGetSubjectPosition)
	baseCamera.GetSubjectPosition = getSubjectPosition

	transparencyController.Update = wrapUpdateTransparency(transparencyController.Update)
	transparencyController.IsValidPartToModify = function(self, ...)
		return isValidPartToModify(...)
	end
	transparencyController.ForceRefresh = true -- ideally we shouldn't need this
	transparencyController.SetupTransparency =
		wrapSetupTransparency(transparencyController.SetupTransparency)

	if config.SmoothRotation then
		local rotListener = UserGameSettings:GetPropertyChangedSignal("RotationType")
		rotListener:Connect(onRotationTypeChanged)
	end
end

return FirstPersonCamera
