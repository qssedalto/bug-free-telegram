# AERTEX iOS 应用架构

## 定位（2026-10-08 调整）

主产品是独立的 **AERTEX iOS App**，不是以「是否认同」为主界面的客户端或换皮 App。「是否认同」是 AERTEX 内部的**单独功能模块**，可以从首页卡片或底部标签进入。欢迎页、服务目录、账户中心及主题体系由 AERTEX 统一管理。

应用仅作为 AERTEX 服务 API 的客户端，不在 iPhone 上运行公网 API 服务。

## 已验证的原生账户 API

- `POST https://auth.qsseda.com/api/app/login`
- `POST https://auth.qsseda.com/api/app/refresh`
- `GET https://auth.qsseda.com/api/app/session`
- `POST https://auth.qsseda.com/api/app/logout`

账户响应 `accentId` 决定强调色，过浅/过深颜色使用安全的控件对比色衍生值。刷新令牌仅存 iOS Keychain，访问令牌仅保留在进程内存中。网络超时不应误删本地刷新令牌。

## 全新页面结构

```
AERTEX (iOS 主应用)
├─ 首页 AERTEXHomeView
│  ├─ 账户欢迎语
│  ├─ 服务入口（网页，清晰标注）
│  └─ 是否认同快捷入口
├─ 服务 AERTEXServicesView
│  ├─ Studio (qsseda.com)
│  ├─ Work (work.qsseda.com)
│  ├─ Intelligence (gpt.qsseda.com)
│  └─ Watch (aw.qsseda.com)
├─ 是否认同 ContentView
│  ├─ 三分支剧情、成就、历史
│  ├─ 数据面板
│  └─ 模块专属设置
└─ 我的 AERTEXHubView
   ├─ 账户资料、连接状态、退出
   ├─ 会话与强调色同步
   └─ 账户中心、主题外观链接
```

已有「是否认同」的业务逻辑和 `RuntimeStore` / `AppPreferences` 数据键不迁移、不重置，避免旧装机用户丢失进度。外部 App 名改为 AERTEX 2.0.0，内部 Bundle ID、模块目录、工具链 product 暂留原名以保留升级兼容性。

## 当前边界与验收

Studio、Work、Intelligence、Watch 尚无已经核实的面向本 App 的业务 API；入口是**打开已知官网链接**，并非已经做到各产品的原生功能对接。没有新增云端同步，也不调用猜测接口。

此前的「App 设置」已经分离为「是否认同设置」；颜色只能从 AERTEX 主站改变，iOS App 同步账户主题色，浅深色跟随设备系统。

完成前必须 Apple SDK 编译、真机验证、登录/刷新/退出/失效 token、断网重连、布局与本地数据迁移。尚未进行真机编译或部署，合并需验收。
