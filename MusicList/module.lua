--[[

	Music List for BackgroundMusic
	License: MIT License (https://spdx.org/licenses/MIT)
	This Luau code was made by the following person:
	- wilsontulus5

--]]

local mus = {}

local musicIdList = {1837751879, 9048374150, 1843397729, 13308532338}	-- 1845736900

function mus.GetMusicIDs()
	return musicIdList
end

function mus.TempAdd(id)
	table.insert(tonumber(id),musicIdList)
end

function mus.TempRemove(id)
	table.remove(tonumber(id),musicIdList)
end

return mus
