//
//  MessageTableViewCell+Updates.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 03/05/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import RxSwift

// MARK: - Updates

extension MessageTableViewCell {
    
    func updateBackground(isContinueMessage: Bool, message: Message? = nil) {
        if let text = messageLabel.text, text.messageContainsOnlyEmoji {
            messageLabel.font = style.emojiFont
            messageLabel.backgroundColor = style.chatBackgroundColor
            return
        }
        messageContainerView.backgroundColor = .clear

        
        if let messageBackgroundImage = messageBackgroundImage(isContinueMessage: isContinueMessage) {
            
            if let message = message {
                if !message.text.isEmpty {
                    messageContainerView.layer.shadowOpacity = 0.18
                    messageContainerView.layer.shadowColor = message.isOwn ? UIColor(red: 107/255, green: 198/255, blue: 255, alpha: 1).cgColor : UIColor(red: 164/255, green: 172/255, blue: 179/255, alpha: 1).cgColor
                    messageContainerView.layer.shadowRadius = 2
                    messageContainerView.clipsToBounds = false
                    messageContainerView.layer.shadowOffset = message.isOwn ? CGSize(width: 2, height: 1) : CGSize(width: -1, height: -1)
                }

                
                
                let bundle = Bundle(for: MessageTableViewCell.self)
                let attachmentPath = message.attachments.isEmpty ? "" : "Attachment"
                let imagePath = message.isOwn ? "OutgoingMessage\(attachmentPath)Bg" : "IncomingMessage\(attachmentPath)Bg"
                let image = UIImage(named: imagePath, in: bundle, compatibleWith: nil)
                messageContainerView.image = image ?? messageBackgroundImage
                
                if !message.attachments.isEmpty {
                    if message.isOwn {
                        messageLabel.textAlignment = .right
                    } else {
                        messageLabel.textAlignment = .left
                    }
                }
                return
            }
            
            messageContainerView.image = messageBackgroundImage
        } else {
            messageContainerView.backgroundColor = .clear
            
            if style.borderWidth > 0 {
                messageContainerView.layer.borderWidth = style.borderWidth
                messageContainerView.layer.borderColor = style.borderColor.cgColor
            }
        }
    }
    
    private func messageBackgroundImage(isContinueMessage: Bool) -> UIImage? {
        guard style.hasBackgroundImage else {
            return nil
        }
        
        return style.alignment == .left
            ? (isContinueMessage ? style.backgroundImages[.leftSide] : style.backgroundImages[.leftBottomCorner])
            : (isContinueMessage ? style.backgroundImages[.rightSide] : style.backgroundImages[.rightBottomCorner])
    }
    
    func update(name: String? = nil, date: Date) {
        nameAndDateStackView.isHidden = false
        
        if style.alignment == .left, let name = name, !name.isEmpty {
            nameLabel.isHidden = false
            nameLabel.text = name
        } else {
            nameLabel.isHidden = true
        }
        
        dateLabel.text = date.relative
    }
    
    func update(replyCount: Int) {
        replyCountButton.isHidden = false
        replyCountButton.setTitle(" \(replyCount) \(replyCount > 1 ? "replies" : "reply") ", for: .normal)
        replyCountButton.setNeedsLayout()
    }
    
    func update(info: String?, date: Date? = nil) {
        guard let info = info else {
            return
        }
        
        infoLabel.text = info
        infoLabel.isHidden = false
    }
    
    func update(text: String) {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        messageContainerView.isHidden = text.isEmpty
        messageLabel.text = text
    }
    
    func enrichText(with message: Message, enrichURLs: Bool) {
        messageTextEnrichment = MessageTextEnrichment(message, style: style, enrichURLs: enrichURLs)
        
        messageTextEnrichment?.enrich()
            .take(1)
            .subscribeOn(SerialDispatchQueueScheduler(qos: .utility))
            .observeOn(MainScheduler.instance)
            .subscribe(onNext: { [weak self] in self?.messageLabel.attributedText = $0 })
            .disposed(by: disposeBag)
    }
    
    func update(reactionCounts: ReactionCounts?, action: @escaping ReactionAction) {
        guard let reactionCounts = reactionCounts,
            !reactionCounts.counts.isEmpty,
            let anchorView = messageStackView.arrangedSubviews.first(where: { !$0.isHidden }) else {
            return
        }
        
        let style = self.style.reactionViewStyle
        reactionsContainer.isHidden = false
        reactionsOverlayView.isHidden = false
        reactionsLabel.text = reactionCounts.string
        messageStackViewTopConstraint?.update(offset: CGFloat.messageSpacing + .reactionsHeight + .reactionsToMessageOffset)
        
        reactionsTailImage.snp.makeConstraints { make in
            let tailOffset: CGFloat = .reactionsToMessageOffset + style.tailCornerRadius - style.tailImage.size.width - 2
            
            if style.alignment == .left {
                self.reactionsTailImageLeftConstraint = make.left.equalTo(anchorView.snp.right).offset(tailOffset).constraint
            } else {
                self.reactionsTailImageRightConstraint = make.right.equalTo(anchorView.snp.left).offset(-tailOffset).constraint
            }
        }
        
        reactionsOverlayView.rx.tapGesture()
            .when(.recognized)
            .subscribe(onNext: { [weak self] gesture in
                if let self = self {
                    action(self, gesture.location(in: self.reactionsOverlayView))
                }
            })
            .disposed(by: disposeBag)
    }
}
