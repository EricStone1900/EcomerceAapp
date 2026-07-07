# EcommerceAppDemo — 项目架构

> 基于 Clean Architecture 的 iOS 电商应用，使用 Swift Package Manager 模块化组织

```

MyEcommerceAppDemo/
│
├── MyEcommerce/                          # App Entry（主应用 Target）
│   ├── MyEcommerceApp.swift              # @main 入口，注册所有依赖 + 路由导航
│   ├── Assets.xcassets/                  # 应用图标、配色等资源
│   └── Preview Content/                  # SwiftUI 预览资源
│
├── MyEcommerceTests/                     # 主 Target 单元测试（脚手架）
│
├── MyEcommerceUITests/                   # 主 Target UI 测试（脚手架）
│
├── Packages/                             # ★ 所有业务代码以 SPM Package 组织
│   │
│   ├── Abstraction/                      # 【最内层】纯协议层（无业务实现）
│   │   ├── Package.swift
│   │   └── Sources/Abstraction/
│   │       ├── ProductAbstraction/       #   商品域协议：Repository、UseCase、DomainModel
│   │       ├── BasketAbstraction/        #   购物车域协议：同上
│   │       ├── UserAbstraction/          #   用户域协议：同上
│   │       ├── AnalyticsAbstraction/     #   分析域协议：事件上报用例协议
│   │       ├── DIAbstraction/            #   DI 容器（Swinject Container 单例封装）
│   │       ├── RoutingAbstraction/       #   路由域协议：AppRoute、RouterProtocol、RouteConfiguration
│   │       └── WebContainerAbstraction/  #   WebView 桥接协议
│   │
│   ├── Domain/                           # 【业务逻辑层】UseCase 实现
│   │   ├── Package.swift
│   │   └── Sources/Domain/
│   │       ├── ProductDomain/            #   商品用例：GetProductsUseCase
│   │       ├── BasketDomain/             #   购物车用例：AddProduct / GetBasket
│   │       ├── UserDomain/               #   用户用例：LoginUserUseCase
│   │       ├── AnalyticsDomain/          #   分析用例：SendProductDetailAnalyticsData、TrackPageLifecycleUseCase
│   │       ├── RoutingDomain/            #   路由用例：NavigateUseCase（跳转编排 + 前置校验）
│   │       └── 各模块含 DI/ 目录 → 向容器注册 UseCase
│   │
│   ├── Data/                             # 【数据层】Repository + Service + Router 实现
│   │   ├── Package.swift
│   │   └── Sources/Data/
│   │       ├── ProductData/              #   商品 Repository → ProductService → API
│   │       ├── BasketData/               #   购物车 Repository → BasketService → API
│   │       ├── UserData/                 #   用户 Repository → UserService → API
│   │       ├── RoutingData/              #   路由实现：AppRouter、RouteFactoryRegistry、TransitioningCoordinator
│   │       └── 每模块含 DTO/、DomainModel/、DI/ 目录
│   │
│   ├── Presentation/                     # 【表示层】SwiftUI Feature 包
│   │   ├── LoginFeature/                 #   登录模块：LoginView + LoginViewModel
│   │   │   └── Route/                    #     LoginRoute + LoginRouteFactory
│   │   ├── ProductsFeature/              #   商品列表 + 详情模块
│   │   │   ├── ProductList/              #     商品列表页
│   │   │   ├── ItemDetail/               #     商品详情页
│   │   │   └── Route/                    #     ProductRoute + ProductRouteFactory
│   │   ├── BasketFeature/                #   购物车模块：BasketView + BasketViewModel
│   │   │   └── Route/                    #     BasketRoute + BasketRouteFactory
│   │   └── WebContainerFeature/          #   WebView 容器模块
│   │       └── Route/                    #     WebContainerRoute + WebContainerRouteFactory
│   │
│   └── Utilities/                        # 【工具层】复用基础组件
│       ├── Networking/                   #   网络层（URLSession + RxSwift）
│       │   └── Sources/Networking/API/
│       │       ├── APIProvider.swift     #     HTTP 客户端核心
│       │       ├── APIRequest.swift      #     请求协议
│       │       ├── APIResponse.swift     #     响应封装
│       │       ├── APIError.swift        #     错误类型
│       │       ├── APIConstants.swift    #     常量
│       │       ├── Environment/          #     开发/生产环境切换
│       │       └── Mock/                 #     Mock APIProvider + 数据工厂
│       ├── ImageLoading/                  #   远程图片加载（Kingfisher 封装门面）
│       ├── Utils/                        #   工具：RxObservable → Combine Publisher 桥接
│       ├── Analytics/                    #   简易分析封装（打印事件）
│       └── PresentationCore/             #   路由 UI 基类：BaseHostingController、BaseNavigationController
│
├── docs/
│   ├── architecture.md                   #   本文件 — 项目架构文档
│   └── plans/                            #   各次执行计划文档
│       ├── analytics-api-endpoint-plan.md
│       ├── dev-prd-environment-switching-plan.md
│       ├── stage9_tests_and_docs_plan.md
│       └── ...（共 8 份 stage 计划）
│
├── .claude/                              # Claude Code 配置
│   ├── settings.json
│   └── settings.local.json
│
├── CLAUDE.md                             # 项目级 AI 指令
└── .gitignore
```

---

## 依赖关系（外层 → 内层）

```
Presentation/Features  →  Domain  →  Abstraction  ←  Data
        │                                           ↑
        │                    ┌──────────────────────┘
        └──── Utilities ─────┘
```

| 层 | 依赖 |
|---|---|
| **Presentation** | Domain, Abstraction, Utilities |
| **Domain** | Abstraction 协议（无实现），RxSwift |
| **Data** | Abstraction 协议 + Networking，RxSwift |
| **Abstraction** | Swinject，RxSwift（零项目内依赖） |
| **Utilities/Networking** | RxSwift + RxCocoa |
| **Utilities/Utils** | RxSwift + Combine |
| **Utilities/Analytics** | 无 |
| **Utilities/DesignSystem** | 设计令牌系统 — ColorTokensProviding（8 语义色 + Asset Catalog 深色/浅色模式）、TypographyTokensProviding（8 字号档位 + Dynamic Type）、RadiusTokensProviding（4 圆角档位）、SpacingTokensProviding（6 间距档位，4pt 网格）、ShadowTokensProviding（card/elevated 两档阴影）、UIKit 兼容层（UIColor+DesignSystem、UIFont+DesignSystem） | SwiftUI 内置（无外部依赖） |
| **Utilities/ImageLoading** | 远程图片加载门面 — AppRemoteImage（KFImage 封装）、ImageLoadingConfiguration、ImageCacheBootstrap | Kingfisher |
| **Utilities/PresentationCore** | RoutingAbstraction, AnalyticsAbstraction, DIAbstraction, Swinject |

---

## 数据流

```
View  →  ViewModel (ObservableObject)
        →  UseCaseProtocol  →  UseCase (Domain)
        →  RepositoryProtocol  →  Repository (Data)
        →  Service  →  APIProvider  →  URLSession
```

- 所有响应式链使用 **RxSwift Observable** 在 Domain / Data 层传递
- ViewModel 层通过 `Utils` 的 `Observable.asPublisher()` 桥接为 **Combine Publisher**
- ViewModel 再用 `assign(to: \.published, on: self)` 驱动 `@Published` 属性
- 路由：LoginView → TabView(Products / Basket / WebTest)，由 `TabRouter` 控制；新路由系统通过 `RouterProtocol.navigate(to:configuration:)` 驱动跳转

---

## 依赖注入

- `Swinject.Container` 单例（`DIContainer.shared`）
- 每模块在 `DI/` 目录下通过 `DIContainer.register*()` 静态方法注册
- `MyEcommerceApp.init()` 中一次性调用所有注册方法完成初始化
