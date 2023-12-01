--!strict
--[[

	Background Music System
	License: MIT License (https://spdx.org/licenses/MIT)
	This Luau code was made by the following person:
	- wilsontulus5

--]]

local marketSrv = game:GetService("MarketplaceService")
local musiclistmodule = require(script.Parent)

local noMusicInStudio = true


function changeMusic(id)
	if game:GetService("ReplicatedStorage"):FindFirstChild("BackgroundMusic") then
		game:GetService("ReplicatedStorage"):WaitForChild("BackgroundMusic"):Destroy()
	end
	local sou = Instance.new("Sound")
	sou.SoundId = "rbxassetid://"..id
	sou.Looped = false
	sou.Name = "BackgroundMusic"
	sou.Volume = 0.5
	sou.Playing = false
	sou.Parent = game:GetService("ReplicatedStorage")
	local na = game:GetService("ReplicatedStorage"):WaitForChild("BGMName")
	local su,mname = pcall(function()
		return marketSrv:GetProductInfo(id, Enum.InfoType.Asset)
	end)
	if su then
		na.Value = mname.Name
	else
		warn("Error getting info for sound ID "..id.." because of: "..mname)
		na.Value = "Unknown"
	end
	sou:Play()
	sou.Ended:Wait()
	
end

local list = musiclistmodule.GetMusicIDs()
if not (game:GetService("RunService"):IsStudio() and noMusicInStudio) then
	while task.wait(.05) do
		local id = list[math.random(1,#list)]
		changeMusic(id)
	end
end