//
//  ComposeComment.swift
//  MergeVideo
//
//  Created by Nah on 10/10/17.
//  Copyright © 2017 Nah. All rights reserved.
//

import Foundation
import UIKit

//let displayWidth: CGFloat = min(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)
//let displayHeight: CGFloat = max(UIScreen.main.bounds.size.width, UIScreen.main.bounds.size.height)

//extension Optional {
//
//    var logable: Any {
//        switch self {
//        case .none:
//            return "⁉️"
//        case let .some(value):
//            return value
//        }
//    }
//}

struct ComposeComment {
    let comment: Comment
    let time: Double
    let place: CGFloat
}

struct Comment {
    
    let id: String
    let channelId: String
    let userId: String
    let content: String
    let avatarPath: String
    let importance: Double
    let sendTime: Date
    
    var isFollowing: Bool = false // Warning: Only update this value in WebSocketService
}

struct Emoji {
    
    let key: String
    let size: CGSize
    let path: String
}

enum CommentPart {
    
    case emoji(Emoji)
    case text(String)
    
    static func parse(_ message: String, _ emojis: [Emoji]) -> [CommentPart] {
        return []
    }
    
}


