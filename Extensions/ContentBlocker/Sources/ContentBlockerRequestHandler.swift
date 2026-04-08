import Foundation
import SafariServices
import AdBlockerCore

final class ContentBlockerRequestHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let store = RulesStore()
        store.ensureSeedRulesFromBundleIfNeeded(bundle: .main)

        let extensionItem = NSExtensionItem()
        guard let attachment = NSItemProvider(contentsOf: store.blockerListURL) else {
            context.cancelRequest(withError: NSError(domain: "ContentBlocker", code: 1))
            return
        }

        extensionItem.attachments = [attachment]
        context.completeRequest(returningItems: [extensionItem], completionHandler: nil)
    }
}
