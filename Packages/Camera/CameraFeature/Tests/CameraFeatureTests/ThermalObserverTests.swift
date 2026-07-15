import Foundation
import Testing

import CameraPipeline
@testable import CameraFeature

/// AsyncStream + NotificationCenter 组合起来天然不适合写"证明什么都没发生"这种依赖竞态/超时的
/// 测试（跟 CameraVision.HorizonAnalyzer 当初跳过"空结果"用例是同一个理由：与其写一个可能偶发
/// 失败的脆弱测试，不如只测确定性的行为）。这里只覆盖两条完全确定性的路径：post 一次通知能收到
/// 一次事件、以及 stop() 之后 start() 重新订阅依然能正常工作——都不需要"等一段时间证明没有第二次"
/// 这种本质上不确定的断言。
@Suite("ThermalObserver")
@MainActor
struct ThermalObserverTests {

    @Test("posting the system thermal notification drives the policy and yields a value")
    func postingNotificationDrivesPolicy() async throws {
        let pipeline = PipelineController()
        let useCase = ThermalPolicyUseCase(pipeline: pipeline)
        let observer = ThermalObserver(thermalPolicyUseCase: useCase)
        observer.start()
        var iterator = observer.shouldForcePassthrough.makeAsyncIterator()

        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        let result = await iterator.next()

        // 具体是 true 还是 false 取决于跑测试这台机器当下真实的 ProcessInfo.thermalState
        // （不可控、不该断言具体值），只验证"确实被触发了一次"。
        #expect(result != nil)

        observer.stop()
    }

    @Test("stop() followed by start() re-attaches and keeps working")
    func stopThenRestartWorks() async throws {
        let pipeline = PipelineController()
        let useCase = ThermalPolicyUseCase(pipeline: pipeline)
        let observer = ThermalObserver(thermalPolicyUseCase: useCase)
        var iterator = observer.shouldForcePassthrough.makeAsyncIterator()

        observer.start()
        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        let first = await iterator.next()
        #expect(first != nil)

        observer.stop()
        observer.start()
        NotificationCenter.default.post(name: ProcessInfo.thermalStateDidChangeNotification, object: nil)
        let second = await iterator.next()
        #expect(second != nil)

        observer.stop()
    }
}
