# 测试目录说明

本目录同时包含自动回归脚本和人工美术截图工具，两者用途不同。

## 自动回归

由 `scripts/check.ps1` 统一运行：

- `combat_integration.gd`：共享 3D 命中、状态和基础战斗规则；
- `command_system_test.gd`：命令序列、确定性随机与寻路；
- `authority_runtime_test.gd`：权威事件顺序、稳定实体 ID、销毁登记和离线重放；
- `match_replica_test.gd`：客户端只读副本、逐对象 tick 去重、状态恢复和阵亡/复活；
- `score_manager_test.gd`：K/D/A、助攻窗口、实际伤害统计、连杀/终结与比赛结算；
- `scene_command_runtime_test.gd`：Lab 与 Bot 场景共用命令运行时；
- `moba_control_test.gd`：MOBA 输入和状态摘要；
- 五名英雄的 `*_test.gd`，以及贝爷行走贴图节奏测试；
- `scene_navigation_test.gd`：场景切换与返回菜单；
- `network_stage_a_peer.gd`：由双进程联机脚本启动，不应单独加入普通测试循环。
- `network_match_rules_peer.gd`：双进程验证可靠击杀播报、同步比分和结算停控。

这些测试应优先验证公开玩法结果、运行时接口和网络契约。表现层数据应通过
`ActorPresentation` 或对应 `HeroVfx` 检查，不再从 `CombatActor` 引用表现常量。
技能数值断言属于当前英雄设计规格，并非应当删除的实现细节。

## 手工截图工具

`capture_*.gd`、`process_*.gd` 和 `export_*.gd` 用于生成预览或处理美术资源，
可能写入 `runtime/`，不属于无副作用的自动回归。统一通过 `scripts/capture_preview.ps1`
或明确的手工命令运行，不能放入 `scripts/check.ps1`。
