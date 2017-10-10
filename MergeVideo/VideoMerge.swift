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

enum ExportError: Error {
    case invalidAsset, emptyVideo, noSession
}

class VideoMerge {
    
    enum State {
        case none, merging, finished(URL), failed(Error?)
    }
    
    private(set) var exportedUrl: URL?
    private var state: State = .none
    
    private var videoUrl: URL
    private var texts: [ComposeComment] = []
    private var brushImage: UIImage?
    private var overlayViews: [UIView] = []
    
    private var exportSession: AVAssetExportSession?
    
    private var progressBlock: VideoExportProgressBlock?
    private var completionBlock: VideoExportCompletionBlock?
    
    private let kDisplayWidth: CGFloat = UIScreen.main.bounds.width
    private let kExportWidth: CGFloat = 800
    
    init(videoUrl: URL, texts: [ComposeComment], brushImage: UIImage?) {
        self.videoUrl = videoUrl
        self.texts = texts
        self.brushImage = brushImage
    }
    
    deinit {
        print("\(self) dealloc") // ERROR: Test!
    }
    
    func startExportVideo(onProgress progressBlock: VideoExportProgressBlock? = nil, onCompletion completionBlock: VideoExportCompletionBlock? = nil) {
        
        self.progressBlock = progressBlock
        self.completionBlock = completionBlock
        
        switch state {
        case .none: processExportVideo()
        case .merging: break
        case let .finished(url): finishExport(url, error: nil)
        case let .failed(error): finishExport(nil, error: error)
        }
    }
    
    func stopExportVideo() {
        exportSession?.cancelExport()
        exportSession = nil
        state = .none
        overlayViews.removeAll()
    }
}

// MARK: - Actions

extension VideoMerge {
    
    private func processExportVideo() {
        do {
            let export = try createExportSession()
            state = .merging
            exportSession = export
            handleExportSession(export)
        } catch let error {
            state = .none
            finishExport(nil, error: error)
        }
    }
    
    private func handleExportSession(_ export: AVAssetExportSession) {
        DispatchQueue.global().async { [weak self] in
            export.exportAsynchronously() {
                DispatchQueue.main.async {
                    guard let this = self else { return }
                    switch export.status {
                    case .completed, .unknown:
                        
                        if let url = export.outputURL, FileManager.default.fileExists(atPath: url.path) {
                            this.exportedUrl = url
                            this.state = .finished(url)
                            this.finishExport(url, error: nil)
                        } else {
                            this.state = .failed(export.error)
                            this.finishExport(nil, error: export.error)
                        }
                        this.exportSession = nil
                        
                    case .failed, .cancelled:
                        this.exportSession = nil
                        this.state = .failed(export.error)
                        this.finishExport(nil, error: export.error)
                        
                    case .exporting, .waiting: break
                    }
                }
            }
            
            while export.status == .waiting || export.status == .exporting {
                DispatchQueue.main.async {
                    guard let this = self else { return }
                    this.progressBlock?(export.progress)
                }
            }
        }
    }
    
    private func finishExport(_ url: URL?, error: Error?) {
        guard let url = url else {
            completionBlock?(nil, nil, error)
            return
        }
        
        do {
            let videoData = try Data(contentsOf: url)
            let imageData = try createPreviewDataFrom(videoUrl: url)
            completionBlock?(videoData, imageData, nil)
        } catch let error {
            completionBlock?(nil, nil, error)
        }
    }
}

// MARK: - Ultilities
    
private extension VideoMerge {
    
    private func createExportSession() throws -> AVAssetExportSession {
        // Get asset from videos
        let asset: AVAsset = AVAsset(url: videoUrl)
        
        guard CMTimeGetSeconds(asset.duration) > 0 else {
            throw ExportError.invalidAsset
        }
        
        // Create input AVMutableComposition, hold our video AVMutableCompositionTrack list.
        let inputComposition = AVMutableComposition()
        
        // Add video into input composition
        guard let videoCompositionTrack = addVideo(from: asset, to: inputComposition) else {
            throw ExportError.emptyVideo
        }
        
        // Add audio into input composition
        _ = addAudio(from: asset, to: inputComposition)
        
        // Add video layer instructions
        let outputVideoInstruction = createVideoLayerInstruction(asset: asset, videoCompositionTrack: videoCompositionTrack)
        
        // Output composition instruction
        let outputCompositionInstruction = AVMutableVideoCompositionInstruction()
        outputCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration)
        outputCompositionInstruction.layerInstructions = [outputVideoInstruction]
        
        let naturalSize = videoCompositionTrack.naturalSize
        let scale: CGFloat = kExportWidth / naturalSize.width
        let exportSize = CGSize(width: naturalSize.width * scale, height: naturalSize.height * scale)
        
        // Output video composition
        let outputComposition = AVMutableVideoComposition()
        outputComposition.instructions = [outputCompositionInstruction]
        outputComposition.frameDuration = CMTimeMake(1, 30)
        outputComposition.renderSize = exportSize
        
        // Add effects
        // addEffect(image: brushImage, texts: texts, toOutputComposition: outputComposition)
        
        // Create export session from input video & output instruction
        guard let exportSession = AVAssetExportSession(asset: inputComposition, presetName: AVAssetExportPresetHighestQuality) else {
            throw ExportError.noSession
        }
        
        exportSession.videoComposition = outputComposition
        exportSession.outputFileType = AVFileType.mov
        exportSession.outputURL = createCacheURL()
        exportSession.shouldOptimizeForNetworkUse = true
        return exportSession
    }
}

// MARK: - Compose Configurations

private extension VideoMerge {
    
    func addVideo(from asset: AVAsset, to inputComposition: AVMutableComposition) -> AVMutableCompositionTrack? {
        // Important: only add track if has video type & insert succesfully, or must remove it out of composition.
        // Otherwise export session always fail with error code -11820
        guard let assetTrack = asset.tracks(withMediaType: AVMediaType.video).first else {
            return nil
        }
        
        guard let compositionTrack = inputComposition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else {
            return nil
        }
        
        do {
            try compositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetTrack, at: kCMTimeZero)
        } catch {
            inputComposition.removeTrack(compositionTrack)
            return nil
        }
        
        return compositionTrack
    }
    
    func addAudio(from asset: AVAsset, to inputComposition: AVMutableComposition) -> AVMutableCompositionTrack? {
        // Important: only add track if has audio type & insert succesfully, or must remove it out of composition.
        // Otherwise export session always fail with error code -11820
        guard let assetTrack = asset.tracks(withMediaType: AVMediaType.audio).first else {
            return nil
        }
        
        guard let compositionTrack = inputComposition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else {
            return nil
        }
        
        do {
            try compositionTrack.insertTimeRange(CMTimeRangeMake(kCMTimeZero, asset.duration), of: assetTrack, at: kCMTimeZero)
        } catch {
            inputComposition.removeTrack(compositionTrack)
            return nil
        }
        
        return compositionTrack
    }
    
    private func createVideoLayerInstruction(asset: AVAsset, videoCompositionTrack: AVCompositionTrack) -> AVMutableVideoCompositionLayerInstruction {
        
        let totalVideoTime = CMTimeAdd(kCMTimeZero, asset.duration)
        let naturalSize = videoCompositionTrack.naturalSize
        let scale: CGFloat = kExportWidth / naturalSize.width
        let transform = videoCompositionTrack.preferredTransform.scaledBy(x: scale, y: scale)
        
        let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoCompositionTrack)
        instruction.setTransform(transform, at: kCMTimeZero)
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
        
        // Remove existing cache at url if has any
        try? FileManager.default.removeItem(at: cacheURL)
        print("Remove previous cache file at path: \(cacheURL)")
        
        return cacheURL
    }
    
    func createPreviewDataFrom(videoUrl: URL) throws -> Data? {
        let asset = AVAsset(url: videoUrl)
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



