//
//  ComposerFileView.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 04/06/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import StreamChatCore
import SnapKit
import RxSwift

final class ComposerFileView: UIView {
    
    let disposeBag = DisposeBag()
    
    let iconView : UIImageView = {
        let imageView = UIImageView(image: UIImage.FileTypes.zip)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    lazy var fileNameLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = Fonts.bold.of(size: 14)
        label.textColor = UIColor(red: 49/255, green: 21/255, blue: 233/255, alpha: 1)

        return label
    }()
    
    private lazy var fileSizeLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.font = .chatSmallBold
        label.textColor = .chatGray
        label.text = " "
        return label
    }()
    
    var fileSize: Int64 = 0 {
        didSet {
            fileSizeLabel.text = fileSize > 0 ? AttachmentFile.sizeFormatter.string(fromByteCount: fileSize) : nil
        }
    }
    
    let removeButton: UIButton = {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(systemName: "minus"), for: .normal)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        button.tintColor = .white
        button.layer.cornerRadius = UIImage.Icons.close.size.width / 2
        return button
    }()
    
    private(set) lazy var progressView = UIProgressView(progressViewStyle: .default)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addSubview(iconView)
        addSubview(fileNameLabel)
        
        addSubview(removeButton)
        addSubview(progressView)
        progressView.progress = 0.3
        iconView.snp.makeConstraints { make in
            make.left.top.equalToSuperview().offset(CGFloat.composerFilePadding)
            make.bottom.equalToSuperview().offset(-CGFloat.composerFilePadding)
            make.width.equalTo(CGFloat.composerFileIconWidth)
            make.height.equalTo(CGFloat.composerFileIconHeight)
        }
        
        fileNameLabel.snp.makeConstraints { make in
            make.centerY.equalTo(iconView.snp.centerY).offset(1)
            make.left.equalTo(iconView.snp.right).offset(CGFloat.composerFilePadding)
            make.right.equalTo(removeButton.snp.left).offset(-CGFloat.composerFilePadding)
            make.width.lessThanOrEqualTo(200)
        }
    
        removeButton.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-CGFloat.composerFilePadding)
            make.centerY.equalTo(fileNameLabel.snp.centerY)
            make.width.height.equalTo(20)
        }
        
        removeButton.setContentHuggingPriority(.required, for: .horizontal)
        
        progressView.snp.makeConstraints { make in
            make.top.equalTo(fileNameLabel.snp.bottom)
            make.left.equalTo(iconView.snp.right).offset(CGFloat.composerFilePadding)
            make.right.equalTo(removeButton.snp.left).offset(-CGFloat.composerFilePadding)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    func updateRemoveButton(tintColor: UIColor?, action: @escaping () -> Void) {
        if let tintColor = tintColor {
            removeButton.tintColor = .white
            removeButton.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        }
        
        removeButton.rx.tap.subscribe(onNext: action).disposed(by: disposeBag)
    }
    
    func updateForProgress(_ progress: Float) {
        guard progress < 1 else {
            fileSizeLabel.isHidden = false
            progressView.isHidden = true
            return
        }
        
        fileSizeLabel.isHidden = true
        progressView.isHidden = false
        progressView.progress = progress
    }
    
    func updateForError(_ text: String) {
        progressView.isHidden = true
        fileSizeLabel.isHidden = false
        fileSizeLabel.text = text
        fileSizeLabel.textColor = UIColor.red.withAlphaComponent(0.7)
    }
}
