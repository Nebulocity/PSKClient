
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

-- Core dot (initially hidden)
local statusDot = PSKClient.MainFrame:CreateTexture(nil, "OVERLAY")
statusDot:SetSize(32, 32)
statusDot:SetPoint("TOPLEFT", 0, -30)
statusDot:SetBlendMode("ADD")
statusDot:Hide()

-- Pulsing glow (initially hidden)
local statusGlow = PSKClient.MainFrame:CreateTexture(nil, "ARTWORK")
statusGlow:SetSize(48, 48)
statusGlow:SetPoint("CENTER", statusDot, "CENTER")
statusGlow:SetBlendMode("ADD")
statusGlow:SetAlpha(0)
statusGlow:Hide()

-- Text
local connStatusText = PSKClient.MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
connStatusText:SetPoint("LEFT", statusDot, "RIGHT", -5, 0)

-- Animate the pulsing glow for ALL states
local pulseTime = 0
local pulseSpeed = 2
local pulseFrame = CreateFrame("Frame")
pulseFrame:SetScript("OnUpdate", function(_, elapsed)
    pulseTime = pulseTime + elapsed * pulseSpeed

    if statusGlow:IsShown() then
        local alpha = 0.2 + 0.2 * math.sin(pulseTime) -- 0.0 to 0.4
        statusGlow:SetAlpha(alpha)
    end
end)

-- Update logic
function PSKClient:UpdateConnectionStatus()
    local connected = PSKClient.Connected
    local seen = next(PSKClient.SeenMasters)

    if connected then
        connStatusText:SetText("Connected to Loot Master: " .. (PSKClient.LootMasterName or "Unknown"))
        statusDot:SetTexture("Interface\\AddOns\\PSKClient\\media\\glowing_dot_green.tga")
        statusGlow:SetTexture("Interface\\AddOns\\PSKClient\\media\\glowing_dot_green.tga")
        statusDot:Show()
        statusGlow:Show()

    elseif seen then
        connStatusText:SetText("Multiple masters detected")
        statusDot:SetTexture("Interface\\AddOns\\PSKClient\\media\\glowing_dot_orange.tga")
        statusGlow:SetTexture("Interface\\AddOns\\PSKClient\\media\\glowing_dot_orange.tga")
        statusDot:Show()
        statusGlow:Show()

    else
        connStatusText:SetText("Not connected to loot master")
        statusDot:SetTexture("Interface\\AddOns\\PSKClient\\media\\glowing_dot_red.tga")
        statusGlow:SetTexture("Interface\\AddOns\\PSKClient\\media\\glowing_dot_red.tga")
        statusDot:Show()
        statusGlow:Show()
    end
end

-- Periodic status check
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

