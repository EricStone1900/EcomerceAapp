import SwiftUI

import ProductsFeature
import LoginFeature
import BasketFeature

import UserDomain
import UserData

import ProductDomain
import ProductData

import BasketDomain
import BasketData

import DIAbstraction

import Analytics
import AnalyticsDomain

import WebContainerDomain
import WebContainerData
import WebContainerAbstraction

import WebContainerFeature

import RoutingDomain
import RoutingData
import PresentationCore

import ImageLoading

import CameraFeature
import CameraUI

enum Screen {
    case Products

    case Basket

    case webTest

    case moduleTest

    case cameraTest

    case camera
}

/// `AppCameraComposition.makeCameraFeature()` 构造真实的 `CameraSession`/`PipelineController`
/// 等一整套依赖，代价不算便宜（虽然真正接触摄像头硬件要等 `CameraViewModel.start()`），不应该在
/// `MyEcommerceApp.body` 每次重新求值时都跑一遍——`@State` 只在这个 View 的身份第一次出现时
/// 构造一次，`context == nil` 这个门槛保证 `.task` 里的构造代码本身也只执行一次。
private struct CameraTabContent: View {
    @State private var context: CameraFeatureContext?

    var body: some View {
        Group {
            if let context {
                CameraView(context: context)
            } else {
                Color.black
                    .overlay(ProgressView().tint(.white))
            }
        }
        .task {
            guard context == nil else { return }
            context = AppCameraComposition.makeCameraFeature()
        }
    }
}

final class TabRouter: ObservableObject {
    
    @Published var screen: Screen = .Products
    
    func change(to screen: Screen) {
        self.screen = screen
    }
}

@main
struct MyEcommerceApp: App {
    
    @StateObject private var tabRouter = TabRouter()
    
    @StateObject private var loginViewModel = LoginViewModel()
            
    init() {

        ImageCacheBootstrap.configure()

        DIContainer.registerAPIProvider()

        DIContainer.registerUserService()
        DIContainer.registerUserRepository()
        DIContainer.registerLoginUserUseCase()
        
        DIContainer.registerProductService()
        DIContainer.registerProductRepository()
        DIContainer.registerGetProductsUseCase()
        
        DIContainer.registerBasketService()
        DIContainer.registerBasketRepository()
        DIContainer.registerAddProductUseCase()
        DIContainer.registerGetBasketUseCase()

        DIContainer.registerAnalyticsWrapper()
        DIContainer.registerSendProductDetailAnalyticsDataUseCase()
        DIContainer.registerTrackPageLifecycleUseCase()

        // 新路由系统 DI 注册
        DIContainer.registerRouteFactoryRegistry()
        DIContainer.registerAppRouter()
        DIContainer.registerNavigateUseCase()
        DIContainer.registerPresentationCore()
        DIContainer.registerAllFeatureRouteFactories()

        DIContainer.registerWebContainerData()
        DIContainer.registerLoadWebContentUseCase()
        DIContainer.registerProcessBridgeCommandUseCase()

        // WebTest Tab — WebContainer Feature DI 注册
        DIContainer.shared.register(WebRouteFactoryProtocol.self) { _ in
            AppWebRouteFactory()
        }

        DIContainer.shared.register(NativeBridgeRouter.self) { resolver in
            NativeBridgeRouter(
                navigationController: nil,
                routeFactory: resolver.resolve(WebRouteFactoryProtocol.self)!
            )
        }.inObjectScope(.container)

        DIContainer.shared.register(WebContainerViewModel.self) { resolver in
            let router = resolver.resolve(NativeBridgeRouter.self)!
            return WebContainerViewModel(bridgeRouter: router)
        }

    }
    
    var body: some Scene {
        WindowGroup {
            
            LoginView(loginViewModel: loginViewModel)
                .fullScreenCover(isPresented: $loginViewModel.isConnected) {
                    
                    if let userId = loginViewModel.userID {
                        
                        TabView(selection: $tabRouter.screen) {

                            ProductListView(userId: userId)
                                .tag(Screen.Products)
                                .environmentObject(tabRouter)
                                .tabItem {
                                    Label("Products", systemImage: "drop.halffull")
                                }

                            BasketView(userId: userId)
                                .tag(Screen.Basket)
                                .tabItem {
                                    Label("Basket", systemImage: "cart.fill")
                                }

                            NavigationStack {
                                WebTestEntryView()
                                    .navigationTitle("WebTest")
                            }
                            .tag(Screen.webTest)
                            .tabItem {
                                Label("WebTest", systemImage: "globe")
                            }

                            NavigationStack {
                                ModuleTestView()
                                    .navigationTitle("ModuleTest")
                            }
                            .tag(Screen.moduleTest)
                            .tabItem {
                                Label("ModuleTest", systemImage: "square.stack.3d.up.fill")
                            }

                            NavigationStack {
                                CameraDebugView()
                                    .navigationTitle("CameraTest")
                            }
                            .tag(Screen.cameraTest)
                            .tabItem {
                                Label("CameraTest", systemImage: "camera.fill")
                            }

                            NavigationStack {
                                CameraTabContent()
                                    .navigationTitle("Camera")
                            }
                            .tag(Screen.camera)
                            .tabItem {
                                Label("Camera", systemImage: "camera.aperture")
                            }
                        }
                        
                         
                        
                    } else {
                        
                        Text("Connexion Error")
                    }
                }
        }
    }
}

