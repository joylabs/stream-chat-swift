//
//  ChatViewController+Composer.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 13/05/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import Photos.PHPhotoLibrary
import SnapKit
import RxSwift
import RxCocoa

// MARK: Setup Keyboard Events

extension Reactive where Base: ChatViewController {
    var keyboard: Binder<KeyboardNotification> {
        return Binder<KeyboardNotification>(base) { chatViewController, keyboardNotification in
            var bottom: CGFloat = 0
            if keyboardNotification.isVisible {
                bottom = keyboardNotification.height
                    - chatViewController.composerView.toolBar.frame.height
                    - chatViewController.initialSafeAreaBottom
            } else {
                chatViewController.composerView.textView.resignFirstResponder()
            }
            
            var contentOffset = CGPoint.zero
            
            let contentHeight = chatViewController.tableView.contentSize.height
                + chatViewController.tableView.contentInset.top
                + chatViewController.tableView.contentInset.bottom
            
            let tableHeight = chatViewController.tableView.bounds.height - keyboardNotification.height
            
            if keyboardNotification.animation != nil,
                keyboardNotification.isVisible,
                !chatViewController.keyboardIsVisible,
                tableHeight < contentHeight {
                contentOffset = chatViewController.tableView.contentOffset
                contentOffset.y += min(bottom, contentHeight - tableHeight)
            }
            
            func animations() {
                chatViewController.view.removeAllAnimations()
                chatViewController.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: bottom, right: 0)
                
                if keyboardNotification.animation != nil {
                    if keyboardNotification.isVisible {
                        if contentOffset != .zero {
                            chatViewController.tableView.setContentOffset(contentOffset, animated: false)
                            chatViewController.keyboardIsVisible = true
                        }
                    } else {
                        chatViewController.keyboardIsVisible = false
                    }
                    
                    chatViewController.view.layoutIfNeeded()
                }
            }
            
            if let animation = keyboardNotification.animation {
                UIView.animate(withDuration: animation.duration,
                               delay: 0,
                               options: [animation.curve, .beginFromCurrentState],
                               animations: animations)
            } else {
                animations()
            }
            
            DispatchQueue.main.async { chatViewController.composerView.updateStyleState() }
        }
    }
}

// MARK: - Composer

public extension ChatViewController {
    enum ComposerAddFileType {
        case photo
        case camera
        case file
        case custom(icon: UIImage?, title: String, ComposerAddFileView.SourceType, ComposerAddFileView.Action)
    }
}

// MARK: Setup

extension ChatViewController {
    
    func createComposerView() -> ComposerView {
        let composerView = ComposerView(frame: .zero)
        composerView.style = style.composer
        return composerView
    }
    
    func setupComposerView() {
        guard composerView.superview == nil else {
            return
        }
        
        composerContainerView = UIView()
        composerContainerView.backgroundColor = .random
        
        composerView.attachmentButton.isHidden = composerAddFileContainerView == nil
        composerView.addToSuperview(composerContainerView)
        
        
        toolbar.backgroundColor = .yellow
        toolbar.setItems([UIBarButtonItem(customView: composerContainerView)], animated: false)
        
        
        view.addSubview(toolbar)
        
        toolbar.snp.makeConstraints { (make) in
            make.leading.bottom.trailing.equalToSuperview()
        }
        
//        containerView.snp.makeConstraints { (make) in
//            make.leading.bottom.trailing.equalToSuperview()
//        }
        
        composerView.hideTopicsButton(for: type)
                
        tableView.snp.makeConstraints { make in
            make.top.equalTo(aboutThisConversationView.snp.bottom)
            make.leading.trailing.equalToSuperview()
            
        }
        
        composerView.attachDocumentButton.rx.tap
            .subscribe(onNext: { [weak self] in self?.showDocumentPicker() })
            .disposed(by: disposeBag)
        

        composerView.attachImageButton.rx.tap
            .subscribe(onNext: { [weak self] in
                guard let _self = self else { return }
                self?.showImagePicker(composerAddFileViewSourceType: .photo(.photoLibrary))
                
            })
            .disposed(by: disposeBag)
        
        
        if let composerAddFileContainerView = composerAddFileContainerView {
            composerAddFileContainerView.add(to: composerView)
            
            composerView.attachmentButton.rx.tap
                .subscribe(onNext: { [weak self] in self?.showAddFileView() })
                .disposed(by: disposeBag)
        }

        composerView.textView.rx.text
            .skip(1)
            .unwrap()
            .do(onNext: { [weak self] in self?.dispatchCommands(in: $0) })
            .filter { [weak self] in !$0.isBlank && (self?.channelPresenter?.channel.config.typingEventsEnabled ?? false) }
            .flatMapLatest { [weak self] text in self?.channelPresenter?.sendEvent(isTyping: true) ?? .empty() }
            .debounce(.seconds(3), scheduler: MainScheduler.instance)
            .flatMapLatest { [weak self] text in self?.channelPresenter?.sendEvent(isTyping: false) ?? .empty() }
            .subscribe()
            .disposed(by: disposeBag)
        
        
        sendButtonTapSubscription = composerView.sendButton.rx.tap
        .subscribe(onNext: { [weak self] in self?.send() })
        sendButtonTapSubscription?.disposed(by: disposeBag)
        
        
        Keyboard.shared.notification
            .filter { $0.isHidden }
            .subscribe(onNext: { [weak self] _ in self?.showCommands(show: false) })
            .disposed(by: disposeBag)
    }
    
    private func dispatchCommands(in text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        showCommandsIfNeeded(for: trimmedText)
        
        // Send command by <Return> key.
        if composerCommandsContainerView.shouldBeShown, text.contains("\n"), trimmedText.contains(" ") {
            composerView.textView.text = trimmedText
            send()
        }
    }
    
    // MARK: Send Message
    
    /// Send a message.
    public func send() {
        let hasTopic = !(composerView.topicTextField.text?.isEmpty ?? true)
        let originalMessage = composerView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        var text = originalMessage
        if hasTopic, let topicText = composerView.topicTextField.text {
            text = topicText
        }
        
        let isMessageEditing = channelPresenter?.editMessage != nil
        
        if findCommand(in: text) != nil || isMessageEditing {
            view.endEditing(true)
        }
        
        if isMessageEditing {
            composerEditingContainerView.animate(show: false)
        }
        
        composerView.isEnabled = false
        
        channelPresenter?.send(text: text)
            .subscribe(
                onNext: { [weak self] messageResponse in
                    if messageResponse.message.type == .error {
                        self?.show(error: ClientError.errorMessage(messageResponse.message))
                    } else {
                        if hasTopic {
                            guard let _self = self else { return }
                            _self.channelPresenter?.send(text: originalMessage, parentIdMessage: messageResponse.message.id).subscribe(onNext: { replyMessage in
                                self?.composerView.topicTextField.text = ""
                                _self.redirectToTopic?( messageResponse.message, _self, _self.channelPresenter)
                            }, onError: { [weak self] in
                                self?.show(error: $0)
                            }, onCompleted: {
                                print("complete")
                            }).disposed(by: _self.disposeBag)
                        }
                    }
                },
                onError: { [weak self] in
                    self?.composerView.reset()
                    self?.show(error: $0)
                },
                onCompleted: { [weak self] in self?.composerView.reset() })
            .disposed(by: disposeBag)
    }
    
    private func findCommand(in text: String) -> String? {
        guard text.count > 1, text.hasPrefix("/") else {
            return nil
        }
        
        var command: String
        
        if let spaceIndex = text.firstIndex(of: " ") {
            command = String(text.prefix(upTo: spaceIndex))
        } else {
            command = text
        }
        
        command = command.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .init(charactersIn: "/"))
        
        return command.isBlank ? nil : command
    }
    
    public func createComposerHelperContainerView(title: String,
                                                  closeButtonIsHidden: Bool = false) -> ComposerHelperContainerView {
        let container = ComposerHelperContainerView()
        container.backgroundColor = style.composer.helperContainerBackgroundColor
        container.titleLabel.text = title
        container.add(to: composerView)
        container.isHidden = true
        container.closeButton.isHidden = closeButtonIsHidden
        return container
    }
}

// MARK: - Composer Edit

extension ChatViewController {
    func createComposerEditingContainerView() -> ComposerHelperContainerView {
        let container = createComposerHelperContainerView(title: "Edit message")
        
        container.closeButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                if let self = self {
                    self.channelPresenter?.editMessage = nil
                    self.composerView.reset()
                    self.hideAddFileView()
                    self.composerEditingContainerView.animate(show: false)
                    
                    if self.composerView.textView.isFirstResponder {
                        self.composerView.textView.resignFirstResponder()
                    }
                }
            })
            .disposed(by: disposeBag)
        
        return container
    }
}

// MARK: - Composer Commands

extension ChatViewController {

    
    func createComposerCommandsContainerView() -> ComposerHelperContainerView {
        let container = createComposerHelperContainerView(title: "Commands", closeButtonIsHidden: true)
        container.isEnabled = !(channelPresenter?.channel.config.commands.isEmpty ?? true)
        
        if container.isEnabled, let channelConfig = channelPresenter?.channel.config {
            channelConfig.commands.forEach { command in
                let view = ComposerCommandView(frame: .zero)
                view.backgroundColor = container.backgroundColor
                view.update(command: command.name, args: command.args, description: command.description)
                container.containerView.addArrangedSubview(view)
                
                view.rx.tapGesture().when(.recognized)
                    .subscribe(onNext: { [weak self] _ in self?.addCommandToComposer(command: command.name) })
                    .disposed(by: self.disposeBag)
            }
        }
        
        return container
    }
    
    private func showCommandsIfNeeded(for text: String) {
        guard composerCommandsContainerView.isEnabled else {
            return
        }
        
        // Show composer helper container.
        if text.count == 1, let first = text.first, first == "/" {
            hideAddFileView()
            showCommands()
            return
        }
        
        if textHasCommand(text) {
            hideAddFileView()
            showCommands()
        } else {
            showCommands(show: false)
        }
    }
    
    func textHasCommand(_ text: String) -> Bool {
        guard !text.isBlank, text.first == "/" else {
            return false
        }
        
        guard let command = findCommand(in: text) else {
            composerCommandsContainerView.containerView.arrangedSubviews.forEach { $0.isHidden = false }
            return false
        }
        
        var visible = false
        let hasSpace = text.contains(" ")
        
        composerCommandsContainerView.containerView.arrangedSubviews.forEach {
            if let commandView = $0 as? ComposerCommandView {
                commandView.isHidden = hasSpace ? commandView.command != command : !commandView.command.hasPrefix(command)
                visible = visible || !commandView.isHidden
            }
        }
        
        return visible
    }
    
    private func showCommands(show: Bool = true) {
        composerCommandsContainerView.animate(show: show)
        composerView.textView.autocorrectionType = show ? .no : .default
        
        if composerEditingContainerView.isHidden == false {
            composerEditingContainerView.moveContainerViewPosition(aboveView: show ? composerCommandsContainerView : nil)
        }
    }
    
    func addCommandToComposer(command: String) {
        let trimmedText = composerView.textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard trimmedText.contains(" ") else {
            composerView.textView.text = "/\(command) "
            return
        }
    }
}

// MARK: - Composer Attachments

extension ChatViewController {
    
    /// Creates a add files container view for the composer view when the add button ⊕ is tapped.
    ///
    /// - Returns: a container helper view.
    open func createComposerAddFileContainerView(title: String) -> ComposerHelperContainerView? {
        guard let presenter = channelPresenter, presenter.channel.config.uploadsEnabled, !composerAddFileTypes.isEmpty else {
            return nil
        }
        
        let container = createComposerHelperContainerView(title: title)
        
        container.closeButton.rx.tap
            .subscribe(onNext: { [weak self] _ in self?.hideAddFileView() })
            .disposed(by: disposeBag)
        
        composerAddFileTypes.forEach { type in
            switch type {
            case .photo:
                if UIImagePickerController.hasPermissionDescription(for: .savedPhotosAlbum),
                    UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
                    addButtonToAddFileView(container,
                                           icon: UIImage.Icons.images,
                                           title: "Upload a photo or video",
                                           sourceType: .photo(.savedPhotosAlbum)) { [weak self] in
                                            guard let _self = self else { return }
                                            self?.showImagePicker(composerAddFileViewSourceType: $0)
                    }
                    
                    composerView.imagesAddAction = { [weak self] _ in
                        guard let _self = self else { return }
                        self?.showImagePicker(composerAddFileViewSourceType: .photo(.savedPhotosAlbum))
                    }
                }
            case .camera:
                if UIImagePickerController.hasPermissionDescription(for: .camera),
                    UIImagePickerController.isSourceTypeAvailable(.camera) {
                    addButtonToAddFileView(container,
                                           icon: UIImage.Icons.camera,
                                           title: "Upload from a camera",
                                           sourceType: .photo(.camera)) { [weak self] in
                                            guard let _self = self else { return }
                                            self?.showImagePicker(composerAddFileViewSourceType: $0)
                    }
                }
            case .file:
                addButtonToAddFileView(container,
                                       icon: UIImage.Icons.file,
                                       title: "Upload a file",
                                       sourceType: .file) { [weak self] _ in
                                        guard let _self = self else { return }
//                                        self?.showDocumentPicker()
                }
            case let .custom(icon, title, sourceType, action):
                addButtonToAddFileView(container,
                                       icon: icon,
                                       title: title,
                                       sourceType: sourceType,
                                       action: action)
            }
        }
        
        return container
    }
    
    private func addButtonToAddFileView(_ container: ComposerHelperContainerView,
                                        icon: UIImage?,
                                        title: String,
                                        sourceType: ComposerAddFileView.SourceType,
                                        action: @escaping ComposerAddFileView.Action) {
        let view = ComposerAddFileView(icon: icon, title: title, sourceType: sourceType, action: action)
        view.backgroundColor = container.backgroundColor
        container.containerView.addArrangedSubview(view)
    }
    
    private func showAddFileView() {
        guard let composerAddFileContainerView = composerAddFileContainerView,
            !composerAddFileContainerView.containerView.arrangedSubviews.isEmpty else {
            return
        }
        
        showCommands(show: false)
        
        composerAddFileContainerView.containerView.arrangedSubviews.forEach { subview in
            if let addFileView = subview as? ComposerAddFileView {
                if case .file = addFileView.sourceType {
                    addFileView.isHidden = !composerView.imageUploaderItems.isEmpty
                } else {
                    addFileView.isHidden = !composerView.isUploaderFilesEmpty
                }
            }
        }
        
        let subviews = composerAddFileContainerView.containerView.arrangedSubviews.filter { $0.isHidden == false }
        
        if subviews.count == 1, let first = subviews.first as? ComposerAddFileView {
            first.tap()
        } else {
            if composerView.textView.frame.height > (.composerMaxHeight / 2)
                || (UIDevice.isPhone && UIDevice.current.orientation.isLandscape) {
                composerView.textView.resignFirstResponder()
            }
            
            composerAddFileContainerView.animate(show: true)
            
            if composerEditingContainerView.isHidden == false {
                composerEditingContainerView.moveContainerViewPosition(aboveView: composerAddFileContainerView)
            }
        }
    }
    
    /// Hide add file view.
    public func hideAddFileView() {
        guard let composerAddFileContainerView = composerAddFileContainerView else {
            return
        }
        
        composerAddFileContainerView.animate(show: false)
        composerCommandsContainerView.containerView.arrangedSubviews.forEach { $0.isHidden = false }
        
        if composerEditingContainerView.isHidden == false {
            composerEditingContainerView.moveContainerViewPosition()
        }
    }
    
    public func showImagePicker(composerAddFileViewSourceType sourceType: ComposerAddFileView.SourceType) {
        StreamPickersController.presentImagePicker(vc: self, composerView: composerView, channel: self.channelPresenter?.channel, composerAddFileViewSourceType: sourceType, disposeBag: disposeBag)
        hideAddFileView()
    }
    

    private func showDocumentPicker() {
        StreamPickersController.showDocument(vc: self, composerView: composerView, channel: self.channelPresenter?.channel, disposeBag: disposeBag)
        hideAddFileView()
    }
}

// MARK: Ephemeral Message Action

extension ChatViewController {
    func sendActionForEphemeral(message: Message, button: UIButton) {
        let buttonText = button.title(for: .normal)
        
        guard let attachment = message.attachments.first,
            let action = attachment.actions.first(where: { $0.text == buttonText }) else {
                return
        }
        
        channelPresenter?.dispatch(action: action, message: message).subscribe().disposed(by: disposeBag)
    }
}
// MARK:- Memo Custom

enum AttachmentError: Error {
    case size
    case maxNumberOfItems
    case extensionNotAllowed
}

extension AttachmentError: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .size:
                return NSLocalizedString(
                    "This file is more than 25mb, please upload a smaller file.",
                    comment: ""
                )
            case .maxNumberOfItems:
                return NSLocalizedString(
                    "Sorry, only one file per message.",
                    comment: ""
                )
            case .extensionNotAllowed:
                return NSLocalizedString(
                    "This type of file is not allowed.",
                    comment: ""
                )
                
        }
    }
}


extension UIViewController {
    func showAlertError(_ message: String) {
        let alert = UIAlertController(title: "Memo", message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

        self.present(alert, animated: true)
    }
}

extension ChatViewController {
    


}
