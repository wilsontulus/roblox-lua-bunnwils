--[[

	Bootstrapper for Obby / Tower Management System Module
	License: MIT License (https://spdx.org/licenses/MIT)
	This Luau code was made by the following person:
	- wilsontulus5

--]]

local players = game:GetService("Players")
local rep = game:GetService("ReplicatedStorage")
local gs = rep:WaitForChild("GameScripts")
local module = require(script.Parent)
module.Init() -- Load modulescript

local function playerAdded(player)
	print("[TowerMgr] Loading data for "..player.Name)
	module.Load(player)
end

players.PlayerAdded:Connect(playerAdded)

for _,player in ipairs(game:GetService("Players"):GetPlayers()) do
	playerAdded(player)
end

players.PlayerRemoving:Connect(function(player)	
	module.RemovingPlayer(player)
end)

rep:WaitForChild("GameScripts"):WaitForChild("Checkpoint").OnServerInvoke = function(player:Player, action)
	return module:CheckpointNavigate(player, action)
end