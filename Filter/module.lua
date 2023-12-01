--[[

	Quick Access Module for Roblox TextService Filtering
	License: MIT License (https://spdx.org/licenses/MIT)
	This Luau code was made by the following person:
	- wilsontulus5

--]]

local textSrv = game:GetService("TextService")
local chat	  = game:GetService("Chat")
local Players = game:GetService("Players")
local filterIssueMessage = "(We're sorry, but the intended text may not appear due to Roblox filtering service being down. Re-send or re-enter your text, or if you're not the sender, please ask the sender to re-send until the text displays correctly.)"
local module = {}

function module.FilterTextOnePlayer(msg,sender)
	local filteredText = ""
		local success, errorMessage = pcall(function()
			filteredText = textSrv:FilterStringAsync(msg,sender.UserId,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
		end)
		if not success then

			warn("Server warning filtering error! Roblox filtering service may be down! Error details: " .. errorMessage .. "")
			filteredText = filterIssueMessage
		end
		return filteredText
		--print("Player is "..player.Name..", filtered text is ".. filteredText)
end

function module.FilterTextTwoPlayer(msg,sender,recv)
	local filteredText = ""
	local success, errorMessage = pcall(function()
		filteredText = textSrv:FilterStringAsync(msg,sender.UserId,Enum.TextFilterContext.PublicChat):GetNonChatStringForUserAsync(recv.UserId)
	end)
	if not success then

		warn("Server warning filtering error! Roblox filtering service may be down! Error details: " .. errorMessage .. "")
		filteredText = filterIssueMessage
	end
	return filteredText
	--print("Player is "..player.Name..", filtered text is ".. filteredText)
end

function module.FilterTextTwoPlayerLegacy(msg,sender,recv)
	local filteredText = ""
	local success, errorMessage = pcall(function()
		filteredText = chat:FilterStringAsync(msg,sender,recv.UserId)
	end)
	if not success then

		warn("Server warning filtering error! Roblox filtering service may be down! Error details: " .. errorMessage .. "")
		filteredText = filterIssueMessage
	end
	return filteredText
	--print("Player is "..player.Name..", filtered text is ".. filteredText)
end

function module.FilterTextGlobal(msg,sender)
	local filteredText = ""
	local success, errorMessage = pcall(function()
		filteredText = chat:FilterStringForBroadcast(msg,sender)
	end)
	if not success then

		warn("Server warning filtering error! Roblox filtering service may be down! Error details: " .. errorMessage .. "")
		filteredText = filterIssueMessage
	end
	return filteredText
	--print("Player is "..player.Name..", filtered text is ".. filteredText)
end

return module
