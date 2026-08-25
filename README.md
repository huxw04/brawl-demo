# Brawl Framework Demo

An independent Godot 4 greybox for a 2.5D arena brawler. World collision,
height and walls use Godot 3D; characters may still use 2D Sprite3D animation.
It does not depend on the old reinforcement-learning demo.

当前中文进度、玩法和后续计划见
[`docs/项目进度总结.md`](docs/%E9%A1%B9%E7%9B%AE%E8%BF%9B%E5%BA%A6%E6%80%BB%E7%BB%93.md)。

## Run

Open `project.godot` with Godot 4, or run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/run.ps1
```

Validate all project scripts without opening a window:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/check.ps1
```

The launcher opens two shared-logic scenes:

- **Character Lab**: switch heroes, use the same MOBA controls as combat, trigger
  actions/statuses with buttons, inspect 3D hit/hurt/push volumes, and test walls.
- **Battle Arena**: control the first formal hero against a utility-AI bot.

Battle controls: right-click the ground to pathfind, left-click for a basic
attack or to confirm an aimed skill, `Q/W/E/R` select ability slots (`R` is the
ultimate), `Shift` rolls, and `Space` jumps. `F1` returns to the
launcher, `F3` toggles collision debug drawing, and `F5` restarts a battle.

See [`docs/framework_design.md`](docs/framework_design.md) for architecture and
[`docs/adding_a_hero.md`](docs/adding_a_hero.md) for the character workflow.
The first playable batch contains Cheems, Sword-and-shield Dog, Bear Grylls,
Nailoong, and Chu Ying. Individual designs live in `docs/heroes/`.
