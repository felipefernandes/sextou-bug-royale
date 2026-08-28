# 📄 SOFTWARE DESIGN DOCUMENT (SDD)

**Project Name:** Sextou: Bug Royale

**Architecture Style:** Client-Server / State Synchronized via WebSockets

**Target Platform:** Web Browsers (HTML5 / WebGL)

**Target Stack:** Node.js, TypeScript, Phaser 3, Colyseus.js, Vite

## 1. System Architecture Overview

The system uses an authoritative server model via **Colyseus.js** to manage room states, physics collisions, game loops, and match logic. The client uses **Phaser 3** as a rendering engine to handle input (mouse targeting/movement), display isometric pixel art, and render interpolated game state updates from the server.

```
┌─────────────────────────────────────────────────────────┐
│                      BROWSER CLIENT                     │
│  ┌──────────────────┐               ┌────────────────┐  │
│  │   Phaser 3 UI    │◄──────────────┤ Colyseus Client│  │
│  │  Render Engine   │ Interpolation │ State Listener │  │
│  └────────┬─────────┘               └───────▲────────┘  │
│           │ Local Input                     │           │
└───────────┼─────────────────────────────────┼───────────┘
            │ Mouse Delta / Action Events     │ WebSocket
            ▼                                 │ Sync (20 FPS)
┌─────────────────────────────────────────────┴───────────┐
│                     SERVER (Node.js)                    │
│  ┌───────────────────────────────────────────────────┐  │
│  │             Colyseus Game Room                    │  │
│  │  - Game State Management (Players, Bullets, Zone) │  │
│  │  - Arcade Physics / Tilemap Collision Checks      │  │
│  │  - Procedural Maze Generation Algorithm          │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## 2. Tech Stack & Dependencies

### Client

- **Framework:** Phaser 3 (`phaser`)
    
- **Language:** TypeScript
    
- **Build Tool:** Vite
    
- **Multiplayer Client:** `colyseus.js`
    

### Server

- **Runtime:** Node.js (v18+)
    
- **Server Framework:** Express + Colyseus (`@colyseus/core`, `@colyseus/ws-transport`)
    
- **Language:** TypeScript
    
- **Physics Engine:** Custom Server-side lightweight bounding box checks via `@colyseus/schema`.
    

## 3. Directory & File Structure

```
/sextou-bug-royale
├── /client
│   ├── index.html
│   ├── package.json
│   ├── tsconfig.json
│   ├── vite.config.ts
│   └── /src
│       ├── main.ts
│       ├── /assets
│       │   ├── /sprites (chairs, office_tiles, weapons, fx)
│       │   └── /audio
│       ├── /network
│       │   └── NetworkManager.ts
│       ├── /scenes
│       │   ├── BootScene.ts
│       │   ├── LobbyScene.ts
│       │   └── GameScene.ts
│       └── /entities
│           ├── ChairPlayer.ts
│           ├── WeaponItem.ts
│           └── ZoneBorder.ts
├── /server
│   ├── package.json
│   ├── tsconfig.json
│   └── /src
│       ├── index.ts
│       ├── /rooms
│       │   └── OfficeBattleRoom.ts
│       ├── /rooms/schema
│       │   ├── OfficeState.ts
│       │   ├── PlayerSchema.ts
│       │   ├── BulletSchema.ts
│       │   └── ItemSchema.ts
│       └── /utils
│           └── MazeGenerator.ts
└── README.md
```

## 4. Data Models & Schemas (Colyseus `@colyseus/schema`)

### 4.1 PlayerSchema (`PlayerSchema.ts`)

```
import { Schema, type } from "@colyseus/schema";

export class PlayerSchema extends Schema {
  @type("string") id: string = "";
  @type("string") teamId: string = "";
  @type("string") role: "DRIVER" | "GUNNER" = "DRIVER";
  @type("string") skin: "DEV" | "QA" | "DESIGNER" | "ANALYSIS" | "PM" = "DEV";
  
  // Position & Motion (Updated by Driver)
  @type("number") x: number = 0;
  @type("number") y: number = 0;
  @type("number") angle: number = 0; // Chair heading direction (radians)
  @type("number") speed: number = 0;
  
  // Gunner State (Updated by Gunner)
  @type("number") aimAngle: number = 0; // Aiming angle (radians)
  
  // Combat State
  @type("number") postItHP: number = 3; // 3 Post-its before elimination
  @type("boolean") isAlive: boolean = true;
  @type("string") currentWeapon: string = "STAPLER";
  @type("number") weaponAmmo: number = -1; // -1 = Infinite (Default)
  @type("string") activePowerUp: string = "NONE";
}
```

### 4.2 BulletSchema (`BulletSchema.ts`)

```
import { Schema, type } from "@colyseus/schema";

export class BulletSchema extends Schema {
  @type("string") id: string = "";
  @type("string") ownerTeamId: string = "";
  @type("string") type: "STAPLER" | "COFFEE" | "ELASTIC" | "DISKETTE" = "STAPLER";
  @type("number") x: number = 0;
  @type("number") y: number = 0;
  @type("number") vx: number = 0;
  @type("number") vy: number = 0;
  @type("number") damage: number = 1;
}
```

### 4.3 ItemSchema (`ItemSchema.ts`)

```
import { Schema, type } from "@colyseus/schema";

export class ItemSchema extends Schema {
  @type("string") id: string = "";
  @type("number") x: number = 0;
  @type("number") y: number = 0;
  @type("string") itemType: "COFFEE_SNIPER" | "ELASTIC_GUN" | "DISKETTE_BOMB" | "CTRL_Z" | "POG_BOOST" | "NOT_FOUND_404" = "COFFEE_SNIPER";
  @type("boolean") isSpawned: boolean = true;
}
```

### 4.4 OfficeState (`OfficeState.ts`)

```
import { Schema, type, MapSchema, ArraySchema } from "@colyseus/schema";
import { PlayerSchema } from "./PlayerSchema";
import { BulletSchema } from "./BulletSchema";
import { ItemSchema } from "./ItemSchema";

export class OfficeState extends Schema {
  @type({ map: PlayerSchema }) players = new MapSchema<PlayerSchema>();
  @type([ BulletSchema ]) bullets = new ArraySchema<BulletSchema>();
  @type([ ItemSchema ]) items = new ArraySchema<ItemSchema>();
  
  // Procedural Maze Grid (0: Floor, 1: Wall)
  @type([ "number" ]) mazeGrid = new ArraySchema<number>();
  @type("number") mazeWidth: number = 20;
  @type("number") mazeHeight: number = 20;

  // Server Reboot Zone State
  @type("number") zoneRadius: number = 1500;
  @type("number") zoneCenterX: number = 1000;
  @type("number") zoneCenterY: number = 1000;
  
  // Match State
  @type("string") matchPhase: "LOBBY" | "PLAYING" | "ENDED" = "LOBBY";
  @type("string") winningTeamId: string = "";
}
```

## 5. Network Protocol & WebSocket Messages

### Client to Server Messages

|Event Name|Payload Structure|Sent By|Description|
|---|---|---|---|
|`input:driver`|`{ targetX: number, targetY: number, drift: boolean }`|Driver|Cursor target position in world coordinates to move the chair vehicle.|
|`input:gunner`|`{ aimAngle: number, isFiring: boolean }`|Gunner|Weapon crosshair angle in radians and trigger state.|
|`action:useItem`|`{}`|Gunner|Triggers currently equipped power-up (e.g., CTRL+Z, POG Boost).|
|`lobby:selectSkin`|`{ skin: string }`|Any|Sets player skin during lobby phase.|

### Server to Client Events (Broadcast / Schema Sync)

|Event Name|Schema Impact|Description|
|---|---|---|
|`state_change`|Full Schema Patch|Sent every tick (20 FPS). Syncs player coordinates, active bullets, and zone shrinkage.|
|`event:playerDied`|`{ teamId: string, killedBy: string }`|Triggers destruction particle effects and audio on client side.|
|`event:rebootZoneStart`|`{ durationMs: number }`|Triggers UI alerts: "REBOOT INCOMING! MOVING TO SAFE AREA".|
|`event:perspectiveBug`|Internal Client Rendering|Clients render opponents using Bug Sprites, while keeping teammates rendered as human avatars.|

## 6. Procedural Maze Generator Algorithm (`MazeGenerator.ts`)

The server constructs an isometric grid using Depth-First Search (DFS) / Recursive Backtracker to ensure all rooms are reachable.

```
export function generateOfficeMaze(width: number, height: number): number[] {
  // 1 = Wall (Partition), 0 = Floor (Cubicle/Hallway)
  const grid: number[][] = Array(height).fill(0).map(() => Array(width).fill(1));

  function carve(x: number, y: number) {
    const directions = [
      [0, -2], [0, 2], [-2, 0], [2, 0]
    ].sort(() => Math.random() - 0.5);

    grid[y][x] = 0;

    for (const [dx, dy] of directions) {
      const nx = x + dx;
      const ny = y + dy;

      if (nx > 0 && nx < width - 1 && ny > 0 && ny < height - 1 && grid[ny][nx] === 1) {
        grid[y + dy / 2][x + dx / 2] = 0;
        carve(nx, ny);
      }
    }
  }

  carve(1, 1);
  return grid.flat();
}
```

## 7. Client-Side Rendering Strategy & Perspective Trick

### 7.1 Isometric Projection Calculations

To convert grid/world coordinates to isometric tile rendering:

```
export function worldToIso(x: number, y: number): { isoX: number, isoY: number } {
  const isoX = x - y;
  const isoY = (x + y) / 2;
  return { isoX, isoY };
}
```

### 7.2 The "Bugs Perspective" Asset Mapping Rule

The client filters player visual rendering based on local session identity:

```
function getPlayerSpriteKey(localPlayerTeamId: string, targetPlayer: PlayerSchema): string {
  if (targetPlayer.teamId === localPlayerTeamId) {
    // Teammate: Render Human Avatar
    return `avatar_${targetPlayer.skin.toLowerCase()}`;
  } else {
    // Adversary: Render as Glitch / Bug
    return `bug_glitch_variant_${(targetPlayer.teamId.length % 3) + 1}`;
  }
}
```

## 8. Development Implementation Phases

### Phase 1: Core Boilerplate & Networking

1. Initialize Vite project with Phaser 3 + Colyseus.js client.
    
2. Initialize Node.js TypeScript server with Colyseus Room (`OfficeBattleRoom`).
    
3. Implement WebSocket connection lifecycle (Join, State Sync, Leave).
    

### Phase 2: Movement & Dual-Control Engine

1. Implement mouse-following physics steering for the **Driver**.
    
2. Implement 360° cursor aim targeting for the **Gunner**.
    
3. Synchronize duo state across network with client prediction.
    

### Phase 3: Isometric Tilemap & Procedural Generation

1. Implement `MazeGenerator.ts` on server.
    
2. Send grid data on room initialization.
    
3. Render isometric tilemap in Phaser 3 client (`GameScene.ts`).
    

### Phase 4: Combat Mechanics & Items

1. Add weapon shooting mechanics (Stapler, Coffee Sniper, Elastic).
    
2. Add pickup boxes ("Deploy Boxes") spawning on server logic.
    
3. Implement Post-it life system (3 hits before elimination).
    

### Phase 5: Zone Shrinkage & Perspective Feature

1. Implement Server Reboot safe zone shrinking over time.
    
2. Implement visual filter where enemy teams render as Bug Glitch sprites.
    
3. Polish UI with corporate satire theme ("Sextou!", "404 Error", "Meeting Freeze").
