//
//  VideoViewController.swift
//  TestMergee
//
//  Created by Александр Островский on 05.05.2024.
//

import UIKit
import PhotosUI

class VideoViewController: UIViewController {

    @IBOutlet weak var saveVideoButton: UIButton!
    @IBOutlet weak var selectMediaButton: UIButton!
    @IBOutlet weak var playerView: UIView!
    private var player: AVPlayer?
    var presenter: VideoPresenterInput!
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func selectMediaAction(_ sender: Any) {
        presenter.actionChooseMedia()
    }
    
    @IBAction func saveVideoAction(_ sender: Any) {
        presenter.actionSaveResult()
    }
    
    private func play(movie: AVAsset) {
        self.player = AVPlayer(playerItem: AVPlayerItem(asset: movie))

        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = playerView.layer.bounds
        playerLayer.videoGravity = .resizeAspect

        playerView.layer.sublayers?.removeAll()
        playerView.layer.addSublayer(playerLayer)

        player?.play()
    }

}

extension VideoViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        presenter.didSelectMedia(with: results)
    }
}


extension VideoViewController: VideoPresenterOutput {
    func showPicker(with selectedIds: [String]) {
        DispatchQueue.main.async {
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            let filter = PHPickerFilter.any(of: [.images, .videos])
            configuration.filter = filter
            configuration.preferredAssetRepresentationMode = .current
            configuration.selection = .ordered
            configuration.selectionLimit = 6
            configuration.preselectedAssetIdentifiers = selectedIds
            let imagePicker = PHPickerViewController(configuration: configuration)
            imagePicker.delegate = self
            self.present(imagePicker, animated: true)
        }
    }
    
    func showAlert(with title: String) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Message", message: title, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default) { (action) in
               print("OK button tapped.")
            }
            alert.addAction(action)
            self.present(alert, animated: true)
        }
    }
    
    func showVideo(with movie: AVAsset) {
        DispatchQueue.main.async {
            self.play(movie: movie)
        }
    }
    
    
}
