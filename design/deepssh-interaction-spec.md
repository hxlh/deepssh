# DeepSSH Web 原型 · 交互规格（文字版）

> 基准原型：`deepssh-prototype.html`（单文件高保真原型，含真实交互）
> 配套文档：`deepssh-prototype-spec.md`（布局、层级、视觉语言、与源码的差异）
> 文档日期：2026-10-04

## 0. 这份文档写什么、不写什么

**写**：原型里真实存在的交互行为与状态流转。每节固定三段——**触发 → 状态变化 → 可见反馈**；状态迁移用表格表达，并标注对应的 `data-*` / `id` 触发点，方便开发对码。

**不写**：视觉规格（尺寸、间距、配色令牌）见 `deepssh-prototype-spec.md`；后端接口字段与业务规则见第 11 章「与源码的差异」。原型没有做的交互，本文档不补写，只在第 12 章如实列出「未接线项」。

术语约定：

| 词 | 含义 |
|---|---|
| 会话（session） | 终端里的一次连接，由 `data-session` 标识（`terminal1`…`terminal5`、新建的 `local1`、`terminal3-copy1`） |
| 配置块（block） | Explorer 里一个 `.ex-sec`，＝一个配置 + 它下面已打开的会话行 |
| 分区 / tab | 同「配置块」，本文统一叫「配置块」 |

---

## 1. 全局约定

### 1.1 反馈层：四种反馈载体

| 载体 | DOM | 用途 | 关闭方式 |
|---|---|---|---|
| Toast | `#toastWrap` | 操作结果的一句话回执 | 自动，2600ms 后移除 |
| 确认对话框 | `#dialog` | 破坏性操作二次确认 | `#dlgCancel` / `#dlgConfirm` / 点遮罩 / `Esc` |
| 抽屉 | `#drawer` | 新增 / 编辑表单 | `#drawerClose` / `#drawerCancel` / 点遮罩 / `Esc` |
| 右键菜单 | `.ctx`（动态插入 `body`） | 上下文操作 | 点菜单项 / 点外部 / 任意滚动 / 缩放 / `Esc` |

**触发 → 状态变化 → 可见反馈（通用）**

- 触发：任何会改变数据或状态的操作。
- 状态变化：更新内存态 → 需要跨会话保留的写 `localStorage`。
- 可见反馈：必须落在三选一——**toast 文案**、**控件自身状态**（选中态、badge、开关）、**列表结构变化**（行增删）。不允许"静默生效"。

### 1.2 持久化键（`localStorage`，落地映射到 `prefs`）

| 键 | 类型 | 默认 | 写入时机 | 读取时机 |
|---|---|---|---|---|
| `deepssh.page` | string | `workbench` | 每次 `showPage()` | 启动时决定初始页面 |
| `deepssh.sbW` | number | `280` | Explorer 分隔条拖动结束 | 启动时恢复宽度 |
| `deepssh.dockH` | number | `280` | 底部分隔条拖动结束 | 启动时恢复高度 |
| `deepssh.dockCollapsed` | `0`/`1` | `0` | 折叠条点击、拖动结束 | 启动时恢复折叠态 |
| `deepssh.dockEventsW` | number | 实测宽度 | `#dockVSplit` 拖动结束 | 启动时恢复事件面板宽度 |
| `deepssh.memHidden` | `0`/`1` | `0` | 页脚「内存监控」开关 | 启动时恢复显隐 |
| `deepssh.uiPresets` | JSON 数组 | `[]` | 界面主题：新建 / 复制 / 删除自定义方案 | 渲染下拉列表时 |
| `deepssh.uiHiddenPresets` | JSON 数组 | `[]` | 界面主题：删除内置方案 / 恢复内置方案 | 渲染下拉列表时 |
| `deepssh.termPresets` | JSON 数组 | `[]` | 终端主题：同上 | 同上 |
| `deepssh.termHiddenPresets` | JSON 数组 | `[]` | 终端主题：同上 | 同上 |

自定义方案对象结构：`{ id, name, sw }`，`id` 形如 `ui-c1-mfz3k2`（`kind` + 序号 + 时间戳 36 进制）。

### 1.3 只在内存、刷新即丢的状态（开发需知道边界）

| 状态 | 载体 | 说明 |
|---|---|---|
| Explorer 配置块顺序 | DOM 顺序 | 拖动后不写盘，刷新回到源码顺序 |
| 配置块折叠状态 | `.ex-sec.collapsed` | 同上 |
| 块内会话顺序 | `.ex-items` 内 DOM 顺序 | 同上；随复制会话追加、关闭会话移除即时重编号 |
| 当前选中的预设方案 | `PRESET_SEL = { ui:'deck', term:'deck' }` | 刷新回到 `deck` |
| 正则高亮规则 | `rxRules` | 跟随终端预设整体替换，不单独持久化 |
| 已打开会话与标签 | DOM | 同上 |
| 连接 / 转发列表的增删改 | DOM | 刷新回到初始 6 条 / 3 条 |

### 1.4 全局键盘

| 按键 | 作用 | 覆盖范围 |
|---|---|---|
| `Esc` | 一次性关闭抽屉、确认框、备注框、右键菜单、下拉菜单 | `document` 级监听 |
| `Tab` | 在预设下拉内按下即收起菜单（焦点自然外移） | 仅预设下拉 |

---

## 2. 页面导航

### 2.1 顶栏主导航

- **触发**：点击 `.page-nav button[data-page]`，值为 `workbench` / `connections` / `tunnels` / `theme`；或点击任意 `[data-open-page]`（页脚「主题配置」按钮，值 `theme`）。
- **状态变化**：所有 `.page` 的 `hidden` 置位——仅目标页 `hidden=false`；`aria-current="page"` 移到目标按钮；写 `deepssh.page`；页面滚动位置归零。
- **可见反馈**：整块 `<main>` 内容替换；当前导航按钮加深并带下划线（`aria-current`）。

### 2.2 导航状态迁移

| 当前 | 触发 | 变化 | 可见反馈 |
|---|---|---|---|
| 任意页 | `data-page="connections"` | `#page-connections.hidden=false`，其余 `true` | 顶部标题变「连接配置」，右侧主 CTA「新增 SSH 配置」 |
| 任意页 | `data-page="tunnels"` | `#page-tunnels.hidden=false` | 标题变「端口转发」 |
| 任意页 | `data-page="theme"` | `#page-theme.hidden=false` | 标题变「主题配置」，页脚出现「恢复默认 / 保存主题」 |
| 任意页 | `data-page="workbench"` | `#page-workbench.hidden=false` | 恢复 Explorer + 终端 + 底板三段布局 |

---

## 3. 工作台 · Explorer 资源管理器

### 3.1 配置块折叠

- **触发**：点击 `.ex-ghead.clickable`（`role="button"` `tabindex="0"`）；键盘 `Enter` / `Space`。点在拖动柄 `.ex-grip` 上不触发折叠。
- **状态变化**：`.ex-ghead` 的 `aria-expanded` 在 `true`/`false` 间切换；父 `.ex-sec` 增删 `.collapsed`。
- **可见反馈**：`aria-expanded="false"` 时折叠箭头 `rotate(-90deg)`（120ms ease），`.ex-items` 整块 `display:none`；标题底色 hover 才出现。

### 3.2 配置块排序（Flutter `ReorderableListView` 语义）

拖动柄：`.ex-ghead` 内由脚本注入的 `.ex-grip`（6 点竖排图标，`cursor:grab`，`touch-action:none`）。

**指针拖动**

- **触发**：在 `.ex-grip` 上 `pointerdown`（仅主键 `button===0`）。
- **状态变化**：脚本对握把 `setPointerCapture`（不支持则降级为普通监听）；被拖块加 `.dragging`，内联 `transform: translateY(指针位移 + 滚动位移)`；树容器加 `.reordering` 变相对定位，插入虚线落位框 `.ex-shade`（高度＝被拖块高度）。落位索引按「指针 Y 与其余块中线比较」得出。
- **可见反馈**：被拖块浮起（白底 + `--shadow-hard` 硬阴影），虚线框落在目标槽位；指针进入树区上下 28px 内触发 `requestAnimationFrame` 自动滚动（每次 5px）。

**松手**

- **触发**：`pointerup` / `pointercancel`。
- **状态变化**：清内联样式与 `.dragging`、移除 `.ex-shade`；若落位索引 ≠ 原索引，调用 `moveSection()` 真正改 DOM 顺序；否则只重排编号。
- **可见反馈**：toast「已把「prod-web-01」移到第 2 位」；焦点移到新位置的 `.ex-grip`；所有握把的 `aria-label` / `title` 重写为「拖动调整顺序，「X」当前第 N 项，共 M 项」。

**键盘排序**

- **触发**：`.ex-grip` 聚焦时按 `Alt` / `Ctrl` / `⌘` + `↑` / `↓`。
- **状态变化**：同 `moveSection(from, to)`，越界忽略。
- **可见反馈**：同指针拖动落位后的表现（toast + 焦点跟随 + 编号刷新）。

**排序状态迁移**

| 当前 | 触发 | 变化 | 可见反馈 |
|---|---|---|---|
| 第 1 位 | 握把 `Alt+↑` | 无（第 1 位不能上移） | 无反馈（`preventDefault` 吃掉按键） |
| 第 N 位 | 握把 `Alt+↓` | 与第 N+1 位交换 | toast + 焦点下移 + 编号刷新 |
| 任意 | 指针向下拖过第 N+1 块中线 | 落位索引变为 N+1 | 虚线框移到该块下方 |
| 任意 | 拖到列表最底部 | 落位索引 = 长度（末位之后） | 虚线框落在最后一块下沿 |

### 3.3 会话排序（配置块内）

拖动柄：每个 `.ex-row` 内由脚本注入的 `.ex-sgrip`（与配置块同一枚 6 点图标，尺寸更小一档）。**作用域限定在所属 `.ex-items`**——会话只能在同一配置内换位，不能被拖进别的配置。

**指针拖动**

- **触发**：在 `.ex-sgrip` 上 `pointerdown`（仅主键 `button===0`）。
- **状态变化**：对握把 `setPointerCapture`；该行加 `.dragging` 并跟随指针 `translateY`；所在 `.ex-items` 加 `.reordering` 变相对定位，插入 `.ex-shade.in-row` 虚线落位框（左右各内缩到行盒宽度）。落位索引按「指针 Y 与同块其余行中线比较」得出。
- **可见反馈**：该行浮起（白底 + `--shadow-hard`），虚线框落在目标槽位；松手 toast「已把「发布流水线」移到第 2 位」，焦点移到新位置的握把，所有握把 `aria-label` / `title` 重写为「当前第 N 项，共 M 项」。

**键盘排序**

- **触发**：`.ex-sgrip` 聚焦时按 `Alt` / `Ctrl` / `⌘` + `↑` / `↓`。
- **状态变化**：同 `moveSession()`，只在同一 `.ex-items` 内换位，越界忽略。
- **可见反馈**：同指针落位后的表现（toast + 焦点跟随 + 编号刷新）。

**会话排序状态迁移**

| 当前 | 触发 | 变化 | 可见反馈 |
|---|---|---|---|
| 块内第 1 位 | 握把 `Alt+↑` | 无（第 1 位不能上移） | 无反馈（`preventDefault` 吃掉按键） |
| 块内第 N 位 | 握把 `Alt+↓` | 与第 N+1 位交换 | toast + 焦点下移 + 编号刷新 |
| 块内仅 1 个会话 | 任意拖动 / 键盘排序 | 无可换位对象 | 无 toast，仅编号刷新为「第 1 项，共 1 项」 |
| 拖到块内最底部 | 指针越过最后一行中线 | 落位索引 = 长度（末位之后） | 虚线框落在最后一行下沿 |

> 行内其余触发点不受影响：点在握把外仍打开会话（3.4），`Enter` / `Space` 仍作用于行本身（握把聚焦时不冒泡给行），右键菜单照旧。

### 3.4 打开会话
- **触发**：点击 `.ex-row`（`data-session`）；键盘 `Enter` / `Space`。
- **状态变化**：`openSession(id)`——若 `#tabStrip` 无 `data-tab="id"` 的标签则 `createTab()` 追加到标签条末尾，再 `activateTab(id)`。
- **可见反馈**：该标签加 `.active`（顶部 3px 赤陶条 + 加粗），终端区替换为该会话的输出内容；同时 Explorer 内同 `data-session` 的行加 `.active`（分组色加深；本地行为赤陶底）；若标签条溢出，激活标签自动横向滚到中间。

### 3.5 会话右键菜单

- **触发**：在 `.ex-row` 上 `contextmenu`（阻止默认菜单）。
- **状态变化**：动态插入 `.ctx[role=menu]` 到 `body`，按指针位置贴边收敛（距视口边缘至少 8px）；记录当前打开的菜单实例（全局唯一）。
- **可见反馈**：菜单项按会话类型分流：

| 行类型（`data-kind`） | 菜单项（顺序固定） |
|---|---|
| `ssh` | 编辑备注 / 复制 / 关闭 SSH 会话 |
| `local` | 关闭终端 |

菜单宽 150px、项高 32px，hover 出现 3px 赤陶左边条。

### 3.6 编辑会话备注

- **触发**：右键菜单「编辑备注」→ 打开 `#noteDlg`，输入框预填该行 `data-note`（无则空），30ms 后聚焦 `#noteInput`。
- **状态变化（点「保存」`#noteSave`）**：取 `value.trim()`；写回该行 `data-note`；`.name` 文本 = 备注，为空则回落到 `data-title`；若该会话有标签页，同步 `.tlabel` 文本与关闭按钮 `aria-label`。
- **可见反馈**：Explorer 行名与标签页标题同时改名；toast「已更新会话备注 发布流水线」，清空备注时 toast 变「已清除会话备注」。
- **取消路径**：`#noteCancel`、点遮罩、`Esc` 均直接关闭，不改任何状态。

### 3.7 复制会话

- **触发**：右键菜单「复制」。
- **状态变化**：`noteSeq++`；新 `data-session` = `<原 id>-copy<序号>`；`cloneNode(true)` 该行并清空 `data-note`、移除 `data-od-id`、去掉 `.active`；克隆行插入到源行**之后**（同一配置块内）；若源会话有 `<template id="src-…">`，把内容复制进 `termContent[新 id]`；`createTab()` + `activateTab()`。
- **可见反馈**：Explorer 出现新行（名称 = `data-title`），标签条新增并激活该标签，toast「已复制会话 deploy@prod-web-01:22」。

### 3.8 关闭会话 → 配置块连带移除 → 树空态

这是本轮新增的核心规则：**配置块只在有会话时存在**。

- **触发**：行内 `.ex-x` 关闭按钮，或右键菜单「关闭 SSH 会话」/「关闭终端」。两者走同一个 `closeSession()`，行为完全一致。
- **按钮显形与命中**：`.ex-x` 默认 `opacity:0`，`.ex-row:hover` 或 `:focus-within` 时显形（键盘 Tab 过去也能看见）。点击由 `#exTree` 上的**事件委托**处理，因此 `duplicateSession()` 克隆出来的行同样有效；处理时 `stopPropagation`，行自身的 click 因 `.ex-x` 命中判断提前 return，不会连带打开会话。
- **状态变化**（`closeSession()` 顺序）：
  1. 记住所属 `.ex-sec`；
  2. 移除该 `.ex-row`；
  3. 若该会话有标签页，`closeTab(tab)` 连带关闭标签；
  4. `delete termContent[id]`；
  5. `pruneSection(sec)`：**块内 `.ex-row` 数为 0 时移除整个 `.ex-sec`**，随后刷新树空态与所有握把编号。
- **可见反馈**：
  - 未清空该块：toast「已关闭 SSH 会话 tail -f access.log」；
  - 刚好清空该块：toast「已关闭 SSH 会话 …，配置「prod-web-01」已从 Explorer 移除」；
  - 所有块都被移除：`#exTree` 加 `.empty`（树区隐藏），`#exTreeEmpty` 取消 `hidden`，显示图标 + 等宽「暂无已打开的会话」+「从右上角「新增连接」打开一个终端」。

**状态迁移表**

| 当前 | 触发 | 变化 | 可见反馈 |
|---|---|---|---|
| 块内有 2 个会话 | 关闭其中 1 个 | 块保留，行数 2→1 | 仅 toast，无块级提示 |
| 块内最后 1 个会话 | 关闭它 | `.ex-sec` 整体移除 | toast 追加「配置「X」已从 Explorer 移除」 |
| 仅剩 1 个块 | 关闭其最后会话 | 树区清空 | 出现树区空态 |
| 树区空态 | 顶栏「新增连接 → 本地终端」 | `#localSec` 不存在则重建并追加到末尾 | 空态消失，`Local` 块重新出现并展开 |
| 任意状态 | 点击行内 `.ex-x` | 等同右键「关闭会话」，走同一 `closeSession()` | 同上两条 toast 规则 |

### 3.9 页脚「内存监控」开关

- **触发**：点击 `#exMemToggle`。
- **状态变化**：`memHidden` 取反；`#bench` 的 `data-mem` 切 `hidden`/`shown`；写 `deepssh.memHidden`；事件面板宽度按新上限重新钳制。
- **可见反馈**：按钮 `.on` 与 `aria-pressed` 同步；`title` / `aria-label` 在「隐藏内存监控面板 / 显示内存监控面板」之间切换；`#memoryDock` 与 `#dockVSplit` 一起进出布局——隐藏时事件面板铺满整行（不留空洞）；toast「已隐藏内存监控面板」/「已显示内存监控面板」。

### 3.10 页脚「主题配置」入口

- **触发**：点击 `.ex-tool[data-open-page="theme"]`。
- **状态变化**：同 2.1 页面导航。
- **可见反馈**：切到主题配置页。

### 3.11 图标轨降级（宽度 ≤96px）

- **触发**：`explorer.clientWidth <= 96`（`RAIL_MAX`），由 `ResizeObserver` 监听。
- **状态变化**：容器查询 `@container ex (max-width:96px)` 生效，仅改呈现不改数据。
- **可见反馈**：名称改为裁剪隐藏（**不是 `display:none`**，仍在无障碍树内）并同步为原生 `title` tooltip，拖宽后自动撤掉；折叠箭头与 `.ex-grip` 拖动柄 `display:none`；分组身份由图标色 + 活动行左侧强调条承担；页脚按钮转为纯图标并保留 `aria-label`；树区空态只留图标。

---

## 4. 工作台 · 新增连接与本地终端

### 4.1 新增连接下拉

- **触发**：点击顶栏或 Explorer 头部的「新增连接」按钮（共用 `#exAddBtn` / `#exAddMenu`）。
- **状态变化**：菜单 `hidden` 取反，同步 `aria-expanded`；全局同时只允许一个该菜单打开。
- **可见反馈**：三项固定菜单：**本地终端 / SSH / 隧道连接**。

### 4.2 菜单项分流

| 菜单项（`data-new`） | 状态变化 | 可见反馈 |
|---|---|---|
| `local` | `localSeq++`，新 id `local<N>`；写 `termContent[id]`；`ensureLocalSec()` 保证 `#localSec` 存在（不存在则重建、绑定握把与折叠、刷新编号与空态）；展开该块；追加 `.ex-row.local`；`createTab()` + `activateTab()`；`showPage('workbench')` | 新块/新行出现在 Explorer，`Local` 块自动展开，终端切到新终端，toast「已打开本地终端 local1」 |
| `ssh` | `showPage('connections')` + `openDrawer('ssh', false)` | 跳到连接配置页并弹出「新增 SSH 配置」抽屉 |
| `tunnel` | `showPage('tunnels')` + `openDrawer('tunnel', false)` | 跳到端口转发页并弹出「新增端口转发」抽屉 |

---

## 5. 工作台 · 终端标签与舞台

### 5.1 激活标签

- **触发**：点击 `.tab[data-tab]`（点关闭按钮 `.x` 不触发）。
- **状态变化**：`activateTab(id)` 同步标签条 `.active`、Explorer 行 `.active`，并按 `id` 取内容：优先 `#src-<id>` 模板，其次 `termContent[id]`。
- **可见反馈**：标签高亮 + 顶部 3px 赤陶条；终端区整体替换；溢出时标签条横向滚动使激活标签居中。

### 5.2 关闭标签

- **触发**：点击标签内 `.x`（`aria-label="关闭 <名称>"`）。
- **状态变化**：移除标签；**若关闭的是当前标签**，激活原位置的新邻居（`min(原索引, 剩余长度-1)`）；无标签时清空所有 Explorer 行的 `.active`。
- **可见反馈**：有邻居则切到邻居；一个不剩时终端区显示「没有活动的会话。请从左侧资源管理器打开一个终端。」

> 注意：关闭标签**只关标签**，Explorer 里的会话行仍在（会话依然"打开"）。要真正结束会话，用 3.8 的右键「关闭」。

### 5.3 空态

| 条件 | 可见反馈 |
|---|---|
| 标签条无标签 | 终端区单行提示「没有活动的会话。请从左侧资源管理器打开一个终端。」 |
| Explorer 无配置块 | 树区空态（3.7） |

---

## 6. 工作台 · 分栏与底部面板

### 6.1 三条分隔条

| 分隔条 | 方向 | 范围 | 默认 | 键盘 |
|---|---|---|---|---|
| `#sbSplit` | 水平拖动（Explorer ↔ 终端） | 56–560px | 280 | `←`/`→` 16px，`Home`/`End` 到端点 |
| `#dockSplit` | 垂直拖动（终端 ↔ 底板） | 96–420px | 280 | `↑`/`↓` 16px，`Home` 折叠、`End` 展开到 420 |
| `#dockVSplit` | 水平拖动（实时事件 ↔ 内存监控） | 260px ~ 容器宽−220px | 实测 | `←`/`→` 16px，`Home`/`End` 到端点 |

- **触发**：`pointerdown` 在分隔条上（非主键、点在 `button` 上时忽略）→ `setPointerCapture` → `pointermove` 实时改尺寸 → `pointerup` 写盘。
- **状态变化**：写 CSS 变量 `--sb-w` / `--dock-h` / `--dock-events-w`；同步 `aria-valuenow`（`aria-valuemin` / `aria-valuemax` 动态计算）；拖动中加 `.dragging`。
- **可见反馈**：两侧面板真实此消彼长（容器高度确定，不是 `min-height`）；分隔条 grip 变 `--accent` 并带 3px 光晕；`role="separator"` + `tabindex="0"`，键盘方向键与拖动等价。

### 6.2 底部面板自动折叠

- **触发**：拖 `#dockSplit` 使高度 < 96px（`DOCK_COLLAPSE_AT`）；或点击折叠条 `#dockFold`。
- **状态变化**：`dockCollapsed` 置位；`#bench` 的 `data-dock` 切 `collapsed`/`expanded`；`aria-expanded` 与 `#dockFoldText` 文案同步；写 `deepssh.dockCollapsed` 与 `deepssh.dockH`。
- **可见反馈**：折叠后底板只剩 37px 标题条，`#dockSplit` 一并退出布局（不留缝）；标题条文案在「收起下方面板 / 展开下方面板」间切换；反向拖动即按指针高度展开，不跳位。

### 6.3 实时事件 / 内存监控

- 两块各自内部滚动，互不影响。
- 事件流按时间倒序插在最前，等级用左侧 3px 竖条 + 等宽芯片表达（`data-lv="error"` 等），面板变窄时芯片隐藏而非溢出。
- 内存面板容器查询降级：<360px 隐藏「示例数据」，<290px 再隐藏「直播」徽标。
- 显隐由 3.9 的开关控制。

---

## 7. 连接配置页

### 7.1 搜索与筛选

- **触发**：`#connSearch` `input` 事件；`#authFilter` `change` 事件。
- **状态变化**：逐行计算可见性——关键词对 `data-name + " " + data-host` 做小写包含匹配；认证方式要求 `#authFilter.value === 'all'` 或等于行上的 `data-auth`（`password` / `key` / `agent`）；不满足则 `row.hidden = true`。
- **可见反馈**：命中行保留，其余直接消失；右上计数 `#connCount` 实时显示「命中 / 总数」（如 `2 / 6`）。

| 当前 | 触发 | 变化 | 可见反馈 |
|---|---|---|---|
| `6 / 6` | 搜索 `bastion` | 仅名称或主机含该词的行留下 | 计数变 `1 / 6` |
| 任意 | 筛选选「私钥」 | 只留 `data-auth="key"` 的行 | 计数同步 |
| 任意 | 筛选选「Agent」 | 只留 `data-auth="agent"` 的行（演示数据中为 `bastion`） | 计数同步 |
| 任意 | 两者同时生效 | 取交集（AND） | 计数为交集数量 |

### 7.2 连接

- **触发**：点击行内 `button[data-connect]`。
- **状态变化**：`showPage('workbench')`；toast 进入中；700ms 后确保 `terminal3` 标签存在（不存在则 `createTab('terminal3')`）并 `activateTab('terminal3')`。
- **可见反馈**：先「正在连接 prod-web-01…」，随后「prod-web-01 已连接」。

> 原型限制：演示用的固定会话，连接后统一激活 `terminal3`，未按被点的行区分；真实实现需按配置建立会话。

### 7.3 编辑

- **触发**：点击 `button[data-edit-ssh]`。
- **状态变化**：`openDrawer('ssh', true)`；标题改「编辑 SSH 配置」。
- **可见反馈**：抽屉从右侧滑入，提交按钮文案为「保存」（新增时是「创建」），toast「正在编辑 <名称>」。

> 原型限制：表单未按行预填，属演示态。

### 7.4 删除

- **触发**：点击 `button[data-delete="<名称>"]`。
- **状态变化**：`confirmDialog('删除配置', '将删除「X」，此操作不可恢复。', '删除', …)`；确认后移除整行 DOM。
- **可见反馈**：确认框（危险按钮 `#dlgConfirm`）；确认后 toast「已删除 <名称>」；取消则无任何变化。

> 已知缺口：删除配置行**不会**同步移除 Explorer 里对应的配置块——Explorer 分区只受"关闭最后一个会话"驱动（见 3.8）。开发需按业务口径补齐联动。

### 7.5 新增 / 编辑抽屉（SSH 与端口转发共用）

- **触发**：`button[data-open-drawer="ssh"|"tunnel"]`、行内编辑按钮，或顶栏菜单项（4.2）。
- **状态变化**：`drawerKind` 记录类型；`.drawer-body form` 按 `data-form` 只显示对应表单；`#drawerKicker` 切 `SSH Profile` / `Port Forwarding`；标题按类型与是否编辑组合；提交按钮 `创建` / `保存`；40ms 后聚焦当前表单第一个输入框。
- **认证方式联动**：`#sshAuth` `change` —— 三选一渐进披露：选「私钥」显示 `#sshKeyField`，选「Agent」显示 `#sshAgentField`（内含可留空的密钥标识 `#sshAgentKey`），选「密码」显示 `#sshPasswordField`，其余两组隐藏。同时 `#sshCredHint` 按 `SSH_CRED_HINTS[mode]` 切换文案（密码 / 私钥 / Agent 三套）。这是**渐进披露**，不是新弹窗。
- **提交校验**：点 `#drawerSubmit`，若名称为空（`#sshName` 或 `#tunName`）→ 聚焦该输入框 + toast「请先填写名称」，**不关闭抽屉**；有值则关闭抽屉、清空名称输入框、toast「已保存 SSH 配置 X」/「已保存端口转发 X」。
- **关闭路径**：`#drawerClose`、`#drawerCancel`、点遮罩、`Esc`。

---

## 8. 端口转发页

### 8.1 启停

- **触发**：点击 `button[data-tunnel-toggle]`。
- **状态变化**：行在 `.run` / `.off` 间切换；按钮文案在「停止 / 启动」间切换；`.r-name .badge` 的 class、圆点 class 与文案整体替换。
- **可见反馈**：badge 从「运行中 + 绿点」变「已停止 + 灰点」，反之亦然；toast「已启动转发 redis-6379」/「已停止转发 web-8080」。

| 当前 | 触发 | 行状态 | 按钮 | badge | toast |
|---|---|---|---|---|---|
| `.run` | 点开关 | `.off` | 启动 | 已停止 | 已停止转发 X |
| `.off` | 点开关 | `.run` | 停止 | 运行中 | 已启动转发 X |

### 8.2 编辑 / 删除 / 新增

- 编辑：`button[data-edit-tunnel]` → `openDrawer('tunnel', true)`，标题「编辑端口转发」。
- 删除：`button[data-delete="<名称>"]` → 与 7.4 同一个确认对话框 → 移除行 + toast「已删除 <名称>」。
- 新增：页头 `button[data-open-drawer="tunnel"]` → `openDrawer('tunnel', false)`。

---

## 9. 主题配置页 · 预设方案下拉

界面主题与终端主题两栏结构完全一致，只是 `data-presets="ui|term"` 不同。触发点：`[data-preset-toggle]`（通栏触发器）、`[data-preset-menu]`（展开列表）、`[data-preset-list]`（列表容器）、`[data-preset-add]`（末位新建）、`[data-preset-restore]`（恢复入口）、行内 `.psel-del[data-preset-del]`、行本体 `.psel-pick[data-pid]`。

### 9.1 展开与收起

- **触发**：点击触发器；或点击 `[data-presets]` 外部；或 `Esc`；或 `Tab`。
- **状态变化**：全局只允许一个预设菜单打开（`openPresetMenu`），打开新菜单会先关旧菜单；触发器 `aria-expanded` 同步。
- **可见反馈**：展开后焦点落在**当前选中行**（`pselFocusFirst`）；收起时焦点交还触发器。

### 9.2 选中方案

- **触发**：点击 `.psel-pick`。
- **状态变化**：`applyPreset(kind, pid)` 写 `PRESET_SEL[kind]` → 同步触发器与各行选中态；**若 kind=`term` 且选中的是内置方案**，整体替换规则列表（`deck` → 7 条默认规则；`one` / `solar` → 空列表）；若是**自定义**方案则**不动**规则列表（自定义方案保存的就是当前规则）。
- **可见反馈**：选中行加左侧 3px 竖条并置 `aria-checked="true"`（其余 `tabIndex=-1`）；触发器更新色块 + 方案名，自定义方案额外显示「自定义」标签；菜单收起、焦点回触发器；toast「终端主题已切换为 One Dark，高亮规则共 0 条」。

### 9.3 删除方案（行内删除按钮）

- **触发**：点击行内 `.psel-del[data-preset-del]`（`aria-label="删除方案 X"`）。
- **状态变化**：
  - **自定义方案** → 从 `deepssh.<kind>Presets` 数组中真正移除；
  - **内置方案** → 把 id 追加进 `deepssh.<kind>HiddenPresets`（只是隐藏，不动内置定义）；
  - 若删掉的正是当前选中项 → 自动切到剩余列表的第一项；一项不剩则 `PRESET_SEL[kind] = null`。
- **可见反馈**：该行立即从列表消失；`title` 区分「删除此自定义方案」/「从列表中移除此内置方案」；toast 组合三段信息，例如「已删除方案「Solarized」，可从「恢复内置方案」取回，已切换到「One Dark」」；删空整栏时列表区显示「暂无方案，可从下方新建。」；焦点移到当前选中行。

### 9.4 新建自定义方案（末位 ＋）

- **触发**：点击 `[data-preset-add]`。
- **状态变化**：以**当前面板设置**为蓝本追加一项，名称 `自定义方案 <自定义数量+1>`，写入 `deepssh.<kind>Presets` 末尾，并立即选中。
- **可见反馈**：列表底部出现新行（带「自定义」标签）+ 删除按钮；触发器切到新方案并显示「自定义」标签；toast「已把当前设置存为「自定义方案 1」」；焦点落在新行。

### 9.5 复制方案（行右键）

- **触发**：在 `.psel-pick` 上 `contextmenu` → 复用右键菜单，只有「复制方案」一项。
- **状态变化**：名称按 `copyName()` 递增后缀（`X` → `X 副本` → `X 副本 副本`，**不叠加同级后缀**）；落位规则——**复制自定义方案插在源项之后**，**复制内置方案插在自定义区块头部**（即内置组之后）；写入存储并立即选中。
- **可见反馈**：新行出现在源项下方、名称以「副本」结尾、继承源项色块；toast「已复制「Command Deck」为「Command Deck 副本」」；焦点落在新行。

### 9.6 恢复内置方案

- **触发**：点击 `[data-preset-restore]`。
- **状态变化**：清空 `deepssh.<kind>HiddenPresets`；若当前选中项已不存在，回落到第一个内置方案；重渲染列表。
- **可见反馈**：入口**仅在有被隐藏方案时出现**，文案带数量「恢复内置方案（2）」；点击后被删的内置方案回到列表，toast「已恢复 2 个内置方案」。

### 9.7 键盘导航

| 按键 | 行为 |
|---|---|
| `↑` / `←` | 上一个可聚焦项（循环） |
| `↓` / `→` | 下一个可聚焦项（循环） |
| `Home` / `End` | 跳到首项 / 末项 |
| `Esc` | 收起菜单，焦点交还触发器 |
| `Tab` | 收起菜单，焦点自然外移 |

焦点序列 = 方案行 → 行内删除按钮 → … → 「＋ 新建自定义方案」→ （可见时）「恢复内置方案（N）」。

---

## 10. 主题配置页 · 正则高亮规则

规则数据：`rxRules`，每项 `{ p: 正则, n: 备注, c: 颜色 }`。**列表顺序即优先级**：从上到下逐条匹配，同一处命中先到者着色，被覆盖的片段不再二次着色。

### 10.1 行内编辑

- **触发**：在 `input[data-k="p"|"n"]` 输入。
- **状态变化**：立即写回 `rxRules[i][k]`，无防抖；同时重绘预览 `#termPreview`。
- **可见反馈**：预览区对应文本按新规则着色；非法正则静默跳过、不报错。

### 10.2 拖动改优先级

- **触发**：在 `.rx-grip` 上 `pointerdown`（仅主键）。
- **状态变化**：握把 `setPointerCapture`；行加 `.dragging` 并跟随指针 `translateY`；插入虚线落位框 `.rx-shade`。
- **可见反馈**：行浮起（白底 + 硬阴影），虚线框落在目标槽位；松手后重排、`data-i` 重编号、焦点落到新位置的握把，toast「已把「错误日志」移到第 2 位」。

### 10.3 键盘排序

- **触发**：`.rx-grip` 聚焦时 `Alt` / `Ctrl` / `⌘` + `↑` / `↓`。
- **可见反馈**：同 10.2 落位后的表现。

### 10.4 取色器

- **触发**：点击 `.rx-color-btn[data-hex]`。
- **状态变化**：展开 `.rx-pop`：原生取色控件 + Hex 文本输入（6 位，非法值忽略并保持原值）+ 7 个预设色板（`RX_SWATCHES`）。任何一次改动都写回 `rxRules[i].c`，并同步行内色块与 Hex 文本、重绘预览。
- **可见反馈**：按钮 `aria-expanded` 切换；点外部或 `Esc` 收起。

### 10.5 增删

- **触发**：点 `.rx-del` 删除该行；点 `#addRule` 追加。
- **状态变化**：删除即从 `rxRules` 移除并整体重渲染（编号重排）；追加项为 `{p:'', n:'', c:'#FFFFFF'}`，随后聚焦新行的正则输入框。
- **可见反馈**：删除 toast「已移除规则「错误日志」」；追加 toast「已添加一条空规则」。

### 10.6 空态

| 条件 | 可见反馈 |
|---|---|
| `rxRules` 为空 | `#rxEmpty` 显示：「当前预设没有高亮规则」+ 说明 One Dark / Solarized 的 `regexHighlights` 为空列表、按从上到下匹配；预览区无着色 |
| `rxRules` 非空 | `#rxEmpty` 隐藏，列表正常渲染 |

> 切换终端预设会**整体替换**规则列表（不是合并），因为源码里 `_updateTerm(preset)` 换掉的是整个设置对象。

---

## 11. 状态迁移总表

| 状态 | 载体 | 初值 | 谁会改 | 可见反馈锚点 |
|---|---|---|---|---|
| 当前页面 | `deepssh.page` + `.page[hidden]` | `workbench` | `data-page` / `data-open-page` | 导航按钮 `aria-current` |
| 激活会话 | `.tab.active` + `.ex-row.active` | `terminal3` | 点会话行 / 点标签 / `openSession()` | 标签顶部赤陶条、终端内容、Explorer 行底色 |
| Explorer 配置块集合 | `.ex-sec` 列表 | 3 块（prod-web-01 / staging-db / Local） | 关闭会话、新建本地终端 | 树区结构变化、空态 |
| 配置块顺序 | DOM 顺序 | prod-web-01 → staging-db → Local | 拖动柄 / `Alt+↑↓` | toast + 握把编号 |
| 块内会话顺序 | `.ex-items` 内 DOM 顺序 | 源码顺序 | 会话握把 / `Alt+↑↓`（限本块内） | toast + 握把编号 |
| 配置块折叠 | `.ex-sec.collapsed` | 全部展开 | 点标题 | 箭头旋转、`.ex-items` 隐藏 |
| Explorer 宽度 | `--sb-w` | 280 | `#sbSplit` | `aria-valuenow` |
| 底板高度 / 折叠 | `--dock-h` / `data-dock` | 280 / 展开 | `#dockSplit`、`#dockFold` | 标题条 37px |
| 内存面板显隐 | `data-mem` + `deepssh.memHidden` | 显示 | `#exMemToggle` | 按钮 `aria-pressed`、事件面板铺满 |
| 事件面板宽度 | `--dock-events-w` | 实测 | `#dockVSplit` | `aria-valuenow` |
| 连接列表可见性 | `.row[hidden]` | 全部可见 | `#connSearch`、`#authFilter` | `#connCount` |
| 转发运行态 | `.row.run` / `.row.off` | 2 运行 1 停止 | `data-tunnel-toggle` | 按钮文案 + badge |
| 当前预设 | `PRESET_SEL` | `ui:deck` / `term:deck` | `.psel-pick`、删除回落、新建、复制 | 触发器色块 + 名称 + 标签 |
| 预设可见集合 | 存储数组 | 2 内置（ui）/ 3 内置（term） | 删除、恢复、新建、复制 | 列表行数、空态、恢复入口 |
| 正则规则 | `rxRules` | 7 条（Command Deck） | 编辑、拖动、增删、取色、切换终端预设 | 预览着色、列表结构 |
| 抽屉 / 对话框 | `hidden` | 全部关闭 | 各触发点 | 遮罩 + 面板 |

---

## 12. 已知边界与未接线项（开发须知）

原型是演示态，以下位置**只有反馈、没有真实状态**，实现时不要照抄：

| 位置 | 现状 | 说明 |
|---|---|---|
| 实时事件流 | 静态 DOM | 无新增、无过滤、无滚动加载 |
| 内存监控读数 / 顶栏脉冲 | 静态「示例数据」 | 落地接 `mem_metrics.rs` 真实源 |
| 终端输出内容 | 写死的 `<template>` + 字符串 | 无真实 PTY、无输入 |
| 「连接」按钮 | 700ms 延时后统一激活 `terminal3` | 未按配置区分会话 |
| 「最近使用」列 | 写死的演示时间戳 | 源码 `SshProfileItem` 无该字段，落地需加 `last_connected_at` 并重新生成 frb，写入时机＝连接成功 |
| Agent 认证 | 筛选与抽屉的可选项，演示数据 `bastion` 使用 | 源码 `SshAuthMode` 仅 `password` / `privateKey`，落地需扩展 Rust 侧枚举 |
| 编辑抽屉 | 打开但不预填、不校验除名称外字段 | 无表单回填、无错误内联提示 |
| 会话行的 ARIA 嵌套 | `.ex-row` 是 `role="button"`，内部又嵌了原生 `<button>`（`.ex-sgrip`、`.ex-x` 都有这个问题） | 交互可用，但交互元素嵌套不合规；落地建议行改用 `role="treeitem"`，或把握把与关闭动作承载在非 button 元素上 |
| 连接配置删除 | 只删列表行 | 不同步移除 Explorer 配置块与已打开会话 |
| 分区顺序 / 块内会话顺序 / 折叠态 | 仅内存 | 落地需写回配置列表与会话列表的排序字段并持久化 |
| 当前选中预设 | 仅内存 | 刷新回到 `deck` |
| 正则规则 | 仅内存 | 落地写 `theme.rs` 的 `regex_highlights` |
| 终端配色 4 色板、光标样式下拉、光标闪烁 | 静态展示，无事件绑定 | 源码有 5 个 `_ColorField`（含选区色），需补 |
| 正则合法性校验 | 未做 | 非法表达式静默跳过 |
| 分隔条拖动 | 无 `scrollIntoView` | 嵌入式预览下会破坏布局，落地保持 Pointer Events 方案 |
