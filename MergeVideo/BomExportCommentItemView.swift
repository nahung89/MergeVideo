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
        
    }
    
    func duration(width: CGFloat, defaultDuration: TimeInterval = 5) -> TimeInterval {
        return defaultDuration + Double(bounds.width / width) * defaultDuration
    }
}
