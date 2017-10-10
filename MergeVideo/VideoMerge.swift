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
    
    private var videoUrl: URL
    private var texts: [ComposeComment] = []
    private var brushImage: UIImage?
    
    private var exportSession: AVAssetExportSession?
    fileprivate(set) var exportUrl: URL?
    private var progressBlock: VideoExportProgressBlock?
    private var completionBlock: VideoExportCompletionBlock?
    
    private var state: State = .none
    
    private var textLabels: [UIView] = []
    
    
    private let displayWidth: CGFloat = UIScreen.main.bounds.width
    
    
    private let kExportWidth: CGFloat = 667
    private let kExportDomain: String = "ExportErrorDomain"
    private let kExportCode: Int = -1
    
    // MARK: - Initialize
    
    init(videoUrl: URL, texts: [ComposeComment], brushImage: UIImage?) {
        self.videoUrl = videoUrl
        self.texts = texts
        self.brushImage = brushImage
        super.init()
        // processExportVideo()
    }
    
    deinit {
        print("\(self) dealloc") // ERROR: Test!
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
            export.exportAsynchronously() {
                DispatchQueue.main.async { [weak self] () -> Void in
                    guard let this = self else { return }
                    switch export.status {
                    case .completed:
                        print("Complete")
                        this.exportUrl = export.outputURL
                        this.exportSession = nil
                        this.state = .finish
                        this.finishExport(export.outputURL, error: nil)
                        
                    case .unknown:
                        print("Unknown")
                        if FileManager.default.fileExists(atPath: export.outputURL!.path) {
                            this.exportUrl = export.outputURL
                            this.exportSession = nil
                            this.state = .finish
                            this.finishExport(export.outputURL, error: nil)
                        } else {
                            this.exportSession = nil
                            this.state = .finish
                            this.finishExport(nil, error: export.error)
                        }
                        
                    case .exporting, .waiting: break
                        
                    case .failed, .cancelled:
                        print("Fail / Cancel: \(export.error)")
                        this.exportSession = nil
                        this.state = .finish
                        this.finishExport(nil, error: export.error)
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
                let imageData = try createPreviewData(fromVideoUrl: url)
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
        
        // Get asset from videos
        let asset: AVAsset = AVAsset(url: videoUrl)
        
        guard CMTimeGetSeconds(asset.duration) > 0 else {
            let message = "error-2"
            let userInfo: [String : Any] = [NSLocalizedDescriptionKey : message]
            error = NSError(domain: kExportDomain, code: kExportCode, userInfo: userInfo) as Error
            return nil
        }
        
        // Create input AVMutableComposition, hold our video AVMutableCompositionTrack list.
        let inputComposition = AVMutableComposition()
        
        // Add list videos into input composition
        guard let videoTrack = addVideo(toInputComposition: inputComposition, fromAsset: asset) else {
            let message = "error-3"
            let userInfo: [String : Any] = [NSLocalizedDescriptionKey : message]
            error = NSError(domain: kExportDomain, code: kExportCode, userInfo: userInfo) as Error
            return nil
        }
        
        
        // Add list audio into input composition
        _ = addAudio(toInputComposition: inputComposition, fromAsset: asset)
        
        // Add video instructions
        let outputVideoInstruction = createOutputVideoInstruction(fromAsset: asset, videoTrack: videoTrack)
        
        // Get all video time length
        var totalVideoTimeLength = kCMTimeZero
        totalVideoTimeLength = CMTimeAdd(totalVideoTimeLength, asset.duration)
        
        // Output composition instruction
        let outputCompositionInstruction = AVMutableVideoCompositionInstruction()
        outputCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, totalVideoTimeLength)
        outputCompositionInstruction.layerInstructions = [outputVideoInstruction]
        
        let videoSize = videoTrack.naturalSize
        let scale: CGFloat = kExportWidth / videoSize.width
        let exportSize = CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
        
        // Output video composition
        let outputComposition = AVMutableVideoComposition()
        outputComposition.instructions = [outputCompositionInstruction]
        outputComposition.frameDuration = CMTimeMake(1, 30)
        outputComposition.renderSize = exportSize
        
        // Add effects
        // addEffect(image: brushImage, texts: texts, toOutputComposition: outputComposition)
        
        // Create export session from input video & output instruction
        if let exportSession = AVAssetExportSession(asset: inputComposition, presetName: AVAssetExportPresetHighestQuality) {
            exportSession.videoComposition = outputComposition
            exportSession.outputFileType = AVFileType.mov
            exportSession.outputURL = createCacheURL()
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
    
    private func addVideo(toInputComposition inputComposition: AVMutableComposition, fromAsset asset: AVAsset) -> AVMutableCompositionTrack? {
        
        guard let track = inputComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else { return nil }
        
        do {
            // Important: only add track if has media type, or have to remove out of composition
            // Otherwise export session always fail with error code -11820
            if let videoTrack = asset.tracks(withMediaType: AVMediaType.video).first {
                try track.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: videoTrack, at: kCMTimeZero)
                return track
            }
            else {
                return nil
            }
        }
        catch let error as NSError {
            print("Fail: \(error)")
            return nil
        }
    }
    
    private func addAudio(toInputComposition inputComposition: AVMutableComposition, fromAsset asset: AVAsset) -> AVMutableCompositionTrack? {
        
        // Add Audio tracks
        guard let track = inputComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else {
            return nil
        }
        
        do {
            // Important: only add track if has media type, or have to remove out of composition
            // Otherwise export session always fail with error code -11820
            if let audioTrack = asset.tracks(withMediaType: AVMediaType.audio).first {
                try track.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: audioTrack, at: kCMTimeZero)
                return track
            }
            else {
                return nil
            }
        }
        catch let error as NSError {
            print("Fail: \(error)")
            return nil
        }
    }
    
    private func createOutputVideoInstruction(fromAsset asset: AVAsset, videoTrack: AVCompositionTrack) -> AVMutableVideoCompositionLayerInstruction {
        var totalVideoTime = kCMTimeZero
        
        let videoSize = videoTrack.naturalSize
        
        // Add instruction for videos
        totalVideoTime = CMTimeAdd(totalVideoTime, asset.duration)
        
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        
        instruction.setTransform(videoTrack.preferredTransform, at: kCMTimeZero)
        
        let scale: CGFloat = kExportWidth / videoSize.width
        
        let t3 = videoTrack.preferredTransform.scaledBy(x: scale, y: scale)
        instruction.setTransform(t3, at: kCMTimeZero)
        
        instruction.setOpacity(0.0, at: totalVideoTime)
        
        return instruction
    }
    
//    private func addEffect(image: UIImage?, texts: [ComposeComment], toOutputComposition outputComposition: AVMutableVideoComposition) {
//
//        // Text layer container
//        let videoFrame = CGRect(origin: CGPoint.zero, size: outputComposition.renderSize)
//        let overlayLayer = CALayer()
//        overlayLayer.frame = videoFrame
//        overlayLayer.masksToBounds = true
//
//        let usedHeight = videoFrame.height * displayWidth / videoFrame.width
//
//        for index in stride(from: 0, to: texts.count, by: 1) {
//            let comment: ComposeComment = texts[index]
//
//            let commentParts = CommentPart.parse(comment.comment.content, [])
//            let textLabel = BomExportCommentItemView(parts: commentParts)
//
//            textLabel.frame.origin.x = videoFrame.maxX
//            textLabel.frame.origin.y = videoFrame.bounds.height - videoFrame.bounds.height * comment.place / usedHeight - textLabel.bounds.height
//
//            let moveAnimation =  CABasicAnimation(keyPath: "position.x")
//            moveAnimation.byValue = -(videoFrame.bounds.width + textLabel.bounds.width)
//            moveAnimation.beginTime = comment.time
//            moveAnimation.duration = textLabel.duration(width: videoFrame.bounds.width)
//            moveAnimation.isRemovedOnCompletion = false
//            moveAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
//            moveAnimation.fillMode = kCAFillModeForwards
//
//            textLabel.layer.add(moveAnimation, forKey: "move")
//
//            // Insert megatext layer
//            overlayLayer.addSublayer(textLabel.layer)
//            textLabels.append(textLabel) // *Very importance: To store instance, otherwise it can't render
//        }
//
//        let watermark = UILabel(frame: CGRect(x: videoFrame.bounds.width - 150, y: 0, width: 150, height: 56))
//        watermark.set(font: .Font(23), color: .white, text: "VIBBIDI.com")
//        watermark.textAlignment = .center
//        watermark.backgroundColor = UIColor(hex: 0x000000, alpha: 0.25)
//        overlayLayer.addSublayer(watermark.layer)
//        textLabels.append(watermark) // *Very importance: To store instance, otherwise it can't render
//
//        let parentLayer = CALayer()
//        parentLayer.frame = videoFrame
//
//        let videoLayer = CALayer()
//        videoLayer.frame = videoFrame
//
//        parentLayer.addSublayer(videoLayer)
//        parentLayer.addSublayer(overlayLayer)
//
//        outputComposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, in: parentLayer)
//    }
    
    
    
}

private extension VideoMerge {
    
    func createCacheURL() -> URL {
        let documentDirFileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputFileName = ProcessInfo.processInfo.globallyUniqueString
        let cacheURL = documentDirFileURL.appendingPathComponent("mergeVideo-\(outputFileName).mov")
        
        // Remove existing file at url if has any
        try? FileManager.default.removeItem(at: cacheURL)
        print("Remove previous cache file at path: \(cacheURL)")
        
        return cacheURL
    }
    
    func createPreviewData(fromVideoUrl url: URL) throws -> Data? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = kCMTimeZero
        imageGenerator.requestedTimeToleranceBefore = kCMTimeZero
        
        var time = asset.duration
        time.value = min(asset.duration.value, 1)
        
        let imageRef = try imageGenerator.copyCGImage(at: time, actualTime: nil)
        let image = UIImage(cgImage: imageRef)
        return UIImageJPEGRepresentation(image, 0.95)
    }
    
}



