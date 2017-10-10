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

    var videoMerge: VideoMerge?
    
    @IBOutlet weak var labelProgress: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        createData()
    }

    func createData() {
        
        let url = Bundle.main.url(forResource: "20s", withExtension: "mp4")!
        let brushImage: UIImage = #imageLiteral(resourceName: "water_mark")
        
        videoMerge = VideoMerge(videoUrl: url, texts: [], brushImage: brushImage)
        
        let begin = Date();
        videoMerge?.startExportVideo(onProgress: { [unowned self] (progress) in
            self.labelProgress.text = "\(progress)"
            }, onCompletion: { [unowned self] (videoData, thumbData, error) in
                let endTime = Date().timeIntervalSince(begin)
                print("---------")
                
                print("Input: \(url)")
                print("Total time: \(endTime)")
                print("---------")
                
                print("video: \(String(describing: videoData?.description))")
                print("thumb: \(String(describing: thumbData?.description))")
                print("error: \(String(describing: error))")
                print("---------")
                
                if error == nil, let videoUrl = self.videoMerge?.exportedUrl {
                    print("url: \(videoUrl)")
                    print("---------")
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

