# Life Path Engine

**Three Roblox life-simulation RPGs built on one data-driven Luau engine.**

You are born into a family, a region and a bloodline, live one year per turn, make choices in yearly events, train toward a tier ladder, form relationships, die and reincarnate. The engine runs all three games. Each game is a content and theme layer on top of it.

| Folder | Game | Theme | Scripts | Lines |
|---|---|---|---|---|
| [`mm/`](mm) | **Motor Maestro**: *Life Path: Chasing Immortality* | Xianxia cultivation; the engine template, plus demo packs `modern_life` and `academy` | 212 | ~38,500 |
| [`sp/`](sp) | **SoulPath**: *Soul Path: Zanpakuto Dynasty* | Soul reapers, hollows and spirit archers | 193 | ~38,200 |
| [`cr/`](cr) | **Cursed Release**: *Cursed Path: Sorcerer Lineage* | Cursed-energy sorcery | 133 | ~25,900 |

SoulPath and Cursed Release are anime-inspired, but every character, place and item name is original. All three games share engine version 0.3 and the same schema keys, so a fix made in one can be ported to the others by copying files.

<!-- Screenshots: put images in docs/images/ and uncomment.
![Main screen](docs/images/main.png)
![Yearly event](docs/images/event.png)
![World map](docs/images/map.png)
-->

## Highlights

- **Plug-in gameplay modules.** A feature is a definition plus a server module. The engine wires its remotes, yearly ticks, effects, buffs and UI tab automatically, and disabling it in the manifest removes all of them. The Fame module and two whole game packs were added without editing the engine.
- **Data-driven content.** Every event, item, region, mentor, talent and title is a plain Lua table. A content validator checks ids, keys, chains and contracts at server start and in tests.
- **Automated tests:** 209 / 202 / 179 passing specs (Motor Maestro / SoulPath / Cursed Release), run by a 100-line test runner.
- **Balance simulation.** A bot-driven report simulates 20–60 lives under six play styles with seeded randomness and flags pacing problems and content that never fires.
- **Server-authoritative and hardened.** Every remote is type-checked, module-gated and rate-limited. Fuzzing (NaN, huge ids and tables, wrong types, floods) caused no server errors.
- **Safe saves.** `UpdateAsync` with a session lock, stale-lock takeover, autosave, a `BindToClose` budget and retries, verified against a mock two-server DataStore.
- **Deterministic.** All gameplay randomness goes through a seeded RNG, so a run can be replayed.
- **Responsive UI** for phone, tablet and desktop, with three layout styles, tooltips, a 3D void intro and a 3D gacha drum. Everything is built from GUI geometry, with no image assets.

---

## 1. What the player does

Each year you spend a few action points on training, study, work, socialising, travel, meditation, hunts or minigames, then press **+1 YEAR** or let auto-age run. On every birthday the engine:

1. Ages you and everyone in your life, then runs the education, career, NPC-autonomy, progression and world ticks in a fixed phase order.
2. Rolls yearly events from the enabled pools (everyday life, genre "fate" events and regional events). Each event has 2–3 choices, with success chances scaled by a stat, locked options that show their requirements, and immediate effects.
3. Applies scheduled story: follow-up events queued earlier (the same year or N years later, with the same person) and silent delayed consequences written to the journal.
4. Checks for death (old age scaled by genetics, health and regional hazards). Death opens the Wheel of Reincarnation.

**Progression** is a tier ladder driven by an energy stat:

| Game | Ladder | Energy | Advance |
|---|---|---|---|
| Motor Maestro | 9 cultivation realms | Qi | Breakthrough |
| SoulPath | 11 spiritual classes | Reiatsu | Soul Awakening |
| Cursed Release | 11 sorcerer grades | Cursed Energy | Grade Promotion |

Each tier has 9 levels, a breakthrough chance and a minimum number of years per level. The final tier allows Ascension, which shows an ending screen and grants a permanent title. Balance target: a fresh life peaks at tier 4–5, which the balance report verifies.

**Between lives** a meta layer persists:
- A meta currency.
- Gacha spins for bloodlines and innate talents, with bloodline locks.
- Permanent Samsara upgrades.
- A Collection Codex: +1% stat XP and energy for every race, talent, title or technique ever obtained.
- A family tree with heirs and grandchildren you can be reborn as.
- Rebirth paths (direct descendant, a stranger in the same era, an ancient era, a century later).
- A hall of legends.

## 2. Engine architecture

```
ReplicatedStorage
  Configs/        all content as plain Lua tables + GameManifest + UIThemeConfig
                  (palette, fonts, layout style and every genre word as a Term); BigNum
  GamePacks/      (Motor Maestro) one folder per game pack: manifest + overridden modules
  Shared/         Content (pack resolution, Extends chains, patching), GamePack
                  (manifest, module registry, effect/buff/requirement contracts),
                  EngineModules/, Requirements, ContentValidator, PackTheme, Gacha,
                  CombatMath, LineageMemory, GeneticsText, PortraitFrames,
                  ThemeSwitcher, ModalShield, Responsive, WheelSpinner, UIStyle, UITheme
  Docs/           ARCHITECTURE (design, milestones, decisions), BALANCE, AUDIT
ReplicatedFirst
  IntroAndLoadingUI   loading screen, 3D void intro, character creation, prologue
ServerScriptService
  GameManager     remote entry point; validates content at boot; wires remotes
  AgingSystem     +1 Year and auto-age loop
  DevConsoleServer  in-game developer console
  Modules/        PlayerState, YearSystem, LifeEventsEngine, SystemRegistry, Rng,
                  one System module per gameplay feature
  Tests/          TestRunner + 29-33 *Spec modules per game
  Tools/          BalanceReport
StarterGui
  LifePathUI      UIController + one ModuleScript per page/modal
StarterPlayer/StarterPlayerScripts
  ResponsiveUI, SoundFX, UIJuiceAnimator, VoidScene, DevConsoleClient
```

The game is entirely UI-driven. The Workspace holds only a baseplate and spawn, and Lighting provides the sky, atmosphere and post-processing for the 3D void scene. There are 20 RemoteEvents: client-to-server intentions, plus server-to-client snapshots and feedback cues.

**Plug-in modules.** A gameplay module is a definition in `Shared/EngineModules` (id, the requirements it adds, effect keys, buff keys, an optional tab) plus a server module with the attribute `System = true`. That server module exports hooks: `YearTicks` (with phase and order), `Remotes` (with validation), `Effects` and `AfterChange`. From there:
- `GamePack` builds the registries.
- `YearSystem` runs the ticks.
- `GameManager` wires the remotes.
- `LifeEventsEngine` applies the effects.
- The UI clones the tab.

**Content contracts.** These are the single sources of truth that the validator enforces: `Requirements.Fields`, `GamePack.EffectKeys`, `GamePack.BuffKeys` and `GamePack.RequirementModules`.

## 3. Gameplay systems

- **Core:** 6 attributes (XP curve, cap 60), 3 proficiencies, health, happiness, stress, money, yearly events, journal, death and rebirth.
- **Training / Cultivation / Progression:** actions with yearly caps, age windows and requirements; meditation; breakthroughs that can fail with injuries; mastery points; Ascension.
- **Education & Careers:** automatic schooling, then university, graduate studies and the genre academy. Includes tuition, grades, honors, part-time and full-time careers with salary, stress and performance, and schooling extras.
- **Masters:** mentors found per region, acceptance requirements, loyalty and quests, a legendary technique at 60 loyalty, and five faction ranks with stipends and trials.
- **Relationships:** family, friends, rivals, partners and children. Affection has thresholds and yearly drift, and there are about 30 interactions. Family help is exploit-tested. Adults can duel for pride, wealth or life stakes.
- **NPC autonomy:** every person acts once a year, choosing by weight from personality (12 types), goals (10), affection and memories. They pursue careers, marry, have children, move, visit, give gifts and loans, brawl, gossip, sabotage and issue challenges. Their memories show on their card.
- **Dynasty & Genetics:** bloodlines, genetic grades and hereditary traits. Children inherit bloodline (with mutation), talent, trait, upbringing and potential. You can be reborn as an heir or a grandchild. There are ancestral heirlooms, and lineage memory fades over generations.
- **Lineages / Wheel / Samsara:** bloodline gacha with 5 rarities (65/24/8/2.5/0.5) and pity at spins 15 and 60, talent slots, locks, a 3D spinning drum and permanent upgrades.
- **Titles** (two equipped at once), **Masteries** (4 branches × 8 nodes), **Inventory** (consumables with limits, 3 equipment slots, legendary weapons, a market) and a **World map** (12–20 regions with roads, tolls, hazards, mentors and regional events).
- **2.0 systems** (Motor Maestro and SoulPath only): a Chronicle HUD, skills, spell schools and elements, turn-based battles against 22 enemies and bosses, minigames, World History eras, Legends and relics, a World Hub with crafting, raids, a journal with 86 goals and 16 daily quests, cosmetics and a guided tutorial.

## 4. Content

Engine ids never change. Players see each game's own words through `UIThemeConfig.Terms`: for example "Qi", "Reiatsu" or "Cursed Energy" for the same energy stat, and "Breakthrough", "Soul Awakening" or "Grade Promotion" for the same advance.

| Pool | Motor Maestro | SoulPath | Cursed Release |
|---|---|---|---|
| Yearly / fate / travel events | 76 / 28 / 20 | 76 / 28 / 28 | 71 / 28 / 21 |
| Regions | 12 | 20 | 12 |
| Bloodlines / mentors | 22 / 14 | 28 / 14 | 28 / 14 |
| Items (market stock) | 58 (28) | 74 (33) | 42 (30) |
| Talents / titles | 36 / 76 | 36 / 76 | 36 / 38 |
| Training actions / masteries | 34 / 32 | 34 / 32 | 26 / 32 |
| Careers / interactions | 16 / 28 | 16 / 28 | 16 / 30 |
| Enemies / skills / spell schools | 22 / 53 / 3 | 22 / 53 / 3 | – |
| NPC personalities / goals / actions | 12 / 10 / 26 | 12 / 10 / 26 | 12 / 10 / 26 |

## 5. Client and UX

- **One UIController with pages:** Train, Study, Masters, Bonds, Lineage, Bag, Chronicle, Samsara, World map, Family Tree, Journal, Progression and Shop.
- **Modals** for events, duels, battles, minigames, the Wheel and the shop.
- **Three layout styles:** a classic three-column layout, Dossier and SoulPass.
- **Phone rules:** landscape lock, two-row icon tabs and larger touch rows.
- **Tooltips:** hover on desktop, tap on touch.
- **A modal shield** under every popup, so no click leaks through to the screen behind it.
- **Progressive disclosure:** actions and tabs stay hidden until the character is old enough for them.
- **Presentation:** a staged loading screen, a 3D void intro, sound cues, screen shake and an ascension ending.

## 6. Authority, saves, monetization

The server owns all state. The client only renders snapshots and sends intentions. Every remote is rate-limited and refused while the player is dead or an event is pending.

Saves use `UpdateAsync` with a session lock (owner session id + timestamp):
- If a second live server tries to load the same player, the player is kicked with a message.
- Locks older than 300 s are taken over, and the old server turns read-only.
- Autosave runs every 120 s.
- On shutdown, a parallel `BindToClose` saves everyone within a 25 s budget.
- Errors get 3 retries; permanent errors get none.
- Save version 2 uses additive fields, so no migrations are needed.

Monetization is fully implemented (passes, developer products, cosmetics and redeem codes: 59 purchases in Motor Maestro and SoulPath, 8 in Cursed Release). Paid power is bounded: extra actions stay within the action cap, and revival works once per life. All product ids are still `0` until the games are published.

## 7. Quality tooling

- **Tests:** specs cover BigNum, requirements, the validator, event chains, economy exploits, inventory, NPC simulations, genetics, the session lock, gacha pity, game packs, themes, the dev console and the balance report itself. Run `ServerScriptService.Tests.TestRunner` in Studio (Run mode).
- **Balance report:** `ServerScriptService.Tools.BalanceReport` runs six bot policies (Idle, Greedy, Focused, Balanced, Random, Specialist) from a seed.
- **Content validator:** runs at server start and flags unknown ids and keys, duplicates, unreachable chain events, items with no source and map contract violations.
- **Developer console:** in-game commands for systems and tick order, passes, test purchases, seeds and pack info.

## 8. Development history

| Date (2026) | Milestone |
|---|---|
| Oct 23–24 | Content loader and game packs, event chains, NPC autonomy, inventory, portability audit, balance tuning |
| Oct 24 | Genetics, heirs, grandchildren, adult duels, Ascension |
| Oct 25 | Launch layer (passes, products, revival); Cursed Release and SoulPath derived from the engine |
| Oct 30–31 | Engine sync back into the template; 2.0 systems: HUD, skills, magic, battles, history, legends, raids, journal, store |
| Nov 2 | SoulPath ported to the 2.0 build; content doubled in all three games |
| Nov 10 | Repository verified identical to the three Studio places |

Development was AI-assisted (Claude Code driving Roblox Studio through an MCP plugin).

## 9. Repository layout and running it

```
mm/ sp/ cr/                  one folder per game, a mirror of the place
  ReplicatedFirst/  ReplicatedStorage/  ServerScriptService/
  StarterGui/LifePathUI/     UIController + pages + modals
  StarterPlayer/StarterPlayerScripts/
  StarterGui/LifePathUI.build.json   (mm, sp) exported GUI instance tree
motor-maestro.project.json   Rojo project files, one per game
soulpath.project.json
cursed-release.project.json
```

File names follow [Rojo](https://rojo.space) conventions (`.server.luau`, `.client.luau`, `.luau` for ModuleScripts, `init.*` for scripts with children). To sync a game's code into an open place:

```bash
rojo serve motor-maestro.project.json
```

The project files sync **code only**. The GUI frame layout, remotes and lighting live in the place itself. Unknown instances are kept (`$ignoreUnknownInstances`), so syncing never deletes them.

## License

Copyright © 2026. All rights reserved. The code is published for portfolio viewing; see [LICENSE](LICENSE).
