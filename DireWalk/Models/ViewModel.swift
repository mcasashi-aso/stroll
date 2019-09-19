//
//  ViewModel.swift
//  DireWalk
//
//  Created by Masashi Aso on 2019/08/27.
//  Copyright © 2019 麻生昌志. All rights reserved.
//

import UIKit
import MapKit

// MARK: - ViewModelDelegate
protocol ViewModelDelegate: class {
    func addHeadingView(to annotationView: MKAnnotationView)
    
    func updateViews()
    func didChangePlace()
    func didChangeState()
    
    func reloadTableViewData(new: [Place], old: [Place])
    func moveCenterToPlace()
    func presentEditPlaceView(place: Place)
    
    func updateActivityViewData(dayChanged: Bool)
}

// MARK: - ViewModel
final class ViewModel: NSObject {
    
    // MARK: - Singlton
    static let shared = ViewModel()
    private override init() {
        super.init()
        model.delegate = self
        self.usingTimer = .scheduledTimer(timeInterval: 1, target: self, selector: #selector(usingTimeUpdater), userInfo: nil, repeats: true)
        NotificationCenter.default.addObserver(self, selector: #selector(didChangeFavorites), name: .didChangeFavorites, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateTableView), name: .didUpdateUserLocation, object: nil)
        updateTableView()
    }
    
    // MARK: - Other Models
    private let model = Model.shared
    var settings = Settings.shared
    private var userDefaults = UserDefaults.standard
    weak var delegate: ViewModelDelegate?
    
    // MARK: - View State
    enum Status { case activity, direction, map, search, hideControllers }
    var state : Status = .direction {
        didSet {
            delegate?.didChangeState()
            UIApplication.shared.isIdleTimerDisabled = (state == .hideControllers)
        }
    }
    
    enum Views { case activity, direction, map }
    var presentView: Views {
        switch state {
        case .activity: return .activity
        case .direction, .hideControllers: return .direction
        case .map, .search: return .map
        }
    }
    
    // MARK: - Label Text
    var labelTitle: String {
        guard let place = model.place else {
            switch state {
            case .direction, .hideControllers, .activity: return "selectDestination".localized
            case .map: return "longPressToSelect".localized
            case .search: return "enterDestination".localized
            }
        }
        switch state {
        case .activity: return "Today's Activity"
        case .direction, .hideControllers, .map, .search:
            return place.title ?? place.address ?? "Pin"
        }
    }
    var aboutLabelText: String {
        if model.place == nil { return " " }
        switch state {
        case .activity, .hideControllers: return " "
        case .direction, .map: return "destination:".localized
        case .search: return "search".localized
        }
    }
    var farLabelText: NSMutableAttributedString {
        guard model.place != nil else {
            return NSMutableAttributedString(attributedString:
                .get("swipeAndSelect".localized, attributes: .white40))
        }
        
        if state == .hideControllers { return NSMutableAttributedString() }
        
        let (far, unit) = { () -> (String, String) in
            guard let far = model.far else { return ("Error", "  ") }
            switch Int(far) {
            case ..<100:  return (String(Int(far)), "m")
            case ..<1000: return (String((Int(far) / 10 + 1) * 10), "m")
            default:
                let double = Double(Int(far) / 100 + 1) / 10
                if double.truncatingRemainder(dividingBy: 1.0) == 0.0 {
                    return (String(Int(double)), "km")
                }else { return (String(double),  "km") }
            }
        }()
        let text = NSMutableAttributedString()
        text.append(.get("  ", attributes: .white40))
        text.append(.get(far, attributes: .white80))
        text.append(.get(" \(unit)", attributes: .white40))
        if settings.alwaysDontShowsFar && (model.far ?? 0) > 50 {
            return NSMutableAttributedString()
        }
        return text
    }
    
    // MARK: - User Heading
    var headingImageAngle: CGFloat {
        model.place != nil ? ((model.heading - 45) * .pi / 180) : (.pi / 2)
    }
    
    var annotation: Annotation?
    
    // MARK: - Favorites & Search
    @UserDefault(.favoritePlaces, defaultValue: Set<Place>())
    var favoritePlaces: Set<Place>
    var searchText = "" { didSet { setResultElements() } }
    var searchResults = [Place]() { didSet { updateTableView() } }
    var searchTableViewPlaces = [Place]() {
        didSet {
            guard searchTableViewPlaces != oldValue else { return }
            delegate?.reloadTableViewData(new: searchTableViewPlaces, old: oldValue)
        }
    }
    @objc func updateTableView() {
        let array = searchText.isEmpty ? Array(favoritePlaces) : searchResults
        searchTableViewPlaces = array.sorted { a, b in
            let location = model.currentLocation
            return a.distance(from: location) < b.distance(from: location)
        }
    }
    
    // MARK: - Using Timer
    var usingTimer = Timer()
    @UserDefault(.usingTimes, defaultValue: 0)
    var usingTime: Int
    @UserDefault(.date, defaultValue: Date())
    var date: Date
}


// MARK: - UIPageVCDelegate
extension ViewModel: UIPageViewControllerDelegate {
    func pageViewController(_ pageViewController: UIPageViewController,
                            didFinishAnimating finished: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        let vc = pageViewController.viewControllers?.first
        switch vc {
        case is DirectionViewController: state = .direction
        case is MapViewController:       state = (state == .search) ? .search : .map
        case is ActivityViewController:  state = .activity
        default: return
        }
        delegate?.updateViews()
    }
}


// MARK: - UISearchBarDelegate
extension ViewModel: UISearchBarDelegate {
    func setResultElements() {
        if searchText.isEmpty {
            self.searchResults = []
        }

        let matchFavorites = favoritePlaces.filter { place in
            (place.title?.contains(searchText) ?? false) || (place.address?.contains(searchText) ?? false)
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        request.region = MKCoordinateRegion(center: model.currentLocation.coordinate,
                                            latitudinalMeters: 10_000,
                                            longitudinalMeters: 10_000)     // 10km四方
        MKLocalSearch(request: request).start { (result, error) in
            guard let mapItems = result?.mapItems, error == nil else { return }
            let results = mapItems.map { item in
                Place(coordinate: item.placemark.coordinate,
                      title: item.name ?? item.placemark.title ?? item.placemark.address,
                      adress: item.placemark.address)
            }
            
            self.searchResults = matchFavorites + results
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        state = .search
        return true
    }
    
    func searchBar(_ searchBar: UISearchBar,
                   shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let nsString = (searchBar.text ?? "") as NSString
        let replaced = nsString.replacingCharacters(in: range, with: text) as String
        searchText = replaced.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        state = .map
        searchBar.resignFirstResponder()
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        setResultElements()
        if searchTableViewPlaces.isEmpty {
            // 検索結果がない場合検索モードを終了する
            state = .map
        }else {
            // 検索結果がある場合はキーボードだけ消す
            searchBar.resignFirstResponder()
            if let cancelButton = searchBar.cancelButton {
                cancelButton.isEnabled = true
            }
        }
    }
    
}
// MARK: - SearchTableViewDelegate
extension ViewModel: UITableViewDelegate {
    func tableView(_ tableView: UITableView,
                   didSelectRowAt indexPath: IndexPath) {
        model.place = searchTableViewPlaces[indexPath.row]
        state = .map
        delegate?.moveCenterToPlace()
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard var place = self.searchTableViewPlaces[safe: indexPath.row] else { return nil }
        let toggleFavoriteAction: UIContextualAction = {
            let action = UIContextualAction(style: .normal, title: "Favorite") {
                (action, view, completion) in
                place.isFavorite.toggle()
                completion(true)
            }
            action.backgroundColor = #colorLiteral(red: 0.9568627451, green: 0.262745098, blue: 0.2117647059, alpha: 1)
            let image: UIImage
            if #available(iOS 13, *) {
                image = UIImage(systemName: place.isFavorite ? "heart" : "heart.fill")!
            }else {
                image = UIImage(named: place.isFavorite ? "Heart" : "HeartFill")!
            }
            action.image = image
            return action
        }()
        let toEditAction: UIContextualAction = {
            let action = UIContextualAction(style: .normal, title: "edit".localized) {
                (action, view, completion) in
                self.delegate?.presentEditPlaceView(place: place)
            }
            action.backgroundColor = .darkGray
            return action
        }()
        let actions = place.isFavorite ? [toggleFavoriteAction, toEditAction]
                                       : [toggleFavoriteAction]
        return UISwipeActionsConfiguration(actions: actions)
    }
}

// MARK: - SearchTableDataSource
extension ViewModel: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        searchTableViewPlaces.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: SearchTableViewCell = tableView.getCell(indexPath: indexPath)
        guard let place = searchTableViewPlaces[safe: indexPath.row] else { return cell }
        cell.setPlace(place)
        return cell
    }
    
    @objc func didChangeFavorites() {
        if let place = model.place,
            let new = favoritePlaces.first(where: { $0.isSamePlace(to: place) && $0 != place}) {
            // 選択中のPlaceの名前が変更された時
            model.place = new
        }
        updateTableView()
    }
}


// MARK: - Using Time
extension ViewModel {
    @objc func usingTimeUpdater() {
        let now = Date()
        let dayChanged = !date.isSameDay(to: now)
        if dayChanged { usingTime = 0 }
        usingTime += 1
        
        // 1分毎に
        if ceil(Double(usingTime) / 60) != ceil(Double(usingTime + 1) / 60) {
            delegate?.updateActivityViewData(dayChanged: dayChanged)
        }
        date = now
    }
}


// MARK: - MKMapViewDelegate
extension ViewModel: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation { return nil }
        let markerView = mapView.dequeueReusableAnnotationView(withIdentifier: "pin") as? MKMarkerAnnotationView
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
        markerView.canShowCallout = true
        markerView.annotation = annotation
        markerView.animatesWhenAdded = true
        
        if let an = annotation as? Annotation {
            markerView.rightCalloutAccessoryView = getAnnotationButton(annotation: an)
        }
        return markerView
    }
    
    func mapView(_ mapView: MKMapView,
                 annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        guard control == view.rightCalloutAccessoryView,
            let an = view.annotation as? Annotation else { return }
        an.place?.isFavorite.toggle()
        view.rightCalloutAccessoryView = getAnnotationButton(annotation: an)
    }
    
    func getAnnotationButton(annotation: Annotation) -> UIButton? {
        guard let place = annotation.place else { return nil }
        let button = UIButton(frame: CGRect(origin: .zero, size: CGSize(width: 30, height: 30)))
        if #available(iOS 13, *) {
            let name = place.isFavorite ? "heart.fill" : "heart"
            let image = UIImage(systemName: name)!
            button.setImage(image, for: .normal)
        }else {
            let name = place.isFavorite ? "HeartFill" : "Heart"
            let image = UIImage(named: name)!.withRenderingMode(.alwaysTemplate)
            button.setImage(image, for: .normal)
            button.tintColor = .systemBlue
        }
        return button
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        guard let view = views.filter({ $0.annotation is MKUserLocation }).first else { return }
        delegate?.addHeadingView(to: view)
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        delegate?.updateViews()
    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        delegate?.updateViews()
    }
}


// MARK: - ModelDelegate
extension ViewModel: ModelDelegate {   
    func didChangePlace() {
        delegate?.didChangePlace()
    }
    
    func didChangeFar() {
        if (model.far ?? 0) > 50 && state == .hideControllers {
            state = .direction
        }
        delegate?.updateViews()
    }
    
    func didChangeHeading() {
        delegate?.updateViews()
    }
}
