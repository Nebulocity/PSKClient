-- Setup minimap button using LibDataBroker and LibDBIcon
local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
local icon = LibStub and LibStub("LibDBIcon-1.0", true)

if ldb then
    local dataObject = ldb:NewDataObject("PSKClient", {
        type = "launcher",
        text = "PSKClient",
        icon = "Interface\\AddOns\\PSKClient\\media\\icon.tga",
        OnClick = function()
            if PSKClientMainFrame:IsShown() then
                PSKClientMainFrame:Hide()
            else
                PSKClientMainFrame:Show()
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("PSKClient - Perchance Some Loot?")
            tt:AddLine("Click to open or close PSKClient.")
        end,
    })

    -- Delay registration until saved variables are ready
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_LOGIN")
    f:SetScript("OnEvent", function()
        PSKClientMinimapDB = PSKClientMinimapDB or {}
        if icon then
            icon:Register("PSKClient", dataObject, PSKClientMinimapDB)
        end
    end)
end
