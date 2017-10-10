//
//  ViewController.swift
//  MergeVideo
//
//  Created by Nah on 10/3/17.
//  Copyright © 2017 Nah. All rights reserved.
//

import UIKit
import AVKit

class ViewController: UIViewController {

    @IBOutlet weak var labelProgress: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createData()
    }

    func createData() {
        
        // let videoNames: [String] = ["22s.mp4"]
        let videoNames: [String] = ["20s.mp4"]
        // let videoNames: [String] = ["video-1.mp4", "video-2.mp4", "video-3.mp4"]
        // let videoNames: [String] = ["video-1.mp4", "video-2.mp4", "video-3.mp4", "video-4.mp4", "video-5.mp4", "video-6.mp4"]
        
        var videoUrls: [URL] = []
        for videoName in videoNames {
            let namePaths = videoName.components(separatedBy: ".")
            guard namePaths.count == 2 else { continue }
            guard let url = Bundle.main.url(forResource: namePaths[0], withExtension: namePaths[1]) else { continue }
            videoUrls.append(url)
        }
        let brushImage: UIImage = #imageLiteral(resourceName: "water_mark")
        
        let videoMerge: VideoMerge = VideoMerge(videoUrls: videoUrls, texts: ["😃 😄 😅 😆","😊 😎 😇 😈", "😉 😋 😏 😌"], brushImage: brushImage)
        
        let begin = Date();
        videoMerge.startExportVideo(onProgress: { [unowned self] (progress) in
            self.labelProgress.text = "\(progress)"
            }, onCompletion: { [unowned self] (videoData, thumbData, error) in
                let endTime = Date().timeIntervalSince(begin)
                print("Input: \(videoNames)")
                print("Total time: \(endTime)")
                print("---------")
                
                print("video: \(String(describing: videoData?.description))")
                print("thumb: \(String(describing: thumbData?.description))")
                print("error: \(String(describing: error))")
                if error == nil, let videoUrl = videoMerge.exportUrl {
                    print("url: \(videoUrl)")
                    self.playVideo(url: videoUrl)
                }
        })
        
    }
    
    func playVideo(url: URL) {
        let player = AVPlayer(url: url)
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        present(playerViewController, animated: true) {
            playerViewController.player!.play()
        }
    }

}

