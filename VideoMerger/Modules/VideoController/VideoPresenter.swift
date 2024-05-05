//
//  VideoViewControllerPresenter.swift
//  TestMergee
//
//  Created by Александр Островский on 05.05.2024.
//

import Foundation
import PhotosUI

protocol VideoPresenterInput: AnyObject {
    func didLoadView()
    func actionChooseMedia()
    func actionSaveResult()
    func didSelectMedia(with data: [PHPickerResult])
}

protocol VideoPresenterOutput: AnyObject {
    func showPicker(with selectedIds: [String])
    func showAlert(with title: String)
    func showVideo(with movie: AVAsset)
}


class VideoPresenter: VideoPresenterInput {
    weak var output: VideoPresenterOutput?
    var interactor: VideoInteractorInput?
    
    private var movie: AVAsset? = nil
    private var selectedMediaIds: [String] = []
    
    func didLoadView() {}
    
    func actionChooseMedia() {
        let ids = selectedMediaIds
        PHPhotoLibrary.requestAuthorization { [weak self, ids] status in
            switch status {
            case .authorized:
                print("Authorization granted")
                self?.output?.showPicker(with: ids)
            case .limited:
                print("Authorization limited")
                self?.output?.showPicker(with: ids)
            case .denied, .restricted:
                self?.output?.showAlert(with: "Authorization denied or restricted")
                print("Authorization denied or restricted")
            case .notDetermined:
                print("Authorization not determined yet")
            @unknown default:
                fatalError("Unknown authorization status")
            }
        }
    }
    
    func didSelectMedia(with data: [PHPickerResult]) {
        let ids = data.compactMap(\.assetIdentifier)
        selectedMediaIds = ids
        var assets: [PHAsset] = []
        
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        
        assets = assets.sorted(by: { a, b in
            guard let first = ids.firstIndex(of: a.localIdentifier), let second = ids.firstIndex(of: b.localIdentifier) else {
                    return false
                }
            return first < second
        })
        
        interactor?.mergeToVideo(assets: assets)
    }
    
    func actionSaveResult() {
        guard let movie = movie else {
            self.output?.showAlert(with: "Please select media for make new video")
            return
        }
        self.interactor?.save(video: movie)
    }
    
}


extension VideoPresenter: VideoInteractorOutput {
    func didSaveVideo(with url: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                self.output?.showAlert(with: "Need authorization to access photo library")
                return
            }
            PHPhotoLibrary.shared().performChanges({
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                let creationRequest = PHAssetCreationRequest.forAsset()
                creationRequest.addResource(with: .video, fileURL: url, options: options)
            }, completionHandler: { success, error in
                if success {
                    self.output?.showAlert(with: "Video has been successfully saved to gallery")
                } else if let error = error {
                    self.output?.showAlert(with: "Error saving video to gallery: \(error.localizedDescription)")
                }
            })
        }
    }
    
    func didMergeAssetsToVideo(asset: AVAsset) {
        self.movie = asset
        self.output?.showVideo(with: asset)
    }
}
