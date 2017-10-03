//
//  VideoMerge.swift
//  VideoMerge
//
//  Created by NAH on 2/11/17.
//  Copyright © 2017 NAH. All rights reserved.
//

import UIKit
import Foundation
import AVFoundation

typealias VideoExportProgressBlock = (Float) -> Void
typealias VideoExportCompletionBlock = (Data?, Data?, Error?) -> Void

class VideoMerge: NSObject {
    
    private enum State: Int {
        case none, merge, finish
    }
    
    private var videoUrls: [URL] = []
    private var texts: [String] = []
    private var brushImage: UIImage?
    
    private var exportSession: AVAssetExportSession?
    fileprivate(set) var exportUrl: URL?
    private var progressBlock: VideoExportProgressBlock?
    private var completionBlock: VideoExportCompletionBlock?
    
    private var state: State = .none
    
    
    private var textLabels: [UILabel] = []
    
    
    private let kVideoSize = CGSize(width: 400, height: 400)
    private let kExportDomain: String = "ExportErrorDomain"
    private let kExportCode: Int = -1
    
    // MARK: - Initialize
    
    init(videoUrls: [URL], texts: [String], brushImage: UIImage?) {
        self.videoUrls = videoUrls
        self.texts = texts
        self.brushImage = brushImage
        super.init()
        processExportVideo()
    }
    
    deinit {
        print("VideoMerge deinit")
    }
    
    // MARK: - Actions
    
    func startExportVideo(onProgress progressBlock: VideoExportProgressBlock? = nil, onCompletion completionBlock: VideoExportCompletionBlock? = nil) {
        
        self.progressBlock = progressBlock
        self.completionBlock = completionBlock
        
        // Has exported video
        if let url = exportUrl {
            finishExport(url, error: nil)
        }
        else if state == .merge {
            // Do nothing
        }
        else  {
            // Start processing
            processExportVideo()
        }
    }
    
    func stopExportVideo() {
        exportSession?.cancelExport()
        exportSession = nil
        state = .none
        textLabels.removeAll()
    }
    
    // MARK: - Exporter
    
    private func processExportVideo() {
        var error: Error?
        if let export = createExportSession(&error) {
            state = .merge
            exportSession = export
            handleExportSession(export)
        }
        else {
            state = .none
            finishExport(nil, error: error)
        }
    }
    
    private func handleExportSession(_ export: AVAssetExportSession) {
        
        
        DispatchQueue.global().async {
            print("Start: \(Date())")
            export.exportAsynchronously() {
                DispatchQueue.main.async { [weak self] () -> Void in
                    guard let this = self else { return }
                    switch export.status {
                    case .completed:
                        print("Complete: \(Date())")
                        this.exportUrl = export.outputURL
                        this.exportSession = nil
                        this.state = .finish
                        this.finishExport(export.outputURL, error: nil)
                        
                    case .unknown:
                        print("Unknown: \(Date())")
                        if FileManager.default.fileExists(atPath: export.outputURL!.path) {
                            this.exportUrl = export.outputURL
                            this.exportSession = nil
                            this.state = .finish
                            this.finishExport(export.outputURL, error: nil)
                        }
                        else {
                            this.exportSession = nil
                            this.state = .finish
                            this.finishExport(nil, error: export.error)
                        }
                        break
                        
                    case .exporting:
                        break;
                        
                    case .failed, .cancelled:
                        print("fail / cancel: \(String(describing: export.error))")
                        this.exportSession = nil
                        this.state = .finish
                        this.finishExport(nil, error: export.error)
                        break
                        
                    default:
                        print("unknown state")
                        break
                    }
                }
            }
            
            while export.status == .waiting || export.status == .exporting {
                DispatchQueue.main.async { [weak self] () -> Void in
                    guard let this = self else { return }
                    this.progressBlock?(export.progress)
                }
            }
        }
    }
    
    private func finishExport(_ url: URL?, error: Error?) {
        if let url = url {
            do {
                let videoData = try Data(contentsOf: url)
                let imageData = previewImageData(forVideoUrl: url)
                completionBlock?(videoData, imageData, nil)
            } catch let error {
                completionBlock?(nil, nil, error)
            }
        }
        else {
            completionBlock?(nil, nil, error)
        }
    }
    
    // MARK: - Ultilities
    
    private func createExportSession(_ error: inout Error?) -> AVAssetExportSession? {
        guard videoUrls.count > 0 else {
            let message = "Doesn't have any video to export."
            print(message)
            let userInfo: [String : Any] = [NSLocalizedDescriptionKey : message]
            error = NSError(domain: kExportDomain, code: kExportCode, userInfo: userInfo) as Error
            return nil
        }
        
        // Get asset from videos
        var assets: [AVAsset] = []
        
        for videoUrl in videoUrls {
            let asset = AVAsset(url: videoUrl)
            guard CMTimeGetSeconds(asset.duration) > 0 else {
                continue
            }
            assets.append(asset)
        }
        
        guard videoUrls.count == assets.count else {
            let message = "Number of video is different with number of assets: (\(videoUrls.count) & \(assets.count))"
            let userInfo: [String : Any] = [NSLocalizedDescriptionKey : message]
            error = NSError(domain: kExportDomain, code: kExportCode, userInfo: userInfo) as Error
            return nil
        }
        
        // Create input AVMutableComposition, hold our video AVMutableCompositionTrack list.
        let inputComposition = AVMutableComposition()
        // Add list videos into input composition
        let videoTracks = addVideo(toInputComposition: inputComposition, fromAssets: assets)
        // Add list audio into input composition
        _ = addAudio(toInputComposition: inputComposition, fromAssets: assets)
        
        // Check data before creating output instructions
        guard videoTracks.count == assets.count else {
            let message = "Number of video tracks is more than 1 or empty!"
            print(message)
            let userInfo: [String : Any] = [NSLocalizedDescriptionKey: message]
            error = NSError(domain: kExportDomain, code: kExportCode, userInfo: userInfo) as Error
            return nil
        }
        
        // Add video instructions
        let outputVideoInstructions = createOutputVideoInstruction(fromAssets: assets, videoTracks: videoTracks)
        
        // Get all video time length
        var totalVideoTimeLength = kCMTimeZero
        for asset in assets {
            totalVideoTimeLength = CMTimeAdd(totalVideoTimeLength, asset.duration)
        }
        
        // Output composition instruction
        let outputCompositionInstruction = AVMutableVideoCompositionInstruction()
        outputCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, totalVideoTimeLength)
        outputCompositionInstruction.layerInstructions = outputVideoInstructions
        
        // Output video composition
        let outputComposition = AVMutableVideoComposition()
        outputComposition.instructions = [outputCompositionInstruction]
        outputComposition.frameDuration = CMTimeMake(1, 30)
        outputComposition.renderSize = kVideoSize
        
        // Add effects
        addEffect(image: brushImage, texts: texts, withAssets: assets, toOutputComposition: outputComposition)
        
        // Create export session from input video & output instruction
        if let exportSession = AVAssetExportSession(asset: inputComposition, presetName: AVAssetExportPresetHighestQuality) {
            exportSession.videoComposition = outputComposition
            exportSession.outputFileType = AVFileType.mov
            exportSession.outputURL =  NSURL.fileURL(withPath: createCacheURL())
            exportSession.shouldOptimizeForNetworkUse = true
            return exportSession
        }
        else {
            let message = "Can not create export session."
            print(message)
            let userInfo: [String : Any] = [NSLocalizedDescriptionKey: message]
            error = NSError(domain: kExportDomain, code: kExportCode, userInfo: userInfo) as Error
            return nil
        }
    }
    
    private func addVideo(toInputComposition inputComposition: AVMutableComposition, fromAssets assets: [AVAsset]) -> [AVMutableCompositionTrack] {
        var videoTracks: [AVMutableCompositionTrack] = []
        var atTime = kCMTimeZero
        
        // Add video tracks
        for asset in assets {
            guard let track = inputComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { continue }
            do {
                // Important: only add track if has media type, or have to remove out of composition
                // Otherwise export session always fail with error code -11820
                if let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first {
                    try track.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoTrack, at: atTime)
                    videoTracks.append(track)
                }
                else {
                    inputComposition.removeTrack(track)
                }
                // Additive time for next asset
                atTime = CMTimeAdd(atTime, asset.duration)
            }
            catch let error as NSError {
                print("addVideoToInputComposition - Fail: \(error)")
            }
        }
        
        return videoTracks
    }
    
    private func addAudio(toInputComposition inputComposition: AVMutableComposition, fromAssets assets: [AVAsset]) -> [AVMutableCompositionTrack] {
        var audioTracks: [AVMutableCompositionTrack] = []
        var atTime = kCMTimeZero;
        
        // Add Audio tracks
        for asset in assets {
            guard let track = inputComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { continue }
            do {
                // Important: only add track if has media type, or have to remove out of composition
                // Otherwise export session always fail with error code -11820
                if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
                    try track.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioTrack, at: atTime)
                    audioTracks.append(track)
                }
                else {
                    inputComposition.removeTrack(track)
                }
                // Additive time for next asset
                atTime = CMTimeAdd(atTime, asset.duration)
            }
            catch let error as NSError {
                print("addAudioToInputComposition - Fail: \(error)")
            }
        }
        
        return audioTracks
    }
    
    private func createOutputVideoInstruction(fromAssets assets: [AVAsset], videoTracks:[AVCompositionTrack]) -> [AVMutableVideoCompositionLayerInstruction] {
        var outputVideoInstructions: [AVMutableVideoCompositionLayerInstruction] = []
        var totalVideoTime = kCMTimeZero
        
        // Add instruction for videos
        for i in 0..<assets.count {
            let asset = assets[i]
            let videoTrack = videoTracks[i]
            totalVideoTime = CMTimeAdd(totalVideoTime, asset.duration)
            
            let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
            instruction.setTransform(videoTrack.preferredTransform, at: kCMTimeZero)
            instruction.setOpacity(0.0, at: totalVideoTime)
            
            outputVideoInstructions.append(instruction)
        }
        return outputVideoInstructions
    }
    
    private func addEffect(image: UIImage?, texts: [String], withAssets assets: [AVAsset], toOutputComposition outputComposition: AVMutableVideoComposition) {
        guard texts.count == assets.count  else { return }
        
        // Text layer container
        let videoFrame = CGRect(origin: CGPoint.zero, size: outputComposition.renderSize)
        let overlayLayer = CALayer()
        overlayLayer.frame = videoFrame
        overlayLayer.masksToBounds = true
        
        let textFrame = videoFrame
        let font = UIFont.systemFont(ofSize: 40)
        var atTime: TimeInterval = 0.0
        
        for index in stride(from: 0, to: texts.count, by: 1) {
            let text = texts[index]
            let asset = assets[index]
            let assetDuration = CMTimeGetSeconds(asset.duration)
            
            guard !text.isEmpty else {
                atTime += assetDuration
                continue
            }
            
            // Creat megatext view layer & calculate font size
            let textLabel = UILabel(frame: textFrame)
            textLabel.text = text
            textLabel.font = font
            textLabel.textColor = UIColor.white
            textLabel.textAlignment = .center
            textLabel.layer.opacity = 0.0
            
            let animateAppear = CABasicAnimation(keyPath: "opacity")
            animateAppear.fromValue = 0.0
            animateAppear.toValue = 1.0
            animateAppear.beginTime = atTime + 0.01
            animateAppear.duration = 0.0
            animateAppear.isRemovedOnCompletion = false
            animateAppear.fillMode = kCAFillModeForwards
            
            let animateDisappear = CABasicAnimation(keyPath: "opacity")
            animateDisappear.fromValue = 1.0
            animateDisappear.toValue = 0.0
            animateDisappear.beginTime = atTime + assetDuration
            animateDisappear.duration = 0.0
            animateDisappear.isRemovedOnCompletion = false
            animateDisappear.fillMode = kCAFillModeForwards
            
            textLabel.layer.add(animateAppear, forKey: "appear")
            textLabel.layer.add(animateDisappear, forKey: "disappear")
            
            // Insert megatext layer
            overlayLayer.addSublayer(textLabel.layer)
            textLabels.append(textLabel)
            
            atTime += assetDuration
        }
        
        let parentLayer = CALayer()
        parentLayer.frame = videoFrame
        
        let videoLayer = CALayer()
        videoLayer.frame = videoFrame
        
        let imageView = UIImageView(frame: CGRect(x: 10, y: 10, width: 60, height: 20))
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = UIColor.yellow
        imageView.image = image
        
        parentLayer.addSublayer(videoLayer)
        parentLayer.addSublayer(imageView.layer)
        parentLayer.addSublayer(overlayLayer)
        
        
        //        // Add credit layer
        //        if _creditView != nil && _creditView?.text != nil {
        //            let animateAppear = CABasicAnimation(keyPath: "opacity")
        //            animateAppear.fromValue = 0.0
        //            animateAppear.toValue = 1.0
        //            animateAppear.beginTime = atTime - 2.0
        //            animateAppear.duration = 0.0
        //            animateAppear.removedOnCompletion = false
        //            animateAppear.fillMode = kCAFillModeForwards
        //
        //            _creditView?.layer.opacity = 0.0
        //            _creditView?.layer.addAnimation(animateAppear, forKey: "appear")
        //            parentLayer.addSublayer(_creditView!.layer)
        //        }
        
        outputComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
    }
    
    private func createCacheURL() -> String {
        // Create export path
        let documentDirectory = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let outputFileName = ProcessInfo.processInfo.globallyUniqueString as NSString
        let cachePath = (documentDirectory as NSString).appendingPathComponent("mergeVideo-\(outputFileName).mov")
        let outputURL = URL(fileURLWithPath: cachePath)
        
        // Remove existing file at url if has any
        do {
            try FileManager.default.removeItem(at: outputURL)
            print("remove file at path \(outputURL) \n")
        }
        catch _ { }
        
        return cachePath
    }
    
}

extension VideoMerge {
    fileprivate func previewImageData(forVideoUrl url: URL?) -> Data? {
        guard let url = url else { return  nil }
        
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        
        // let composition = AVVideoComposition(propertiesOfAsset: asset)
        // var time = composition.frameDuration
        var time = asset.duration
        time.value = min(asset.duration.value, 1)
        
        do {
            let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let image = UIImage(cgImage: imageRef)
            return UIImageJPEGRepresentation(image, 0.9)
        }
        catch let error as NSError {
            print("previewImage(forVideoUrl:) fail - \(error)")
            return nil
        }
    }
    
}
