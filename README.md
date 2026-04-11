# luci-app-adguardhome

复杂的 AdGuard Home 的 OpenWrt LuCI 管理界面

## 修改记录

### 2026-04-11

- **修复 LuCI ucode 兼容性问题**：`manual.lua` 和 `base.lua` 中的 `redirect` 方法调用
  - **问题**：OpenWrt 25.12+ (APK) 使用 ucode 替代传统 Lua CGI，`self.map:redirect()` 方法不可用
  - **修复**：将 `self.map:redirect()` 改为 `luci.http.redirect()`
  - **涉及文件**：
    - `luasrc/model/cbi/AdGuardHome/manual.lua:65`
    - `luasrc/model/cbi/AdGuardHome/base.lua:153,161`

- **防火墙 DNS 重定向 - 多 IP 支持优化**：重构 `set_iptables_fw3()` 和 `set_iptables_fw4()` 函数
  - **原因**：原实现只获取一个 LAN 接口的第一个 IP，对于多接口或多 IP 场景支持不足
  - **改进**：使用 `ifconfig` 获取**所有** LAN IPv4/IPv6 地址，为每个 IP 添加单独的 DNAT 规则
  - **规则示例**：
    ```
    nft add rule inet fw4 dstnat ip daddr 10.0.0.1 udp dport 53 redirect to :1745 comment "AdGuardHome"
    nft add rule inet fw4 dstnat ip6 daddr 240e:3b0:xxxx udp dport 53 redirect to :1745 comment "AdGuardHome"
    ```
  - **清除规则同步更新**：使用 handle 删除方式清理带有 "AdGuardHome" 注释的残留规则
  - **保留客户端来源 IP**：DNAT 方式使 AdGuardHome 查询日志可显示真实客户端 IP（127.0.0.1 来源为 dnsmasq 转发）

### 2026-04-10

- **防火墙 DNS 重定向来源 IP 保留**：重构 `set_iptables_fw3()` 和 `set_iptables_fw4()` 函数，从原来的 `REDIRECT` 方式改为 `DNAT` 方式
  - **原因**：`REDIRECT` target 会将目标地址改成 `127.0.0.1`，导致 AdGuardHome 收到的所有请求来源显示为 `127.0.0.1`
  - **FW4 方案**：使用 nftables 在 `inet fw4 dstnat` 链中添加 DNAT 规则
  - **FW3 方案**：兼容 nftables 和 iptables，优先使用 DNAT 方式
  - **清除规则**：正确清理残留规则
  - **注意**：如果无法获取 LAN IP，会回退到 `REDIRECT`

### 2026-04-09（后续）

- **基础设置**：将原先 `optional = true` 的 CBI 项改为 `optional = false`（并对 `upprotect`、`crontab` 增加 `rmempty = true`），避免 LuCI 把 GFW / 密码 / 升级保留 / 计划任务等收进「-- 更多选项 --」下拉，改为与页面其它项一样默认全部展开
- **代码检阅修复**：补全所有 SVG 内联 `width`/`height` 属性（`log.htm`、`AdGuardHome_check.htm`、`AdGuardHome_chpass.htm`）；补全 `po/zh-cn/AdGuardHome.po` 中 13 个缺失的中文翻译（sessions.db、stats.db、filters、YAML Editor、Reload、Reverse Order、Local Time、Download、Clear Log、Are you sure...、No log available、Not Redirect、Loading...）
- 恢复「网页管理端口」下方的 **打开 AdGuard Home 网页后台** 跳转按钮（与配置的 `httpport` 一致）
- 修正主内容区样式未生效问题：在页面加载时为 `.cbi-map` 增加 `adguardhome-luci-page` 类名，并优化标题、说明、表单卡片与左右分栏排版
- 状态区增加服务 / DNS 重定向徽章展示
- **核心更新按钮**：彻底重构 `AdGuardHome_check.htm`，解决 SVG 图标被 LuCI 全局样式撑满的问题；增加 Toast 提示（检查中 / 已更新 / 检查错误），日志区独立渲染
- **日志页面**：同步更新 `log.htm`，统一 SVG 图标尺寸与按钮样式
- **密码页面**：同步更新 `AdGuardHome_chpass.htm`，修正图标比例，简化哈希计算流程提示
- 所有 SVG 图标统一加 `!important` 强制固定为 18px / 16px，防止被全局 LuCI 主题覆盖
- **手动设置页**：`yamleditor.htm` 曾用 `svg { max-width:100% }`，在宽屏 `.cbi-value` 下会把文档图标撑满整行；已去掉该规则并增加 `AdGuardHome_manual_shell.htm`（提前注入 `.adguardhome-luci-page` 与 SVG 尺寸兜底），工具栏 SVG 增加 `width`/`height` 与内联样式

### 2026-04-09

#### Web 界面 Apple 风格改造

- 采用卡片式模块化布局，所有设置项默认展开可见
- Apple 设计风格：
  - SF Symbols 风格 SVG 图标
  - 蓝紫色渐变卡片标题
  - 圆角设计（12px/16px）
  - 柔和阴影
  - 深色模式自动适配
- 11 个功能分组卡片：
  1. 状态卡片 - 运行状态/版本信息
  2. 基础设置 - 启用/端口/重定向
  3. 核心管理 - 二进制/工作目录/配置
  4. 核心更新 - 版本检查/一键更新
  5. GFW 列表 - 上游 DNS/列表管理
  6. 安全设置 - Web 密码
  7. 日志配置 - 日志路径/详细日志
  8. 数据管理 - 升级保护/备份
  9. 定时任务 - Crontab 任务
  10. 网络设置 - 启动等待
  11. 自定义下载 - 下载链接
- 改造的文件：
  - `base.lua` - 重构为分组卡片结构
  - `manual.lua` - 适配新卡片样式
  - `AdGuardHome_status.htm` - Apple 风格卡片 CSS
  - `AdGuardHome_check.htm` - Apple 风格更新按钮
  - `AdGuardHome_chpass.htm` - Apple 风格密码计算器
  - `log.htm` - Apple 风格日志查看器
  - `yamleditor.htm` - Apple 风格 YAML 编辑器

---

#### View 模板路径迁移

- 将 View 模板文件从 `luasrc/view/AdGuardHome/` 迁移到 `htdocs/luci-static/resources/view/AdGuardHome/`
- 适配 OpenWrt 25.12+ 新版 LuCI 的文件结构
- 迁移的文件列表：
  - `AdGuardHome_check.htm` - 更新核心版本页面
  - `AdGuardHome_chpass.htm` - 修改密码页面
  - `AdGuardHome_status.htm` - 状态显示页面
  - `log.htm` - 日志查看页面
  - `yamleditor.htm` - YAML 编辑器页面

#### 静态资源整理

- 将 CodeMirror 编辑器相关资源整合到 `htdocs/luci-static/resources/codemirror/`
- 将 bcrypt 加密库整合到 `htdocs/luci-static/resources/`

#### 架构检测修复

- `update_core.sh` 添加 `x86_64` 架构支持
- 修复使用 `uname -m` 时返回 `x86_64` 无法识别的问题
- 同时修复 `doupx()` 和 `doupdate_core()` 两个函数的架构检测

#### 目录结构更新

- 新版目录结构使用 `htdocs/` 目录存放静态资源和视图模板
- 兼容 OpenWrt 24.10 (opkg) 和 OpenWrt 25.12+ (APK) 两种包管理器

---

## 特性

 - 网页管理端口配置
 - LuCI 下载/更新核心版本（支持自定义链接下载）
   - 如果为 tar.gz 文件需要与官方的文件结构一致
   - 或者直接为主程序二进制
 - UPX 压缩核心（xz 依赖，脚本自动下载）
 - DNS 重定向
   - 作为 dnsmasq 的上游服务器
   - 重定向 53 端口到 AdGuard Home
   - 使用 53 端口替换 dnsmasq
 - 自定义执行文件路径（支持 tmp，每次重启后自动下载 bin）
 - 自定义配置文件路径
 - 自定义工作路径
 - 自定义运行日志路径
 - GFWList 删除/添加/定义上游 DNS 服务器
 - 修改网页登陆密码（支持 bcrypt 加密）
 - 倒序/正序 查看/删除/备份运行日志 + 本地浏览器时区转换
 - 手动修改配置文件
   - 支持 CodeMirror YAML 编辑器
   - 模板快速配置
 - 系统升级保留勾选文件
 - 开机启动后当网络准备好时重启（3 分钟超时）
 - 关机时备份勾选的工作目录中的文件
 - 计划任务
   - 自动更新核心（3:30/天）
   - 自动截短查询日志（每小时，限制到 2000 行）
   - 自动截短运行日志（3:30/天，限制到 2000 行）
   - 自动更新 IPv6 主机并重启（每小时）
   - 自动更新 GFWList 并重启（3:30/天）

## 兼容性

### OpenWrt 版本

| 版本 | 包管理器 | 状态 |
|------|----------|------|
| OpenWrt 24.10 及更早版本 | opkg | ✅ 支持 |
| OpenWrt 25.12+ | APK | ✅ 支持 |

### 防火墙版本

| 防火墙 | 版本 | 状态 |
|--------|------|------|
| Firewall v3 (fw3) | OpenWrt 19.07 - 21.02 | ✅ 自动检测 |
| Firewall v4 (fw4) | OpenWrt 22.03+ | ✅ 自动检测 |

项目会自动检测系统防火墙版本并选择合适的 DNS 重定向方式。

### 目录结构

```
luci-app-adguardhome/
├── Makefile                           # OpenWrt 包编译配置
├── htdocs/
│   └── luci-static/resources/
│       ├── view/AdGuardHome/         # View 模板
│       │   ├── AdGuardHome_check.htm
│       │   ├── AdGuardHome_chpass.htm
│       │   ├── AdGuardHome_status.htm
│       │   ├── log.htm
│       │   └── yamleditor.htm
│       ├── codemirror/               # YAML 编辑器
│       └── twin-bcrypt.min.js        # 密码加密
├── luasrc/
│   ├── controller/AdGuardHome.lua    # LuCI 控制器
│   └── model/cbi/AdGuardHome/       # CBI 模型
│       ├── base.lua
│       ├── log.lua
│       └── manual.lua
├── root/
│   ├── etc/
│   │   ├── config/AdGuardHome        # UCI 配置
│   │   ├── init.d/AdGuardHome       # 启动脚本
│   │   └── uci-defaults/            # 初始化脚本
│   └── usr/share/AdGuardHome/       # 共享脚本
│       ├── AdGuardHome_template.yaml
│       ├── addhost.sh
│       ├── firewall.start
│       ├── gfw2adg.sh
│       ├── getsyslog.sh
│       ├── tailto.sh
│       ├── update_core.sh
│       ├── waitnet.sh
│       └── watchconfig.sh
└── po/zh-cn/AdGuardHome.po          # 简体中文翻译
```

## 使用方法

### APK 安装（OpenWrt 25.12+）

```bash
apk add luci-app-adguardhome
```

### OPKG 安装（OpenWrt 24.10 及更早版本）

```bash
opkg install luci-app-adguardhome_*.ipk
```

### 编译集成

```bash
# 克隆到 OpenWrt 源码目录
git clone https://github.com/rufengsuixing/luci-app-adguardhome.git package/luci-app-adguardhome

# 或者添加到 feeds
echo "src-git AdGuardHome https://github.com/rufengsuixing/luci-app-adguardhome.git" >> feeds.conf.default
./scripts/feeds update -a
./scripts/feeds install -a

# 编译
make menuconfig  # 选择 LuCI -> Applications -> luci-app-adguardhome
make -j$(nproc)
```

## DNS 重定向模式说明

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| 无 | 不进行 DNS 重定向 | 仅管理 AdGuard Home |
| 作为 dnsmasq 上游 | 将 AdGuard Home 作为 dnsmasq 的上游 | 与其他代理插件配合（如 ssr-plus） |
| 重定向 53 端口 | 将所有 53 端口流量重定向到 AdGuard Home | 完整 DNS 过滤 |
| 替换 dnsmasq | 使用 53 端口替换 dnsmasq | 完全替代 dnsmasq |

## 已知问题

 - DB 数据库不支持不支持 mmap 的文件系统（如 jffs2、data-stk-oo），请修改工作目录到支持 mmap 的文件系统
 - AdGuard Home 不支持 ipset，如需与 ipset 配合使用，只能作为 dnsmasq 上游
 - 如果发现大量来自 127.0.0.1 的 localhost 查询，可能是 DDNS 插件导致，可删除或注释 `/etc/hotplug.d/iface/95-ddns`

## 关于 UPX 压缩

在压缩文件系统（如 jffs2）上使用 UPX 压缩：

| 指标 | 未压缩 | UPX 压缩后 | 差异 |
|------|--------|------------|------|
| 文件大小 | 14112 KB | 5309 KB | -8793 KB |
| 实际占用 | 6260 KB | 5324 KB | -936 KB |
| VmRSS 运存 | 14380 KB | 18496 KB | +4116 KB |

UPX 压缩以运存空间换取 ROM 空间，压缩文件系统收益较小，非压缩文件系统收益较大。

## 与 SSR Plus 配合

 - **方法一**：DNS 重定向 → 作为 dnsmasq 上游服务器
 - **方法二**：DNS 重定向 → 使用 53 端口替换 dnsmasq，将 AdGuard Home 上游 DNS 设为 `127.0.0.1:[代理端口]`
 - **方法三**：DNS 重定向 → 重定向 53 端口，AdGuard Home 上游 DNS 设为 `127.0.0.1:53`
 - **方法四**：任意重定向方式 + GFWList + 自动更新

---

## English

### luci-app-adguardhome

Complex OpenWrt LuCI management interface for AdGuard Home.

### Features

 - Web management port configuration
 - Download/update core in LuCI
 - UPX compress core
 - DNS redirect
   - As upstream of dnsmasq
   - Redirect port 53 to AdGuard Home
   - Replace dnsmasq with port 53
 - Custom bin/config/work/log paths
 - GFWList management
 - Password encryption (bcrypt)
 - Log viewing with timezone conversion
 - Manual config with CodeMirror YAML editor
 - System upgrade file preservation
 - Boot wait for network
 - Workdir backup on shutdown
 - Cron tasks

### Compatibility

 - OpenWrt 24.10 and earlier (opkg)
 - OpenWrt 25.12+ (APK)
 - Firewall v3 (fw3) and v4 (fw4)

### Usage

```bash
# OpenWrt 25.12+
apk add luci-app-adguardhome

# OpenWrt 24.10 and earlier
opkg install luci-app-adguardhome_*.ipk
```

### Screenshots

![Base Settings](https://user-images.githubusercontent.com/22387141/71361626-81d60900-25ce-11ea-91d5-ac4e35d5c41e.png)
![Status](https://user-images.githubusercontent.com/22387141/71361650-90242500-25ce-11ea-9727-9306a3da1357.png)
![Log](https://user-images.githubusercontent.com/22387141/71361700-b944b580-25ce-11ea-8562-f68c28952b2b.png)
![Manual Config](https://user-images.githubusercontent.com/22387141/71361704-bb0e7900-25ce-11ea-8042-6dd396607030.png)
