#if !canImport(UIKit)
// MARK: - UIKit Compatibility Stubs (for macOS command-line compilation only)
// These stubs allow RoutingAbstraction to compile when UIKit is not available
// (e.g., during `swift test` on macOS). The actual runtime target is iOS.

public protocol UIViewControllerAnimatedTransitioning {}
open class UIViewController {}
open class UIView {}

// Stage 5 转场协调器所需的协议桩
public protocol UINavigationControllerDelegate {}
public protocol UIViewControllerTransitioningDelegate {}
#endif
