-- DisenchantTooltip - written entirely by AI (Claude), designed and tested in the game by the maintainer.
--
-- Remembers what every item you disenchant turns into, and shows it as a line in the
-- tooltip of that item:
--     Disenchants to (8x):
--       1-3 Strange Dust          88%
--       1 Lesser Magic Essence    12%
-- (the % = in how many of the disenchants it came out; the more disenchants, the more exact)
--
-- How a disenchant is noticed:
--   1. the Disenchant cast is sent -> the game tells the name of the target (the item); the contents
--      of the bags are remembered at that moment
--   2. the loot window gets ready shortly after -> what is in it is what the item turned into
--   3. the item is the one in the bags with that name, or else the one that is gone from the bags
--      (Forever does not lock the item in the bags while it is disenchanted)

local DISENCHANT = 13262          -- spell ID of Disenchant
local WAIT_SECONDS = 10           -- the loot has to come this soon after the cast started
local COLOR = "|cff9d9dff"        -- colour of the tooltip line (light violet, like enchanting)

-- DisenchantTooltipDB.items[itemID] = { times = how many were disenchanted,
--     mats = { [matItemID] = { hits = in how many disenchants it came out,
--                              min = fewest at once, max = most at once, name = "Strange Dust" } } }
DisenchantTooltipDB = DisenchantTooltipDB

local pending -- the disenchant on its way: { time, name = target name, before = bag contents, mats = loot }

-- /detip debug: tells in the chat what the addon sees (to find out why something is not recorded)
local function Debug(...)
	if DisenchantTooltipDB and DisenchantTooltipDB.debug then print("|cff9d9dffDisenchantTooltip:|r", ...) end
end

local function IsDisenchant(spellID)
	if spellID == DISENCHANT then return true end
	-- another rank or ID of the same spell: compare by name
	local name = spellID and C_Spell.GetSpellName(spellID)
	return name ~= nil and name == C_Spell.GetSpellName(DISENCHANT)
end

-- what is in the bags: counts[itemID] = how many, names[itemID] = its name
local function Snapshot()
	local counts, names = {}, {}
	local last = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
	for bag = 0, last do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info and info.itemID then
				counts[info.itemID] = (counts[info.itemID] or 0) + (info.stackCount or 1)
				names[info.itemID] = info.itemName or (info.hyperlink and info.hyperlink:match("%[(.-)%]"))
			end
		end
	end
	return counts, names
end

local function NewPending(name)
	local counts, names = Snapshot()
	pending = { time = GetTime(), name = name, before = counts, names = names }
end

-- which item was disenchanted: the one with the target's name, or else the one that is gone from the bags
local function FindItem()
	local found
	if pending.name and pending.name ~= "" then
		for id, name in pairs(pending.names) do
			if name == pending.name then
				if found then found = nil break end -- two items with this name: cannot tell
				found = id
			end
		end
		if found then return found end
	end
	local now = Snapshot()
	for id, count in pairs(pending.before) do
		if (now[id] or 0) < count and not pending.matIDs[id] then
			if found then return nil end -- more than one is gone: cannot tell
			found = id
		end
	end
	return found
end

local Save

-- the loot is known; record it as soon as it is clear which item it came from
local function TryRecord()
	local itemID = FindItem()
	Debug("disenchanted item:", itemID or "not known yet")
	if itemID then
		Save(itemID, pending.mats)
		pending = nil
	elseif GetTime() - pending.time > WAIT_SECONDS then
		Debug("gave up - could not tell which item it was")
		pending = nil
	end
end

-- the loot window holds what the item turned into
local function OnLoot()
	Debug("loot ready,", GetNumLootItems(), "item(s); disenchant on its way:", pending and
		("yes, started " .. string.format("%.1f", GetTime() - pending.time) .. " s ago, target " .. tostring(pending.name)) or "no")
	if not pending or pending.mats then return end -- nothing on its way, or this loot is already read
	if GetTime() - pending.time > WAIT_SECONDS then pending = nil return end
	-- only loot from an item (not a mob or a chest looted right after)
	if GetLootSourceInfo then
		local guid = GetLootSourceInfo(1)
		Debug("loot source:", guid or "unknown")
		if guid and not guid:find("^Item%-") then return end
	end
	local mats, matIDs = {}, {}
	for i = 1, GetNumLootItems() do
		local link = GetLootSlotLink(i)
		local matID = link and C_Item.GetItemInfoInstant(link)
		local _, name, quantity = GetLootSlotInfo(i)
		if matID then
			mats[#mats + 1] = { id = matID, name = name, quantity = quantity or 1 }
			matIDs[matID] = true
		end
	end
	if #mats == 0 then pending = nil return end
	pending.mats, pending.matIDs = mats, matIDs
	TryRecord()
end

Save = function(itemID, mats)
	Debug("recorded", #mats, "material(s) for item", itemID, C_Item.GetItemNameByID(itemID) or "")
	local entry = DisenchantTooltipDB.items[itemID] or { times = 0, mats = {} }
	DisenchantTooltipDB.items[itemID] = entry
	entry.times = entry.times + 1
	local got = {} -- matID -> how many came out of this one disenchant
	for _, m in ipairs(mats) do got[m.id] = (got[m.id] or 0) + m.quantity end
	for _, m in ipairs(mats) do
		if got[m.id] then
			local mat = entry.mats[m.id] or { hits = 0 }
			entry.mats[m.id] = mat
			mat.hits = mat.hits + 1
			mat.min = math.min(mat.min or got[m.id], got[m.id])
			mat.max = math.max(mat.max or got[m.id], got[m.id])
			mat.name = m.name or mat.name
			got[m.id] = nil -- counted once per disenchant
		end
	end
end

-- TOOLTIP: on every item that was disenchanted before, a heading and one line per material
local function AddLine(tooltip, itemID)
	local entry = itemID and DisenchantTooltipDB and DisenchantTooltipDB.items[itemID]
	if not entry then return end
	local list = {}
	for matID, mat in pairs(entry.mats) do list[#list + 1] = { id = matID, mat = mat } end
	table.sort(list, function(a, b) return a.mat.hits > b.mat.hits end) -- the most common first
	tooltip:AddLine(COLOR .. "Disenchants to (" .. entry.times .. "x):|r")
	for _, m in ipairs(list) do
		local icon = C_Item.GetItemIconByID(m.id)
		local name = C_Item.GetItemNameByID(m.id) or m.mat.name or ("item " .. m.id)
		local amount = (m.mat.min == m.mat.max) and m.mat.min or (m.mat.min .. "-" .. m.mat.max)
		tooltip:AddDoubleLine("  " .. (icon and ("|T" .. icon .. ":0|t ") or "") .. amount .. " " .. name,
			math.floor(m.mat.hits / entry.times * 100 + 0.5) .. "%", 1, 1, 1, 1, 1, 1)
	end
end

if TooltipDataProcessor and Enum.TooltipDataType then
	TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
		if tooltip == GameTooltip or tooltip == ItemRefTooltip then AddLine(tooltip, data and data.id) end
	end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterUnitEvent("UNIT_SPELLCAST_SENT", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
events:RegisterEvent("LOOT_READY")
events:RegisterEvent("BAG_UPDATE_DELAYED")
events:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... == "DisenchantTooltip" then
			DisenchantTooltipDB = DisenchantTooltipDB or {}
			DisenchantTooltipDB.items = DisenchantTooltipDB.items or {}
			-- version 0.1 kept only totals, from which no range or % can be made: start those items again
			for itemID, entry in pairs(DisenchantTooltipDB.items) do
				for _, mat in pairs(entry.mats) do
					if not mat.hits then DisenchantTooltipDB.items[itemID] = nil break end
				end
			end
		end
	elseif event == "UNIT_SPELLCAST_SENT" then
		local _, target, _, spellID = ...
		if IsDisenchant(spellID) then
			Debug("disenchant sent, target:", target or "?")
			NewPending(target)
		end
	elseif event == "UNIT_SPELLCAST_START" then
		local _, _, spellID = ...
		if IsDisenchant(spellID) and not (pending and GetTime() - pending.time < 2) then
			Debug("disenchant started (not seen being sent)")
			NewPending(nil)
		end
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
		local _, _, spellID = ...
		if IsDisenchant(spellID) and pending and not pending.mats then
			Debug("disenchant stopped")
			pending = nil
		end
	elseif event == "LOOT_READY" then
		OnLoot()
	elseif event == "BAG_UPDATE_DELAYED" then
		if pending and pending.mats then TryRecord() end -- the item may leave the bags only now
	end
end)

SLASH_DISENCHANTTOOLTIP1 = "/detip"
SlashCmdList.DISENCHANTTOOLTIP = function(msg)
	if msg == "debug" then
		DisenchantTooltipDB.debug = not DisenchantTooltipDB.debug or nil
		print("DisenchantTooltip: debug " .. (DisenchantTooltipDB.debug and "on" or "off"))
	else
		local n = 0
		for _ in pairs(DisenchantTooltipDB.items) do n = n + 1 end
		print("DisenchantTooltip: " .. n .. " item(s) remembered. /detip debug = show what it sees in the chat.")
	end
end
