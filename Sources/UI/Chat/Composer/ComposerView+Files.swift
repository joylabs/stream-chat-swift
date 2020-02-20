//
//  ComposerView+Files.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 04/06/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import RxSwift

extension ComposerView {
    
    func setupFilesStackView() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.isHidden = true
        return stackView
    }
    
    /// Add a file upload item for message attachments.
    ///
    /// - Parameter item: a file upload item.
    public func addFileUploaderItem(_ item: UploaderItem) {
        guard let uploader = uploader else {
            return
        }
        
        filesCollectionView.isHidden = false
        fileUploaderItems.append(item)
        uploader.upload(item: item)
        updateFilesCollectionView()
    }
    
    public func removeFileUploaderItem(_ itemUploader: UploaderItem) {
        self.fileUploaderItems = self.fileUploaderItems.filter { (uploader) -> Bool in
            uploader.url != itemUploader.url
        }
    }
    
    var isUploaderFilesEmpty: Bool {
        return (uploader?.items.firstIndex(where: { $0.type == .file })) == nil
    }
}
