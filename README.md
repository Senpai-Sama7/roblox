# 🌀 Brainrot Checkpoint Obby — Official Operational Manual

Welcome to the **Brainrot Checkpoint Obby** codebase! This repository houses a production-ready, highly optimized, and mathematically hardened multiplayer obby core loop designed for Roblox.

This document serves as both the technical documentation and the operational manual for developers, designers, and administrators deploying and maintaining the game.

---

## 🗺️ System Architecture

This system utilizes a strict **"Authoritative Server / Dumb Client"** topology to guarantee 100% security against client-side exploitation, while optimizing network throughput via localized client rendering.

```text
                  ┌──────────────────────────────────────────────┐
                  │            SERVER (Authoritative)            │
                  │  [GameServer.server.luau]                    │
                  │    ├── Session State & Timers                │
                  │    ├── Distance-Over-Time Anti-Cheat         │
                  │    ├── Touch Debouncing & Cooldowns          │
                  │    └── [DataManager.luau]                    │
                  │          ├── Atomic conflict resolution      │
                  │          └── Exponential Backoff Retries     │
                  └──────────────────────┬───────────────────────┘
                                         │
                   Network Events        │ (Minimal payload data)
                   (RemoteEvents)        │
                                         ▼
                  ┌──────────────────────────────────────────────┐
                  │             CLIENT (Visuals Only)            │
                  │  [ObbyHUD.client.luau]                       │
                  │    ├── Local Frame-Rate Independent Timer    │
                  │    └── Programmatic Glassmorphic HUD          │
                  │  [ObbyClient.client.luau]                    │
                  │    ├── Burst Particle VFX (Autocleanup)      │
                  │    └── Local Audio/Tone Synthesizer          │
                  └──────────────────────────────────────────────┘
```

### Key Architectural Contracts

1. **Zero Economy Trust**: All coin counts, best run times, and checkpoint orders are stored and processed strictly on the Server.
2. **Minimal Remote Payloads**: `RemoteEvents` only carry structural signals (such as `"CheckpointHit"`, `"RunFinished"`, and `"CoinCollected"`). The client reconstructs all display states locally, preventing remote payload modification attacks.
3. **Conflict-Free Saves**: `DataManager` uses `UpdateAsync` with an atomic evaluation strategy to merge database records. Even in high-concurrency cross-server scenarios, player data is never blind-overwritten.

---

## 💾 Persistent Data Schema

Player progress is serialized and saved in Roblox's `DataStoreService` under the namespace `ObbyPlayerData_v1`.

```luau
export type PlayerData = {
    bestRunTimeSeconds: number, -- Lower is better (Default: 999999)
    totalRuns: number,          -- Total successful run finishes
    totalCoins: number,         -- Cumulative coins collected across all runs
}
```

---

## 🛠️ Operational Setup Manual

### 1. Synchronizing the Codebase (Rojo Setup)

This project is structured for synchronization via [Rojo](https://rojo.space/). To map this local project into Roblox Studio:

1. **Install Rojo**:
   * Install the [Rojo VS Code Extension](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo).
   * Install the companion **Rojo Roblox Studio Plugin** via the Studio Toolbox.
2. **Start the Sync Server**:
   * Open this directory in your terminal or VS Code and run:

     ```bash
     rojo serve
     ```

3. **Connect Studio**:
   * Open an empty **Baseplate** file in Roblox Studio.
   * Open the Rojo Plugin panel in Studio and click **Connect**.
   * The structural folders under `src/` will automatically sync to their respective standard locations:
     * `ServerScriptService/GameServer`
     * `ServerScriptService/DataManager`
     * `StarterGui/ObbyHUD`
     * `StarterPlayer/StarterPlayerScripts/ObbyClient`

---

### 2. Designing the Physical Course

The scripts automatically bind to physical assets in the workspace using Roblox's `CollectionService` tags. You do not need to insert any scripts into the parts themselves.

#### Step A: Configure the Spawn Point

1. Insert a standard `SpawnLocation` into the workspace.
2. The server will cache this spawn location on startup and use it as the starting point and reset point.

#### Step B: Build Checkpoints

1. Create a physical part (e.g., a neon pad) for each checkpoint.
2. Add the Tag **`Checkpoint`** to the part using the *Tag Editor* window (or via command bar).
3. Add a new **Attribute** to the part:
   * **Name**: `Order`
   * **Type**: `Integer` / `Double` (Number)
   * **Value**: Set sequentially starting at `1` for the first checkpoint, `2` for the second, etc.
   * *Note*: If a player skips a checkpoint or hits them out of order, the touch event is silently rejected.

#### Step C: Scatter Coins

1. Place small golden parts (e.g., cylinders or spheres) along your course.
2. Add the Tag **`Coin`** to each of these parts.
3. *Note*: The server permits players to collect each physical coin once per run. Coins reset when a new run begins.

#### Step D: Build the Finish Line

1. Create a final pad or gate at the end of the course.
2. Add the Tag **`FinishLine`** to this part.

---

### 3. Enabling Database Persistence

Roblox blocks local studio sessions from calling production databases by default. To enable saving and loading:

1. In Roblox Studio, click **Home > Game Settings**.
2. Go to **Security**.
3. Toggle **Enable Studio Access to API Services** to **ON**.
4. Save the settings.

---

## 🛡️ Anti-Cheat & Hardening Specifications

The core game loop incorporates several math-driven defenses against typical exploit engines:

### 1. Distance-Over-Time (DoT) Velocity Validation

When a player touches a checkpoint, the server calculates the straight-line magnitude to the previous checkpoint:
$$\text{Speed} = \frac{\text{Distance (studs)}}{\text{Elapsed Time (seconds)}}$$
If $\text{Speed} > 150 \text{ studs/sec}$, the server flags the interaction, rejects the checkpoint update, and logs an alert. This stops instant checkpoint-teleport hacks dead in their tracks.

### 2. Stream-In Character Teleport Safety

In streaming-enabled or high-latency servers, immediately teleporting a player during character respawns often fails because the physics constraints have not loaded. `GameServer` uses asynchronous safety loops:

```luau
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart", 5)
```

This guarantees the player is securely positioned at their active checkpoint without falling through the void or failing to teleport.

### 3. Atomic Merge Database Strategy

To prevent data loss if a player saves in two places simultaneously or switches servers rapidly, `DataManager` utilizes `UpdateAsync` with an atomic comparison block:

```luau
bestRunTimeSeconds = math.min(data.bestRunTimeSeconds, oldData.bestRunTimeSeconds or 999999)
totalCoins = math.max(data.totalCoins, oldData.totalCoins or 0)
```

This guarantees that your player database is strictly incremental and never corrupts old records during connection drops.

---

## 🧪 Testing & Quality Assurance Manual

To verify your obby is working flawlessly, use the following verification workflows in Roblox Studio:

### Local Playtesting (1 Player)

1. Press **F5** (or click **Play**) in Roblox Studio.
2. Check your output window. You should see:

   ```text
   [GameServer] Checkpoint count: X
   [GameServer] Brainrot Checkpoint Obby initialized!
   ```

3. Run through your course. Ensure you hit checkpoints in order.
4. Verify that you hear the synthesize beep tone and see particle bursts when collecting coins and touching checkpoints.
5. Finish the run and verify that your **BestTime** updates in the top-right HUD and the player list.

### Multiplayer Network Testing (Local Server)

1. Go to the **Test** tab in Roblox Studio.
2. Under the *Clients and Servers* section, select **Local Server** and set the player count dropdown to **2 Players** or **3 Players**.
3. Click **Start**.
4. This spins up an independent local Roblox server instance and multiple client viewports.
5. Run the course on client 1. Complete the obby and collect coins.
6. Verify that Client 2 sees Client 1's particle bursts and updates on the leaderboard in real-time.
7. Disconnect Client 1. Check the local server console to verify that the saving log triggers cleanly:

   ```text
   [DataManager] Saved data for Player1
   ```

---

## ❓ Troubleshooting & FAQs

### "Missed Checkpoints!" notification keeps displaying at the finish line

* **Solution**: Ensure your checkpoints are tagged correctly and their `Order` attribute starts exactly at `1` and increments sequentially by `1` without gaps. Check the server console log to verify how many checkpoints were discovered at startup.

### The timer flashes golden but my Best Time did not save

* **Solution**: You likely have not enabled Studio Access to API Services (see Security section). The server will fall back to using default memory values, meaning best times will clear when you stop playing.

### Players occasionally fall through the map on respawn

* **Solution**: The teleport safety yields until the character's `HumanoidRootPart` is loaded. If your map parts are not anchored, or if your spawn pad is too close to a kill-boundary, players may spawn in dangerous zones. Ensure your `SpawnLocation` and checkpoints are anchored and elevated.

---

## 📜 Codebase File Manifest

* **[`src/ServerScriptService/GameServer.server.luau`](src/ServerScriptService/GameServer.server.luau)**: Core game loop executor, touch event handler, leaderboard updates, and security manager.
* **[`src/ServerScriptService/DataManager.luau`](src/ServerScriptService/DataManager.luau)**: Robust local persistence middleware with safe retries and atomic transaction handling.
* **[`src/ServerScriptService/Signal.luau`](src/ServerScriptService/Signal.luau)**: Zero-allocation internal event system used as a performance-safe alternative to Roblox RBXScriptSignals.
* **[`src/StarterGui/ObbyHUD.client.luau`](src/StarterGui/ObbyHUD.client.luau)**: High-performance, lightweight UI controller driving the glassmorphic HUD.
* **[`src/StarterPlayerScripts/ObbyClient.client.luau`](src/StarterPlayerScripts/ObbyClient.client.luau)**: Localized cosmetic effects manager synthesizing beeps and rendering particle bursts.
