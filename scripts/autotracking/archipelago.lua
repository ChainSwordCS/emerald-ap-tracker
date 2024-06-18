ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/flag_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/ap_helper.lua")

CUR_INDEX = -1
PLAYER_ID = -1
TEAM_NUMBER = 0

EVENT_ID=""
KEY_ID=""

LOCATION_SETS_COLLECTED = {}

function onClear(slot_data)
	CUR_INDEX = -1
	resetLocations()
	resetItems()
	LOCATION_SETS_COLLECTED = {}

	if slot_data == nil then
		print("its fucked")
		return
	end

	PLAYER_ID = Archipelago.PlayerNumber or -1
	TEAM_NUMBER = Archipelago.TeamNumber or 0
	
	--print(dump_table(slot_data))

	for k,v in pairs(slot_data) do
		if k == "remove_roadblocks" then
			for r,c in pairs(ROADBLOCK_CODES) do
				Tracker:FindObjectForCode(c).CurrentStage = has_value(slot_data['remove_roadblocks'],r)
			end
		elseif SLOT_CODES[k] then
			Tracker:FindObjectForCode(SLOT_CODES[k].code).CurrentStage = SLOT_CODES[k].mapping[v]
		end
	end

	if PLAYER_ID>-1 then
		updateEvents(0)
		EVENT_ID="pokemon_emerald_events_"..TEAM_NUMBER.."_"..PLAYER_ID
		Archipelago:SetNotify({EVENT_ID})
		Archipelago:Get({EVENT_ID})

		KEY_ID="pokemon_emerald_keys_"..TEAM_NUMBER.."_"..PLAYER_ID
		Archipelago:SetNotify({KEY_ID})
		Archipelago:Get({KEY_ID})
	end
end

function onItem(index, item_id, item_name, player_number)
	if index <= CUR_INDEX then
		return
	end
	CUR_INDEX = index;
	local v = ITEM_MAPPING[item_id]
	if not v or not v[1] then
		--print(string.format("onItem: could not find item mapping for id %s", item_id))
		return
	end
	local obj = Tracker:FindObjectForCode(v[1])
	if obj then
		obj.Active = true
	else
		print(string.format("onItem: could not find object for code %s", v[1]))
	end
end

--called when a location gets cleared
function onLocation(location_id, location_name)
	local v = LOCATION_MAPPING[location_id]
	if not v or not v[1] then
		-- if not in main list, check list of sets
		local w = LOCATION_SETS[location_id]
		if w and w[1] then
			local obj = Tracker:FindObjectForCode(w[1])
			if not obj then
				print(string.format("onLocation: LOCATION_SETS: could not find object for code %s", w[1]))
			else
				--[[ just keep a counter for each group, and decrement it.
					no need to keep track of which individual checks have been cleared,
					as the AP server will only send each check clear once.
				]]--
				local amt = LOCATION_SETS_COLLECTED[w[1]]
				if not amt or not amt[1] then
					LOCATION_SETS_COLLECTED[w[1]] = {obj.ChestCount} -- "item_count"
					amt = LOCATION_SETS_COLLECTED[w[1]]
				end
				if amt[1] > 0 then
					amt[1] = amt[1] - 1
				end
				if amt[1] == 0 then
					obj.AvailableChestCount = 0
				end
			end
			return
		else
		print(string.format("onLocation: could not find location mapping for id %s (%s)", location_id, location_name))
		return
		end
	end
	local obj = Tracker:FindObjectForCode(v[1])
	if obj then
		obj.AvailableChestCount = 0
	else
		print(string.format("onLocation: could not find object for code %s", v[1]))
	end
end

function onNotify(key, value, old_value)
	if key == EVENT_ID then
		updateEvents(value)
	elseif key == KEY_ID then
		updateVanillaKeyItems(value)
	end
end

function onNotifyLaunch(key, value)
	if key == EVENT_ID then
		updateEvents(value)
	elseif key == KEY_ID then
		updateVanillaKeyItems(value)
	end
end

function updateEvents(value)
	if value ~= nil then
		local gyms = 0
		for i, code in ipairs(FLAG_EVENT_CODES) do
			local bit = value >> (i - 1) & 1
			if i < 9 then
				gyms = gyms + bit
				if has("op_bdg_off") then --mark badge if unrandomized
					Tracker:FindObjectForCode(FLAG_BADGE_CODES[i]).Active = bit
				end
			end
			if code == "harbormail" then --special case for handling harbor mail, do not overwrite active value in case obtained as filler item
				Tracker:FindObjectForCode(code).Active = Tracker:FindObjectForCode(code).Active or bit
			elseif #code>0 then
				Tracker:FindObjectForCode(code).Active = bit
			end
		end
		Tracker:FindObjectForCode("gyms").CurrentStage = gyms
	end
end

function updateVanillaKeyItems(value) 
	if value ~= nil then
		for i, obj in ipairs(FLAG_ITEM_CODES) do
			local bit = value >> (i - 1) & 1
			if obj.codes and has(obj.option) then
				for i, code in ipairs(obj.codes) do 
					Tracker:FindObjectForCode(code).Active = bit
				end
			end
		end
	end
end

Archipelago:AddClearHandler("clear handler", onClear)
Archipelago:AddItemHandler("item handler", onItem)
Archipelago:AddLocationHandler("location handler", onLocation)
Archipelago:AddSetReplyHandler("notify handler", onNotify)
Archipelago:AddRetrievedHandler("notify launch handler", onNotifyLaunch)