---------------------------------------------------
-- This file is for helper functions for the addon
---------------------------------------------------

local PSKClient = select(2, ...)

-- Debounce flags
local refreshPlayerScheduled = false
local refreshBidScheduled = false
local refreshLootScheduled = false
local refreshAvailablePlayers = false

-- Facilitates row pools.
PSKClient.RowPool = PSKClient.RowPool or {}

---------------------------------------------------
-- Set/Get important details we'll need below
---------------------------------------------------

PSKClient.ScrollChildren = PSKClient.ScrollChildren or {}
PSKClient.Headers = PSKClient.Headers or {}
PSKClient.ScrollFrames = PSKClient.ScrollFrames or {}

local DEFAULT_COLUMN_WIDTH = 220
local COLUMN_HEIGHT = 355

CLASS_NAME_TO_FILE = {
    ["Warrior"] = "WARRIOR",
    ["Paladin"] = "PALADIN",
    ["Hunter"]  = "HUNTER",
    ["Rogue"]   = "ROGUE",
    ["Priest"]  = "PRIEST",
    ["Shaman"]  = "SHAMAN",
    ["Mage"]    = "MAGE",
    ["Warlock"] = "WARLOCK",
    ["Druid"]   = "DRUID",
}

-- DO NOT OVERWRITE 'RAID_CLASS_COLORS'!!!
-- It will break other addons...
local CLASS_COLORS = RAID_CLASS_COLORS or {
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
    PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    HUNTER  = { r = 0.67, g = 0.83, b = 0.45 },
    ROGUE   = { r = 1.00, g = 0.96, b = 0.41 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    SHAMAN  = { r = 0.00, g = 0.44, b = 0.87 },
    MAGE    = { r = 0.41, g = 0.80, b = 0.94 },
    WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
    DRUID   = { r = 1.00, g = 0.49, b = 0.04 },
}



function PSKClient:SafeAmbiguate(name)
    return name and Ambiguate(name, "short") or ""
end



---------------------------------------------------------
-- Create scrollable list container with head/backdrop.
---------------------------------------------------------

function CreateBorderedScrollFrame(name, parent, x, y, titleText, customWidth)
    local COLUMN_WIDTH = customWidth or 220
    local COLUMN_HEIGHT = 355

    local container = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    container:SetSize(COLUMN_WIDTH, COLUMN_HEIGHT + 20)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    container:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    container:SetBackdropColor(0.1, 0.1, 0.1, 0.85)

    -- Header text (was parented to 'parent', now to 'container')
    local header = container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("BOTTOMLEFT", container, "TOPLEFT", 5, 10)
    header:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    header:SetTextColor(1, 0.85, 0.1)
    header:SetText(titleText)

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", name, container, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(COLUMN_WIDTH - 26, COLUMN_HEIGHT)
    scrollFrame:SetPoint("TOPLEFT", container, "TOPLEFT", 5, -5)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(COLUMN_WIDTH - 40, COLUMN_HEIGHT)
    scrollFrame:SetScrollChild(scrollChild)

    return scrollFrame, scrollChild, container, header
end



----------------------------------------
-- Refresh Loot List
----------------------------------------

function PSKClient:RefreshLootList()

	if not PSKClientDB or not PSKClientDB.LootDrops then return end


    local scrollChild = PSKClient.ScrollChildren.Loot
    local header = PSKClient.Headers.Loot
    if not scrollChild or not header then return end

    -- Clear previous children
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    PSKClient.RowPool = PSKClient.RowPool or {}
    PSKClient.RowPool[scrollChild] = PSKClient.RowPool[scrollChild] or {}
    local pool = PSKClient.RowPool[scrollChild]

    local yOffset = -5

    for index, loot in ipairs(PSKClientDB.LootDrops) do
        local row = pool[index]
        if not row then
            row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetSize(240, 20)
            row:SetFrameLevel(scrollChild:GetFrameLevel() + 1)
            pool[index] = row
        end

        row:SetParent(scrollChild)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()

        -- Setup visuals once
        if not row.bg then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
        end
        row.bg:SetColorTexture(0, 0, 0, 0)

        if not row.iconTexture then
            row.iconTexture = row:CreateTexture(nil, "ARTWORK")
            row.iconTexture:SetSize(16, 16)
            row.iconTexture:SetPoint("LEFT", row, "LEFT", 5, 0)

            row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.itemText:SetPoint("LEFT", row.iconTexture, "RIGHT", 8, 0)

            row:SetScript("OnEnter", function()
                GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink(row.itemLink or "")
                GameTooltip:Show()
            end)

            row:SetScript("OnLeave", GameTooltip_Hide)

            row:SetScript("OnClick", function()
                if PSKClient.SelectedLootRow and PSKClient.SelectedLootRow.bg then
                    PSKClient.SelectedLootRow.bg:SetColorTexture(0, 0, 0, 0)
                end
                row.bg:SetColorTexture(0.2, 0.6, 1, 0.2)
                PSKClient.SelectedLootRow = row
                PSKClient.SelectedItem = row.itemLink
                PSKClient.SelectedItemData = row.lootData
                PSKClient.BidButton:Enable()

                local pulse = row:CreateAnimationGroup()
                local fadeOut = pulse:CreateAnimation("Alpha")
                fadeOut:SetFromAlpha(1)
                fadeOut:SetToAlpha(0.4)
                fadeOut:SetDuration(0.2)
                fadeOut:SetOrder(1)

                local fadeIn = pulse:CreateAnimation("Alpha")
                fadeIn:SetFromAlpha(0.4)
                fadeIn:SetToAlpha(1)
                fadeIn:SetDuration(0.2)
                fadeIn:SetOrder(2)

                pulse:SetLooping("NONE")
                pulse:Play()
            end)
        end

        -- Update visuals each loop
        row.iconTexture:SetTexture(loot.itemTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.itemText:SetText(loot.itemLink or "Unknown")
        row.itemLink = loot.itemLink
        row.lootData = loot

        yOffset = yOffset - 22
    end

    -- Hide unused rows
    for i = #PSKClientDB.LootDrops + 1, #pool do
        if pool[i] then pool[i]:Hide() end
    end

    header:SetText("Loot Drops (" .. #PSKClientDB.LootDrops .. ")")

    -- PSKClient:BroadcastUpdate("RefreshLootList")
end


----------------------------------------
-- Refresh Player List (for Main or Tier)
----------------------------------------

function PSKClient:RefreshPlayerLists()

	if InCombatLockdown() then
		if PSKClient.EventFrame and PSKClient.EventFrame.RegisterEvent then
			PSKClient.EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		end
		return
	end

    if not PSKClientDB or not PSKClient.CurrentList then return end

    local scrollChild = PSKClient.ScrollChildren.Main
    local header = PSKClient.Headers.Main
    if not scrollChild or not header then return end

    -- Clear previous list
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local names = {}
    if PSKClient.CurrentList == "Main" and PSKClientDB.MainList then
        names = PSKClientDB.MainList
    elseif PSKClient.CurrentList == "Tier" and PSKClientDB.TierList then
        names = PSKClientDB.TierList
    end

    -- Update header text
    header:SetText((PSKClient.CurrentList == "Main" and "PSK Main" or "PSK Tier") .. " (" .. #names .. ")")

    local yOffset = -5
    for index, entry in ipairs(names) do
		local name = entry.name
		local storedDate = entry.dateLastRaided or "Never"

		local row = PSKClient:GetOrCreateRow(index, scrollChild, "Player")
		
		-- row:SetParent(scrollChild)
		row:ClearAllPoints()
		row:SetSize(200, 20)
		row:SetPoint("TOPLEFT", 0, yOffset)
		row:Show()
	
		-- Background for status glow
		if not row.bg then
			row.bg = row:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints()
			row.bg:SetColorTexture(0, 0.5, 1, 0.15)  -- Light blue for selection
		end
		
		-- row.bg:Hide()		

		
		
        -- Get live data from raid/group/guild APIs
		local class, level, zone, online, inRaid = "SHAMAN", "???", "???", false, false

		-- Try raid/group info first
		if IsInRaid() then
			for i = 1, MAX_RAID_MEMBERS do
				local unit = "raid" .. i
				if UnitExists(unit) and Ambiguate(UnitName(unit), "short") == name then
					local _, classToken = UnitClass(unit)
					class = classToken or class
					level = UnitLevel(unit) or level
					zone = GetZoneText()
					online = UnitIsConnected(unit)
					inRaid = true
					break
				end
			end
		elseif IsInGroup() then
			for i = 1, GetNumGroupMembers() - 1 do
				local unit = "party" .. i
				if UnitExists(unit) and Ambiguate(UnitName(unit), "short") == name then
					local _, classToken = UnitClass(unit)
					class = classToken or class
					level = UnitLevel(unit) or level
					zone = GetZoneText()
					online = UnitIsConnected(unit)
					inRaid = false
					break
				end
			end
		end

		-- Fallback to Guild Roster
		if class == "SHAMAN" and GetNumGuildMembers() > 0 then
			for i = 1, GetNumGuildMembers() do
				local gName, _, _, gLevel, _, gZone, _, _, gOnline, _, gClassFile = GetGuildRosterInfo(i)
				local gShortName = Ambiguate(gName or "", "short")
				if gShortName == name then
					class = gClassFile or class
					level = gLevel or level
					zone = gZone or zone
					online = gOnline or false
					break
				end
			end
		end

        row.playerData = {
			name = name,
			class = class,
			online = online,
			inRaid = inRaid,
			level = level,
			zone = zone,
			dateLastRaided = storedDate
		}

        -- Position
		if not row.posText then
			row.posText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.posText:SetPoint("LEFT", row, "LEFT", 5, 0)
		end
		row.posText:SetText(index)

        -- Class icon
		if not row.classIcon then
			row.classIcon = row:CreateTexture(nil, "ARTWORK")
			row.classIcon:SetSize(16, 16)
			row.classIcon:SetPoint("LEFT", row.posText, "RIGHT", 8, 0)
		end
		
		if CLASS_ICON_TCOORDS[class] then
			row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
			row.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
		else
			row.classIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
			row.classIcon:SetTexCoord(0, 1, 0, 1)
		end

		
		-- Extract the player class
		local playerClass = playerData and playerData.class or "SHAMAN"
		local fileClass = string.upper(row.playerData.class or "SHAMAN")
		
		-- Corrected class color lookup
		local classColor = RAID_CLASS_COLORS[fileClass] or { r = 1, g = 1, b = 1 }

		-- Create the player name text with the correct color
		if not row.nameText then
			row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 8, 0)
		end
		
		row.nameText:SetText(row.playerData.name)
		row.nameText:SetTextColor(classColor.r, classColor.g, classColor.b)

		-- Status
		if not row.statusText then
			row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
			row.statusText:SetPoint("LEFT", row.nameText, "RIGHT", 10, 0)
		end
		
		if inRaid then
			row.statusText:SetText("In Raid")
			row.statusText:SetTextColor(1, 0.5, 0)
			row.nameText:SetAlpha(1)
			row.classIcon:SetAlpha(1)
			row.bg:Show()
		elseif online then
			row.statusText:SetText("Online")
			row.statusText:SetTextColor(0, 1, 0)
			row.nameText:SetAlpha(1)
			row.classIcon:SetAlpha(1)
			row.bg:Hide()
		else
			row.statusText:SetText("Offline")
			row.statusText:SetTextColor(0.5, 0.5, 0.5)
			row.bg:Hide()
			row.nameText:SetAlpha(0.5)
			row.classIcon:SetAlpha(0.5)
		end
		
	
        -- Tooltip
		row:SetScript("OnEnter", function(self)
			if self.playerData then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:ClearLines()

				local class = self.playerData.class or "SHAMAN"
				local name = self.playerData.name or "Unknown"
				local tcoords = CLASS_ICON_TCOORDS[class]
				if tcoords then
					local icon = string.format("|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:16:16:0:0:256:256:%d:%d:%d:%d|t ",
						tcoords[1]*256, tcoords[2]*256, tcoords[3]*256, tcoords[4]*256)
					local classColor = RAID_CLASS_COLORS[class] or {r = 1, g = 1, b = 1}
					GameTooltip:AddLine(icon .. name, classColor.r, classColor.g, classColor.b)
				else
					GameTooltip:AddLine(name)
				end

				GameTooltip:AddLine("Level: " .. tostring(self.playerData.level), 0.8, 0.8, 0.8)
				GameTooltip:AddLine("Location: " .. tostring(self.playerData.zone), 0.8, 0.8, 0.8)
				GameTooltip:AddLine("Last Raided: " .. tostring(self.playerData.dateLastRaided), 0.8, 0.8, 0.8)
				GameTooltip:Show()
			end
		end)

		row:SetScript("OnLeave", GameTooltip_Hide)

		
        yOffset = yOffset - 22
    end
	
	-- Hide unused rows in the pool
	local pool = PSKClient.RowPool[scrollChild] or {}
	for i = #names + 1, #pool do
		if pool[i] then
			pool[i]:Hide()
		end
	end
	
end


---------------------------------------------------
-- Handle delayed refresh after combat
---------------------------------------------------
-- -- Create a dedicated event frame for combat-related events
if not PSKClient.EventFrame then
    PSKClient.EventFrame = CreateFrame("Frame")
end

-- Register the event
PSKClient.EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

-- Handle the event
PSKClient.EventFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then
        PSKClient:DebouncedRefreshPlayerLists()
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)


------------------------------------------
-- Check if player is in list
------------------------------------------

function PSKClient:IsPlayerInList(list, targetName)
    for _, entry in ipairs(list) do
        if type(entry) == "table" and entry.name == targetName then
            return true
        elseif type(entry) == "string" and entry == targetName then
            return true
        end
    end
    return false
end


----------------------------------------
-- Refresh Bid List
----------------------------------------

function PSKClient:RefreshBidList()
    if not PSKClient.BidEntries then return end

    local scrollChild = PSKClient.ScrollChildren.Bid
    local header = PSKClient.Headers.Bid
    if not scrollChild or not header then return end

    PSKClient.RowPool = PSKClient.RowPool or {}
    PSKClient.RowPool[scrollChild] = PSKClient.RowPool[scrollChild] or {}
    local pool = PSKClient.RowPool[scrollChild]

    local bidCount = #PSKClient.BidEntries
    header:SetText("Bids (" .. bidCount .. ")")

    -- Wipe visible list
    for _, child in ipairs({scrollChild:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    -- Build index map from current list
	local indexMap = {}
	local list = (PSKClient.CurrentList == "Tier") and PSKClientDB.TierList or PSKClientDB.MainList
	if not list then list = {} end  -- fallback to empty table if nil

	for i, name in ipairs(list) do
		indexMap[name] = i
	end

	-- Sort bidders by list position; if not in list, push to end
	table.sort(PSKClient.BidEntries, function(a, b)
		local aIndex = indexMap[a.name] or math.huge
		local bIndex = indexMap[b.name] or math.huge
		return aIndex < bIndex
	end)

    local yOffset = -5
    for index, bidData in ipairs(PSKClient.BidEntries) do
        local row = pool[index]
        if not row then
            row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
            row:SetSize(220, 20)
            row:SetFrameLevel(scrollChild:GetFrameLevel() + 1)
            pool[index] = row
        end

        row:SetParent(scrollChild)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", 0, yOffset)
        row:Show()

        -- Background
        if not row.bg then
            row.bg = row:CreateTexture(nil, "BACKGROUND")
            row.bg:SetAllPoints()
        end
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.bg:Hide()

        row:EnableMouse(true)

        -- Position
        if not row.posText then
            row.posText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.posText:SetPoint("LEFT", row, "LEFT", 5, 0)
        end
		
		row.posText:SetText(index)
        -- row.posText:SetText(bidData.position)

        -- Class Icon
        local class = bidData.class or "SHAMAN"
        if not row.classIcon then
            row.classIcon = row:CreateTexture(nil, "ARTWORK")
            row.classIcon:SetSize(16, 16)
            row.classIcon:SetPoint("LEFT", row.posText, "RIGHT", 4, 0)
        end
        if CLASS_ICON_TCOORDS[class] then
            row.classIcon:SetTexture("Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes")
            row.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[class]))
        end

        -- Name
        if not row.nameText then
            row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 4, 0)
        end
        row.nameText:SetText(bidData.name)


        -- Award Button
        if not row.awardButton then
            row.awardButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            row.awardButton:SetSize(16, 16)
            row.awardButton:SetPoint("LEFT", row.nameText, "RIGHT", 30, 0)
            row.awardButton:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Check")
            row.awardButton:GetNormalTexture():SetTexCoord(0.2, 0.8, 0.2, 0.8)
            row.awardButton:SetText("")
        end
		
        local safeIndex = index  -- capture correctly

		row.awardButton:SetScript("OnClick", function(self)
			local row = self:GetParent()
			if row and row.bg then
				row.bg:SetColorTexture(0, 1, 0, 0.4)
				local pulse = row:CreateAnimationGroup()
				local fadeOut = pulse:CreateAnimation("Alpha")
				fadeOut:SetFromAlpha(1)
				fadeOut:SetToAlpha(0)
				fadeOut:SetDuration(0.4)
				fadeOut:SetOrder(1)
				local fadeIn = pulse:CreateAnimation("Alpha")
				fadeIn:SetFromAlpha(0)
				fadeIn:SetToAlpha(1)
				fadeIn:SetDuration(0.4)
				fadeIn:SetOrder(2)
				pulse:SetLooping("NONE")
				pulse:Play()
			end

			PSKClient.SelectedPlayer = bidData.name
			PSKClient:AwardPlayer(safeIndex)
		end)
		
        row.awardButton:SetScript("OnEnter", function(self)
            local row = self:GetParent()
            if row and row.bg then
                row.bg:SetColorTexture(0.2, 1, 0.2, 0.25)
                row.bg:Show()
            end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText("Award Loot", 1, 1, 1)
            GameTooltip:AddLine("Click to award loot to this player.", 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
		
        row.awardButton:SetScript("OnLeave", function(self)
            local row = self:GetParent()
            if row and row.bg then
                row.bg:Hide()
            end
            GameTooltip:Hide()
        end)

        yOffset = yOffset - 22
    end

    -- Hide unused bid rows
    for i = #PSKClient.BidEntries + 1, #pool do
        if pool[i] then pool[i]:Hide() end
    end
end


------------------------------------------------
-- Function to enable reusing of rows
-- This should prevent redrawing every refresh
------------------------------------------------

function PSKClient:GetOrCreateRow(index, parent, rowType)
    PSKClient.RowPool = PSKClient.RowPool or {}
    PSKClient.RowPool[parent] = PSKClient.RowPool[parent] or {}
    local pool = PSKClient.RowPool[parent]

    local row = pool[index]
    if not row then
        row = CreateFrame("Button", nil, parent, "BackdropTemplate")
        row:SetSize(650, 20)
        row:SetFrameLevel(parent:GetFrameLevel() + 1)

        -- Background
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0, 0, 0, 0)
        row.bg:Hide()

        pool[index] = row
    end

	if row:GetParent() ~= parent then
		row:SetParent(parent)
	end

    -- Log rows setup
    if rowType == "Log" and not row.classIcon then
        row.classIcon = row:CreateTexture(nil, "ARTWORK")
        row.classIcon:SetSize(16, 16)
        row.classIcon:SetPoint("LEFT", row, "LEFT", 5, 0)

        row.playerText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.playerText:SetPoint("LEFT", row.classIcon, "RIGHT", 5, 0)

        row.iconTexture = row:CreateTexture(nil, "ARTWORK")
        row.iconTexture:SetSize(16, 16)
        row.iconTexture:SetPoint("LEFT", row.playerText, "RIGHT", 6, 0)

        row.itemText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.itemText:SetPoint("LEFT", row.iconTexture, "RIGHT", 6, 0)

        row.timeText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.timeText:SetPoint("LEFT", row, "LEFT", 480, 0)
    end

    -- Player/Bid rows setup (minimal setup here; add more as needed)
    if rowType == "Player" and not row.posText then
        row.posText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.posText:SetPoint("LEFT", row, "LEFT", 5, 0)

        row.classIcon = row:CreateTexture(nil, "ARTWORK")
        row.classIcon:SetSize(16, 16)
        row.classIcon:SetPoint("LEFT", row.posText, "RIGHT", 8, 0)

        row.nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.nameText:SetPoint("LEFT", row.classIcon, "RIGHT", 8, 0)

        row.statusText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.statusText:SetPoint("LEFT", row.nameText, "RIGHT", 10, 0)
    end

    return row
end


-------------------------------------------
-- Refresh only after a short delay
-------------------------------------------

function PSKClient:DebouncedRefreshPlayerLists()
    if refreshPlayerScheduled then return end
    refreshPlayerScheduled = true
    C_Timer.After(0.5, function()
        refreshPlayerScheduled = false
        PSKClient:RefreshPlayerLists()
    end)
end

function PSKClient:DebouncedRefreshBidList()
    if refreshBidScheduled then return end
    refreshBidScheduled = true
    C_Timer.After(0.5, function()
        refreshBidScheduled = false
        PSKClient:RefreshBidList()
    end)
end

function PSKClient:DebouncedRefreshLootList()
    if refreshLootScheduled then return end
    refreshLootScheduled = true
    C_Timer.After(0.5, function()
        refreshLootScheduled = false
        PSKClient:RefreshLootList()
    end)
end
