--[[

	ROBLOX Character CFrame Recorder
	License: MIT License (https://spdx.org/licenses/MIT)
	This Luau code is made by the following person:
	- wilsontulus5

--]]

local dataSrv = game:GetService("DataStoreService")
local dataStore = dataSrv:GetDataStore("SejahteraCFrameRecordsV1")
local Admins = require(script.Parent:WaitForChild("RankList")).GetAdmins()
local runSrv = game:GetService("RunService")
local rigR6 = script:WaitForChild("RigR6")
rigR6.PrimaryPart.Anchored = true

local FPS = 15 --Frames per second --Must be either 60, or <= 30 --In practice, anything above 15 is too laggy

local recLimit = 600 --Maximum seconds it can record
local recLimitDS = 90 --Maximum seconds it can record with DataStore saving

local RecordingPlayerIDs = {
	[1] = false;
}

local RecordedCF = {
	[1] = {	-- Roblox
		
	}
}

local SampleData = {
	FPS = 15;
	Username = "Roblox";
	Frames = {}
}

local module = {}

function module.StartRecording(player:Player, saveToData:boolean, stopWhenDied: boolean)
	if not player or not player:IsA("Player") then return end
	print("Preparing to record CFrame steps of "..player.Name)
	repeat task.wait() until player and player.Character and player.Character.PrimaryPart
	local char = player.Character
	local charPrimaryPart = char.PrimaryPart
	local length = 0
	local maxLength = if saveToData then recLimitDS else recLimit
	local tFps = FPS
	if char and (game.JobId=='' or player:HasAppearanceLoaded()) then
		print("[CFRECORD] Recording player "..player.Name.." CFrames.")
		RecordingPlayerIDs[player.UserId] = true
		RecordedCF[player.UserId] = {}
		local rcf = RecordedCF[player.UserId]
		local hum = player.Character:FindFirstChildWhichIsA("Humanoid")
		local humDevent
		if stopWhenDied == true and hum then
			humDevent = hum.Died:Connect(function() task.wait(1) RecordingPlayerIDs[player.UserId] = false end)
		end
		repeat
			if FPS==60 then runSrv.Heartbeat:Wait() else task.wait(1/tFps) end
			if player and char and charPrimaryPart and rcf then
				table.insert(rcf, {charPrimaryPart.CFrame:GetComponents()})
				length += 1
			else
				break
			end 
		until length>=maxLength*FPS or not RecordingPlayerIDs[player.UserId] or not char
		RecordingPlayerIDs[player.UserId] = false
		print("[CFRECORD] Finished recording player "..player.Name.." CFrames.", if saveToData == true then "- Saving to DataStore..." else "")
		if humDevent then
			humDevent:Disconnect()
		end
		humDevent = nil
		if saveToData == true then
			local savetable = SampleData
			savetable.FPS = tFps
			savetable.Username = player.Name
			savetable.Frames = RecordedCF[player.UserId]
			local attempts = 0
			local stdSuccess, stErrors = false, ""
			repeat
				stdSuccess, stErrors = pcall(function()
					return dataStore:SetAsync("User_"..player.UserId, savetable, {player.UserId})
				end) task.wait(1)
			until stdSuccess or attempts > 3
			if not stdSuccess then
				warn("[CFRECORD] Couldn't save "..player.Name.."'s data more than 3 times to DataStore because: "..tostring(stErrors))
			end
		end
	end
end

function module.StopRecording(player:Player)
	if player and player.UserId and RecordingPlayerIDs[player.UserId] then
		RecordingPlayerIDs[player.UserId] = false
		print(RecordedCF[player.UserId])
	else
		warn("[CFRECORD] Player "..player.Name.." is not recording CFrame steps")
	end
end

function module.PlayRecording(player:Player, playFPS:number)
	if RecordedCF[player.UserId] then
		local desiredFPS = tonumber(playFPS) or FPS
		local cl = rigR6:Clone()
		cl.Parent = workspace
		cl.Name = "Record of "..player.Name.." CFrame Rig"
		cl.PrimaryPart.Anchored = true
		print("Playing back "..player.Name.."'s last CFrame Record")
		for _,v in pairs(RecordedCF[player.UserId]) do
			cl.PrimaryPart.CFrame = CFrame.new(table.unpack(v))
			task.wait(1 / desiredFPS)
		end
		cl.PrimaryPart.Anchored = false
		print("[CFRECORD] Playback finished.") task.wait(3) if cl then cl:Destroy() end
	else
		warn("[CFRECORD] Player "..player.Name.."'s CFrame records is not found!")
	end
end

function module.PlayRecordingFromDataStore(userID: number)
	if tonumber(userID) and tonumber(userID) > 0 then
		local attempts = 0
		local stdSuccess, stData = false, ""
		repeat
			stdSuccess, stData = pcall(function()
				return dataStore:GetAsync("User_"..userID)
			end) task.wait(1)
		until stdSuccess or attempts > 3
		if stdSuccess then
			if stData and typeof(stData) == "table" and stData["FPS"] then
				if stData["Frames"] and stData["Frames"][1] then
					local tFps = stData["FPS"]
					local cl = rigR6:Clone()
					cl.Parent = workspace
					cl.Name = "Record of "..stData["Username"] or "[Unknown Username]".." CFrame Rig"
					cl.PrimaryPart.Anchored = true
					print("Playing back "..stData["Username"] or "[Unknown Username]".." (ID "..userID..")'s last CFrame Record")
					for _,v in pairs(stData["Frames"]) do
						cl.PrimaryPart.CFrame = CFrame.new(table.unpack(v))
						task.wait(1/tFps)
					end
					cl.PrimaryPart.Anchored = false
					print("[CFRECORD] Playback finished.") task.wait(3) if cl then cl:Destroy() end
				else
					warn("[CFRECORD] Player "..stData["Username"] or "[Unknown Username]".." (ID "..userID..")'s data from the DataStore is obtainable, but the recorded frames are missing or corrupted.")
				end
			else
				warn("[CFRECORD] Player ID "..userID.."'s data from the DataStore is empty.")
			end
		else
			warn("[CFRECORD] Couldn't get Player ID "..userID.."'s data from the DataStore because of error: "..tostring(stData))
		end
	end
end

function module.ChangeFPS(nFps:number)
	if tonumber(nFps) and nFps > 0 then
		print("[CFRECORD] Changed Record FPS from "..FPS.." to "..nFps..". Record processes made before this change is still going to be saved at it's previously set FPS.")
		FPS = nFps
	end
end

return module
