//
//  VideoViewControllerInteractor.swift
//  TestMergee
//
//  Created by Александр Островский on 05.05.2024.
//

import Foundation
import Photos

protocol VideoInteractorInput: AnyObject {
    func mergeToVideo(assets: [PHAsset])
    func save(video: AVAsset)
}

protocol VideoInteractorOutput: AnyObject {
    func didMergeAssetsToVideo(asset: AVAsset)
    func didSaveVideo(with url: URL)
}

class VideoInteractor: VideoInteractorInput {
    
    private var videoService: VideoServiceProtocol = VideoService()
    weak var output: VideoInteractorOutput?
    
    func mergeToVideo(assets: [PHAsset]) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            do {
                let movie = try await self.videoService.merge(assets)
                self.output?.didMergeAssetsToVideo(asset: movie)
            } catch {
                print(error)
            }
        }
    }
    
    func save(video: AVAsset) {
        Task { [weak self] in
            guard let self = self else { return }
            let url = try await self.videoService.export(asset: video)
            self.output?.didSaveVideo(with: url)
        }
    }
    
}
