//
//  EmbeddedMessage.swift
//  StreamChatCore
//
//  Created by Carlos Triana on 25/03/20.
//  Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Foundation
public struct EmbeddedMessageInfo: Codable {
    public var html: String?
    public var thread_id: String?
    public var messageType: String?
    public var isTopicMessage: Bool?
}
