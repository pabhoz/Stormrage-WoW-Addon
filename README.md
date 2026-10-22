<div align="center">

# ⚔️ Stormrage

**One minimap button for every Stormrage addon.**

![WoW 3.3.5a](https://img.shields.io/badge/WoW-3.3.5a%20(WotLK)-8a2be2)
![Interface 30300](https://img.shields.io/badge/Interface-30300-blue)
![License: GPL v3](https://img.shields.io/badge/License-GPLv3-green)

</div>

---

**EN** — Install it next to [Soulstone](https://github.com/pabhoz/Soulstone-WoW-Addon), [Smart Cast](https://github.com/pabhoz/SmartCast-WoW-Addon) and [Tactics Coach](https://github.com/pabhoz/TacticsCoach-WoW-Addon) and they stop adding a button each: one ⚔️ button opens a menu with all of them, their quick actions (save your character, copy your other spec's bars, choose your Smart Cast spells…) and the realm's website. Without it, every addon keeps its own button, exactly as before. `/stormrage` opens the menu, `/stormrage minimap` hides the button.

**ES** — Instálalo junto a [Soulstone](https://github.com/pabhoz/Soulstone-WoW-Addon), [Smart Cast](https://github.com/pabhoz/SmartCast-WoW-Addon) y [Tactics Coach](https://github.com/pabhoz/TacticsCoach-WoW-Addon) y dejan de poner un botón cada uno: un solo botón ⚔️ abre un menú con todos, sus acciones rápidas (guardar tu personaje, copiar las barras de tu otro spec, elegir los hechizos de Smart Cast…) y el sitio del reino. Sin él, cada addon conserva su botón como siempre. `/stormrage` abre el menú y `/stormrage minimap` oculta el botón.

## For addon authors / Para autores de addons

Any addon can join the menu. Add `## OptionalDeps: Stormrage` to your `.toc` and, once your saved variables are loaded:

```lua
local hub = type(Stormrage) == "table" and Stormrage.Register and Stormrage.Register({
  name = "My Addon",
  icon = "Interface\\Icons\\INV_Misc_QuestionMark",
  description = "One short line",
  onClick = function(mouseButton) MyAddon_Toggle() end,
  tooltip = function(tooltip) tooltip:AddLine("Extra info") end,  -- optional
  actions = { { text = "Do something", func = MyAddon_Something } }, -- optional
})
if not hub then MyAddon_CreateMinimapButton() end
```

## Installation

Unzip into `World of Warcraft/Interface/AddOns/` so that you get `Interface/AddOns/Stormrage/Stormrage.toc`.

## License

GPL-3.0-or-later. See [LICENSE](LICENSE).
