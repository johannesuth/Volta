// Volta · Copyright © 2026 Johannes Uth. All rights reserved.
// Source-available under the Volta License (see LICENSE). Not for redistribution.

import AppKit
import SwiftUI
import XCTest
import VoltaLanguageCore
@testable import Volta

/// The panel ends with its own card of actions, and every icon next to a text sits in a framed badge.
@MainActor
final class PanelActionsTests: XCTestCase {
    func testBottomCardOffersLowPowerAppSettingsBatterySettingsAndQuit() {
        XCTAssertEqual(PanelAction.allCases, [.lowPower, .appSettings, .batterySettings, .quit])
        XCTAssertEqual(PanelAction.allCases.map { $0.title(language: .german) },
                       ["Stromsparmodus", "App-Einstellungen …", "Batterie-Einstellungen …", "Volta beenden"])
        XCTAssertEqual(PanelAction.allCases.map { $0.title(language: .english) },
                       ["Low Power Mode", "App Settings…", "Battery Settings…", "Quit Volta"])
    }

    func testOnlyTheSettingsRowsShowAnArrow() {
        XCTAssertEqual(PanelAction.allCases.filter(\.opensWindow), [.appSettings, .batterySettings])
    }

    private func rgba(_ color: Color) -> [Int] {
        let c = NSColor(color).usingColorSpace(.sRGB)!
        return [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
    }

    func testEverySectionAndEveryActionHasItsOwnBadgeColour() {
        XCTAssertEqual(Set(TileKind.allCases.map { rgba($0.badgeHue) }).count, TileKind.allCases.count)
        XCTAssertEqual(Set(PanelAction.allCases.map { rgba($0.hue) }).count, PanelAction.allCases.count)
        XCTAssertEqual(rgba(PanelAction.quit.hue), rgba(Hue.alarm), "quitting is the one red action")
    }

    private func luminance(_ rep: NSBitmapImageRep, x: CGFloat, y: CGFloat) -> CGFloat {
        let c = rep.colorAt(x: Int(x * 2), y: Int(y * 2))!.usingColorSpace(.deviceRGB)!
        return 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
    }

    private func checkBadge(_ scheme: ColorScheme, plate: Color, file: StaticString = #filePath, line: UInt = #line) throws {
        try RenderSupport.requireGPU()
        let size: CGFloat = 20
        let view = IconBadge(symbol: "gearshape.fill", hue: Hue.sky, size: size)
            .padding(10)
            .background(plate)
            .environment(\.colorScheme, scheme)
            .environment(\.dim, Dim())
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let rep = NSBitmapImageRep(data: renderer.nsImage!.tiffRepresentation!)!
        let outside = luminance(rep, x: 4, y: 20)
        let edge = stride(from: 10.0, through: 11.0, by: 0.5).map { abs(luminance(rep, x: $0, y: 20) - outside) }.max()!
        let fill = abs(luminance(rep, x: 12.5, y: 20) - outside)
        XCTAssertGreaterThan(edge, 0.08, "the badge has a visible frame (\(scheme))", file: file, line: line)
        XCTAssertGreaterThan(fill, 0.04, "the badge is filled with its colour (\(scheme))", file: file, line: line)
    }

    func testIconBadgeIsFramedAndFilledInDarkMode() throws { try checkBadge(.dark, plate: Color(white: 0.17)) }
    func testIconBadgeIsFramedAndFilledInLightMode() throws { try checkBadge(.light, plate: Color(white: 0.93)) }

    func testRowDividersAreJustSlightlyStrongerThanBefore() {
        // 2.4.2 drew them at 16 % of the text colour; the user asked for a barely more visible line.
        XCTAssertGreaterThan(Dim.rowDividerOpacity, 0.16)
        XCTAssertLessThanOrEqual(Dim.rowDividerOpacity, 0.2)
    }

}
