# 🌀 Brainrot Checkpoint Obby — S-TIER Edition Official Manual

Welcome to the **Brainrot Checkpoint Obby S-TIER Edition** codebase! This is a production-ready, monetization-integrated, retention-optimized multiplayer obby designed for maximum dopamine delivery and zero exploit tolerance on Roblox.

This document serves as the technical reference, operational manual, and onboarding guide for developers, designers, QA testers, and administrators.

---

## 🗺️ System Architecture

This system enforces a strict **"Authoritative Server / Dumb Client"** topology. The server owns 100% of game state; the client owns 100% of visual effects.

```text
                   ┌──────────────────────────────────────────────┐
                   │            SHARED MODULES                      │
                   │  [Config.luau] ── Game balance & prices        │
                   │  [Types.luau] ── Type definitions                │
                   │  [LevelData.luau] ── Fallback positions          │
                   └──────────────────────┬───────────────────────┘
                                          │
                   ┌──────────────────────┴───────────────────────┐
                   │            SERVER (Authoritative)            │
                   │  [GameServer.server.luau]                    │
                   │    ├── Session State & Timers                │
                   │    ├── Combo System (up to 3.0x)             │
                   │    ├── Daily Rewards with Streaks            │
                   │    ├── Monetization (Gamepasses/Products)   │
                   │    ├── Distance-Over-Time Anti-Cheat         │
                   │    ├── Per-Type Touch Debouncing             │
                   │    └── [DataManager.luau]                    │
                   │          ├── Atomic conflict resolution      │
                   │          ├── forceOverwrite for purchases    │
                   │          └── Exponential Backoff Retries     │
                   │  [Signal.luau] ── Zero-allocation events      │
                   │  [GenerateLevelData.luau] ── Studio utility    │
                   └──────────────────────┬───────────────────────┘
                                          │
                    Network Events        │ (Minimal payload data)
                    (RemoteEvents)        │
                                          ▼
                   ┌──────────────────────────────────────────────┐
                   │             CLIENT (Visuals Only)            │
                   │  [ObbyHUD.client.luau]                       │
                   │    ├── Local Timer, Combo Counter           │
                   │    ├── Daily Reward Popup                   │
                   │    ├── Glassmorphism HUD                     │
                   │    └── Notification Queue                   │
                   │  [ObbyClient.client.luau]                    │
                   │    ├── Burst Particle VFX (Autocleanup)      │
                   │    ├── Layered Audio / Pitch Shifts         │
                   │    └── Ring Explosions                      │
                   │  [ObbyEffects.client.luau]                   │
                   │    ├── Bloom, Vignette, Screen Flash        │
                   │    ├── Character Trails (rainbow, fire...)  │
                   │    ├── Chromatic Aberration at speed        │
                   │    └── Dynamic FOV                          │
                   └──────────────────────────────────────────────┘
```

### Key Architectural Contracts

1. **Zero Economy Trust**: All coin counts, best run times, combo multipliers, and checkpoint orders are stored and processed strictly on the Server.
2. **Minimal Remote Payloads**: `RemoteEvents` only carry structural signals (`"CheckpointHit"`, `"RunFinished"`, `"CoinCollected"`). The client reconstructs all display states locally.
3. **Conflict-Free Saves**: `DataManager` uses `UpdateAsync` with atomic merge. For purchases, `forceOverwrite = true` bypasses the max() merge to prevent coin deductions from being overwritten.
4. **Combo Authoritativeness**: Combo multipliers are computed server-side using `COMBO_WINDOW_SECONDS = 8.0`. The client merely displays the result.
5. **Daily Reward Auto-Show**: The server automatically checks daily reward eligibility on player login and fires the popup if unclaimed.

---

## 💾 Persistent Data Schema (v2)

Player progress is stored across three separate DataStore namespaces for conflict isolation:

### Core Stats (Atomic Merge via UpdateAsync)
Namespace: `ObbyPlayerData_v2`

```luau
export type PlayerData = {
    bestRunTimeSeconds: number, -- Lower is better (Default: 999999)
    totalRuns: number,          -- Total successful run finishes
    totalCoins: number,         -- Cumulative coins collected
}
```

### Player Settings (SetAsync, no merge needed)
Namespace: `ObbyPlayerSettings_v1`

```luau
export type PlayerSettings = {
    sfxEnabled: boolean,
    musicEnabled: boolean,
    trailEnabled: boolean,
    trailColor: { r: number, g: number, b: number },
    ownedTrails: { string },    -- e.g. {"rainbow", "fire"}
    ownedAuras: { string },     -- e.g. {"glow", "pulse"}
    equippedTrail: string?,      -- Currently equipped trail ID
    equippedAura: string?,       -- Currently equipped aura ID
}
```

### Daily Rewards (SetAsync)
Namespace: `ObbyPlayerSettings_v1` (shared store, separate key)

```luau
export type DailyRewardState = {
    lastClaimDate: string, -- "YYYY-MM-DD"
    streak: number,        -- 0 to 7 (max)
}
```

---

## 🎮 Feature Summary (S-TIER Edition)

### Combo System
- **Window**: `COMBO_WINDOW_SECONDS = 8.0`
- **Tiers**:
  - 3 checkpoints → 1.5x multiplier (`"ON FIRE!"`)
  - 5 checkpoints → 2.0x multiplier (`"UNSTOPPABLE!"`)
  - 8 checkpoints → 3.0x multiplier (`"GODLIKE!"`)
- Combo affects all coin earnings for the run. Resets on timeout or run reset.

### Daily Rewards
- **Base**: 50 coins
- **Streak Bonus**: +10 per streak day (max 7 days)
- **Premium Bonus**: +50 extra coins
- **Auto-Show**: Popup appears automatically on login if not yet claimed today
- Streak resets if you miss a day

### Monetization
- **Gamepasses** (one-time purchase, permanent):
  - 2x Coins — doubles all coin earnings
  - VIP — +50% coins, golden name tag, rainbow trail, VIP badge
- **Developer Products** (consumable):
  - Coin Pack (100), (500), (2,000)
- **Roblox Premium**: +20% coin bonus on all earnings, +50 on daily rewards

### Cosmetics
- **Trails**: rainbow (animated), fire, ice, neon, gold — purchasable with coins
- **Auras**: glow, pulse, sparkle — purchasable with coins
- Trails are equipped via `BuyTrail` server action and rendered client-side

### Leaderboards
- Global OrderedDataStore (`ObbyLeaderboard_v1`)
- Updates only on new personal best times
- Stores times in hundredths of a second

---

## 🛠️ Operational Setup Manual

### 1. Synchronizing the Codebase (Rojo Setup)

This project is structured for synchronization via [Rojo](https://rojo.space/).

1. **Install Rojo**:
   ```bash
   npm install -g rojo
   ```

2. **Start the Sync Server**:
   ```bash
   rojo serve
   ```

3. **Connect Studio**:
   * Open an empty **Baseplate** file in Roblox Studio.
   * Open the Rojo Plugin panel in Studio and click **Connect**.
   * The structural folders under `src/` will automatically sync.

### 2. Designing the Physical Course

The scripts bind to physical assets in the workspace using `CollectionService` tags. You do **not** need to insert any scripts into the parts themselves.

#### Option A: Tag Parts in Studio (Recommended)

**Spawn Point**
1. Insert a standard `SpawnLocation` into the workspace.
2. The server caches this spawn location on startup.

**Checkpoints**
1. Create a physical part for each checkpoint.
2. Add the Tag **`Checkpoint`** using the *Tag Editor*.
3. Add an **Attribute** named `Order` (type: `Integer`, values: 1, 2, 3...).

**Coins**
1. Place small parts along the course.
2. Add the Tag **`Coin`**.

**Finish Line**
1. Create a final part at the end.
2. Add the Tag **`FinishLine`**.

#### Option B: LevelData Fallback (For glTF/Imported Levels)

If your level geometry comes from a glTF export (which strips all Roblox-specific tags and attributes), you can define fallback positions in `src/ReplicatedStorage/LevelData.luau`:

```luau
LevelData.USE_FALLBACK = true
LevelData.CHECKPOINTS = {
    { position = Vector3.new(-304.979, 9.192, 57.847), order = 1 },
    { position = Vector3.new(-363.451, 10.968, 73.157), order = 2 },
    -- ... etc
}
LevelData.COINS = {
    Vector3.new(-350, 12, 80),
    -- ... etc
}
LevelData.FINISH_LINE = Vector3.new(-400, 15, 150)
LevelData.SPAWN_POSITION = Vector3.new(-304.979, 9.192, 57.847)
```

When the server starts, if **zero** tagged parts are found in CollectionService AND `USE_FALLBACK = true`, it spawns invisible detection parts at these positions. These parts are transparent, anchored, and have the correct CollectionService tags — the existing touch handlers connect automatically.

#### Option C: GenerateLevelData Utility (Studio Script)

If you have a properly tagged Studio place and want to auto-generate the LevelData module:

1. Add `GenerateLevelData.luau` to `ServerScriptService` in Studio.
2. Run the game in Studio.
3. Copy the printed output into `src/ReplicatedStorage/LevelData.luau`.

This script scans all tagged parts and generates the exact Lua code needed for the fallback.

---

### 3. Enabling API Services

1. In Roblox Studio: **Home → Game Settings → Security**
2. Toggle **Enable Studio Access to API Services** → **ON**
3. Save.

### 4. Enabling Monetization

1. **Home → Game Settings → Monetization**
2. Toggle **Enable Studio Access to MarketplaceService** → **ON**
3. Save.

> **⚠️ CRITICAL**: Before publishing, replace all `id = 0` values in `Config.luau` with real Roblox asset IDs from the Creator Dashboard.

---

## 🛡️ Anti-Cheat & Hardening Specifications

### 1. Distance-Over-Time (DoT) Velocity Validation

When a player touches a checkpoint, the server calculates:
$$\text{Speed} = \frac{\text{Distance (studs)}}{\text{Elapsed Time (seconds)}}$$
If $\text{Speed} > 150 \text{ studs/sec}$, the interaction is blocked. If the time between touches is ≤ 0.01s and distance > 2 studs, it's also blocked (teleport hack catch).

### 2. Per-Type Touch Debouncing

Each touch type (checkpoint, coin, finish line) has **independent** debounce tables. Touching a coin does NOT debounce a checkpoint, and vice versa. This prevents cross-type debounce exploitation.

### 3. Coin Distance Validation

The server requires the player's `HumanoidRootPart` to exist and be within `COIN_COLLECT_RADIUS` (8 studs) of the coin. If the HRP is missing (common cheat), collection is rejected.

### 4. Atomic Merge + forceOverwrite

- **Normal saves** (run finish): `UpdateAsync` with `math.min(bestTime)` / `math.max(runs, coins)` — strictly incremental.
- **Purchase saves** (trail/aura/dev product): Use `forceOverwrite = true` to bypass the max() merge. This prevents a concurrent save with a higher coin count from undoing a deduction.

### 5. Receipt Deduplication

Developer product purchases use a timestamp-based dedup table (`processedReceipts`) with 1-hour TTL and periodic cleanup. Even if Roblox retries the `ProcessReceipt` callback after a server restart, the purchase is only granted once.

### 6. Unknown Action Logging

Any unrecognized client action sent to `PlayerAction.OnServerEvent` is logged with the player's name and action string, enabling security monitoring.

---

## 🧪 Testing & Quality Assurance

### Local Playtesting (1 Player)

1. Press **F5** in Studio.
2. Check output:
   ```text
   [GameServer] Found X checkpoints, Y coins, Z finish lines via CollectionService
   [GameServer] Brainrot Checkpoint Obby S-TIER initialized!
   ```
3. Run through the course. Verify checkpoints fire in order.
4. Collect coins and verify particle bursts + sounds.
5. Finish the run and verify BestTime updates.

### Testing the LevelData Fallback

1. Ensure no parts in workspace have `Checkpoint`, `Coin`, or `FinishLine` tags.
2. Set `LevelData.USE_FALLBACK = true` and fill in positions.
3. Press F5. Verify:
   ```text
   [GameServer] No tagged parts found — using LevelData fallback positions
   [GameServer] Spawned N fallback detection parts from LevelData
   ```

### Testing Daily Rewards

1. Start playtest. Wait 1 second after spawn.
2. The Daily Reward popup should **auto-appear** if you haven't claimed today.
3. Click CLAIM. Coins should add to your total.
4. Stop and restart playtest. The popup should say "Come back tomorrow!"

### Testing Combo System

1. Place 3+ checkpoints close together (spaced for quick traversal).
2. Run through them rapidly (< 8 seconds apart).
3. Verify combo text appears: `COMBO x3! ON FIRE!` (gold), then `x5! UNSTOPPABLE!` (orange), then `x8! GODLIKE!` (red).
4. Wait 8+ seconds between checkpoints. Combo should reset to 1.

### Multiplayer Network Testing

1. **Test → Clients and Servers → 2 Players → Start**
2. Run the course on Client 1.
3. Verify Client 2 sees particle bursts independently.
4. Verify each player's coins, combos, and times are fully independent.

---

## ❓ Troubleshooting & FAQs

### "Missed Checkpoints!" at finish line
**Solution**: Ensure checkpoints are tagged `Checkpoint` with `Order` attributes starting at 1 and incrementing by 1 without gaps. Check the server console for discovered checkpoint count.

### "No tagged parts found — using LevelData fallback"
**Expected**: This appears when using the LevelData fallback system. If you see this unexpectedly, check that your tagged parts are correctly named and in the workspace.

### Best time flashes gold but didn't save
**Solution**: Enable Studio Access to API Services (Game Settings → Security). Without this, DataStore is unavailable and all data is session-only.

### Trail purchase worked but coins came back after restart
**Solution**: This was a bug in the atomic merge (max() overwrote deductions). It is now fixed with `forceOverwrite = true`. If you see this, ensure you're on the latest commit.

### Players fall through map on respawn
**Solution**: The teleport yields until `HumanoidRootPart` loads (5s timeout). Ensure your spawn pad and checkpoints are anchored and elevated.

### "Unknown action from PlayerName: ..." in output
**Solution**: This is the security log catching unexpected client actions. Review the action string. If it's from your own code, the action name may have a typo. If it's from an exploiter, it's being blocked and logged.

---

## 📜 Codebase File Manifest

* **[`src/ServerScriptService/GameServer.server.luau`](src/ServerScriptService/GameServer.server.luau)**: Core game loop, touch handlers, combo system, daily rewards, monetization, anti-cheat, leaderboard updates.
* **[`src/ServerScriptService/DataManager.luau`](src/ServerScriptService/DataManager.luau)**: DataStore wrapper with atomic merge, forceOverwrite, NaN guards, exponential backoff retries.
* **[`src/ServerScriptService/Signal.luau`](src/ServerScriptService/Signal.luau)**: Zero-allocation custom event system with connection pooling.
* **[`src/ServerScriptService/GenerateLevelData.luau`](src/ServerScriptService/GenerateLevelData.luau)**: Studio utility script to auto-generate LevelData from tagged parts.
* **[`src/ReplicatedStorage/Config.luau`](src/ReplicatedStorage/Config.luau)**: Central game balance — prices, multipliers, combo tiers, daily rewards, placeholder IDs.
* **[`src/ReplicatedStorage/Types.luau`](src/ReplicatedStorage/Types.luau)**: Shared type definitions for server and client.
* **[`src/ReplicatedStorage/LevelData.luau`](src/ReplicatedStorage/LevelData.luau)**: Fallback positions for checkpoints, coins, finish line when tags are absent.
* **[`src/StarterGui/ObbyHUD.client.luau`](src/StarterGui/ObbyHUD.client.luau)**: Glassmorphism HUD with timer, combo, progress bar, daily rewards, notifications, shop UI.
* **[`src/StarterPlayerScripts/ObbyClient.client.luau`](src/StarterPlayerScripts/ObbyClient.client.luau)**: Particle bursts, ring explosions, camera shake, layered audio with pitch shifts.
* **[`src/StarterPlayerScripts/ObbyEffects.client.luau`](src/StarterPlayerScripts/ObbyEffects.client.luau)**: Post-processing (bloom, color correction), screen flash, character trails, chromatic aberration, vignette.
* **[`promo.html`](promo.html)**: Standalone immersive promotional landing page with Three.js, GSAP, Web Audio.
* **[`test_signal.luau`](test_signal.luau)**: 4 automated tests for the Signal utility (zero allocations, yielding, concurrent disconnect, tail reconnect).
* **[`test_datamanager.luau`](test_datamanager.luau)**: 9 automated tests for DataManager (default load, save/load, schema merge, retry success/failure, atomic merge, NaN recovery, settings persistence, daily reward persistence).

---

*Built for speed. Hardened for production. Optimized for retention.* 🏆
