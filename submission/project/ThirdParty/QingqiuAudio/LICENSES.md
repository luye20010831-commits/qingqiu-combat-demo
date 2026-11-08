# 青丘音效来源与加工

**2026-11-09状态**：用户要求删除AI生成音效后，本文涉及的25份AI程序合成音频已从当前工程及最新无音效包实际删除，旧合成入口停用；第三方原始录音、加工片段与许可证保留。下文合成描述为历史来源记录。[删除范围与证据](../../docs/音频制作/AI合成音效删除_20261109.md)。

## 狐鸣原始录音

- 作品：Fox_noise.mp3
- 作者：janneair
- 来源：https://freesound.org/people/janneair/sounds/192518/
- 页面许可：CC0 1.0，https://creativecommons.org/publicdomain/zero/1.0/
- 下载的是作者页面公开提供的 HQ MP3 预览，保存为 fox_original.mp3。不是 qubodup 的另外一个清理版本。
- 处理：截取、降噪、滤波、调音高、重新组合、淡入淡出和短混响，形成 P1／P2／P3 不同狐鸣层。

## 女声层

- 作品：Female Scream 1
- 作者：Nocturnal_Vanguard / AuraVoice
- 来源：https://opengameart.org/content/female-scream-1
- 原文件：https://opengameart.org/sites/default/files/female_scream_1.ogg
- 页面许可：CC0 1.0，https://creativecommons.org/publicdomain/zero/1.0/
- 处理：剪辑、拉长、音高分层、滤波与混响，和狐鸣混合为 P3 凄厉叫声。没有模仿或克隆指定人物的声音。

来源页面快照保存在同目录。上面两项均在 2026-11-07 核对许可。虽然 CC0 不要求署名，仍保留作者与出处便于追溯。

## 原创程序合成

spirit_hit_1/2/3、spirit_cast 和 spirit_fire_transition 由 tools/build_fox_audio.py 以噪声、正弦波与包络合成，没有使用人物肉体撞击录音。

运行时文件位于 Art/Audio/Qingqiu，生成脚本需要 NumPy 和 ffmpeg。audio_manifest.json 记录时长、峰值及 RMS。所有输出均留有峰值余量，运行时再独立降低播放音量。

## 2026-11-08 战斗时序增量

既有三阶段狐鸣／女声文件保持，本轮 AI 从已有成品各剪出约 0.32 秒短发力声，供实际受击使用；原始录音来源与许可仍按上文追溯。本批未重新下载这些原材料或复核其网页许可。

新增脚步与衣物声来自 [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio)，已从官方原包核对 CC0，原件和许可另存 ThirdParty/KenneyRpgAudio。其他 Combat 目录的风、火、魅惑、解魅、结果及玩家伤害声由 AI 编写 NumPy 脚本合成；均非个人手工录音。详见 tools/build_combat_audio.py、Art/Audio/Qingqiu/Combat/combat_audio_manifest.json 与 Scenes/Qingqiu/COMBAT_AUDIO.md。


## 2026-11-08 转场女声邪笑

作品 [Female Evil Laugh](https://freesound.org/people/mvVoiceActing/sounds/219778/)，作者 mvVoiceActing，页面明确 CC0 1.0。2026-11-08 现场核对；下载作者页面公开 HQ MP3 预览，保存在 PhaseCinematics/female_evil_laugh_hq.mp3，页面快照和实际下载 URL 见同目录 source.json。未取得登录下载的原始 WAV。AI 滤波、淡入淡出、短回声与响度处理为 P2 转场笑声；没有克隆指定人物声音。新 P3 起燃声由 AI 程序合成，非第三方录音。详见 Art/Audio/Qingqiu/PhaseReveal。
