--[[

	Obby / Tower Management System
	License: MIT License (https://spdx.org/licenses/MIT)
	This Luau code is made by the following person:
	- wilsontulus5

--]]

local badgeSrv = game:GetService("BadgeService")
local players = game:GetService("Players")
local runSrv = game:GetService("RunService")
local srvStor = game:GetService("ServerStorage")
local ExpDetec = require(script.Parent:WaitForChild("ExploitDetection"))
local replicatedStorage = game:GetService("ReplicatedStorage"):WaitForChild("GameScripts")
local logErrorToPlayer = replicatedStorage:WaitForChild("LogErrorToClient")
local transitionMote = replicatedStorage:WaitForChild("TriggerTransitionScreen")
local towers = workspace:WaitForChild("Towers")
local apis = script.Parent
local dataPS = require(apis:WaitForChild("DatastorePS"))
local coinsEnabled = true
local coinsAPI = if coinsEnabled then require(script.Parent:WaitForChild("CoinsAPI")) else nil
local unixTime = require(replicatedStorage:WaitForChild("LocalAPI"):WaitForChild("UnixTime"))
local initialized = false
local checkpoints = {}
local userCheckpoints = { -- Lists last user checkpoint
	[1] = workspace:WaitForChild("LobbySpawns"):GetChildren()[math.random(1,3)]
}
local TowerMgr = {}
local characters = workspace:WaitForChild("Characters")
local lobbySpawn = workspace:WaitForChild("LobbySpawns")
local winnerSpawn = workspace:WaitForChild("Winners"):WaitForChild("Spawn")
local adminListModule = apis:WaitForChild("RankList")

local DebugMode = false


local Sampledata = { -- Datastore system assistance
	ID1 = false;
	ID2 = false;
	ID3 = false;
	ID4 = false;
	ID5 = false;
	ID6 = false;
	ID7 = false;
	ID8 = false;
	Wins = 0;
}

local towerFolders = { -- Store list of tower folders to simplify naming
	[1] = towers.Tower1_One;
	[2] = towers.Tower2_Two;
	[3] = towers.Tower3_Three;
	[4] = towers.Tower4_Four;
}

type TowerDataType = {
	Name : string;
	MinimumTime : number;
	AutokickMinimumTime : number;
	MinimumCoiledTime : number;
	BadgeID : number;
	Coins : number;
	WinPad : BasePart;
	Stages : any;
}


local TowerData = { -- Store list of tower data
	[1] = {
		Name = "One";
		MinimumTime = 60;
		AutokickMinimumTime = 50;
		MinimumCoiledTime = 10;
		BadgeID = 00000000000;
		Coins = 100;
		WinPad = towerFolders[1].WinPad;
		Stages = {
			[1] = {
				Name = "Northern";
				Part = towerFolders[1].One.Checkpoint1.CheckPoint.PartTrigger;	
			};
			[2] = {
				Name = "Southern";
				Part = towerFolders[1].One.Checkpoint2.CheckPoint.PartTrigger;	
			};
		}
	};
	
	
}

local loadedData = { -- Datastore system assistance
	[2] = {
		ID1 = false;
		ID2 = false;
		ID3 = false;
		ID4 = false;
		ID5 = false;
		ID6 = false;
		ID7 = false;
		ID8 = false;
		Wins = 0;
	};
}

local SampleAECheckPointsMetadata = {
	RegisteredPlayers = {
		[1] = true;
		[51] = false;
	};	-- User ID goes here
	TowerID = 0;
	Part = workspace.Baseplate; -- just a random part for sample, not going to be used
	OriginalPath = "workspace.Baseplate";
	ObfusPath = "workspace.Part.X";
}

local function studioprint(...)
	if runSrv:IsStudio() or DebugMode or script.studioprintOnServer.Value then
		print(...)
	end
end

local function debugwarn(...)
	if game.ServerScriptService:FindFirstChild("DebugMode") then
		warn(...)
	end
end

local function resetUserCheckpoint(userID, towerID)
	if tonumber(userID) then
		userCheckpoints[tonumber(userID)] = workspace:WaitForChild("LobbySpawns"):GetChildren()[math.random(1,3)]
		if tonumber(towerID) and TowerData[tonumber(towerID)] and towerFolders[tonumber(towerID)] then
			userCheckpoints[tonumber(userID)] = towerFolders[tonumber(towerID)].Spawn
		end
	end
end

local function obfuscatePartParent(part:BasePart, target:Folder)
	if part and part.Parent and part:IsA("BasePart") and target and (target:IsA("Folder") or target:IsA("Model")) then
		local oldParent = part.Parent
		local rng = Random.new()
		local descendant = target:GetDescendants()
		local attempts = 100
		repeat
			local eligibleDescendant = {}
			for _,v:Instance in ipairs(descendant) do
				if (v:IsA("Folder") or v:IsA("Model")) and #v:GetChildren() >= 3 and v ~= part and v ~= oldParent then -- Requires a folder or model with at least 3 instances in it to make it less suspicious to exploiters
					table.insert(eligibleDescendant, v)
				end
			end
			if #eligibleDescendant >= 2 then
				part.Parent = eligibleDescendant[rng:NextInteger(1, #eligibleDescendant)]
				return true
			end
			attempts -= 1
			task.wait(0.1)
		until (part.Parent and part.Parent ~= oldParent) or attempts < 1 or not oldParent 
	end
	return false
end


local function formatTime(timeVal)
	local hours = math.floor(math.fmod(timeVal, 86400)/3600)
	local minutes = math.floor(math.fmod(timeVal,3600)/60)
	local seconds = math.fmod(timeVal,60)
	return string.format("%d:%02d:%05.2f", hours, minutes, seconds)
end

local function checkLegit(plr:Player, toweID: number, AECheckPointsMetadata)
	print("Checking legitimacy for player "..plr.Name.." in tower ID "..toweID)
	local plrVal = plr:WaitForChild("PlayerValue")
	local SpawednTimer = tonumber(plrVal:WaitForChild("CurrentStepSpawnTime").Value)
	local BeatenWCoils = (( plrVal:WaitForChild("BeatenWithGC").Value or plr.Character:FindFirstChild("GravityCoil")) or (plrVal:WaitForChild("BeatenWithSC").Value or plr.Character:FindFirstChild("SpeedCoil")) or (plrVal:WaitForChild("BeatenWithFC").Value or plr.Character:FindFirstChild("FusionCoil")))
	local RemTime = os.time() - SpawednTimer
	local RemTimeOSD = os.date("!*t",RemTime)
	if BeatenWCoils then
		if RemTime >= TowerData[toweID].MinimumCoiledTime then
			return true
		else
			return false, "Finished too fast! in "..RemTimeOSD.hour.." hours, "..RemTimeOSD.min.." minutes, and "..RemTimeOSD.sec.." seconds, even with coils", "Finished too fast in "..RemTime.." seconds, but expected "..TowerData[toweID].MinimumCoiledTime..", coils are used but still too fast"
		end
	else
		if RemTime >= TowerData[toweID].MinimumTime then

			local Legit, MissedPart, MissedPartPath = false, nil, nil
			if AECheckPointsMetadata and typeof(AECheckPointsMetadata) == "table" then
				local AECCounts = 0
				local AECMissCounts = 0
				for t,AECName in pairs(AECheckPointsMetadata) do
					if AECName["RegisteredPlayers"] and AECName["TowerID"] and AECName.TowerID == toweID then
						AECCounts += 1
						local rgp = AECName["RegisteredPlayers"]
						local raecPart = AECName["Part"]
						if (rgp and raecPart and (rgp[plr.UserId] or rgp[tostring(plr.UserId)] or rgp[tonumber(plr.UserId)])) or not (rgp and raecPart and typeof(raecPart) == "Instance" and raecPart:FindFirstChildWhichIsA("TouchTransmitter")) then
							Legit = true
							continue
						else
							AECMissCounts += 1
							if AECMissCounts > 2 then
								Legit = false 
								MissedPart = AECName["Part"]
								MissedPartPath = "ORG: "..AECName["OriginalPath"].." - OBF: "..AECName["ObfusPath"]
								if (AECName["ObfusPath"] and #tostring(AECName["ObfusPath"]) < 10) or not AECName["ObfusPath"] then
									Legit = true
									continue
								end
								
								-- AEC Taint + 1
								
								plrVal:WaitForChild("AECTaint").Value += 1
								if plrVal:WaitForChild("AECTaint").Value >= 3 and (os.time() - plrVal:WaitForChild("AECTaint"):WaitForChild("LastTime").Value) < 600 then
									plr.Character:FindFirstChildWhichIsA("Humanoid"):TakeDamage(math.huge)
									ExpDetec.KickPlr(plr, "Finished Tower: "..TowerData[toweID].Name..", but missed parts more than 3 times", "Exceeded threshold of 3 attempts.")
									return false, "cancel", "cancel"
								end
								plrVal:WaitForChild("AECTaint"):WaitForChild("LastTime").Value = os.time()
								
								return false, "You did not travel through the tower properly", if MissedPart then "Missed part at coordinate: "..MissedPart.Position.X..", "..MissedPart.Position.Y..", "..MissedPart.Position.Z.." - info:"..tostring(MissedPartPath) else "Missed an unknown part [BUG FIX NEEDED]"
							else
								Legit = true
								warn(plr.Name.." - Less than 3 missed part detected. ","ORG: "..AECName["OriginalPath"].." - OBF: "..AECName["ObfusPath"])
								continue
							end

						end
					end
				end
				if AECCounts < 1 then	-- metadata exist but nothing inside metadata? skip it instead of causing damage.
					warn("Tower ID "..toweID.." has an empty AECheckpoints system! Proceeding to winner anyway. Meta:",AECheckPointsMetadata)
					Legit = true MissedPart = false
				end

				if MissedPart or not Legit then
					warn("[TowerManager_CheckLegit] Player "..plr.Name.." did not travel through the Tower ID "..toweID.." properly. Missed part is at:",if MissedPart then "Missed part at coordinate: "..MissedPart.Position.X..", "..MissedPart.Position.Y..", "..MissedPart.Position.Z.." - info:"..tostring(MissedPartPath) else "Missed an unknown part [BUG FIX NEEDED]"," located in explorer at: ",MissedPartPath)
					--[[
					plrVal:WaitForChild("AECTaint").Value += 1
					if plrVal:WaitForChild("AECTaint").Value >= 3 and (os.time() - plrVal:WaitForChild("AECTaint"):WaitForChild("LastTime").Value) < 600 then
						plr.Character:FindFirstChildWhichIsA("Humanoid"):TakeDamage(math.huge)
						ExpDetec.KickPlr(plr, "Finished Tower: "..TowerData[toweID].Name..", but missed parts more than 3 times", "Exceeded threshold of 3 attempts.")
						return false, "cancel", "cancel"
					end
					plrVal:WaitForChild("AECTaint"):WaitForChild("LastTime").Value = os.time()
					--]]
					return false, "You did not travel through the tower properly", if MissedPart then "Missed part at coordinate: "..MissedPart.Position.X..", "..MissedPart.Position.Y..", "..MissedPart.Position.Z.." - info:"..tostring(MissedPartPath) else "Missed an unknown part [BUG FIX NEEDED]"
				end
			else
				warn("Tower ID "..toweID.." does not contain AECheckpoints system! Proceeding to winner anyway. Meta:",AECheckPointsMetadata)
				Legit = true
			end
			return Legit, Legit, Legit
		else
			return false, "Finished too fast in "..RemTimeOSD.hour.." hours, "..RemTimeOSD.min.." minutes, and "..RemTimeOSD.sec.." seconds", "Finished in "..RemTime.." seconds, expected "..TowerData[toweID].MinimumTime
		end
	end



end

local function giveCompletedAllTowers(player:Player)
	if player then
		local gcS, gcF = pcall(function()
			return badgeSrv:AwardBadge(player.UserId, 2153334873)
		end)
		if not gcS then
			warn("[TowerManager] Error Giving AllTowersCompleted Badge to Player "..player.Name.." UID "..player.Us)
		end
	end
	return true
end


function TowerMgr.Set(player:Player, cat:string, amount)
	if player and cat ~= nil and amount ~= nil then
		dataPS.SetTowerData(player, cat, amount)
	end
end

function TowerMgr.SetByNewMethod(player:Player)
	if player and loadedData[player.UserId] then
		for al, vl in pairs (loadedData[player.UserId]) do
			dataPS.SetTowerData(player, al, vl)
		end
	elseif player and not loadedData[player.UserId] then
		warn("[TowerManager] Invalid player data load! Reloading..")
		local op1, op2 = pcall(function()
			local s = dataPS.GiveTowerData(player, true) print("[TowerManager] Tower data is loaded: ",tostring(s))
			local sWins = dataPS.GiveTowerWinsData(player, true) print("[TowerManager] Tower Wins data is loaded: ",tostring(sWins))
			loadedData[player.UserId] = Sampledata
			loadedData[player.UserId].TowerWins = sWins
			for dataIndex, dataValue in pairs (s) do
				loadedData[player.UserId][dataIndex] = dataValue
			end
		end)
		if op1 then
			print("[TowerManager] Reloading success.")
			for al, vl in pairs (loadedData[player.UserId]) do
				dataPS.SetTowerData(player, al, vl)
			end
		else
			warn("[TowerManager] Reloading player data fail! Reason: "..tostring(op2))
			return false, op2
		end
	end
	if player:FindFirstChild("leaderstats") and player:FindFirstChild("leaderstats"):FindFirstChild("Wins") then
		dataPS.SetGlobalTowerWinsData(player, player:FindFirstChild("leaderstats"):FindFirstChild("Wins").Value)
	end
	return true
end


function TowerMgr.Load(player:Player)
	if player ~= nil then
		if loadedData[player.UserId] then
			warn("[TowerManager] LoadedData for UID "..player.UserId.." still exists while Load is called! Removing.")
			loadedData[player.UserId] = nil
		end
		print("[TowerManager] Attempt to Read tower data for "..player.Name.." (ID "..player.UserId..")")
		local successLoadTowerData = dataPS.GiveTowerData(player, true) print("[TowerManager] Tower data is loaded: ",tostring(successLoadTowerData))
		print("[TowerManager] Fetching Tower Wins Data for player "..player.UserId)
		local sWins = dataPS.GiveTowerWinsData(player, true) print("[TowerManager] Tower Wins data is loaded: ",tostring(sWins))
		studioprint("[TowerManager] LoadedData for "..player.UserId.." is: "..tostring(loadedData[player.UserId]))
		loadedData[player.UserId] = Sampledata
		studioprint("[TowerManager] LoadedData for "..player.UserId.." is: "..tostring(loadedData[player.UserId]))
		local DataPlr = loadedData[player.UserId]
		DataPlr.TowerWins = sWins
		studioprint("[TowerManager] LoadedData for "..player.UserId.." is: "..tostring(loadedData[player.UserId]))
		local pTowersBeaten = player:WaitForChild("PlayerValue"):WaitForChild("TowersBeaten")
		local pWinCounts = player:WaitForChild("leaderstats"):WaitForChild("Wins")
		studioprint("[TowerManager] LoadedData for "..player.UserId.." is: "..tostring(loadedData[player.UserId]))
		if successLoadTowerData then
			for dataIndex, dataValue in pairs (successLoadTowerData) do
				DataPlr[dataIndex] = dataValue
			end
			for _,jk in pairs (pTowersBeaten:GetChildren()) do
				if jk:IsA("BoolValue") then
					local rTWID = string.split(jk.Name, "Tower")[2]
					jk.Value = DataPlr["ID"..rTWID]
				end
			end
			pWinCounts.Value = tonumber(sWins)
		else
			for _,jk in pairs (pTowersBeaten:GetChildren()) do
				if jk:IsA("BoolValue") then
					jk.Value = false
				end
			end
			pWinCounts.Value = tonumber(sWins) or 0
		end
		studioprint("[TowerManager] LoadedData "..player.UserId.." status is :" ..tostring(loadedData[player.UserId]))
		resetUserCheckpoint(player.UserId)
	else warn("[TowerManager] Player is nil while loading tower data")
	end
end

function TowerMgr.SRTimer(player: Player)
	local srt = player:WaitForChild("PlayerValue"):WaitForChild("CurrentSRTimer")
	local d,h,m,s,ms = 0, 0, 0, 0, 00

	if d < 1 and h < 1 then
		srt.Value = m
	end
end

function TowerMgr.Init()
	
	if initialized == true then return end
	for i,v in pairs (workspace:WaitForChild("Towers"):GetChildren()) do
		if v:IsA("Folder") and v:FindFirstChild("TowerID") then
			local twid = v:FindFirstChild("TowerID")
			local spwn = v:FindFirstChild("Spawn")
			local AECheckpoints = v:FindFirstChild("AECheckpoints")
			local AECheckPointsMetadata = {}
			local tdata = TowerData[twid.Value]
			local winpad = tdata.WinPad or v:FindFirstChild("WinPad")
			local debounceList = {}
			print("Initializing Tower: "..TowerData[twid.Value].Name.." (ID "..twid.Value..")")
		--	towerFolders[tonumber(twid.Value)] = v
			print("Tower folder: "..tostring(towerFolders[twid.Value])..", call: towerFolders["..tostring(twid.Value).."]")
			local spwncool = {}
			for i,v in pairs(tdata.Stages) do
				if v.Part then
					v.Part.Touched:Connect(function(part:BasePart)
						local success1, charplayer = pcall(function()
							return players:GetPlayerFromCharacter(part.Parent)
						end) 
						if success1 and charplayer and charplayer:DistanceFromCharacter(v.Part.Position) < 60 then
							if part.Parent and part.Parent:FindFirstChildWhichIsA("Humanoid") and part.Parent:FindFirstChildWhichIsA("Humanoid").Health > 0 and charplayer then
								local char = part.Parent
								local plrVal = charplayer:WaitForChild("PlayerValue")
								if plrVal.CurrentTowerID.Value == twid.Value and (plrVal.LatestCheckpoint.Value + 1) == i then
									plrVal.CurrentCheckpoint.Value = i
									plrVal.LatestCheckpoint.Value = i
									if char:FindFirstChild("GravityCoil") then
										plrVal.BeatenWithGC.Value = true
									end
									if char:FindFirstChild("SpeedCoil") then
										plrVal.BeatenWithSC.Value = true
									end
									if char:FindFirstChild("FusionCoil") then
										plrVal.BeatenWithFC.Value = true
									end
									userCheckpoints[charplayer.UserId] = v.Part
								end
							end
						end
					end)
				end
			end
			spwn.Transparency = 1
			
			spwn.Touched:Connect(function(part)
				local su1, player = pcall(function()
					return players:GetPlayerFromCharacter(part.Parent)
				end) 
				if su1 then
					if part.Parent and part.Parent:FindFirstChildWhichIsA("Humanoid") and player then
						debounceList[player.UserId] = nil
						
					--[[ Moved to EnterTower
					
						local char = part.Parent
						if spwncool[player.UserId]  then return end
						spwncool[player.UserId] = true
						local plrVal = player:WaitForChild("PlayerValue")
						plrVal.CurrentTowerID.Value = twid.Value
						plrVal.CurrentTowerTimer.Value = 0
						plrVal.CurrentStepSpawnTime.Value = os.time()
						if char:FindFirstChild("GravityCoil") then
							plrVal.BeatenWithGC.Value = true
						end
						if char:FindFirstChild("SpeedCoil") then
							plrVal.BeatenWithSC.Value = true
						end
						task.wait(.5)
						spwncool[player.UserId] = nil
						
					]]
						
					end
				end
			end)
			
			
			if AECheckpoints then
				print("[TowerManager] AECheckpoints found for tower ID "..twid.Value..", initializing AECs...")
				for _,AEC in ipairs(AECheckpoints:GetChildren()) do
					if AEC:IsA("BasePart") then
						task.spawn(function()
							AEC.CanCollide = false
							AEC.Anchored = true
							AEC.CanTouch = true
							AEC.CanQuery = false
							AEC.Locked = true
							AEC.Transparency = 1
							if AECheckPointsMetadata[AEC.Name] then
								local attemptK = 0
								repeat
									AEC.Name = "AE"..Random.new():NextInteger(1,33554430)
									AEC.Name = "AE"..math.random(1,33554430)
									attemptK += 1
								until not AECheckPointsMetadata[AEC.Name] or attemptK > 10
								if attemptK > 10 then
									return
								end
							end
							local oldAECName = AEC.Name
							AECheckPointsMetadata[oldAECName] = {
								RegisteredPlayers = {};	-- User ID goes here
								TowerID = twid.Value;
								Part = AEC;
								OriginalPath = AEC:GetFullName();
								ObfusPath = "";
							}
							local rng = Random.new()
							local cooldownPlayers = {}
							pcall(function()	-- Risky part manipulation but enough to tackle off some exploiters using fixed calculations
								AEC.Color = Color3.new(rng:NextNumber(0,1),rng:NextNumber(0,1),rng:NextNumber(0,1))
								AEC.Size = AEC.Size + Vector3.new(rng:NextNumber(0.1,2),rng:NextNumber(0.1,2),rng:NextNumber(0.1,2))
								AEC.Position = AEC.Position + Vector3.new(rng:NextNumber(0.1,0.5),rng:NextNumber(0.1,0.5),rng:NextNumber(0.1,0.5))
								local isAECParentObfuscated = obfuscatePartParent(AEC, v)
								if not isAECParentObfuscated then
									AEC.Parent = v:FindFirstChild("TopRunnersPodium") or v:FindFirstChild("Frame") or v:FindFirstChild("AECheckpoints") or v
								end
							end)
							AEC.Touched:Connect(function(part:BasePart)
								if part.Parent and part.Parent:FindFirstChildWhichIsA("Humanoid") then
									studioprint("[TowerManager] AEC is pressed at ",AECheckPointsMetadata[oldAECName].OriginalPath,"by "..part.Parent.Name)
									local humanoid = part.Parent:FindFirstChildWhichIsA("Humanoid")
									local player = players:GetPlayerFromCharacter(part.Parent)
									if player and player:WaitForChild("PlayerValue").CurrentTowerID.Value == twid.Value and player:DistanceFromCharacter(AEC.Position) < 50 and not cooldownPlayers[player.UserId] then
										AECheckPointsMetadata[oldAECName].RegisteredPlayers[player.UserId] = true
										cooldownPlayers[player.UserId] = true
										task.wait(1.4)
										cooldownPlayers[player.UserId] = nil
									end
								end
							end)
							AEC.TouchEnded:Connect(function(part:BasePart)
								if part.Parent and part.Parent:FindFirstChildWhichIsA("Humanoid") then
									studioprint("[TowerManager] AEC is unpressed at ",AECheckPointsMetadata[oldAECName].OriginalPath,"by "..part.Parent.Name)
									local humanoid = part.Parent:FindFirstChildWhichIsA("Humanoid")
									local player = players:GetPlayerFromCharacter(part.Parent)
									if player and player:WaitForChild("PlayerValue").CurrentTowerID.Value == twid.Value and player:DistanceFromCharacter(AEC.Position) < 50 and not cooldownPlayers[player.UserId] then
										AECheckPointsMetadata[oldAECName].RegisteredPlayers[player.UserId] = true
										cooldownPlayers[player.UserId] = true
										task.wait(1.4)
										cooldownPlayers[player.UserId] = nil
									end
								end
							end)
							AECheckPointsMetadata[oldAECName].ObfusPath = AEC:GetFullName()
							print("[TowerManager] Initialized AEC at: ",if AECheckPointsMetadata[oldAECName] and AECheckPointsMetadata[oldAECName].OriginalPath then AECheckPointsMetadata[oldAECName].OriginalPath else nil)
						end)
					end
				end
				print("[TowerManager] Finished initializing AECheckpoints for tower ID "..twid.Value..", contains:",AECheckPointsMetadata)
			end
			
			if winpad then
				winpad.CanTouch = true
				winpad.CanQuery = true
				winpad.Touched:Connect(function(part)
					local playerD = if part and part.Parent then players:GetPlayerFromCharacter(part.Parent) else nil
					if part.Parent and part.Parent:FindFirstChildWhichIsA("Humanoid") and players:GetPlayerFromCharacter(part.Parent):WaitForChild("PlayerValue").CurrentTowerID.Value == twid.Value and not debounceList[players:GetPlayerFromCharacter(part.Parent).UserId] then
						local player = players:GetPlayerFromCharacter(part.Parent)
						local Success, ISError = pcall(function()
							local char = player.Character
							local hum = char:FindFirstChildWhichIsA("Humanoid")
							local charRoot = char.PrimaryPart
							debounceList[player.UserId] = true
							local plrVal = player:WaitForChild("PlayerValue")
							local plrWinCount = player:WaitForChild("leaderstats"):WaitForChild("Wins")
							local LatestCheckpoint = plrVal:WaitForChild("LatestCheckpoint",1)
							local SpawednTimer = tonumber(plrVal:WaitForChild("CurrentStepSpawnTime").Value)
							local tower = towerFolders[twid.Value]
							local RemTime = os.time() - SpawednTimer
							local RemTimeOSD = os.date("!*t",RemTime)
							local ptoolinf = "no boost items"
							local BeatWithGravC = plrVal:WaitForChild("BeatenWithGC").Value or part.Parent:FindFirstChild("GravityCoil")
							local BeatWithSpeedC = plrVal:WaitForChild("BeatenWithSC").Value or part.Parent:FindFirstChild("SpeedCoil")
							local BeatWithFusionC = plrVal:WaitForChild("BeatenWithFC").Value or part.Parent:FindFirstChild("FusionCoil")
							if BeatWithGravC and BeatWithSpeedC then
								ptoolinf = "Gravity Coil and Speed Coil"
							elseif BeatWithGravC then
								ptoolinf = "Gravity Coil"
							elseif BeatWithSpeedC then
								ptoolinf = "Speed Coil"
							elseif BeatWithFusionC then
								ptoolinf = "Fusion Coil"
							end
							if not (LatestCheckpoint and LatestCheckpoint.Value) then return false end
							if LatestCheckpoint.Value ~= #TowerData[twid.Value].Stages then return false end
							local success, emsg, dtemsg = checkLegit(player, twid.Value, AECheckPointsMetadata)
							if success then
								print("Player "..player.Name.." passed checkLegit tests. Proceeding to winner room.")
								transitionMote:FireClient(player, "Teleporting to Winners Room...", 3) task.wait(1)
								userCheckpoints[player.UserId] = nil
								plrVal:WaitForChild("TowersBeaten"):WaitForChild("Tower"..twid.Value).Value = true
								pcall(function() char:MoveTo(winnerSpawn.Position + Vector3.new(0,5,0)) task.wait(1) end)

								charRoot.CFrame = winnerSpawn.CFrame + Vector3.new(0,5,0)
								winnerSpawn.Sound:Play()
								local si,mi = pcall(function()
									badgeSrv:AwardBadge(player.UserId, TowerData[twid.Value].BadgeID)
								end)
								if not si then
									warn("[TowerManager] Error giving badge from Tower ID "..twid.Value.." for Player "..player.Name..". Reason: "..mi)
								end
								local beaten = 0
								for _,lo in pairs (plrVal.TowersBeaten:GetChildren()) do
									if lo.Value then
										beaten += 1
									end
								end
								if beaten >= 7 then
									local sia,mia = pcall(function()
										return giveCompletedAllTowers(player)
									end)
									if not sia then
										warn("[TowerManager] Error giving Completed All Towers Badge for Player "..player.Name..". Reason: "..mi)
									end
								end
								plrWinCount.Value += 1
								-- Reset

								plrVal:WaitForChild("CurrentTowerID").Value = 1000000	-- 1000000 is the "winner room" as tower ID
								plrVal:WaitForChild("CurrentTowerTimer").Value = 0
								plrVal:WaitForChild("CurrentCheckpoint").Value = 0
								plrVal:WaitForChild("LatestCheckpoint").Value = 0
								plrVal:WaitForChild("BeatenWithGC").Value = false
								plrVal:WaitForChild("BeatenWithSC").Value = false
								plrVal:WaitForChild("BeatenWithFC").Value = false
								resetUserCheckpoint(player.UserId)
								if coinsEnabled then
									coinsAPI.Modify(player, TowerData[twid.Value].Coins)
								end
								replicatedStorage:WaitForChild("DonationAnno"):FireAllClients(player.DisplayName.." has beaten "..TowerData[twid.Value].Name.." Tower in "..string.format("%0.2i", RemTimeOSD.hour).."h:"..string.format("%0.2i", RemTimeOSD.min).."m:"..string.format("%0.2i", RemTimeOSD.sec).."s with "..ptoolinf.."!",Color3.fromRGB(150,240,150))


								task.wait(1)
								if player:DistanceFromCharacter(workspace:WaitForChild("Winners"):WaitForChild("Spawn").Position) > 30 then
									charRoot.CFrame = winnerSpawn.CFrame + Vector3.new(0,5,0)
									winnerSpawn.Sound:Play()
									if characters:FindFirstChild(player.Name) then
										characters:FindFirstChild(player.Name):WaitForChild("Head").CFrame = workspace:WaitForChild("Winners"):WaitForChild("altSpawn").CFrame
										characters:FindFirstChild(player.Name):MoveTo(workspace:WaitForChild("Winners"):WaitForChild("altSpawn").Position)
									end
								end
								if loadedData[player.UserId] then
									local charplrData = loadedData[player.UserId]
									charplrData["ID"..twid.Value] = true
									charplrData["TowerWins"] += 1
									print("[TowerManager] Saving player data")
									TowerMgr.SetByNewMethod(player)
								else
									warn("[TowerManager] Player is winning, but their data is not loaded! Attempting reload...")
									studioprint("[TowerManager] LoadedData "..player.UserId.." status is :" ..tostring(loadedData[player.UserId]))
									local op1, op2 = pcall(function()
										local s = dataPS.GiveTowerData(player, true) print("[TowerManager] Tower data is loaded: ",tostring(s))
										local sWins = dataPS.GiveTowerWinsData(player, true) print("[TowerManager] Tower Wins data is loaded: ",tostring(sWins))
										loadedData[player.UserId] = Sampledata
										loadedData[player.UserId].TowerWins = sWins
										for dataIndex, dataValue in pairs (s) do
											loadedData[player.UserId][dataIndex] = dataValue
										end
									end)
									if op1 then
										print("[TowerManager] Reloading success.")
										loadedData[player.UserId]["ID"..twid.Value] = true
										loadedData[player.UserId]["TowerWins"] += 1
										print("[TowerManager] Saving player data")
										local pd, pd1 = pcall(function()
											return TowerMgr.SetByNewMethod(player)
										end)
										if pd then
											print("[TowerManager] Saving success.")
										else
											warn("[TowerManager] Saving failed: "..tostring(pd1))
										end
									else
										warn("[TowerManager] Reloading player data fail! Reason: "..tostring(op2))
									end
								end
								if TowerData[twid.Value].WinFunction then
									TowerData[twid.Value].WinFunction(player)
								end
								local evtcS, evtcE = pcall(function()
									if tower:FindFirstChild("TopRunnersPodium") and tower:FindFirstChild("WinningEvent") and not string.find(ptoolinf, "Coil") then
										local evtc = tower:FindFirstChild("WinningEvent")
										if evtc then
											evtc:Fire(player, RemTime)
										end
									end
								end)

								userCheckpoints[player.UserId] = nil
								debounceList[player.UserId] = nil
							else
								if string.find(string.lower(emsg), "travel through") or emsg == "You did not travel through the tower properly" then
									player.Character:FindFirstChildWhichIsA("Humanoid"):TakeDamage(math.huge)
									replicatedStorage:WaitForChild("DonationAnno"):FireClient(player,"You didn't travel through the "..TowerData[twid.Value].Name.." Tower properly. Try again, and if you think it's false please contact the developers with video proof of beating the tower.",Color3.fromRGB(240,50,50))
									warn("Player "..player.Name.." didn't pass an AECheckpoint! Details:", dtemsg)
								elseif RemTime > TowerData[twid.Value].AutokickMinimumTime then
									player.Character:FindFirstChildWhichIsA("Humanoid"):TakeDamage(math.huge)
									replicatedStorage:WaitForChild("DonationAnno"):FireClient(player,"The time of you beating "..TowerData[twid.Value].Name.." Tower in "..string.format("%0.2i", RemTimeOSD.hour).."h:"..string.format("%0.2i", RemTimeOSD.min).."m:"..string.format("%0.2i", RemTimeOSD.sec).."s with "..ptoolinf.." is invalid. If you think it's false please contact the developers with video proof of beating the tower.",Color3.fromRGB(240,50,50))
								elseif string.format(string.lower(emsg), "cancel") or emsg == "cancel" then
									
								else
									--	warn(player.Name.." (ID "..player.UserId..") tried to finish Tower ID "..twid.Value.." while their CTID is "..plrVal.CurrentTowerID.Value.."!")
									player.Character:FindFirstChildWhichIsA("Humanoid"):TakeDamage(math.huge)
									ExpDetec.KickPlr(player, "Finished Tower: "..TowerData[twid.Value].Name..", but "..emsg, dtemsg)
								end

								local plrVal = player:WaitForChild("PlayerValue")
								plrVal:WaitForChild("CurrentStepSpawnTime").Value = 0
								plrVal:WaitForChild("CurrentTowerID").Value = 0
								plrVal:WaitForChild("CurrentTowerTimer").Value = 0
								plrVal:WaitForChild("CurrentCheckpoint").Value = 0
								plrVal:WaitForChild("LatestCheckpoint").Value = 0
								plrVal:WaitForChild("BeatenWithGC").Value = false
								plrVal:WaitForChild("BeatenWithSC").Value = false
								plrVal:WaitForChild("BeatenWithFC").Value = false
								resetUserCheckpoint(player.UserId)
								task.wait(1)
								debounceList[player.UserId] = nil
							end
						end)
						if not Success then
							logErrorToPlayer:FireClient(player, tostring(ISError))
						end

						userCheckpoints[player.UserId] = nil
						debounceList[player.UserId] = nil
					elseif playerD and debounceList[playerD.UserId] then
						debugwarn("[TowerMgr] Player "..playerD.Name.." is in cooldown for touching winpad")
					elseif playerD then
						debugwarn("[TowerMgr] Player "..playerD.Name.." has invalid character for touching winpad")
						
					end
				end)
			else
				warn("WinPad for Tower ID "..twid.Value.." is missing!")
			end
			print("Finished Initializing Tower: "..TowerData[twid.Value].Name.." (ID "..twid.Value..")")
		end
	end
	local rtlCold = false
	initialized = true
end

function TowerMgr.InstallPlayer(player)--[[
	repeat task.wait(.05) until initialized
	if loadedData[player.UserId] then
		loadedData[player.UserId] = nil
	end
	for i,v in pairs (checkpoints) do
		spawn(function()
			v.Touched:Connect(function(touch)
				local stage = i
				if touch.Parent:FindFirstChildWhichIsA("Humanoid") then
					local hum = touch.Parent:FindFirstChild("Humanoid")
					-- If a part in a model touches the part, touch = that part not the model
					if hum and hum.Health > 0 then
						-- The thing that touched the checkpoint is alive
						local player = game:GetService("Players"):GetPlayerFromCharacter(touch.Parent)
						-- This allows us to find a player with their character (it's very useful)
						if player then
							-- Whatever touched the checkpoint is a player
							cp.Set(player,stage)
						end
					end
				end
			end)
		end)
	end]]
	warn("[TowerManager] InstallPlayer is deprecated, use Load instead")
	TowerMgr.Load(player)
end

function TowerMgr.RemovingPlayer(player)

	resetUserCheckpoint(player.UserId)
	
end

function TowerMgr.New(towerID:number, newtowerData: TowerDataType)
	assert(tonumber(towerID), "Tower ID is invalid or not specified")
	assert(not TowerData[tonumber(towerID)], "Tower ID is already used")
	if towerID and tonumber(towerID) and newtowerData and not TowerData[tonumber(towerID)] then
		TowerData[tonumber(towerID)] = newtowerData
	end 
end

function TowerMgr:ResetPlayer(player:Player)
	local plrVal = player:WaitForChild("PlayerValue")
	plrVal:WaitForChild("CurrentStepSpawnTime").Value = 0
	plrVal:WaitForChild("CurrentTowerID").Value = 0
	plrVal:WaitForChild("CurrentTowerTimer").Value = 0
	plrVal:WaitForChild("CurrentCheckpoint").Value = 0
	plrVal:WaitForChild("LatestCheckpoint").Value = 0
	plrVal:WaitForChild("BeatenWithGC").Value = false
	plrVal:WaitForChild("BeatenWithSC").Value = false
	plrVal:WaitForChild("BeatenWithFC").Value = false
	resetUserCheckpoint(player.UserId)
end

function TowerMgr:ResetRun(player: Player)
	local plrVal = player:WaitForChild("PlayerValue")
	if plrVal:WaitForChild("CurrentTowerID").Value > 0 then
		plrVal:WaitForChild("CurrentStepSpawnTime").Value = os.time()
		plrVal:WaitForChild("CurrentTowerTimer").Value = 0
		plrVal:WaitForChild("CurrentCheckpoint").Value = 1
		plrVal:WaitForChild("LatestCheckpoint").Value = 1
		plrVal:WaitForChild("BeatenWithGC").Value = false
		plrVal:WaitForChild("BeatenWithSC").Value = false
		plrVal:WaitForChild("BeatenWithFC").Value = false
		resetUserCheckpoint(player.UserId, plrVal:WaitForChild("CurrentTowerID").Value)
		if player and player.Character and player.Character.PrimaryPart then
			player.Character:MoveTo(towerFolders[tonumber(plrVal:WaitForChild("CurrentTowerID").Value)].Spawn.Position)
		end
	end
end

function TowerMgr:EnterTower(player: Player, id: number, openIfClosed: boolean)
	local twd = TowerData[tonumber(id)]
	local twf = towerFolders[tonumber(id)]
	local char = player.Character
	local plrVal = player:WaitForChild("PlayerValue")
	local warnMessage = nil
	if openIfClosed and (twf:FindFirstChild("Closed") and twf.Closed.Value) then
		twf.Closed.Value = false
	end
	if player and char and twd and twf and twf:FindFirstChild("Spawn") and not (twf:FindFirstChild("Closed") and twf.Closed.Value) then
		local hum = char:FindFirstChildWhichIsA("Humanoid")
		local charRoot = char.PrimaryPart
		if hum and hum.Health > 0 and charRoot then
			print("[TowerMgr] Player "..player.Name.." entered Tower ID "..id)
			plrVal:WaitForChild("CurrentCheckpoint").Value = 1
			plrVal:WaitForChild("LatestCheckpoint").Value = 1
			plrVal.CurrentTowerID.Value = id
			plrVal.CurrentTowerTimer.Value = 0
			plrVal.CurrentStepSpawnTime.Value = os.time()
			if char:FindFirstChild("GravityCoil") then
				plrVal.BeatenWithGC.Value = true
			end
			if char:FindFirstChild("SpeedCoil") then
				plrVal.BeatenWithSC.Value = true
			end
			if char:FindFirstChild("FusionCoil") then
				plrVal.BeatenWithFC.Value = true
			end
			transitionMote:FireClient(player, "Teleporting to "..twd.Name.." Tower...", 3) task.wait(1)
			userCheckpoints[player.UserId] = twf:WaitForChild("Spawn")
			charRoot.Anchored = true
			pcall(function() char:MoveTo(twf:WaitForChild("Spawn").Position + Vector3.new(0,1,0)) end)
			char:SetPrimaryPartCFrame(twf:WaitForChild("Spawn").CFrame)
			task.wait(.5)
			charRoot.Anchored = false
			return true
		else
			warnMessage = "[TowerMgr] Player "..player.Name.." didn't have a valid Humanoid"
		end
		
		--// Pardon me for spamming elseifs here but it's for purpose of detailed debugging...
		
	elseif not twd then	
		warnMessage = "[TowerMgr] Tower ID "..id.." is not found in TowerData"
	elseif not twf then
		warnMessage = "[TowerMgr] Tower ID "..id.." is not found in TowersFolder. Found: "..tostring(twf)
	elseif not char then
		warnMessage = "[TowerMgr] Tower ID "..id.." is valid but player "..player.Name.." didn't have a valid Character"
	elseif (twf:FindFirstChild("Closed") and twf.Closed.Value) then
		warnMessage = "[TowerMgr] Tower ID "..id.." is currently closed!"
	elseif not twf:FindFirstChild("Spawn") then
		warnMessage = "[TowerMgr] Tower ID "..id.." have their spawnpoint missing!"
	else
		warnMessage = "[TowerMgr] Tower ID "..id.." encountered an unknown error. Triggered by: "..player.Name
	end
	if warnMessage then
		warn(warnMessage)
		return false,warnMessage
	end
end

function TowerMgr:GetTowerFolderFromID(id:number)	
	local twd = TowerData[tonumber(id)]
	local twf = towerFolders[tonumber(id)]
	if twd and twf and twf:FindFirstChild("Spawn") then
		return twf
	elseif not twd then
		warn("[TowerMgr] Tower ID "..id.." is not found in TowerData")
	elseif not twf then
		warn("[TowerMgr] Tower ID "..id.." is not found in TowersFolder. Found: "..tostring(twf))
	end
end

function TowerMgr:SetCheckpoint(player, id, pos)
	local twd = TowerData[id]
	local twf = towerFolders[id]
	local char = player.Character
	local plrVal = player:WaitForChild("PlayerValue")
	if player and char and twd and twf and twf:FindFirstChild("Spawn") then
		local hum = char:FindFirstChildWhichIsA("Humanoid")
		local charRoot = char.PrimaryPart
		if hum and hum.Health > 0 and charRoot then
			
		end
	end
end

function TowerMgr:EnterLobby(player:Player)
	local char = player.Character
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	local charRoot = char.PrimaryPart or char:FindFirstChild("HumanoidRootPart")
	local choosenSpawnPart = lobbySpawn:GetChildren()[math.random(1,3)]
	if hum and hum.Health > 0 and charRoot then
		transitionMote:FireClient(player, "Teleporting to Lobby...", 1.8) task.wait(1)
		pcall(function() char:MoveTo(choosenSpawnPart.Position + Vector3.new(0,5,0)) end)
		task.wait(.5)
		charRoot.CFrame = choosenSpawnPart.CFrame + Vector3.new(0,5,0)
		TowerMgr:ResetPlayer(player)
	end
end

function TowerMgr:FinishTower(player, id)
	local twid = {
		Value = id or 0	-- Backwards compatibility
	}
	error("[TowerManager] FinishTower function is removed because Datastore is broken through this function, use WinPad instead.")
	
end

function TowerMgr.GetTowerFolders()
	return towerFolders
end

function TowerMgr.GetTowerData()
	return TowerData
end

local checkPointDebounceList = {}
function TowerMgr:CheckpointNavigate(player:Player, action:string)
	local stringtonum = {
		["Left"] = 1;
		["Right"] = 2;
		["End"] = 3;
		["Latest"] = 4;
	}
	local action = action
	if typeof(action) == "string" then
		action = stringtonum[action]
	end
	local adminList = require(adminListModule).GetAdmins()
	local enumeration = {
		[0] = "Start";
		[1] = "Previous";
		[2] = "Next";
		[3] = "End";
		[4] = "Latest";
	}
	local plrVal = player:WaitForChild("PlayerValue")
	local id = plrVal:WaitForChild("CurrentTowerID")
	if id.Value > 0 and id.Value < 1000000 and not checkPointDebounceList[player.UserId] then
		checkPointDebounceList[player.UserId] = true
		local targetTowerData = TowerData[tonumber(id.Value)]
		local targetTowerStages = targetTowerData.Stages
		local targetTowerFolder = towerFolders[tonumber(id.Value)]
		local char = player.Character
		local currentcp = plrVal:WaitForChild("CurrentCheckpoint")
		local latestcp = plrVal:WaitForChild("LatestCheckpoint")
		if currentcp.Value > 0 and latestcp.Value > 1 and targetTowerStages and #targetTowerStages > 1 then
			local previouscp = tonumber(plrVal:WaitForChild("CurrentCheckpoint").Value) - 1
			local nextcp = tonumber(plrVal:WaitForChild("CurrentCheckpoint").Value) + 1
			local enumerationTarget = {
				[0] = {	
					Stage = targetTowerStages[1];	--// Go to first checkpoint
					Check = function()
						return true; -- everyone starts from stage 1 anyway
					end;
					Append = function()
						currentcp.Value = 1
					end;
				};
				[1] = {
					Stage = targetTowerStages[previouscp];	--// Go to previous checkpoint
					Check = function()
						if previouscp > 0 then return true end -- Pass if the "Previous Checkpoint" is not lower than stage 1
					end;
					Append = function()
						currentcp.Value -= 1
					end;
				};
				[2] = {
					Stage = targetTowerStages[nextcp]; 	--// Go to next checkpoint
					Check = function()
						if nextcp <= latestcp.Value then return true end	-- Pass if the "Next Checkpoint" is not greater than last checkpoint 
					end;
					Append = function()
						currentcp.Value += 1
					end;
				};
				[3] = {
					Stage = targetTowerStages[#targetTowerStages]; 	--// Go to final checkpoint
					Check = function()
						if latestcp.Value == #targetTowerStages then return true end 
					end;
					Append = function()
						currentcp.Value = #targetTowerStages
					end;
				};
				[4] = {
					Stage = targetTowerStages[latestcp.Value]; 	--// Go to latest checkpoint
					Check = function()
						return true; -- Latest checkpoint can't really be cheated anyway
					end;
					Append = function()
						currentcp.Value = latestcp.Value
					end;
				};
			}
			studioprint("[TowerMgr] Performing NavigateCheckPoint action "..action.." for player "..player.Name)
			if enumerationTarget[action] and char and char.PrimaryPart and char:FindFirstChildWhichIsA("Humanoid") and enumerationTarget[action].Check() then
				local humanoid = char:FindFirstChildWhichIsA("Humanoid")
				enumerationTarget[action].Append()
				if targetTowerData and humanoid and not humanoid.Sit then
					char.PrimaryPart.CFrame = enumerationTarget[action].Stage.Part.CFrame + Vector3.new(0,5,0)
					userCheckpoints[player.UserId] = enumerationTarget[action].Stage.Part
					studioprint("[TowerMgr] Finished NavigateCheckPoint action "..action.." for player "..player.Name..", latestcheckp is "..latestcp.Value.." and currentcheckp is"..currentcp.Value)
					return true, currentcp.Value, enumerationTarget[action].Stage.Name
				else
					logErrorToPlayer:FireClient(player, "Error teleporting to checkpoint:",if humanoid.Sit then "You cannot teleport anywhere else while sitting." elseif not targetTowerData then "Invalid tower data, or mismatched checkpoint and tower relations." else "Unknown error(?), contact administrator.")
					return false
				end
			end
		end
	end
	task.wait(.5) checkPointDebounceList[player.UserId] = nil
end

function TowerMgr:GetCheckpointUserId(userId:number)
	return userCheckpoints[userId]
end

return TowerMgr


