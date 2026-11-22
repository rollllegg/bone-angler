# Bone Angler · 骨灰级钓手

## 整体试玩 Demo

双击 `启动/运行游戏.cmd`，或运行已导出的 `game/build/windows/BoneFishing.exe`。封面选中「开始游戏」后，可以在冥河钓鱼、到炼药台处理鱼获、给灵魂端药，再手动放行。试玩共五天，每天 6 位来客，共 30 位。来客间隔为 20～25 秒。

| 界面 | 键盘操作 |
| --- | --- |
| 封面 | W / S 选择，空格确认，C 关闭设置 |
| 河岸（Q） | 空格抛竿，X 收竿。入水点靠近虚线时，按箭头对应的 WASD 或方向键逆向拉鱼，精确命中获得双倍进度 |
| 钓组 | Shift 开始换件，时间照常流逝。W / S 选槽位，空格打开列表。鱼饵用 WASD 选择，其他部件用 W / S，空格确认。C 逐级返回 |
| 接待（E） | A / D 选等候的来客，W / S 选药剂并预览，空格喂药，Shift 放行 |
| 鱼篓与炼药（R） | WASD 在网格中选择，空格提炼鱼获、放入原液或强化药剂，Shift 切换页签。F 确认配制复方，强化时 X 换属性、V 切换增减 |
| 市场（T） | W / S 选类别，空格进入，再用 W / S 选商品、空格购买或维修。A / D 调整鱼饵数量，C 返回上一级 |
| 暂停 | P / Esc 暂停，P / Esc 或空格继续，C 返回封面。切出游戏时默认自动暂停 |

开局配给 40 枚渡魂币、10 个素指骨饵，以及装有小号钩和一件稳魂指骨的浅水短杆。河岸钓组可更换竿体、鱼钩、握柄和鱼饵，稳魂指骨按杆型自动装配。放行可获得服务费，买到长杆后可转向深水。两种水域合计有 11 种普通鱼。静鳍鳅在浅水较常见、深水较少见，每份静鳍原液只降低 1 点意志。深水装备异刺指骨拟饵时可遇到巨刺灰鳞鱼。巨刺当前沿用字母练习规则，真名捕获参数与遗骨回收方式为试玩设置。

市场的属性饵按药效分为智慧饵、情感饵、意志饵（补对应属性）和愚笨饵、憎恨饵、恍惚饵（降对应属性）。查看商品详情可见目标鱼种。使用时，当前水域的目标鱼上钩权重乘以 3。普通鱼的体型概率由鱼钩决定，鱼种各有自己的体长范围。旧存档的体型饵会等量折算成素指骨饵。

原液既可单独使用，也可配成 78 种双原液复方。接待页左侧显示当天的放行门槛与用药预览。第 1 天随机选两项，均需达到 7。第 2 天随机选一项下限与另一项上限。第 3 天检查两项下限和一项上限。第 4、5 天三项都使用区间。每天放行完当班来客后开启下一天，门槛随存档保留。

来客达到当天要求后，按 Shift 放行，灵魂会沿石路走入冥府大门。前一位离场时即可接待下一位。切换地点会保留抛竿、拉鱼与送客动画进度。

浮漂入水后等 3～8 秒上钩，通常为 5 秒。上钩前收竿会保留鱼饵和耐久。候鱼时切换地点，候鱼计时继续。在其他页面时有鱼上钩，屏幕左侧会弹出感叹号气泡，河岸按钮的 Q 也会变成红色感叹号。按 Q 或点击河岸按钮，在 3 秒内返回可开始拉鱼或真名捕获。超时后鱼会脱钩，上钩时消耗的鱼饵和耐久照常扣除。钓到遗骨时会自动回收，并在屏幕左侧显示提醒。

背景和动态鱼线按 405×243 像素网格绘制，界面独立叠加。河景、店铺、鱼竿、封面与灵魂帧均已通过 PerfectPixel，仓库包含 `game/assets/art/demo/` 下的运行素材与 `sources.json` 来源记录。详细制作记录 `game/assets/SOURCES.md` 和原始生成图 `game/art/source` 保留在本地，不影响克隆后运行 Demo。

新入口为 `game/scenes/demo/demo.tscn`。旧的组装、字母钓鱼和独立玩法练习仍保留在 `game/scenes/main.tscn`，可在编辑器中单独运行。

流程回归：

```powershell
& game/.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path game --script res://tests/test_integrated_demo.gd
# 去掉 --headless 并追加 -- --capture，可导出实际游戏画面到 game/build/validation/playtest。
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

试玩界面使用缝合像素字体 12 px 简体比例版，Noto Sans SC 用于缺字回退和旧练习场景。两款字体的来源和 SIL Open Font License 1.1 许可位于 `game/assets/fonts/`。工具安装目录、Godot 缓存和导出文件不纳入版本管理。
