local ADDON, ZS = ...

---------------------------------------------------------
--  SECTION: Defaults
---------------------------------------------------------
-- Colours per C_PvP.GetZonePVPInfo() type. Defaults are Blizzard's own from
-- SetZoneText(). "none" covers zones with no PvP type.
ZS.COLOR_KEYS = { "sanctuary", "friendly", "hostile", "contested", "arena", "combat", "none" }
ZS.COLOR_LABELS = {
    sanctuary = "Sanctuary",
    friendly  = "Friendly territory",
    hostile   = "Hostile territory",
    contested = "Contested territory",
    arena     = "Free-for-all",
    combat    = "Combat zone",
    none      = "No PvP type",
}
ZS.DEFAULT_COLORS = {
    sanctuary = { r = 0.41, g = 0.8,    b = 0.94 },
    friendly  = { r = 0.1,  g = 1.0,    b = 0.1 },
    hostile   = { r = 1.0,  g = 0.1,    b = 0.1 },
    contested = { r = 1.0,  g = 0.7,    b = 0 },
    arena     = { r = 1.0,  g = 0.1,    b = 0.1 },
    combat    = { r = 1.0,  g = 0.1,    b = 0.1 },
    none      = { r = 1.0,  g = 0.9294, b = 0.7607 },
}

-- Font size settings and the Blizzard strings each one drives.
local FONTS = {
    zoneSize = { "ZoneTextString" },
    subSize  = { "SubZoneTextString" },
    pvpSize  = { "PVPInfoTextString", "PVPArenaTextString" },
}
local ALL_STRINGS = { "ZoneTextString", "SubZoneTextString", "PVPInfoTextString", "PVPArenaTextString" }

-- Blizzard's values, read from the client at load. A nil setting means "use these",
-- so anything never touched stays exactly as the game has it.
ZS.Blizz = {}
local fontInfo = {}

local function CaptureBlizz()
    local B = ZS.Blizz
    local _, _, _, x, y = ZoneTextFrame:GetPoint(1)
    B.x, B.y = x or 0, y or -128
    for key, names in pairs(FONTS) do
        for _, name in ipairs(names) do
            local fs = _G[name]
            local path, size, flags = fs:GetFont()
            fontInfo[name] = { object = fs:GetFontObject(), path = path, flags = flags }
            B[key] = B[key] or math.floor(size + 0.5)
        end
    end
    B.fadeIn  = ZoneTextFrame.fadeInTime  or ZoneFadeInDuration  or 0.5
    B.hold    = ZoneTextFrame.holdTime    or ZoneHoldDuration    or 1.0
    B.fadeOut = ZoneTextFrame.fadeOutTime or ZoneFadeOutDuration or 2.0
end

---------------------------------------------------------
--  SECTION: Settings access
---------------------------------------------------------
function ZS.Get(key)
    local v = ZS.db[key]
    if v == nil then return ZS.Blizz[key] end
    return v
end

function ZS.Set(key, v)
    local b = ZS.Blizz[key]
    if v == nil or (b and math.abs(v - b) < 1e-6) then
        ZS.db[key] = nil
    else
        ZS.db[key] = v
    end
    ZS.ApplyLayout()
end

function ZS.GetColor(key)
    if not ZS.DEFAULT_COLORS[key] then key = "none" end
    return ZS.db.colors[key] or ZS.DEFAULT_COLORS[key]
end

local function SameColor(a, b)
    return math.abs(a.r - b.r) < 1e-3 and math.abs(a.g - b.g) < 1e-3 and math.abs(a.b - b.b) < 1e-3
end

function ZS.SetColor(key, c)
    if c == nil or SameColor(c, ZS.DEFAULT_COLORS[key]) then
        ZS.db.colors[key] = nil
    else
        ZS.db.colors[key] = { r = c.r, g = c.g, b = c.b }
    end
    ZS.Recolor()
end

function ZS.ResetAll()
    local colors = ZS.db.colors
    wipe(ZS.db)
    wipe(colors)
    ZS.db.colors = colors
    ZS.ApplyLayout()
    ZS.Recolor()
end

---------------------------------------------------------
--  SECTION: Applying
---------------------------------------------------------
function ZS.ApplyLayout()
    ZoneTextFrame:ClearAllPoints()
    ZoneTextFrame:SetPoint("TOP", UIParent, "TOP", ZS.Get("x"), ZS.Get("y"))

    for key, names in pairs(FONTS) do
        local size = ZS.db[key]
        for _, name in ipairs(names) do
            local info = fontInfo[name]
            if size then
                _G[name]:SetFont(info.path, size, info.flags)
            elseif info.object then
                _G[name]:SetFontObject(info.object)
            else
                _G[name]:SetFont(info.path, ZS.Blizz[key], info.flags)
            end
        end
    end

    -- Unlocked mode holds the text on screen; it sets its own hold time.
    for _, f in ipairs({ ZoneTextFrame, SubZoneTextFrame }) do
        FadingFrame_SetFadeInTime(f, ZS.Get("fadeIn"))
        FadingFrame_SetHoldTime(f, ZS.unlocked and 86400 or ZS.Get("hold"))
        FadingFrame_SetFadeOutTime(f, ZS.Get("fadeOut"))
    end

    -- SetFontObject can reset the text colour, so put ours back.
    ZS.Recolor()
    if ZS.UpdateMover then ZS.UpdateMover() end
end

-- Original-game territories by uiMapID. The beta returns no PvP type anywhere, so
-- these fill it in. Any other outdoor zone counts as contested.
local TERRITORY = {
    [1429] = "Alliance", -- Elwynn Forest
    [1426] = "Alliance", -- Dun Morogh
    [1438] = "Alliance", -- Teldrassil
    [1436] = "Alliance", -- Westfall
    [1432] = "Alliance", -- Loch Modan
    [1439] = "Alliance", -- Darkshore
    [1453] = "Alliance", -- Stormwind City
    [1455] = "Alliance", -- Ironforge
    [1457] = "Alliance", -- Darnassus
    [1411] = "Horde",    -- Durotar
    [1412] = "Horde",    -- Mulgore
    [1420] = "Horde",    -- Tirisfal Glades
    [1421] = "Horde",    -- Silverpine Forest
    [1413] = "Horde",    -- The Barrens
    [1454] = "Horde",    -- Orgrimmar
    [1456] = "Horde",    -- Thunder Bluff
    [1458] = "Horde",    -- Undercity
}

local function FactionLabel(group)
    if group == "Horde" then return FACTION_HORDE or "Horde" end
    return FACTION_ALLIANCE or "Alliance"
end

-- Walks up from the player's map (caves and subzone maps) to a listed zone or
-- any zone. Returns pvpType, factionName; nil in instances or off the zone maps.
local function TerritoryPvP()
    if IsInInstance() then return nil end
    if not (C_Map and C_Map.GetBestMapForUnit) then return nil end
    local mapID = C_Map.GetBestMapForUnit("player")
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    while mapID do
        local owner = TERRITORY[mapID]
        if owner then
            local kind = (owner == UnitFactionGroup("player")) and "friendly" or "hostile"
            return kind, FactionLabel(owner)
        end
        local info = C_Map.GetMapInfo(mapID)
        if not info or not info.mapType or info.mapType < zoneType then return nil end
        if info.mapType == zoneType then return "contested" end
        mapID = info.parentMapID
    end
end
ZS.TerritoryPvP = TerritoryPvP

-- Returns pvpType, factionName, filled. filled is true when the type came from
-- TERRITORY because the client reported none.
local function GetPvPType()
    local t, faction
    if C_PvP and C_PvP.GetZonePVPInfo then
        t, _, faction = C_PvP.GetZonePVPInfo()
    elseif GetZonePVPInfo then
        t, faction = GetZonePVPInfo()
    end
    if (t == nil or t == "") and ZS.db.fillPvP ~= false then
        local ft, ff = TerritoryPvP()
        if ft then return ft, ff, true end
    end
    return t, faction, false
end
ZS.GetPvPType = GetPvPType

-- Blizzard leaves the PvP line empty when it has no type. Write it for filled-in
-- types, following SetZoneText's rule: show it on a new zone or a type change,
-- clear it on a subzone-only popup.
local lastFilled
local function FillPvPLine(showZone)
    local t, faction, filled = GetPvPType()
    if filled then
        local line
        if t == "contested" then
            line = CONTESTED_TERRITORY or "(Contested Territory)"
        else
            line = (FACTION_CONTROLLED_TERRITORY or "(%s Territory)"):format(faction)
        end
        if showZone or lastFilled ~= t then
            PVPInfoTextString:SetText(line)
            SubZoneTextString:SetPoint("TOP", "PVPInfoTextString", "BOTTOM", 0, 0)
        else
            PVPInfoTextString:SetText("")
            SubZoneTextString:SetPoint("TOP", "ZoneTextString", "BOTTOM", 0, 0)
        end
    end
    lastFilled = filled and t or nil
end

-- Colours every zone string for pvpType. With no argument it uses the type being
-- tested, or the zone you're in.
function ZS.Recolor(pvpType)
    pvpType = pvpType or ZS.previewType or GetPvPType()
    local c = ZS.GetColor(pvpType)
    for _, name in ipairs(ALL_STRINGS) do
        _G[name]:SetTextColor(c.r, c.g, c.b)
    end
end

---------------------------------------------------------
--  SECTION: Preview
---------------------------------------------------------
local function FactionName(opposite)
    local group = UnitFactionGroup("player")
    if opposite then group = (group == "Horde") and "Alliance" or "Horde" end
    if group == "Horde" then return FACTION_HORDE or "Horde" end
    return FACTION_ALLIANCE or "Alliance"
end

local function SampleLine(pvpType)
    local controlled = FACTION_CONTROLLED_TERRITORY or "(%s Territory)"
    if pvpType == "sanctuary" then return SANCTUARY_TERRITORY or "(Sanctuary)" end
    if pvpType == "friendly" then return controlled:format(FactionName(false)) end
    if pvpType == "hostile" then return controlled:format(FactionName(true)) end
    if pvpType == "contested" then return CONTESTED_TERRITORY or "(Contested Territory)" end
    if pvpType == "arena" then return FREE_FOR_ALL_TERRITORY or "(Free-for-All PvP Zone)" end
    if pvpType == "combat" then return COMBAT_ZONE or "(Combat Zone)" end
    return ""
end

-- With no pvpType, replays Blizzard's popup for the zone you're in. With one, shows
-- your current zone dressed as that PvP type.
function ZS.Preview(pvpType)
    if not pvpType then
        ZS.previewType = nil
        ZoneTextFrame.zoneText = ""
        ZoneText_OnEvent(ZoneTextFrame, "ZONE_CHANGED_NEW_AREA")
        return
    end
    ZS.previewType = pvpType
    ZoneTextString:SetText(GetZoneText())
    local sub = GetSubZoneText()
    SubZoneTextString:SetText(sub ~= GetZoneText() and sub or "")
    PVPArenaTextString:SetText("")
    PVPInfoTextString:SetText(SampleLine(pvpType))
    if PVPInfoTextString:GetText() == "" then
        SubZoneTextString:SetPoint("TOP", "ZoneTextString", "BOTTOM", 0, 0)
    else
        SubZoneTextString:SetPoint("TOP", "PVPInfoTextString", "BOTTOM", 0, 0)
    end
    ZS.Recolor()
    FadingFrame_Show(ZoneTextFrame)
    FadingFrame_Show(SubZoneTextFrame)
end

---------------------------------------------------------
--  SECTION: Init
---------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")

    ZoneStyleDB = ZoneStyleDB or {}
    ZS.db = ZoneStyleDB
    ZS.db.colors = ZS.db.colors or {}

    CaptureBlizz()
    -- Blizzard colours the text inside SetZoneText on every zone change; recolour after it.
    hooksecurefunc("SetZoneText", function(showZone)
        ZS.previewType = nil
        FillPvPLine(showZone)
        ZS.Recolor()
    end)
    ZS.ApplyLayout()
end)

---------------------------------------------------------
--  SECTION: Debug
---------------------------------------------------------
-- What the client reports for this zone, and where the popup sits on screen.
function ZS.Debug()
    local function P(...) print("|cff66ccffZoneStyle|r:", ...) end
    P("zone", tostring(GetZoneText()), "subzone", tostring(GetSubZoneText()))
    if C_PvP and C_PvP.GetZonePVPInfo then
        P("C_PvP.GetZonePVPInfo:", tostring((select(1, C_PvP.GetZonePVPInfo()))),
            tostring((select(2, C_PvP.GetZonePVPInfo()))), tostring((select(3, C_PvP.GetZonePVPInfo()))))
    else
        P("C_PvP.GetZonePVPInfo: missing")
    end
    if GetZonePVPInfo then
        P("GetZonePVPInfo:", tostring((select(1, GetZonePVPInfo()))),
            tostring((select(2, GetZonePVPInfo()))), tostring((select(3, GetZonePVPInfo()))))
    end
    local mapID = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
    local ft, ff = TerritoryPvP()
    P("map", tostring(mapID), "territory list:", tostring(ft), tostring(ff),
        "fill in:", ZS.db.fillPvP == false and "off" or "on")
    local point, rel, relPoint, x, y = ZoneTextFrame:GetPoint(1)
    P("ZoneTextFrame anchor:", tostring(point), rel and rel.GetName and tostring(rel:GetName()) or tostring(rel),
        tostring(relPoint), tostring(x), tostring(y))
    local cx, cy = ZoneTextFrame:GetCenter()
    P("ZoneTextFrame centre:", tostring(cx), tostring(cy), "screen width", tostring(UIParent:GetWidth()))
    local r, g, b = ZoneTextString:GetTextColor()
    P(("zone text colour: %.2f %.2f %.2f"):format(r, g, b), "pvp line:", tostring(PVPInfoTextString:GetText()))
end

---------------------------------------------------------
--  SECTION: Slash commands
---------------------------------------------------------
SLASH_ZONESTYLE1 = "/zonestyle"
SLASH_ZONESTYLE2 = "/zstyle"
SlashCmdList.ZONESTYLE = function(msg)
    msg = (msg or ""):lower()
    if msg:match("^%s*debug") then
        ZS.Debug()
    elseif msg:match("^%s*preview") or msg:match("^%s*test") then
        ZS.Preview()
    elseif msg:match("^%s*reset") then
        ZS.ResetAll()
        if ZS.RefreshConfig then ZS.RefreshConfig() end
        print("|cff66ccffZoneStyle|r: reset to Blizzard defaults.")
    elseif ZS.ToggleConfig then
        ZS.ToggleConfig()
    end
end

function ZoneStyle_OnCompartmentClick()
    if ZS.ToggleConfig then ZS.ToggleConfig() end
end
