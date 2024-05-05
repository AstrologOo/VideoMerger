//
//  AppBuilder.swift
//  TestMergee
//
//  Created by Александр Островский on 05.05.2024.
//

import UIKit

class AppBuilder {
    static func getVideoController() -> UIViewController {
        let controller = VideoViewController()
        let presenter = VideoPresenter()
        let interactor = VideoInteractor()
        
        controller.presenter = presenter
        presenter.interactor = interactor
        presenter.output = controller
        interactor.output = presenter
        
        return controller
    }
}
