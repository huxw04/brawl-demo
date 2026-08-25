# 褚赢形象参考与生成记录

## 公开参考

- 爱奇艺《棋魂》剧集页，用于确认角色与作品语境：https://www.iq.com/album/1qnvyvuwowo
- 公开剧照（360 图片源），用于面部妆容、黑色高冠和长发轮廓参考：https://hao5.qhimg.com/t0143108a48e1dc0bcd.png
- 公开宣传剧照（搜狐图片源），用于白色宽袖外袍和红色内袖的配色参考：https://p8.itc.cn/images01/20201028/0b11e8001fd14d6bbc0dcd10cec81fa0.jpeg

项目内下载的参考仅用于开发阶段视觉研究，不作为运行时素材：

- `chu_ying_reference_expression.png`
- `chu_ying_reference_costume.jpeg`

## 生成记录

使用 Codex 内置 ImageGen 生成，未调用外部图像插件。核心提示词摘要：三头身 Q 版古装棋士褚赢；保留真人角色的细长眉眼、额间妆点、高黑色南朝冠、长黑发、白色宽袖礼服、红色内袖与领口；空手作即将落子的姿态；完整单人、透明背景；不绘制棋盘、棋子、扇子、文字或额外道具。随后以同一母图执行一次透明背景与边缘清理。

- 母图：`chu_ying_chibi_master_v1.png`
- 运行时透明底：`../sprites/chu_ying_idle_v1.png`
