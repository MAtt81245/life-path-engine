--[[
================================================================================
 BALANCE REPORTS                                  (2026-10-24, seed 1, 20 lives)
 Tool: ServerScriptService.Tools.BalanceReport (see its header for usage).
 Reproduce: set GamePacks.ActivePack, Run, then on the server:
   local BR = require(game.ServerScriptService.Tools.BalanceReport)
   print(BR.Format(BR.Run({ Lives = 20, Seed = 1 })))
 Same seed = same numbers (verified: identical tables on separate servers).
================================================================================

POLICIES
  Idle      never acts; first available event choice (baseline for passive gains)
  Greedy    every action in list order; uses every enabled system
  Focused   spams the best XP-per-energy action; rests only above 75 stress
  Balanced  manages stress/health/relationships first, spreads XP, safest choices
  Random    random affordable actions and random event choices
  Specialist each life masters one stat (cycling through all); the social one
            courts a partner and keeps its five closest people close

COMMERCIAL LAUNCH (2026-10-25) - current numbers
  No gameplay tuning changed; the bot buys nothing, so campaigns measure the free game.
  Campaign 30 lives (seeds 7 / 3 / 1): Life 1 still peaks at Core Formation (seed 7: 7/9
  at 136), final realm not reached; BalanceReport 0 errors, 0 violations.
  Paid power stays bounded: golden diamonds sit on top of the free cap within
  MaxActionSlots (6); a revival is once per life at 50% health and refunds the death's
  Karma; the Miracle Pill is +20% for one attempt (still clamped to Realms.MaxChance).
  Display prices: passes R$149 / 399 / 249, Karma 50/200/600 for R$49/179/449,
  revival R$99, pill R$79 (real prices are set on the Creator Hub).

HEIRS, DUELS & ASCENSION (2026-10-24) - previous numbers
  Bot: takes over young heirs (<= 18) and asks adult heirs for a newborn grandchild
  (taking over a 25-year-old who never cultivated cost ~a realm per life), quick-resolves
  duels. Campaign 12 lives: seed 7 4/7 4/9 5/6 5/5 5/5 4/9 4/9 5/9 6/4 7/5 5/8 7/7 (2 heirs);
  seed 3 best 7/8 (2 heirs); seed 1 best 6/8 (4 heirs); 0 errors, 0 violations.

GENETICS & HEIRS UPDATE (2026-10-24) - previous numbers
  Core Formation YearsPerLevel 5 -> 8: Life 1 now peaks at Core Formation (seeds 1/2/3/7:
  4/5-4/8 at ages 118-139) instead of squeezing into Nascent Soul at its last breath.
  Measured: Kunlun travel was not the cause (blocking travel left Life 1 at 5/3).
  Bot: uses the 3 starter spins, courts its closest friend, tries for two children, and
  is reborn as the best-bred child unless it has 120+ Karma for a full wheel run.
  Campaign seed 7, 12 lives: 4/8 4/7 5/8 4/6 5/3 5/6 6/8 7/7 6/5 7/6 6/6 5/7, 2 heir
  rebirths, 0 errors, 0 violations (seed 3: best 7/5, 3 heirs). Spirit-root longevity
  (+25 years per grade) was needed: children otherwise died before their cultivator
  parent (heirs 0).

WORLD & DYNASTY UPDATE (2026-10-24) - previous numbers
  Campaign bot now also travels to richer-Qi neighbors it can survive (5x the fee in
  savings) and consecrates its first equipped item. Balanced, seed 7, 12 lives:
  life 1 peaks at Nascent Soul 5/4 (age 163; Kunlun's 1.5x Qi lifts it from Core
  Formation), lives 2-12 at realm 5-6, best 6/8; 0 errors, 0 violations. The Qi of
  Kunlun (1.5x) and the Ruins (2.5x) is the main new accelerator; the Ruins' -6 HP/yr
  and the Marsh's -3 HP/yr keep them from being free.
  Unlock ages: infant actions 0-3, study 4, physical training 7, weapon/Qi arts and
  masters 12, jobs 16; Meditate needs the Spirit Root (age 6 event).

SAMSARA META-PROGRESSION (2026-10-24) - numbers before the World update
  Life 1: 2 action diamonds (BaseActionSlots), 3 social interactions. Free diamonds
  cap at 4 (Temporal Awareness, stat peak, realm, windows); pass diamonds go to 6.
  Campaign bot (Balanced, seed 7, 12 lives): buys Temporal Awareness first, then
  Karmic Fortune / Social Magnetism / Soul Retention with at most half its Karma,
  picks Descendant when married (else Stranger). Result: life 1 peaks at realm 4
  (age 125); realms 5-6 by lives 2-11; realm 7 at life 12; 0 errors, 0 violations.
  Upgrade costs: Temporal Awareness 40/120, Karmic Fortune 20-160, Soul Retention
  15-125, Social Magnetism 30/90. Paths: Descendant 30 (free if married), Past and
  Future 25. Glimpse: 8% (+5%/rank) per year at ages 4-30, max 3, 15% (+5%/rank).

CORE LOOP OVERHAUL (2026-10-24) - superseded numbers kept for history
  Changes: yearly action slots (4, max 6) with per-activity caps; social budget 4
  a year, once per person per interaction; bloodline/talent spins with pity, lock
  and Codex; attribute/proficiency cap 60; realm pacing retuned (YearsPerLevel
  0,2,3,5,10,16,24,35,50,70,100; LongevityBonus 0,5,10,15,25,50,100,200,350,600).
  Fresh lives (12 per policy, 1500-year cap): every policy dies of old age;
  realm at death Greedy 5, Focused 5, Random 5, Balanced 4, Specialist 4
  (target Core Formation 4 - Nascent Soul 5); FINDINGS (0).
  Campaign (BalanceReport.Campaign, Balanced, reincarnating with Wheel spins):
  seed 1 grows from Nascent Soul in life 1 to Void Refinement by life 8 as
  bloodlines and lifespan talents accumulate; seed 2 first reached True Immortal
  9/9 in life 59 ("dozens of rebirths"). A longer 3-seed x 80-life batch was
  lost to a Studio timeout and not rerun.
  Exploits found by the new detectors and fixed:
  - Longevity Peach (+5 years, once a year) gave endless life to any rich
    character -> Use.MaxPerLife = 6; lifespan_runaway finding added.
  - Pity on a pool without the guaranteed rarity crashed the roll -> falls back.
  Note: bloodline-only events (Race requirement) are covered by the campaign, not
  by fresh lives.

TUNING PASS (2026-10-24) - what changed and what the report says now
  1. End-game by ~165 -> RealmsConfig.YearsPerLevel (0,1,1,2,3,4,6,8,12,16,25):
     each sub-level must stabilize before the next breakthrough. Qi gains are a
     fraction of the requirement, so attempts (not Qi) were the only gate; real
     players could attempt after every meditation. Now: no progression_ceiling
     in 400 years (realm 9-10 reached); in 1,200-year runs Balanced reaches
     True Immortal 9 in 10/10 lives at median age 742, Specialist in 2/10.
     UI shows "Stabilizing - N yr"; dev console: why breakthrough. Validator
     warns if stabilizing a realm takes longer than its lifespan.
  2. Training self-damage -> TrainingSystem.InjuryFloor = 0.3: actions that cost
     health are refused below 30% max health ("Rest first"). Base Focused: early
     deaths 20/20 -> 3/20 (events/stress, now INFO). Academy: Greedy 36 -> 80,
     Focused 23 -> 80; zero findings.
  3. Unreachable prodigy / social_butterfly / proposal -> no content change
     needed: the new Specialist policy unlocked both titles and fired proposal
     (3x in modern_life). They were reachable; no bot played that way.
  After: base 0 WARN (INFO only), modern_life 0 findings, academy 0 findings.
  Tests: base 103/103, academy 95 passed / 8 skipped.
  Still open (design call, not a defect): in modern_life an Idle life with an
  early free job ends as rich as active play; education does not pay off.

BEFORE TUNING (kept for comparison)

BASE (life_path_xianxia)
  Idle      death 81      best stat 13   money 2.9e5  realm 1
  Greedy    17/20 alive at 400, 3 died ~151 of wounds; realm 11 in 17/20 by ~166
  Focused   all died ~150 of wounds (PhysicalTraining 92% of actions)
  Balanced  20/20 alive at 400; final realm in 20/20 by ~163; money 3.6e6
  Random    13/20 alive; final realm by ~160
  Findings  WARN progression_ceiling (Greedy, Balanced, Random): the end-game
            (True Immortal 9) is reached in most lives by age ~165, leaving
            200+ years with nothing left to progress.
            WARN early_death (Focused): spamming Physical Training costs more
            health than regeneration restores.
            WARN title_never_unlocked: prodigy (Int 25 by 16), social_butterfly
            (5 friends at 70 affection).

MODERN_LIFE
  All policies die of old age at 96-115 (Idle 80); money 2.4e5-3.9e5.
  Findings  WARN event_never_fired: proposal (weight 0.25).
            WARN title_never_unlocked: prodigy, social_butterfly.
  Note      Idle ends richer than Greedy and Balanced: an early event's first
            choice hands Idle a Street Vendor job kept for life, while active
            policies pay tuition and study first. Education does not pay off
            financially within a modern life. Design decision, not a bug.

ACADEMY (experimental)
  Idle 80 / Balanced 80 / Random 80: full lifespans.
  Greedy dies ~36, Focused ~23, all of wounds: Quirk Drills and Sparring cost
  health and Rest is the only recovery.
  Findings  WARN early_death (Greedy, Focused). Event coverage complete.

DETECTOR CALIBRATION (fixed while building, each has a spec case)
  - Lives cut off by MaxYears were counted as early deaths.
  - early_death warns only when at least EarlyDeathShare of lives die before
    EarlyDeathRatio of their own lifespan; fewer is INFO.
  - Compounding money needs two consecutive growth windows from a real base
    (MoneyGrowthBase); childhood money -> first job -> promotion fooled it.

LIMITS
  Bots are heuristics, not players: a finding says where to look, not what to
  change. One pack per server (packs are read at module load). Bots do not
  reincarnate; persistence between lives stays covered by SimulationSpec.
================================================================================
]]

return {}
