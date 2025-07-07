//
//  QuickLookController.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import Foundation
import QuickLook
import UIKit

class QuickLookController: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
    static let shared = QuickLookController()
    
    private var fileURL: URL?
    private var previewController: QLPreviewController?
    
    override private init() {
        super.init()
    }
    
    func previewFile(_ url: URL) {
        self.fileURL = url
        
        let controller = QLPreviewController()
        controller.dataSource = self
        controller.delegate = self
        previewController = controller
        
        if let rootViewController = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            var topController = rootViewController
            while let presentedController = topController.presentedViewController {
                topController = presentedController
            }
            
            topController.present(controller, animated: true, completion: nil)
        }
    }
    
    // MARK: - QLPreviewControllerDataSource
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return fileURL != nil ? 1 : 0
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        guard let url = fileURL else {
            fatalError("No URL to preview")
        }
        return url as QLPreviewItem
    }
    
    // MARK: - QLPreviewControllerDelegate
    
    func previewControllerDidDismiss(_ controller: QLPreviewController) {
        fileURL = nil
        previewController = nil
    }
} 