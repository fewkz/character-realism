-- Copyright 2022 fewkz
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at https://mozilla.org/MPL/2.0/.
--
-- This module makes the player's avatar's shadows visible when they are in first person.
-- It does this by creating a mirror of the player's avatar and using a trick to make the
-- mirror invisible while still casting shadows, by setting material to ForceField and
-- transparency to -math.huge.
-- This module only supports R6 avatars and only works in Future and ShadowMap lighting mode.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FirstPersonShadows = {}

local stop: () -> ()?

function FirstPersonShadows.start()
	if stop then
		return
	end
	local mirror = Instance.new("Folder")
	mirror.Name = "FirstPersonMirror"
	-- We put the mirror in CurrentCamera so that it can be filtered from
	-- raycasts by blacklisting the descendants of CurrentCamera.
	mirror.Parent = workspace.CurrentCamera
	local character: Model = if Players.LocalPlayer.Character
		then Players.LocalPlayer.Character
		else Players.LocalPlayer.CharacterAdded:Wait()

	local mirrorMap = {}
	local function descendantSetup(descendant: Instance)
		local bodyPart = if descendant.Parent == character
			then if descendant.Name == "Torso"
				then Enum.BodyPart.Torso
				elseif descendant.Name == "Left Arm" then Enum.BodyPart.LeftArm
				elseif descendant.Name == "Right Arm" then Enum.BodyPart.RightArm
				elseif descendant.Name == "Left Leg" then Enum.BodyPart.LeftLeg
				elseif descendant.Name == "Right Leg" then Enum.BodyPart.RightLeg
				else nil
			else nil
		if descendant:IsA("Part") and (bodyPart or assert(descendant.Parent):IsA("Accessory")) then
			local mirrorPart = descendant:Clone()
			mirrorPart.Anchored = true
			mirrorPart.Massless = true
			mirrorPart.CanTouch = false
			mirrorPart.CanCollide = false
			mirrorPart.CanQuery = false
			mirrorPart.CastShadow = true
			-- When material is set to ForceField and transparency is set to -math.huge,
			-- the part is invisible, but still casts shadows.
			mirrorPart.Material = Enum.Material.ForceField
			mirrorPart.Transparency = -math.huge
			for _, child in mirrorPart:GetChildren() do
				if not child:IsA("SpecialMesh") then
					child:Destroy()
				end
			end
			descendant.ChildAdded:Connect(function(child)
				if child:IsA("SpecialMesh") then
					child:Clone().Parent = mirrorPart
				end
			end)

			-- Adds any CharacterMeshes that are in the character to the mirror part.
			if bodyPart then
				local conn = character.ChildAdded:Connect(function(characterChild)
					if
						characterChild:IsA("CharacterMesh")
						and characterChild.BodyPart == bodyPart
					then
						local specialMesh = Instance.new("SpecialMesh")
						specialMesh.MeshId = "rbxassetid://" .. characterChild.MeshId
						specialMesh.Parent = mirrorPart
					end
				end)
				descendant.AncestryChanged:Connect(function(_, parent)
					if not parent then
						conn:Disconnect()
					end
				end)
				for _, child in character:GetChildren() do
					if child:IsA("CharacterMesh") and child.BodyPart == bodyPart then
						local specialMesh = Instance.new("SpecialMesh")
						specialMesh.MeshId = "rbxassetid://" .. child.MeshId
						specialMesh.Parent = mirrorPart
					end
				end
			end

			mirrorPart.Parent = mirror
			mirrorMap[descendant] = mirrorPart
		end
	end
	for _, descendant in character:GetDescendants() do
		task.spawn(descendantSetup, descendant)
	end
	character.DescendantAdded:Connect(descendantSetup)
	character.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("Part") and mirrorMap[descendant] then
			mirrorMap[descendant]:Destroy()
			mirrorMap[descendant] = nil
		end
	end)
	RunService:BindToRenderStep(
		"FirstPersonShadows",
		Enum.RenderPriority.Camera.Value,
		function()
			for _, descendant in character:GetDescendants() do
				if descendant:IsA("Part") and mirrorMap[descendant] then
					mirrorMap[descendant].CFrame = descendant.CFrame
					mirrorMap[descendant].Size = descendant.Size
				end
			end
		end
	)
	function stop()
		mirror:Destroy()
		RunService:UnbindFromRenderStep("FirstPersonShadows")
	end
end

function FirstPersonShadows.stop()
	if stop then
		stop()
		stop = nil
	end
end

return FirstPersonShadows
