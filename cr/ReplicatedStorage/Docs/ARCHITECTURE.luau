--[[
================================================================================
 UNIVERSAL LIFE SIMULATION ENGINE - ARCHITECTURE NOTES        (engine 0.3.0)
 Standalone game "Cursed Path: Sorcerer Lineage" (jujutsu sorcery RPG, converted
 2026-10-25 from the cultivation game with the same mechanics, numbers and schema
 keys; single mode, the multi-pack template lives in an external backup).
 Milestones 3 (event chains), 4 (NPC autonomy), 5 (inventory & items) and the
 portability audit included.
================================================================================

LAYOUT
  ReplicatedStorage
    Configs/            All content + GameManifest ("cursed_path_sorcerer") +
                        UIThemeConfig (look and vocabulary). BigNum also lives here.
    Shared/             Engine code usable by server and client:
                          Content (resolves content modules from Configs),
                          PackTheme (theme + Terms for UI and server messages),
                          GamePack (manifest, module registry, contracts),
                          EngineModules/ (one definition per engine module),
                          Requirements (condition checker), ContentValidator,
                          UIStyle (palette, factories), UITheme (bespoke frames),
                          Gacha (spins with pity)
    Remotes/            Client -> server intentions, server -> client snapshots
    Docs/               This file
  ServerScriptService
    GameManager         Remote entry point; validates the content at startup
    AgingSystem         Advance Year button + optional auto-age loop
    Modules/            PlayerState (state, buffs, saves), YearSystem (one year),
                        LifeEventsEngine, SystemRegistry (discovers System = true
                        modules: Training/Cultivation/Master/Career/Relationship/
                        Npc/Progression/Inventory/Fame systems), DevConsole, Rng
    Tests/              TestRunner + *Spec modules
    Tools/              BalanceReport (multi-policy simulation, see Docs/BALANCE)
  StarterGui
    LifePathUI          UIController + one ModuleScript per tab
    LifePathBackdrop    Full-screen background

THIS GAME: CURSED PATH: SORCERER LINEAGE (display names over engine keys)
  The conversion renamed content only; code identifiers, state fields, config keys
  and save fields keep their engine names. Engine key -> what the player sees:
    Qi / QiMult / QiControl   Cursed Energy (CE) / CE gain / "CE Manipulation" stat
    Realm, SubLevel           Sorcerer Grade (11 tiers: Non-Sorcerer, Grade 4, Grade 3,
                              Semi-Grade 2, Grade 2, Semi-Grade 1, Grade 1, Special Grade,
                              Special Grade: Domain Sovereign, Special Grade: The Honored
                              One, Heian Calamity), 9 levels each
    Breakthrough              Grade Promotion (button PROMOTION; ASCEND -> TRANSCEND)
    Karma (state.Karma)       Binding Vows (meta currency, icon ❖)
    Money                     Yen (¥; same amounts as before)
    Race / Bloodline          Sorcerer Clan; Legacy = Innate Origin; Heirloom = Cursed Tool
    Spirit Root (grade/flag)  Cursed Energy Trait; flag SpiritRoot = the cursed energy test
    Proficiencies Sword/Spear/QiArts   Cursed Tools / Taijutsu / Barrier & Domain Arts
    Masters / Sect            Mentors / Jujutsu Faction (MentorName, StudentName terms)
    Samsara / Wheel           Rebirth / Wheel of Curses (Cursed Reincarnation)
  Rarity keys stay Common/Rare/Epic/Legendary/Mythic; display names (Common,
  Uncommon, Rare, Legendary, Mythic) come from Spin.Rarities[key].Name
  (RacesConfig.RarityName, Gacha.RarityName). Every word above is a Term in
  Configs/UIThemeConfig (see THEME & TERMINOLOGY).

AUTHORITY AND SECURITY
  The server owns all state. The client renders PlayerState.Snapshot and sends
  intentions; every request is validated (argument types, module enabled,
  alive, no pending event, rate limit, requirements, costs).
  Every remote is rate-limited, including GetState (1/s), SetAutoAge and
  Reincarnate (0.5 s); reincarnation stops reading oversized talent lists.
  Live probes (NaN/inf indexes, 10K-char ids, 5K-entry tables, wrong types,
  request floods) produced no server errors and no state changes.
  Saves: a player leaving during load never registers a state; SetAsync is
  retried 3 times; BindToClose saves all players in parallel (25 s budget).
  Session locking: every load and save goes through UpdateAsync on the same
  record, which carries _Lock = { Owner = SessionId, Time }. Load takes the
  lock (3 tries); if another live server holds it the player is kicked with
  "Your save is still open on another server". Saves write only while this
  server owns the lock and refresh Time (autosave every 120 s); a lock older
  than LockTimeout (300 s) belongs to a crashed server and may be taken over,
  after which the old server goes read-only instead of overwriting. Leaving
  and shutdown save with release = true; read-only sessions release without
  writing. Legacy saves without _Lock load normally and gain a lock.
  Permanent errors (Studio without API access, 403) are not retried.
  SessionId = game.JobId, or a GUID in Studio where JobId is empty.
  Verified with Tests/MockDataStore (UpdateAsync semantics) simulating two
  servers: SessionLockSpec (exclusive hold, release/handoff, stale takeover,
  late save refused, new player, legacy save, read-only release, outage).
  Tests ship as ModuleScripts in ServerScriptService and run only on demand.

CONTENT LOADING
  Every system loads content with Content.Get("<Name>") (Configs/<Name>), never
  by requiring Configs directly, so a cloned place only edits Configs. There is
  one game per place: no pack folders, chains or runtime switching.

GAME MANIFEST AND MODULES
  GameManifest declares Id, Version, EngineVersion, Theme, Modules, EventPools,
  Interface (TabLabels, CounterNames) and Dependencies. Engine modules: Cultivation,
  Education, Careers, Masters, Relationships, Masteries, Titles, Lineages,
  NpcAutonomy, Inventory, and the optional add-on Fame.
  Core (always on): character, attributes, proficiencies, energy actions, money,
  meters, yearly events, journal, death and reincarnation.
  A disabled module is skipped everywhere: remotes are rejected, yearly ticks
  skipped, its buffs ignored, owned event effects ignored, event pools gated,
  training actions with `Module` hidden, and its tabs/panels hidden in the UI.
  "Active" = enabled and every module it Requires is active.

ADDING A GAMEPLAY MODULE (no engine edits)
  1. Shared/EngineModules/<Id>: Id, Name, Description, Requires, Optional,
     EffectKeys, RequirementFields, Requirements = { Field = fn(view, v) },
     Buffs = { Key = "add" | "mult" | "nested" }. GamePack builds Modules,
     EffectKeys, RequirementModules, RequirementEvaluators, BuffDefs/BuffKeys
     from this folder; Requirements and PlayerState.GetBuffs pick them up.
  2. ServerScriptService/Modules/<Name> with attribute System = true exporting
     Hooks (see SystemRegistry): YearTicks (Phase Systems|Growth, Order),
     Remotes (Module, Cooldown, Validate, Handle), Effects, AfterChange.
     YearSystem runs the phases, GameManager wires every remote (creating the
     RemoteEvent if missing), LifeEventsEngine applies Effects.
  3. Per-life data: PlayerState.ModuleData(state, Id, defaults); saved with the
     character, reset each life, sent to the client as Snapshot.Modules.
  4. The manifest opts in with Modules = { <Id> = true }; Optional modules left out
     of it are off without a warning.
  5. UI (optional): Tab = { Label, Order } in the definition plus a ModuleScript
     named Page inside it (Init(ctx, frame), Render(snapshot)). UIController
     clones a tab button, creates the page frame, places it by Order (built-in
     tabs are 10..80, so 65 sits before Journal) and shares the bar evenly
     between visible tabs. Inactive modules get no tab. Manifests may relabel it
     (Interface.TabLabels.<Id>). Settings in the definition keep server and page
     numbers in sync. The validator rejects a Tab without a Page.
  Proof: Fame (Shared/EngineModules/Fame + Modules/FameSystem) was added with no
  engine edit (Perform action, yearly decay, Fame event effect, MinFame title,
  FameMult buff, its own Fame tab); it is off in this game's manifest.
  Dev console: `systems` lists systems, year ticks in order, remotes, effects.

  Contracts content is written against (single sources of truth):
    Requirements.Fields        requirement keys (core + module evaluators)
    GamePack.EffectKeys        event effect keys (+ owning module)
    GamePack.BuffKeys          buff keys merged by PlayerState.GetBuffs
    GamePack.RequirementModules

EVENT CHAINS
  Option effects can schedule more story (see YearlyEventsConfig header):
    FollowUp = { Id, InYears }           next event now (0) or at a later birthday
    Delayed  = { InYears, Text, Effects } silent consequence logged to the journal
  Event fields: ChainOnly (never rolled yearly, only via FollowUp),
  Target = { Inherit = true } (reuse the parent's person; a person created by
  the parent with NewRelationship becomes the chain's target), Cooldown (years
  between repeats of a Repeatable event).
  Flow: Resolve -> ApplyEffects schedules into state.ScheduledEvents /
  ScheduledEffects -> each birthday YearSystem calls Engine.ProcessScheduled
  (before the death check) which applies due consequences and queues due
  follow-ups; queued follow-ups count toward MaxEventsPerYear. A chained entry
  is re-checked when presented (module enabled, not seen unless Repeatable,
  inherited person still alive, Requires) and silently dropped otherwise.
  Death and rebirth clear pending chains. Saves: the three new state lists are
  additive and default to empty, so SaveVersion stays 2 (no migration needed).
  Validator: unknown follow-up ids, bad InYears/Pool, Delayed without InYears or
  Effects, Inherit outside ChainOnly, unreachable ChainOnly events, follow-ups
  into disabled modules, Inherit with a parent that has no person.
  Shipped chains (ids, with this game's titles): stolen_notes -> notes_thief_returns
  (4y, same person), lost_wallet -> purse_owner ("The Owner Remembers", 2y),
  mugging -> watch_captain ("The Auxiliary Manager", same year), friend_in_need ->
  loan repaid (3y delayed), immortal_cave ("The Sealed Cursed Object") ->
  sect_reward ("The Higher-Ups' Reward", 1y) or Heian remnant awakening (5y delayed),
  sect_tournament ("The Domain Clash Tournament") -> poison_exposed (3y).

NPC AUTONOMY (module NpcAutonomy, requires Relationships)
  Modules/NpcSystem runs once per year from YearSystem, right after the
  relationship tick, and only over the character's own relationships (capped
  by RelationshipsConfig.MaxRelationships), so cost stays tiny.
  Profile (added lazily, also to old saves): Personality, Goal, Occupation,
  Retired, Married/Spouse, Children, Away, Memories (newest first, max 4).
  Choice: weighted random between IdleWeight and each allowed action of
  Configs/NpcBehaviorConfig, weight = Weight x personality x goal
  x affection (AffectionScale) x memories (MemoryBias). Filters: life Stages,
  relationship Categories/Types, When conditions.
  Actions change the NPC's life (job, promotion, marriage, children, moving
  away/back, retirement, drifting apart), affect the player (visits, gifts,
  rumors) or queue an existing life event about the NPC through
  Engine.TriggerFor (e.g. friend_in_need, rival_challenge); the event's own
  filters, repeats, cooldown, age window and requirements still apply.
  Caps per year: MaxJournalEntriesPerYear, MaxTriggeredEventsPerYear.
  Goals are replaced when their CompletedBy action happens.
  Memories come from NPC actions, player interactions (gift, argue, ask help,
  romance, duel, reconcile) and events changing affection by 10 or more; they
  are shown on relationship cards and bias future choices.
  Away people cannot use Spend Time. Contracts: GamePack.NpcEffectKeys and
  GamePack.NpcConditionKeys; the validator checks every reference.
  Observed over 15 simulated lives: 92 NPCs found work, 53 married, 44 moved
  away. By the character's death nearly all peers have died or drifted apart.

INVENTORY & ITEMS (module Inventory)
  Configs/ItemsConfig: Categories, equipment Slots (+ display names), Items and
  the market Shop list. Item: Price / SellPrice / MaxStack, MinAge, Requires,
  Module, Use = { Effects, UsesPerYear } (same effect schema as events, applied
  with Engine.ApplyEffects), Equip = { Slot, Buffs } (merged in GetBuffs).
  State: state.Inventory = { Items = { id = count }, Equipped = { slot = id },
  Uses = { id = n }, UsesAge }; old saves get an empty inventory, new lives
  start empty. Helpers: PlayerState.Inventory / ItemCount / AddItem (removing
  the last copy of an equipped item unequips it).
  Modules/InventorySystem: Buy / Sell / Use / Equip / Unequip, called through
  the InventoryAction remote with the usual act() validation.
  Content hooks: event effect Items = { id = count } (negative removes) and
  requirement Items = { id = count }. Shipped: Protective Omamori (lucky_charm) for
  returning the lost wallet, Sealed Calamity Finger (jade_bracelet) from the
  inheritance, the sealed cursed object's Prison Realm Fragment (ancient_talisman),
  which unlocks a safer choice in the Domain Expansion Clash (heavenly_tribulation).
  Equipment slots display as Cursed Tool / Uniform / Charm.
  UI: Inventory tab (equipped slots, bag with use / equip / sell, market with
  requirement hints).

ECONOMY: FAMILY HELP
  "Ask Help" from family is data-driven (RelationshipsConfig.FamilyHelp):
  pocket money to 11 (¥5-20), teen allowance to 17 (¥20-80), adult help
  (¥100-400), x (0.5 + affection / 200), x1.5 if the relative has a job (NPC
  autonomy). Relatives under 18 comfort instead of paying. Validated by the
  ContentValidator (ordered brackets, Min <= Max, full age coverage).
  Measured with the worst-case strategy (ask every relative every year, 30
  lives, median): family income by 13 went from ¥11,057 to ¥460 (market items
  affordable from it: 12 of 14 -> 3), by 18 from ¥18,784 to ¥1,463; adult help
  is about ¥1,100 per year across all relatives. EconomySpec keeps this as a
  regression test (by 13 <= 1,000 and <= half the market; by 18 <= 3,000).

CREATING A NEW GAME (clone this place)
  1. Clone the place; change Configs/GameManifest (new Id, Name, Modules flags,
     EventPools) so old saves of this game are backed up instead of loaded.
  2. Rewrite the content modules in Configs (stats, actions, events, realms...).
  3. Edit Configs/UIThemeConfig: Palette, Fonts, Pip shape and every Term
     (EnergyName, TierHeader, AdvanceTierButton, RaceName, MetaCurrency, MoneySymbol,
     MentorName, ReviveLine, AscendLog, ...); UI and server messages pick them up
     with no code change. This game is itself such a conversion (see THIS GAME).
  4. Run the tests and BalanceReport in a playtest; ContentValidator also runs at
     server start. Skips show fixtures the new content lacks.

TESTS
  Command bar:
    print(require(game.ServerScriptService.Tests.TestRunner).Report())
  Edit-mode require caches modules between runs, so after editing code run the
  tests inside a Run playtest (fresh modules), e.g. via the command bar there.
  Tests run against the game's own content (expect.skipUnless for optional fixtures).
  Specs: BigNum, Requirements, ContentValidator, ReviewFixes (dropped delayed
  consequences, widowhood, oversized reincarnation, future saves), Economy (family-help exploit
  over 20 lives, adult brackets, underage siblings), Inventory (market rules,
  selling, consumables and yearly limits, equipment buffs, module gating, item
  effects/requirements, validation), NpcAutonomy (profiles, stages,
  filters, personality/goal/memory weights, triggers, yearly caps, module
  gating, long simulations), EventChains (delayed and
  same-year follow-ups, inherited person, delayed consequences, cooldowns,
  missing person, death clears chains, chain validation), Theme (vocabulary, server
  words, standalone content, creation guard), Commerce, Progression curves, and
  Simulation (whole lives through the real server modules with a simulated
  player, invariants checked every year, reincarnation, disabled modules,
  save protection).

SAVES
  DataStore "LifePathSave_v2", key u_<UserId>, fields Version, Pack and _Lock
  (session lock, see AUTHORITY AND SECURITY).
  - Older versions are migrated through PlayerState.Migrations[fromVersion];
    if no migration exists the old save is backed up to u_<id>_backup_v<n>.
  - Saves of another game (different manifest Id) are backed up to
    u_<id>_backup_pack_<gameId>, never loaded.
  - Saves from a newer engine, or a failed load, make the session read-only so
    the real save is never overwritten.
  Event queue entries keep legacy pool names ("Yearly"/"Life"), which
  LifeEventsEngine still resolves.

PORTABILITY RULES (audit, see Docs/AUDIT)
  An earlier probe game (different stat set, no cultivation) found base-game
  assumptions; these rules keep a cloned place with new Configs working:
  - Engine code never names a content stat. PlayerStatsConfig.Roles maps engine
    roles to stats: Social (social buffs on chance rolls, master search, job
    interviews) and Knowledge (character sheet row). A role may be omitted.
    Duel XP goes to the interaction's own ChanceStat.
  - Requirements fail closed on stats/proficiencies the pack does not define.
  - Snapshot.QiGains lists the Qi of every action with QiFraction (no action
    called Meditate is assumed).
  - Counter display names: GameManifest.Interface.CounterNames.
  - The validator counts problems inside content owned by a disabled module
    (training actions, masters, masteries, tiers, careers, items) and reports
    one warning per module instead of errors; they become errors when enabled.
  - Tests that need base fixture content or an enabled module call
    expect.skipUnless(cond, reason); skips are counted and listed.

CORE LOOP: YEARLY ACTION SLOTS (BitLife rules)
  Every year refills Actions (PlayerState.StartYear): TrainingConfig.BaseActionSlots
  (2) + Temporal Awareness ranks + PlayerStatsConfig.ActionBonus (stat peak) + realm
  ActionSlots (high realms) + SlotBonuses age windows + the ActionSlots buff, capped
  at FreeActionCap (4); golden slots from game passes come on top, all within
  MaxActionSlots (6). The sheet draws them as diamonds above +1 YEAR (gold first).
  Each action costs Slots (1) and may run MaxPerYear times (DefaultMaxPerYear 2).
  The Actions effect (consumables) adds slots for the current year only.
  Social: RelationshipsConfig.SocialPerYear (3) + Social Magnetism interactions per year in total,
  each interaction once per person per year (state.SocialDone). Interactions no
  longer cost action slots. All checks live in TrainingSystem.Check /
  RelationshipSystem.Interact; the UI, bots and dev console reuse them.
  Old saves (Energy pool) migrate on load. Spec: YearlyLimitsSpec.

REINCARNATION: WHEEL, PITY, LOCK, CODEX
  Modules/WheelSystem (Reincarnate remote, only while dead): spin a Sorcerer Clan
  (Lineages module) or a talent slot for Binding Vows (Karma); Shared/Gacha rolls weighted
  rarities (RacesConfig.Spin 65/24/8/2.5/0.5, TalentsConfig.Spin) with pity rules
  (Epic+ by the 15th spin, Legendary+/Mythic by the 60th; small pools without the
  guaranteed rarity fall back safely). Lock (60 Binding Vows) keeps a clan for every
  next life; spins are refused while locked; unlock is free. Rebirth uses what the
  wheel holds. The Collection Codex (state.Codex, permanent) records every race,
  talent, title and technique ever obtained: +1% AllStatXp and QiMult per entry
  (TalentsConfig.Codex). Requirement field Race gates clan-only content
  (clan_elders "Summons of the Clan Head", primordial_awakening "Innate Technique
  Awakening"). Spec: WheelSpec. Server messages print the rarity display name.
  Spin luck (Cursed Fortune +8%/rank, Honored One VIP +25%) multiplies every rarity
  above the lowest (Gacha luck argument). Each spin fires Remotes.SpinResult; the
  client rolls Shared/WheelSpinner (3D drum: RenderStepped, cubic ease-out, UIScale /
  TextTransparency by distance from the center line, tick per row, flash + fanfare
  for Epic+); AgingSystem delays the result toast until the drum lands.

WORLD: REGIONS, MAP, TRAVEL (World engine module, optional; base pack on)
  WorldRegionsConfig (6 regions in life-stage order; id -> name): the only birthplace
  qinghe = Tokyo Suburban Ward & Clan Estates (home, parks, school, family dojo), crimson =
  Tokyo Jujutsu High Campus (Grade 4 Sorcerer; sparring, dorm black market), capital =
  Kyoto Sister-School Grounds (Grade 3 Sorcerer; clan etiquette, Exchange Event); kunlun =
  Star Corridor & Cursed Warehouse (Grade 3 Sorcerer, or age 16 + ¥1,500 toll), marsh =
  Shibuya Veil District (age 14, Deadly), ruins = Shinjuku Showdown Ruins (Semi-Grade 2).
  Modules/RegionSystem, Shared/EngineModules/World (Map tab + Page).
  - Birth: a PlayerState.NewLifeHooks entry rolls a starter region (StarterWeight);
    Direct Descendants are moved to the family's region by SamsaraSystem.Apply.
  - Region modifiers are the "Region" per-life buff source (PlayerState.SetLifeBuff),
    refreshed yearly and on travel (Shibuya curse-user bonus at Alignment <= -20);
    hazards cost health yearly; the Shinjuku Showdown Ruins add +10% glimpse chance.
  - TravelAction remote: neighbors only, age 12+, destination Requires, 1 action
    diamond + TravelFee, then a road encounter (TravelEventsConfig events with
    Trigger = "Travel", picked by Weight/Route/Requires; the lethal ones, Curse User
    Ambush and Cursed Energy Surge, need age 13+). Regional events use the Region
    requirement (The Dorm Black Market, The Kyoto Exchange Event, Trial of the Cursed
    Warehouse, A Relic in the Ruins; ids black_market, imperial_exam, orthodox_sect,
    star_relic).
  - Age-appropriate content: toddler and child actions and events stay at home, parks,
    school or the family shrine/dojo; lethal fights, patrols and missions start at 13
    (primordial_beast, road ambushes) or behind region gates (Shibuya 14+).
  - The Map page mirrors RegionSystem.Check for instant feedback; roads are rotated
    frames redrawn on resize. Spec: WorldSpec.

DYNASTY: HEIRLOOMS, RELATIVES, FAMILY TREE (Dynasty engine module + Lineage tab)
  FamilyTreeConfig, Modules/DynastySystem, Shared/LineageMemory, UIController/FamilyTreePage.
  - Consecrate one equipped Cursed Tool/Uniform/Charm (DynastyAction). At death it
    becomes an ancestral Cursed Tool (heirloom) in state.Heirlooms (permanent): +5% AllStatXp soul stack per generation
    (each new life). Direct Descendants inherit family heirlooms at 12; any other
    rebirth leaves them Lost with the old family in its region (heirloom_reclaim: buy,
    duel or steal; requirement LostHeirloomHere).
  - Past-life records (PlayerState.DeathRecorders) gain Region, Occupation, Rival,
    Partner, Heirloom, Biography and NextPath (Descendant = accent clan link on
    the tree, anything else = cyan soul leap).
  - The Mist of Time (LineageMemory): clear <= 2 generations, oral history <= 4,
    then a forgotten stone "An Unknown Ancestor of <Region>"; Ancestral Chronicler
    (+1/rank) and Soul Imprint (+0.5/rank) delay it; Grade 2 Sorcerer+ ancestors
    (FamilyTreeConfig.ImmortalRealm = 5) and heirloom creators are never forgotten.
  - Extended relatives only appear when met (MeetRelative: grandfather_homestead,
    cousin_visit). Children are not tracked as people yet, so the tree has none.
  - Lineage tab: draggable/scrollable canvas scaled to its height, ◀ Older / Newer ▶
    pan buttons, tweened connectors and nodes, detail panel with heirloom controls.
    Spec: DynastySpec.

LIFE 1 CREATION, LEGACIES, GENETICS AND HEIRS (Dynasty)
  - Modules/CreationSystem: a new save has state.Creation = { Spins = 3 }: free wheel
    rolls (CreationAction: Bloodline | Legacy | Done) at age 0 of Life 1, shown on the
    client drum by ReplicatedFirst/IntroAndLoadingUI before the prologue (cards update
    only when the drum lands).
  - FamilyLegacyConfig: 7 origins (money at birth, a "Legacy" life buff, parent
    affection, an heirloom-hint item). Every new life applies state.Wheel.Legacy or the
    default (DynastySystem NewLifeHook); a starter reroll undoes the previous grant.
    Full rebirths spin it on the Wheel (SpinLegacy, 20 Binding Vows, own pity).
    This game's origins: Window-Sight Townsfolk ... Star Plasma Guardian House.
  - GeneticsConfig + Shared/GeneticsText: friends, rivals and partners get Genetics
    { Race, Grade, Trait } via PlayerState.RelationshipHooks. Grades gate romance
    (Charisma, Sorcerer Grade) and add a chance penalty to romance and duels; each grade adds
    25 years before old-age death (LongevityPerGrade).
  - Children (relationship type Child, category Child): TryForChild (partner, 18+),
    child_born event (HaveChild). Genetics from both parents: 60/40 bloodline, mutation
    10% + spouse grade bonus (to 35%) raising one rarity tier, one of your talents, the
    spouse's trait at 50-80%, potential from your peak stats; upbringing guidance once
    (Taijutsu / Scholarly / Cursed Energy; keys Martial / Scholarly / Spiritual,
    child age <= 15).
  - Heir rebirth: Lineage tab "Be reborn as this child" -> Reincarnate ChooseHeir. The
    Descendant path then costs nothing and spins are refused; Confirm reincarnates with
    the heir's race, talents and legacy, then DynastySystem.BecomeHeir applies name,
    hereditary trait ("Heredity" life buff), potential + upbringing levels, the spouse as
    your Parent and other children as Siblings. Children are born again at age 0 (the
    simulation always starts a life at birth). Grandchildren are not tracked.
  Spec: GeneticsSpec.

FAMILY TREE LAYOUT (Lineage tab)
  Family units (a person or a couple + their children's units) laid out as a tidy tree:
  width = max(members, sum of children widths); children side by side beneath their unit,
  so a new generation widens only its own branch and nothing overlaps. Nodes sit on a
  pixel grid (PAD + col * COL_W, PAD + row * ROW_H) in one Content frame.
  Connectors are orthogonal (no rotation): marriage line between a couple, a stem from
  its middle down to a horizontal bus, a drop from the bus to each child. Rows:
  grandparents, parents (+ uncles/aunts), past lives -> you (+ spouse), siblings,
  children (+ their in-law spouses), grandchildren. Past lives sit left of you on your
  row (the tree is shifted right to make room). UIScale 0.62-0.78; deeper trees scroll
  vertically. The ended life is not repeated as a past life while you are dead.

HEIRS, GRANDCHILDREN
  Your children marry and have children via NPC autonomy (Child is in NOT_PARENTS):
  PlayerState.NpcChildHooks -> DynastySystem.AddGrandchild stores rel.Offspring with
  genetics combined from the child and their spouse (DynastySystem.Combine/ChildBlood).
  Heir modes (Reincarnate ChooseHeir relId mode):
  - TakeOver: continue the child's life at min(age, 25); DynastySystem.GrowUp grows stats
    0.4 levels/year (+0.3 for the upbringing focus), proficiencies after 12, the cursed
    energy awakening (SpiritRoot flag) from 6; the family is wound back only for the age-25 adult snapshot.
  - Grandchild (children 19+): reborn at 0 as the heir's newborn; genetics combined once
    more (another awakening chance); the heir is your Parent, your old spouse your
    Grandparent, the heir's children your siblings.

TACTICAL CLASH DUELS (Modules/DuelSystem, DuelConfig, UIController/DuelModal)
  Best of 3 exchanges; stances Strike > Channel > Guard > Strike (+35% for the advantaged
  side), shown as ⚡ Black Flash Blitz > 👁 Technique Release / Domain Amp >
  🛡 Simple Domain / Falling Blossom > Black Flash (optional Short names feed the
  "Beats ..." line and the round log). Stance power from stats, best proficiency,
  grade, techniques and equipment;
  the foe scales from your average (Difficulty by kind, rival grade, faction rank) and
  favors one stance (shown on its card). DuelAction remote: Stance / Quick / Close; an
  open duel quick-resolves when the year advances. Used by Blood Feud and Wager duels,
  faction promotion trials and the heirloom_reclaim duel (effect StartDuel); outcomes are
  registered as DuelSystem.Outcomes[kind]. Dev console: duel [difficulty].

ASCENSION ENDGAME (Modules/AscensionSystem)
  At Heian Calamity 9 the PROMOTION seal becomes TRANSCEND (AscendAction): the life ends
  with +500 Binding Vows, state.Ascensions +1, the Calamity of Legend title
  (heavenly_ascendant) in the Codex, and every later life gets the title flag and a
  Cursed Legacy life buff (key "Divine") of x1.1 all stat XP and CE per transcendence.
  Messages and the ending screen read Terms AscendRequirement / AscendLog /
  AscendDeath / AscendDone / AscendTitle / LegacyBuffName / AscendOutro.

MOBILE, TABLET AND DESKTOP (Shared/Responsive, StarterPlayerScripts/ResponsiveUI)
  Responsive.Profile(viewport, touch): Kind Phone (touch, short side < 500 GUI px),
  Tablet (other touch) or Desktop, and Scale = min(vw/1280, vh/720) clamped 0.75..1.6.
  ResponsiveUI (client): Core GUI on, PlayerGui.ScreenOrientation LandscapeSensor
  (StarterGui too); every root frame of the game's ScreenGuis gets a UIScale
  "ResponsiveScale" = Scale with its Size divided by it (same screen area; pixel
  paddings, strokes and text caps follow the screen). Touch: text renders at 9 px
  where its box allows (never < 7 px, never taller than the box); every button except
  grid cells gets a 44x44 screen-px UISizeConstraint and grows around its centre
  (AnchorPoint 0.5; Position re-based if its own code moves it); list gaps >= 6 px.
  Opt-outs: attribute NoAutoScale (ScreenGui or root; TutorialUI sizes itself) and
  TouchSafe (buttons a layout already sizes). Re-applied on rotation/resize.
  Layouts: phones get a taller tab row (0.15 of Main), Advance / Auto-age side by
  side, and pages drawn 2.5x tall inside vertical ScrollingFrames (Family and
  Chronicle scroll on their own); tablets get a 44 px+ Auto-age button; the shop and
  verdict cards widen and the shop body scrolls; the creation card drops its slot
  descriptions for full-size Spin buttons; the guide banner grows with side-by-side
  Got it / Skip. Verified with Studio device emulation (iPhone 13 844x390, iPad A16
  1180x820) and desktop; ResponsiveSpec checks the profiles.

AUDIO AND JUICE
  PlayerState.Feedback(player, cue, data) -> Remotes.Feedback -> StarterPlayerScripts/SoundFX:
  Clash, DuelStart/Win/Lose, BreakthroughSuccess/Major/Fail (fail shakes the main panel),
  Milestone, Ascend, Purchase, Revive; the Advance Year button clicks locally; the drum keeps its own tick
  and fanfare. Sounds are Roblox built-in rbxasset:// sounds verified to load in Studio;
  swap them for rbxassetid:// audio in SoundFX.CUES.

MENTORS: REGIONS AND FACTION RANKS (engine: Masters module)
  MastersConfig.Regions: Seek a Mentor only finds mentors of the current region:
  Suburban Ward: The Scarred Physical Assassin (iron_fist_han); Suburbs/Campus/Kyoto: The
  Immortal Fight-Club Boss (spear_saint_long, wanders); Kyoto: The Overtime Grade-1
  Mentor (scholar_bai) and The Best-Friend Boogie Brawler (madame_su); Star Corridor:
  The Old Kyoto Swordmaster (elder_mo) and The Blindfolded Honored One (sage_ye);
  Shibuya/Campus town: The Stitched-Brow Curse User (blood_lotus). SectRanks: Jujutsu
  Student -> Field Exorcist -> Senior Exorcist -> Faction Elder -> School Principal with
  yearly stipends; MasterAction "Trial" (1 action, Requires incl. MasterLoyalty, chance
  + TrialStat) promotes. Star Corridor: Grade 3 Sorcerer, or AltRequires age 16 + AltFee
  ¥1,500 faction toll (RegionSystem.Check, Map page).

ADULT DUELS
  Rival interactions: Spar (pride), Wager (16+, 20% of your money, min ¥100), Blood Feud
  (16+, the loser dies or you lose 60 health). Grade penalty + 4% per grade above
  Non-Sorcerer.

THE OLD RIVAL TWIST (Samsara)
  Echoes now remember their region; a rival who outlived you is Powerful when you
  died at Grade 4 Sorcerer+. rival_mentor (RivalMentorHere) -> BecomeRivalDisciple:
  yearly lessons in the old life's top proficiency, their signature technique after
  2 years ("Technique" life buff), and after 3 years plus a glimpse or proficiency
  20 the rival_reckoning (Trigger = "System"): reveal your past life in a duel
  (needs RemembersPastLife) or inherit their legacy. Every rebirth also gets a new
  rival of your own age at 8.

PROGRESSIVE DISCLOSURE
  ProgressionGatesConfig: tab ages (Bonds/Study 4, Bag 7, Mentors/Talents/Map 12),
  the cursed energy strip waits for the cursed energy test (flag SpiritRoot from
  spirit_root "The Cursed Energy Test", or age 7), milestone toasts (Modules/MilestoneSystem). Actions carry MinAge/MaxAge
  and Requires (TrainingSystem.Check); TrainingPage hides what is not available yet.
  Infants: Sense Invisible Curses, Cursed Bear Movie Night, Rest. Careers and part-time
  jobs at 16. Action card titles stay short (about 22 characters) to keep >= 10 px.
  Spec: ProgressiveDisclosureSpec.

INTRO AND PROLOGUE
  ReplicatedFirst/IntroAndLoadingUI replaces the default loading screen (theme palette:
  abyss black, double violet frame, rotating seal with drawn trigrams, staged loading; Studio
  workspace attribute HoldLoadingScreen holds it for UI checks) and plays the
  reincarnation prologue (WorldRegionsConfig.Prologue: the Wheel of Curses, typewriter via
  MaxVisibleGraphemes, Skip / Continue) at age 0 of every life when World is on.

SAMSARA META-PROGRESSION (permanent, bought on the Wheel of Curses)
  SamsaraUpgradesConfig (WheelSystem BuyUpgrade, Binding Vows, only while dead;
  state.Upgrades is saved): Temporal Awareness (+1 free seal x2), Cursed Fortune
  (KarmicFortune, +8% spin luck x5), Soul Imprint (SoulRetention, +5% glimpse
  chance/strength x5, slower memory decay), Social Magnetism (+1 social x2), Ancestral
  Chronicler (+1 remembered generation x3).
  Game passes and products: see CURSED BLACK MARKET.

CURSED BLACK MARKET (MonetizationConfig, Modules/MonetizationSystem, UIController/ShopModal)
  Passes (ownership runtime only, state.Passes stripped by Serialize, refreshed on join
  and after PromptGamePassPurchaseFinished):
    Time Manipulation Pass  (CelestialTimekeeper) +1 golden seal, auto-age 1.5 s/year
                            (AgingSystem asks PlayerState.GetAutoAgeSeconds per player)
    Honored One VIP         (ImmortalVIP) +1 golden, +25% spin luck, x2 Wheel speed,
                            [VIP] name badge (jackpot gold)
    Ancestral Clan Vault    (BloodlineVault) clan Lock costs 0 Binding Vows
                            (PlayerState.HasFreeLock)
  A newly granted pass's golden seal is usable the same year.
  Developer products: MarketplaceService.ProcessReceipt -> GrantProduct. PurchaseIds go
  in state.Receipts (saved, last 60) so a retried receipt never grants twice; the receipt
  is confirmed once PlayerState.Save succeeds (always in Studio).
    Binding Vow / Greater Binding Vow / Special Grade Vow Packs (Karma 50 / 200 / 600);
    Special Grade Cursed Object (MiraclePill): CE to 100% + state.PillBonus 0.2, spent by
    the next Grade Promotion attempt; Reverse Cursed Energy Miracle Revival
    (MiracleRevival, death prompt only).
  Miracle Revival: PlayerState.Die keeps a runtime deep copy of the life when the death
  is untimely (age < max lifespan, not options.Final, not already revived this life).
  Revive restores it at 50% health, takes back the death's Binding Vows, keeps receipts,
  passes, tutorial progress and the pill; PendingEvent/PendingDuel are cleared. Natural
  deaths and Ascension pass { Final = true }. Any successful Wheel action clears the
  offer (AgingSystem); a late receipt refunds ReviveFallbackKarma instead.
  Items with Module = <engine module> are hidden/refused when the pack lacks it.
  ShopAction remote ("BuyPass" | "BuyProduct", id, sandbox): Studio Test Purchase
  (sandbox, honoured only when RunService:IsStudio(), and automatic for ids still 0)
  grants for free with the same celebration; live servers always prompt Roblox.
  Feedback cue Purchase -> accent celebration banner + sound; Revive -> sound.
  UI: accent header button at the end of the tab row and the Rebirth page; the shop card
  lists passes and visible products; the Death's Threshold card (ReviveTitle) opens on
  an untimely death (Reverse Cursed Technique / Accept death). Item texts use Terms
  tokens ({MetaCurrency}, {AdvanceTierName}, ...).

LIFE 1 ONBOARDING (Modules/TutorialSystem, UIController/TutorialGuide)
  Four banners with a pulsing ring, each once when its moment comes: 1 creation wheel
  (when GamePack.CreationSpins has a wheel), 2 action pips on the first turn, 3 Advance Year when actions hit 0,
  4 Core CE Meditation + PROMOTION when the energy bar wakes (the guide finds the action
  whose name contains "Meditat"; with Cultivation; otherwise it ends at
  3). Doing the thing or "Got it" moves on, "Skip tutorial" ends it. The guide waits
  under the intro, life-event modals and the shop. TutorialAction remote ("Step", n |
  "Skip") stores TutorialStep / TutorialCompleted (saved); Life 2+ is always completed
  and older Life 1 saves past age 12 are left alone. Dev console: tutorial reset|skip.

THEME & TERMINOLOGY (Configs/UIThemeConfig, Shared/PackTheme)
  Palette (UIStyle.C keys: "gold" = accent, "qi" = energy), Fonts (Enum.Font names,
  unknown -> default), Corner multiplier, Pip { Rotation, Corner } and Terms.
  Server messages use PlayerState.Words("+%d {MetaCurrency}") / PlayerState.Term(key);
  a lowercase token ("{raceName}") gives the lowercase word. Engine message keys a pack
  may omit (MentorName, StudentName, SectName, PeakLine, ReviveLine, ReviveLog,
  BirthLine, Ascend*, LegacyBuffName) fall back to PackTheme.DEFAULT_TERMS (neutral
  wording), so other games never show a raw key; unknown keys still return themselves.
  UIStyle applies the palette/fonts at require, so every page is themed; UITheme maps
  old colours baked into the layout to the theme's and reads pip shape and words;
  IntroAndLoadingUI reads palette and RaceName. UI code never hardcodes genre words:
  use S.Terms (EnergyName, TierHeader, AdvanceTierButton, RaceName, RebirthTab,
  MetaCurrency, ShopName, ...). Glyphs must exist in the UI fonts (verified: ◆ ❖ ● ★
  ☯ ⚜; not ✦ ✧ ⬢ ✕). This game ("Abyssal Curse"): bg #09080E / #120F1D /
  #181426, violet accent #9D4EDD / #7B2CBF, crimson #E11D48, cyan energy #38BDF8, jackpot
  gold #F59E0B (C.jackpot: Mythic rarity, VIP); Bodoni titles; cursed-seal pips
  (Shape "CursedSeal", 45°, corner 0.04; a round badge is Pip { Rotation = 0,
  Corner = 0.5 }, a slanted crest { 15, 0.22 }).

REBIRTH PATHS, ERAS, ECHOES, GLIMPSES (Samsara engine module, optional)
  RebirthPathsConfig, Modules/SamsaraSystem, WheelSystem ChoosePath + Confirm (path
  cost paid at rebirth; Confirm captures the old life before PlayerState.Reincarnate):
  - Descendant (30 Binding Vows, free if Married at death): clan name, 25% of wealth,
    the first equipped item as a cursed tool heirloom, family affection 85-95.
  - Stranger (free, default): same era; Partner/Friend/Rival who were alive become
    echoes, met through past_life_encounter (MeetEcho effect, aged forward).
  - The Heian Golden Age (era key Ancient, 25): era LifeBuff QiMult 1.25, -25 max
    health, +2 stress/year, primordial_beast event ("A Heian-Era Curse"). A Century
    Later (Future, 25): legend_of_self (LegendOfSelf effect reads the old name, grade
    and alignment).
  - Past-Life Glimpses: Growth year tick, ages 4-30, max 3 per life, chance
    8% + Soul Imprint; recover strength (15% + Soul Imprint) of the old top
    proficiency and attribute, plus CE if the old grade was higher; narrated in the
    Chronicle. Requirement fields HasEcho, Era, RemembersPastLife (special options).
  Per-life data: state.Modules.Samsara. Era buffs use the generic state.LifeBuffs.
  Spec: SamsaraSpec. Packs without the module rebirth exactly as before.

PROGRESSION PACING (hard scaling)
  Attributes and proficiencies cap at PlayerStatsConfig.MaxLevel (60). Grade
  stabilization (YearsPerLevel) outgrows grade longevity after Grade 2 Sorcerer, so a
  fresh life peaks at Semi-Grade 2-Grade 2 and Heian Calamity needs lifespan
  legacies (clans, Mythic talents) from many lives. Repeatable lifespan items
  need Use.MaxPerLife (the validator warns otherwise). Run titles (Curse User
  Blademaster, Higher-Up Strategist, Special Grade Prodigy) reward dedicated builds.
  Measured with BalanceReport.Campaign (see Docs/BALANCE).

UI THEME (abyss black, violet, crimson, cyan cursed energy)
  Style "Dossier" (UIThemeConfig.Style, 2026-10-25): modern urban-occult look. UITheme.glass
  panels (#0B0914 obsidian glass, 1 px neon border, 4 px corners; Trim/corner gems removed),
  GothamBlack titles, BuilderSansBold text, RobotoMono numbers (Fonts.Mono), Corner 0.34.
  UITheme.Layout(gui, profile) (called from UIController.applyLayout, Wide or Phone table of
  screen rectangles): Sheet = ID banner (square portrait with crimson corner brackets and a
  grade stamp from RealmsConfig Stamp, e.g. [G4] / [SG], three meters, 3x2 ledger); Main =
  tab row (crimson highlight bar, Black Market button) + pages; a docked command bar
  (Sheet.CommandDeck) holds ActionGems, Main.Strip (grade, CE bar, PROMOTION) and the
  crimson -> violet +1 YEAR (UIStyle.gradient) with Auto. Root UIPadding is removed in this
  mode (children are placed in screen rectangles). Training page: attributes dossier left
  (accent strips, thin bars), mission deck right (2 columns of briefing cards: 4 px accent
  bar, uppercase title, Mono cost, reward Pills). Instance names are unchanged.
  Loading screen: Cursed Eye domain seal (counter-rotating crimson/violet rings, pulsing
  eye), Terms LoadingTitle / LoadingSubtitle / LoadingStage1-5 / LoadingDone. Studio UI
  checks: workspace attributes HoldLoadingScreen and SkipIntro (skips creation + prologue).
  The classic description below still applies when Style is omitted.
  Shared/UIStyle holds the palette used by every page; Shared/UITheme restyles the
  static layout idempotently: double-bordered panels (ink frame, violet trim, corner
  gems), avatar seal (grade initials, clan rarity border), vital bars with
  icons, ActionGems ("Cursed Seals": rotated pips in non-rotated holders: layouts ignore
  Rotation on direct children; violet free, gold pass, dark socket spent) + social
  counter above the +1 YEAR medallion, two-column ledger, medallion that
  pulses at 0 actions, grade emblem, crimson ritual PROMOTION, connected tab bar
  (icons, accent underline), old-palette retint (the template's jade colours map to
  the theme's roles). Applied once in edit mode (with
  Preview cards, so Studio never shows empty panels) and by UIController at
  startup (previews cleared). Pages may use ctx.Theme.frame (add UIPadding before
  frame: the trim is placed relative to it). Lineage tab =
  Rebirth page in three columns (wheel + drum, rebirth path + Binding Vow upgrades,
  codex + passes + past lives), built in code. Journal tab label: Chronicle.

DEVELOPER CONSOLE (Studio only)
  Press F2 in a playtest, type help. Modules/DevConsole runs every command on
  the server against the player's real state; DevConsoleServer exposes it via
  Remotes.DevCommand and StarterPlayerScripts/DevConsoleClient draws the panel.
  Gate: RunService:IsStudio() and no ServerScriptService attribute
  DevConsole = false. Outside that the remote is never created, the client
  builds no UI, and Execute refuses anyway (verified with the attribute off).
  Commands: state, get <path>, set, stat, skill, counter, flag, qi, realm,
  year [n] [auto], events [filter], event <id>, choose <n>, npc, buffs,
  why <action|event|title|career|tier|master|item|mastery> <id>, item, title,
  heal, kill, seed, log, pack, pass, buy, tutorial, upgrade, glimpse, region, travel,
  consecrate, equip, reborn, family, grandchildren, duel, help.
  Tooling: the Studio-only BindableFunction DevConsoleServer.DevConsoleBridge runs a
  command as the first player from server-side scripts (MCP UI checks).
  No duplicated rules: `why` uses TrainingSystem.Check and
  Engine.WhyIneligible (the same code the game runs), `buffs` lists
  PlayerState.BuffSources (what GetBuffs merges).

CONTENT EXPANSION (2026-11-02, Cursed Path)
  Every list-type content pool doubled with new, original Jujutsu-themed entries
  (no named canon characters). Same schema, numbers kept at the existing tiers.
    Yearly events 35 -> 71 (chain curse_glimpse -> window_agent_visit), sorcerer
    fate events 14 -> 28, travel 10 -> 21 (5 road encounters, 6 regional events).
    Regions 6 -> 12: hills, arcade, window_office, hiei, colony, coast. Each one's
    QiMult stays below the existing region with the same gate. Map nodes are 90x55 px
    on a ~778x227 canvas in landscape Studio: keep positions inside x 0.06-0.94,
    y 0.12-0.88 and clear of each other (audited: no overlap, no clipping).
    Clans 14 -> 28, mentors 7 -> 14 (MastersConfig.Regions for each new region),
    items 21 -> 42 (shop 14 -> 30), talents 18 -> 36, titles 19 -> 38, training
    13 -> 26, masteries 16 -> 32 (deep nodes cost 30/45/65/90), careers 8 -> 16,
    interactions 13 -> 30 (incl. 3 upbringings), genetics traits 6 -> 12,
    upbringings 3 -> 6, origins 7 -> 14, rebirth upgrades 5 -> 10, NPC personalities,
    goals, actions, occupations and name pools doubled.
  Kept as designed: grades/realms, education tiers, genetics grades, faction ranks,
  rarity tables, game passes.
  Shared fixes from the sister games: seal tooltip (UIController ctx.AttachTooltip,
  hover on desktop, tap on touch), Bonds cards wrap action rows (SocialPage), NPC
  loans never push yen below 0 (NpcSystem).

DECISIONS
  - One game per place (2026-10-25): multiple packs inside one place were removed;
    new games are clones of the place with their own Configs and UIThemeConfig.
  - Each content module stays a plain Lua table that the validator checks.
  - Cultivation stays inside PlayerState (Qi, realm longevity) but is gated by
    the module flag; extracting it fully is deferred until a second progression
    module (e.g. superpowers) needs the same interface.
  - The yearly simulation moved from the AgingSystem Script into
    Modules/YearSystem so it can be tested; behavior is unchanged.
  - Network sends go through PlayerState.Fire, which ignores non-Player keys;
    this lets tests and future offline simulations run the real modules.
  - No third-party test framework: a 100-line runner avoids a new dependency.
  - Late-game pacing is time-based: RealmsConfig.YearsPerLevel gates each
    breakthrough (state.LevelSince), because Qi gains scale with the requirement
    and cannot pace anything. Training cannot kill: TrainingSystem.InjuryFloor.
    Both came from the balance report (Docs/BALANCE, tuning pass).
  - All gameplay randomness goes through Modules/Rng (plus NpcSystem.Rng), so
    Rng.Seed(n) replays a run; BalanceReport seeds every life from Seed + life
    and gives every policy the same seeds (common random numbers).

IMPLEMENTATION MATRIX (after milestone 5)
  System                     Status         Notes
  Character / attributes     IMPLEMENTED    6 stats (cap 60), XP curve, spun bloodlines and talents
  Time / aging               IMPLEMENTED    turn-based years + auto-age; no calendar
  Actions                    IMPLEMENTED    yearly slots, per-activity caps, age/module/requirement gates
  Events                     IMPLEMENTED    random, fixed-age, relationship-targeted,
                                            follow-up chains, delayed consequences,
                                            cooldowns (no location-based events yet)
  Relationships              IMPLEMENTED    affection, drift, deaths, memories, away
  NPC autonomy               IMPLEMENTED    yearly weighted choices for the character's
                                            relationships; no NPC-to-NPC relations or
                                            off-screen world population
  Progression                IMPLEMENTED    stats, proficiencies, realms, masteries,
                                            titles, education, careers
  Inventory / items          IMPLEMENTED    consumables, equipment slots, valuables,
                                            market; no crafting or item durability
  Economy                    PARTIAL        money, salary, tuition, market prices,
                                            age-scaled family help; static prices
  Locations / organizations  IMPLEMENTED    6 regions (World module); factions exist as
                                            mentors with ranks
  Game manifest + modules    IMPLEMENTED    modules defined by files (EngineModules +
                                            SystemRegistry); Fame proves it
  Content validation         IMPLEMENTED    this milestone
  Save versioning/integrity  IMPLEMENTED    this milestone (migrations table empty)
  Save session locking       IMPLEMENTED    UpdateAsync lock key, verified on a mock
  Tests                      IMPLEMENTED    179 cases (incl. YearlyLimits, Wheel, PackPortability, SystemRegistry,
                                            BalanceReport, DevConsole, Tuning, Theme, Commerce); skips
  Balance diagnostics        IMPLEMENTED    Tools/BalanceReport, 6 policies, seeded, yields
  Developer console          IMPLEMENTED    Studio-only, F2; 24 commands; DevConsoleSpec
  Yearly action slots        IMPLEMENTED    BitLife-style slots + per-activity and social caps
  Reincarnation spins        IMPLEMENTED    Gacha with pity, bloodline lock, Collection Codex
  Bespoke UI theme           IMPLEMENTED    Shared/UITheme (edit-mode previews, Rebirth page)
  Content folders            SINGLE GAME    Configs only (packs removed 2026-10-25)
  Theme + vocabulary         IMPLEMENTED    UIThemeConfig Terms in UI and server messages
  Content-defined stat sets  IMPLEMENTED    stat roles (verified with a probe game)
  Localization               MISSING        UI text is English in content/UI code
  Generative AI              NOT APPLICABLE none in project; keep rules authoritative

NEXT MILESTONES (prioritized in Docs/AUDIT)
  1. DONE: Tools/BalanceReport (results in Docs/BALANCE).
  2. DONE: Studio-only developer console (see DEVELOPER CONSOLE).
  3. DONE: module registry (Shared/EngineModules + SystemRegistry); see
     ADDING A GAMEPLAY MODULE, including module-declared UI tabs.
  4. Resource/progression abstraction (Qi + realms become one game's resource).
  Later: descendants/dynasties, crafting, NPC-to-NPC relations.
================================================================================
]]

return {}
