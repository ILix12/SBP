import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// UIKit is bridged because UIDocumentPicker provides the system Files experience.
struct SongDocumentPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick, onCancel: onCancel) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // Ask the system to derive a dynamic UTI from the extension. Files providers
        // often do not know an app-specific exported UTI until after installation.
        let sbpType = UTType(filenameExtension: "sbp") ?? UTType(exportedAs: "com.opensongbook.sbp")
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [sbpType], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.shouldShowFileExtensions = true
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void; let onCancel: () -> Void
        init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) { self.onPick = onPick; self.onCancel = onCancel }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { onCancel() }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { urls.forEach(onPick) }
    }
}
