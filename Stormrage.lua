-- Stormrage - one minimap button for every Stormrage addon (WoW 3.3.5a).
-- Copyright (C) 2026 pabhoz - https://github.com/pabhoz/Stormrage-WoW-Addon
-- Licensed under the GNU General Public License v3.0 or later. See LICENSE.

-- Other addons add themselves to the menu with Stormrage.Register and then skip
-- their own minimap button. Declare "## OptionalDeps: Stormrage" in the .toc so
-- this file loads first, and call it once the addon's saved variables exist:
--
--   if Stormrage and Stormrage.Register then
--     Stormrage.Register({
--       name = "My Addon",                     -- required
--       icon = "Interface\\Icons\\...",        -- 36x36 icon path
--       description = "one short line",
--       onClick = function(mouseButton) end,   -- click on its row in the menu
--       tooltip = function(tooltip) end,       -- extra lines when hovering its row
--       actions = { { text = "Do X", func = function() end } },  -- quick actions
--     })
--   else
--     -- create the addon's own minimap button
--   end

Stormrage = Stormrage or {}

local VERSION = 1
local SITE = "stormrage-server.com"
local ICON = "Interface\\Icons\\Spell_Nature_Lightning"

local L = setmetatable({}, { __index = function(_, k) return k end })
local locale = GetLocale()
if locale == "esES" or locale == "esMX" then
	L["Stormrage addons"] = "Addons de Stormrage"
	L["Click: open the menu\nDrag: move"] = "Clic: abrir el menu\nArrastra: mover"
	L["No Stormrage addons installed yet."] = "Todavia no hay addons de Stormrage instalados."
	L["The realm's website"] = "El sitio del reino"
	L["Copy the address (Ctrl+C) and open it in your browser."] = "Copia la direccion (Ctrl+C) y abrela en tu navegador."
	L["Installed:"] = "Instalados:"
	L["/stormrage minimap - show / hide the button"] = "/stormrage minimap - muestra / oculta el boton"
end
Stormrage.L = L

local addons = {}

-- Registers an addon in the menu. Returns true: the caller skips its own button.
function Stormrage.Register(info)
	if type(info) ~= "table" or type(info.name) ~= "string" then return false end
	for i, a in ipairs(addons) do
		if a.name == info.name then addons[i] = info return true end
	end
	addons[#addons + 1] = info
	table.sort(addons, function(a, b) return a.name:lower() < b.name:lower() end)
	if Stormrage.RefreshMenu then Stormrage.RefreshMenu() end
	return true
end

function Stormrage.Addons()
	return addons
end

Stormrage.version = VERSION

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff8fb8ffStormrage|r: " .. msg)
end

---------------------------------------------------------------- website popup

StaticPopupDialogs["STORMRAGE_SITE"] = {
	text = L["The realm's website"] .. "\n\n" .. L["Copy the address (Ctrl+C) and open it in your browser."],
	button1 = OKAY,
	hasEditBox = 1,
	editBoxWidth = 260,
	OnShow = function(self)
		local eb = self.editBox or _G[self:GetName() .. "EditBox"]
		eb:SetText("https://" .. SITE)
		eb:HighlightText()
		eb:SetFocus()
	end,
	EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

---------------------------------------------------------------- menu

-- A small frame of its own instead of UIDropDownMenu, which taints the
-- default UI in 3.3.5 when addons open it.
local menu
local rows = {}
local ROW, ACTION, WIDTH = 34, 18, 250

local function HideMenu()
	if menu then menu:Hide() end
end

local function RowOnClick(self, mouse)
	HideMenu()
	if self.kind == "addon" then
		if self.addon.onClick then self.addon.onClick(mouse) end
	elseif self.kind == "action" then
		self.action.func()
	elseif self.kind == "site" then
		StaticPopup_Show("STORMRAGE_SITE")
	end
end

local function RowOnEnter(self)
	if self.kind ~= "addon" or not self.addon.tooltip then return end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:AddLine(self.addon.name)
	self.addon.tooltip(GameTooltip)
	GameTooltip:Show()
end

local function Row(i)
	local r = rows[i]
	if r then return r end
	r = CreateFrame("Button", nil, menu)
	r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(26, 26)
	r.icon:SetPoint("LEFT", 4, 0)
	r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
	r.name:SetPoint("RIGHT", -4, 0)
	r.name:SetJustifyH("LEFT")
	r.desc = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
	r.desc:SetPoint("RIGHT", -4, 0)
	r.desc:SetJustifyH("LEFT")
	r:SetScript("OnClick", RowOnClick)
	r:SetScript("OnEnter", RowOnEnter)
	r:SetScript("OnLeave", GameTooltip_Hide)
	rows[i] = r
	return r
end

local function Layout()
	local y, n = -30, 0
	local function Place(r, height)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", 10, y)
		r:SetSize(WIDTH - 20, height)
		r:Show()
		y = y - height
	end
	for _, a in ipairs(addons) do
		n = n + 1
		local r = Row(n)
		r.kind, r.addon, r.action = "addon", a, nil
		r.icon:SetTexture(a.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
		r.icon:Show()
		r.name:SetText(a.name)
		r.name:SetFontObject(GameFontNormal)
		r.desc:SetText(a.description or "")
		Place(r, ROW)
		for _, act in ipairs(a.actions or {}) do
			n = n + 1
			local s = Row(n)
			s.kind, s.addon, s.action = "action", a, act
			s.icon:Hide()
			s.name:SetText("     " .. act.text)
			s.name:SetFontObject(GameFontHighlightSmall)
			s.desc:SetText("")
			Place(s, ACTION)
		end
	end
	if #addons == 0 then
		menu.empty:Show()
		y = y - 24
	else
		menu.empty:Hide()
	end
	n = n + 1
	local site = Row(n)
	site.kind, site.addon, site.action = "site", nil, nil
	site.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
	site.icon:Show()
	site.name:SetText(L["The realm's website"])
	site.name:SetFontObject(GameFontNormal)
	site.desc:SetText(SITE)
	y = y - 6
	Place(site, ROW)
	for i = n + 1, #rows do rows[i]:Hide() end
	menu:SetHeight(-y + 12)
end

local function CreateMenu()
	menu = CreateFrame("Frame", "StormrageMenu", UIParent)
	menu:SetWidth(WIDTH)
	menu:SetFrameStrata("DIALOG")
	menu:SetClampedToScreen(true)
	menu:EnableMouse(true)
	menu:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	menu:SetBackdropColor(0.05, 0.05, 0.1, 0.95)
	local title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 14, -10)
	title:SetText("|cff8fb8ffStormrage|r")
	menu.empty = menu:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	menu.empty:SetPoint("TOPLEFT", 14, -34)
	menu.empty:SetText(L["No Stormrage addons installed yet."])
	local close = CreateFrame("Button", nil, menu, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	menu:Hide()
	tinsert(UISpecialFrames, "StormrageMenu")
end

function Stormrage.RefreshMenu()
	if menu and menu:IsShown() then Layout() end
end

-- Opens the menu next to `anchor` (the minimap button), or at the cursor.
function Stormrage.ToggleMenu(anchor)
	if not menu then CreateMenu() end
	if menu:IsShown() then menu:Hide() return end
	Layout()
	menu:ClearAllPoints()
	if anchor then
		menu:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 8, 8)
	else
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / s, y / s)
	end
	menu:Show()
end

---------------------------------------------------------------- minimap button

local mm

local function Position()
	local angle = math.rad(StormrageHubDB.minimap.angle)
	mm:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(angle), 80 * math.sin(angle))
end

local function UpdateButton()
	if StormrageHubDB.minimap.hide then mm:Hide() else mm:Show() end
end

local function CreateMinimapButton()
	mm = CreateFrame("Button", "StormrageMinimapButton", Minimap)
	mm:SetSize(31, 31)
	mm:SetFrameStrata("MEDIUM")
	mm:SetFrameLevel(8)
	mm:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local icon = mm:CreateTexture(nil, "BACKGROUND")
	icon:SetTexture(ICON)
	icon:SetSize(20, 20)
	icon:SetPoint("TOPLEFT", 7, -5)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
	local border = mm:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(53, 53)
	border:SetPoint("TOPLEFT")
	mm:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mm:RegisterForDrag("LeftButton")
	mm:SetScript("OnClick", function(self)
		GameTooltip:Hide()
		Stormrage.ToggleMenu(self)
	end)
	mm:SetScript("OnDragStart", function(self)
		HideMenu()
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			StormrageHubDB.minimap.angle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			Position()
		end)
	end)
	mm:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	mm:SetScript("OnEnter", function(self)
		if menu and menu:IsShown() then return end
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine(L["Stormrage addons"])
		for _, a in ipairs(addons) do
			GameTooltip:AddDoubleLine(a.name, a.description or "", 1, 1, 1, 0.7, 0.7, 0.7)
		end
		GameTooltip:AddLine(L["Click: open the menu\nDrag: move"], 0.8, 0.8, 0.8)
		GameTooltip:Show()
	end)
	mm:SetScript("OnLeave", GameTooltip_Hide)
	Position()
	UpdateButton()
end

---------------------------------------------------------------- slash and startup

SLASH_STORMRAGE1 = "/stormrage"
SlashCmdList.STORMRAGE = function(msg)
	msg = (msg or ""):lower():match("^%s*(.-)%s*$")
	if msg == "minimap" then
		StormrageHubDB.minimap.hide = not StormrageHubDB.minimap.hide
		UpdateButton()
		return
	end
	if msg == "" then
		Stormrage.ToggleMenu(mm and mm:IsShown() and mm or nil)
		return
	end
	local names = {}
	for _, a in ipairs(addons) do names[#names + 1] = a.name end
	Print(L["Installed:"] .. " " .. (#names > 0 and table.concat(names, ", ") or "-"))
	Print(L["/stormrage minimap - show / hide the button"])
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
	if name ~= "Stormrage" then return end
	StormrageHubDB = StormrageHubDB or {}
	StormrageHubDB.minimap = StormrageHubDB.minimap or { angle = 195, hide = false }
	CreateMinimapButton()
	self:UnregisterEvent("ADDON_LOADED")
end)
