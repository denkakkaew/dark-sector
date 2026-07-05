# Dark Sector — Storyboard & Presentation Deck

**Project:** Dark Sector — an educational space-defense arcade game
**Engine:** Godot 4.6 (GL Compatibility renderer, Jolt 3D physics)
**Target:** single 16:9 landscape touchscreen kiosk on Windows
**Audience:** kids ~8–12 (and everyone who walks past the kiosk)
**Prepared:** 2026-07-04

> **How to read this document.** After the pitch and the story campaign, each
> numbered section is one screen the player sees, in the order they see it.
> Every screen shows: a wireframe of the layout, what is on it, how the player
> interacts, and what happens next. Educational design notes, a HUD legend, and
> art direction follow at the end. Screens are drawn at the 16:9 aspect ratio
> the kiosk runs at.

---

## The 30-second pitch

> *The aliens have a plan: scout Earth's defenses, build a base on the Moon,
> mine Mars for fuel — then invade. You are the turret gunner who breaks that
> plan, one step at a time. Fight through four real places in our solar system
> — the ISS, the Moon, Mars, and Earth orbit — and learn true space facts as
> you go. Answer the mission quiz to recharge your energy, save the planet,
> and put your name at the top of the board.*

**Core loop:** briefing (learn a fact) → aim → fire → destroy aliens → protect
the energy bar → clear the scene → quiz (use the fact, win energy back) →
next scene → win and rank.

**Why it's educational:** every scene is a real destination in the solar
system. The story delivers a true space fact before each battle, and the
between-scene quiz rewards remembering it — learning is wired into the game's
energy system, not bolted on.

---

## The story campaign — 4 scenes, one alien plan

The campaign follows the aliens' invasion plan; the player breaks the chain at
every link:

```
  SCENE 1            SCENE 2            SCENE 3            SCENE 4
 ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
 │   ISS    │      │  MOON    │      │  MARS    │      │  EARTH   │
 │  First   │ ───► │ Forward  │ ───► │  Mining  │ ───► │  Orbit   │
 │ Contact  │      │   Base   │      │   Raid   │      │Last Stand│
 └──────────┘      └──────────┘      └──────────┘      └──────────┘
  scouts probe      they stage on     they steal fuel    the armada
  our defenses      the far side      for the fleet      arrives
```

| # | Scene | Story beat | Sample "DID YOU KNOW?" facts | Difficulty |
|---|-------|-----------|------------------------------|------------|
| 1 | **ISS — First Contact** | Alien scouts ambush the International Space Station. You man its defense turret with Earth glowing below. | The ISS flies ~400 km up at ~28,000 km/h — astronauts see **16 sunrises a day!** | Tutorial pace: slow ships, mostly straight-in attacks |
| 2 | **The Moon — Forward Base** | The aliens are building a staging base on the far side of the Moon. Destroy their landers before the base goes online. | The Moon is **384,400 km** away; its gravity is **1/6 of Earth's**; the far side never faces us | Faster ships, side-strafing attackers join in |
| 3 | **Mars — The Mining Raid** | Alien drones are strip-mining Mars for fuel minerals to power the invasion fleet. Stop the ore carriers escaping Valles Marineris. | Mars is red because of **iron rust**; it has the solar system's tallest volcano, **Olympus Mons**; a Mars day is 24.6 h | Weaving flight paths; slow armored ore carriers worth big points |
| 4 | **Earth Orbit — The Last Stand** | The refueled armada arrives at Earth. Everything is on the line. Win here and… **"Yay!! We protected Earth!"** | Earth's **atmosphere and magnetic field** shield us from space radiation every day | Everything at once: all flight modes, fastest waves |

Each scene = one level. Difficulty rises scene by scene; the energy bar, score,
and timer carry through the whole campaign.

---

## Screen flow at a glance

```
        ┌─────────────┐
        │ 1. TITLE /  │
        │   SPLASH    │
        └──────┬──────┘
               │ tap "Start"
               ▼
        ┌─────────────┐
        │ 2. SIGN-IN  │  enter name
        └──────┬──────┘
               │ tap "Play"
               ▼
        ┌─────────────┐
        │ 3. MISSION  │  story + DID YOU KNOW? fact
        │  BRIEFING   │  (per scene)
        └──────┬──────┘
               │ auto after countdown
               ▼
        ┌─────────────┐   alien destroyed ──► score up
        │ 4. GAMEPLAY │   alien gets through ──► energy down
        │   (HUD)     │
        └──┬───────┬──┘
   scene   │       │  energy = 0
  cleared  │       │
           ▼       ▼
   ┌───────────┐  ┌────────────┐
   │ 5. SCENE  │  │ 8. GAME    │
   │  CLEARED  │  │    OVER    │
   └─────┬─────┘  └─────┬──────┘
         ▼              │
   ┌───────────┐        │
   │ 6. QUIZ   │  correct answer = +energy / +score
   └─────┬─────┘        │
         │ scenes 1→2→3→4 remain ──► back to (3) next scene
         │ scene 4 done            │
         ▼                         ▼
   ┌───────────┐            ┌────────────┐
   │ 7. VICTORY│            │ 9. RESULTS │
   │ "Yay!! We │ ─────────► │ + RANKING  │
   │ protected │            │ (leader-   │
   │  Earth!"  │            │  board)    │
   └───────────┘            └─────┬──────┘
                                  │ Play again / Sign out
                                  └──────► back to (2) or (1)
```

---

## 1. Title / Splash screen

```
┌──────────────────────────────────────────────────────────────┐
│                                                                │
│         · . ˚      *       ·        .    ✦        ·   *         │
│    ✦        ·      .    ·        *         .          ·        │
│                                                                │
│                     ██████  █████  █████ █  █                   │
│                     █    █  █   █  █   █ █ █                    │
│                     █    █  █████  █████ ██                     │
│                     █    █  █   █  █  █  █ █                    │
│                     ██████  █   █  █   █ █  █                   │
│                        D A R K   S E C T O R                   │
│                                                                │
│           ~ defend the solar system. learn its secrets. ~     │
│                                                                │
│                     ┌────────────────────┐                     │
│                     │      ▶  START       │                    │
│                     └────────────────────┘                     │
│                                                                │
│   Earth ◗ (glowing blue, lower-left)        v1.0   🏆 Ranking  │
└──────────────────────────────────────────────────────────────┘
```

**On screen**
- Game logo "DARK SECTOR" over a slow-drifting starfield, with Earth glowing at
  one edge and the dark sector beyond.
- Tagline signalling the double promise: arcade action + real space knowledge.
- One large, touch-friendly **START** button.
- Secondary **Ranking** shortcut (jump straight to the leaderboard) and a
  version tag in the corner.
- Idle "attract mode": the four scene backdrops (ISS, Moon, Mars, Earth) slowly
  cross-fade behind the logo, previewing the campaign.

**Interaction:** Tap **START** → Sign-In. Tap **Ranking** → Results/leaderboard
(view-only).

**Purpose in the pitch:** sets tone and theme; establishes the kiosk "attract"
screen that idles between players and advertises the four destinations.

---

## 2. Sign-In screen

```
┌──────────────────────────────────────────────────────────────┐
│                                                                │
│                     WHO'S DEFENDING EARTH?                     │
│                                                                │
│                  Enter your name, cadet:                       │
│                                                                │
│              ┌──────────────────────────────┐                 │
│              │  ARIA_                        │  ◄ text field   │
│              └──────────────────────────────┘                 │
│                                                                │
│                     ┌──────────────────┐                       │
│                     │     ✔  PLAY       │                      │
│                     └──────────────────┘                       │
│                                                                │
│   ┌───────────────────────────────────────────────────────┐  │
│   │  [ Q ][ W ][ E ][ R ][ T ][ Y ][ U ][ I ][ O ][ P ]   │  │
│   │   [ A ][ S ][ D ][ F ][ G ][ H ][ J ][ K ][ L ]        │  │
│   │     [ Z ][ X ][ C ][ V ][ B ][ N ][ M ][ ⌫ ]           │  │
│   └───────────────────────────────────────────────────────┘  │
│                                                       ‹ Back   │
└──────────────────────────────────────────────────────────────┘
```

**On screen**
- Prompt and a single **name field** (touch keyboard on the kiosk; hardware
  keyboard in dev).
- Large **PLAY** button, disabled until a name is entered.
- **Back** to title.

**Interaction:** Type a name → tap **PLAY**. The name is stored in game state and
carried through to the leaderboard at the end of the run.

**Purpose in the pitch:** this is the first of the three "outlives-a-level"
subsystems — **sign-in** — so scores can be attributed to a player.

---

## 3. Mission Briefing (per scene) — story + space fact

Shown before every scene. This is where the educational layer starts: one story
beat, one true space fact, then straight into action.

```
┌──────────────────────────────────────────────────────────────┐
│  MISSION 3 of 4                                    ⚡ ▐█████░▌ │
│                                                                │
│              ▓▓▓  M A R S — THE MINING RAID  ▓▓▓              │
│         (red planet backdrop with alien mining drones)        │
│                                                                │
│   » Alien drones are stealing minerals from Mars to fuel      │
│     their invasion fleet. Stop the ore carriers, Aria! «      │
│                                                                │
│   ┌────────────────────────────────────────────────────┐     │
│   │ 💡 DID YOU KNOW?                                     │     │
│   │ Mars looks red because its soil is full of iron      │     │
│   │ rust! It also has the tallest volcano in the solar   │     │
│   │ system — Olympus Mons. (remember this for the quiz!) │     │
│   └────────────────────────────────────────────────────┘     │
│                                                                │
│                          ▁▂▃  3  ▃▂▁                           │
│                        (countdown 3·2·1)                       │
└──────────────────────────────────────────────────────────────┘
```

**On screen**
- Mission number (`1 of 4` … `4 of 4`) and the scene's name over its backdrop.
- One-sentence **story beat** addressed to the signed-in player.
- A **"DID YOU KNOW?" fact card** — one true, kid-friendly space fact, flagged
  as quiz material so kids actually read it.
- A short **3·2·1 countdown**, then gameplay starts automatically.

**Briefing text per scene**

| Scene | Story line | Fact card |
|---|---|---|
| 1 · ISS | "Alien scouts are attacking the International Space Station — man the turret!" | The ISS orbits ~400 km above Earth at ~28,000 km/h. Astronauts on board see 16 sunrises every day! |
| 2 · Moon | "The aliens are building a secret base on the far side of the Moon. Stop the landers!" | The Moon is 384,400 km from Earth, and its gravity is only 1/6 of ours. We always see the same side! |
| 3 · Mars | "Alien drones are stealing minerals from Mars to fuel their fleet. Stop the ore carriers!" | Mars is red because of iron rust, and it has the tallest volcano in the solar system: Olympus Mons. |
| 4 · Earth | "This is it — the alien armada has reached Earth. Hold the line, defender!" | Earth's atmosphere and magnetic field protect us from space radiation every single day. |

**Interaction:** None required — auto-advances when the countdown ends.

**Purpose in the pitch:** the educational hook. Story gives context, the fact
card teaches, and the quiz flag gives kids a reason to remember — all in under
ten seconds.

---

## 4. Gameplay — the core screen (HUD)

This is the screen the game lives in. Everything else frames it. The layout is
identical in all four scenes; the backdrop, enemies, and what you're protecting
change per scene.

```
┌──────────────────────────────────────────────────────────────┐
│ ⚡ ENERGY ▐████████████░░░░░▌  SCENE 3·MARS  ⏱ 0:42  SCORE 1250│ ◄ HUD top bar
│                                                                │
│            ◣◥ alien        ◤◢ alien                            │
│          (far, small)     (weaving in)                         │
│                    ▣▣ ore carrier                              │
│                  (slow, armored)                               │
│                                                                │
│                          ✛  ◄ reticle (aim point)             │
│                                                                │
│              │ │  ◄ laser bolts travelling forward             │
│              │ │                                               │
│                                                                │
│        ▂▂▂▂▂▂▂  scene backdrop / horizon glow  ▂▂▂▂▂▂▂        │
│                 ╔═══════╗                                      │
│                 ║ TURRET║  ◄ slides left/right    ┌─────────┐ │
│    ◄━━━ rail ━━━╨───┬───╨━━━ rail ━━━►            │  FIRE   │ │
│                  ▼ barrel                          └─────────┘ │
└──────────────────────────────────────────────────────────────┘
```

**On screen (HUD elements)**
- **Energy bar** (top-left): what you're protecting. Drains each time an alien
  gets through. At zero → Game Over.
- **Scene indicator** (`SCENE 3·MARS`): which of the four missions is active.
- **Timer** (`⏱`): the per-scene timer — the second persistent subsystem.
- **Score** (top-right): rises with each alien destroyed.
- **Reticle / aim marker** (`✛`): shows where the turret is pointing; follows the
  player's touch/mouse. Aim-assist gently snaps onto a nearby alien.
- **Turret** (bottom-centre): slides left/right along a rail; barrel pivots to aim.
- **FIRE button** (bottom-right): large touch target. Spacebar also fires (dev).
- **Alien ships** flying in varied patterns — **direct**, **strafe**, **weave**,
  and **swoop** — introduced scene by scene.

**How each scene looks and plays**

| Scene | Backdrop | Enemy mix | "Gets through" means |
|---|---|---|---|
| 1 · ISS | Blue Earth filling the lower view, ISS solar panels at the edges | Slow scouts, mostly DIRECT | Scout reaches the station |
| 2 · Moon | Grey cratered horizon, Earth small in the black sky | Faster scouts + STRAFE landers | Lander touches down at the base site |
| 3 · Mars | Red dust plains, pink sky, mining rigs on the horizon | WEAVE drones + slow armored ore carriers (bonus points) | Ore carrier escapes with fuel |
| 4 · Earth | Dark space, Earth behind you, red alert glow | All modes incl. SWOOP, fastest cadence | Invader breaks through to Earth |

**Interaction**
- **Aim:** drag / move the reticle to point the turret.
- **Fire:** tap **FIRE** (or spacebar) — lasers travel forward; cooldown limits
  fire rate.
- **Move:** turret tracks left/right so the player can cover the whole field.

**What can happen from here**
- Laser hits an alien → **Screen 4a** (hit) → score up.
- Alien gets through → **Screen 4b** (leak) → energy down.
- Scene wave fully cleared → **Screen 5** (Scene Cleared) → **Screen 6** (Quiz).
- Energy hits zero → **Screen 8** (Game Over).

**Purpose in the pitch:** this is the whole game in one frame — show it running,
then peel back each HUD element to the three required subsystems (timer here;
sign-in and ranking bookend it). One gameplay scene is already playable today.

---

### 4a. Hit / destruction moment (beat, not a separate screen)

```
              ◤◢ alien
                 ╲
                  ✸  ◄ burst of particles + flash
                 ╱          "+100"  floats up
              │ │  laser
```

- On a hit the alien flashes, bursts into a **particle explosion**, and vanishes;
  a floating **+points** confirms the score. Immediate, punchy feedback — the
  reason the loop feels good.

### 4b. Alien gets through (beat)

```
 ⚡ ENERGY ▐██████░░░░░░░░░░░▌   ◄ bar drops + flashes red
        ▂▂▂▂▂ scene horizon ▂▂▂▂▂
            ◥◤  ◄ alien crosses the line, screen edge pulses red
```

- A leaked alien drains the **energy bar**, which flashes red, and the screen
  edge pulses to warn the player. Repeated leaks end the run.

---

## 5. Scene cleared / tally

```
┌──────────────────────────────────────────────────────────────┐
│                                                                │
│                  ✦   MARS IS SAFE — RAID STOPPED!   ✦          │
│                                                                │
│                    SCENE 3  ►  COMPLETE                        │
│                                                                │
│              Score so far ............ 6 400                   │
│              Energy remaining ........ ▐██████░░░▌             │
│              Time ................... 1:42                     │
│                                                                │
│                  One more question, cadet . . .                │
│                        ▁▂▃  quiz  ▃▂▁                          │
└──────────────────────────────────────────────────────────────┘
```

**On screen:** a story-flavored "scene saved" headline (per scene: *"The ISS is
safe!"*, *"Moon base destroyed!"*, *"Mars raid stopped!"*), a quick tally
(score, energy, time), and a lead-in to the quiz.

**Interaction:** Auto-advances to the **Quiz (Screen 6)**.

**Purpose in the pitch:** shows the campaign escalation and that progress
(score, energy) carries between scenes.

---

## 6. Quiz — remember the fact, win energy back

The educational payoff. One multiple-choice question drawn from the fact card
this scene's briefing showed. Correct → real in-game reward. Wrong → no
penalty, the right answer is shown cheerfully. Kids can't lose here — only
learn.

```
┌──────────────────────────────────────────────────────────────┐
│                     🧠  MISSION QUIZ  🧠                       │
│                                                                │
│              Why does Mars look red?                           │
│                                                                │
│        ┌──────────────────────────────────────────┐          │
│        │   A · Its soil is full of iron rust       │          │
│        └──────────────────────────────────────────┘          │
│        ┌──────────────────────────────────────────┐          │
│        │   B · It is very hot                      │          │
│        └──────────────────────────────────────────┘          │
│        ┌──────────────────────────────────────────┐          │
│        │   C · Aliens painted it                   │          │
│        └──────────────────────────────────────────┘          │
│                                                                │
│    ✔ CORRECT!  +⚡ energy recharged  +500 bonus score          │
│         ⚡ ENERGY ▐██████████░░░░░▌ ──► ▐█████████████░░▌      │
└──────────────────────────────────────────────────────────────┘
```

**On screen**
- One question, **three big touch buttons** (one silly wrong answer keeps the
  tone playful).
- Feedback banner: correct → **+energy refill and +bonus score**, with the
  energy bar visibly refilling; wrong → "Good try! The answer is A — Mars is
  covered in iron rust!" and no penalty.

**Sample question per scene**

| Scene | Question | Answers (✔ correct) |
|---|---|---|
| 1 · ISS | How many sunrises do ISS astronauts see each day? | 1 · **16 ✔** · 100 |
| 2 · Moon | How strong is the Moon's gravity compared to Earth's? | Same · **1/6 ✔** · Double |
| 3 · Mars | Why does Mars look red? | **Iron rust ✔** · Very hot · Aliens painted it |
| 4 · Earth | What shields Earth from space radiation? | **Atmosphere + magnetic field ✔** · Clouds · Satellites |

**Interaction:** Tap an answer → feedback (≈2 s) → next Mission Briefing
(Screen 3), or **Victory (Screen 7)** after scene 4's quiz.

**Purpose in the pitch:** closes the learning loop — the fact taught before the
battle is rewarded after it, and the reward (energy) directly helps the player
survive the next, harder scene. Learning has gameplay value.

---

## 7. Victory — "Yay!! We protected Earth!"

```
┌──────────────────────────────────────────────────────────────┐
│        ✦   *    ˚   ·     ✦        ·      *      ˚    ·        │
│                                                                │
│                  🎉  YAY!! WE PROTECTED EARTH!  🎉             │
│                                                                │
│                   ◗ Earth — safe & glowing ◖                  │
│                                                                │
│      You defended the ISS, freed the Moon, saved Mars —       │
│                and stopped the invasion. 🌍                    │
│                                                                │
│               Defender ............ Aria                       │
│               Final score ......... 9 850                     │
│               Time ................ 2:54                       │
│               Quiz answers ........ 4 / 4  🧠                  │
│                                                                │
│                 ┌──────────────────────────┐                  │
│                 │   VIEW RANKING  ▶         │                 │
│                 └──────────────────────────┘                  │
└──────────────────────────────────────────────────────────────┘
```

**On screen:** the win message **"Yay!! We protected Earth!"** (the spec's exact
win text), a one-line recap of the four-scene journey, and the run summary —
including how many quiz questions were answered correctly.

**Interaction:** Continue to **Results / Ranking (Screen 9)**, where the score is
saved and placed on the board.

**Purpose in the pitch:** the payoff — clearing all 4 scenes wins, and the quiz
tally shows a parent/teacher at the kiosk that something was learned.

---

## 8. Game Over (lose path)

```
┌──────────────────────────────────────────────────────────────┐
│                                                                │
│                    ⚠   STATION OFFLINE   ⚠                     │
│                                                                │
│                        GAME  OVER                              │
│                                                                │
│              The energy bar reached zero —                    │
│              too many ships slipped through.                  │
│                                                                │
│               Defender ............ Aria                       │
│               Reached .............. Scene 3 · Mars            │
│               Final score ......... 4 100                     │
│                                                                │
│           ┌──────────────┐    ┌──────────────┐                │
│           │  TRY AGAIN ↻  │    │  RANKING  🏆  │               │
│           └──────────────┘    └──────────────┘                │
└──────────────────────────────────────────────────────────────┘
```

**On screen:** the loss reason (energy hit zero), how far into the campaign the
player got (scene name, not just a number), and their score.

**Interaction:** **Try Again** → new run (Mission Briefing, Scene 1). **Ranking**
→ the score is still recorded and shown on the board.

**Purpose in the pitch:** the fail state that gives the energy bar its stakes —
and the quiz its value, since correct answers refill exactly this bar.

---

## 9. Results & Ranking / Leaderboard

```
┌──────────────────────────────────────────────────────────────┐
│                        🏆  TOP DEFENDERS  🏆                   │
│                                                                │
│   #   NAME            SCORE      SCENE     QUIZ    TIME        │
│  ───────────────────────────────────────────────────────      │
│   1   NOVA            12 300      4 ✓      4/4     2:38        │
│   2   ARIA   ◄ you    9 850       4 ✓      3/4     2:54   ★   │
│   3   REX             8 420       4 ✓      2/4     3:03        │
│   4   KAI             6 100       3        2/3     —           │
│   5   MILO            4 100       2        1/2     —           │
│   ...                                                          │
│                                                                │
│   Your run: 9 850  —  new personal best!                      │
│                                                                │
│      ┌──────────────┐   ┌──────────────┐   ┌──────────────┐  │
│      │ PLAY AGAIN ↻ │   │  SIGN OUT ⎋  │   │  TITLE  ⌂    │  │
│      └──────────────┘   └──────────────┘   └──────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

**On screen**
- Ranked **leaderboard** (top-N by score), with the current player's row
  highlighted (`◄ you ★`).
- Columns show how far each defender got (scene 1–4) and their **quiz score** —
  knowledge is on the scoreboard too.
- The run's result line ("new personal best!").
- Navigation: **Play Again**, **Sign Out** (back to Sign-In for a new player),
  **Title**.

**Interaction:** persists locally (a `user://` file) so the board survives
restarts — the third required subsystem, **ranking**.

**Purpose in the pitch:** closes the loop and drives replay on a shared kiosk —
"beat the person before you," in both shooting and knowing.

---

## Educational design — how the learning works

**Learning goals (ages 8–12).** After a full run, a player has met four true
ideas about our solar system:

1. The **ISS** is a real place where people live in orbit, moving incredibly
   fast (16 sunrises a day).
2. The **Moon** is far away, low-gravity, and always shows us the same face.
3. **Mars** is a rusty desert world with record-setting geography.
4. **Earth** is special — its atmosphere and magnetic field actively protect us.

**Design principles**

- **One fact per scene.** No walls of text — a single wow-fact, delivered in
  the briefing, used in the quiz. Repetition without lecturing.
- **Learning has gameplay value.** The quiz refills the energy bar, which is
  the survival resource for the next, harder scene. Paying attention literally
  keeps you alive.
- **No punishment for wrong answers.** A wrong quiz answer shows the correct
  one with a friendly tone and costs nothing. The kiosk stays fun for a
  7-year-old and a grandparent alike.
- **Facts are real and checkable.** Everything on the fact cards is true,
  age-appropriate astronomy — the game can be defended to teachers and parents.
- **Extensible.** Each scene's facts/questions live in a small data table, so
  a content pass can add question pools or a second difficulty tier without
  touching gameplay code.

---

## Recurring HUD legend

| Element | Where | Meaning |
|---|---|---|
| ⚡ **Energy bar** | top-left | Survival resource; drains when aliens get through; refilled by correct quiz answers; 0 = game over |
| **SCENE n·NAME** | top-centre | Current mission (1·ISS → 4·EARTH) |
| ⏱ **Timer** | top-centre | Per-scene timer |
| **SCORE** | top-right | Points; +score per alien destroyed, +bonus per correct quiz answer |
| ✛ **Reticle** | follows aim | Where the turret is pointing (with aim-assist) |
| **Turret** | bottom-centre | Slides on a rail; barrel pivots to aim |
| **FIRE** | bottom-right | Fires lasers (also spacebar) |
| ◣◥ **Aliens** | mid-field | Fly in via direct / strafe / weave / swoop paths, introduced scene by scene |
| ▣▣ **Ore carrier** | mid-field (Mars) | Slow, armored, high-value target |

---

## Art & mood direction

- **Feel:** fast, readable, arcade. Big touch targets, punchy hit feedback,
  clear at a glance from a standing kiosk player. Friendly, not scary — the
  aliens are cartoonish invaders, not horror.
- **Camera:** fixed 3D view above/behind the turret looking out into space;
  aliens grow as they approach so threat reads instantly.
- **Per-scene palettes** — each destination has its own instantly-readable look:

| Scene | Palette & backdrop |
|---|---|
| 1 · ISS | Deep space black + the big blue glow of Earth below; white/gold ISS solar panels framing the view |
| 2 · Moon | Silver-grey craters, harsh white sunlight, tiny blue Earth in a black sky |
| 3 · Mars | Rust reds and ochres, dusty pink sky, dark mining rigs on the horizon |
| 4 · Earth | Darkest scene: black space, red alert glow, Earth bright and vulnerable behind the player |

- **Constants across scenes:** hot cyan/green laser bolts, warm orange
  explosions, red for energy warnings — the danger language never changes.

---

## Build status (transparency for the demo)

| Screen / system | Status |
|---|---|
| 4. Gameplay core — aliens, turret, aim, fire, hit effects | **Playable now** (all four flight modes, aim-assist, spacebar + FIRE button) |
| Web/kiosk build | **Exported** (`docs/` — runs in a browser) |
| 4 scene variants (backdrops + per-scene enemy tables) | Designed — the playable core is scene-agnostic; scenes swap backdrop and spawn data |
| 1. Title, 2. Sign-in | Designed — next to build |
| 3. Mission briefing + fact cards, 6. Quiz | Designed — content lives in a per-scene data table |
| Energy bar, timer, score HUD | Designed — hooks into the planned `GameState` autoload |
| 5/7/8 Scene cleared, victory, game over | Designed |
| 9. Ranking / leaderboard | Designed — local `user://` persistence |

> The core shooting loop (Screen 4) is already running and can be demoed live.
> The surrounding screens in this storyboard are the roadmap to the full
> experience, built on the phased implementation plan in
> `planning/IMPLEMENTATION_PLAN.md`.
