# Cheems / Balltze 原型角色资源

角色名：`Cheems`。视觉目标不是精致拟人武士，而是尽量保留原梗图的狗脸、姿态和廉价 P 图幽默感：狗本体不穿武士服，斗笠压住眼睛，刀在常态背在背后。上线前仍需确认原图来源和使用范围。

- `references/`：用户提供的参考图及 `sources.md` 来源记录；不被游戏直接加载。
- `sprites/`：透明背景分层精灵。运行时代码会自动寻找以下固定名称：
  - `cheems_body_v1.png`：根据 `cheems.png` 清晰化的狗本体，常驻且原则上不做动画；
  - `cheems_hat_v1.png`：根据 `cheems2.png` 提取并清晰化的单独斗笠，常驻并遮住眼睛；
  - `cheems_katana_v1.png`：根据 `cheems1.png`、`cheems2.png` 制作的单独刀；同一张图分别用于背刀和出鞘刀层；
  - `cheems_scabbard_v1.png`：与武士刀比例匹配的独立黑色刀鞘，常驻背部；刀本体根据拔刀状态在背刀层与动作层之间切换；
  - `cheems_samurai_idle_v1.png`：旧的整图占位，仅在上述本体文件不存在时回退使用。
- `vfx/`：刀光、剑气、法阵等效果贴图；`cheems_magic_circle_v1.png` 以加法 Shader 贴到 3D 地面。
- `audio/`：技能与动作音效。

运行时只引用 `sprites/`、`vfx/` 和 `audio/`。替换同名文件后需重新导入 Godot。

分层图片使用相同尺寸的透明画布和相同原点导出，避免运行时重新猜测对齐。动作表现优先由刀层、刀光、地面痕迹和法阵承担；不要求狗本体挥臂、迈步或脚掌贴地。
