import SwiftUI
import UIKit

/// Presents the system "Save to Files" flow (Files app, iCloud Drive, AirDrop,
/// etc.) for the whole Captures directory, as a copy so the on-device
/// originals stay put.
struct DirectoryExporterView: UIViewControllerRepresentable {
    let directoryURL: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [directoryURL], asCopy: true)
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}
