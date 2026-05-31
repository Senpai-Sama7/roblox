# Brainrot Checkpoint Obby — Complete Instruction Manual (S-TIER Edition)

> **Made for:** Players, testers, designers, and anyone who needs to run this game.
> **Reading time:** ~10 minutes. **Follow the steps in order.**

---

## Table of Contents

1. [What Is This Game?](#1-what-is-this-game)
2. [How to Set Up the Project](#2-how-to-set-up-the-project)
3. [How to Play the Game](#3-how-to-play-the-game)
4. [Every System Explained (Simple)](#4-every-system-explained-simple)
5. [How to Test Everything](#5-how-to-test-everything)
6. [How to Make Changes](#6-how-to-make-changes)
7. [Troubleshooting](#7-troubleshooting)
8. [Project Map (Who Talks to Who)](#8-project-map-who-talks-to-who)

---

## 1. What Is This Game?

This is a **speedrun obstacle course (obby)** on Roblox. You run from start to finish as fast as you can, touching checkpoints along the way. There are coins to collect, combos to build, daily rewards to claim, trails and auras to buy, and leaderboards to climb.

### What Makes It Special?

- **Combo System** — Hit checkpoints fast in a row and get a score multiplier (up to **3.0x**!)
- **Daily Rewards** — Come back every day for free coins (up to **120** on day 7)
- **Monetization** — Gamepasses (2x Coins, VIP), coin packs, and Roblox Premium bonuses
- **Cosmetics** — Buy rainbow trails, fire trails, glow auras, and more with in-game coins
- **Anti-Cheat** — The server checks your speed, distance, and debounces every touch type independently
- **S-TIER Visuals** — Bloom, vignette, screen flashes, particle bursts, dynamic camera FOV, glassmorphism HUD, chromatic aberration
- **LevelData Fallback** — Works even with imported/glTF geometry that has no tags

---

## 2. How to Set Up the Project

### What You Need

- **Windows computer** (this guide is written for Windows)
- **Roblox Studio** — [download here](https://www.roblox.com/create)
- **Node.js** — [download here](https://nodejs.org/) (click the LTS version)
- The game code (you already have it in the `roblox` folder)

### Step 1: Install Rojo

Rojo is a tool that turns your code files into a Roblox place file. Open **PowerShell** (press Windows key, type "PowerShell", open it) and run:

```bash
npm install -g rojo
```

> **What `npm install -g rojo` does:** It downloads and installs the Rojo tool so you can use it from any folder. The `-g` means "global" — you only need to do this once.

Verify it worked:

```bash
rojo --version
```

You should see something like `Rojo 7.6.1`. If not, close and re-open PowerShell and try again.

### Step 2: Build the Game File

Navigate to the project folder in PowerShell:

```bash
cd "C:\Users\Donov\roblox"
```

Build the game:

```bash
rojo build -o obby.rbxl
```

> **What `rojo build -o obby.rbxl` does:** It reads `default.project.json` (the "blueprint"), finds all your `.luau` code files, and packs them into a single `obby.rbxl` file that Roblox Studio can open.

### Step 3: Open in Roblox Studio

1. **Open Roblox Studio** (double-click the icon)
2. Click **Open from File** (not "Open from Roblox" — that's different)
3. Navigate to `C:\Users\Donov\roblox\obby.rbxl` and open it
4. If Studio asks "Do you want to upgrade this place?" — click **Yes**

### Step 4: Enable Studio to Access the Internet (API Services)

This is **required** for the game to save data, check gamepasses, and run the leaderboard. Without this, the game will crash on startup.

1. Go to **Home** tab → **Game Settings** (gear icon)
2. Click **Security**
3. Turn **ON** "Enable Studio Access to API Services"
4. Click **Save**

### Step 5: Enable Monetization (Gamepasses, Developer Products)

1. Go to **Home** tab → **Game Settings**
2. Click **Monetization**
3. Turn **ON** "Enable Studio Access to MarketplaceService"
4. Click **Save**

### Step 6: Playtest

Press **F5** on your keyboard. The game should start. You should see:

- A glass-like HUD panel at the top of the screen
- A timer that says `0:00.00`
- "Checkpoints: 0 / 0"
- A **RESET** button (red)

If you see red error messages in the **Output** window at the bottom of Studio, look them up in the [Troubleshooting](#7-troubleshooting) section.

---

## 3. How to Play the Game

### The Goal

Start at the spawn point, hit every checkpoint in order (1, 2, 3...), then touch the **Finish Line**. Your time is recorded. If you touch the finish line before hitting all checkpoints, you get a red message saying "Missed checkpoints!" — you must hit them all.

### Controls

| Action | How |
|--------|-----|
| Move | **WASD** keys |
| Jump | **Spacebar** |
| Reset run | Click the **RESET** button (red, top-right of the HUD) |
| Claim daily reward | Click **CLAIM** on the daily reward popup (auto-appears on login if unclaimed) |

### The HUD (What All the Numbers Mean)

```
┌─────────────────────────────────────────────────────┐
│ SPEEDRUN                                [VIP] [2x]  │
│                                                     │
│                    0:00.00                           │ ← Timer
│                                                     │
│          COMBO x5! UNSTOPPABLE!                     │ ← Combo (appears at 2+)
│                                                     │
│ ████████████████████░░░░░░░░░░░░░░░░░              │ ← Progress bar
│                                                     │
│  Best: 0:45.67     💎 23 (x2.0)        Runs: 12    │ ← Stats
│  Checkpoints: 5 / 10                               │ ← Progress text
│                                      [RESET]        │ ← Reset button
└─────────────────────────────────────────────────────┘
```

- **Timer** — Counts up while you run. The server records the real time (your screen is just visual).
- **Combo** — Appears when you hit 2+ checkpoints within 8 seconds of each other. Colors: Gold (3) → Orange (5) → Red (8+).
- **Progress bar** — Fills up as you hit checkpoints.
- **Best** — Your fastest ever run.
- **💎 Coins** — How many coins you've collected this run, with current multiplier.
- **Runs** — Total number of completed runs (ever).
- **Badges [VIP], [2x], [PREMIUM]** — Appear if you own the corresponding gamepass or have Roblox Premium.

### What Happens When You Finish

1. The timer **stops**
2. Coins are **added** to your total (with all multipliers applied)
3. If it's your **best time**, the timer turns **gold** and you get a "NEW BEST!" notification
4. If it's not your best time, you get a green "Finished" notification
5. Your character gets a **teleport back** to spawn for the next run
6. The **leaderboard** updates if you set a new best time

---

## 4. Every System Explained (Simple)

### Checkpoints

- Each checkpoint has a number (the **Order** attribute, like "1", "2", "3")
- You must touch them **in order**. Skipping one doesn't work (the server blocks it)
- They're tagged with `Checkpoint` in the **CollectionService**
- When you touch one, you get a particle burst, a sound, and a notification
- **LevelData Fallback**: If your level has no tagged parts (e.g., imported from glTF), the server can spawn invisible detection parts from `LevelData.luau` instead

### Coins

- Coins float around the obby. Touch them to collect them.
- You can only collect each coin **once per run** (the server remembers which ones you've grabbed)
- The server checks that you're **within 8 studs** of the coin when you touch it. If your HumanoidRootPart is more than 8 studs away, the coin is **rejected** (this stops cheating)
- If you delete your HumanoidRootPart (a cheat method), the coin is also **rejected**

### Combo System

- Hit checkpoints within **8 seconds** of each other to build a combo
- Combo tiers:
  - **3 checkpoints in a row** → 1.5x multiplier ("ON FIRE!")
  - **5 in a row** → 2.0x ("UNSTOPPABLE!")
  - **8 in a row** → 3.0x ("GODLIKE!")
- The combo **resets** if you take too long between checkpoints (more than 8 seconds) or if you reset your run
- Combo affects coin rewards: more combo = more coins per run

### Daily Rewards

- Log in once per day and the popup **auto-appears** after 1 second
- Base reward: **50 coins**
- Streak bonus: **+10 coins per day** (max 7-day streak = +70)
- Premium bonus: **+50 extra coins** if you have Roblox Premium
- If you miss a day, your **streak resets to 0**
- If you already claimed today, the popup says "Come back tomorrow!"
- The streak check uses **Julian day numbers** — it correctly handles month and year boundaries (unlike simple date subtraction)

### Cosmetics (Trails & Auras)

- **Trails**: rainbow, fire, ice, neon, gold — each leaves a colored trail behind your character
- **Auras**: glow, pulse, sparkle — visual effects around your character
- Buy them with coins using the `BuyTrail` and `BuyAura` server actions
- Once bought, they're saved to your settings and persist across sessions
- VIP players automatically get the rainbow trail equipped

### Monetization

| Type | Example | How It Works |
|------|---------|--------------|
| **Gamepass** (buy once, permanent) | 2x Coins, VIP | Server checks `UserOwnsGamePassAsync` on login. Applies permanent multiplier. |
| **Developer Product** (buy repeatedly) | Coin Packs (100/500/2000) | Server gets `ProcessReceipt` callback. Adds coins to your account. The server remembers the `PurchaseId` with a 1-hour timeout so you never get double-spent. |
| **Roblox Premium** | +20% coins | Server checks `player.MembershipType` on login. |

> **Purchase Safety**: When you buy a trail or aura, the server deducts coins and saves with `forceOverwrite = true`. This prevents the atomic merge (which normally uses `max()`) from accidentally restoring your old coin count and undoing the purchase.

### Anti-Cheat (How the Game Catches Cheaters)

1. **Speed check**: Server calculates distance/time between checkpoints. If you move faster than 150 studs/second, you're blocked.
2. **Same-frame check**: If you somehow travel more than 2 studs in a single frame (0.01 seconds), you're blocked. (This catches teleport hacks.)
3. **Coin distance check**: You must be within 8 studs of a coin to collect it. Remote coin collection doesn't work.
4. **HRP check**: If your HumanoidRootPart is missing or deleted (a common cheat), coin collection is blocked entirely.
5. **Per-type debouncing**: Each touch type (checkpoint, coin, finish) has its own debounce timer. Touching a coin does NOT block a checkpoint touch.
6. **All client actions are rate-limited**: You can only fire one action per 0.5 seconds to the server. No spamming.
7. **Receipt deduplication**: The server remembers every Roblox purchase's `PurchaseId` with a timestamp so you can't claim the same coin pack twice, even if Roblox retries the callback.
8. **Unknown action logging**: Any unrecognized action from a client is logged with the player's name for security review.

### Leaderboard

- If you set a new personal best time, the server updates the **OrderedDataStore** `ObbyLeaderboard_v1`
- The leaderboard stores times in **hundredths of a second** (so 45.67 seconds is stored as 4567)
- The leaderboard is **global** (all servers share it)

### Data Save System

The game saves 3 separate things per player:

| What | Saved As | How Often |
|------|----------|-----------|
| **Stats** (best time, runs, coins) | `Player_<userId>` | On run finish, on leaving, on server shutdown |
| **Settings** (SFX, trails, cosmetics owned) | `Settings_<userId>` | On buying a trail, on leaving, on server shutdown |
| **Daily Reward** (last claim date, streak) | `Daily_<userId>` | On claiming a reward, on leaving, on server shutdown |

> **"Atomic Merge" for Stats**: If two different Roblox servers try to save the same player's stats at the same time, the server picks:
> - The **faster** best time (smaller number wins)
> - The **higher** number of runs (max wins)
> - The **higher** coin count (max wins)
>
> This means you never lose progress even if there's a conflict.

> **"forceOverwrite" for Purchases**: When you buy a trail or get a dev product, the server uses `forceOverwrite = true` to bypass the max() merge. This guarantees your coin deduction actually sticks, even if another server has a concurrent save.

> **Data safety**: Every save uses `pcall` (error-protected call) with 3 retries and exponential backoff (1 second → 2 seconds → 4 seconds). If all 3 retries fail, the save is abandoned (data stays in memory and will try again on next save).

---

## 5. How to Test Everything

### Basic Gameplay Test

1. Press **F5** to start playtesting
2. Your character should appear at the spawn point
3. Look at the HUD — you should see the timer start counting
4. If there are no checkpoints or coins yet, you'll see "Checkpoints: 0 / 0". That's normal.

### Testing Without a Built Level (LevelData Fallback)

If you have a glTF-imported level with no tags, the game uses the LevelData fallback system. The fallback positions are **pre-filled** from actual Export.gltf coordinates — no manual entry needed:

1. Open `src/ReplicatedStorage/LevelData.luau`
2. Verify `USE_FALLBACK = true` (already set by default)
3. The file contains 9 checkpoints and 12 coins derived from real glTF node positions (SpawnLocation, OB_BallPlatform_a, Carousel, Ivy_Hanging_a clusters)
4. Rebuild (`rojo build -o obby.rbxl`) and open in Studio
5. Press F5. The server should log: `Spawned 21 fallback detection parts from LevelData`
6. Run through the course — the invisible parts work exactly like tagged parts

To customize positions, edit the Vector3 values in `LevelData.luau` directly, or use the GenerateLevelData utility (see below).

### Testing With Tagged Parts

#### Step 1: Add a Spawn Location

1. Go to the **Home** tab
2. Click **Model** → search for "SpawnLocation"
3. Drag one into the workspace
4. Position it at `0, 5, 0`

#### Step 2: Add Checkpoints

1. Insert a **Part** (Home tab → Part)
2. Size it to about `4, 1, 4`
3. In the **Explorer** panel, select the part
4. In the **Properties** panel, find **Attributes** (at the bottom), click **+**
5. Create an attribute named `Order` with type **number**, value `1`
6. In **Properties**, find **CollectionService** → add tag `Checkpoint`
7. Position it `4` studs away from spawn
8. Repeat for checkpoints 2, 3 etc.

#### Step 3: Add Coins

1. Insert a **Part** (size `1, 1, 1`)
2. Add tag `Coin` (in CollectionService)
3. Position it near a checkpoint

#### Step 4: Add a Finish Line

1. Insert a **Part** (size `6, 1, 6`)
2. Add tag `FinishLine`
3. Position it at the end of your course

#### Step 5: Playtest

Press **F5**. Your character spawns, the timer starts. Run through checkpoints in order, collect coins, hit the finish line.

### Using GenerateLevelData (Auto-Generate Positions)

GenerateLevelData has **dual modes**:

**Mode A — Tagged Parts**: If your Studio place has parts tagged with `Checkpoint`, `Coin`, and `FinishLine`, the script exports their positions exactly.

**Mode B — Auto-Suggest**: If **zero** tagged parts exist, the script analyzes all BaseParts in workspace, clusters them by height tiers, and auto-generates a playable course from bounding-box geometry. This works on any level, even raw glTF imports.

Usage:
1. Copy `src/ServerScriptService/GenerateLevelData.luau` into `ServerScriptService` in Studio
2. Run the game in Studio (or use the Command bar: `require(script).generate()`)
3. Check the **Output** window — you'll see a complete `LevelData.luau` module printed
4. Copy that output and paste it into `src/ReplicatedStorage/LevelData.luau`
5. Rebuild with Rojo

The script also prints a **diff** comparing the generated data against the existing LevelData, so you can see exactly what would change.

### Testing Monetization (Simulate Purchases)

Roblox Studio lets you pretend to buy things without spending real money:

1. In the playtest window, go to the **Test** tab (top menu bar)
2. Click **Simulate Purchase**
3. Choose a gamepass or developer product
4. A dialog appears — click **Purchase**
5. The server's `ProcessReceipt` function fires, and you should see coins added

> **Important**: The gamepass/product IDs in `Config.luau` are all set to `0` and marked with `PUBLISH_BLOCKER` comments. This works in Studio simulation mode (it grants everything for free). When you publish the game, you must replace these with the real Roblox asset IDs from the Creator Dashboard. Search for `PUBLISH_BLOCKER` in Config.luau to find all IDs that need replacing.

### Testing Data Persistence

1. Start a playtest, collect some coins, finish a run
2. **Stop** the playtest (F5 again)
3. Start a new playtest (F5)
4. Check the HUD — your coins and best time should still show

> **What's happening**: When you stop playtest, the `BindToClose` function saves all player data to a mock DataStore (in Studio, it's ephemeral — only persists during the session). In a real published game, DataStore actually persists to the cloud.

### Testing with Multiple Players (Local Server)

1. Go to **Test** tab → **Clients** dropdown
2. Set it to **2 Players** (or more)
3. Click **Start**
4. Multiple Studio windows open — each is a different player
5. You can race yourself! Check that each player's coins, combos, and times are **independent**

### Testing Combo System

1. Place 3+ checkpoints close together (within 8 studs of each other)
2. Run through them quickly (less than 8 seconds between each)
3. After the 3rd checkpoint, look for **"COMBO x3! ON FIRE!"** in gold
4. Keep going: hit 5 checkpoints for **"COMBO x5! UNSTOPPABLE!"** (orange), 8 for **"COMBO x8! GODLIKE!"** (red)
5. Now wait 8+ seconds between checkpoints — the combo resets back to 1

### Testing Daily Rewards

1. Start playtest
2. After 1 second, the server auto-checks your daily reward status
3. If you haven't claimed today, the **Daily Reward** popup slides in from the top
4. Click **CLAIM**
5. The popup disappears, coins are added
6. If you click the button again, the server tells you "Already claimed"
7. The button text changes to **"CLOSE"** — click it to dismiss the popup

> **Note**: In Studio testing, "today" is your computer's current date. If you want to test streak mechanics, you'd need to manipulate the system clock (not recommended).

### Testing Cosmetics (Trails & Auras)

1. Earn some coins by running the course
2. Send a `BuyTrail` action from the client (or test via the server console):
   ```lua
   -- In Studio command bar (server context):
   local player = game.Players:GetPlayers()[1]
   game.ReplicatedStorage.Remotes.PlayerAction:FireServer("BuyTrail", "rainbow")
   ```
3. Your coins should decrease by 500 (rainbow trail cost)
4. Restart playtest — the trail should still be owned and equipped

---

## 6. How to Make Changes

### The Project File Structure

```
roblox/                              ← Root folder (this is where you run commands)
├── default.project.json             ← Blueprint: tells Rojo which files go where
├── test_datamanager.luau            ← 9 automated tests for DataManager
├── test_signal.luau                 ← 4 automated tests for Signal utility
├── obby.rbxl                        ← Built game file (run rojo build to make this)
├── index.html                        ← AAA-grade landing page (playable demo, analytics, 3D map)
└── src/                             ← All your code lives here
    ├── ReplicatedStorage/           ← Files shared by server AND client
    │   ├── Config.luau              ← Game balance — prices, speeds, multipliers
    │   ├── Types.luau               ← Type definitions (used by Luau type checker)
    │   └── LevelData.luau           ← Fallback positions for imported levels
    ├── ServerScriptService/         ← Server-only code (runs on Roblox's servers)
    │   ├── GameServer.server.luau   ← Main server logic (gameplay, monetization, etc.)
    │   ├── DataManager.luau         ← DataStore wrapper (saves/loads player data)
    │   ├── Signal.luau              ← Utility: custom event system
    │   └── GenerateLevelData.luau   ← Studio utility: auto-generate LevelData from tags
    ├── StarterGui/                  ← Client-only code for the HUD
    │   └── ObbyHUD.client.luau      ← Main HUD (timer, combo, daily rewards, shop)
    └── StarterPlayerScripts/        ← Client-only VFX and effects
        ├── ObbyClient.client.luau   ← Sound, particles, camera shake, ring effects
        └── ObbyEffects.client.luau  ← Bloom, vignette, screen flash, trails, chromatic ab.
```

### How to Edit Config (The Easy Way)

Open `src/ReplicatedStorage/Config.luau`. This is where all the **tunable numbers** live. Change these without touching any other code:

| Variable | Default | What It Does |
|----------|---------|--------------|
| `COIN_VALUE_PER_COIN` | `1` | Base coins per coin collected |
| `PREMIUM_COIN_BONUS` | `0.20` | +20% coins for Premium members |
| `COMBO_WINDOW_SECONDS` | `8.0` | How long you have between checkpoints to keep combo alive |
| `DAILY_REWARD_BASE` | `50` | Base coins for daily reward |
| `DAILY_REWARD_STREAK_MULTIPLIER` | `10` | Extra coins per streak day |
| `DAILY_REWARD_MAX_STREAK` | `7` | Max streak days |
| `MAX_SPEED_STUDS_PER_SEC` | `150` | Anti-cheat speed limit |
| `NOTIFICATION_DURATION` | `2.5` | Default notification popup lifetime (seconds) |
| `COMBO_DISPLAY_DURATION` | `1.5` | How long combo label stays visible after update (seconds) |
| `SFX_VOLUME` | `0.5` | Default volume for sound effects |
| `COSMETICS.TRAILS` | — | Array of purchasable trails (id, name, cost, color) |
| `COSMETICS.AURAS` | — | Array of purchasable auras (id, name, cost) |

**Example**: Want daily rewards to give double? Change `DAILY_REWARD_BASE = 50` to `DAILY_REWARD_BASE = 100`.

**Example**: Want combos to last longer? Change `COMBO_WINDOW_SECONDS = 8.0` to `COMBO_WINDOW_SECONDS = 15.0`.

### How to Change the HUD Colors

Open `src/StarterGui/ObbyHUD.client.luau`. Around line 24, there's a color table:

```lua
local C = {
    bg       = Color3.fromRGB(12, 13, 20),      ← Dark background
    accent   = Color3.fromRGB(0, 195, 255),      ← Cyan accent
    gold     = Color3.fromRGB(255, 200, 50),      ← Gold
    green    = Color3.fromRGB(50, 255, 150),      ← Green
    red      = Color3.fromRGB(255, 65, 85),       ← Red
    -- ... etc
}
```

Change any `Color3.fromRGB(R, G, B)` to pick a different color. Use [color picker](https://www.colorhexa.com/) to find RGB values you like.

### How to Add a New Trail

1. Open `src/ReplicatedStorage/Config.luau`
2. Find the `TRAILS` table
3. Add a new entry:
```lua
{ id = "void", name = "Void", cost = 10000, color = Color3.fromRGB(30, 0, 50) },
```
4. Save the file, rebuild, and the trail will appear in the shop

### How to Add a New Aura

1. Open `src/ReplicatedStorage/Config.luau`
2. Find the `AURAS` table
3. Add a new entry:
```lua
{ id = "shadow", name = "Shadow", cost = 5000 },
```
4. The aura is now purchasable via the `BuyAura` server action

### How to Add More Checkpoints or Coins in the Game

1. In Roblox Studio, add a **Part** to the workspace
2. Tag it with `Checkpoint` (or `Coin` or `FinishLine`)
3. For checkpoints, add an **Attribute** called `Order` (type `number`)
4. The server's `CollectionService` listener automatically picks it up — no code changes needed!

### How to Change Gamepass/Product IDs

Before publishing, you must set real Roblox IDs in `Config.luau`. Search for `PUBLISH_BLOCKER` to find all placeholder IDs:

```lua
Config.GAMEPASSES = {
    DOUBLE_COINS = {
        id = 12345678,  -- PUBLISH_BLOCKER: Replace with actual Gamepass ID
        name = "2x Coins",
        ...
    },
}
```

Get the IDs from: [create.roblox.com/dashboard](https://create.roblox.com/dashboard) → Your game → **Monetization** → **Gamepasses** or **Developer Products**.

### How to Rebuild After Changes

Every time you edit a file, you need to rebuild:

```bash
rojo build -o obby.rbxl
```

Then re-open in Studio (or use **Rojo Live Sync** — see tip below).

### 📌 Pro Tip: Use Rojo Live Sync

Instead of rebuilding every time, you can sync changes **live**:

1. Open your code in a code editor (VS Code, etc.)
2. In Roblox Studio, go to **Plugins** tab → **Rojo** → **Connect** (if the Rojo plugin is installed)
3. In PowerShell, run:
```bash
rojo serve
```
4. Now any file you save automatically updates in Studio. No more rebuilding!

### How to Run the Automated Tests

The game comes with test suites for the Signal utility and the DataManager. To run them, you need **Lune** (a Luau runtime):

1. Install Lune: [github.com/lune-org/lune](https://github.com/lune-org/lune)
   - Download the `.exe` for Windows
   - Put it somewhere in your PATH (or just in the project folder)

2. Run tests:
```bash
lune run test_signal.luau
lune run test_datamanager.luau
```

Expected output:
```
✓ E1/E5: Zero allocations per Fire
✓ E2: Yielding handlers survive and don't block
✓ E3: Concurrent disconnects handle gracefully
✓ E4: Tail disconnect + reconnect handled correctly
All Success Criteria Passed.
```

```
✓ T1: Default data load verified
✓ T2: Standard Save & Load verified
... (all 9 tests pass)
All DataManager S-tier test suites completed successfully.
```

---

## 7. Troubleshooting

| Problem | Most Likely Cause | Solution |
|---------|-------------------|----------|
| **Red error: "DataStoreService is not available"** | API Services not enabled | Go to Game Settings → Security → Enable Studio Access to API Services → ON |
| **Red error: "MarketplaceService is not available"** | Monetization not enabled | Go to Game Settings → Monetization → Enable → ON |
| **Red error: "Attempt to index nil with 'WaitForChild'"** | A module or RemoteEvent didn't exist when the script tried to load it | This usually happens if you didn't build properly. Run `rojo build -o obby.rbxl` and re-open. |
| **Checkpoints/coins don't work** | Parts not tagged correctly | Make sure each part has the right tag (`Checkpoint`, `Coin`, or `FinishLine`) in CollectionService. Checkpoints also need an `Order` attribute (number). |
| **"No tagged parts found — using LevelData fallback"** | Normal when using imported/glTF geometry | Expected behavior. Fill in positions in `LevelData.luau` and rebuild. |
| **HUD doesn't appear** | Script error in ObbyHUD | Check the Output window for red messages. Ensure all required RemoteEvents exist (they're created automatically, but a script error could prevent it). |
| **"Not enough coins" when buying a trail** | You need to earn coins first | Run a few laps and collect the floating coins, or simulate a purchase from the Test tab. |
| **Daily reward popup doesn't appear** | You already claimed today (in Studio, this is based on your PC's date) | The popup still appears but says "Already claimed" and offers a CLOSE button instead. |
| **Nothing happens when I touch checkpoints** | The server-side script isn't running | Check if there are any errors in the Output window. Make sure the `GameServer` script exists in `ServerScriptService`. |
| **Build fails with "JSON parse error"** | Missing comma or bracket in `default.project.json` | Open `default.project.json` and look for the error. A missing comma is the most common issue. |
| **Rojo sync isn't working** | Plugin not installed or not connected | Install the Rojo Studio plugin from the Roblox Plugin Marketplace. In Studio, go to Plugins → Rojo → Connect. Then run `rojo serve` in PowerShell. |
| **Camera shake doesn't work** | Script error in ObbyClient | The `restoreShake` function uses `camera.CFrame`, but `camera` was changed to `workspace.CurrentCamera` in the FOV function. Make sure the shake functions also reference a live camera. (They use their own local variable that gets set correctly.) |
| **Data doesn't save between playtests** | Normal in Studio | Studio's DataStore is ephemeral — data only persists during a single session. DataStore persistence only works in published games. |
| **"Unknown action from PlayerName: ..."** | A client sent an unrecognized action | If this is from your own code, check for typos in action strings. If from an exploiter, the action is being blocked and logged — this is correct behavior. |
| **Trail purchase worked but coins came back after restart** | Old bug (fixed) | This was caused by the atomic merge using `max()` which overwrote coin deductions. It is now fixed with `forceOverwrite = true`. Update to the latest commit. |
| **Daily streak reset at month boundary** | Old bug (fixed) | The old `isYesterday` function used simple date subtraction which broke at month/year boundaries. It now uses Julian day numbers. Update to the latest commit. |

### If You See This Error in Output:

```
[DataManager] UpdateAsync failed (attempt 1/3): DataStore request was not available.
  [DataManager] UpdateAsync failed (attempt 2/3): DataStore request was not available.
  [DataManager] UpdateAsync failed (attempt 3/3): DataStore request was not available.
  [DataManager] FAILED to save stats for PlayerName after 3 retries
```

**Cause**: You haven't enabled API Services (see Step 4 of setup). The DataStore can't connect.

**Fix**: Go to Game Settings → Security → **Enable Studio Access to API Services** → ON → Save → Restart playtest.

### If Coin Collection is Blocked:

```
[Anti-Cheat] PlayerName coin blocked — missing HRP
```

**Cause**: The player's character has no `HumanoidRootPart`. This happens naturally for about 0.1 seconds after respawn (before the character fully loads), or it could be a cheat attempt.

**If it happens once and works fine after**: Normal, ignore it.

**If it happens every time**: Check that your character model has a `HumanoidRootPart`. Standard Roblox characters always do, but custom models might not.

---

## 8. Project Map (Who Talks to Who)

```
                    ┌─────────────┐
                    │   PLAYER    │
                    │  (Keyboard) │
                    └──────┬──────┘
                           │
                           ▼
               ┌──────────────────────┐
               │   ObbyHUD.client     │  ← Shows timer, combo, badges, daily reward
               │   (StarterGui)       │     Sends "RequestReset", "ClaimDailyReward",
               │                      │     "BuyTrail", "BuyAura" to server
               └──────────┬───────────┘
                          │ FireClient / OnServerEvent
                          ▼
               ┌──────────────────────┐
               │   GameServer.server  │  ← The BRAIN. Validates everything.
               │   (ServerScriptSvc)  │     Handles checkpoints, coins, finish line.
               │                      │     Anti-cheat, combo, daily rewards, monetization.
               └──────────┬───────────┘
                          │
                     ┌────┴────┐
                     │         │
                     ▼         ▼
           ┌────────────┐  ┌────────────┐
           │ DataManager│  │ Config     │  ← Settings database
           │ (Module)   │  │ (Module)   │     Prices, multipliers, IDs
           └────────────┘  └────────────┘
                     │
                     ▼
           ┌────────────────────┐
           │   Roblox DataStore   │  ← Cloud save: stats, settings, daily
           │   (Cloud)            │
           └────────────────────┘

    ┌──────────────────┬──────────────────┐
    │ ObbyClient.client│ ObbyEffects.client│
    │ (StarterScripts)  │ (StarterScripts)  │
    │                   │                   │
    │ • Sounds          │ • Bloom effect    │
    │ • Particle bursts │ • Vignette        │
    │ • Camera shake    │ • Screen flash    │
    │ • Ring effects    │ • Character trails│
    │ • Dynamic FOV     │ • Chromatic ab.   │
    └──────────────────┴──────────────────┘
```

### The Golden Rule

**The server is the boss. The client is just for looks.**

- The timer you see on your screen? **Client-only visual.** The server computes the real time.
- The combo counter? The server tells you what it is. Your client just displays it.
- Coins? The server checks distance, HRP existence, and duplicate collection. Your client can't just say "I got a coin."
- Purchases? All validated by the server's `ProcessReceipt` handler. Receipts are deduplicated so you can't claim the same purchase twice.
- Daily rewards? The server tracks the date and streak. The client just shows the popup.

This means even if someone hacks their Roblox client, they can't cheat. The server decides everything.

---

## Quick Reference Card

| Task | Command/Action |
|------|---------------|
| **Build the game** | `rojo build -o obby.rbxl` |
| **Start live sync** | `rojo serve` |
| **Open in Studio** | File → Open from File → `obby.rbxl` |
| **Playtest** | Press **F5** |
| **Simulate purchase** | Test tab → Simulate Purchase |
| **Test DataManager** | `lune run test_datamanager.luau` |
| **Test Signal** | `lune run test_signal.luau` |
| **Enable API Services** | Game Settings → Security → Enable Studio Access to API Services |
| **Enable Monetization** | Game Settings → Monetization → Enable |
| **Add a checkpoint** | Part → Attribute: `Order` (number) → Tag: `Checkpoint` |
| **Add a coin** | Part → Tag: `Coin` |
| **Add a finish line** | Part → Tag: `FinishLine` |
| **Change game balance** | Edit `src/ReplicatedStorage/Config.luau` |
| **Change colors** | Edit `src/StarterGui/ObbyHUD.client.luau` (line 24) |
| **Add fallback positions** | Edit `src/ReplicatedStorage/LevelData.luau` |
| **Generate LevelData from Studio** | Run `GenerateLevelData.luau` in Studio, copy output |

---

*If something isn't working, check the **Output** window in Roblox Studio (View → Output). Red messages tell you exactly what went wrong. Look up the message in [Troubleshooting](#7-troubleshooting) above.*

*Happy speedrunning!* 🏃‍♂️💨
