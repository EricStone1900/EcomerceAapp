import os

public enum CameraLog {
    public static let session = Logger(subsystem: "com.myecoapp.camera", category: "Session")
    public static let pipeline = Logger(subsystem: "com.myecoapp.camera", category: "Pipeline")
    public static let vision = Logger(subsystem: "com.myecoapp.camera", category: "Vision")
}
