# DisenchantTooltip (WoW Forever)

**Remembers what your disenchanted items turned into, and shows it in their tooltip.**

DisenchantTooltip is a World of Warcraft addon for the Forever client. Every time you disenchant an item, it writes down what came out. Later, when you hover over the same item, its tooltip shows what it turns into:

```
Disenchants to (8x):
  1-3 Strange Dust          88%
  1 Lesser Magic Essence    12%
```

The range is the fewest and the most that came out at once. The % is in how many of the disenchants the material came out; the number in brackets says how many disenchants that is based on.

---

**Project status:** Early version (0.1).

**Transparency:** DisenchantTooltip is written entirely by AI. All of the code and this documentation were produced by an AI coding assistant (Claude); the maintainer is not a programmer and did not write any of it by hand. His part was deciding what the addon should do, testing it in the game and reporting what was wrong. The code is one Lua file, kept readable and commented so that it can be inspected directly.

**License:** [MIT](LICENSE)

---

## What it does

- Notices your own disenchants and records what each item turned into.
- Keeps for each item how many times it was disenchanted and, for each material, how often it came out and how many at once.
- Shows that as a line in the tooltip of the item (by item ID, so every copy of the item shows it).
- Learns only from what you disenchant yourself. An item you never disenchanted shows nothing.

## Install

1. Download this repository.
2. Copy the folder `DisenchantTooltip` into `World of Warcraft/_forever_/Interface/AddOns/`.
3. Start the game, or log out to the character select screen and back in.

The records are stored by the game in `WTF/Account/<account>/SavedVariables/DisenchantTooltip.lua`, shared by all your characters.

## Requirements

- World of Warcraft, Forever client (interface 16001).
- No other addons or libraries.
