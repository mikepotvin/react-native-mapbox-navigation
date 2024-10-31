import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections

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
  var embedded: Bool
  var embedding: Bool
  private let routingProvider = MapboxRoutingProvider() // Instantiate MapboxRoutingProvider
  
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
    guard origin.count == 2, destination.count == 2,
          let latOrigin = origin[1] as? CLLocationDegrees,
          let lonOrigin = origin[0] as? CLLocationDegrees,
          let latDest = destination[1] as? CLLocationDegrees,
          let lonDest = destination[0] as? CLLocationDegrees else {
        onError?(["message": "Invalid origin or destination coordinates."])
        return
    }
    
    embedding = true

    let originWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: latOrigin, longitude: lonOrigin))
    let destinationWaypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: latDest, longitude: lonDest))

    var waypointsArray = [originWaypoint]
    
    // Adding intermediate waypoints if any
    for waypointArray in waypoints {
      if let waypointCoordinates = waypointArray as? NSArray, waypointCoordinates.count == 2,
         let lat = waypointCoordinates[1] as? CLLocationDegrees, let lon = waypointCoordinates[0] as? CLLocationDegrees {
        let waypoint = Waypoint(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
        waypointsArray.append(waypoint)
      }
    }
    
    waypointsArray.append(destinationWaypoint)

    // let options = NavigationRouteOptions(waypoints: [originWaypoint, destinationWaypoint])
    let options = NavigationRouteOptions(waypoints: [originWaypoint, destinationWaypoint], profileIdentifier: .automobileAvoidingTraffic)

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
    // update calculate method: replaced Directions.shared.calculate method with routingProvider.calculateRoutes
    routingProvider.calculateRoutes(options: options) { [weak self] result in
      guard let strongSelf = self, let parentVC = strongSelf.parentViewController else {
        return
      }
      
      switch result {
        case .failure(let error):
          strongSelf.onError?(["message": error.localizedDescription])
        case .success(let indexedRouteResponse): // indexedRouteResponse is an array of RouteResponse
          guard let self = self else {
            return
          }
          let navigationService = MapboxNavigationService(indexedRouteResponse: indexedRouteResponse, customRoutingProvider: self.routingProvider, credentials: NavigationSettings.shared.directions.credentials, simulating: strongSelf.shouldSimulateRoute ? .always : .never)
          
          let navigationOptions = NavigationOptions(navigationService: navigationService, bottomBanner: CustomBottomBarViewController())
          let vc = NavigationViewController(for: indexedRouteResponse, navigationOptions: navigationOptions)

          vc.shouldManageApplicationIdleTimer = false
          vc.showsEndOfRouteFeedback = strongSelf.showsEndOfRouteFeedback
          StatusView.appearance().isHidden = strongSelf.hideStatusView

          NavigationSettings.shared.voiceMuted = strongSelf.mute;
          
          vc.delegate = strongSelf
        
          parentVC.addChild(vc)
          strongSelf.addSubview(vc.view)
          vc.view.frame = strongSelf.bounds
          vc.didMove(toParent: parentVC)
          strongSelf.navViewController = vc

          if let muteButton = vc.floatingButtons?[1] {
            muteButton.addTarget(self, action: #selector(self?.toggleMute(sender:)), for: .touchUpInside)
          }
      }
      
      strongSelf.embedding = false
      strongSelf.embedded = true
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
