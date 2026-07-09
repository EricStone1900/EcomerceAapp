import Testing

@Test("SpeechPermissionManager initial status is notDetermined")
func permissionManagerInitialStatus() {
    let manager = SpeechPermissionManager()
    #expect(manager.currentStatus == .notDetermined)
}
