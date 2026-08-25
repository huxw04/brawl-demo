# 参考图记录

把参考图片放在本目录，并为每张图片记录：文件名、来源链接、作者/上传者、用途、是否允许在项目中再利用。

早期整图占位 `cheems_samurai_idle_v1.png` 未复制第三方二创，只使用了文字方向；当前运行版本已经改为下述用户参考图驱动的分层素材。

## 2026-08-22 分层素材

输入参考由用户放入本目录：`cheems.png` 用于本体，`cheems2.png` 用于斗笠，`cheems1.png` 与 `cheems2.png` 用于刀。请后续补充三张图的原始来源和使用许可。

输出：

- `../sprites/cheems_body_v1.png`
- `../sprites/cheems_hat_v1.png`
- `../sprites/cheems_katana_v1.png`

使用 Codex 内置 ImageGen。提示词：

1. 本体：保留参考图中 Cheems 的确切身份、坐姿、身体比例、别扭的腿部位置、眯眼、口鼻、头部角度和低成本梗图感；只提高分辨率、毛发清晰度和边缘质量；移除黑色背景并输出透明 alpha；禁止衣服、斗笠、刀、阴影、地面、文字、绘画化和姿势重绘。
2. 斗笠：只提取参考图中的宽檐编织斗笠；保留磨损、不均匀草编纹理、低帽檐和压住狗眼睛的轮廓；移除狗、刀、绿幕、花瓣、UI、文字和阴影；透明背景。生成器把透明棋盘格烘入图片，因此运行时使用浅色中性背景键控材质，不再重绘斗笠。
3. 武士刀：参考两张图生成一把独立、清晰但仍像廉价照片拼贴的日本刀；长而略弯的银色刀身、黑柄白色菱形缠带、小型深色刀镡；完整横向侧视、刀尖在左、刀柄在右；移除狗、斗笠、背景、花瓣、UI、手、阴影和文字；透明背景。

## 2026-08-22 动作效果素材

用户补充 `剑气.png`、`法阵.png`、`次元斩.png` 作为表现方向参考；三张图只用于观察光柱厚度、法阵层次和交错切割线，不被运行时直接加载。原始来源和再利用许可仍待补充。

输出：

- `../sprites/cheems_scabbard_v1.png`
- `../vfx/cheems_magic_circle_v1.png`

使用 Codex 内置 ImageGen（参考图编辑/派生模式）。提示词：

1. 法阵：`Create a square top-down game VFX texture for a Godot 3D floor decal, guided by the provided reference image. A precise Japanese dimensional-slash magic circle: multiple concentric rings, restrained geometric sigils, broken radial tick marks, and a sharp central hexagonal star. Cold white core light with pale cyan and very subtle lavender edges, elegant samurai/space-cutting mood, readable from an angled MOBA camera. Pure solid black background so additive blending removes it cleanly. Perfectly centered, rotationally symmetric overall, crisp thin luminous strokes, generous black negative space, no orange, no flames, no characters, no weapons, no readable text, no letters, no numbers, no watermark, no border outside the circle. Asset texture, 1:1 composition, high contrast, 1024x1024.` 参考 `法阵.png`。
2. 刀鞘：`Create one isolated Japanese katana scabbard game sprite that matches the exact proportions and slightly cheap photocomposite realism of the provided katana asset. Side view, perfectly horizontal, scabbard mouth on the right and tapered tip on the left, long slim gently curved saya sized to cover the blade in the reference. Matte charcoal-black lacquer with restrained dark brown wrapping detail near the mouth and one small dull brass fitting; no sword, no exposed blade, no hands, no character, no text. Transparent background with clean edges and generous padding, object centered, 1:1 square canvas, 1024x1024. Preserve practical cutout-photo texture rather than polished fantasy concept art.` 参考 `../sprites/cheems_katana_v1.png`。

动态 Q 光柱、W 月牙擦除、R 切割线/虚影/碎裂仍由 Godot 3D 几何、Shader 和 Tween 生成，没有把参考截图直接转成游戏贴图。
