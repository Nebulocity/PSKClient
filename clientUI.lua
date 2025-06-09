
local PSKClient = select(2, ...)

------------------------
-- Ensure settings exist
------------------------

if not PSKClientDB then PSKClientDB = {} end
PSKClientDB.Settings = PSKClientDB.Settings or { buttonSoundsEnabled = true, lootThreshold = 3 } -- default to 3 for rare
PSKClient.Settings = CopyTable(PSKClientDB.Settings)
local pskTabScrollFrameHeight = -115
local manageTabScrollFrameHeight = -87

------------------------
-- Initialize containers
------------------------

PSKClient.ScrollFrames = {}
PSKClient.ScrollChildren = {}
PSKClient.Headers = {}

------------------------
-- Create main frame
------------------------

PSKClient.MainFrame = CreateFrame("Frame", "PSKClientMainFrame", UIParent, "BasicFrameTemplateWithInset")
PSKClient.MainFrame:SetSize(705, 500)
PSKClient.MainFrame:SetPoint("CENTER")
PSKClient.MainFrame:SetMovable(true)
PSKClient.MainFrame:EnableMouse(true)
PSKClient.MainFrame:RegisterForDrag("LeftButton")
PSKClient.MainFrame:SetScript("OnDragStart", PSKClient.MainFrame.StartMoving)
PSKClient.MainFrame:SetScript("OnDragStop", PSKClient.MainFrame.StopMovingOrSizing)
PSKClient.MainFrame:SetFrameStrata("HIGH")
PSKClient.MainFrame:SetFrameLevel(200)
table.insert(UISpecialFrames, "PSKClientMainFrame")

------------------------
-- MainFrame Title
------------------------

PSKClient.MainFrame.title = PSKClient.MainFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
PSKClient.MainFrame.title:SetPoint("CENTER", PSKClient.MainFrame.TitleBg, "CENTER", 0, 0)
PSKClient.MainFrame.title:SetText("PSK Client- Perchance Some Loot?")


-----------------------------
-- Connection indicator
-----------------------------

local statusText = PSKClient.MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
statusText:SetPoint("TOPLEFT", 245, -70)

local statusDot = PSKClient.MainFrame:CreateTexture(nil, "OVERLAY")
statusDot:SetSize(12, 12)
statusDot:SetPoint("LEFT", statusText, "RIGHT", 6, 0)

function PSKClient:UpdateConnectionStatus()
    if PSKClient.Connected then
        statusText:SetText("Connected to loot master (" .. (PSKClient.LootMasterName or "Unknown") .. ")")
        statusDot:SetColorTexture(0, 1, 0, 1) -- green
    else
        statusText:SetText("Not connected to loot master")
        statusDot:SetColorTexture(1, 0, 0, 1) -- red
    end
end

local statusUpdater = CreateFrame("Frame")
local elapsed = 0

statusUpdater:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= 5 then
        -- Consider disconnected if no ping in last 10 seconds
        if PSKClient.LastPingTime and (GetTime() - PSKClient.LastPingTime > 10) then
            PSKClient.Connected = false
            PSKClient.LootMasterName = nil
        end

        PSKClient:UpdateConnectionStatus()
        elapsed = 0
    end
end)



---------------------------------------------
-- Set the default selected list (main/tier)
---------------------------------------------

PSKClient.CurrentList = "Main"


----------------------------------------------
-- Parent Player scroll frame to ContentFrame
----------------------------------------------

local playerScroll, playerChild, playerFrame, playerHeader =
    CreateBorderedScrollFrame("PSKScrollFrame", PSKClient.MainFrame, 10, pskTabScrollFrameHeight, "PSK Main ( .. mainListCount .. )")
PSKClient.ScrollFrames.Main = playerScroll
PSKClient.ScrollChildren.Main = playerChild
playerHeader:ClearAllPoints()
playerHeader:SetPoint("TOPLEFT", playerScroll, "TOPLEFT", 0, 20)
PSKClient.Headers.Main = playerHeader


----------------------------------------------
-- Parent Loot scroll frame to ContentFrame
----------------------------------------------

local lootScroll, lootChild, lootFrame, lootHeader =
    CreateBorderedScrollFrame("PSKLootScrollFrame", PSKClient.MainFrame, 240, pskTabScrollFrameHeight, "Loot Drops")
PSKClient.ScrollFrames.Loot = lootScroll
PSKClient.ScrollChildren.Loot = lootChild
lootHeader:ClearAllPoints()
lootHeader:SetPoint("TOPLEFT", lootScroll, "TOPLEFT", 0, 20)
PSKClient.Headers.Loot = lootHeader

--------------------------------------------
-- Parent Bidding scroll frame to ContentFrame
----------------------------------------------

local bidCount = (PSKClient.BidEntries and #PSKClient.BidEntries) or 0
local bidScroll, bidChild, bidFrame, bidHeader =
    CreateBorderedScrollFrame("PSKBidScrollFrame", PSKClient.MainFrame, 470, pskTabScrollFrameHeight, "Bids (0)", 220)
PSKClient.ScrollFrames.Bid = bidScroll
PSKClient.ScrollChildren.Bid = bidChild
bidHeader:ClearAllPoints()
bidHeader:SetPoint("TOPLEFT", bidScroll, "TOPLEFT", 0, 20)
PSKClient.Headers.Bid = bidHeader


----------------------------------
-- Refresh lists on load
----------------------------------

C_Timer.After(0.1, function()
	PSKClient:DebouncedRefreshPlayerLists()
	PSKClient:DebouncedRefreshLootList()
	PSKClient:DebouncedRefreshBidList()
end)

