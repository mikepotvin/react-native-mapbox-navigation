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
    private let passiveLocationManager = PassiveLocationManager()
    private lazy var passiveLocationProvider = PassiveLocationProvider(locationManager: passiveLocationManager)
    
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
    
    var navigationView: NavigationView!
    
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
    }
    
    @objc private func toggleMute(sender: UIButton) {
        onMuteChange?(["isMuted": sender.isSelected]);
    }
    
    private func embed() {
        guard origin.count == 2 && destination.count == 2 else { return }
        
        embedding = true
        
        
        navigationView = NavigationView(frame: self.bounds)
        navigationView.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(navigationView)
        NSLayoutConstraint.activate([
            navigationView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
            navigationView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            navigationView.topAnchor.constraint(equalTo: self.topAnchor),
            navigationView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        ])
        StatusView.appearance().isHidden = self.hideStatusView
        let navigationViewportDataSource = NavigationViewportDataSource(navigationView.navigationMapView.mapView,
                                                                        viewportDataSourceType: .raw)
        navigationView.navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
        navigationView.navigationMapView.navigationCamera.follow()
        passiveLocationProvider.startUpdatingLocation()
        
        let navigationRouteOptions = NavigationRouteOptions(coordinates: [
            CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees),
            CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees)
        ], profileIdentifier: .automobileAvoidingTraffic)
        MapboxRoutingProvider().calculateRoutes(options: navigationRouteOptions) { (result) in
            switch result {
            case .failure(let error):
                print("Error occured: \(error.localizedDescription)")
            case .success(let routeResponse):
                let navigationService = MapboxNavigationService(indexedRouteResponse: routeResponse, credentials: NavigationSettings.shared.directions.credentials, simulating: self.shouldSimulateRoute ? .always : .never)
                
                let navigationOptions = NavigationOptions(navigationService: navigationService, bottomBanner: CustomBottomBarViewController())
                
                let navigationViewController = NavigationViewController(for: routeResponse,
                                                                        navigationOptions: navigationOptions)
                navigationViewController.delegate = self
                
                navigationViewController.shouldManageApplicationIdleTimer = false
                navigationViewController.showsEndOfRouteFeedback = self.showsEndOfRouteFeedback
                
                
                NavigationSettings.shared.voiceMuted = self.mute;
                
                if let muteButton = navigationViewController.floatingButtons?[1] {
                    muteButton.addTarget(self, action: #selector(self.toggleMute(sender:)), for: .touchUpInside)
                }
                
                navigationViewController.view.frame = self.bounds
                UIView.transition(with: self.navigationView, duration: 1, options: [.transitionCurlUp], animations: {
                    //navigationViewController.navigationMapView = self.navigationView.navigationMapView
                    self.addSubview(navigationViewController.view)
                }, completion: { (success) -> Void in
                    if success {
                        self.navigationView.removeFromSuperview()
                    }
                })
                self.navViewController = navigationViewController
                self.parentViewController?.addChild(navigationViewController)
                navigationViewController.didMove(toParent: self.parentViewController)
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
