local ADDON, ZS = ...

local frame
local refreshers = {}

local function Track(w)
    refreshers[#refreshers + 1] = w
    return w
end

function ZS.RefreshConfig()
    for _, w in ipairs(refreshers) do w:Refresh() end
end

local function Round(v, step)
    return math.floor(v / step + 0.5) * step
end

---------------------------------------------------------
--  SECTION: Widgets
---------------------------------------------------------
local function Text(parent, text, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontHighlight")
    fs:SetText(text)
    return fs
end

local function Button(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w, h)
    b:SetText(text)
    b:SetScript("OnClick", onClick)
    return b
end

-- Slider with a typed-value box. key is a ZS.Get/ZS.Set setting.
local function Slider(parent, label, key, min, max, step, fmt, x, y)
    local s = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(180, 16)
    s:SetPoint("TOPLEFT", x, y - 16)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(min, max)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)

    local title = Text(s, label, "GameFontNormalSmall")
    title:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 2)
    s.title = title

    local box = CreateFrame("EditBox", nil, s, "InputBoxTemplate")
    box:SetSize(50, 18)
    box:SetPoint("LEFT", s, "RIGHT", 12, 0)
    box:SetAutoFocus(false)
    box:SetJustifyH("CENTER")

    local function Show(v) box:SetText(fmt:format(v)) end

    s:SetScript("OnValueChanged", function(self, v, userInput)
        if not userInput then return end
        v = Round(v, step)
        ZS.Set(key, v)
        Show(v)
    end)
    box:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then ZS.Set(key, Round(math.max(min, math.min(max, v)), step)) end
        self:ClearFocus()
        s:Refresh()
    end)
    box:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        s:Refresh()
    end)

    function s:Refresh()
        local v = ZS.Get(key)
        self:SetValue(v)
        Show(v)
    end
    return Track(s)
end

local function PickColor(c, onChange)
    local r, g, b = c.r, c.g, c.b
    local function Changed()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        onChange({ r = nr, g = ng, b = nb })
    end
    local function Cancel() onChange({ r = r, g = g, b = b }) end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = Changed, cancelFunc = Cancel,
        })
    else
        ColorPickerFrame.func, ColorPickerFrame.cancelFunc = Changed, Cancel
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
    end
end

-- Swatch, label in the colour itself, and a Test button that shows the popup
-- as that PvP type.
local function ColorRow(parent, key, x, y)
    local sw = CreateFrame("Button", nil, parent, "BackdropTemplate")
    sw:SetSize(20, 20)
    sw:SetPoint("TOPLEFT", x, y)
    sw:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    sw:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)

    local label = Text(parent, ZS.COLOR_LABELS[key])
    label:SetPoint("LEFT", sw, "RIGHT", 8, 0)

    function sw:Refresh()
        local c = ZS.GetColor(key)
        self:SetBackdropColor(c.r, c.g, c.b, 1)
        label:SetTextColor(c.r, c.g, c.b)
    end
    sw:SetScript("OnClick", function(self)
        PickColor(ZS.GetColor(key), function(c)
            ZS.SetColor(key, c)
            self:Refresh()
        end)
    end)

    local test = Button(parent, "Test", 50, 20, function() ZS.Preview(key) end)
    test:SetPoint("TOPLEFT", x + 190, y)
    return Track(sw)
end

-- Show/hide box in front of a size slider's title: the title moves right to
-- make room. key is a setting where nil means shown.
local function ShowCheck(slider, key, onChange)
    local cb = CreateFrame("CheckButton", nil, slider, "UICheckButtonTemplate")
    cb:SetSize(20, 20)
    cb:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", -4, -3)
    slider.title:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 18, 2)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Show this line")
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
    cb:SetScript("OnClick", function(self)
        ZS.db[key] = (not self:GetChecked()) and false or nil
        onChange()
    end)
    function cb:Refresh() self:SetChecked(ZS.db[key] ~= false) end
    return Track(cb)
end

-- Button showing the current font; click for the list (game fonts, then
-- LibSharedMedia ones). Each entry is drawn in its own font.
local function FontPicker(parent, x, y)
    local b = Button(parent, "", 230, 22, nil)
    b:SetPoint("TOPLEFT", x, y)
    local function Pick(path)
        ZS.db.font = path
        ZS.ApplyLayout()
        b:Refresh()
    end
    b:SetScript("OnClick", function(self)
        local fonts = ZS.FontList()
        if MenuUtil and MenuUtil.CreateContextMenu then
            MenuUtil.CreateContextMenu(self, function(_, root)
                if root.SetScrollMode then root:SetScrollMode(360) end
                root:CreateRadio("Game default", function() return ZS.db.font == nil end, function() Pick(nil) end)
                for _, f in ipairs(fonts) do
                    local radio = root:CreateRadio(f.name,
                        function() return ZS.db.font and ZS.db.font:lower() == f.path:lower() end,
                        function() Pick(f.path) end)
                    if radio.AddInitializer then
                        radio:AddInitializer(function(button)
                            local fs = button.fontString or button.Text
                            if fs then fs:SetFont(f.path, 13, "") end
                        end)
                    end
                end
            end)
        else
            -- No menu API: step to the next font.
            local cur, nextPath = ZS.db.font, nil
            for i, f in ipairs(fonts) do
                if cur and f.path:lower() == cur:lower() then
                    nextPath = fonts[i + 1] and fonts[i + 1].path
                    break
                end
            end
            if not cur then nextPath = fonts[1].path end
            Pick(nextPath)
        end
    end)
    function b:Refresh() self:SetText(ZS.FontName()) end
    return Track(b)
end

---------------------------------------------------------
--  SECTION: Mover
---------------------------------------------------------
-- A box the size of the zone text area. Drag it to set the position; the popup
-- stays on screen while unlocked.
local mover

local function MoverOffset()
    local cx = mover:GetCenter()
    return Round(cx - UIParent:GetWidth() / 2, 1), Round(mover:GetTop() - UIParent:GetTop(), 1)
end

local function GetMover()
    if mover then return mover end
    mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mover:SetSize(512, 128)
    mover:SetFrameStrata("DIALOG")
    mover:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    mover:SetBackdropColor(0.2, 0.6, 1, 0.15)
    mover:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)
    local hint = Text(mover, "ZoneStyle: drag to move", "GameFontNormalSmall")
    hint:SetPoint("BOTTOM", mover, "TOP", 0, 2)
    mover:SetMovable(true)
    mover:SetClampedToScreen(true)
    mover:EnableMouse(true)
    mover:RegisterForDrag("LeftButton")
    mover:SetScript("OnDragStart", function(self)
        self:StartMoving()
        self.dragging = true
    end)
    mover:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self.dragging = false
        local x, y = MoverOffset()
        ZS.Set("x", x)
        ZS.Set("y", y)
        ZS.RefreshConfig()
    end)
    -- Drag the real text along with the box.
    mover:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local x, y = MoverOffset()
        ZoneTextFrame:ClearAllPoints()
        ZoneTextFrame:SetPoint("TOP", UIParent, "TOP", x, y)
    end)
    mover:Hide()
    return mover
end

function ZS.UpdateMover()
    if not mover or not mover:IsShown() or mover.dragging then return end
    mover:ClearAllPoints()
    mover:SetPoint("TOP", UIParent, "TOP", ZS.Get("x"), ZS.Get("y"))
end

function ZS.SetUnlocked(on)
    ZS.unlocked = on
    if on then
        GetMover():Show()
    elseif mover then
        mover:Hide()
    end
    ZS.ApplyLayout()
    if on then ZS.Preview(ZS.previewType) end
    if frame then frame.unlock:SetText(on and "Lock" or "Unlock") end
end

---------------------------------------------------------
--  SECTION: Window
---------------------------------------------------------
local function Build()
    frame = CreateFrame("Frame", "ZoneStyleConfig", UIParent, "BackdropTemplate")
    frame:SetSize(600, 560)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetScript("OnHide", function() ZS.SetUnlocked(false) end)
    tinsert(UISpecialFrames, "ZoneStyleConfig")

    local title = Text(frame, "ZoneStyle", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -18)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetTexture("Interface\\AddOns\\ZoneStyle\\icon")
    icon:SetPoint("RIGHT", title, "LEFT", -6, 0)
    local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    local version = Text(frame, "v" .. (getMeta and getMeta(ADDON, "Version") or "?"), "GameFontDisableSmall")
    version:SetPoint("TOPLEFT", 20, -20)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -6, -6)

    -- Left column: position, size, timing.
    local L = 28
    Text(frame, "Position", "GameFontNormal"):SetPoint("TOPLEFT", L, -50)
    Slider(frame, "Horizontal", "x", -1000, 1000, 1, "%d", L, -70)
    Slider(frame, "Vertical", "y", -1200, 0, 1, "%d", L, -112)
    frame.unlock = Button(frame, "Unlock", 100, 22, function() ZS.SetUnlocked(not ZS.unlocked) end)
    frame.unlock:SetPoint("TOPLEFT", L, -158)

    Text(frame, "Text size", "GameFontNormal"):SetPoint("TOPLEFT", L, -198)
    ShowCheck(Slider(frame, "Zone name", "zoneSize", 8, 72, 1, "%d", L, -218), "showZone", ZS.ApplyLayout)
    ShowCheck(Slider(frame, "Subzone name", "subSize", 8, 72, 1, "%d", L, -260), "showSub", ZS.ApplyLayout)
    ShowCheck(Slider(frame, "PvP line", "pvpSize", 8, 72, 1, "%d", L, -302), "showPvP", ZS.ApplyLayout)

    Text(frame, "Timing (seconds)", "GameFontNormal"):SetPoint("TOPLEFT", L, -350)
    Slider(frame, "Fade in", "fadeIn", 0, 5, 0.1, "%.1f", L, -370)
    Slider(frame, "Hold", "hold", 0, 20, 0.5, "%.1f", L, -412)
    Slider(frame, "Fade out", "fadeOut", 0, 10, 0.1, "%.1f", L, -454)

    -- Right column: colours.
    local R = 320
    Text(frame, "Colour by zone PvP type", "GameFontNormal"):SetPoint("TOPLEFT", R, -50)
    for i, key in ipairs(ZS.COLOR_KEYS) do
        ColorRow(frame, key, R, -72 - (i - 1) * 28)
    end
    local note = Text(frame, "The zone, subzone and PvP lines all take the colour of the zone's PvP type. Test shows your current zone as that type.", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", R, -276)
    note:SetWidth(250)
    note:SetJustifyH("LEFT")

    -- On by default: the beta reports no PvP type, so without it every zone is "No PvP type".
    local fill = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    fill:SetSize(24, 24)
    fill:SetPoint("TOPLEFT", R - 4, -320)
    local fillLabel = Text(frame, "Fill in PvP type from the original\nzone territories when the game\ngives none")
    fillLabel:SetPoint("TOPLEFT", fill, "TOPRIGHT", 4, -4)
    fillLabel:SetJustifyH("LEFT")
    fill:SetScript("OnClick", function(self)
        ZS.db.fillPvP = (not self:GetChecked()) and false or nil
        ZS.Recolor()
    end)
    function fill:Refresh() self:SetChecked(ZS.db.fillPvP ~= false) end
    Track(fill)

    Text(frame, "Font", "GameFontNormal"):SetPoint("TOPLEFT", R, -384)
    FontPicker(frame, R, -404)

    local preview = Button(frame, "Preview", 110, 24, function() ZS.Preview() end)
    preview:SetPoint("BOTTOMLEFT", 24, 20)
    local reset = Button(frame, "Reset all", 110, 24, function()
        ZS.ResetAll()
        ZS.RefreshConfig()
    end)
    reset:SetPoint("LEFT", preview, "RIGHT", 10, 0)
    local done = Button(frame, "Close", 110, 24, function() frame:Hide() end)
    done:SetPoint("BOTTOMRIGHT", -24, 20)

    frame:Hide()
end

function ZS.ShowConfig()
    if not frame then Build() end
    ZS.RefreshConfig()
    frame:Show()
end

function ZS.ToggleConfig()
    if frame and frame:IsShown() then
        frame:Hide()
    else
        ZS.ShowConfig()
    end
end

---------------------------------------------------------
--  SECTION: Game settings entry
---------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
    local panel = CreateFrame("Frame")
    panel.name = "ZoneStyle"
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetSize(24, 24)
    icon:SetTexture("Interface\\AddOns\\ZoneStyle\\icon")
    icon:SetPoint("TOPLEFT", 16, -12)
    local title = Text(panel, "ZoneStyle", "GameFontNormalLarge")
    title:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    local text = Text(panel, "ZoneStyle has its own settings window. You can also open it with /zonestyle.")
    text:SetPoint("TOPLEFT", 16, -46)
    local open = Button(panel, "Open ZoneStyle", 160, 24, function()
        if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
        ZS.ShowConfig()
    end)
    open:SetPoint("TOPLEFT", 16, -74)
    local category = Settings.RegisterCanvasLayoutCategory(panel, "ZoneStyle")
    Settings.RegisterAddOnCategory(category)
end)
