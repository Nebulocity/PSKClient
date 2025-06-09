local PSKClient = select(2, ...)
_G.PSKClientGlobal = PSKClient


---------------------------------
-- Switch between Main/Tier List
---------------------------------

PSKClient.ToggleListButton = CreateFrame("Button", nil, PSKClient.MainFrame, "GameMenuButtonTemplate")
PSKClient.ToggleListButton:SetSize(140, 30)
PSKClient.ToggleListButton:SetText("Switch to Tier List")

PSKClient.ToggleListButton:SetScript("OnClick", function()
    if PSKClient.CurrentList == "Main" then
        PSKClient.CurrentList = "Tier"
        PSKClient.ToggleListButton:SetText("Switch to Main List")
    else
        PSKClient.CurrentList = "Main"
        PSKClient.ToggleListButton:SetText("Switch to Tier List")
    end

    -- Update Header Text
    local listKey = PSKClient.CurrentList
    local header = PSKClient.Headers.Main
    local count = listKey == "Main" and #PSKClientDB.MainList or #PSKClientDB.TierList
    if header then
        header:SetText((listKey == "Main" and "PSK Main" or "PSK Tier") .. " (" .. count .. ")")
    end

	if PSKClient.PlayRandomPeonSound then
		PSKClient:PlayRandomPeonSound()
	end

    PSKClient:DebouncedRefreshPlayerLists()
    PSKClient:DebouncedRefreshBidList()
end)


---------------------------------------------
-- Center buttons at top of PSKClient.ContentFrame
---------------------------------------------

local spacing = 20
local buttonWidth = 140

PSKClient.ToggleListButton:SetWidth(buttonWidth)

local totalWidth = buttonWidth * 3 + spacing * 2
local startX = -totalWidth / 2 + buttonWidth / 2

PSKClient.ToggleListButton:ClearAllPoints()
PSKClient.ToggleListButton:SetPoint("TOPLEFT", PSKClient.MainFrame, "TOPLEFT", 10, -60)

