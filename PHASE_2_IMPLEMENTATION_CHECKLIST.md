# Phase 2 Implementation Checklist

## Pre-Implementation ✅

- [x] Read audit document
- [x] Create MainActorMessages.swift (270 LOC)
- [x] Create AppIntents.swift (258 LOC)
- [x] Create AsyncTimerHelpers.swift (39 LOC)
- [x] Migrate ContentView.swift to @Observable (2 classes)
- [x] Migrate ModernPermissionManager.swift to @Observable
- [x] Generate implementation report
- [x] Generate reference implementations

**Status**: Infrastructure complete ✅

---

## Task 1: NotificationCenter Migration (82 usages)

### 1.1 Memory Management Notifications

**File: ModernMemoryManager.swift** (13 locations)

- [ ] Line 158: `handleWarningMemoryPressure()` → `MemoryPressureWarning`
- [ ] Line 170: `handleCriticalMemoryPressure()` → `MemoryPressureCritical`
- [ ] Line 171: Same function → `ReduceQualityForMemoryPressure`
- [ ] Line 174: Same function → `ShowMemoryWarningUI`
- [ ] Line 267: `reduceProcessingQuality()` → `ReduceProcessingQuality`
- [ ] Line 272: `stopNonEssentialProcesses()` → `StopNonEssentialProcesses`
- [ ] Line 491: `clearCaches()` → `CachesCleared`
- [ ] Line 1075: Memory warning → `MemoryPressureWarning`
- [ ] Line 1103: Predictive notification → `PredictedMemoryPressure`
- [ ] Line 1174: Stop processes → `StopNonEssentialProcesses`
- [ ] Line 1178: Reduce quality → `ReduceProcessingQuality`
- [ ] Line 1337: Notification posting (check context)
- [ ] Line 1436: Notification posting (check context)

**Observers to migrate:**
- [ ] Line 80: `addObserver` for memory pressure
- [ ] Line 103: `addObserver` for predicted pressure

**File: MemoryManager.swift** (3 locations)

- [ ] Line 231: Quality reduction → `ReduceQualityForMemoryPressure`
- [ ] Line 249: Emergency pressure → `EmergencyMemoryPressure`
- [ ] Line 93: Observer migration

**Subtotal**: 16 touchpoints

---

### 1.2 Error Recovery Notifications

**File: ErrorRecoveryManager.swift** (8 locations)

- [ ] Line 297: `retryCameraSetup()` → `RetryCameraSetup`
- [ ] Line 303: `retryRecordingStart()` → `RetryRecordingStart`
- [ ] Line 309: `retryRecordingStop()` → `RetryRecordingStop`
- [ ] Line 326: `restartCameraSetup()` → `RestartCameraSetup`
- [ ] Line 332: `restartRecording()` → `RestartRecording`
- [ ] Line 358: `forceStopRecording()` → `ForceStopRecording`
- [ ] Line 493: Error recovered → `ErrorRecovered`
- [ ] Add async observer monitoring task

**File: ErrorHandlingManager.swift** (2 locations)

- [ ] Line 288: Force stop → `ForceStopRecording`
- [ ] Line 330: Show warning → `ShowMemoryWarning`

**Subtotal**: 10 touchpoints

---

### 1.3 Focus Mode Notifications

**File: FocusModeIntegration.swift** (9 locations)

- [ ] Line 279: Hide controls → `FocusModeShouldHideControls`
- [ ] Line 285: Show controls → `FocusModeShouldShowControls`
- [ ] Line 291: Reduce effects → `FocusModeShouldReduceVisualEffects`
- [ ] Line 297: Restore effects → `FocusModeShouldRestoreVisualEffects`
- [ ] Line 303: Enable minimal → `FocusModeShouldEnableMinimalMode`
- [ ] Line 309: Disable minimal → `FocusModeShouldDisableMinimalMode`
- [ ] Line 317: Custom behavior (check context)
- [ ] Line 72: Observer migration
- [ ] Add async monitoring task

**Subtotal**: 9 touchpoints

---

### 1.4 Accessibility Notifications

**File: AccessibilityAwareGlass.swift** (5 locations)

- [ ] Line 126: Glass settings → `AccessibilityGlassSettingsChanged`
- [ ] Line 127: Metal rendering → `MetalRenderingSettingsChanged`
- [ ] Line 102: Observer for accessibility
- [ ] Line 109: Observer for contrast
- [ ] Line 116: Observer for transparency

**File: MotorAccessibilityFeatures.swift** (13 locations)

- [ ] Line 184: Switch control → `MotorAccessibilityShouldApplySwitchControlConfiguration`
- [ ] Line 189: Assistive touch → `MotorAccessibilityShouldApplyAssistiveTouchConfiguration`
- [ ] Line 194: Reduced motion → `MotorAccessibilityShouldApplyReducedMotionConfiguration`
- [ ] Line 199: Touch accommodations → `MotorAccessibilityShouldApplyTouchAccommodations`
- [ ] Line 204: Alternate controls → `MotorAccessibilityShouldApplyAlternateControlMethods`
- [ ] Line 433: Voice control → `MotorAccessibilityShouldSetupVoiceControlCommands`
- [ ] Line 444: Switch scanning → `MotorAccessibilityShouldSetupSwitchControlScanning`
- [ ] Line 455: Custom actions → `MotorAccessibilityShouldSetupAssistiveTouchCustomActions`
- [ ] Line 67-88: Observer migrations (4 observers)
- [ ] Add async monitoring task

**Subtotal**: 18 touchpoints

---

### 1.5 System State Notifications

**File: BatteryAwareProcessingManager.swift** (4 locations)

- [ ] Line 114: Battery state → `BatteryStateChanged`
- [ ] Line 60-74: Observer migrations (3 observers)

**File: BatteryManager.swift** (3 locations)

- [ ] Line 84-100: Observer migrations (3 observers)
- [ ] Add battery state posting

**File: DualCameraManager.swift** (1 location)

- [ ] Line 200: Thermal observer → migrate to async

**File: ThermalManager.swift** (1 location)

- [ ] Line 78: Thermal observer → migrate to async

**Subtotal**: 9 touchpoints

---

### 1.6 UI/ViewController Notifications

**File: ViewController.swift** (5 locations)

- [ ] Line 956-986: Observer migrations (5 observers)
- [ ] Add async monitoring tasks

**File: GlassmorphismView.swift** (1 location)

- [ ] Line 53: Observer migration

**File: LiquidGlassView.swift** (1 location)

- [ ] Line 82: Commented observer (review and migrate if needed)

**File: PerformanceMonitor.swift** (4 locations)

- [ ] Line 348-458: Observer migrations (4 observers)

**Subtotal**: 11 touchpoints

---

### NotificationCenter Migration Summary

| Category | Post Calls | Observers | Total |
|----------|-----------|-----------|-------|
| Memory Management | 13 | 3 | 16 |
| Error Recovery | 8 | 0 | 10 |
| Focus Mode | 7 | 2 | 9 |
| Accessibility | 10 | 8 | 18 |
| System State | 1 | 8 | 9 |
| UI/ViewController | 0 | 11 | 11 |
| **TOTAL** | **39** | **32** | **82** |

**Estimated Time**: 3-4 days

---

## Task 2: Timer Migration (20 instances)

### 2.1 High-Frequency Timers (< 1s interval)

- [ ] **AudioManager.swift:312** - audioLevelTimer (0.1s)
  - Add property: `audioLevelMonitoringTask: Task<Void, Never>?`
  - Replace Timer with `Timer.asyncSequence(interval: 0.1, tolerance: 0.01)`
  - Add `startAudioLevelMonitoring()` and `stopAudioLevelMonitoring()`

- [ ] **AudioControlsView.swift:471** - peakDecayTimer (0.5s, one-shot)
  - Replace with `Task.sleep(nanoseconds: 500_000_000)`

**Subtotal**: 2 timers

---

### 2.2 Recording/Duration Timers (1s interval)

- [ ] **ViewController.swift:402** - recordingTimer (1s)
  - Add property: `recordingTimerTask: Task<Void, Never>?`
  - Implement `startRecordingTimer()` and `stopRecordingTimer()`
  - Update `didStartRecording()` and `didStopRecording()`

- [ ] **ViewController.swift:830** - countdownTimer (1s)
  - Add property: `countdownTimerTask: Task<Void, Never>?`
  - Implement `startCountdownTimer(from:)`
  - Replace timer invalidation with task cancellation

- [ ] **ContentView.swift:241** - timer (1s)
  - Add property: `timerTask: Task<Void, Never>?`
  - Migrate to async sequence

- [ ] **DynamicIslandManager.swift:263** - durationUpdateTimer (1s)
  - Add property: `durationMonitoringTask: Task<Void, Never>?`
  - Migrate to async sequence

- [ ] **LiveActivityManager.swift:302** - durationTimer (1s)
  - Part of multi-timer migration
  - Add to `startAllMonitoring()` task group

- [ ] **VisualCountdownView.swift:53** - countdownTimer (1s)
  - Add property: `countdownTask: Task<Void, Never>?`
  - Migrate to async sequence with break condition

**Subtotal**: 6 timers

---

### 2.3 Monitoring Timers (5-60s interval)

- [ ] **PerformanceMonitor.swift:555** - monitoringTimer (configurable)
  - Add property: `monitoringTask: Task<Void, Never>?`
  - Implement `startMonitoring()` and `stopMonitoring()`
  - Run on `.utility` priority

- [ ] **MemoryManager.swift:100** - memory check (5s)
  - Add property: `memoryCheckTask: Task<Void, Never>?`
  - Migrate to async sequence

- [ ] **ThermalManager.swift:118** - thermalTimer (5s)
  - Add property: `thermalMonitoringTask: Task<Void, Never>?`
  - Implement `startThermalMonitoring()` and `stopThermalMonitoring()`

- [ ] **ThermalManager.swift:332** - mitigationTimer (variable, one-shot)
  - Add property: `mitigationDelayTask: Task<Void, Never>?`
  - Replace with `Task.sleep(nanoseconds:)`

- [ ] **ViewController.swift:1651** - periodic refresh (5s)
  - Add property: `refreshTask: Task<Void, Never>?`
  - Migrate to async sequence

- [ ] **ViewController.swift:1024** - periodic check (10s)
  - Add property: `checkTask: Task<Void, Never>?`
  - Migrate to async sequence

- [ ] **BatteryManager.swift:108** - battery update (30s)
  - Add property: `batteryUpdateTask: Task<Void, Never>?`
  - Migrate to async sequence

- [ ] **LiveActivityManager.swift:310** - batteryTimer (30s)
  - Part of multi-timer migration

- [ ] **LiveActivityManager.swift:318** - thermalTimer (60s)
  - Part of multi-timer migration

- [ ] **LiveActivityManager.swift:326** - storageTimer (60s)
  - Part of multi-timer migration

**Subtotal**: 10 timers

---

### 2.4 Storage/Resource Timers

- [ ] **StorageManager.swift:72** - storageCheckTimer (configurable)
  - Add property: `storageMonitoringTask: Task<Void, Never>?`
  - Implement `startStorageMonitoring()` and `stopStorageMonitoring()`

- [ ] **BatteryAwareProcessingManager.swift:81** - batteryMonitorTimer
  - Add property: `batteryMonitoringTask: Task<Void, Never>?`
  - Migrate to async sequence

**Subtotal**: 2 timers

---

### Timer Migration Summary

| Category | Count | Files | Status |
|----------|-------|-------|--------|
| High-Frequency (< 1s) | 2 | 2 | 📋 Ready |
| Recording/Duration (1s) | 6 | 4 | 📋 Ready |
| Monitoring (5-60s) | 10 | 5 | 📋 Ready |
| Storage/Resource | 2 | 2 | 📋 Ready |
| **TOTAL** | **20** | **13** | **Pattern established** |

**Estimated Time**: 2-3 days

---

## Task 3: AppIntents Integration

### 3.1 Code Implementation

- [x] Create AppIntents.swift
- [ ] Add DualCameraManager extensions
  - [ ] `isFlashEnabled()` method
  - [ ] `startRecordingAsync()` method
  - [ ] `stopRecordingAsync()` method
  - [ ] `capturePhotoAsync()` method
  - [ ] `swapCamerasAsync()` method

- [ ] Add ViewController property exposure
  - [ ] `exposedCameraManager` computed property

### 3.2 Info.plist Updates

- [ ] Add `NSAppIntentsUsageDescription`
- [ ] Add `INIntentsSupported` array with 6 intents
- [ ] Add `INEnums` for VideoQualityEnum

### 3.3 Testing

- [ ] Test Siri command: "Start recording with DualCameraApp"
- [ ] Test Siri command: "Stop recording"
- [ ] Test Siri command: "Take a photo with DualCameraApp"
- [ ] Test Siri command: "Switch camera"
- [ ] Test Shortcuts app integration
- [ ] Test Lock Screen widget (iOS 26)

**Estimated Time**: 1-2 days

---

## Task 4: Testing & Validation

### 4.1 Unit Tests

- [ ] MainActorMessage type safety tests
- [ ] Async timer cancellation tests
- [ ] Async timer accuracy tests
- [ ] @Observable update frequency tests
- [ ] AppIntents parameter validation tests

### 4.2 Integration Tests

- [ ] End-to-end notification flow
- [ ] Multi-timer coordination
- [ ] Memory pressure → UI update flow
- [ ] Siri → recording start → stop flow

### 4.3 Performance Tests

- [ ] SwiftUI update frequency benchmark (expect 40% reduction)
- [ ] Notification async stream latency
- [ ] Timer drift measurement
- [ ] Memory leak profiling with Instruments

### 4.4 Manual Testing

- [ ] Test on iOS 26 device/simulator
- [ ] Test on iOS 17-25 devices (backward compatibility)
- [ ] Test with VoiceOver enabled
- [ ] Test with Low Power Mode enabled
- [ ] Test with Reduce Motion enabled

**Estimated Time**: 2-3 days

---

## Task 5: Documentation

- [x] Create PHASE_2_MIGRATION_REPORT.md
- [x] Create PHASE_2_REFERENCE_IMPLEMENTATIONS.md
- [x] Create PHASE_2_IMPLEMENTATION_CHECKLIST.md
- [ ] Update inline code documentation
- [ ] Add migration notes to CHANGELOG
- [ ] Update README with iOS 26 features

**Estimated Time**: 0.5 days

---

## Timeline Summary

| Phase | Duration | Dependencies |
|-------|----------|-------------|
| **Infrastructure** | ✅ Complete | None |
| **NotificationCenter Migration** | 3-4 days | Infrastructure |
| **Timer Migration** | 2-3 days | Infrastructure |
| **AppIntents Integration** | 1-2 days | None (parallel) |
| **Testing & Validation** | 2-3 days | All migrations |
| **Documentation** | 0.5 days | Testing complete |
| **TOTAL** | **9-13 days** | Sequential + parallel |

---

## Completion Criteria

### Must Have ✅

- [ ] All 82 notification usages migrated to type-safe messages
- [ ] All 20 timer instances migrated to async sequences
- [ ] All 8 @Published properties migrated to @Observable
- [ ] All 6 AppIntents implemented and tested
- [ ] Zero compilation warnings
- [ ] Zero memory leaks (validated with Instruments)
- [ ] All unit tests passing
- [ ] Performance benchmarks meeting targets (40% SwiftUI improvement)

### Should Have 🎯

- [ ] Siri integration fully tested
- [ ] Backward compatibility validated (iOS 17-25)
- [ ] Code documentation updated
- [ ] CHANGELOG updated

### Nice to Have 🌟

- [ ] Lock Screen widgets tested
- [ ] Shortcuts app automations documented
- [ ] Performance comparison report generated
- [ ] Video demo of Siri integration

---

## Risk Mitigation

### High Risk Items

1. **Async Context Migration** (Timers)
   - Mitigation: Keep old code commented until fully validated
   - Rollback: Revert to Timer.scheduledTimer if issues

2. **iOS 26 API Availability**
   - Mitigation: Use @available checks throughout
   - Rollback: Disable AppIntents if iOS 26 unavailable

3. **NotificationCenter Observer Breaking Changes**
   - Mitigation: Use `postLegacy()` for backward compatibility
   - Rollback: Keep both old and new observers temporarily

### Medium Risk Items

1. **@Observable Compatibility**
   - Mitigation: Test thoroughly on real devices
   - Rollback: Revert to @Published + ObservableObject

2. **Task Cancellation Timing**
   - Mitigation: Add proper cancellation checks
   - Rollback: Manual timer invalidation

---

## Success Metrics

| Metric | Target | Measurement Method |
|--------|--------|-------------------|
| SwiftUI update reduction | 40% | Instruments profiling |
| Notification type safety | 100% | Compile-time verification |
| Timer memory leaks | 0 | Instruments Memory Profiler |
| Siri intent success rate | > 95% | Manual testing |
| Code coverage | > 80% | XCTest code coverage |
| Performance regression | < 5% | Baseline comparison |

---

## Sign-Off

- [ ] Code review completed
- [ ] All tests passing
- [ ] Performance benchmarks met
- [ ] Documentation updated
- [ ] Approved for merge

**Reviewer**: _______________  
**Date**: _______________

---

## Notes

Add any implementation notes, blockers, or discoveries here:

```
[Space for notes]
```
