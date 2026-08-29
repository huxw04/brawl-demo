# 地图数据与场景构建

## 目标

地图内容不写进战斗场景脚本。地图文件只保存地图本身的信息，`ArenaWorld` 负责把数据构造成 3D 地面、边界、墙体和碰撞；寻路、房主命令校验、出生与未来复活逻辑读取同一份地图定义。

这样更换地图不需要复制战斗场景，未来的随机生成器、地图编辑器和外部导入器也只需要输出相同格式的 JSON。

## 文件与职责

- `maps/*.json`：可存档、可生成、可导入的纯地图数据；
- `src/maps/map_definition.gd`：解析、类型转换、格式校验、边界与出生点查询；
- `src/maps/map_catalog.gd`：稳定 `map_id` 到本地文件的白名单；
- `src/presentation/arena_world.gd`：根据定义生成 3D 表现和物理碰撞；
- `src/navigation/arena_pathfinder.gd`：根据地图边界动态建立寻路网格；
- `src/network/network_session.gd`：开局广播 `map_id + map_version`，房主按同一地图边界验证操作。

目前有两张地图：

- `stage_b_test_arena`：原有 `1400 × 900 码` 小测试场，供 Lab、Bot 和回归测试使用；
- `large_brawl_01`：`3000 × 2200 码` 的第一张联机乱斗灰盒图，含 12 个稳定出生点和 7 个障碍物。

## JSON 格式 v1

世界中 `1 单位 = 100 码`。核心字段如下：

```json
{
  "format_version": 1,
  "map_id": "large_brawl_01",
  "map_version": 1,
  "display_name": "大乱斗灰盒 01",
  "size": [30.0, 22.0],
  "floor_color": "233442",
  "grid_color": "354b5b",
  "boundary_color": "526f80",
  "camera": {
    "orthographic_size": 11.5,
    "position": [0.0, 10.8, 11.8],
    "look_at": [0.0, 0.7, 0.0]
  },
  "spawn_points": [
    {"id": "north_west", "position": [-12.0, 0.05, -8.0]}
  ],
  "obstacles": [
    {
      "id": "center_pillar",
      "kind": "box",
      "center": [0.0, 1.35, 0.0],
      "size": [2.2, 2.7, 2.2],
      "color": "6b607e",
      "label": ""
    }
  ]
}
```

约束：

- `map_id`、出生点 ID 和障碍物 ID 在各自范围内唯一且稳定；
- `map_version` 在任何会改变碰撞、出生或玩法结果的修改后递增；
- 出生点必须位于地图边界内；
- v1 障碍物只支持轴对齐 `box`，其 `center.y` 是盒子中心高度；
- 地图四周的物理边界由 `size` 自动生成，不重复写入 `obstacles`；
- 地面网格、颜色和标签是表现数据，不参与战斗随机数。

## 联机一致性

房主在 match config 中发送地图 ID、地图版本、稳定出生点 ID 和最终出生坐标。客户端必须能从目录加载相同 ID 与版本，否则拒绝进入比赛。房主校验鼠标目标点时不再使用固定常量，而使用已加载地图的合法边界。

当前 `game_version` 握手还能阻止不同构建版本混用。以后允许玩家导入自定义地图时，需要在握手中增加地图内容哈希，不能只依赖整数版本。

战斗随机与表现随机继续分离：服务器从 `spawn_points` 选择复活位置时使用比赛 `BattleRng`；地面尘土等纯特效使用本机表现随机数。

## 后续扩展

下一阶段按顺序增加：

1. 地图选择进入房间配置；
2. 更多障碍类型、装饰物、危险区与可交互物；
3. JSON 导入校验报告与地图预览；
4. 程序化生成器输出同一 JSON 格式；
5. 自定义地图内容哈希与联机分发策略。

地图数据不直接保存脚本、任意资源路径或可执行表达式，避免导入外部地图时把数据格式变成代码执行入口。
