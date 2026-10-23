---------------------------------------------------------
--  ZoneStyle - Minimap button
--  Author: Dranged
---------------------------------------------------------
-- A LibDBIcon button (so minimap addons can collect it): click opens the settings.

local ADDON, ZS = ...

local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBI = LibStub and LibStub("LibDBIcon-1.0", true)

ZS.ICON = "Interface\\AddOns\\ZoneStyle\\icon"

function ZS.SetMinimapShown(on)
    ZS.db.minimap.hide = not on
    if not DBI then return end
    if on then DBI:Show("ZoneStyle") else DBI:Hide("ZoneStyle") end
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if not (LDB and DBI) then return end
    local launcher = LDB:NewDataObject("ZoneStyle", {
        type = "launcher",
        text = "ZoneStyle",
        icon = ZS.ICON,
        OnClick = function() ZS.ToggleConfig() end,
        OnTooltipShow = function(tt)
            tt:AddLine("ZoneStyle")
            tt:AddLine("|cffffd100Click|r to open the settings", 1, 1, 1)
            tt:AddLine("|cffffd100Drag|r to move this button", 1, 1, 1)
        end,
    })
    DBI:Register("ZoneStyle", launcher, ZS.db.minimap)
end)
