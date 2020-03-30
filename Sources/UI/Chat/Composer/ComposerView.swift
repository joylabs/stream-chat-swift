//
//  ComposerView.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 10/04/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import SnapKit
import RxSwift
import RxCocoa

/// A composer view.
public final class ComposerView: UIView {
    
    /// A composer view  style.
    public var style: ComposerViewStyle?
    
    private var styleState: ComposerViewStyle.State = .disabled {
        didSet {
            if styleState != oldValue, let style = style {
                let styleState = style.style(with: self.styleState)
                
                messagesContainer.layer.cornerRadius = 10
                messagesContainer.layer.borderWidth = styleStateStyle?.borderWidth ?? 0
                messagesContainer.layer.borderColor = styleStateStyle?.tintColor.cgColor ?? nil
                
                textView.tintColor = styleState.tintColor
                sendButton.tintColor = styleState.tintColor
                
                if self.styleState == .edit {
                    sendButton.setTitleColor(styleState.tintColor, for: .normal)
                } else if self.styleState == .active {
                    sendButton.setTitleColor(styleState.tintColor, for: .normal)
                }
            }
        }
    }
    
    private var styleStateStyle: ComposerViewStyle.Style? {
        return style?.style(with: styleState)
    }
    
    /// An `UITextView`.
    /// You have to use the `text` property to change the value of the text view.
    public private(set) lazy var textView = setupTextView()
    var textViewTopConstraint: Constraint?
    
    lazy var toolBar = UIToolbar(frame: .zero)
    
    /// An action for a plus button in the images attachments collection view.
    /// If it's nil, it will not be shown in the images collection view.
    public var imagesAddAction: AttachmentCollectionViewCell.TapAction?
    
    private var previousTextBeforeReset: NSAttributedString?
    private let disposeBag = DisposeBag()
    private(set) weak var heightConstraint: Constraint?
    
    var baseTextHeight = CGFloat.greatestFiniteMagnitude
    
    /// An images collection view.
    public private(set) lazy var imagesCollectionView = setupImagesCollectionView()
    public private(set) lazy var filesCollectionView = setupFilesCollectionView()
    public var imageUploaderItems: [UploaderItem] = []
    public var fileUploaderItems: [UploaderItem] = []
    
    /// Uploader for images and files.
    public var uploader: Uploader?
    
    /// An editing state of the composer.
    public var isEditing: Bool = false
    
    public var belowFileStackTopConstraint: Constraint?
    public var belowImageViewTopConstraint: Constraint?
    public var defaultTopConstraint: Constraint?
    
    
    public lazy var firstDivider: UIView = {
        let firstDivider = UIView()
        firstDivider.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        return firstDivider
    }()
    
    public lazy var secondDivider: UIView = {
        let secondDivider = UIView()
        secondDivider.isHidden = true
        secondDivider.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        return secondDivider
    }()
    
    public lazy var topicButton: UIButton = {
        let button = UIButton()
        button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 16, bottom: 4, right: 0)
        button.backgroundColor = UIColor(displayP3Red: 226/255, green: 246/255, blue: 253/255, alpha: 1)
        button.setTitleColor(UIColor(displayP3Red: 0, green: 155/255, blue: 234/255, alpha: 1), for: .normal)
        button.setTitle("TOPIC", for: .normal)
        button.titleLabel?.font = Fonts.bold.of(size: 12)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: -15, bottom: 0, right: 0)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -25, bottom: 0, right: 0)
        button.setImage(UIImage.Icons.topic, for: .normal)
        button.layer.cornerRadius = 8
        button.addTarget(self, action: #selector(dispatchTopicComposer), for: .touchUpInside)
        return button
    }()
    
    public lazy var topicTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "Type topic here"
        textField.font = Fonts.black.of(size: 14)
        textField.textColor = UIColor(red: 0, green: 155/255, blue: 234/255, alpha: 1)
        textField.isHidden = false
        return textField
    }()
    
    public lazy var topicActionsContainer: UIView = {
        let container = UIView()
        container.isHidden = true
        container.backgroundColor = UIColor(red: 226/255, green: 246/255, blue: 253/255, alpha: 1)
        container.layer.cornerRadius = 8
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 5
        stackView.distribution = .fillProportionally
        stackView.alignment = .center
        
        
        let closeButton = UIButton()
        closeButton.setImage(UIImage(systemName: "xmark.circle"), for: .normal)
        closeButton.tintColor = UIColor(red: 0, green: 155/255, blue: 234/255, alpha: 1)
        closeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        closeButton.addTarget(self, action: #selector(resetTopicButton), for: .touchUpInside)
        
        stackView.addArrangedSubview(topicTextField)
        stackView.addArrangedSubview(closeButton)
        container.addSubview(stackView)
        
        
        topicTextField.snp.makeConstraints { make in
            make.width.equalTo(120)
        }
        
        stackView.snp.makeConstraints { (make) in
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.top.equalToSuperview().offset(5)
            make.bottom.equalToSuperview().offset(-5)
        }
        return container
    }()
    
    public lazy var attachImageButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.Icons.attachImage, for: .normal)
        return button
    }()
    
    public lazy var attachDocumentButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage.Icons.attachDocument, for: .normal)
        return button
    }()
    
    public private(set) lazy var actionsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.spacing = 0
        stackView.addArrangedSubview(attachImageButton)
        stackView.addArrangedSubview(attachDocumentButton)
        return stackView
    }()
    
    public private(set) lazy var customStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        stackView.addArrangedSubview(topicButton)
        stackView.addArrangedSubview(topicActionsContainer)
        stackView.addArrangedSubview(actionsStackView)
        return stackView
    }()
    /// A placeholder label.
    /// You have to use the `placeholderText` property to change the value of the placeholder label.
    public private(set) lazy var placeholderLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.textColor = style?.placeholderTextColor
        textView.addSubview(label)
        
        label.snp.makeConstraints { make in
            make.left.equalTo(textView.textContainer.lineFragmentPadding)
            make.top.equalTo(textView.textContainerInset.top)
            make.right.equalToSuperview()
        }
        
        return label
    }()
    
    /// A send button.
    public private(set) lazy var sendButton: UIButton = {
        let button = UIButton(frame: .zero)
        button.setImage(UIImage.Icons.send, for: .normal)
        button.backgroundColor = backgroundColor
        button.titleLabel?.font = .chatMediumBold
        
        button.snp.makeConstraints {
            sendButtonWidthConstraint = $0.width.equalTo(CGFloat.composerButtonWidth).priority(999).constraint
        }
        
        return button
    }()
    
    public private(set) lazy var messagesContainer: UIView = {
        let view = UIView()
        view.addSubview(textView)
        view.addSubview(sendButton)
        return view
    }()
    
    let sendButtonVisibilityBehaviorSubject = BehaviorSubject<(isHidden: Bool, isEnabled: Bool)>(value: (false, false))
    /// An observable sendButton visibility state.
    public private(set) lazy var sendButtonVisibility = sendButtonVisibilityBehaviorSubject
        .distinctUntilChanged { lhs, rhs -> Bool in lhs.0 == rhs.0 && lhs.1 == rhs.1 }
    
    private var sendButtonWidthConstraint: Constraint?
    private var sendButtonRightConstraint: Constraint?
    
    /// An attachment button.
    public private(set) lazy var attachmentButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage.Icons.plus, for: .normal)
        button.snp.makeConstraints { $0.width.equalTo(CGFloat.composerButtonWidth).priority(999) }
        button.backgroundColor = backgroundColor
        return button
    }()
    
    /// The text of the text view.
    public var text: String {
        get {
            return textView.attributedText.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        set {
            textView.attributedText = attributedText(text: newValue)
            updatePlaceholder()
        }
    }
    
    /// The placeholder text.
    public var placeholderText: String {
        get { return placeholderLabel.attributedText?.string ?? "" }
        set { placeholderLabel.attributedText = attributedText(text: newValue, textColor: styleStateStyle?.tintColor) }
    }
    
    func attributedText(text: String = "", textColor: UIColor? = nil) -> NSAttributedString {
        guard let style = style else {
            return NSAttributedString(string: text)
        }
        
        return NSAttributedString(string: text, attributes: [.foregroundColor: textColor ?? style.textColor,
                                                             .font: style.font,
                                                             .paragraphStyle: NSParagraphStyle.default])
    }
    
    /// Toggle `isUserInteractionEnabled` states for all child views.
    public var isEnabled: Bool = true {
        didSet {
            if let style = style {
                sendButton.isEnabled = style.sendButtonVisibility == .whenActive ? isEnabled : false
                sendButtonVisibilityBehaviorSubject.onNext((sendButton.isHidden, sendButton.isEnabled))
            }
            
            // attachmentButton.isEnabled = isEnabled
            imagesCollectionView.isUserInteractionEnabled = isEnabled
            imagesCollectionView.alpha = isEnabled ? 1 : 0.5
            filesCollectionView.isUserInteractionEnabled = isEnabled
            filesCollectionView.alpha = isEnabled ? 1 : 0.5
            
            styleState = isEnabled ? .normal : .disabled
        }
    }
}

// MARK: - Add to Superview

public extension ComposerView {
    /// Add the composer to a view.
    ///
    /// - Parameters:
    ///   - view: a superview.
    ///   - placeholderText: a placeholder text.
    func addToSuperview(_ view: UIView, placeholderText: String = "Type here", setConstraints: Bool = true) {
        guard let style = style else {
            return
        }
        
        // Add to superview.
        view.addSubview(self)
        if setConstraints {
            snp.makeConstraints { make in
                make.left.equalTo(view.safeAreaLayoutGuide.snp.leftMargin)
                make.right.equalTo(view.safeAreaLayoutGuide.snp.rightMargin)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottomMargin)
            }
        }
        
        
        // Apply style.
        backgroundColor = .white
        clipsToBounds = true
        addSubview(firstDivider)
        addSubview(imagesCollectionView)
        addSubview(filesCollectionView)
        addSubview(secondDivider)
        addSubview(customStackView)
        addSubview(messagesContainer)
        
        firstDivider.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        secondDivider.snp.makeConstraints { make in
            make.top.equalTo(customStackView.snp.top)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        
        // Add buttons.
        if style.sendButtonVisibility != .none {
            sendButton.isHidden = style.sendButtonVisibility == .whenActive
            sendButton.isEnabled = style.sendButtonVisibility == .whenActive
            sendButton.setTitleColor(style.style(with: .active).tintColor, for: .normal)
            sendButton.setTitleColor(style.style(with: .disabled).tintColor, for: .disabled)
            sendButtonVisibilityBehaviorSubject.onNext((sendButton.isHidden, sendButton.isEnabled))
            
            sendButton.snp.makeConstraints { make in
                
                make.bottom.equalToSuperview().offset(-10)
                sendButtonRightConstraint = make.right.equalToSuperview().constraint
            }
        }
        
        imagesCollectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.left.right.equalToSuperview()
        }
        
        
        filesCollectionView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(4)
            make.left.right.equalToSuperview()
        }
        
        
        customStackView.setContentCompressionResistancePriority(.required, for: .vertical)
        customStackView.snp.makeConstraints { make in
            belowFileStackTopConstraint = make.top.equalTo(filesCollectionView.snp.bottom).offset(4).constraint
            belowFileStackTopConstraint?.deactivate()
            
            belowImageViewTopConstraint = make.top.equalTo(imagesCollectionView.snp.bottom).constraint
            belowImageViewTopConstraint?.deactivate()
            
            
            defaultTopConstraint = make.top.equalToSuperview().offset(4).constraint
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
        }
        
        attachDocumentButton.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.width.equalTo(50)
        }
        
        attachImageButton.snp.makeConstraints { make in
            make.height.equalTo(50)
            make.width.equalTo(50)
        }
        messagesContainer.setContentCompressionResistancePriority(.required, for: .vertical)
        messagesContainer.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.top.equalTo(customStackView.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-10)
        }
        
        
        updateTextHeightIfNeeded()
        textView.keyboardAppearance = style.textColor.isDark ? .default : .dark
        textView.backgroundColor = backgroundColor
        
        textView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(5)
            make.bottom.equalToSuperview().offset(-5)
            if sendButton.superview == nil {
                make.right.equalToSuperview().offset(-textViewPadding)
            } else {
                make.right.equalTo(sendButton.snp.left)
            }
            
            make.left.equalToSuperview().offset(textViewPadding)
        }
        
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        // Add placeholder.
        self.placeholderText = placeholderText
        updateToolbarIfNeeded()
        updateStyleState()
        
    }
    
    func hideTopicsButton(for type: ChatScreenType) {
        #if STAGING || DEVELOP || DEVELOP2
        topicActionsContainer.alpha = type == .topic ? 0 : 1
        topicButton.alpha = type == .topic ? 0 : 1
        #else
        topicActionsContainer.alpha = 0
        topicButton.alpha = 0 
        #endif
    }
    
    /// Reset states of all child views and clear all added/generated data.
    func reset() {
        isEnabled = true
        isEditing = false
        previousTextBeforeReset = textView.attributedText
        textView.attributedText = attributedText()
        uploader?.reset()
        imageUploaderItems = []
        updatePlaceholder()
        filesCollectionView.isHidden = true
        updateImagesCollectionView()
        updateFilesCollectionView()
        styleState = textView.isFirstResponder ? .active : .normal
    }
    
    @objc func dispatchTopicComposer(_ sender: UIButton) {
        topicButton.isHidden = true
        topicActionsContainer.isHidden = false
        topicTextField.becomeFirstResponder()
    }
    
    @objc func resetTopicButton(_sender: UIButton) {
        topicActionsContainer.isHidden = true
        topicButton.isHidden = false
        topicTextField.text = ""
    }
    
    /// Update the placeholder and send button visibility.
    func updatePlaceholder() {
        placeholderLabel.isHidden = textView.attributedText.length != 0
        DispatchQueue.main.async { [weak self] in self?.updateSendButton() }
    }
    
    internal func updateSendButton() {
        let isAnyFileUploaded = uploader?.items.first(where: { $0.attachment != nil }) != nil
        
        if let style = style {
            let isHidden = text.count == 0 && !isAnyFileUploaded
            
            if style.sendButtonVisibility == .whenActive {
                sendButton.isHidden = isHidden
            } else {
                sendButton.isEnabled = !isHidden
            }
            
            sendButtonVisibilityBehaviorSubject.onNext((sendButton.isHidden, sendButton.isEnabled))
        }
    }
    
    func updateStyleState() {
        guard styleState != .disabled else {
            return
        }
        
        styleState = !textView.isFirstResponder
            && imageUploaderItems.isEmpty
            && isUploaderFilesEmpty
            && text.isEmpty ? .normal : (isEditing ? .edit : .active)
    }
}

// MARK: - Send Button Customization

extension ComposerView {
    
    /// Replace send button image with a new image.
    ///
    /// - Parameters:
    ///   - image: a new send button image.
    ///   - buttonWidth: update the button width (optional).
    public func setSendButtonImage(_ image: UIImage, buttonWidth: CGFloat? = nil) {
        sendButton.setImage(image, for: .normal)
        
        if let buttonWidth = buttonWidth {
            sendButtonWidthConstraint?.update(offset: max(buttonWidth, image.size.width))
        }
    }
    
    /// Replace send button image with a title.
    ///
    /// - Parameters:
    ///   - title: a send button title
    ///   - rightEdgeOffset: a right edge inset for the title (optional).
    public func setSendButtonTitle(_ title: String, rightEdgeOffset: CGFloat = .messageEdgePadding) {
        sendButton.setImage(nil, for: .normal)
        sendButton.setTitle(title, for: .normal)
        sendButtonWidthConstraint?.deactivate()
        sendButtonWidthConstraint = nil
        sendButtonRightConstraint?.update(offset: -rightEdgeOffset)
    }
}

// MARK: - Blurred Background

private extension ComposerView {
    func addBlurredBackground(blurEffectStyle: UIBlurEffect.Style) {
        let isDark = blurEffectStyle == .dark
        
        guard !UIAccessibility.isReduceTransparencyEnabled else {
            backgroundColor = isDark ? .chatDarkGray : .chatComposer
            return
        }
        
        let blurEffect = UIBlurEffect(style: blurEffectStyle)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.isUserInteractionEnabled = false
        insertSubview(blurView, at: 0)
        blurView.makeEdgesEqualToSuperview()
        
        let adjustingView = UIView(frame: .zero)
        adjustingView.isUserInteractionEnabled = false
        adjustingView.backgroundColor = .init(white: isDark ? 1 : 0, alpha: isDark ? 0.25 : 0.1)
        insertSubview(adjustingView, at: 0)
        adjustingView.makeEdgesEqualToSuperview()
    }
}
