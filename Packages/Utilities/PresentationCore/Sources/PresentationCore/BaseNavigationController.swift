#if canImport(UIKit)
import UIKit

/// UINavigationController 基类，统一配置导航栏外观。
///
/// 所有通过路由框架创建的页面共享同一套 UI 规范：
/// - 标题字体/颜色
/// - 返回箭头图标
/// - Bar 按钮样式
///
/// 修改此处样式即可全局生效，无需逐页修改。
open class BaseNavigationController: UINavigationController {

    // MARK: - Lifecycle

    open override func viewDidLoad() {

        super.viewDidLoad()
        configureAppearance()
    }

    // MARK: - Appearance

    /// 配置统一导航栏外观。
    /// 子类可覆写此方法自定义样式。
    open func configureAppearance() {

        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        // 标题样式
        appearance.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
            .foregroundColor: UIColor.label,
        ]
        appearance.largeTitleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 34, weight: .bold),
            .foregroundColor: UIColor.label,
        ]

        // 返回按钮样式（使用 SF Symbols 系统图标）
        let backImage = UIImage(systemName: "chevron.left")
        appearance.setBackIndicatorImage(backImage, transitionMaskImage: backImage)

        // 应用外观到所有状态
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
        navigationBar.compactAppearance = appearance

        // Bar 按钮全局色调
        navigationBar.tintColor = .systemBlue
    }
}
#endif
