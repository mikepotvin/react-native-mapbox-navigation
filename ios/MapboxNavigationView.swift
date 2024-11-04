import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxMaps
import MapboxCoreMaps

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


    let locationProvider: LocationProvider = passiveLocationProvider
    navigationView = NavigationView(frame: self.bounds)
    navigationView.translatesAutoresizingMaskIntoConstraints = false
    self.addSubview(navigationView)
    NSLayoutConstraint.activate([
        navigationView.leadingAnchor.constraint(equalTo: self.leadingAnchor),
        navigationView.trailingAnchor.constraint(equalTo: self.trailingAnchor),
        navigationView.topAnchor.constraint(equalTo: self.topAnchor),
        navigationView.bottomAnchor.constraint(equalTo: self.bottomAnchor)
    ])
    let navigationViewportDataSource = NavigationViewportDataSource(navigationView.navigationMapView.mapView,
                                                                    viewportDataSourceType: .raw)
    navigationView.navigationMapView.navigationCamera.viewportDataSource = navigationViewportDataSource
    navigationView.navigationMapView.navigationCamera.follow()
    navigationView.navigationMapView.mapView.location.overrideLocationProvider(with: locationProvider)
    passiveLocationProvider.startUpdatingLocation()
    
    let navigationRouteOptions = NavigationRouteOptions(coordinates: [
        CLLocationCoordinate2D(latitude: 37.77766, longitude: -122.43199),
        CLLocationCoordinate2D(latitude: 37.77536, longitude: -122.43494)
    ])
    MapboxRoutingProvider().calculateRoutes(options: navigationRouteOptions) { (result) in
            switch result {
            case .failure(let error):
                print("Error occured: \(error.localizedDescription)")
            case .success(let routeResponse):
                let navigationService = MapboxNavigationService(routeResponse: routeResponse.routeResponse, routeIndex: 0, routeOptions: navigationRouteOptions, credentials: NavigationSettings.shared.directions.credentials)

                let navigationOptions = NavigationOptions(navigationService: navigationService, bottomBanner: CustomBottomBarViewController())

                let navigationViewController = NavigationViewController(for: IndexedRouteResponse(routeResponse: routeResponse.routeResponse, routeIndex: 0),
                                                                        navigationOptions: navigationOptions)
                navigationViewController.delegate = self

                // Make sure to set `transitioningDelegate` to be a current instance of `ViewController`.
                //navigationViewController.transitioningDelegate = self.parentViewController!

                // Make sure to present `NavigationViewController` in animated way.
                navigationViewController.view.frame = self.bounds
                //self.parentViewController!.present(navigationViewController, animated: true)
                //self.addSubview(navigationViewController.view)
                UIView.transition(with: self.navigationView, duration: 1, options: [.transitionCurlUp], animations: {
                    self.addSubview(navigationViewController.view)
                }, completion: nil)
                navigationViewController.didMove(toParent: self.parentViewController)
                self.navViewController = navigationViewController
                //       strongSelf.addSubview(vc.view)
                //       vc.view.frame = strongSelf.bounds
                //       vc.didMove(toParent: parentVC)
                //       strongSelf.navViewController = vc
            }
          
    }
    // navigationMapView = NavigationMapView(frame: .zero)
    // let passiveLocationManager = PassiveLocationManager()
    // self.passiveLocationManager = passiveLocationManager
    // let passiveLocationProvider = PassiveLocationProvider(locationManager: passiveLocationManager)
    // navigationMapView!.mapView.location.overrideLocationProvider(with: passiveLocationProvider)
    // self.addSubview(navigationMapView!)
    

    // let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: origin[1] as! CLLocationDegrees, longitude: origin[0] as! CLLocationDegrees))
    // let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: destination[1] as! CLLocationDegrees, longitude: destination[0] as! CLLocationDegrees))

    // var waypointsArray = [originWaypoint]
    
    // // Adding intermediate waypoints if any
    // for waypointArray in waypoints {
    //   if let waypointCoordinates = waypointArray as? NSArray, waypointCoordinates.count == 2,
    //      let lat = waypointCoordinates[1] as? CLLocationDegrees, let lon = waypointCoordinates[0] as? CLLocationDegrees {
    //     let waypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
    //     waypointsArray.append(waypoint)
    //   }
    // }
    
    // waypointsArray.append(destinationWaypoint)

    // let options = NavigationRouteOptions(waypoints: [originWaypoint, destinationWaypoint])
    //let options = NavigationRouteOptions(waypoints: [originWaypoint, destinationWaypoint], profileIdentifier: .automobileAvoidingTraffic)

/* REMOVE: https://github.com/sarafhbk/react-native-mapbox-navigation/commit/96b4e7b110b11662af0881206571b8ff6505538f
   doesn't build with 2.18.0 version of mapbox navigation sdk for ios
    if let vehicleMaxHeight = vehicleMaxHeight?.doubleValue {
        options.includesMaxHeightOnMostRestrictiveBridge = true
        options.maxHeight = vehicleMaxHeight
    }
    if let vehicleMaxWidth = vehicleMaxWidth?.doubleValue {
        options.maxWidth = vehicleMaxWidth
    }
*/

    // Directions.shared.calculate(options) { [weak self] (_, result) in
    //   guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
    //     return
    //   }
      
    //   switch result {
    //     case .failure(let error):
    //       strongSelf.onError!(["message": error.localizedDescription])
    //     case .success(let response):
    //       guard let weakSelf = self else {
    //         return
    //       }
    //       let navigationService = MapboxNavigationService(routeResponse: response, routeIndex: 0, routeOptions: options, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
          
    //       let navigationOptions = NavigationOptions(navigationService: navigationService, bottomBanner: CustomBottomBarViewController())
    //       let vc = NavigationViewController(for: response, routeIndex: 0, routeOptions: options, navigationOptions: navigationOptions)

    //       vc.shouldManageApplicationIdleTimer = false
    //       vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
    //       StatusView.appearance().isHidden = strongSelf.hideStatusView

    //       NavigationSettings.shared.voiceMuted = strongSelf.mute;
          
    //       vc.delegate = strongSelf
        
    //       parentVC.addChild(vc)
    //       strongSelf.addSubview(vc.view)
    //       vc.view.frame = strongSelf.bounds
    //       vc.didMove(toParent: parentVC)
    //       strongSelf.navViewController = vc

    //       if let muteButton = vc.floatingButtons?[1] {
    //         muteButton.addTarget(self, action: #selector(self?.toggleMute(sender:)), for: .touchUpInside)
    //       }
    //   }
      
      self.embedding = false
      self.embedded = true
    
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
