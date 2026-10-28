# 高清分层菜单演员

本目录用于主页、选人和结果演出；战斗像素角色及既有 HD 主立绘保持原文件。

`rio-{body,hair,limbs,sword}-v1.png` 由内置 image_gen 分别新绘，参照
`assets/art/rio.png`：22 岁小个子成年人、蓝双马尾、蓝色不透明比基尼上衣、
navy/cyan 及踝裹裙泳装、凉鞋，以及超过身体高度的重剑。其余四张独立
`*-parts-v1.png` 由根任务生成，保留自然猫、三鞋鲨、平面蓝衫小人及黄鸡的梗身份。
全部透明 PNG 原生文件保存于项目，没有用 Python 修改图像或将旧立绘滤成部件。
生成提示和原生输出路径见 `generation-prompts.json` / `four-memes-prompts-v1.json`。

资源登记：

- `manifest.json`：Rio，4 张纹理、17 个部件记录（16 个同时可见层 + 1 个头表情变体）。
- `four_memes.json`：猫 12 / 小人 12 / 黄鸡 11 / 鲨 12 个部件记录；含表情变体。
- 五人共 64 个记录，普通舞蹈同时绘制 60 个独立部件，8 张新生成 PNG。
- `schema.example.json`：字段例子。`source_rect` 和可选 `source_parts` 是原图像素坐标；
  `size`、骨骼及绑定位置使用 foot-relative 原生身体单位，各人身体单位为 100。
- `pivot` 是裁片内归一化轴点；`source_joint_start/end` 是裁片内原图像素关节。
  `flip_x/y` 同时镜像缓存和关节轴点，不需要改 PNG。
- `bone` 将实际部件关节轴映射到语义骨骼两端，保留源部件曲线；用于四肢、整条后腿。
  `bone_overlap_start/end` 提供隐藏关节的重叠；不会把足底端点额外延长。
- 相邻格的纹理按 alpha 连通部件逐行登记到 `source_parts`，第一次使用只在运行时
  合成独立 ImageTexture 缓存，随后每层一次绘制。鲨尾/身体的隐藏切口盖面不参加绘制。

动画性质：新画的独立身体部件 + 连续关节曲线，不是 8 张独立 AI 全身动画帧。
舞蹈按 8 个拍点校准，160 BPM、两拍 0.75 秒循环；髋、肩、肘、膝、头、尾/发和道具
各有动作。Rio 的上裙另外使用 6 段布料骨链网格、两片下裙随不同相位运动。
双马尾相位各异；重剑角度由原图 alpha 轮廓的 32 点凸包求地面支撑，双手 IK 跟柄，
`weapon_ground_contact.y` 保持 0，真正的 `weapon_tip` 可在地面之上。角色足底根不漂移。

接口：`game/hd_character_rig.gd`（CanvasItem，Control 和 Node2D 均可）。

```gdscript
has_assets(id: String) -> bool
draw_character(canvas, id, clip, progress, facing = 1, tint = Color.WHITE, body_height = 300.0)
get_pose_state(id, clip, progress, body_height = 300.0) -> Dictionary
get_content_rect(id, clip, progress, body_height = 300.0, facing = 1) -> Rect2
release_cache()
```

`progress` 为 0..1。`idle` / `dance` 循环；`invite` / `confirm` / `easter` 单次，
调用方完成后回到 dance。推荐时长 2.25 / 0.75 / 0.32 / 0.24 / 0.32 秒。
renderer 保留调用方 draw transform，不移动 Control、按钮或整个演员根。
`get_pose_state` 提供真实骨点、活动部件数、头表情、内容框、剑尖与地面接点。
布局应预采样整个循环的 union bounds 作固定 contain，不能每一帧按 bbox 重新缩放。
鲨和 Rio 的尾/巨剑较宽；主页和选人应留足完整演出空间。头像仍可使用既有精美主立绘。

验证：`work/hd-rig-test/render_actual.gd` 用真正 OpenGL/Godot 生成 20 张独立画面，
每张 4 个不同相位，共 80 个可见姿态；主 UI native 接线由 UI 任务单独验证。
`tests/hd_character_rig.gd` 检查资源登记、脚点、真实关节变化、地面支撑及完整布局框。
测试输出和捕获图放在 work，不作为生产角色素材。
