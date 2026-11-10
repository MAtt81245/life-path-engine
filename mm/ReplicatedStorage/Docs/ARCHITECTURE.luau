--[[
================================================================================
 UNIVERSAL LIFE SIMULATION ENGINE - ARCHITECTURE NOTES        (engine 0.3.0)
 Milestones 2 (content loader + game packs), 3 (event chains),
 4 (NPC autonomy), 5 (inventory & items) and the portability audit
 (see Docs/AUDIT) included.
================================================================================

LAYOUT
  ReplicatedStorage
    Configs/            Base content library + base GameManifest (the default
                        game, "life_path_xianxia"). BigNum also lives here.
    GamePacks/          One folder per game pack: GameManifest + overrides.
                        Attribute ActivePack selects the pack ("" = Configs).
    Shared/             Engine code usable by server and client:
                          Content (resolves content modules for the active pack),
                          GamePack (manifest, module registry, contracts),
                          EngineModules/ (one definition per engine module),
                          Requirements (condition checker), ContentValidator,
                          UIStyle (palette, factories), UITheme (bespoke frames),
                          Gacha (spins with pity)
    Remotes/            Client -> server intentions, server -> client snapshots
    Docs/               This file
  ServerScriptService
    GameManager         Remote entry point; validates the pack at startup
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
  Every system loads content with Content.Get("<Name>") instead of requiring
  Configs directly. Lookup order: GamePacks/<ActivePack>, the packs it Extends
  (manifest field, chained, cycles reported), then Configs. A pack overrides
  whole modules; to change only part of one, build on the inherited version:
      return Content.Extend("TitlesConfig", script.Parent, function(titles) ... end)
  Content.Extend re-runs the inherited module from a clone (not a deep copy), so
  the copy's helper functions (RacesConfig.Get, TalentsConfig.Roll...) read the
  patched data; inherited data is never mutated. When a pack adds or removes
  list entries it must rebuild that module's indexes (see
  GamePacks/modern_life/TitlesConfig). A deep copy kept the base closures, so
  patched packs silently used base races/talents (fixed; GamePacksSpec).
  The pack is chosen when modules load: changing ActivePack needs a new server.

GAME PACKS AND MODULES
  GameManifest declares Id, Version, EngineVersion, Extends (optional), Theme,
  Modules, EventPools, Interface (TabLabels, CounterNames) and Dependencies. A
  pack folder name must equal its manifest Id. Engine modules: Cultivation,
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
  4. Packs opt in with Modules = { <Id> = true }; Optional modules left out of a
     manifest are off without a warning.
  5. UI (optional): Tab = { Label, Order } in the definition plus a ModuleScript
     named Page inside it (Init(ctx, frame), Render(snapshot)). UIController
     clones a tab button, creates the page frame, places it by Order (built-in
     tabs are 10..80, so 65 sits before Journal) and shares the bar evenly
     between visible tabs. Inactive modules get no tab. Manifests may relabel it
     (Interface.TabLabels.<Id>). Settings in the definition keep server and page
     numbers in sync. The validator rejects a Tab without a Page.
  Proof: Fame (Shared/EngineModules/Fame + Modules/FameSystem) was added with no
  engine edit; the academy pack enables it (Perform action, yearly decay, Fame
  event effect, MinFame title, FameMult buff, and its own Fame tab).
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
  Shipped chains: stolen_notes -> notes_thief_returns (4y, same person),
  lost_wallet -> purse_owner (2y), mugging -> watch_captain (same year),
  friend_in_need -> loan repaid (3y delayed), immortal_cave -> sect_reward (1y)
  or legacy awakening (5y delayed), sect_tournament -> poison_exposed (3y).

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
  requirement Items = { id = count }. Shipped: lucky charm for returning the
  lost purse, jade bracelet from the inheritance, the immortal cave's Ancient
  Talisman, which unlocks a safer choice in the heavenly tribulation.
  UI: Inventory tab (equipped slots, bag with use / equip / sell, market with
  requirement hints). modern_life extends the catalogue (first aid kit, laptop,
  smartphone, designer suit...) and renames slots to Gear / Outfit / Gadget.

ECONOMY: FAMILY HELP
  "Ask Help" from family is data-driven (RelationshipsConfig.FamilyHelp):
  pocket money to 11 ($5-20), teen allowance to 17 ($20-80), adult help
  ($100-400), x (0.5 + affection / 200), x1.5 if the relative has a job (NPC
  autonomy). Relatives under 18 comfort instead of paying. Validated by the
  ContentValidator (ordered brackets, Min <= Max, full age coverage).
  Measured with the worst-case strategy (ask every relative every year, 30
  lives, median): family income by 13 went from $11,057 to $460 (market items
  affordable from it: 12 of 14 -> 3), by 18 from $18,784 to $1,463; adult help
  is about $1,100 per year across all relatives. EconomySpec keeps this as a
  regression test (by 13 <= $1,000 and <= half the market; by 18 <= $3,000).

CREATING A NEW GAME
  1. Create GamePacks/<new_id>/ with a GameManifest (Id = folder name,
     EngineVersion, Modules flags, EventPools, optional Extends / Interface).
  2. Add only the content modules you change, using Content.Extend to patch
     inherited ones or returning a full table to replace them.
  3. Set ReplicatedStorage.GamePacks.ActivePack = "<new_id>" to play it.
  4. Run the tests. GamePacksSpec validates every pack; ContentValidator also
     runs at server start and reports unknown/unused modules in the pack folder.
  Example: GamePacks/modern_life (no cultivation, masters or bloodlines; Qi
  Control shown as Focus; fencing / martial arts / programming; coding bootcamp
  and software engineer; new modern events; relabeled tab). Six modules, no code
  changes, 0 validator errors or warnings, verified in playtest.

TESTS
  Command bar:
    print(require(game.ServerScriptService.Tests.TestRunner).Report())
  Edit-mode require caches modules between runs, so after editing code run the
  tests inside a Run playtest (fresh modules), e.g. via the command bar there.
  Tests follow the active pack; pack-specific cases pass packId explicitly.
  Specs: BigNum, Requirements, ContentValidator, ReviewFixes (dropped delayed
  consequences, widowhood, oversized reincarnation, future saves), Economy (family-help exploit
  over 20 lives, adult brackets, underage siblings), Inventory (market rules,
  selling, consumables and yearly limits, equipment buffs, module gating, item
  effects/requirements, validation), NpcAutonomy (profiles, stages,
  filters, personality/goal/memory weights, triggers, yearly caps, module
  gating, long simulations), EventChains (delayed and
  same-year follow-ups, inherited person, delayed consequences, cooldowns,
  missing person, death clears chains, chain validation), GamePacks (resolution,
  inheritance, no mutation, indexes, every pack valid), Progression curves, and
  Simulation (whole lives through the real server modules with a simulated
  player, invariants checked every year, reincarnation, disabled modules,
  save protection).

SAVES
  DataStore "LifePathSave_v2", key u_<UserId>, fields Version, Pack and _Lock
  (session lock, see AUTHORITY AND SECURITY).
  - Older versions are migrated through PlayerState.Migrations[fromVersion];
    if no migration exists the old save is backed up to u_<id>_backup_v<n>.
  - Saves from another pack are backed up to u_<id>_backup_pack_<packId>.
  - Saves from a newer engine, or a failed load, make the session read-only so
    the real save is never overwritten.
  Event queue entries keep legacy pool names ("Yearly"/"Life"), which
  LifeEventsEngine still resolves.

PACK PORTABILITY (audit, see Docs/AUDIT)
  GamePacks/academy is an EXPERIMENTAL probe pack (different stat set, rivals,
  a 3-round tournament chain, no cultivation) used to find base-game
  assumptions. Rules that came out of it:
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
  New-pack workflow: copy a GameManifest, enable only modules you supply content
  for, override content modules (whole module or Content.Extend; rebuild ById
  indexes when replacing lists), run ContentValidator.RunAll, set ActivePack,
  run TestRunner in a playtest; failures and skips show what the pack lacks.

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
  Modules/WheelSystem (Reincarnate remote, only while dead): spin a bloodline
  (Lineages module) or a talent slot for Karma; Shared/Gacha rolls weighted
  rarities (RacesConfig.Spin 65/24/8/2.5/0.5, TalentsConfig.Spin) with pity rules
  (Epic+ by the 15th spin, Legendary+/Mythic by the 60th; small pools without the
  guaranteed rarity fall back safely). Lock (60 Karma) keeps a bloodline for every
  next life; spins are refused while locked; unlock is free. Rebirth uses what the
  wheel holds. The Collection Codex (state.Codex, permanent) records every race,
  talent, title and technique ever obtained: +1% AllStatXp and QiMult per entry
  (TalentsConfig.Codex). Requirement field Race gates bloodline-only content
  (clan_elders, primordial_awakening). Spec: WheelSpec.
  Spin luck (Karmic Fortune +8%/rank, Immortal VIP +25%) multiplies every rarity
  above the lowest (Gacha luck argument). Each spin fires Remotes.SpinResult; the
  client rolls Shared/WheelSpinner (3D drum: RenderStepped, cubic ease-out, UIScale /
  TextTransparency by distance from the center line, tick per row, flash + fanfare
  for Epic+); AgingSystem delays the result toast until the drum lands.

WORLD: REGIONS, MAP, TRAVEL (World engine module, optional; base pack on)
  WorldRegionsConfig (6 regions: Qinghe, Crimson Reach, Imperial Capital as starters;
  Kunlun needs Qi Condensation, Blood Marsh age 14, Shattered Star Ruins Core
  Formation), Modules/RegionSystem, Shared/EngineModules/World (Map tab + Page).
  - Birth: a PlayerState.NewLifeHooks entry rolls a starter region (StarterWeight);
    Direct Descendants are moved to the family's region by SamsaraSystem.Apply.
  - Region modifiers are the "Region" per-life buff source (PlayerState.SetLifeBuff),
    refreshed yearly and on travel (Blood Marsh demonic bonus at Alignment <= -20);
    hazards cost health yearly; the Ruins add +10% glimpse chance.
  - TravelAction remote: neighbors only, age 12+, destination Requires, 1 action
    diamond + TravelFee, then a road encounter (TravelEventsConfig events with
    Trigger = "Travel", picked by Weight/Route/Requires). Regional events use the
    Region requirement (black market, imperial exam, orthodox sect trial, star relic).
  - The Map page mirrors RegionSystem.Check for instant feedback; roads are rotated
    frames redrawn on resize. Spec: WorldSpec.

DYNASTY: HEIRLOOMS, RELATIVES, FAMILY TREE (Dynasty engine module + Lineage tab)
  FamilyTreeConfig, Modules/DynastySystem, Shared/LineageMemory, UIController/FamilyTreePage.
  - Consecrate one equipped Weapon/Robe/Talisman (DynastyAction). At death it becomes
    an heirloom in state.Heirlooms (permanent): +5% AllStatXp soul stack per generation
    (each new life). Direct Descendants inherit family heirlooms at 12; any other
    rebirth leaves them Lost with the old family in its region (heirloom_reclaim: buy,
    duel or steal; requirement LostHeirloomHere).
  - Past-life records (PlayerState.DeathRecorders) gain Region, Occupation, Rival,
    Partner, Heirloom, Biography and NextPath (Descendant = gold bloodline link on
    the tree, anything else = cyan soul leap).
  - The Mist of Time (LineageMemory): clear <= 2 generations, oral history <= 4,
    then a forgotten stone "An Unknown Ancestor of <Region>"; Ancestral Chronicler
    (+1/rank) and Soul Retention (+0.5/rank) delay it; Nascent Soul+ ancestors and
    heirloom creators are never forgotten.
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
    Full rebirths spin it on the Wheel (SpinLegacy, 20 Karma, own pity).
  - GeneticsConfig + Shared/GeneticsText: friends, rivals and partners get Genetics
    { Race, Grade, Trait } via PlayerState.RelationshipHooks. Grades gate romance
    (Charisma, realm) and add a chance penalty to romance and duels; each grade adds
    25 years before old-age death (LongevityPerGrade).
  - Children (relationship type Child, category Child): TryForChild (partner, 18+),
    child_born event (HaveChild). Genetics from both parents: 60/40 bloodline, mutation
    10% + spouse grade bonus (to 35%) raising one rarity tier, one of your talents, the
    spouse's trait at 50-80%, potential from your peak stats; upbringing guidance once
    (Martial / Scholarly / Spiritual, child age <= 15).
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
    0.4 levels/year (+0.3 for the upbringing focus), proficiencies after 12, the Spirit
    Root from 6; the family is wound back only for the age-25 adult snapshot.
  - Grandchild (children 19+): reborn at 0 as the heir's newborn; genetics combined once
    more (another awakening chance); the heir is your Parent, your old spouse your
    Grandparent, the heir's children your siblings.

TACTICAL CLASH DUELS (Modules/DuelSystem, DuelConfig, UIController/DuelModal)
  Best of 3 exchanges; stances Strike > Channel > Guard > Strike (+35% for the advantaged
  side). Stance power from stats, best proficiency, realm, techniques and equipment;
  the foe scales from your average (Difficulty by kind, rival grade, sect rank) and
  favors one stance (shown on its card). DuelAction remote: Stance / Quick / Close; an
  open duel quick-resolves when the year advances. Used by Blood Feud and Wager duels,
  sect promotion trials and the heirloom_reclaim duel (effect StartDuel); outcomes are
  registered as DuelSystem.Outcomes[kind]. Dev console: duel [difficulty].

ASCENSION ENDGAME (Modules/AscensionSystem)
  At True Immortal 9 the Breakthrough seal becomes ASCEND (AscendAction): the life ends
  with +500 Karma, state.Ascensions +1, Heavenly Ascendant in the Codex, and every later
  life gets the title flag and a Divine Legacy life buff of x1.1 all stat XP and Qi per
  ascension. The client plays the golden ending screen on the Ascend feedback cue.

UI JUICE (StarterPlayerScripts/UIJuiceAnimator, client, --!strict, no dependencies)
  Watches PlayerGui (existing + DescendantAdded, deferred one step) and adds motion
  without touching any screen's code:
  - Bars: frames named "Fill" / "...Fill" (every UIStyle.bar) or JuiceBar = true glide to
    each new Size (TweenService:GetValue Quart Out, 0.28 s) from one Heartbeat loop that
    disconnects when nothing moves. A Size write the animator did not make is a new
    target, so UIStyle.setBar stays the API.
  - Popups: frames whose name has Modal / Popup / Panel / Window / Dialog / Overlay /
    Menu / Shop / Inventory (or JuicePop = true) pop 0.82 -> 1 (Back Out, 0.22 s) when
    Visible turns true. A frame covering its parent (modal roots, dimmers) pops its
    centered children (the Card) instead. Created-visible frames pop only with JuicePop.
  - Buttons: hover 1.04, press 0.92, Back spring on release; touch skips hover;
    buttons covering their parent (ClickShield) and non-Interactable / inactive ones
    stay still.
  All scaling goes through a UIScale named "Juice"; objects that already own a UIScale
  (ResponsiveScale roots, hand-animated cards like ShopModal/DuelModal/EventModal Pop,
  wheel rows) are skipped, since Roblox applies one UIScale per object. Opt-out:
  attribute NoJuice on a ScreenGui or any ancestor (the intro loading bar has it, as it
  tweens itself); engine/tool GUIs (TouchGui, Freecam, DevConsole, Chat) are skipped.

TAB ROWS AND HEADER OFFER (UIController, ChronicleHUD, MenuModal)
  - layoutTabs: visible tabs share the bar evenly; past TAB_ROW_MAX (9) they wrap into
    two rows (UIListLayout.Wraps). Wide screens grow the bar x1.65 and the pages give
    up that height (tabBase holds the one-row geometry of the last layout pass); phones
    split their already tall bar instead.
  - Dossier styles (SoulPass, Dossier) place every panel themselves (UITheme.Layout):
    withHud reserves the header strip at the top (0.055, phones 0.075), compresses every
    rect above the command deck under it and docks the routine bar under the pages
    (0.05, phones 0.085). Without it the header covered the tabs and the routine bar
    covered the command deck.
  - The header ends in an "Offer" slot (HUD.OfferWidth 0.11). MenuModal docks the
    Starter Pack chip there (hover for details, x to dismiss), so no offer floats
    over a page. Avoid floating cards over Pages; dock them in header/bar slots.

PHONE LAYOUT RULES (checked on an emulated iPhone 16, 852x393 landscape)
  - ResponsiveUI touch targets (44 px) never grow past their parent; owners mark
    deliberately sized controls TouchSafe (tabs, header chip, routine/menu buttons,
    modal header tabs and Close, stacked Spin/Lock, stat (i), skill tiers, Gift tags).
    Setting TouchSafe later removes an applied minimum.
  - Text: the readable minimum is capped so the longest word stays on one line
    (measured with GetTextBoundsAsync) and then stepped down while TextFits is false,
    as far as 7 screen px.
  - ChronicleHUD.ApplyProfile: phones drop the header Name (the sheet shows it), use
    short Identity/Year text and a short Offer label (PhoneText), and give the routine
    bar twice the height without caption or last gain.
  - Tabs: two rows of icons (PHONE_TWO_ROW_GROWTH). Pages with 3+ full-height columns
    (STACK_ON_PHONE) stack them full width on a canvas of 2 x columns.
  - Per page: Bonds actions wrap in threes, Talents trees 2 x 2, Skills two cards a row,
    Legends/Raids taller rows; Menu and World modals get a bigger card on phones.

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
  Got it / Skip. Pack-independent (reads layout, never content). Verified with
  Studio device emulation (iPhone 13 844x390, iPad A16 1180x820) and desktop;
  ResponsiveSpec checks the profiles.

CREATION SCREEN GUARD
  GamePack.CreationSpins() says which Life 1 pre-birth wheels can roll (Lineages +
  RacesConfig.Spin with entries; Dynasty + FamilyLegacyConfig.Spin with entries).
  With none (e.g. modern_life), CreationSystem closes Creation at birth and
  IntroAndLoadingUI goes straight to the prologue; a missing wheel hides its button.

AUDIO AND JUICE
  PlayerState.Feedback(player, cue, data) -> Remotes.Feedback -> StarterPlayerScripts/SoundFX:
  Clash, DuelStart/Win/Lose, BreakthroughSuccess/Major/Fail (fail shakes the main panel),
  Milestone, Ascend, Purchase, Revive; the Advance Year button clicks locally; the drum keeps its own tick
  and fanfare. Sounds are Roblox built-in rbxasset:// sounds verified to load in Studio;
  swap them for rbxassetid:// audio in SoundFX.CUES.

MASTERS: REGIONS AND SECT RANKS
  MastersConfig.Regions: Seek a Master only finds masters of the current region (Han and
  Long in Qinghe, Bai and Su in the Capital, Mo and Ye on Kunlun, the Blood Lotus in the
  Marsh / Crimson Reach). SectRanks: Outer -> Inner -> Core -> Elder -> Grand Patriarch with
  yearly stipends; MasterAction "Trial" (1 action, Requires incl. MasterLoyalty, chance
  + TrialStat) promotes. Kunlun: Foundation Establishment, or AltRequires age 16 + AltFee
  $1,500 sect toll (RegionSystem.Check, Map page).

ADULT DUELS
  Rival interactions: Spar (pride), Wager (16+, 20% of your money, min $100), Blood Feud
  (16+, the loser dies or you lose 60 health). Grade penalty + 4% per realm above Mortal.

THE OLD RIVAL TWIST (Samsara)
  Echoes now remember their region; a rival who outlived you is Powerful when you
  died at Qi Condensation+. rival_mentor (RivalMentorHere) -> BecomeRivalDisciple:
  yearly lessons in the old life's top proficiency, their signature technique after
  2 years ("Technique" life buff), and after 3 years plus a glimpse or proficiency
  20 the rival_reckoning (Trigger = "System"): reveal your past life in a duel
  (needs RemembersPastLife) or inherit their legacy. Every rebirth also gets a new
  rival of your own age at 8.

PROGRESSIVE DISCLOSURE
  ProgressionGatesConfig: tab ages (Bonds/Study 4, Bag 7, Masters/Talents/Map 12),
  the cultivation strip waits for the Spirit Root (flag SpiritRoot from spirit_root,
  or age 7), milestone toasts (Modules/MilestoneSystem). Actions carry MinAge/MaxAge
  and Requires (TrainingSystem.Check); TrainingPage hides what is not available yet.
  Infants: Crawl & Play, Listen to Parents, Rest. Careers and part-time jobs at 16.
  Spec: ProgressiveDisclosureSpec.

INTRO AND PROLOGUE
  ReplicatedFirst/IntroAndLoadingUI replaces the default loading screen (obsidian,
  double gold frame, rotating Bagua seal with drawn trigrams, at least 2.5 s; Studio
  workspace attribute HoldLoadingScreen holds it for UI checks) and plays the
  reincarnation prologue (WorldRegionsConfig.Prologue, typewriter via
  MaxVisibleGraphemes, Skip / Continue) at age 0 of every life when World is on.

SAMSARA META-PROGRESSION (permanent, bought on the Wheel)
  SamsaraUpgradesConfig (WheelSystem BuyUpgrade, Karma, only while dead; state.Upgrades
  is saved): Temporal Awareness (+1 free diamond x2), Karmic Fortune (+8% spin luck
  x5), Soul Retention (+5% glimpse chance/strength x5, slower memory decay), Social
  Magnetism (+1 social x2), Ancestral Chronicler (+1 remembered generation x3).
  Game passes and products: see IMMORTAL TREASURY.

IMMORTAL TREASURY (MonetizationConfig, Modules/MonetizationSystem, UIController/ShopModal)
  Passes (ownership runtime only, state.Passes stripped by Serialize, refreshed on join
  and after PromptGamePassPurchaseFinished):
    Celestial Timekeeper  +1 golden diamond, auto-age 1.5 s/year (AgingSystem asks
                          PlayerState.GetAutoAgeSeconds per player)
    Fate Weaver VIP       +1 golden, +25% spin luck, x2 Wheel speed, [VIP] name badge
    Bloodline Vault       bloodline Lock costs 0 Karma (PlayerState.HasFreeLock)
  A newly granted pass's golden diamond is usable the same year.
  Developer products: MarketplaceService.ProcessReceipt -> GrantProduct. PurchaseIds go
  in state.Receipts (saved, last 60) so a retried receipt never grants twice; the receipt
  is confirmed once PlayerState.Save succeeds (always in Studio).
    Karma packs 50 / 200 / 600; Miracle Pill: Qi to 100% + state.PillBonus 0.2, spent by
    the next breakthrough attempt; Miracle Revival (death prompt only).
  Miracle Revival: PlayerState.Die keeps a runtime deep copy of the life when the death
  is untimely (age < max lifespan, not options.Final, not already revived this life).
  Revive restores it at 50% health, takes back the death's Karma, keeps receipts,
  passes, tutorial progress and the pill; PendingEvent/PendingDuel are cleared. Natural
  deaths and Ascension pass { Final = true }. Any successful Wheel action clears the
  offer (AgingSystem); a late receipt refunds ReviveFallbackKarma instead.
  Items with Module = <engine module> are hidden/refused when the pack lacks it.
  ShopAction remote ("BuyPass" | "BuyProduct", id, sandbox): Studio Test Purchase
  (sandbox, honoured only when RunService:IsStudio(), and automatic for ids still 0)
  grants for free with the same celebration; live servers always prompt Roblox.
  Feedback cue Purchase -> gold celebration banner + sound; Revive -> sound.
  UI: gold header button at the end of the tab row and the Samsara page; the shop card
  lists passes and visible products; the Heaven's Verdict card opens on an untimely
  death (Defy / Accept fate). Item texts use Terms tokens ({MetaCurrency}, ...).

LIFE 1 ONBOARDING (Modules/TutorialSystem, UIController/TutorialGuide)
  Four banners with a pulsing ring, each once when its moment comes: 1 creation wheel
  (Lineages packs), 2 action pips on the first turn, 3 Advance Year when actions hit 0,
  4 Meditate + Breakthrough when the energy bar wakes (cultivation packs; others end at
  3). Doing the thing or "Got it" moves on, "Skip tutorial" ends it. The guide waits
  under the intro, life-event modals and the shop. TutorialAction remote ("Step", n |
  "Skip") stores TutorialStep / TutorialCompleted (saved); Life 2+ is always completed
  and older Life 1 saves past age 12 are left alone. Dev console: tutorial reset|skip.

PACK THEME & TERMINOLOGY (Configs/UIThemeConfig, GamePacks/<pack>/UIThemeConfig,
Shared/PackTheme)
  Palette (UIStyle.C keys: "gold" = accent, "qi" = energy), Fonts (Enum.Font names,
  unknown -> default), Corner multiplier, Pip { Rotation, Corner } and Terms. Packs use
  Content.Extend so they list only what changes; PackTheme.Get merges onto the base.
  Server messages use the active pack's words too: PlayerState.Words("+%d {MetaCurrency}")
  / PlayerState.Term(key); a lowercase token ("{raceName}") gives the lowercase word.
  AdvanceTierName: Breakthrough / Promotion (modern_life) / Awakening (academy).
  UIStyle applies the palette/fonts at require, so every page is themed; UITheme maps
  base colours baked into the layout to the pack's and reads pip shape and words;
  IntroAndLoadingUI reads palette and RaceName. UI code never hardcodes genre words:
  use S.Terms (EnergyName, TierHeader, AdvanceTierButton, RaceName, RebirthTab,
  MetaCurrency, ShopName, ...). Glyphs must exist in the UI fonts (verified: ◆ ❖ ● ★
  ☯ ⚜; not ✦ ✧ ⬢ ✕). Base: obsidian/jade/gold, diamonds 45°; modern_life:
  slate/cyan/emerald, round badges 0°; academy: crimson/charcoal, violet/silver,
  crests 15°.

REBIRTH PATHS, ERAS, ECHOES, GLIMPSES (Samsara engine module, optional)
  RebirthPathsConfig, Modules/SamsaraSystem, WheelSystem ChoosePath + Confirm (path
  cost paid at rebirth; Confirm captures the old life before PlayerState.Reincarnate):
  - Descendant (30 Karma, free if Married at death): surname, 25% of wealth, the
    first equipped item as heirloom, family affection 85-95.
  - Stranger (free, default): same era; Partner/Friend/Rival who were alive become
    echoes, met through past_life_encounter (MeetEcho effect, aged forward).
  - Ancient era (25): era LifeBuff QiMult 1.25, -25 max health, +2 stress/year,
    primordial_beast event. Future (25): legend_of_self (LegendOfSelf effect reads
    the old name, realm and alignment).
  - Past-Life Glimpses: Growth year tick, ages 4-30, max 3 per life, chance
    8% + Soul Retention; recover strength (15% + Soul Retention) of the old top
    proficiency and attribute, plus Qi if the old realm was higher; narrated in the
    Chronicle. Requirement fields HasEcho, Era, RemembersPastLife (special options).
  Per-life data: state.Modules.Samsara. Era buffs use the generic state.LifeBuffs.
  Spec: SamsaraSpec. Packs without the module rebirth exactly as before.

PROGRESSION PACING (hard scaling)
  Attributes and proficiencies cap at PlayerStatsConfig.MaxLevel (60). Realm
  stabilization (YearsPerLevel) outgrows realm longevity after Nascent Soul, so a
  fresh life peaks at Core Formation-Nascent Soul and True Immortal needs lifespan
  legacies (bloodlines, Mythic talents) from many lives. Repeatable lifespan items
  need Use.MaxPerLife (the validator warns otherwise). Run titles (Demon Cult
  Blademaster, Scholarly Emperor, Pure Qi Immortal) reward dedicated builds.
  Measured with BalanceReport.Campaign (see Docs/BALANCE).

UI THEME (obsidian, smoked jade, burnished gold, parchment)
  Shared/UIStyle holds the palette used by every page; Shared/UITheme restyles the
  static layout idempotently: double-bordered panels (ink frame, gold trim, corner
  gems), avatar seal (realm initials, bloodline rarity border), vital bars with
  icons, ActionGems (rotated diamonds in non-rotated holders: layouts ignore
  Rotation on direct children; jade free, gold pass, dark socket spent) + social
  counter above the +1 YEAR medallion, two-column ledger, medallion that
  pulses at 0 actions, realm emblem, crimson ritual Breakthrough, connected tab bar
  (icons, gold underline), old-palette retint. Applied once in edit mode (with
  Preview cards, so Studio never shows empty panels) and by UIController at
  startup (previews cleared). Pages may use ctx.Theme.frame. Lineage tab =
  Samsara page in three columns (wheel + drum, rebirth path + Karma upgrades,
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

CONTENT EXPANSION (2026-11-02, base pack)
  Every content pool of the base pack was doubled with new entries (marked
  "Content expansion (2026-11-02)" in each config); packs that replace a config keep theirs.
  - Events: yearly 38 -> 76 (sect_recruiters -> sect_letter chain), cultivation/fate 14 -> 28,
    travel 10 -> 20 (5 road encounters, 5 regional events).
  - Journal: life goals 43 -> 86, daily quests 8 -> 16. Titles 38 -> 76.
  - Wheel: talents 18 -> 36, bloodlines 11 -> 22, family legacies 7 -> 14, Samsara upgrades
    13 -> 26 (existing effect keys only).
  - Character: upbringings 8 -> 16, hidden talents 8 -> 16 (journal counters), fusion
    recipes 23 -> 46. Genetics traits 6 -> 12.
  - Items 29 -> 58 (market 14 -> 28), world-hub drops/recipes/merchant/events doubled,
    raid shop 5 -> 10, relics 3 -> 6, epitaphs 5 -> 10, omens 6 -> 12.
  - Battle enemies 11 -> 22 (new bosses: Blood Lotus Elder, Nine-Tailed Fox, Heavenly Demon Lord).
  - Training actions 17 -> 34. Ids never collide across talents, titles, hidden talents and
    events (the Codex and fusion look traits up by id).
  - Social: interactions 14 -> 28 (generic Affection/Happiness/Stress/MoneyCost ones); the
    Bonds cards now have a fixed 84 px header and wrap actions in rows of 5 (3 on phones),
    every card as tall as the one with the most rows. Name pools doubled.
  - NPCs: occupations, personalities, goals and actions doubled. NPC money effects never push
    the player below $0 (a loan takes at most what you have).
  - Careers 8 -> 16, schools 6 -> 12, masters 7 -> 14 (one per new region), mastery nodes 16 -> 32
    (four deeper nodes per branch), world regions 6 -> 12 with two-way roads.
  - Balance: new Qi sources stay below the existing ones (Thunder Plateau x2 < Ruins x2.5,
    Bone Desert x1.5 < Marsh x1.6, Marrow Pill 1 Qi level and 4 per life, big fate events
    0.6-1.2 Qi) so fresh lives still peak at realm 4-5 in Tools/BalanceReport.
  - Kept as designed on purpose (structural systems, not pools): realms, skills, spell schools,
    proficiencies, personality sliders, legend thrones, minigames, career/sect rank ladders.

ENGINE SYNC FROM THE STANDALONE GAMES (2026-10-30)
  Ported from SoulPath.rbxl (built from Cursed Path, itself from the cultivation release),
  keeping this template's packs (per-pack PackTheme, Content chain, ContentValidator.RunAll,
  pack-aware tests). Genre content was not ported; the base pack keeps its cultivation text.
  - Fixes: family tree zoom/fit and text inside node boxes; panel UIPadding added before
    the frame trim (World map, duel modal); staged loading screen that waits for the
    first render (UIController sets the Ready attribute); tutorial guide waits for the
    creation wheel to be on screen; the journal logs only the final starter spin.
  - Engine words as Terms with neutral defaults (PackTheme DEFAULT_TERMS): mentor /
    student / sect, peak, revive, birth, ascension and legacy-buff lines, map title,
    LegacyName, HeirloomName, loading emblem/title/stage lines. The base pack keeps the
    original cultivation wording; modern_life and academy define their own.
  - Rarity display names in server messages (Gacha.RarityName), Terms.MoneySymbol
    (UIStyle.money, PlayerState.FormatMoney), genetics text via GradeLabel / GradeSuffix,
    optional Short names for duel stances and proficiencies, Fonts.Mono (RobotoMono).
  - Modern layout styles, opt-in per theme with UIThemeConfig.Style: "Dossier" (top ID
    banner, docked command bar) and "SoulPass" (twin-wing card, top Reiatsu strips); see
    Shared/UITheme LAYOUTS and UITheme.Layout. Packs without a Style keep the classic look.
  - Loading screen emblem seal (Terms.LoadingEmblem; the base pack uses ☯), themed fonts
    and corners; modern map page (theme colours, Terms.MapTitle, nodes that scale).
  - Studio-only UI check switches: workspace attributes HoldLoadingScreen, SkipIntro,
    StartTab.
  Verified: base 186 passed; modern_life 151 passed / 35 skipped; academy 140 passed /
  46 skipped; 0 failures; ContentValidator.RunAll 0 errors (pack warnings are the usual
  disabled-module notices).

2.0 ENGINE, PHASE 1: NARRATIVE & PROGRESSION (2026-10-30)
  Anti-bug shield
  - Shared/ModalShield: Attach(overlay) adds a full-screen invisible TextButton (Active,
    Modal) under the card, so no click passes through a popup (EventModal, DuelModal,
    TreasuryOverlay, VerdictOverlay, PathModal; the intro screens use the same shield).
    AnyOpen()/Changed/OpenRects() let the tutorial hide while a popup is up;
    ClampRect/Clamp keep tutorial rings and the guide banner 8 px inside the viewport,
    and the banner moves off any open card (never over a modal header).
  - Growing containers: UIStyle.fit (AutomaticSize.Y, padding 6 top/bottom, 10
    left/right), UIStyle.autoLabel, UIStyle.toScroller. Used by the chronicle entries,
    the stat cards (Training page, list now scrolls) and the birth screen's trait boxes.
  3D void scene
  - StarterPlayerScripts/VoidScene (client only): black Atmosphere + Bloom, a procedural
    spirit tree of Neon cylinders (seeded, UIThemeConfig.Scene), magic-circle floor,
    motes, the player's avatar copy as a black Highlight silhouette (outline = theme
    gold), and a breathing camera tween. UITheme.SceneGlass: Main/Sheet at
    PanelTransparency 0.12 with magic-circle watermarks and golden L brackets.
    Scene.Enabled = false keeps the flat 2D backdrop.
  Birth screen (ReplicatedFirst/IntroAndLoadingUI, Modules/CreationSystem)
  - Quick Start ("Quick"): free spins left roll instantly, born at once, no prologue.
  - Three trait cards (Bloodline, Family Legacy, Innate Talent = GamePack.CreationSpins
    Talent, talent slot 1) with rarity gem, title, buffs and signature; "Your Trait
    Buffs" box; Blood Ladder = the main wheel's real odds per tier (Terms.LadderTitle).
  - Rerolls of every card: "RerollMeta" costs MonetizationConfig.BirthRerollMetaCost
    (30) in the meta currency; product BirthReroll (199 R$) is a paid random item:
    PolicyService.ArePaidRandomItemsRestricted hides it on the client and refuses it
    on the server; a late receipt after birth refunds meta currency.
  Main HUD (UIController/ChronicleHUD, Modules/ChronicleSystem, Configs/ChronicleConfig)
  - Header: Name <<Title>> | Race . Gender . Age . Stage | Year . Era | City | wealth .
    social class | fame tier | Life #. World year = BirthYear + Age; Life 1 is born in
    StartYear, later lives RebirthGap years after the last death (state.WorldYear).
  - Dual bar: ACTIONS x/y + SOCIAL x/y + AGE UP. Routine bar: Relax/Just Be a Kid,
    Help the Family, Study, Socialize; the active routine pays its Gains every year
    (year tick Systems, Order 5). Today's Omen: one claim per UTC day (state.OmenDay).
  - Today tab (UIController/TodayPage, default tab): omen banner, CURRENT GOAL with
    progress, 3 THINGS TO DO cards, the latest chronicle line with a typewriter toggle
    (ctx.Typewriter, also used by the event modal). Event choices are gold buttons; a
    risky choice (Chance roll or Risky = true) and a health-costing training action
    show a warning badge.
  YOUR PATH (UIController/PathModal, Modules/PathSystem, Modules/ChoiceStats)
  - Each resolved event becomes a node in state.PathLog (per life, saved, not in the
    snapshot; PathQuery "List"): what happened, your choice, roads not taken,
    consequences, how the world remembers it (LifeEventsEngine Before/AfterResolve).
  - How everyone chose: real counts in DataStore ChoiceStats_v1 (flushed every 60 s
    and on close); below ChoiceStats.MinSample (50) the card says there is not enough
    data. Never simulated.
  - Return to This Path (product PathRewind, 99 R$): checkpoints of the last 6
    decisions of the session (runtime only) restore per-life fields, trim the log and
    ask the question again; account data (Karma, receipts, lineage, codex, upgrades,
    heirlooms, omen day, world year) is never rolled back. PathAction "SelectRewind"
    picks the node before the purchase.
  Studio checks: workspace attributes SkipIntro, StartTab ("Today"...), OpenPath.
  Spec: ChronicleSpec (SystemRegistrySpec order now includes ChronicleSystem).

2.0 ENGINE, PHASE 2: RPG STATS, SKILLS, MAGIC, CHARACTER, MINIGAMES, BATTLES (2026-10-31)
  New optional engine modules (Shared/EngineModules, enabled in the base pack only):
  Skills, Arcana (requires Skills; tab "Magic & Sword"), Character, Minigames, Battle
  (requires Skills). Skills owns the combat buff keys (SwordDamageMult, MagicDamageMult,
  ManaCostMult, DamageTakenMult, GoldMult, BattleRewardMult, FleeBonus, SkillXp,
  SkillXpMult); Character re-declares them for its personality buffs.
  Attributes (PlayerStatsConfig)
  - 12 attributes in Groups: Physical & Aura (Strength, Agility, Vitality, Battle Aura,
    Aura Potential) and Magical & Mental (Intelligence, Mana, Magic Power, Magic Control,
    Luck, Charisma, Qi Control). MaxLevel = nil (no cap); ProficiencyMaxLevel = 60.
  - Rating(level): rating = level x RatingScale (2), adult average 50, bands 0+ Very Low
    ... 140+ Legendary; shown on the Training page with an (i) tooltip.
  - Shared/CombatMath is the only damage formula: sword = Strength, Agility, Battle Aura,
    Swordsmanship; magic = Magic Power, Magic Control, Magic skill, affinity, spell rank.
    Missing stats (packs with other attributes) count as 0. Saves gain new stats at 0.
  - PlayerState.StatResetHooks (after SetRace), PlayerState.LoadHooks (after a load),
    PlayerState.GetTrainingAgeOffset (Prodigy pass), Snapshot.TrainingAgeOffset,
    Snapshot.Grimoire, Snapshot.FusionDiscovered.
  Skills (SkillsConfig, Modules/SkillSystem, Skills tab)
  - 12 skills, ranks Beginner 0 ... God 90, XpForLevel 5 + 1.2 x level. Ceilings by life
    stage (Infant 3, Child 12, Teen 45, Adult 90, Elder none). Magic and Swordsmanship gain
    nothing before age 8 (Prodigy pass: 5; TrainingConfig Prodigy actions too).
  - Levels 15 / 30 / 45 unlock a yearly action (SkillAction remote, 1 action, risky
    ones have Chance + Fail) and a permanent passive (buff source "Skill:<id><level>").
  - Training trains skills (TrainingSystem.ActionHooks; explicit SkillXp or inferred from
    StatXp / proficiency). SkillSystem.ApplyEffects is shared by Arcana, Battle, Minigames.
  - SkillSystem.CounterHooks / LevelHooks; dev console: lifeskill <skill> <level>.
  Arcana (ArcanaConfig, Modules/ArcanaSystem, Magic & Sword tab)
  - Affinities 0-100 for Fire, Water, Wind, Earth, Healing (rolled at birth, one favored);
    special schools Sound / Gravity / Lightning / Shadow / Time open at Knowledge 15-75.
  - 7 spells per element gated by affinity; practice costs mana (refilled yearly), not
    actions; Mastery 0-5, chantless at 5. Emptying the pool = Mana Collapse once a year
    (max mana +6 / +3 / +2 / +1 by age). Silent Casting Trial at Magic Control 20.
  - Spell Forge (Magic 30, Knowledge 15, age 10, 1 action, once a year): 1-2 elements,
    shape, rank; TextService-filtered name. state.Grimoire is account-wide; later lives
    learn its spells (1 action), a Legend's spells (skill 75+ / peak fame 2000 /
    ascended) are Taught (free). Grimoire and FusionDiscovered survive a path rewind.
  Character (CharacterConfig, Modules/CharacterSystem, Character tab)
  - Upbringing (buff source, family affection), Hero (+10) / Neutral / Villain (-8),
    birthplace, echoes of the last life. Parents get adult attribute cards; Mana, Magic
    Power, Magic Control, Battle Aura, Aura Potential and Luck are inherited as birth
    levels, every other stat as an XP multiplier (buff source "Genetics").
  - 10 personality sliders pushed by training, rest, routines, risky / moral choices,
    battles, minigames, omens and the Personality event effect; past 50 a side grants
    buffs; Requirements field Personality gates event options (3 new yearly events).
  - Trait Fusion (age 12, once a year): 23 recipes (talents + revealed hidden talents)
    or a wild fusion of two same-rarity traits into a talent of the next rarity.
    4 hidden talents per life reveal through counters (spells cast, sneaks, battles won,
    omens, routine years, motes, skill actions).
  Minigames (MinigamesConfig, Modules/MinigameSystem, UIController/MinigameModal)
  - Catch the Light (15 s, score capped at 40) and Sneak to the Study (ages 4-16), once a
    year each, offered as THINGS TO DO cards on the Today page. Studio: workspace
    attribute OpenMinigame = "Motes" | "Sneak".
  Battles (BattleConfig, Modules/BattleSystem, UIController/BattleModal)
  - 11 enemies in unlock order, some regional; BattleConfig.Visible shows only fightable
    or beaten foes plus the single next target. 1 action to start, age 8+.
  - Attack (sword), Cast (spell; key chant Z/X/C/V x1.35, chantless always), Guard (-60%
    next hit, +12% mana), Flee (Agility + FleeBonus), signature move once per battle
    (x2.5, named after the birth talent or bloodline). Damage becomes real health loss
    (x0.4, never below 30%). A diagonal VS banner opens each fight.
  Spec: Phase2Spec (EventChainsSpec characters now have neutral life buffs;
  SystemRegistrySpec order includes CharacterSystem, BattleSystem and ArcanaSystem).

2.0 ENGINE, PHASE 3: WORLD HISTORY, LEGENDS, PEOPLE, WORLD HUB, RAIDS, JOURNAL, STORE (2026-10-31)
  New optional engine modules (base pack only): Legends (tab 95), WorldHub (requires
  Inventory), Raids (tab 96), Goals (tab 82). Core systems (always on): HistorySystem,
  BondSystem, SchoolingSystem, JournalSystem, CosmeticSystem. Account-wide state added to
  PathSystem.AccountKeys: World, FamilyClass, Raids, Journal, Cosmetics, Purchases,
  CodesUsed, Slots (plus Grimoire, FusionDiscovered). Snapshot adds World, Journal, Raids,
  Cosmetics, Purchases, CodesUsed, SlotCards.
  World history and rebirth (HistoryConfig, Modules/HistorySystem, UIController/RebirthModal)
  - World Chronicle (state.World.History, max 60): wars, invasions, successions, city
    destruction + rebuild (12-30 years), boss statues, taught spells, relics, raids.
  - Death screen: "Continue as your Child / Heir" (Descendant path, oldest child, family
    class and city kept) or "Reincarnate as a Random Soul" (Stranger path, class rolled
    Poor 30 / Commoner 55 / Noble 15). Both go through the Reincarnate remote, action
    "Organic" (GameManager refuses gameplay remotes from the dead). No pre-birth menus.
  - Birth anomalies 0.5-3% (x3 with Secret Birth): Born Blind (Mind's Eye), Born Frail
    (Glass Vessel), Heavenly Restriction (Mana capped at 0, body buffs). StatCaps are
    enforced in PlayerState.AddStatXp.
  Legends (LegendsConfig, Modules/LegendsSystem, Legends tab)
  - Seven Great Thrones with original names (config); Encounter (lead chance), Spar
    (1 action), Challenge (age gate, once a year, power vs holder; seat 4 is vacant and
    claimed at power 100k). Family Weapon at Crafting 20 (tier per 20 levels, cost 500),
    worn by every heir. 2 relic leads in one life recover a relic for all generations.
  - Hall of Lives: DeathRecorder adds Score, Title, Epitaph, Throne. Community Hall:
    CommunityHall RemoteEvent + CommunityQuery RemoteFunction + MessagingService; Share
    publishes in a spawned thread so the remote never yields.
  People and education
  - BondSystem: rel.Bond {Level, Xp} from RelationshipSystem.InteractHooks (talk, gift,
    TrainTogether); family / friend bonds feed the "Bonds" life buff.
  - SchoolingSystem (SchoolingConfig, ages 4-17): Village, Home, Tutor (120/yr, needs
    300), Mage Tutor and Sword Tutor (90/yr), Self. The Study tab reads "Education".
  World hub (WorldHubConfig, Modules/WorldHubSystem, UIController/WorldModal)
  - Tabs Events (2 h rotation, 20 min active buff, Wanted Posters paying Bounty Seals),
    Merchant (3 h rotation), Crafting (material drops from BattleSystem.WinHooks into
    trinkets; Inventory Sell +1 / Sell All), Friends (+10% growth with a friend in the
    server, +5% power and Guild Member title for group members, Weekly Champions on an
    OrderedDataStore). Rotations are seeded from os.time, so servers agree without
    storage. WorldHubConfig.GroupId = 0 until the group exists.
  Raids (RaidConfig, Modules/RaidSystem, Raids tab)
  - Normal 5 / Hard 15 / Expert 30 / Nightmare 50 / Calamity 75 (Calamity writes history).
    In-memory parties of 1-5, Quick Join, leader starts; odds 5-95% from party power;
    tickets 3 (+1 a day), tokens buy from the raid shop.
  Journal and legacy (JournalConfig, Modules/JournalSystem, Goals tab)
  - 7-day login streak, 3 daily quests (all three = +1 Karma), 43 Life Goals from
    state.Counters, 38 titles, Legacy Tree (8 SamsaraUpgrades: AllStatXp, LifespanBonus,
    StartingMoney, TalentChance, Heirloom) applied at birth.
  Store (MonetizationConfig, MonetizationSystem, CosmeticSystem, ShopModal, MenuModal)
  - The Trove category grid; Gift a Friend (ProcessReceipt routes pendingGift); one-time
    Starter Pack (19 R$); micro products 19-59 R$; 14 procedural frames
    (Shared/PortraitFrames, Guildbound free for group members); 99 R$ themes with the
    live Shared/ThemeSwitcher; passes up to the 2000 R$ ULTIMATE (choose birth stats,
    clamped). Items flagged RandomItem hide when PolicyService restricts paid random
    items (server and client). Save slots 2 and 3 (tarot carousel). Second Life uses
    PlayerState.DeathEscapeHooks (once per life). Codes RELEASE, SPINLUCK, SECONDCHANCE,
    FREE99, UNBOUND (once per account; no "like the game" gate, per Roblox policy).
  - All product and pass ids are 0 (Studio test grants only); set real ids before launch.
  Spec: Phase3Spec (SamsaraSpec and GeneticsSpec birth money now come from the class;
  SystemRegistrySpec order includes HistorySystem, SchoolingSystem, BondSystem,
  JournalSystem).

DECISIONS
  - Configs/ stays where it is as the base library rather than moving into
    GamePacks: existing saves, tools and the default game keep working, and
    packs only carry their differences.
  - Packs override whole modules (plus Content.Extend for patching) instead of
    field-level merging: simple to reason about, and each module stays a plain
    Lua table that the validator checks the same way.
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
    and gives every policy the same seeds (common random numbers). Hash-table order is
    not stable between runs, so the bot walks owned items and discovered masters in
    sorted order (an unsorted item loop made ~1 in 20 seeded pairs differ).

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
  Locations / organizations  PARTIAL        sects exist as masters; no locations
  Game manifest + modules    IMPLEMENTED    modules defined by files (EngineModules +
                                            SystemRegistry); Fame proves it
  Content validation         IMPLEMENTED    this milestone
  Save versioning/integrity  IMPLEMENTED    this milestone (migrations table empty)
  Save session locking       IMPLEMENTED    UpdateAsync lock key, verified on a mock
  Tests                      IMPLEMENTED    124 cases (incl. YearlyLimits, Wheel, PackPortability, SystemRegistry,
                                            BalanceReport, DevConsole, Tuning); skips; suite
                                            runs under any pack
  Balance diagnostics        IMPLEMENTED    Tools/BalanceReport, 6 policies, seeded, yields
  Developer console          IMPLEMENTED    Studio-only, F2; 24 commands; DevConsoleSpec
  Yearly action slots        IMPLEMENTED    BitLife-style slots + per-activity and social caps
  Reincarnation spins        IMPLEMENTED    Gacha with pity, bloodline lock, Collection Codex
  Bespoke UI theme           IMPLEMENTED    Shared/UITheme (edit-mode previews, Samsara page)
  Multi-pack content folders IMPLEMENTED    milestone 2 (GamePacks + Content)
  Interface per pack         PARTIAL        tab labels, counter names; other UI
                                            strings fixed (e.g. proficiency header)
  Pack-defined stat sets     IMPLEMENTED    stat roles; verified with academy pack
  Localization               MISSING        UI text is English in content/UI code
  Generative AI              NOT APPLICABLE none in project; keep rules authoritative

NEXT MILESTONES (prioritized in Docs/AUDIT)
  1. DONE: Tools/BalanceReport (results in Docs/BALANCE).
  2. DONE: Studio-only developer console (see DEVELOPER CONSOLE).
  3. DONE: module registry (Shared/EngineModules + SystemRegistry); see
     ADDING A GAMEPLAY MODULE, including module-declared UI tabs.
  4. Resource/progression abstraction (Qi + realms become one pack's resource).
  Later: descendants/dynasties, crafting, NPC-to-NPC relations.
================================================================================
]]

return {}
