@preconcurrency import Metal
import Testing

import CameraPipeline
@testable import CameraFeature

private struct StubProcessor: FrameProcessor {
    let id: PluginID
    func process(_ texture: MTLTexture, context: RenderContext) -> MTLTexture { texture }
}

private struct StubAnalyzer: FrameAnalyzer {
    let id: PluginID
    let preferredFPS = 10
    func analyze(_ frame: Frame) async -> [Annotation] { [] }
}

@Suite("PluginRegistry")
struct PluginRegistryTests {

    @Test("resolves registered processors by ID, in the order the IDs were requested")
    func resolvesRegisteredProcessorsInRequestedOrder() {
        let registry = PluginRegistry()
        registry.register(StubProcessor(id: PluginID("a")), id: PluginID("a"))
        registry.register(StubProcessor(id: PluginID("b")), id: PluginID("b"))

        let resolved = registry.resolveProcessors(["b", "a"])

        #expect(resolved.map(\.id) == [PluginID("b"), PluginID("a")])
    }

    @Test("unregistered IDs are silently skipped, not an error")
    func skipsUnregisteredIDs() {
        let registry = PluginRegistry()
        registry.register(StubProcessor(id: PluginID("a")), id: PluginID("a"))

        let resolved = registry.resolveProcessors(["a", "does-not-exist"])

        #expect(resolved.map(\.id) == [PluginID("a")])
    }

    @Test("processors and analyzers are kept in separate namespaces")
    func processorsAndAnalyzersAreSeparateNamespaces() {
        let registry = PluginRegistry()
        registry.register(StubProcessor(id: PluginID("shared-id")), id: PluginID("shared-id"))
        registry.register(StubAnalyzer(id: PluginID("shared-id")), id: PluginID("shared-id"))

        #expect(registry.resolveProcessors(["shared-id"]).count == 1)
        #expect(registry.resolveAnalyzers(["shared-id"]).count == 1)
    }

    @Test("re-registering the same ID replaces the previous entry")
    func reregisteringReplacesPreviousEntry() {
        let registry = PluginRegistry()
        registry.register(StubAnalyzer(id: PluginID("first")), id: PluginID("x"))
        registry.register(StubAnalyzer(id: PluginID("second")), id: PluginID("x"))

        let resolved = registry.resolveAnalyzers(["x"])

        #expect(resolved.count == 1)
        #expect(resolved.first?.id == PluginID("second"))
    }
}
