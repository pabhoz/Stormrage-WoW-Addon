-- Stormrage hub tests with a simulated 3.3.5a UI. Run from the addon folder:
-- lua5.1 tests/run.lua   (tests/run.sh does it in Docker)

local passed = 0
local function check(cond, msg)
	if not cond then error("FAIL: " .. msg, 2) end
	passed = passed + 1
	print("ok  " .. msg)
end

local noop = function() end
local function Stub(t) return setmetatable(t or {}, { __index = function() return noop end }) end

local frames, created = {}, {}
function CreateFrame(kind, name, parent)
	local f = Stub({ scripts = {}, events = {}, shown = true, name = name })
	function f:SetScript(k, fn) self.scripts[k] = fn end
	function f:RegisterEvent(e) self.events[e] = true end
	function f:UnregisterEvent(e) self.events[e] = nil end
	function f:Hide() self.shown = false end
	function f:Show() self.shown = true end
	function f:IsShown() return self.shown end
	function f:SetHeight(h) self.height = h end
	function f:CreateFontString()
		local fs = Stub({})
		function fs:SetText(t) self.text = t end
		return fs
	end
	function f:CreateTexture() return Stub({}) end
	frames[#frames + 1] = f
	if name then _G[name] = f created[name] = f end
	return f
end
function GetLocale() return "esES" end
function GetCursorPosition() return 0, 0 end
DEFAULT_CHAT_FRAME = { AddMessage = noop }
UIParent = Stub({ GetEffectiveScale = function() return 1 end })
Minimap = Stub({})
GameTooltip = Stub({})
StaticPopupDialogs, UISpecialFrames, SlashCmdList = {}, {}, {}
local popups = {}
function StaticPopup_Show(name) popups[#popups + 1] = name end
function tinsert(t, v) t[#t + 1] = v end

dofile("Stormrage.lua")

local function fire(event, ...)
	for _, f in ipairs(frames) do
		if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
	end
end

-- an addon that loads after the hub (OptionalDeps) registers right away
local clicks, acted = {}, 0
check(Stormrage.Register({
	name = "Smart Cast", icon = "x", description = "d",
	onClick = function(b) clicks[#clicks + 1] = b end,
	actions = { { text = "Choose", func = function() acted = acted + 1 end } },
}) == true, "Register returns true so the addon skips its own button")
check(Stormrage.Register({ name = "Soulstone" }) == true, "a second addon registers")
check(Stormrage.Register({}) == false, "an entry without a name is refused")
Stormrage.Register({ name = "Soulstone", description = "new" })
check(#Stormrage.Addons() == 2 and Stormrage.Addons()[2].description == "new", "registering twice replaces the entry")
check(Stormrage.Addons()[1].name == "Smart Cast", "sorted by name")

fire("ADDON_LOADED", "Stormrage")
check(created.StormrageMinimapButton and created.StormrageMinimapButton.shown, "one minimap button")

-- open the menu from the button
created.StormrageMinimapButton.scripts.OnClick(created.StormrageMinimapButton, "LeftButton")
local menu = created.StormrageMenu
check(menu and menu.shown, "click opens the menu")
local visible = {}
for _, f in ipairs(frames) do
	if rawget(f, "kind") and f.shown then visible[#visible + 1] = f end
end
-- rows: Smart Cast, its action, Soulstone, website
check(#visible == 4, "menu rows: addon, action, addon, website (" .. #visible .. ")")
check(visible[1].kind == "addon" and visible[2].kind == "action" and visible[4].kind == "site", "rows in order")

visible[1].scripts.OnClick(visible[1], "RightButton")
check(clicks[1] == "RightButton" and not menu.shown, "addon row passes the mouse button and closes the menu")
SlashCmdList.STORMRAGE("")
visible[2].scripts.OnClick(visible[2], "LeftButton")
check(acted == 1, "action row runs its function")
SlashCmdList.STORMRAGE("")
visible[4].scripts.OnClick(visible[4], "LeftButton")
check(popups[1] == "STORMRAGE_SITE", "website row shows the address to copy")

SlashCmdList.STORMRAGE("minimap")
check(StormrageHubDB.minimap.hide == true and not created.StormrageMinimapButton.shown, "/stormrage minimap hides the button")

print(("all %d passed"):format(passed))
