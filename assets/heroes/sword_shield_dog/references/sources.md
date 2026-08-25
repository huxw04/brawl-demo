# 刀盾狗素材记录

## 网络参考

- 刀盾狗原始参考：<https://gengtu.tos-accelerate.volces.com/memes/0b/f0/a3/f3/0bf0a3f38b691849a4f9725cde493851.webp?x-tos-process=style%2Fc>
- 梗图条目：<https://wiki.gengtu.net/origin/dao-dun-gou/>
- 肌肉 Doge 原始参考：<https://i.kym-cdn.com/photos/images/newsfeed/001/582/322/94d.png>
- Swole Doge 条目：<https://knowyourmeme.com/memes/swole-doge>

网络图片只存放在 `references/`；游戏运行资源存放在 `sprites/`。

## 生成与编辑记录

模式均为 ImageGen。普通身体和肌肉身体采用 `precise-object-edit`：要求保留原图人物身份、脸、比例、姿势和廉价网络梗质感，只移除武器/边缘杂质、适度清晰化并输出透明背景。短刀与木盾采用 `stylized-concept`：参考原图重新制作独立透明武器图层，不包含手、角色、文字或服装。

- `sword_shield_dog_body_v1.png`：保留原刀盾狗身体，移除刀盾并补齐被遮挡手部。
- `sword_shield_dog_sword_v1.png`：横向、刀尖朝右的短阔单手剑，钢刃、黄铜护手、棕色握柄。
- `sword_shield_dog_shield_v1.png`：正视木质鸢形盾，木板、暗色边框、金属盾脐与铆钉。
- `sword_shield_dog_swole_v1.png`：保留经典肌肉 Doge 的完整轮廓与姿势，清理边缘并输出透明背景。
