# 青丘 / Qingqiu

## 最新笔试提交 / Technical design submission

**V4.1 · 九尾狐三阶段战斗 · 有声1.5倍速演示。**

- [下载完整提交包](https://github.com/luye20010831-commits/qingqiu-combat-demo/releases/download/v4.1-submission-20261109/qingqiu-fox-boss-v4.1-submission.zip) · [Release下载页](https://github.com/luye20010831-commits/qingqiu-combat-demo/releases/tag/v4.1-submission-20261109)
- [两页设计说明](submission/docs/qingqiu-fox-boss-v4.1-design.pdf) · [完整Godot源码](submission/project/) · [运行与阅读说明](submission/README.md)
- [战斗机制演示（有声1.5倍速，约1分47秒）](https://github.com/luye20010831-commits/qingqiu-combat-demo/releases/download/v4.1-submission-20261109/qingqiu-fox-boss-v4.1-combat-demo-1.5x.mp4) · [28动作预演（约29秒）](https://github.com/luye20010831-commits/qingqiu-combat-demo/releases/download/v4.1-submission-20261109/qingqiu-fox-boss-v4.1-animation-preview-1.5x.mp4)
- [工具、AI与素材来源](submission/docs/credits-and-ai.md) · [试玩迭代与未完成项](submission/docs/playtest-and-iteration.md) · [提交内容对照](submission/docs/submission-checklist.md)

录像为当前提交源码的引擎实录，使用脚本安排站位、出招及尾血快进；成片1.5倍速，游戏速度不变。本人已补充确认体验全部三阶段并打完P3，调整后“简单多了，打得过了”。实际分工和未完成项见材料。

本轮已删除P2／P3眼睛特写与辅助快捷键提示条；爱心投射物最长2.5秒。P1为青白色且不产生粉雾，P3为更饱和的深玫红并保留粉雾／取光解除。源码、两页设计说明及两段有声视频均已更新。本轮自动／原生和独立导出包已核对，用户此前P3通关属于前一版本，最新修正待本人再体验。

以下展示页及原速静音视频为此前作品展示，最新笔试材料以上述链接为准。

**一场从幼狐到九尾的三阶段 Boss 战。**  
A three-phase boss encounter, from a fox cub to a nine-tailed fox.

[观看演示 / Watch](https://luye20010831-commits.github.io/qingqiu-combat-demo/) · [下载 MP4 / Download](media/qingqiu-combat-demo-20261109.mp4) · [中文简历](resume/Lu_Ye_Game_Design_CN_20261109.pdf) · [English CV](resume/Lu_Ye_Gameplay_and_Interactive_AI_EN_20261109.pdf)

[![Qingqiu combat demonstration](media/poster.jpg)](https://luye20010831-commits.github.io/qingqiu-combat-demo/)

## 展示内容 / The encounter

- **单尾幼狐 / One-tailed cub** — 追逐、近身攻击与追踪爱心；短暂魅惑和护魂盾反制。Pursuit, close-range attacks and a homing charm heart, with brief loss of control and a shield counter.
- **双尾迷雾 / Two tails, gathering mist** — 鬼火弹幕、落地黑焰、移动通道与反击间隙。Ghost-fire patterns and falling black flames, with movement routes and windows to counterattack.
- **九尾金瞳 / Nine tails, golden eyes** — 四心魅惑、光点解魅、环形弹幕及金焰转场。Four charm hearts, cleansing lights, circular barrages and golden-fire transitions.

## 我的工作 / My role

陆叶 / Lu Ye — 主要负责Boss技能与阶段行为、弹幕／火柱密度、魅惑和反制要求，以及试玩后的修改判断。新增美术由AI生成；代码、Shader、素材处理、动画关键帧和自动验证由AI执行，具体见来源与分工说明。

Primary contributions: boss abilities and phase behavior, projectile/pillar density, charm and counterplay requirements, playtest feedback and revision decisions. Artwork is AI-generated; code, shaders, asset processing, animation keyframes and automated checks were produced with AI assistance.

## 历史录像说明 / Earlier capture notes

这是 **Godot 引擎实录，原速、静音**。录像通过脚本安排输入、阶段和招式，并设置生命值保护，用于集中展示机制。该段为此前的历史录像；当前试玩与最新提交以上方材料为准。

Captured in **Godot at normal speed, without audio**. Inputs, stage/attack triggers and health protection are scripted to present the mechanics. This describes an earlier recording; see the latest submission and updated playtest notes above.

项目处于开发中。可进一步提供可玩 Demo 和开发过程演示。  
Prototype in development. A playable demo and development walkthrough are available.

## 来源 / Credits

The underlying project foundation is [ForlornU / TopdownStarter](https://github.com/ForlornU/TopdownStarter), licensed under MIT. Code and assets were developed with AI assistance, as described above.

