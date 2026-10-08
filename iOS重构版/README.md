# AERTEX iOS 原生应用（2.0.1）

**AERTEX 是主 App，「是否认同」只是其中的一个附属功能。** 本工程从原有「是否认同」SwiftUI iOS 版本升级而来，保留原先的剧情与本地数据模型，重新建立顶层产品结构。

## 应用结构

| 底部标签 | 原生页面 | 实际能力 |
| --- | --- | --- |
| 首页 | AERTEXHomeView | 欢迎页、主站服务卡片、内置功能入口 |
| 服务 | AERTEXServicesView | 访问 Studio、Work、Intelligence、Watch 的官方网页 |
| 我的 | AERTEXHubView | AERTEX ID 信息、登录会话、主站强调色、同步与退出 |

「是否认同」不占用一级底部标签，而从首页「我的应用」或服务页「内置应用」打开全屏原生模块，保留返回 AERTEX 的入口。登录首先进入 `AERTEXLoginView`，验证成功后才进入 `AERTEXRootView`。全局使用原生 SwiftUI、iOS 26 Liquid Glass（低版本 Material 回退），强调色由 AERTEX ID 账户 `accentId` 决定，浅深模式跟随 iOS 系统。

## 技术约束

- 认证接口由 `auth.qsseda.com` 提供：`/api/app/login`、`refresh`、`session`、`logout`。
- iPhone 是原生 API 客户端，不在本机开设公网 API。
- 暂无已核实的 Studio/Work/Intelligence/Watch 移动业务 API，因此它们在当前版本以**明确标记的网页入口**提供，不伪装成原生 API。
- 原有「是否认同」功能（2023-06-19 锚点、1.05 倍、99 位上限、剧情历史、对数图、汇率）保持可用。
- 历史、签到、成就、金额设置仍属于本机数据，不上传到云端。
- `CFBundleDisplayName` 已更新为 AERTEX（2.0.0）；暂时保留 `com.tglab.shifourentong.ios` Bundle ID、Swift Package target/xtool product 名及既有图标资源，避免破坏原设备的数据迁移与现有编译配置。外部名称与内部工程标识可能不一致。

## 构建与验收

现有 `xtool.yml` 与 `Package.swift` 仍供原工作流使用；生成的 IPA 如果未签名仍需 Apple 开发签名才能安装真机。

在合并前必须使用 Apple SDK 实际编译、安装，并检查启动、四个底部标签、登录与断网重连、主站配色、系统深浅色及游戏本地数据迁移。此 GitHub 分支尚未完成 Apple 真机验收。

## 2.0.1 原生接口迭代

- 「我的」页面提供真正的原生显示名称编辑表单（非 WebView）。
- `AERTEXAuthStore.updateDisplayName` 通过 `PATCH /api/app/profile` 更新自己账户的资料；访问令牌过期时尝试刷新后重试。
- **配套依赖：** `qssed.studio` Auth Worker 需首先发布新的 `/api/app/profile` 路由；上线前验证数据库 RLS、账号状态和同步结果。
- 界面仍保留独立网站服务入口，尚未把 Work、Watch、Intelligence 的业务页面伪装成原生功能。

## 2.1.0 原生服务接入（新增）

AERTEX 的「首页」和「服务」页现在可直接打开三个 SwiftUI 服务页面：

- **Studio**：云端项目/任务与个人工作台计数（`GET /api/native/studio/overview`）。
- **Intelligence**：云端会话列表、单个会话的消息记录（`GET /api/native/intelligence/conversations`）。暂无原生发送消息能力。
- **Watch**：已同步的电脑 ActivityWatch 数据源数、最近同步时间及电脑名称（`GET /api/native/watch/status`）；不代表 Apple Watch 或 Health 数据。
- **Work**：尚未提供受信任的原生业务接口，仍明确标示为 Safari 网页入口，不使用 WebView。
- **是否认同**：继续作为应用内可退出的附属模块，不改变本地存档与 Bundle ID。

原生客户端复用 AERTEX ID Keychain refresh token 和内存里的 access token。新增服务 API 必须先在后端生产环境上线，然后才能发布/安装此版本。本次改动尚需 xtool 在 Omarchy 的 SwiftUI SDK 编译和 iPhone 真机验证。
