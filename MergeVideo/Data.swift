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
        let emoji: Emoji = Emoji(key: "1", size: CGSize(width: 80, height: 80), path: "")
        let texts: [CommentPart] = [CommentPart.emoji(emoji),
                                    CommentPart.text("Hello")]
        return texts
        
    }
    
}


extension UIView {
    
    var x: CGFloat {
        get {
            return self.frame.origin.x
        } set(value) {
            self.frame.origin.x = value
        }
    }
    
    var y: CGFloat {
        get {
            return self.frame.origin.y
        } set(value) {
            self.frame.origin.y = value
        }
    }
    
    var w: CGFloat {
        get {
            return self.frame.size.width
        } set(value) {
            self.frame.size.width = value
        }
    }
    
    var h: CGFloat {
        get {
            return self.frame.size.height
        } set(value) {
            self.frame.size.height = value
        }
    }
}

extension UIFont {
    
    class func Font(_ size: CGFloat) -> UIFont! {
        guard let f = UIFont(name: ".SFUIDisplay-Light", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.light)
        }
        return f
    }
    
    class func FontMedium(_ size: CGFloat) -> UIFont! {
        guard let f = UIFont(name: ".SFUIDisplay-Medium", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.medium)
        }
        return f
    }
    
    class func FontRegular(_ size: CGFloat) -> UIFont! {
        guard let f = UIFont(name: ".SFUIDisplay-Regular", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.regular)
        }
        return f
    }
    
    class func FontBold(_ size: CGFloat) -> UIFont! {
        guard let f = UIFont(name: ".SFUIDisplay-Semibold", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.semibold)
        }
        return f
    }
    
    class func FontHardBold(_ size: CGFloat) -> UIFont! {
        guard let f = UIFont(name: ".SFUIDisplay-Bold", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.bold)
        }
        return f
    }
    
    class func FontHeavyBold(_ size: CGFloat) -> UIFont! {
        guard let f = UIFont(name: ".SFUIDisplay-Heavy", size: size) else {
            return UIFont.systemFont(ofSize: size, weight: UIFont.Weight.heavy)
        }
        return f
    }
    
    class func FontIcon(_ size: CGFloat) -> UIFont! {
        return UIFont(name: "Icon", size: size)
    }
    
    
}

