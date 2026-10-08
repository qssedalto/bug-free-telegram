# AERTEX ×「是否认同」iOS 集成说明

## 定位

「是否认同」iOS App 是 AERTEX 的原生客户端，不应在 iPhone 上开启公网 HTTP API 服务。现有 AERTEX ID 服务位于 `https://auth.qsseda.com`。

## 已有服务端契约（不修改线上服务端）

- `POST /api/app/login`：邮箱与密码登录，返回 token 和账户资料。
- `POST /api/app/refresh`：轮换刷新令牌。
- `GET /api/app/session`：通过 Bearer access token 获取当前账户资料。
- `POST /api/app/logout`：退出。
- 账户资料中的 `accentId` 用来同步主站强调色。

目前没有公开且核实过的原生 App 资料编辑、剧情保存或任意站内业务 API；这些功能不得通过猜测端点实现。

## 本次 UI 集成

- 顶部增加 AERTEX 账户入口，显示用户、连接状态、最近同步时间。
- 设置增加「账户与服务中心」入口；主题继续以主站账户色为准。
- 支持从原生页面同步会话与颜色、前往主站、账户中心和主题外观页面。
- 断网或服务端暂时故障时，刷新令牌保留在 iOS Keychain；不会因瞬时网络错误被删除。
- 额外提供登录页的恢复会话入口。
- 不修改「是否认同」原有三分支剧情、金额计算、本地历史。
- 遵循项目现有 iOS 26 Liquid Glass，低版本继续走现有 Material fallback。

## 待上线前验证

1. 用 xtool / Xcode 编译并安装到真机，排查 Swift 编译与运行时问题。
2. 测试：首次登录、杀进程恢复、token 过期后的刷新、退出、断网重试、失效 token。
3. 测试：主站调整主题色 → App 重新打开/点击同步 → 全界面主题一致。
4. 测试：深浅模式、辅助功能大字体、iPhone 竖屏和横屏、键盘与弹窗叠加。
5. 评估正式切换系统浏览器 + OAuth 2.0 PKCE。原生输入 AERTEX 账户密码虽为现有受支持的第一方方案，但不应给第三方应用复用。

> 该分支未在 Apple SDK 环境完成编译、签名或真机部署，也未更改后端。合并前需要完成真机验收。
