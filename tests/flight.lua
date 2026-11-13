-- Flying mount panel tests with a simulated 3.3.5a UI and a fake realm running mod-azeroth-flight.
-- Run from the addon folder: lua5.1 tests/flight.lua   (tests/run.sh does it in Docker)

local passed = 0
local function check(cond, msg)
	if not cond then error("FAIL: " .. msg, 2) end
	passed = passed + 1
	print("ok  " .. msg)
end

local noop = function() end
local function Stub(t) return setmetatable(t or {}, { __index = function() return noop end }) end

local frames, created = {}, {}
local function NewFrame(kind, name)
	local f = Stub({ scripts = {}, events = {}, shown = true, name = name, enabled = true })
	function f:SetScript(k, fn) self.scripts[k] = fn end
	function f:HookScript(k, fn) self.scripts[k] = fn end
	function f:RegisterEvent(e) self.events[e] = true end
	function f:Hide() self.shown = false end
	function f:Show() self.shown = true if self.scripts.OnShow then self.scripts.OnShow(self) end end
	function f:IsShown() return self.shown end
	function f:Enable() self.enabled = true end
	function f:Disable() self.enabled = false end
	function f:SetText(t) self.text = t end
	function f:GetText() return self.text end
	function f:CreateFontString()
		local fs = Stub({})
		function fs:SetText(t) self.text = t end
		function fs:Show() self.shown = true end
		function fs:Hide() self.shown = false end
		return fs
	end
	function f:CreateTexture()
		local t = Stub({})
		function t:SetTexture(p) self.path = p end
		function t:Show() self.shown = true end
		function t:Hide() self.shown = false end
		return t
	end
	frames[#frames + 1] = f
	if name then _G[name] = f created[name] = f end
	return f
end
function CreateFrame(kind, name) return NewFrame(kind, name) end

function GetLocale() return "esES" end
function GetCursorPosition() return 0, 0 end
function GetTime() return now end
now = 100
function UnitName() return "Thrall" end
function GetActiveTalentGroup() return 1 end
local TREES = { { "Sagrado", "IconHoly" }, { "Proteccion", "IconProt" }, { "Reprension", "IconRet" } }
function GetTalentTabInfo(tab) return TREES[tab][1], TREES[tab][2], tab == 3 and 51 or 10 end
DEFAULT_CHAT_FRAME = { AddMessage = noop }
UIParent = Stub({ GetEffectiveScale = function() return 1 end })
Minimap = Stub({})
GameTooltip = Stub({})
YES, NO, OKAY = "Si", "No", "Ok"
StaticPopupDialogs, UISpecialFrames, SlashCmdList = {}, {}, {}
local popups = {}
function StaticPopup_Show(which, text)
	local d = { which = which, text = text }
	popups[#popups + 1] = d
	return d
end
function tinsert(t, v) t[#t + 1] = v end

local SPELLS = { [32242] = "Grifo presto azul", [61229] = "Draco de escarcha", [458] = "Caballo marron" }
function GetSpellInfo(id) return SPELLS[id] end
local chatLines = {}
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) chatLines[#chatLines + 1] = m end }

-- the client's Mounts tab (FrameXML PetPaperDollFrame, 3.3.5a)
local MOUNTS = { { 1001, 458 }, { 1002, 61229 }, { 1003, 32242 } }   -- creatureID, spell
function GetCompanionInfo(mode, i) local m = MOUNTS[i] if m then return m[1], "x", m[2], "icon", false end end
function GetNumCompanions() return #MOUNTS end
PetPaperDollFrame = NewFrame("Frame", "PetPaperDollFrame") PetPaperDollFrame.shown = false
PetPaperDollFrameCompanionFrame = NewFrame("Frame", "PetPaperDollFrameCompanionFrame")
PetPaperDollFrameCompanionFrame.shown = false
CompanionModelFrame = NewFrame("Frame", "CompanionModelFrame")
function PetPaperDollFrame_FindCompanionIndex(id) for i, m in ipairs(MOUNTS) do if m[1] == id then return i end end return 0 end
local hooks = {}
function PetPaperDollFrame_UpdateCompanions() for _, h in ipairs(hooks) do h() end end
function hooksecurefunc(name, fn) assert(name == "PetPaperDollFrame_UpdateCompanions") hooks[#hooks + 1] = fn end
local toggled, tabSet = 0, nil
function ToggleCharacter(tab) toggled = toggled + 1 PetPaperDollFrame.shown = true end
function PetPaperDollFrame_SetTab(id) tabSet = id PetPaperDollFrameCompanionFrame.mode = "MOUNT" PetPaperDollFrameCompanionFrame:Show() end
local function select(creature) PetPaperDollFrameCompanionFrame.idMount = creature PetPaperDollFrame_UpdateCompanions() end

-- the realm: answers ".volar ..." on the addon channel like AzerothCore + mod-azeroth-flight
local realm = { flying = { { 61229, 280 }, { 32242, 280 } }, chosen = 0, enabled = true, mounted = 0 }
local sent = {}
function SendAddonMessage(prefix, msg, channel, target)
	sent[#sent + 1] = { prefix = prefix, msg = msg, channel = channel, target = target }
	local id, cmd = msg:sub(2, 5), msg:sub(6)
	local out, ok = {}, true
	local function m(text) out[#out + 1] = "m" .. id .. text end
	if not realm.enabled then
		m("There is no such command.") ok = false
	elseif #realm.flying == 0 then
		m("No conoces ninguna montura voladora.") ok = false
	elseif cmd == "volar lista" then
		m("M;" .. realm.chosen)
		for _, v in ipairs(realm.flying) do m("V;" .. v[1] .. ";" .. v[2]) end
	elseif cmd:match("^volar elegir %d+$") then
		local s = tonumber(cmd:match("%d+"))
		local known = false
		for _, v in ipairs(realm.flying) do if v[1] == s then known = true end end
		if known then realm.chosen = s m("Desde ahora Volar usa algo.") else m("No conoces esa montura voladora.") ok = false end
	elseif cmd == "volar" then
		realm.mounted = realm.mounted + 1
	end
	out[#out + 1] = (ok and "o" or "f") .. id
	for _, reply in ipairs(out) do
		for _, f in ipairs(frames) do
			if f.events.CHAT_MSG_ADDON then f.scripts.OnEvent(f, "CHAT_MSG_ADDON", prefix, reply, "WHISPER", "Thrall") end
		end
	end
end

dofile("Stormrage.lua")
dofile("Channel.lua")
dofile("Flight.lua")

local F = Stormrage.Flight
local button = created.StormrageFlightButton

local listed
for _, a in ipairs(Stormrage.Addons()) do if a.name == "Montura de vuelo" then listed = a end end
check(listed and listed.onClick, "the hub lists it")
check(button and not button.shown, "a hidden button is attached to the Mounts tab model")

local l = F.ParseList({ "M;32242", "V;61229;280", "V;32242;280", "garbage" })
check(l and l.chosen == 32242 and l.flying[61229] == 280, "parses .volar lista")
check(F.ParseList({ "No conoces ninguna montura voladora." }) == nil, "no list without the header")

-- the hub (and /vuelo) open the character window on the Mounts tab, which asks the realm
listed.onClick("LeftButton")
check(toggled == 1 and tabSet == 3, "the hub opens the Mounts tab")
check(sent[#sent].msg:match("^i%d%d%d%dvolar lista$") and sent[#sent].target == "Thrall", "showing the tab asks the realm silently")

-- a ground mount: no button; the line says what the spell uses
select(1001)
check(not button.shown, "no button on a ground mount")

-- a flying mount: the button sets it, without mounting
select(1003)
check(button.shown and button.enabled and button.text == "Usar en Azeroth", "a flying mount shows Usar en Azeroth")
button.scripts.OnClick(button)
check(sent[#sent].msg:match("volar elegir 32242$") and realm.chosen == 32242 and realm.mounted == 0, "the click chooses it and does not mount")
check(button.text == "Se usa en Azeroth" and not button.enabled, "on the chosen one it says so and is disabled")
check(chatLines[#chatLines]:match("Alas de los Condenados usara Grifo presto azul"), "the chat confirms it")

-- another flying mount can take its place
select(1002)
check(button.shown and button.enabled and button.text == "Usar en Azeroth", "another flying mount can be chosen")

-- the tab on companions (critters) hides it
PetPaperDollFrameCompanionFrame.mode = "CRITTER"
PetPaperDollFrame_UpdateCompanions()
check(not button.shown, "hidden on the companions tab")
PetPaperDollFrameCompanionFrame.mode = "MOUNT"

-- no flying mounts, or a realm without the module: nothing shows
realm.flying = {}
F.Refresh()
select(1003)
check(not button.shown, "without flying mounts nothing shows")
realm.flying, realm.enabled = { { 32242, 280 } }, false
F.Refresh()
check(not button.shown, "a realm without the module shows nothing")

SlashCmdList.STORMRAGEFLIGHT("")
check(tabSet == 3 and toggled >= 1, "/vuelo opens the Mounts tab")

print(("all %d passed"):format(passed))
