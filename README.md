# DeepSSH

DeepSSH 是一个基于 Flutter Desktop 和 Rust 的跨平台 SSH 客户端。界面层使用 Flutter/Dart，SSH、配置持久化等能力由 Rust 后端提供，并通过 Flutter Rust Bridge 暴露给 Dart。

## 功能概览

- SSH 连接管理：创建、编辑、删除 SSH Profile。
- Explorer 侧边栏：管理本地终端、SSH Profile 和已打开的 SSH 会话。
- SSH 会话：连接、关闭、复制会话，并在 Explorer 中显示会话备注或最近执行的命令。
- 终端渲染：基于 vendored `xterm`，支持终端输入、输出、光标样式、滚动缓冲等能力。
- 主题配置：支持 UI 主题和终端主题配置，并持久化到本地 YAML 配置。
- 颜色配置：支持调色板、十六进制颜色和 HTML/CSS 颜色名输入。
- 正则高亮：支持为终端输出配置正则匹配规则、前景色和备注。
- 跨平台构建脚本：提供 Bash、Windows Batch、PowerShell 三套入口。

## 技术栈

- Flutter Desktop / Dart
- Rust
- Flutter Rust Bridge
- xterm.dart（vendored in `third_party/xterm`）
- YAML 配置持久化

## 环境要求

基础工具：

- Flutter SDK，并启用对应桌面平台支持。
- Rust toolchain，包括 `cargo`。
- `flutter_rust_bridge_codegen`。

平台相关：

- Windows：需要 Visual Studio Build Tools / Desktop C++ toolchain。
- macOS：需要 Xcode 命令行工具。
- Linux：需要 Flutter Linux desktop 构建依赖。

## 获取依赖

```bash
flutter pub get
```

如果 Rust/Dart bridge 模型变更，需要重新生成 bridge 代码：

```bash
flutter_rust_bridge_codegen generate
```

也可以直接使用格式化脚本，它会同时执行 codegen 和 analyze。

## 本地运行

Windows：

```bash
flutter run -d windows
```

macOS：

```bash
flutter run -d macos
```

Linux：

```bash
flutter run -d linux
```

## 构建脚本

项目提供三套等价脚本：

- `build.sh`：macOS/Linux/Git Bash。
- `build.bat`：Windows CMD / Batch。
- `build.ps1`：Windows PowerShell。

### 格式化、代码生成和静态分析

Bash：

```bash
./build.sh fmt
```

Windows CMD：

```bat
build.bat fmt
```

PowerShell：

```powershell
.\build.ps1 fmt
```

该命令会执行：

```text
cargo fmt --manifest-path rust/Cargo.toml
dart format lib test
flutter_rust_bridge_codegen generate
flutter analyze
```

### 构建

`build` 默认使用 `--debug`。

Bash：

```bash
./build.sh build
./build.sh build --debug
./build.sh build --profile
./build.sh build --release
```

Windows CMD：

```bat
build.bat build
build.bat build --release
```

PowerShell：

```powershell
.\build.ps1 build
.\build.ps1 build --release
```

`build.sh` 会根据当前系统自动选择 Flutter desktop target：

- macOS：`flutter build macos`
- Linux：`flutter build linux`
- Windows/Git Bash：`flutter build windows`

Windows 的 `build.bat` 和 `build.ps1` 固定构建 Windows target。

### 打包

`package` 默认使用 `--release`，输出一个可发布目录，不压缩。

Bash：

```bash
./build.sh package
./build.sh package --debug
./build.sh package --profile
./build.sh package --release
```

Windows CMD：

```bat
build.bat package
build.bat package --release
```

PowerShell：

```powershell
.\build.ps1 package
.\build.ps1 package --release
```

输出目录格式：

```text
dist/deepssh-<platform>-<arch>-<mode>/
```

示例：

```text
dist/deepssh-windows-x64-release/
dist/deepssh-macos-arm64-release/
dist/deepssh-linux-x64-release/
```

`dist/` 已加入 `.gitignore`。

## 测试

运行全部 Flutter 测试：

```bash
flutter test
```

运行指定测试文件：

```bash
flutter test test/widget_test.dart
```

运行 Rust 格式化：

```bash
cargo fmt --manifest-path rust/Cargo.toml
```

## 配置与持久化

应用会将 SSH Profile 和主题配置持久化到本地配置文件中。主题配置包含 UI 颜色、UI 字体、终端颜色、终端字体、光标设置、滚动缓冲和正则高亮规则。

运行应用时可能会在项目目录下生成本地 `config/` 目录；该目录属于本地运行数据，不应提交到仓库。

## 项目结构

```text
lib/
  core/               核心模型、主题、通用组件
  features/           SSH、终端、主题配置等功能模块
  src/rust/           Flutter Rust Bridge 生成的 Dart 绑定
  workbench/          主工作台页面和布局
rust/src/             Rust 后端代码
third_party/xterm/    vendored xterm.dart
windows/              Windows desktop 工程
build.sh              macOS/Linux/Git Bash 构建入口
build.bat             Windows CMD 构建入口
build.ps1             Windows PowerShell 构建入口
```

## 开发约定

- 修改 Rust 暴露给 Dart 的接口后，需要运行 `flutter_rust_bridge_codegen generate`。
- 提交前建议运行 `./build.sh fmt` 或对应平台脚本的 `fmt` 命令。
- 打包产物放在 `dist/`，不要提交构建产物和本地配置。
