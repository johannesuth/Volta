// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import Foundation
import Metal
import XCTest

/// SwiftUI's `ImageRenderer` draws through Metal. GitHub's hosted macOS runners are virtual machines
/// without a usable GPU, where Metal aborts the whole test process, so pixel tests of SwiftUI views
/// are skipped there. They run on every Mac.
enum RenderSupport {
    static func requireGPU() throws {
        let hostedCI = ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
        try XCTSkipIf(hostedCI || MTLCreateSystemDefaultDevice() == nil,
                      "SwiftUI pixel test needs a GPU; GitHub's hosted macOS runners have none.")
    }
}
