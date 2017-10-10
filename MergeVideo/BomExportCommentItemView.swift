//
//  BomExport.swift
//  MergeVideo
//
//  Created by Nah on 10/10/17.
//  Copyright © 2017 Nah. All rights reserved.
//

import Foundation
import UIKit

class BomExportCommentItemView: UIView {
    
    init(parts: [CommentPart]) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 64))
        setCommentParts(parts)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    fileprivate func setCommentParts(_ parts: [CommentPart]) {
        var maxX: CGFloat = 0
        
        for part in parts {
            switch part {
            case let .emoji(emoji):
                let ih: CGFloat = 64
                let imageView = UIImageView(frame: CGRect(x: maxX, y: 0, width: ih, height: ih))
                addSubview(imageView)
                maxX += imageView.w
                
            case let .text(message):
                let label = UILabel(frame: CGRect(x: maxX, y: 0, width: 0, height: h))
                label.font = .FontHardBold(35)
                label.textColor = .white
                label.text = message
                label.sizeToFit()
                label.h = h
                addSubview(label)
                maxX += label.w
            }
        }
        w = maxX
    }
    
    func duration(width: CGFloat, defaultDuration: TimeInterval = 5) -> TimeInterval {
        return defaultDuration + Double(bounds.width / width) * defaultDuration
    }
}
