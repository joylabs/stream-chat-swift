//
//  FileAttachmentCollectionViewCell.swift
//  StreamChatCore
//
//  Created by Carlos Triana on 20/02/20.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Foundation
import UIKit

public final class FileAttachmentCollectionViewCell: UICollectionViewCell, Reusable {

    var fileView: ComposerFileView = ComposerFileView(frame: .zero)
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(fileView)
        fileView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reset() {
        
    }
    
}
