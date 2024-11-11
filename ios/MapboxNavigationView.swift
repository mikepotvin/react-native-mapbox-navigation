import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps

// adapted from https://pspdfkit.com/blog/2017/native-view-controllers-and-react-native/ and https://github.com/mslabenyak/react-native-mapbox-navigation/blob/master/ios/Mapbox/MapboxNavigationView.swift
extension UIView {
    var parentViewController: UIViewController? {
        var parentResponder: UIResponder? = self
        while parentResponder != nil {
            parentResponder = parentResponder!.next
            if let viewController = parentResponder as? UIViewController {
                return viewController
            }
        }
        return nil
    }
}

class MapboxNavigationView: UIView, NavigationViewControllerDelegate {
    weak var navViewController: NavigationViewController?
    var passiveLocationManager: PassiveLocationManager?
    
    var embedded: Bool
    var embedding: Bool
    
    
    @objc var origin: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc var waypoints: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc var destination: NSArray = [] {
        didSet { setNeedsLayout() }
    }
    
    @objc var shouldSimulateRoute: Bool = false
    @objc var showsEndOfRouteFeedback: Bool = false
    @objc var hideStatusView: Bool = false
    @objc var mute: Bool = false
    
    @objc var onLocationChange: RCTDirectEventBlock?
    @objc var onRouteProgressChange: RCTDirectEventBlock?
    @objc var onError: RCTDirectEventBlock?
    @objc var onCancelNavigation: RCTDirectEventBlock?
    @objc var onArrive: RCTDirectEventBlock?
    @objc var onMuteChange: RCTDirectEventBlock?
    @objc var vehicleMaxHeight: NSNumber?
    @objc var vehicleMaxWidth: NSNumber?
    
    var navigationMapView: NavigationMapView!
    
    override init(frame: CGRect) {
        self.embedded = false
        self.embedding = false
        super.init(frame: frame)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if (navViewController == nil && !embedding && !embedded) {
            embed()
        } else {
            navViewController?.view.frame = bounds
        }
    }
    
    override func removeFromSuperview() {
        super.removeFromSuperview()
        // cleanup and teardown any existing resources
        self.navViewController?.removeFromParent()
        // clean up PassiveLocationManager
        self.passiveLocationManager = nil
    }
    
    @objc private func toggleMute(sender: UIButton) {
        onMuteChange?(["isMuted": sender.isSelected]);
    }
    
    private func embed() {
        guard origin.count == 2 && destination.count == 2 else { return }
        
        embedding = true
        
        // We can activate "Free-Drive" without having to display a temporary map
        // this is possible by starting up the passiveLocationManager.
        
        //        navigationMapView = NavigationMapView(frame: self.bounds)
        //        navigationMapView.translatesAutoresizingMaskIntoConstraints = false
        //        self.addSubview(navigationMapView)
        //        NSLayoutConstraint.activate([
        //            navigationMapView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
        //            navigationMapView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        //            navigationMapView.topAnchor.constraint(equalTo: self.topAnchor),
        //            navigationMapView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        //        ])
        //
        //        let navigationViewportDataSource = NavigationViewportDataSource(navigationMapView.mapView,
        //                                                                        viewportDataSourceType: .raw)
        //        navigationViewportDataSource.options.followingCameraOptions.zoomUpdatesAllowed = false
        //                navigationViewportDataSource.followingMobileCamera.zoom = 13.0
        //        navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        //        navigationMapView.navigationCamera.follow()

        // 
        // start up passiveLocationProvider before requesting a route as suggested by Mapbox.
        print("Starting up PassiveLocationManager")
        let passiveLocationManager = PassiveLocationManager()
        self.passiveLocationManager = passiveLocationManager
        passiveLocationManager.startUpdatingLocation()
        
        let navigationRouteOptions = NavigationRouteOptions(coordinates: [
            CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees),
            CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees)
        ], profileIdentifier: .automobileAvoidingTraffic)
        MapboxRoutingProvider().calculateRoutes(options: navigationRouteOptions) { [weak self] result in
            guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
                // TODO: call onError here? we've lost our self reference so how can we?
                return
            }
            switch result {
            case .failure(let error):
                strongSelf.onError?(["message": error.localizedDescription])
            case .success(let routeResponse):
                guard let weakSelf = self else {
                    // TODO: call onError here? we've lost our self reference so how can we?
                    return
                }
                
                // dispose of PLM after this call
                let navigationService = MapboxNavigationService(indexedRouteResponse: routeResponse, credentials: NavigationSettings.shared.directions.credentials, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
                
                if strongSelf.passiveLocationManager != nil {
                    print("Setting PassiveLocationManager to nil")
                }
                strongSelf.passiveLocationManager = nil
                
                let navigationOptions = NavigationOptions(navigationService: navigationService, bottomBanner: CustomBottomBarViewController())
                
                let navigationViewController = NavigationViewController(for: routeResponse,
                                                                        navigationOptions: navigationOptions)
                navigationViewController.shouldManageApplicationIdleTimer = false
                navigationViewController.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
                
                StatusView.appearance().isHidden = strongSelf.hideStatusView
                NavigationSettings.shared.voiceMuted = strongSelf.mute;
                
                if let muteButton = navigationViewController.floatingButtons?[1] {
                    muteButton.addTarget(strongSelf, action: #selector(strongSelf.toggleMute(sender:)), for: .touchUpInside)
                }
                
                navigationViewController.delegate = strongSelf
                //strongSelf.addSubview(navigationViewController.view)
                parentVC.addChild(navigationViewController)
                navigationViewController.view.frame = strongSelf.bounds
                navigationViewController.didMove(toParent: parentVC)
                strongSelf.navViewController = navigationViewController

                // Cleanup PassiveLocationManager
                //strongSelf.passiveLocationManager = nil
                
                UIView.animate(withDuration: 1, delay: 0, options: .transitionCurlUp, animations: {
                    strongSelf.addSubview(navigationViewController.view)
                }, completion: { (success) -> Void in
                    // Cleanup PassiveLocationManager
                    //strongSelf.passiveLocationManager = nil
                })
                
                // We don't need to animate the view here if there's no passive map view to swap with.
//                UIView.transition(with: self.navigationMapView, duration: 1, options: [.transitionCurlUp], animations: {
//                    //navigationViewController.navigationMapView = self.navigationView.navigationMapView
//                    self.addSubview(navigationViewController.view)
//                }, completion: { (success) -> Void in
//                    if success {
//                        self.navigationMapView.removeFromSuperview()
//                        print("completed animation for navigationViewController")
//                    }
//                })
            }
            
        }
        
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didUpdate progress: RouteProgress, with location: CLLocation, rawLocation: CLLocation) {
        onLocationChange?(["longitude": location.coordinate.longitude, "latitude": location.coordinate.latitude])
        onRouteProgressChange?(["distanceTraveled": progress.distanceTraveled,
                                "durationRemaining": progress.durationRemaining,
                                "fractionTraveled": progress.fractionTraveled,
                                "distanceRemaining": progress.distanceRemaining])
    }
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        if (!canceled) {
            return;
        }
        onCancelNavigation?(["message": ""]);
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) -> Bool {
        onArrive?(["message": ""]);
        return true;
    }
}


class CustomBottomBarViewController: ContainerViewController {
    
    
    override func loadView() {
        super.loadView()
        
    }
    // this will just hide the bottom progress view
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
}
