# 奶龙素材记录

## 官方身份参考

- `nailoong_official_character.png`：下载自第七印象奶龙官方网站角色页：<https://www.nailoong.com/ipStar/Nailong/>；直接图片：<https://www.nailoong.com/img/ipStar/image_nailoong.png>。只作为身份、比例与特征参考。

## 生成与运行资源

- `nailoong_identity_master_v1.png`：2026-08-25 使用内置 ImageGen 的 `identity-preserve` 工作流生成。官方角色图是唯一输入身份锚点；要求保留圆头、小嘴、绿色圆眼、短粗四肢、肚皮、肉垫和棕色爪尖，只把双臂改为自然待机并轻微转向屏幕右侧。输出中的棋盘格被烘焙进 RGB，因此仅作为用户确认的身份母版。
- `../sprites/nailoong_idle_v1.png`：对上述用户确认母版执行内置 ImageGen `background-extraction`，仅移除棋盘格并保存真实透明背景。运行时使用此版本，不使用前两张被用户否决的通用幼龙尝试。

最终母版提示的核心限制：不增加吻部、白色大眼球、张嘴笑、头部尖刺、长尾、衣服或装备；不改造成通用动画电影幼龙；可识别度优先于额外精修。
