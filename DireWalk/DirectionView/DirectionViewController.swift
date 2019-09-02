//
//  DirectionViewController.swift
//  DireWalk
//
//  Created by 麻生昌志 on 2019/02/27.
//  Copyright © 2019 麻生昌志. All rights reserved.
//

import UIKit
import CoreLocation

class DirectionViewController: UIViewController {
    
    static func create() -> DirectionViewController {
        let sb = UIStoryboard(name: "Direction", bundle: nil)
        let vc = sb.instantiateInitialViewController() as! DirectionViewController
        return vc
    }
    
    let userDefaults = UserDefaults.standard
    let viewModel = ViewModel.shared
    let model = Model.shared
    
    @IBOutlet weak var headingImageView: UIImageView!
    @IBOutlet weak var distanceLabel: UILabel!
    
    func updateFarLabel() {
        distanceLabel.attributedText = viewModel.farLabelText
    }
    
    func updateHeadingImage() {
        headingImageView.transform = CGAffineTransform(rotationAngle: viewModel.headingImageAngle)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let image = UIImage(named: "Direction")!.withRenderingMode(.alwaysTemplate)
        headingImageView.image = image
        distanceLabel.adjustsFontSizeToFitWidth = true
        
        updateFarLabel()
        updateHeadingImage()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        let whiteValue = viewModel.arrowColor
        if #available(iOS 13, *) {
            headingImageView.image?.withTintColor(UIColor(white: whiteValue, alpha: 1),
                                                  renderingMode: .alwaysTemplate)
        }
        headingImageView.tintColor = UIColor(white: whiteValue, alpha: 1)
        updateFarLabel()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        guard let force = touch?.force,
            let maximum = touch?.maximumPossibleForce else { return }
        let percent = force / maximum
        if percent == 1.0 {
            if viewModel.state != .hideControllers {
                viewModel.state = .hideControllers
            }else {
                viewModel.state = .direction
            }
        }
    }
    @IBOutlet var longPressGestureRecognizer: UILongPressGestureRecognizer! {
        didSet {
            longPressGestureRecognizer.minimumPressDuration = 0.5
        }
    }
    @IBAction func longPress(_ sender: UILongPressGestureRecognizer) {
        if sender.state == UIPanGestureRecognizer.State.began {
            if viewModel.state != .hideControllers {
                viewModel.state = .hideControllers
            }else {
                viewModel.state = .direction
            }
        }
    }
}
