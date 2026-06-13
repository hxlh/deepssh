# GitHub Actions 构建优化说明

## 优化内容

### 1. Flutter 缓存（第 32 行）
```yaml
- name: Setup Flutter
  uses: subosito/flutter-action@v2
  with:
    channel: stable
    cache: true  # 新增：缓存 Flutter SDK
```

**效果**：Flutter SDK 不需要每次重新下载

### 2. Rust 依赖缓存（第 37-43 行）
```yaml
- name: Cache Rust dependencies
  uses: Swatinem/rust-cache@v2
  with:
    workspaces: |
      rust
      native
    cache-on-failure: true
```

**使用**：[Swatinem/rust-cache](https://github.com/Swatinem/rust-cache)

**效果**：
- 自动缓存 `~/.cargo/registry`（crates.io 下载）
- 自动缓存 `~/.cargo/git`（git 依赖）
- 自动缓存 `target/`（编译产物）
- 根据 Cargo.lock 智能失效缓存

**预期提升**：首次构建后，Rust 编译时间减少 **70-80%**

### 3. flutter_rust_bridge_codegen 缓存（第 45-58 行）
```yaml
- name: Cache flutter_rust_bridge_codegen
  id: cache-frb
  uses: actions/cache@v4
  with:
    path: |
      ~/.cargo/bin/flutter_rust_bridge_codegen*
    key: ${{ runner.os }}-frb-${{ hashFiles('**/Cargo.lock', '**/pubspec.lock') }}
    restore-keys: |
      ${{ runner.os }}-frb-

- name: Install flutter_rust_bridge_codegen
  if: steps.cache-frb.outputs.cache-hit != 'true'
  run: cargo install flutter_rust_bridge_codegen
```

**效果**：
- 缓存已编译的 `flutter_rust_bridge_codegen` 二进制
- 只有在依赖变化时才重新编译
- 这个工具编译很慢（2-3分钟），缓存后跳过

**预期提升**：节省 **2-3 分钟**

## 预期性能改进

| 阶段 | 首次构建 | 缓存命中后 | 节省时间 |
|------|---------|-----------|---------|
| Flutter SDK | ~2 分钟 | ~10 秒 | ~1.5 分钟 |
| Rust 依赖下载 | ~3 分钟 | ~5 秒 | ~2.5 分钟 |
| Rust 编译 | ~8 分钟 | ~1-2 分钟 | ~6 分钟 |
| flutter_rust_bridge_codegen | ~3 分钟 | ~5 秒 | ~2.5 分钟 |
| **总计** | **~20 分钟** | **~8 分钟** | **~12 分钟** |

**首次构建后的构建速度提升约 60%**

## 缓存策略

### Rust 缓存键
- 基于 `Cargo.lock` 和工作区路径
- 自动处理，无需手动配置

### FRB 缓存键
- `key: ${{ runner.os }}-frb-${{ hashFiles('**/Cargo.lock', '**/pubspec.lock') }}`
- 当 Rust 或 Flutter 依赖变化时失效
- `restore-keys` 允许使用部分匹配的旧缓存

### 缓存清理
- GitHub Actions 自动清理 7 天未使用的缓存
- 缓存大小限制：10 GB（整个仓库）

## 验证优化效果

构建完成后，在 Actions 日志中查看：

```
Cache Rust dependencies
  Cache restored from key: Linux-rust-cache-abcd1234
  Saved 1.2 GB

Cache flutter_rust_bridge_codegen
  Cache restored successfully
  
Install flutter_rust_bridge_codegen
  Skipped (cache hit)
```

## 进一步优化建议

### 1. 使用 sccache（可选）
如果 Rust 编译仍然很慢，可以添加分布式编译缓存：

```yaml
- name: Install sccache
  run: |
    cargo install sccache
    echo "RUSTC_WRAPPER=sccache" >> $GITHUB_ENV

- name: Show sccache stats
  run: sccache --show-stats
```

### 2. 并行构建（如果有多个 Rust crate）
```yaml
- name: Build Rust
  run: cargo build --release --jobs 4
```

### 3. 增量编译（已默认启用）
Rust 增量编译已由 `rust-cache` 自动处理。

## 注意事项

1. **首次构建仍然慢**
   - 缓存需要在首次运行后生成
   - 后续构建才会快

2. **缓存可能失效**
   - 修改 `Cargo.lock` 会导致 Rust 缓存失效
   - 修改依赖会触发重新编译

3. **不同分支共享缓存**
   - 同一仓库的不同分支可以共享缓存
   - 加速 PR 构建

4. **Windows vs macOS**
   - 两个平台使用独立的缓存
   - 不会互相干扰

## 测试优化效果

1. 合并这个改动后，手动触发一次构建（首次）
2. 等待完成后，再触发一次构建（使用缓存）
3. 对比两次构建时间

预期第二次构建时间减少 **50-60%**。
