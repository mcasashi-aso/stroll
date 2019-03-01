//
//  DirectionViewController.swift
//  DireWalk
//
//  Created by 麻生昌志 on 2019/02/27.
//  Copyright © 2019 麻生昌志. All rights reserved.
//

import UIKit
import CoreLocation

class DirectionViewController: UIViewController, CLLocationManagerDelegate {
    
    let userDefaults = UserDefaults.standard
    
    var locationManager = CLLocationManager()
    
    @IBOutlet weak var headingImageView: UIView!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var unitLabel: UILabel!
    
    var destinationLocation = CLLocation()
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        locationManager.headingFilter = 0.1
        
        let headingRadian: CGFloat = userDefaults.object(forKey: ud.key.directoinButtonHeading.rawValue) as! CGFloat
        headingImageView.transform = CGAffineTransform(rotationAngle: headingRadian * CGFloat.pi / 180)
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if destinationLocation.coordinate.latitude == 0.0 ||
            destinationLocation.coordinate.longitude == 0.0 {
            destinationLocation = CLLocation(
                latitude: userDefaults.object(forKey: ud.key.annotationLatitude.rawValue) as! CLLocationDegrees,
                longitude: userDefaults.object(forKey: ud.key.annotationLongitude.rawValue) as! CLLocationDegrees)
        }
        
        let far = destinationLocation.distance(from: locationManager.location!)
        var distance: String!
        var unit: String!
        if 50 > Int(far) {
            distance = "\(Int(far))"
            unit = "m"
        }else if 500 > Int(far){
            distance = "\((Int(far) / 10 + 1) * 10)"
            unit = "m"
        }else {
            let doubleNum = Double(Int(far) / 100 + 1) / 10
            if doubleNum.truncatingRemainder(dividingBy: 1.0) == 0.0 {
                distance = "\(Int(doubleNum))"
                unit = "km"
            }else {
                distance = "\(doubleNum)"
                unit = "km"
            }
        }
        distanceLabel.text = distance
        unitLabel.text = unit
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        locationManager.delegate = self
        if userDefaults.object(forKey: ud.key.annotationLatitude.rawValue) != nil {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }

}