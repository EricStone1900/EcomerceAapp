# Speech Plan 6: 性能与体验打磨

## 背景

语音核心链路打通后，本计划对整体性能与用户体验进行打磨：模型懒加载策略验证、首次下载体验优化、异常场景覆盖、真机/模拟器差异验证。

**来源**：`docs/specs/speech_swift_integration_plan.md` 阶段 6

## 步骤

### Step 1: 验证模型懒加载策略

确认语音模型仅在用户主动触发语音功能时才加载，非语音场景不占用内存：

- 应用冷启动后，用 Xcode Memory Debugger 检查是否有额外内存占用
- 点击语音搜索按钮后，确认模型开始加载，内存占用上升
- 退出语音搜索页，验证模型是否释放（或保持在合理范围的 Warm Cache）

**策略决策**：
- 如果模型加载耗时较长（>2s），考虑在 App 启动后空闲时预加载（`DispatchQueue.global().asyncAfter`）
- 预加载需在网络空闲时进行，不影响 UI 线程
- 记录决策到文档

### Step 2: 首次下载体验优化

模型首次下载（Kokoro 约 80~170MB，Parakeet 约 X MB）的用户体验关键点：

| 场景 | 处理方式 |
|------|---------|
| Wi-Fi 环境 | 静默下载，展示进度条即可，不阻断操作 |
| 蜂窝网络 | 下载前弹出确认："下载语音模型约 XX MB，当前使用蜂窝数据，是否继续？" |
| 下载中退出 | 下次进入时恢复下载（检查 speech-swift 是否支持断点续传） |
| 下载失败 | 展示重试按钮 + 错误原因（网络超时/存储空间不足等） |
| 存储空间不足 | 提示"存储空间不足，请清理后重试" |

实现方式：
- 在 `SpeechModelDownloadMonitor` 中增加网络状态监测（使用 `NWPathMonitor` 或已有的网络工具）
- 下载确认弹窗使用 DesignSystem 的通用 Alert 组件
- 下载进度用 DesignSystem 的进度条组件

### Step 3: 异常场景覆盖

编写全面的降级处理逻辑：

```
场景                                  → 降级行为
─────────────────────────────────────────────────────────────────
麦克风权限拒绝                          → 引导去设置开启，按钮不可用
模型下载失败（无网络）                    → 提示"请检查网络后重试"
模型下载失败（空间不足）                  → "请清理存储空间后重试"
ASR 识别超时（说话后 10s 无结果）         → 提示"未检测到语音，请重试"
ASR 识别结果为空白                       → 提示"未听清，请再说一遍"
TTS 播放失败                            → 静默失败，Toast 提示
内存压力（模型加载后低内存警告）           → 释放模型资源，降级提示
模拟器运行                              → ASR/TTS 性能下降，告知开发者预期差异
```

### Step 4: 真机 vs 模拟器差异验证

| 验证项 | 模拟器行为 | 真机行为 |
|--------|-----------|---------|
| ASR 模型推理 | 回退 CPU，速度较慢 | Neural Engine，实时推理 |
| TTS 语音合成 | 回退 CPU | Neural Engine |
| 音频播放/录制 | 使用 Mac 麦克风/喇叭 | 使用设备麦克风/扬声器 |
| 性能 | 可能有明显延迟 | 流畅 |

记录测试矩阵，确认真机体验可接受。

### Step 5: 音频会话管理

确保语音搜索与播报不互相冲突：

- 语音搜索时：配置 `AVAudioSession.Category.playAndRecord`
- 语音播报时：配置 `AVAudioSession.Category.playback`
- 使用 `AVAudioSession.sharedInstance().setCategory(_:options:)` 切换
- 处理来电中断（`AVAudioSession.interruptionNotification`）

## 涉及文件清单

- `Packages/Utilities/SpeechKit/Sources/SpeechKit/SpeechModelDownloadMonitor.swift`（修改，增加网络检测与断点续传）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/SpeechPermissionManager.swift`（修改，完善降级）
- `Packages/Utilities/SpeechKit/Sources/SpeechKit/AudioSessionManager.swift`（新建，音频会话管理）
- `Packages/Presentation/ProductsFeature/.../Views/`（补全异常 UI 提示）
- `MyEcommerceApp/Info.plist`（确认权限文案正确）
- `docs/specs/speech_swift_integration_plan.md`（可选，记录最终决策）

## 验收标准

- [ ] 非语音场景下模型不加载，不占用额外内存
- [ ] 首次下载在 Wi-Fi 下静默完成，蜂窝数据下需确认
- [ ] 所有异常场景有合理降级，不崩溃
- [ ] 真机体验流畅，模拟器功能正常（性能可接受）
- [ ] 语音搜索与播报的音频会话互不冲突
- [ ] 来电/音频中断可正确处理
