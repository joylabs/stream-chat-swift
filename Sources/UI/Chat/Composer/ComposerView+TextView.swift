//
//  ComposerView+TextView.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 04/06/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit

// MARK: - Text View Height

extension ComposerView {
    
    func setupTextView() -> UITextView {
        let textView = UITextView(frame: .zero)
        textView.delegate = self
        textView.attributedText = attributedText()
        textView.showsVerticalScrollIndicator = false
        textView.showsHorizontalScrollIndicator = false
        textView.isScrollEnabled = false
        return textView
    }
    
    var textViewPadding: CGFloat {
        return baseTextHeight == .greatestFiniteMagnitude ? 0 : ((style?.height ?? .composerHeight) - baseTextHeight) / 2
    }
    
    private var textViewContentSize: CGSize {
        return textView.sizeThatFits(CGSize(width: textView.frame.width, height: .greatestFiniteMagnitude))
    }
    
    /// Update the height of the text view for a big text length.
    func updateTextHeightIfNeeded() {
        if baseTextHeight == .greatestFiniteMagnitude {
            let text = textView.attributedText
            textView.attributedText = attributedText(text: "Stream")
            baseTextHeight = textViewContentSize.height.rounded()
            textView.attributedText = text
        }
        
        updateTextHeight(textView.attributedText.length > 0 ? textViewContentSize.height.rounded() : baseTextHeight)
    }
    
    private func updateTextHeight(_ height: CGFloat) {
        //let heightConstraint = heightConstraint,
        
        imagesCollectionView.isHidden = imageUploaderItems.isEmpty
        filesStackView.isHidden = isUploaderFilesEmpty
        
        
        if imagesCollectionView.isHidden {
            belowImageViewTopConstraint?.deactivate()
            belowFileStackTopConstraint?.deactivate()
            defaultTopConstraint?.activate()
            
        } else {
            belowImageViewTopConstraint?.activate()
            belowFileStackTopConstraint?.deactivate()
            defaultTopConstraint?.deactivate()
        }
        
        if imagesCollectionView.isHidden {
            if filesStackView.isHidden {
                belowImageViewTopConstraint?.deactivate()
                belowFileStackTopConstraint?.deactivate()
                defaultTopConstraint?.activate()
            } else {
                belowImageViewTopConstraint?.deactivate()
                belowFileStackTopConstraint?.activate()
                defaultTopConstraint?.deactivate()
            }
        }
        textView.isScrollEnabled = height >= CGFloat.composerMaxHeight
        updateToolbarIfNeeded()
    }
    
    func updateToolbarIfNeeded() {

    }
}

// MARK: - Text View Delegate

extension ComposerView: UITextViewDelegate {
    
    public func textViewDidBeginEditing(_ textView: UITextView) {
        updateTextHeightIfNeeded()
        updateSendButton()
    }
    
    public func textViewDidEndEditing(_ textView: UITextView) {
        updateTextHeightIfNeeded()
        updatePlaceholder()
    }
    
    public func textViewDidChange(_ textView: UITextView) {
        updatePlaceholder()
        updateTextHeightIfNeeded()
    }
}
