//
//  AttachmentFilePreview.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 12/04/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import SnapKit
import RxSwift

final class AttachmentFilePreview: UIImageView, AttachmentPreviewProtocol {
    
    let disposeBag = DisposeBag()
    var attachment: Attachment?
    
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView(frame: .zero)
        imageView.contentMode = .scaleToFill
        addSubview(imageView)
        
        imageView.snp.makeConstraints { make in
            make.left.equalToSuperview().offset(CGFloat.messageInnerPadding)
            make.top.equalToSuperview().offset(CGFloat.attachmentFileIconTop)
        }
        
        return imageView
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .chatMediumBold
        label.textColor = .chatBlue
        addSubview(label)
        
        label.snp.makeConstraints { make in
            make.bottom.equalTo(iconImageView.snp.centerY)
            make.left.equalTo(iconImageView.snp.right).offset(CGFloat.messageInnerPadding)
            make.right.equalToSuperview().offset(-CGFloat.messageEdgePadding)
        }
        
        return label
    }()
    
    private lazy var sizeLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .chatSmall
        label.textColor = .chatGray
        addSubview(label)
        
        label.snp.makeConstraints { make in
            make.top.equalTo(iconImageView.snp.centerY)
            make.left.equalTo(iconImageView.snp.right).offset(CGFloat.messageEdgePadding)
            make.right.equalToSuperview().offset(-CGFloat.messageEdgePadding)
        }
        
        return label
    }()
    
    func update(maskImage: UIImage?, _ completion: @escaping Competion) {
        guard let attachment = attachment, let file = attachment.file else {
            return
        }
        
        
        iconImageView.image = file.type.icon
        titleLabel.text = attachment.title
        sizeLabel.text = file.sizeString
        image = maskImage
    }
    
    
    func updateAttachmentLayout(_ message: Message) {
        sizeLabel.font = UIFont(name: "Lato-Regular", size: 11)
        iconImageView.contentMode = .scaleAspectFit
        titleLabel.font = UIFont(name: "Lato-Bold", size: 14)
        backgroundColor = UIColor(displayP3Red: 239/255, green: 237/255, blue: 255/255, alpha: 1)
        
        // Remove constraints
        iconImageView.snp.removeConstraints()
        titleLabel.snp.removeConstraints()
        sizeLabel.snp.removeConstraints()
        snp.removeConstraints()
        
        
        if !message.text.isEmpty {
            sizeLabel.textAlignment = .center
            snp.makeConstraints { make in
                make.width.equalTo(200)
            }
            
            iconImageView.snp.makeConstraints { make in
                make.top.equalToSuperview().offset(10)
                make.centerX.equalToSuperview()
                make.width.equalTo(50)
                make.height.equalTo(50)
            }
            
            titleLabel.snp.makeConstraints { make in
                make.top.equalTo(iconImageView.snp.bottom).offset(5)
                make.leading.equalToSuperview().offset(CGFloat.messageInnerPadding)
                make.trailing.equalToSuperview().offset(-CGFloat.messageInnerPadding)
            }
            
            sizeLabel.snp.makeConstraints { make in
                make.top.equalTo(titleLabel.snp.bottom).offset(5)
                make.leading.equalToSuperview().offset(CGFloat.messageInnerPadding)
                make.trailing.equalToSuperview().offset(-CGFloat.messageInnerPadding)
                make.bottom.equalToSuperview().offset(-10)
            }
        } else {
            sizeLabel.textAlignment = .left
            iconImageView.snp.makeConstraints { make in
                make.left.equalToSuperview().offset(CGFloat.messageInnerPadding)
                make.top.equalToSuperview().offset(20)
            }
            
            titleLabel.snp.makeConstraints { make in
                make.bottom.equalTo(iconImageView.snp.centerY)
                make.left.equalTo(iconImageView.snp.right).offset(CGFloat.messageInnerPadding)
                make.right.equalToSuperview().offset(-CGFloat.messageEdgePadding)
            }
            
            sizeLabel.snp.makeConstraints { make in
                make.top.equalTo(iconImageView.snp.centerY)
                make.left.equalTo(titleLabel.snp.left)
                make.right.equalToSuperview().offset(-CGFloat.messageEdgePadding)
                make.bottom.equalToSuperview().offset(-20)
            }
        }
    }
}
