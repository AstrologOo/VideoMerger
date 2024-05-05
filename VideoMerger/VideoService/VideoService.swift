//
//  VideoService.swift
//  TestMergee
//
//  Created by Александр Островский on 04.05.2024.
//

import UIKit
import AVFoundation
import Photos

protocol VideoServiceProtocol {
    func merge(_ assets: [PHAsset]) async throws -> AVAsset
    func export(asset: AVAsset) async throws -> URL
}


class VideoService: VideoServiceProtocol {
    
    enum AssetsError: Error {
        case error
    }
    
    func merge(_ assets: [PHAsset]) async throws -> AVAsset {
        let movie = AVMutableComposition()
        guard let videoTrack = movie.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw AssetsError.error }
        
        var currentDuration = movie.duration
        
        for asset in assets {
            if asset.mediaType == .video {
                let avAsset = try await requestVideoAsset(from: asset)
                let duration = try await avAsset.load(.duration)
                let avAssetRange = CMTimeRangeMake(start: CMTime.zero, duration: duration)
                let avAssetVideoTrack = try await avAsset.loadTracks(withMediaType: .video).first
                
                guard  let avAssetVideoTrack = avAssetVideoTrack else { throw AssetsError.error }
                
                try videoTrack.insertTimeRange(avAssetRange, of: avAssetVideoTrack, at: currentDuration)

                currentDuration = movie.duration
            } else {
                let image = try await requestImage(from: asset)
                let fileName = "temp_\(UUID().uuidString)"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).mov")
                try await writeSingleImageToMovie(image: image, movieLength: 3, outputFileURL: url)
                
                let avAsset = AVURLAsset(url: url)
                let duration = try await avAsset.load(.duration)
                let avAssetRange = CMTimeRangeMake(start: CMTime.zero, duration: duration)
                let avAssetVideoTrack = try await avAsset.loadTracks(withMediaType: .video).first
                
                guard let avAssetVideoTrack = avAssetVideoTrack else { throw AssetsError.error }
                
                try videoTrack.insertTimeRange(avAssetRange, of: avAssetVideoTrack, at: currentDuration)
                currentDuration = movie.duration
            }
        }
        
        return movie
    }

    @discardableResult
    func export(asset: AVAsset) async throws -> URL {
        let fileName = "mergedMovie_\(UUID().uuidString)"
        let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).mov")
        
        guard let exporter = AVAssetExportSession.init(asset: asset, presetName: AVAssetExportPresetHighestQuality) else { throw AssetsError.error }
        exporter.outputURL = exportURL
        exporter.outputFileType = AVFileType.mov
        
        print(exporter.supportedFileTypes.contains(.mov))
        
        
        await exporter.export()
        
        switch exporter.status {
            case .completed:
                return exportURL
            default:
                throw AssetsError.error
        }
    }
    
    private func writeSingleImageToMovie(image: UIImage, movieLength: TimeInterval, outputFileURL: URL) async throws {
        let imageSize = image.size
        
        let videoWriter = try AVAssetWriter(outputURL: outputFileURL, fileType: AVFileType.mov)
        let videoSettings: [String: Any] = [AVVideoCodecKey: AVVideoCodecType.h264,
                                            AVVideoWidthKey: imageSize.width,
                                            AVVideoHeightKey: imageSize.height]
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: videoSettings)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: nil)
        
        if !videoWriter.canAdd(videoWriterInput) { throw AssetsError.error }
        videoWriterInput.expectsMediaDataInRealTime = true
        videoWriter.add(videoWriterInput)
        
        videoWriter.startWriting()
        let timeScale: Int32 = 600
        let halfMovieLength = Float64(movieLength/2.0)
        let startFrameTime = CMTimeMake(value: 0, timescale: timeScale)
        let endFrameTime = CMTimeMakeWithSeconds(halfMovieLength, preferredTimescale: timeScale)
        videoWriter.startSession(atSourceTime: startFrameTime)
        
        guard let cgImage = image.cgImage else { throw AssetsError.error }
        let buffer: CVPixelBuffer = try self.pixelBuffer(fromImage: cgImage, size: imageSize)
        while !adaptor.assetWriterInput.isReadyForMoreMediaData { usleep(10) }
        adaptor.append(buffer, withPresentationTime: startFrameTime)
        while !adaptor.assetWriterInput.isReadyForMoreMediaData { usleep(10) }
        adaptor.append(buffer, withPresentationTime: endFrameTime)
        
        videoWriterInput.markAsFinished()
        await videoWriter.finishWriting()
        if let _ = videoWriter.error {
            throw AssetsError.error
        }
    }
    
    private func pixelBuffer(fromImage image: CGImage, size: CGSize) throws -> CVPixelBuffer {
        let options: CFDictionary = [kCVPixelBufferCGImageCompatibilityKey as String: true, kCVPixelBufferCGBitmapContextCompatibilityKey as String: true] as CFDictionary
        var pxbuffer: CVPixelBuffer? = nil
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, options, &pxbuffer)
        guard let buffer = pxbuffer, status == kCVReturnSuccess else { throw AssetsError.error }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        guard let pxdata = CVPixelBufferGetBaseAddress(buffer) else { throw AssetsError.error }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pxdata, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { throw AssetsError.error }
        context.concatenate(CGAffineTransform(rotationAngle: 0))
        context.draw(image, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        return buffer
    }
    
    private func requestImage(from asset: PHAsset) async throws -> UIImage {
       return try await withCheckedThrowingContinuation { continuation  in
           let option = PHImageRequestOptions()
           option.isSynchronous = true
           option.resizeMode = .fast
           let size = CGSize(width: 1280, height: 720) // PHImageManagerMaximumSize
           PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: option) { image, _ in
               if let image = image {
                   continuation.resume(returning: image)
               } else {
                   continuation.resume(throwing: AssetsError.error)
               }
           }
       }
    }
    
    private func requestVideoAsset(from asset: PHAsset) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation  in
            PHImageManager.default().requestAVAsset(forVideo: asset, options: nil) { avAsset, _, _ in
                if let videoAsset = avAsset {
                    continuation.resume(returning: videoAsset)
                } else {
                    continuation.resume(throwing: AssetsError.error)
                }
            }
        }
    }
}
