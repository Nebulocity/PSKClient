
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
PSKClient.MainFrame.title:SetText("Perchance PSK - Perchance Some Loot?")


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
    CreateBorderedScrollFrame("PSKBidScrollFrame", PSKClient.MainFrame, 470, pskTabScrollFrameHeight, "Bids ( .. bidCount .. )", 220)
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

