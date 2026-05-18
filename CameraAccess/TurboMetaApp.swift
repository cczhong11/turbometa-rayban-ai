/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

//
// CameraAccessApp.swift
//
// Main entry point for the CameraAccess sample app demonstrating the Meta Wearables DAT SDK.
// This app shows how to connect to wearable devices (like Ray-Ban Meta smart glasses),
// stream live video from their cameras, and capture photos. It provides a complete example
// of DAT SDK integration including device registration, permissions, and media streaming.
//

import Foundation
import MWDATCore
import SwiftUI

#if DEBUG
import MWDATMockDevice
#endif

@main
struct TurboMetaApp: App {
  #if DEBUG
  // Debug menu for simulating device connections during development
  @StateObject private var debugMenuViewModel = DebugMenuViewModel(mockDeviceKit: MockDeviceKit.shared)
  #endif
  private let wearables: WearablesInterface
  @StateObject private var wearablesViewModel: WearablesViewModel

  init() {
    let wearables = Self.makeWearables()
    self.wearables = wearables
    self._wearablesViewModel = StateObject(wrappedValue: WearablesViewModel(wearables: wearables))
  }

  var body: some Scene {
    WindowGroup {
      // Main app view with access to the shared Wearables SDK instance
      // The Wearables.shared singleton provides the core DAT API
      MainAppView(wearables: wearables, viewModel: wearablesViewModel)
        // Show error alerts for view model failures
        .alert("Error", isPresented: $wearablesViewModel.showError) {
          Button("OK") {
            wearablesViewModel.dismissError()
          }
        } message: {
          Text(wearablesViewModel.errorMessage)
        }
        #if DEBUG
      // Bug 图标已隐藏
      // .sheet(isPresented: $debugMenuViewModel.showDebugMenu) {
      //   MockDeviceKitView(viewModel: debugMenuViewModel.mockDeviceKitViewModel)
      // }
      // .overlay {
      //   DebugMenuView(debugMenuViewModel: debugMenuViewModel)
      // }
        #endif

      // Registration view handles the flow for connecting to the glasses via Meta AI
      RegistrationView(wearables: wearables, viewModel: wearablesViewModel)
    }
  }

  private static func makeWearables() -> WearablesInterface {
    if isRunningTests && ProcessInfo.processInfo.environment["FORCE_DAT_STREAM_SESSION"] != "1" {
      print("🧪 [TurboMeta] Running under tests, using NoopWearables host")
      return NoopWearables()
    }

    do {
      try Wearables.configure()
      print("✅ [TurboMeta] Wearables SDK configured successfully")
      return Wearables.shared
    } catch {
      print("❌ [TurboMeta] Wearables.configure() failed: \(error) | \(error.localizedDescription)")
      return NoopWearables()
    }
  }

  private static var isRunningTests: Bool {
    ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil
      || NSClassFromString("XCTestCase") != nil
  }
}

private struct NoopListenerToken: AnyListenerToken {
  func cancel() async {}
}

final class NoopWearables: WearablesInterface, @unchecked Sendable {
  var registrationState: RegistrationState { .available }
  var devices: [DeviceIdentifier] { [] }

  func addRegistrationStateListener(_ listener: @escaping @Sendable (RegistrationState) -> Void) -> any AnyListenerToken {
    listener(registrationState)
    return NoopListenerToken()
  }

  func registrationStateStream() -> AsyncStream<RegistrationState> {
    AsyncStream { continuation in
      continuation.yield(registrationState)
      continuation.finish()
    }
  }

  func startRegistration() async throws(RegistrationError) {}

  func handleUrl(_ url: URL) async throws(WearablesHandleURLError) -> Bool {
    false
  }

  func startUnregistration() async throws(UnregistrationError) {}

  func addDevicesListener(_ listener: @escaping @Sendable ([DeviceIdentifier]) -> Void) -> any AnyListenerToken {
    listener(devices)
    return NoopListenerToken()
  }

  func devicesStream() -> AsyncStream<[DeviceIdentifier]> {
    AsyncStream { continuation in
      continuation.yield(devices)
      continuation.finish()
    }
  }

  func deviceForIdentifier(_ identifier: DeviceIdentifier) -> Device? {
    nil
  }

  func checkPermissionStatus(_ permission: Permission) async throws(PermissionError) -> PermissionStatus {
    .denied
  }

  func requestPermission(_ permission: Permission) async throws(PermissionError) -> PermissionStatus {
    .denied
  }

  func addDeviceSessionStateListener(forDeviceId deviceId: DeviceIdentifier, listener: @escaping @Sendable (SessionState) -> Void) async -> any AnyListenerToken {
    listener(.stopped)
    return NoopListenerToken()
  }
}
