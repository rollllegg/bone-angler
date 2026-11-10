# Bone Angler · 骨灰级钓手

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

## 导出与本地预览

```powershell
# 导出 Windows 和 Web 版本
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\game\tools\Build.ps1 -Target All

# 启动本地 Web 预览服务
python .\game\tools\serve_web.py
```

导出文件分别位于 `game/build/windows/` 和 `game/build/web/`；本地预览地址为 <http://127.0.0.1:8060>。

项目附带 Noto Sans SC 中文字体及其 SIL Open Font License 1.1 许可。工具安装目录、Godot 缓存和导出文件不纳入版本管理。
