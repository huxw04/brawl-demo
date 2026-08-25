# 贝尔·格里尔斯素材记录

此目录中的图片仅作为角色设计、姿势、服装和身份特征参考，不是可直接发布的游戏运行资源。最终 `sprites/` 需要记录实际制作方式与许可状态。

## 用户提供的梗图

- `1.png`：正面近景，适合参考脸部、头巾和二创气质；原始来源待补充。
- `2.png`：背面全身，适合参考服装背面和剪贴风格；原始来源待补充。
- `3.png`：右侧身接近全身，是当前首选姿态母版；适合保留轮廓和服装，箱子、武器与缺失脚部需要重建；原始来源待补充。

## 网络候选

- `candidate_a_classic_full_standing.jpg`：经典完整正面站姿，用于补足身体比例、裤腿和靴子。发现页面：<https://www.pinterest.com/pin/809381364311221585/>；直接图片：<https://i.pinimg.com/originals/34/40/47/34404724f751d5cf2cfa45863ec1964c.jpg>。
- `candidate_b_classic_backpack_full.jpg`：经典三分之二全身姿态，用于补背包、工装裤和人物身份。页面：<https://www.gq.com/gallery/bear-grylls>；直接图片：<https://media.gq.com/photos/558438923655c24c6c97ef3b/master/w_1024,c_limit/style-2011-06-10-essentials-bear-grylls-bear-grylls-portrait.jpg>。
- `candidate_c_dark_gear_three_quarter.jpg`：高清三分之二行走姿态，用于补侧向重心、脸和背包结构。页面：<https://news.cision.com/bushnell-outdoor-products/i/bear-grylls,c1230055>；直接图片：<https://mb.cision.com/Public/303/9288345/b0a35f95d5c34344_org.jpg>。
- `candidate_d_side_motion.jpg`：跨越动作近景，并非完整侧身；仅用于补充脸、肩背和动作受力。页面：<https://www.primevideo.com/-/pt/detail/Man-vs-Wild/0IA0401V3156XXGYBJ95JUJQ0V>；直接图片：<https://m.media-amazon.com/images/S/pv-target-images/b25a8ba655d2a76fdfbbdbee34d67d9b202db2c056a503391e92fe637863e517.jpg>。

## 当前合成建议

以用户提供的 `3.png` 作为右侧身构图，以 `candidate_a` 补全人体比例、裤腿和靴子，以 `candidate_b` / `candidate_c` 补脸、背包与服装细节；移除原图箱子和科幻武器，双臂恢复成适合独立小刀图层的自然戒备姿势。最终人物保留节目截图式真人质感和略粗糙的网络剪贴边缘，不改造成标准游戏盔甲。

## 生成记录

- `bear_grylls_body_concept_v1.png`：2026-08-25 使用内置 ImageGen 生成的透明背景身份母版。输入参考为用户提供的 `3.png`、`candidate_a_classic_full_standing.jpg` 和 `candidate_c_dark_gear_three_quarter.jpg`。生成要求为：保留 `3.png` 的朝右三分之二侧身轮廓，用候选 A 补全全身比例、浅色工装裤与靴子，用候选 C 提供脸、暗色户外衬衫和背包；空手、完整手脚、单人、透明背景；不包含武器、钩爪、绳索、箱子、科幻装备、帽子、头巾、文字、标志或水印。输出为 `1024 × 1536`、32 位 ARGB，角落透明度已检查为 0。

### 关键姿势试验

2026-08-25 使用内置 ImageGen 的 `identity-preserve` 工作流，以 `bear_grylls_body_concept_v1.png` 为唯一身份锚点，只允许改变手脚、重心和极小幅度的身体倾斜：

- `bear_grylls_idle_alpha_v1.png`：稳定待机，双脚着地、双手自然下垂；已通过 32 位 ARGB 和角落 alpha=0 检查，是可用的真透明姿势。
- `bear_grylls_walk_reach_v1.png`：行走抬脚/伸展试验。
- `bear_grylls_walk_contact_v1.png`：宽步接触相试验。
- `bear_grylls_walk_pass_v1.png`：紧凑经过相试验，后脚弯曲抬起。

后三张人物身份和服装一致性较好，但生成器将透明棋盘格烘焙进 24 位 RGB。对它们再次执行 `background-extraction` 后，仅待机图成功生成真实 alpha；失败的提取结果保留为 `*_bg_attempt*.png`，不能进入运行时 `sprites/`。下一步应先确定动作幅度是否满意，再选择可靠的本地抠图流程或继续进行单图背景提取，不能仅凭预览中的棋盘格判断透明度。

### 双姿势行走修订

根据用户反馈，正式方案缩减为两帧：一帧近侧腿在前，一帧远侧腿在前；头部统一转向移动方向，使用侧脸而不是持续看镜头。

- `bear_grylls_walk_side_a_v1.png`：侧脸和身体方向正确，大口袋所在的近侧腿在前；当前仍为烘焙棋盘格的 24 位 RGB，只作姿势参考。
- `bear_grylls_walk_side_b_rejected_v1.png`：尝试交换远近腿的失败结果。即使增加彩色骨架 `walk_pose_b_guide.*` 并明确要求“大口袋腿退后”，生成结果仍把大口袋腿画在前方，因此标记为 rejected，禁止进入运行时。
- `bear_grylls_walk_side_b_rejected_v2.png`：进一步把姿势参考拆成四种颜色，并明确采用交叉步态：远侧腿与近侧戴表右手同时向前，近侧大口袋腿与远侧左手同时向后。生成结果已正确实现朝右侧脸和戴表右手向前，但仍把大口袋近侧腿画在前方，形成同侧手脚向前；同时输出仍是烘焙棋盘格的 24 位 RGB（角落 alpha=255）。因此继续标记为 rejected，仅用于说明“手臂约束有效、腿部层级失败”。

结论：内置 ImageGen 能稳定保持侧脸、身份和服装，但不能可靠控制该侧视构图中的左右腿层级。第二帧不应继续靠提示词碰运气；应在用户授权后采用确定性的图层方法，将腰部以下的两条腿分离、交换前后层级并修整裤裆接缝。普攻和技能只要求单张动作高光，不存在左右交替问题，仍适合继续使用身份保持生成。

### 运行时行走资源

经用户复核，前面的“顺拐”判断混淆了画面遮挡与人物左右腿身份。最终选择 `bear_grylls_walk_lower_swap_attempt_v1.png` 与 `bear_grylls_walk_side_b_pose_v2.png` 作为一对相反跨步关键姿势，并与真透明待机图组成行走循环。

- `../sprites/bear_grylls_idle_v1.png`：由 `bear_grylls_idle_alpha_v1.png` 保留 alpha 转存。
- `../sprites/bear_grylls_walk_near_v1.png`：来自 `bear_grylls_walk_lower_swap_attempt_v1.png`。
- `../sprites/bear_grylls_walk_far_v1.png`：来自 `bear_grylls_walk_side_b_pose_v2.png`。

两张行走原图的棋盘格已经烘焙进 RGB，运行资源采用确定性的浅色中性背景提取转换为 32 位透明 PNG。转换后尺寸均为 `1024 × 1536`，角落 alpha=0；参考原图不覆盖，继续留作可追溯母版。

### 普攻动作候选

2026-08-25 使用内置 ImageGen 的 `identity-preserve` 模式，以透明待机图锁定身份、服装和背包，以右侧身行走图锁定人物朝向与画布比例，各生成一张完整全身动作高光帧：

- `bear_grylls_basic_ranged_pose_v1.png`：远程普攻投刀刚脱手的随挥姿势。人物朝右，戴表右臂在肩胸高度完全前伸、手指张开；人物图不包含飞刀，投射物留给运行时独立生成。
- `bear_grylls_basic_melee_pose_v1.png`：近战普攻的低重心曲臂挥刀姿势。双膝弯曲、身体前倾，戴表右手握一把短柄求生刀，刀柄与手腕方向连续。

两张候选均为 `1024 × 1536`，生成器把棋盘格烘焙进 24 位 RGB（角落 alpha=255）。用户确认后已用与行走图相同的确定性背景提取流程转成 `../sprites/bear_grylls_basic_ranged_v1.png` 与 `../sprites/bear_grylls_basic_melee_v1.png`，均为 32 位透明运行资源；参考原图继续保留。

### W / E / R 动作候选

2026-08-25 继续使用内置 ImageGen 的 `identity-preserve` 模式，每个技能单独生成一张高表现力全身定格；人物贴图只承担肢体表演，技能特效继续由运行时 3D 表现层完成：

- `bear_grylls_skill_w_backstab_pose_v1.png`：W 背身藏刀姿势。主体背对镜头、低重心宽站、回头观察；戴表右手在腰后反握短刀，刀刃向下。毒雾、标记和延迟伤害特效不烘焙在图中。
- `bear_grylls_skill_e_grapple_pose_v1.png`：E 钩爪绷紧受力姿势。戴表右臂朝右前方伸直，胸腹和腰背向后形成夸张弓形，左臂与背包向后拖曳。钩头、绳索与拉拽轨迹由运行时绘制。
- `bear_grylls_ultimate_ambush_pose_v1.png`：R 正面悬空低蹲姿势。双膝外张、双臂在胸前形成 X，戴表右手反握短刀；用于残影瞬移后的定格。残影、位移和轻微浮空由运行时控制。

三张候选均为 `1024 × 1536`，原图是烘焙棋盘格的 24 位 RGB（角落 alpha=255）。用户确认后已统一转换为以下 32 位透明运行资源并接入技能时间线：

- `../sprites/bear_grylls_skill_w_v1.png`
- `../sprites/bear_grylls_skill_e_v1.png`
- `../sprites/bear_grylls_ultimate_v1.png`

转换只移除背景，不重绘人物；原始动作候选继续留在 `references/` 作为可追溯母版。
