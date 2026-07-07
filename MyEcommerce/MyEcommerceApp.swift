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

enum Screen {
    case Products

    case Basket

    case webTest

    case moduleTest
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
                        }
                        
                         
                        
                    } else {
                        
                        Text("Connexion Error")
                    }
                }
        }
    }
}

