# Brain Tricks — adding levels without republishing the app

The app reads extra levels from the Firebase Realtime Database node **`brainPuzzles`**.
Add/edit levels there and every user gets them on next launch — **no Play Store update**,
as long as a level only uses art props / emoji / mechanics already in the app (listed below).

- A level whose `id` matches a built-in level **overrides** it.
- A new `id` is **added**.
- The built-in 210 levels stay as an offline fallback.

## Where to put them
Firebase Console → Realtime Database → create node `brainPuzzles`. Under it, each child is one
level object (key can be anything — the level number is read from the `id` field). Easiest: import
this JSON onto the `brainPuzzles` node:

```json
{
  "300": {
    "id": 300,
    "type": "dragTo",
    "tier": 7,
    "background": "roomBg",
    "question": "Plug in the lamp.",
    "hint": "Connect the plug.",
    "solution": "Plug -> socket",
    "answer": { "plug": "socket" },
    "nodes": [
      { "id": "socket", "art": "socket", "x": 0.25, "y": 0.4, "size": 0.26, "isTarget": true },
      { "id": "bulb",   "art": "bulb",   "x": 0.7,  "y": 0.4, "size": 0.3 },
      { "id": "plug",   "art": "plug",   "x": 0.45, "y": 0.84, "size": 0.24, "draggable": true }
    ]
  },
  "301": {
    "id": 301,
    "type": "tapObject",
    "tier": 7,
    "question": "Tap the cat.",
    "hint": "Pointy ears.",
    "solution": "The cat",
    "answer": "cat",
    "highlightId": "cat",
    "nodes": [
      { "id": "dog", "art": "dog", "x": 0.3, "y": 0.5, "size": 0.26 },
      { "id": "cat", "art": "cat", "x": 0.7, "y": 0.5, "size": 0.26 }
    ]
  }
}
```

## Level fields
| field | required | notes |
|---|---|---|
| `id` | yes | unique number (use 300+ for your new ones to avoid clashing with built-ins 1–210) |
| `type` | yes | one of: `tapObject`, `tapMulti`, `choice`, `dragTo`, `sequence` |
| `question` | yes | the prompt text |
| `nodes` | yes | list of objects in the scene (see below) |
| `answer` | yes | depends on type (see below) |
| `hint` | yes | shown when player buys a hint |
| `solution` | yes | shown when player skips |
| `tier` | no | difficulty band 1–7 (cosmetic ordering) |
| `background` | no | `roomBg`, `skyBg`, `tableBg`, `snowBg` (default = plain) |
| `highlightId` | no | node id to glow when a hint is bought |

## `answer` by type
- `tapObject` / `choice` → a string node id: `"answer": "cat"`
- `tapMulti` → list of node ids: `"answer": ["a","b","c"]`
- `sequence` → list of node ids **in tap order**: `"answer": ["s1","s2","s3"]`
- `dragTo` → map of {draggableId: targetId}; multiple pairs = multi-step:
  `"answer": { "key": "lock", "plug": "socket" }`

## Node fields
| field | notes |
|---|---|
| `id` | unique within the level; referenced by `answer` |
| `x`, `y` | position 0..1 (0=left/top, 1=right/bottom). default 0.5 |
| `size` | 0..1 fraction of the scene. default 0.16 (use 0.2–0.4 for hero objects) |
| `art` | a drawn prop name (see list). Preferred for the graphic look |
| `emoji` | any emoji string (use if no art prop fits, e.g. `"🍌"`) |
| `label` | text on a `choice` card |
| `color` | optional tint as an ARGB int, e.g. blue = `4282339765` |
| `draggable` | `true` for the piece the player drags (dragTo) |
| `isTarget` | `true` for the drop target (dragTo) |
| `cover` | `true` = an object that disappears when tapped, revealing hidden ones |
| `reveals` | list of node ids to un-hide when this node is tapped/dragged |
| `hidden` | `true` = invisible until revealed (used with `cover`/`reveals`) |

### Reveal (find hidden) example
```json
{ "id":"box","art":"box","x":0.5,"y":0.5,"size":0.42,"cover":true,"reveals":["gift"] },
{ "id":"gift","art":"gift","x":0.5,"y":0.5,"size":0.3,"hidden":true }
```
Type `tapObject`, `"answer":"gift"` → player taps the box to reveal the gift, then taps the gift.

## Available `art` props (already in the app)
kettle, coffeemaker, plug, socket, screwdriver, hammer, scissors, fireplace, logs, fire, match,
window, windowBroken, curtain, sun, cloud, snow, icecream, person, personCold, baby, cat, dog,
fish, bone, carrot, key, lock, candle, glass, bucket, door, bed, bulb, bulbOn, star, heart, ball,
apple, tree, car, balloon, gift, box, rug, button, switchOff, switchOn, cup, cheese, moon, cabinet.

➡️ For anything **not** in this list you can still use an **emoji** (works fully from Firebase).
A brand-new drawn prop or a new game mechanic is the only thing that needs an app update.
