--[[
================================================================================
 ENGINE AUDIT - pack portability                                  (2026-10-24)
 Historical: the modern_life and academy packs it mentions were removed on
 2026-10-25 (single standalone game; template backed up outside this place), and
 the base game was then converted to "Cursed Path: Sorcerer Lineage" (see the
 GENRE CONVERSION section at the end). Names below are the cultivation originals.
 Evidence comes from running code, not from documentation. Verified = exercised
 by tests or a live playtest in this audit.
================================================================================

METHOD
  1. Read the engine (GamePack, Content, YearSystem, PlayerState, GameManager,
     LifeEventsEngine, UI controller) and grepped for base-game names.
  2. Baseline: 73/73 tests, 0 validator errors on both packs.
  3. Built GamePacks/academy (Power/Technique/Speed/Spirit/Intellect/Charm,
     rivals, Sports Festival chain) and ran the validator, a player playtest,
     scripted lives, the full suite and a 60-life balance run under it.

SYSTEM STATUS
  Verified           yearly loop, training, events + chains + delayed effects,
                     relationships, NPC autonomy, titles, inventory, saves +
                     session lock (mock store), content validator, packs
                     (base, modern_life, academy), reincarnation/karma
  Under-tested       real DataStore + two live servers (needs a published place),
                     UI pages other than Training/sheet under non-base packs
  Partial            economy (static prices), interface text per pack, quests
                     (expressible as event chains + flags/counters, no quest log)
  Fragile            adding a gameplay MODULE: GamePack registry, YearSystem tick
                     order, GameManager remotes and UI tabs are edited by hand;
                     cultivation fields (Qi, RealmIndex) live in core state and
                     lifespan reads RealmsConfig even with Cultivation off
  Missing            combat model, factions/organizations, off-screen world
                     population, developer console, balance report
  Not applicable     generative AI (deterministic rules cover NPC behavior)

DEFECTS FOUND AND FIXED (each has a regression test)
  1. Client UI crashed on every render in a pack without an Intelligence stat
     (UIController sheet row).                       -> Roles.Knowledge
  2. Seek Master threw in a pack without Charisma (MasterSystem).  -> Roles.Social
  3. Snapshot threw in a pack without a Meditate action, so no state ever reached
     the client (PlayerState).                       -> Snapshot.QiGains
  4. Requirements silently PASSED on a stat the pack does not define.
                                                     -> fail closed
  5. Validator demanded valid content for disabled modules (55 of 163 academy
     errors were in content never used).  -> counted per module as one warning
  6. Counter names were engine constants.  -> Interface.CounterNames
  7. Tests assumed base stat names / base events / base actions, so the suite
     could not judge another pack.  -> skipUnless + pack-driven fixtures
  Result: academy went from 163 validator errors + 3 crashes to 0 errors with
  ~280 lines of content and no engine edits beyond the fixes above.

LATER WORK (2026-10-24): developer console, balance report + campaign, module
registry with UI tabs, BitLife yearly limits, Wheel spins/pity/lock/Codex,
hard scaling and the bespoke UI theme. See Docs/ARCHITECTURE and Docs/BALANCE.

TOP GAPS / RISKS (ranked)
  1. DONE (2026-10-24): Tools/BalanceReport, five seeded bot policies with
     automatic findings; results per pack in Docs/BALANCE.
  2. DONE (2026-10-24): modules plug in by files (Shared/EngineModules +
     SystemRegistry hooks); Fame added with no engine edit. UI tabs still manual.
  3. Cultivation state in core PlayerState (Qi, RealmIndex, realm-scaled stat XP,
     realm longevity, karma formula). Works when disabled, but a game with a
     different progression resource must reuse Qi. High; defer until needed.
  4. DONE (2026-10-24): Studio-only developer console (F2), see
     Docs/ARCHITECTURE "DEVELOPER CONSOLE".
  5. Real persistence untested (Studio API access off). Low effort once the
     place is published; high value before launch.

NOT WORTH IMPLEMENTING YET
  - A generic combat system: no pack needs turn-based combat; chance checks on
    stats cover duels/tournaments (verified in academy).
  - A separate quest framework: FollowUp/Delayed chains + Flags/Counters +
    Requirements already express multi-stage, branching, delayed quests; only a
    quest log UI is missing.
  - Stat aliasing in the loader (reusing base content under new stat names):
    convenient but adds hidden transforms; packs override content instead.
  - Localization, runtime pack switching, AI-driven NPCs.

RECOMMENDED SEQUENCE
  1. Balance report (multi-policy simulation per pack, written as a report).
  2. Studio-only dev console using existing server modules.
  3. Publish + verify DataStore and two-server locking.
  4. Year-tick/remote registry for modules, then progression-resource
     abstraction, each behind the existing tests and all packs.

THIRD-PACK VALIDATION (how to repeat it)
  Set GamePacks.ActivePack = "academy", Play, then on the server run
  ContentValidator.RunAll() and TestRunner.Report(). Current result:
  0 validator errors; 72 passed, 7 skipped (base fixtures / Inventory off),
  1 failed: "several events happened (3)" - the probe pack has too few events
  per life. That failure is a genuine content finding, left visible on purpose.
  The academy pack is experimental: not a finished game.

GENRE CONVERSION (2026-10-25): cultivation -> Cursed Path: Sorcerer Lineage
  A full re-theme of the shipped game in place, done as a portability check:
  content text, UIThemeConfig (palette, Bodoni titles, cursed-seal pips, terms) and
  the manifest changed; mechanics, numbers, ids, schema keys and save fields did not.
  Engine changes it needed (all genre-neutral, each defaulting to the old behaviour):
    - PackTheme.DEFAULT_TERMS: engine messages (mentor/student, revive, birth line,
      peak, ascension, legacy buff) became Terms with neutral fallbacks; the old
      code had "Heaven's verdict", "disciple of a master", "peak of the Dao" baked in.
    - Rarity display names (Spin.Rarities[key].Name, Gacha.RarityName,
      RacesConfig.RarityName): server messages printed raw rarity keys.
    - Optional Short names for duel stances and proficiencies (compact UI labels).
    - Terms.MoneySymbol for UIStyle.money / PlayerState.FormatMoney, GradeSuffix /
      GradeLabel for genetics text, C.jackpot palette role.
  Tests that compared literal genre words (ThemeSpec, WheelSpec, SamsaraSpec) now
  read the vocabulary instead. Result: 179/179 tests, 0 validator errors, BalanceReport
  0 errors / 0 violations; UI audit found only pre-existing 8-9 px labels.
  Remaining genre text: DevConsole help/output (Studio only) and engine module
  descriptions in Shared/EngineModules (developer-facing).
================================================================================
]]

return {}
