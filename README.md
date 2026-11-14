# Bone Angler · 骨灰级钓手

## 整体试玩 Demo

双击 `启动/运行游戏.cmd`，或运行已导出的 `game/build/windows/BoneFishing.exe`。封面点击「开始游戏」进入冥河钓点。当前沿用原有演示数值，先以直接喂鱼补全灵魂为主。NPC 按 20～25 秒随机间隔到达，首位 NPC 也遵循这个间隔。

| 操作 | 效果 |
| --- | --- |
| 空格 | 播放四帧抛竿动作，每帧 0.25 秒，共 1 秒，之后进入候鱼 |
| W / A / S / D | 根据箭头逆向拉鱼；鱼线入水点靠近虚线边缘时可获得完美判定 |
| E | 进入灵魂店铺，保留当前鱼与抛竿进度 |
| Q | 回到冥河岸，继续原来的钓鱼进度 |
| 1 / 2 / 3 或点击鱼按钮 | 给选中的灵魂喂对应鱼，扣除共享鱼篓中的真实库存 |
| P / Esc | 暂停；P / 空格继续。窗口失焦时自动暂停 |

灵魂三项属性达到当天要求后，短暂停留显示喂食结果，自动转身、背对玩家沿石路走向冥府大门，随距离缩小并在门内消失，再接待下一位。切换场景会保留抛竿、拉鱼或送客动画的进度；来客与每天的计时在两个场景间共享。

背景和动态鱼线按 405×243 像素网格绘制，界面独立叠加。河景、店铺、鱼竿、封面与灵魂帧均已通过 PerfectPixel，仓库包含 `game/assets/art/demo/` 下的运行素材与 `sources.json` 来源记录。详细制作记录 `game/assets/SOURCES.md` 和原始生成图 `game/art/source` 保留在本地，不影响克隆后运行 Demo。

新入口为 `game/scenes/demo/demo.tscn`。旧的组装、字母钓鱼和独立玩法练习仍保留在 `game/scenes/main.tscn`，可在编辑器中单独运行。

流程回归：

```powershell
& game/.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_integrated_demo.gd
# 去掉 --headless 并追加 -- --capture，可导出实际游戏画面到 game/build/validation/demo。
```

## 开发环境

- Windows 64 位。
- Godot **4.7.2 Standard**，使用 GDScript 和 Compatibility 兼容渲染模式。
- Godot **4.7.2** 导出模板，用于导出 Windows x64 和 Web 版本。
- Git，用于版本管理。
- Python **3.10**，用于本地预览 Web 版本。
- 可选：VS Code 和 Godot Tools **2.7.1** 扩展；也可以使用 Godot 内置脚本编辑器。

工具版本、下载地址和校验值统一记录在 `game/tools/toolchain.json`。

## 准备环境

在仓库根目录运行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\game\tools\Install-Environment.ps1 -SkipCreativeTools
```

脚本会准备 Godot、对应导出模板和编辑器扩展，便携工具保存在 `game/.tools/`。

如果已经安装 Godot 4.7.2，可直接导入 `game/project.godot`，按 F5 运行。

## 启动与检查

- `启动/启动编辑器.cmd`：打开 Godot 工程。
- `启动/运行游戏.cmd`：运行游戏。
- `启动/检查环境.cmd`：检查开发环境。
- `启动/打开代码.cmd`：在 VS Code 中打开工程。

## 像素图后处理

本项目以后新生成或重新生成的像素图，交付前统一经过 [PerfectPixel](https://github.com/theamusing/perfectPixel) 处理并检查。

- 将一张或多张图片拖到 `启动/像素图后处理.cmd` 上处理。
- 原图保留，结果另存为同目录下的 `原文件名.perfect.png`，并附带 `.perfect.json` 处理记录。已有结果不会被覆盖。
- 默认保留采样得到的透明通道，关闭自动补行、删行的正方形修正；仍需检查实际输出尺寸、细线和动画帧的一致性。
- 自动识别失败时，可指定 `--grid 宽 高` 重试；原图与处理稿保存在 `game/art/source`，确认后的正式素材放入 `game/assets/art`，并记录在 `game/assets/SOURCES.md`。

首次安装或在另一台电脑上准备工具：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\game\tools\Install-PerfectPixel.ps1
```

指定网格或输出位置：

```powershell
.\game\.tools\perfect-pixel\venv\Scripts\python.exe .\game\tools\perfect_pixel.py "原图.png" --grid 64 64 --output "处理稿.png"
```

源码与处理环境位于 `game/.tools/perfect-pixel/`，上游提交与源码压缩包校验值固定在 `game/tools/toolchain.json`；安装脚本复用已有兼容依赖，缺失的依赖仅安装到项目内的 Python 环境。

## 导出与本地预览

```powershell
# 导出 Windows 和 Web 版本
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\game\tools\Build.ps1 -Target All

# 启动本地 Web 预览服务
python .\game\tools\serve_web.py
```

导出文件分别位于 `game/build/windows/` 和 `game/build/web/`；本地预览地址为 <http://127.0.0.1:8060>。

项目附带 Noto Sans SC 中文字体及其 SIL Open Font License 1.1 许可。工具安装目录、Godot 缓存和导出文件不纳入版本管理。
