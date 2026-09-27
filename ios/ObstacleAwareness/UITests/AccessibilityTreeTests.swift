import XCTest

/// Dumps and checks the accessibility tree the app exposes.
///
/// This exists because "I turned VoiceOver on and it read the card correctly"
/// is not something that can be verified from a development machine, and
/// "it compiles" says nothing about what a screen reader will say. XCUITest's
/// snapshot *is* the accessibility tree VoiceOver reads from, so asserting
/// against it is the closest thing to a real check that does not require
/// someone holding the phone and reporting what they heard.
///
/// What it can and cannot establish. It verifies **structure**: that the status
/// card is a single element carrying one written-out sentence rather than nine
/// separately-focusable fragments, that every control has a label describing
/// what it does, and that the camera preview and its box overlays are hidden
/// from the reader. It cannot verify speech, VoiceOver's own gesture handling,
/// or the running state's sentence — the simulator has no ARKit, so the app
/// stays in its idle state throughout.
final class AccessibilityTreeTests: XCTestCase {

    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    /// Prints the whole tree to the test log. Not an assertion — this is the
    /// artefact to read when something sounds wrong on the device.
    func testDumpAccessibilityTree() throws {
        print("=== ACCESSIBILITY TREE BEGIN ===")
        print(app.debugDescription)
        print("=== ACCESSIBILITY TREE END ===")
    }

    /// The status card must be ONE element speaking ONE sentence.
    ///
    /// The failure this guards against is specific: dropping
    /// `accessibilityElement(children: .ignore)` turns the card into nine
    /// focusable fragments, so a reader hears "Stop", swipe, "Door", swipe,
    /// "1.1 metres" instead of a sentence. When the thing being described is
    /// approaching, that is the difference between useful and useless.
    func testStatusCardIsOneElementWithASentence() throws {
        let expected = "Stopped. Press Start to begin detecting obstacles."
        // The card is an `Other` element, not a `staticText`:
        // `accessibilityElement(children: .ignore)` collapses the VStack into a
        // single container and the sentence becomes that container's label. An
        // earlier version of this test queried `staticTexts` and failed against
        // a perfectly working card, which is worth remembering — a failing
        // accessibility assertion is as likely to be the query's fault as the
        // app's.
        let card = app.otherElements[expected]
        XCTAssertTrue(card.waitForExistence(timeout: 5),
                      "No single element carries the whole status sentence. Tree:\n\(app.debugDescription)")
    }

    /// Every control names the action it performs, not the state it is in.
    func testControlsAreLabelled() throws {
        for label in ["Start detecting", "Speak nearest obstacle",
                      "Audio only", "Haptic only", "Both",
                      "Assist, prototype", "Detect, objects",
                      "Capture, ground truth", "Benchmark, latency"] {
            let element = app.descendants(matching: .any)[label]
            XCTAssertTrue(element.exists, "Nothing in the tree is labelled '\(label)'.")
        }
    }

    /// The selected tab and the selected feedback condition must report
    /// themselves as selected, or a reader cannot tell which is active.
    func testSelectionIsExposed() throws {
        XCTAssertTrue(app.buttons["Assist, prototype"].isSelected,
                      "The active tab does not carry the selected trait.")
        XCTAssertTrue(app.buttons["Both"].isSelected,
                      "The active feedback condition does not carry the selected trait.")
    }

    /// The Detect tab carries Assist's guarantees: the tab reports itself
    /// selected once chosen, its status card is one element speaking one
    /// sentence, and its controls name what they do. The screenshot is kept
    /// with the result bundle so the layout can be looked at, not just asserted.
    func testDetectModeIsNavigable() throws {
        let tab = app.buttons["Detect, objects"]
        XCTAssertTrue(tab.waitForExistence(timeout: 5), "No Detect tab in the tree.")
        tab.tap()
        XCTAssertTrue(tab.isSelected, "The Detect tab does not carry the selected trait once chosen.")

        let card = app.otherElements["Stopped. Press Start to see what the detector finds."]
        XCTAssertTrue(card.waitForExistence(timeout: 5),
                      "No single element carries the Detect status sentence. Tree:\n\(app.debugDescription)")

        for label in ["Start detecting objects", "Speak detected objects", "Confidence threshold"] {
            XCTAssertTrue(app.descendants(matching: .any)[label].exists,
                          "Nothing in the Detect tree is labelled '\(label)'.")
        }

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "detect_idle"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    /// Reports whether the preview, its overlays and the HUD reach a screen
    /// reader. **Reports — it does not assert**, because XCUITest cannot
    /// answer this question and pretending otherwise produces a red suite that
    /// says nothing.
    ///
    /// What was tried, so nobody repeats it: `.accessibilityHidden(true)` on
    /// the HUD; the same on its preview container; and
    /// `.accessibilityElement(children: .ignore)` followed by
    /// `.accessibilityHidden(true)`, which should collapse the subtree to one
    /// element and then remove it. Under every one of those, all three labels
    /// stayed both directly queryable and present in the raw tree, and the
    /// `children: .ignore` did not even merge them — which is the tell that
    /// XCUITest is reading a hierarchy these modifiers do not govern, rather
    /// than that the modifiers are absent.
    ///
    /// **SETTLED ON DEVICE, 18 September 2026: the modifiers work.** Checked
    /// with VoiceOver running on the iPhone 13 Pro Max — swiping from the top
    /// of the Assist screen reaches the status card without announcing
    /// "stopped", "nominal" or "Camera preview" on the way. So every label
    /// this test still prints is an XCUITest artifact and nothing else, and
    /// the earlier conclusion drawn from the direct-versus-enumerated query
    /// distinction was simply wrong. The output below is kept as a tripwire:
    /// if the set it prints ever *grows*, something new has been added to the
    /// preview without being hidden, which is worth re-checking on a device.
    func testReportPreviewExposure() throws {
        let decorative = ["stopped", "nominal", "Camera preview",
                          "Needs a LiDAR-equipped iPhone."]
        let direct = decorative.filter { app.staticTexts[$0].exists }
        print("=== PREVIEW EXPOSURE (informational) ===")
        print("directly queryable: \(direct)")
        print("NOTE: XCUITest does not honour SwiftUI's accessibilityHidden here;")
        print("      verify on a device with VoiceOver, not from this output.")
        print("=== END ===")
    }
}
