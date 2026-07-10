import WebKit
import UIKit

/// Intercepts WKWebView file input taps and replaces with native UIDocumentPickerViewController.
/// This ensures the full native file picker (iCloud, Files, Photos) is available
/// rather than WKWebView's limited built-in handler.
extension WKWebView {

    /// Call in `webView(_:runOpenPanelWith:initiatedByFrame:completionHandler:)` (WKUIDelegate).
    static func handleFileUpload(
        parameters: WKOpenPanelParameters,
        from viewController: UIViewController,
        completion: @escaping ([URL]?) -> Void
    ) {
        var contentTypes: [UTType] = [.item]
        if parameters.allowsMultipleSelection {
            contentTypes = [.image, .pdf, .plainText, .data]
        }

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.allowsMultipleSelection = parameters.allowsMultipleSelection

        // Hold strong ref
        let adapter = DocumentPickerAdapter(completion: completion)
        picker.delegate = adapter
        objc_setAssociatedObject(picker, &AssociatedKey.adapter, adapter, .OBJC_ASSOCIATION_RETAIN)

        viewController.present(picker, animated: true)
    }
}

private final class DocumentPickerAdapter: NSObject, UIDocumentPickerDelegate {
    let completion: ([URL]?) -> Void
    init(completion: @escaping ([URL]?) -> Void) { self.completion = completion }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        completion(urls)
    }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion(nil)
    }
}

private enum AssociatedKey { static var adapter = "documentPickerAdapter" }

import UniformTypeIdentifiers
private typealias UTType = UniformTypeIdentifiers.UTType
