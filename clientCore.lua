-- core.lua


local PSKClient = select(2, ...)

-- Ensure PSKClientDB is initialized correctly
if not PSKClientDB then PSKClientDB = {} end
if not PSKClientDB.MainList then PSKClientDB.MainList = {} end
if not PSKClientDB.TierList then PSKClientDB.TierList = {} end
if not PSKClientDB.LootDrops then PSKClientDB.LootDrops = {} end

_G.PSKClientGlobal = _G.PSKClientGlobal or {}


PSKClient.RarityNames = {
	[0] = "Poor",
	[1] = "Common",
	[2] = "Uncommon",
	[3] = "Rare",
	[4] = "Epic",
	[5] = "Legendary"
}

 PSKClient.RarityColors = {
	[0] = "9d9d9d", -- Poor
	[1] = "ffffff", -- Common
	[2] = "1eff00", -- Uncommon
	[3] = "0070dd", -- Rare
	[4] = "a335ee", -- Epic
	[5] = "ff8000", -- Legendary
}


-- Main Variables
PSKClient.BiddingOpen = false
PSKClient.BidEntries = {}
PSKClient.CurrentList = "Main"
PSKClient.RollResults = PSKClient.RollResults or {}
PSKClient.ManualCancel = false
PSKClient.BidTimers = {}


-------------------------------------------
-- Frame for updating PSK lists on update.
-------------------------------------------

PSKClient.RosterFrame = CreateFrame("Frame")
PSKClient.RosterFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
PSKClient.RosterFrame:SetScript("OnEvent", function(_, event, ...)
	if PSK and PSKClient.RefreshAvailableMembers then
		PSKClient:DebouncedRefreshAvailablePlayerList()
	end
		
	if PSK and PSKClient.CurrentList then
		local original = PSKClient.CurrentList
		PSKClient.CurrentList = "Main"
		PSKClient:DebouncedRefreshPlayerLists()
		PSKClient.CurrentList = "Tier"
		PSKClient:DebouncedRefreshPlayerLists()
		PSKClient.CurrentList = original
	end
end)


----------------------------------------
-- Auto-Refresh Player Lists on Events
----------------------------------------
PSKClient.EventFrame = CreateFrame("Frame")
PSKClient.EventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
PSKClient.EventFrame:RegisterEvent("PLAYER_FLAGS_CHANGED")
PSKClient.EventFrame:RegisterEvent("GUILD_ROSTER_UPDATE")
PSKClient.EventFrame:RegisterEvent("PLAYER_GUILD_UPDATE")
PSKClient.EventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
PSKClient.EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

PSKClient.EventFrame:SetScript("OnEvent", function(_, event, ...)
    -- Events where we trigger a guild roster scan
	GuildRoster()

    -- Handle group/raid changes
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_FLAGS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
        if PSK and PSKClient.CurrentList then
            local original = PSKClient.CurrentList
            PSKClient.CurrentList = "Main"
            PSKClient:DebouncedRefreshPlayerLists()
            PSKClient.CurrentList = "Tier"
            PSKClient:DebouncedRefreshPlayerLists()
            PSKClient.CurrentList = original
        end
        return
    end
end)


------------------------------------------
-- Console commands to open addon
------------------------------------------

local slashFrame = CreateFrame("Frame")
slashFrame:RegisterEvent("PLAYER_LOGIN")

slashFrame:SetScript("OnEvent", function()
	-- Hard reset all saved and in-memory data
	wipe(PSKClientDB)

	-- Reinitialize required fields
	PSKClientDB = {
		MainList = {},
		TierList = {},
		LootDrops = {}
	}
	PSKClient.BidEntries = {}
	PSKClient.LootDrops = {}
	PSKClient.CurrentList = "Main"
	PSKClient.BiddingOpen = false
	PSKClient.RollResults = {}
	PSKClient.ManualCancel = false
	PSKClient.BidTimers = {}

	-- Setup slash command
	SLASH_PSKCLIENT1 = "/pskclient"
	SlashCmdList["PSKCLIENT"] = function()
		if PSKClient and PSKClient.MainFrame then
			if PSKClient.MainFrame:IsShown() then
				PSKClient.MainFrame:Hide()
			else
				PSKClient.MainFrame:Show()
			end
		end
	end
end)



------------------------------------------
-- Console command to clear PSK lists
------------------------------------------
SLASH_PSKCLIENTCLEAR1 = "/pskclientclear"
SlashCmdList["PSKCLIENTCLEAR"] = function()
    StaticPopup_Show("PSK_CONFIRM_CLEAR_LISTS")
end


StaticPopupDialogs["PSK_CONFIRM_CLEAR_LISTS"] = {
    text = "This will permanently clear both the Main and Tier lists.\nAre you sure?",
    button1 = "Yes",
    button2 = "Cancel",
    OnAccept = function()
        PSKClientDB.MainList = {}
        PSKClientDB.TierList = {}
		PSKClientDB.LootDrops = {}
        PSKClient:RefreshPlayerLists()
		PSKClient:RefreshLootList()
        print("[PSK] All PSK lists have been cleared.")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3
}


-------------------------------------------------
-- Register addon message handler
-------------------------------------------------


local chunkBuffer = {}
-- local receivedBidUpdate = false

C_ChatInfo.RegisterAddonMessagePrefix("PSK_SYNC")

local f = CreateFrame("Frame")
f:RegisterEvent("CHAT_MSG_ADDON")

print("[PSK Client] Addon message handler initialized")

f:SetScript("OnEvent", function(_, _, prefix, message, channel, sender)

    if prefix ~= "PSK_SYNC" then return end
	
    local msgType, index, total, chunk = strmatch(message, "^(.-)@@(%d+)@@(%d+)@@(.+)$")
	
	if not msgType or not index or not total or not chunk then
		print("[PSK Client] Malformed message dropped:", message)
		return
	end

    index = tonumber(index)
    total = tonumber(total)
	
    if not msgType or not index or not total or not chunk then
        print("[PSK Client] Failed to parse message:", message)
        return
    end

    local key = sender .. "||" .. msgType
    chunkBuffer[key] = chunkBuffer[key] or {}
    chunkBuffer[key][index] = chunk

	local receivedChunks = 0
	for i = 1, total do
		if chunkBuffer[key][i] then receivedChunks = receivedChunks + 1 end
	end
	
	-- print(string.format("[PSK Client] %s: %d/%d chunks received so far", msgType, receivedChunks, total))
	-- if msgType == "UPDATE_LOOT" then
		-- print(string.format("[PSK Client] Received chunk %d/%d for %s from %s", index, total, msgType, sender))
	-- end

    -- Check if all parts are received
    local assembled = true
    for i = 1, total do
        if not chunkBuffer[key][i] then
            assembled = false
            break
        end
    end

	-- if msgType == "UPDATE_LOOT" then
		-- print(string.format("[PSK Client] Received chunk %d/%d for UPDATE_LOOT from %s", index, total, sender))
	-- end


    if not assembled then return end

    local orderedChunks = {}
    for i = 1, total do
        table.insert(orderedChunks, chunkBuffer[key][i] or "")
    end

    local fullEncoded = table.concat(orderedChunks)

    chunkBuffer[key] = nil  -- Clear buffer for this sender/message combo

    local LibSerialize = LibStub("LibSerialize")
    local LibDeflate = LibStub("LibDeflate")

    local compressed = LibDeflate:DecodeForPrint(fullEncoded)
    if not compressed then return end

    local serialized = LibDeflate:DecompressZlib(compressed)
    if not serialized then return end

    local success, data = LibSerialize:Deserialize(serialized)
    if not success then return end

	-- print("[PSK Client] Final msgType:", "[" .. tostring(msgType) .. "]")
	
    -- Dispatch based on message type
    if msgType == "UPDATE_MAIN_LIST" then
		-- print(string.format("[PSK Client] Assembled %s (%d chunks, length %d)", msgType, total, #fullEncoded))
        PSKClientDB.MainList = {}
		PSKClientDB.MainList = data
		PSKClient:RefreshPlayerLists()
		
    elseif msgType == "UPDATE_TIER_LIST" then
		-- print(string.format("[PSK Client] Assembled %s (%d chunks, length %d)", msgType, total, #fullEncoded))
        PSKClientDB.TierList = {}
		PSKClientDB.TierList = data
		PSKClient:RefreshPlayerLists()
		
    elseif msgType == "UPDATE_LOOT" then
	    -- print(string.format("[PSK Client] Received chunk %d/%d for %s from %s", index, total, msgType, sender))
		PSKClientDB.LootDrops = {}
		PSKClientDB.LootDrops = data
		PSKClient:RefreshLootList()

    elseif msgType == "UPDATE_BIDS" then
		
		PSKClientDB.BidEntries = {}  -- wipe first
		
		local count = type(data) == "table" and #data or 0
		
		-- print(string.format("[PSK Client] UPDATE_BIDS payload decoded: %s, #entries: %d", type(data), count))
		
		if type(data) ~= "table" or #data == 0 then
			-- print("[PSK Client] UPDATE_BIDS ignored: empty payload")
			PSKClientDB.BidEntries = {} 
			PSKClient.BidEntries = {} 
			PSKClient:RefreshBidList()
			return
		else
			for i, entry in ipairs(data) do
				-- print(string.format("  %d. %s (%s)", i, entry.name or "?", entry.class or "?"))
			end
			
			PSKClientDB.BidEntries = data
			PSKClient.BidEntries = data 
			PSKClient:RefreshBidList()
		end	end

end)


