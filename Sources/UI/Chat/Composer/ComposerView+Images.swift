//
//  ComposerView+Images.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 04/06/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import SnapKit
import RxSwift
import RxCocoa
// MARK: - Images Collection View

extension ComposerView: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func setupImagesCollectionView() -> UICollectionView {
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.itemSize = CGSize(width: .composerAttachmentSize, height: .composerAttachmentSize)
        collectionViewLayout.minimumLineSpacing = .composerCornerRadius / 2
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 0, left: .composerCornerRadius, bottom: 0, right: .composerCornerRadius)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.isHidden = true
        collectionView.backgroundColor = backgroundColor
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(cellType: AttachmentCollectionViewCell.self)
        collectionView.snp.makeConstraints { $0.height.equalTo(CGFloat.composerAttachmentsHeight) }
        
        return collectionView
    }
    
    
    func setupFilesCollectionView() -> UICollectionView {
        let collectionViewLayout = UICollectionViewFlowLayout()
        collectionViewLayout.scrollDirection = .horizontal
        collectionViewLayout.itemSize = CGSize(width: 250, height: 40)
        collectionViewLayout.minimumLineSpacing = .composerCornerRadius / 2
        collectionViewLayout.minimumInteritemSpacing = 0
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 0, left: .composerCornerRadius, bottom: 0, right: .composerCornerRadius)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: collectionViewLayout)
        collectionView.isHidden = true
        collectionView.backgroundColor = backgroundColor
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(cellType: FileAttachmentCollectionViewCell.self)
        collectionView.snp.makeConstraints { $0.height.equalTo(50) }
        return collectionView
    }
    
    /// Add an image upload item for message attachments.
    ///
    /// - Parameter item: an image upload item.
    public func addImageUploaderItem(_ item: UploaderItem) {
        guard let uploader = uploader else {
            return
        }
        
        uploader.upload(item: item)
        updateImagesCollectionView()
        
        if !imageUploaderItems.isEmpty {
            imagesCollectionView.scrollToItem(at: .item(0), at: .right, animated: false)
        }
    }
    
    func updateImagesCollectionView() {
        imageUploaderItems = uploader?.items.filter({ $0.type != .file }) ?? []
        imagesCollectionView.reloadData()
        imagesCollectionView.isHidden = imageUploaderItems.isEmpty
        updateTextHeightIfNeeded()
        updateSendButton()
        updateStyleState()
        updateToolbarIfNeeded()
    }
    
    func updateFilesCollectionView() {
        fileUploaderItems = uploader?.items.filter({ $0.type == .file }) ?? []
        filesCollectionView.reloadData()
        filesCollectionView.isHidden = fileUploaderItems.isEmpty
        updateTextHeightIfNeeded()
        updateSendButton()
        updateStyleState()
        updateToolbarIfNeeded()
    }
    
    private func uploaderItem(at indexPath: IndexPath) -> UploaderItem? {
        let imageIndex = indexPath.item
        
        guard imageIndex >= 0, imageIndex < imageUploaderItems.count else {
            return nil
        }
        
        return imageUploaderItems[imageIndex]
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
        case filesCollectionView:
            return fileUploaderItems.count
        case imagesCollectionView:
            return imageUploaderItems.count
        default:
            return 0
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        switch collectionView {
        case filesCollectionView:
            return cellForFile(collectionView, cellForItemAt: indexPath)
        case imagesCollectionView:
            return cellForImage(collectionView, cellForItemAt: indexPath)
        default:
            return UICollectionViewCell()
        }
    }
    
    
    private func cellForFile(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let item = fileUploaderItems[indexPath.row]
        let cell = collectionView.dequeueReusableCell(for: indexPath) as FileAttachmentCollectionViewCell
        
        let fileView = cell.fileView
        fileView.iconView.image = item.fileType.icon
        fileView.backgroundColor = UIColor(red: 239/255, green: 237/255, blue: 255/255, alpha: 1)
        fileView.layer.cornerRadius = 6
        fileView.fileNameLabel.text = item.fileName
        fileView.fileSize = item.fileSize
        
        
        fileView.updateRemoveButton(tintColor: style?.textColor) { [weak self, weak item, weak fileView] in
            if let self = self, let item = item, let fileView = fileView {
                self.uploader?.remove(item)
                self.updateFilesCollectionView()
                self.updateSendButton()
            }
        }
        
        if item.attachment == nil, item.error == nil {
            cell.fileView.updateForProgress(item.lastProgress)
            
            item.uploading
                .observeOn(MainScheduler.instance)
                .do(onError: { [weak fileView] error in fileView?.updateForError("\(error)") },
                    onCompleted: { [weak self, weak fileView] in
                        fileView?.updateForProgress(1)
                        self?.updateSendButton()
                    },
                    onDispose: { [weak fileView, weak item] in
                        if let error = item?.error {
                            fileView?.updateForError("\(error)")
                        } else {
                            fileView?.updateForProgress(1)
                        }
                })
                .map { $0.progress }
                .bind(to: fileView.progressView.rx.progress)
                .disposed(by: fileView.disposeBag)
            
        } else if let error = item.error {
            fileView.updateForError("\(error)")
        }
        
        return cell
    }
    
    private func cellForImage(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(for: indexPath) as AttachmentCollectionViewCell
        
        guard let item = uploaderItem(at: indexPath) else {
            return cell
        }
        
        cell.imageView.image = item.image
        
        cell.updateRemoveButton(tintColor: style?.textColor) { [weak self] in
            if let self = self {
                self.uploader?.remove(item)
                self.updateImagesCollectionView()
                self.updateSendButton()
            }
        }
        
        if item.attachment == nil, item.error == nil {
            cell.updateForProgress(item.lastProgress)
            
            item.uploading
                .observeOn(MainScheduler.instance)
                .do(onError: { [weak cell] error in cell?.updateForError() },
                    onCompleted: { [weak self, weak cell] in
                        cell?.updateForProgress(1)
                        self?.updateSendButton()
                    },
                    onDispose: { [weak cell, weak item] in
                        if item?.error == nil {
                            cell?.updateForProgress(1)
                        } else {
                            cell?.updateForError()
                        }
                })
                .map { $0.progress }
                .bind(to: cell.progressView.rx.progress)
                .disposed(by: cell.disposeBag)
            
        } else if item.error != nil {
            cell.updateForError()
        }
        return cell
    }
    
    public func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        switch collectionView {
        case imagesCollectionView:
            if let cell = cell as? AttachmentCollectionViewCell,
                let item = uploaderItem(at: indexPath),
                let gifData = item.gifData {
                cell.startGifAnimation(with: gifData)
            }
            break
        default:
            break
        }
        
    }
    
    public func collectionView(_ collectionView: UICollectionView,
                               didEndDisplaying cell: UICollectionViewCell,
                               forItemAt indexPath: IndexPath) {
        switch collectionView {
        case imagesCollectionView:
            if let cell = cell as? AttachmentCollectionViewCell {
                cell.removeGifAnimation()
            }
        default:
            break
        }
        
    }
}
