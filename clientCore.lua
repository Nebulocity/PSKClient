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
