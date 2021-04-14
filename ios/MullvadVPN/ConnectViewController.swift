//
//  ConnectViewController.swift
//  MullvadVPN
//
//  Created by pronebird on 20/03/2019.
//  Copyright © 2019 Mullvad VPN AB. All rights reserved.
//

import UIKit
import MapKit
import Logging

class CustomOverlayRenderer: MKOverlayRenderer {
    override func draw(_ mapRect: MKMapRect, zoomScale: MKZoomScale, in context: CGContext) {
        let drawRect = self.rect(for: mapRect)
        context.setFillColor(UIColor.secondaryColor.cgColor)
        context.fill(drawRect)
    }
}

protocol ConnectViewControllerDelegate: class {
    func connectViewControllerShouldShowSelectLocationPicker(_ controller: ConnectViewController)
    func connectViewControllerShouldConnectTunnel(_ controller: ConnectViewController)
    func connectViewControllerShouldDisconnectTunnel(_ controller: ConnectViewController)
    func connectViewControllerShouldReconnectTunnel(_ controller: ConnectViewController)
}

class ConnectViewController: UIViewController, MKMapViewDelegate, RootContainment, TunnelObserver, AccountObserver
{
    weak var delegate: ConnectViewControllerDelegate?

    private let mainContentView: ConnectMainContentView = {
        let view = ConnectMainContentView(frame: UIScreen.main.bounds)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let logger = Logger(label: "ConnectViewController")

    private var lastLocation: CLLocationCoordinate2D?
    private let locationMarker = MKPointAnnotation()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    var preferredHeaderBarStyle: HeaderBarStyle {
        if !Account.shared.isLoggedIn {
            return .default
        }
        switch tunnelState {
        case .connecting, .reconnecting, .connected:
            return .secured

        case .disconnecting, .disconnected:
            return .unsecured
        }
    }

    var prefersHeaderBarHidden: Bool {
        return false
    }

    private var tunnelState: TunnelState = .disconnected {
        didSet {
            setNeedsHeaderBarStyleAppearanceUpdate()
            updateTunnelConnectionInfo()
            updateUserInterfaceForTunnelStateChange()

            // Avoid unnecessary animations, particularly when this property is changed from inside
            // the `viewDidLoad`.
            let isViewVisible = self.viewIfLoaded?.window != nil

            updateLocation(animated: isViewVisible)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        mainContentView.connectionPanel.collapseButton.addTarget(self, action: #selector(handleConnectionPanelButton(_:)), for: .touchUpInside)
        mainContentView.connectButton.addTarget(self, action: #selector(handleConnect(_:)), for: .touchUpInside)
        mainContentView.splitDisconnectButton.primaryButton.addTarget(self, action: #selector(handleDisconnect(_:)), for: .touchUpInside)
        mainContentView.splitDisconnectButton.secondaryButton.addTarget(self, action: #selector(handleReconnect(_:)), for: .touchUpInside)

        mainContentView.selectLocationButton.addTarget(self, action: #selector(handleSelectLocation(_:)), for: .touchUpInside)

        TunnelManager.shared.addObserver(self)
        self.tunnelState = TunnelManager.shared.tunnelState

        addSubviews()
        setupMapView()
        updateLocation(animated: false)

        Account.shared.addObserver(self)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if previousTraitCollection?.userInterfaceIdiom != traitCollection.userInterfaceIdiom ||
            previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
            updateTraitDependentViews()
        }
    }

    func setMainContentHidden(_ isHidden: Bool, animated: Bool) {
        let actions = {
            self.mainContentView.containerView.alpha = isHidden ? 0 : 1
        }

        if animated {
            UIView.animate(withDuration: 0.25, animations: actions)
        } else {
            actions()
        }
    }

    private func addSubviews() {
        view.addSubview(mainContentView)
        NSLayoutConstraint.activate([
            mainContentView.topAnchor.constraint(equalTo: view.topAnchor),
            mainContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainContentView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - AccountObserver

    func account(_ account: Account, didLoginWithToken token: String, expiry: Date) {
        setNeedsHeaderBarStyleAppearanceUpdate()
    }

    func account(_ account: Account, didUpdateExpiry expiry: Date) {
        // no-op
    }

    func accountDidLogout(_ account: Account) {
        setNeedsHeaderBarStyleAppearanceUpdate()
    }

    // MARK: - TunnelObserver

    func tunnelStateDidChange(tunnelState: TunnelState) {
        DispatchQueue.main.async {
            self.tunnelState = tunnelState
        }
    }

    func tunnelPublicKeyDidChange(publicKeyWithMetadata: PublicKeyWithMetadata?) {
        // no-op
    }

    // MARK: - Private

    private func updateUserInterfaceForTunnelStateChange() {
        mainContentView.secureLabel.text = tunnelState.localizedTitleForSecureLabel.uppercased()
        mainContentView.secureLabel.textColor = tunnelState.textColorForSecureLabel

        mainContentView.connectButton.setTitle(tunnelState.localizedTitleForConnectButton, for: .normal)
        mainContentView.selectLocationButton.setTitle(tunnelState.localizedTitleForSelectLocationButton, for: .normal)
        mainContentView.splitDisconnectButton.primaryButton.setTitle(tunnelState.localizedTitleForDisconnectButton, for: .normal)

        updateTraitDependentViews()
    }

    private func updateTraitDependentViews() {
        mainContentView.setActionButtons(tunnelState.actionButtons(traitCollection: self.traitCollection))
    }

    private func attributedStringForLocation(string: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 0
        paragraphStyle.lineHeightMultiple = 0.80
        return NSAttributedString(string: string, attributes: [
            .paragraphStyle: paragraphStyle])
    }

    private func updateTunnelConnectionInfo() {
        switch tunnelState {
        case .connected(let connectionInfo),
             .reconnecting(let connectionInfo):
            mainContentView.cityLabel.attributedText = attributedStringForLocation(string: connectionInfo.location.city)
            mainContentView.countryLabel.attributedText = attributedStringForLocation(string: connectionInfo.location.country)

            mainContentView.connectionPanel.dataSource = ConnectionPanelData(
                inAddress: "\(connectionInfo.ipv4Relay) UDP",
                outAddress: nil
            )
            mainContentView.connectionPanel.isHidden = false
            mainContentView.connectionPanel.collapseButton.setTitle(connectionInfo.hostname, for: .normal)

        case .connecting, .disconnected, .disconnecting:
            mainContentView.cityLabel.attributedText = attributedStringForLocation(string: " ")
            mainContentView.countryLabel.attributedText = attributedStringForLocation(string: " ")
            mainContentView.connectionPanel.dataSource = nil
            mainContentView.connectionPanel.isHidden = true
        }
    }

    private func locationMarkerOffset() -> CGPoint {
        // The spacing between the secure label and the marker
        let markerSecureLabelSpacing = CGFloat(22)

        // Compute the secure label's frame within the view coordinate system
        let secureLabelFrame = mainContentView.secureLabel.convert(mainContentView.secureLabel.bounds, to: view)

        // The marker's center coincides with the geo coordinate
        let markerAnchorOffsetInPoints = locationMarkerSecureImage.size.height * 0.5

        // Compute the distance from the top of the label's frame to the center of the map
        let secureLabelDistanceToMapCenterY = secureLabelFrame.minY - mainContentView.mapView.frame.midY

        // Compute the marker offset needed to position it above the secure label
        let offsetY = secureLabelDistanceToMapCenterY - markerAnchorOffsetInPoints - markerSecureLabelSpacing

        return CGPoint(x: 0, y: offsetY)
    }

    private func computeCoordinateRegion(centerCoordinate: CLLocationCoordinate2D, centerOffsetInPoints: CGPoint) -> MKCoordinateRegion  {
        let span = MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        var region = MKCoordinateRegion(center: centerCoordinate, span: span)
        region = mainContentView.mapView.regionThatFits(region)

        let latitudeDeltaPerPoint = region.span.latitudeDelta / Double(mainContentView.mapView.frame.height)
        var offsetCenter = centerCoordinate
        offsetCenter.latitude += CLLocationDegrees(latitudeDeltaPerPoint * Double(centerOffsetInPoints.y))
        region.center = offsetCenter

        return region
    }

    private func updateLocation(animated: Bool) {
        switch tunnelState {
        case .connected(let connectionInfo),
             .reconnecting(let connectionInfo):
            let coordinate = connectionInfo.location.geoCoordinate
            if let lastLocation = self.lastLocation, coordinate.approximatelyEqualTo(lastLocation) {
                return
            }

            let markerOffset = locationMarkerOffset()
            let region = computeCoordinateRegion(centerCoordinate: coordinate, centerOffsetInPoints: markerOffset)

            locationMarker.coordinate = coordinate
            mainContentView.mapView.addAnnotation(locationMarker)
            mainContentView.mapView.setRegion(region, animated: animated)

            self.lastLocation = coordinate

        case .disconnected, .disconnecting:
            let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
            if let lastLocation = self.lastLocation, coordinate.approximatelyEqualTo(lastLocation) {
                return
            }

            let span = MKCoordinateSpan(latitudeDelta: 90, longitudeDelta: 90)
            let region = MKCoordinateRegion(center: coordinate, span: span)
            mainContentView.mapView.removeAnnotation(locationMarker)
            mainContentView.mapView.setRegion(region, animated: animated)

            self.lastLocation = coordinate

        case .connecting:
            break
        }
    }

    // MARK: - Actions

    @objc func handleConnectionPanelButton(_ sender: Any) {
        mainContentView.connectionPanel.toggleConnectionInfoVisibility()
    }

    @objc func handleConnect(_ sender: Any) {
        delegate?.connectViewControllerShouldConnectTunnel(self)
    }

    @objc func handleDisconnect(_ sender: Any) {
        delegate?.connectViewControllerShouldDisconnectTunnel(self)
    }

    @objc func handleReconnect(_ sender: Any) {
        delegate?.connectViewControllerShouldReconnectTunnel(self)
    }

    @objc func handleSelectLocation(_ sender: Any) {
        delegate?.connectViewControllerShouldShowSelectLocationPicker(self)
    }

    // MARK: - MKMapViewDelegate

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polygon = overlay as? MKPolygon {
            let renderer = MKPolygonRenderer(polygon: polygon)
            renderer.fillColor = UIColor.primaryColor
            renderer.strokeColor = UIColor.secondaryColor
            renderer.lineWidth = 1.0
            renderer.lineCap = .round
            renderer.lineJoin = .round

            return renderer
        }

        if #available(iOS 13, *) {
            if let multiPolygon = overlay as? MKMultiPolygon {
                let renderer = MKMultiPolygonRenderer(multiPolygon: multiPolygon)
                renderer.fillColor = UIColor.primaryColor
                renderer.strokeColor = UIColor.secondaryColor
                renderer.lineWidth = 1.0
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
        }

        if let tileOverlay = overlay as? MKTileOverlay {
            return CustomOverlayRenderer(overlay: tileOverlay)
        }

        fatalError()
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation === locationMarker {
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: "location", for: annotation)
            view.isDraggable = false
            view.canShowCallout = false
            view.image = self.locationMarkerSecureImage
            return view
        }
        return nil
    }

    // MARK: - Private

    private var locationMarkerSecureImage: UIImage {
        return UIImage(named: "LocationMarkerSecure")!
    }

    private func setupMapView() {
        mainContentView.mapView.insetsLayoutMarginsFromSafeArea = false
        mainContentView.mapView.delegate = self
        mainContentView.mapView.register(MKAnnotationView.self, forAnnotationViewWithReuseIdentifier: "location")

        if #available(iOS 13.0, *) {
            // Use dark style for the map to dim the map grid
            mainContentView.mapView.overrideUserInterfaceStyle = .dark
        }

        addTileOverlay()
        loadGeoJSONData()
        hideMapsAttributions()
    }

    private func addTileOverlay() {
        // Use `nil` for template URL to make sure that Apple maps do not load
        // tiles from remote.
        let tileOverlay = MKTileOverlay(urlTemplate: nil)

        // Replace the default map tiles
        tileOverlay.canReplaceMapContent = true

        mainContentView.mapView.addOverlay(tileOverlay)
    }

    private func loadGeoJSONData() {
        let fileURL = Bundle.main.url(forResource: "countries.geo", withExtension: "json")!
        let data = try! Data(contentsOf: fileURL)

        let overlays = try! GeoJSON.decodeGeoJSON(data)
        mainContentView.mapView.addOverlays(overlays, level: .aboveLabels)
    }

    private func hideMapsAttributions() {
        for subview in mainContentView.mapView.subviews {
            if subview.description.starts(with: "<MKAttributionLabel") {
                subview.isHidden = true
            }
        }
    }
}

private extension TunnelState {

    var textColorForSecureLabel: UIColor {
        switch self {
        case .connecting, .reconnecting:
            return .white

        case .connected:
            return .successColor

        case .disconnecting, .disconnected:
            return .dangerColor
        }
    }

    var localizedTitleForSecureLabel: String {
        switch self {
        case .connecting, .reconnecting:
            return NSLocalizedString("Creating secure connection", comment: "")

        case .connected:
            return NSLocalizedString("Secure connection", comment: "")

        case .disconnecting, .disconnected:
            return NSLocalizedString("Unsecured connection", comment: "")
        }
    }

    var localizedTitleForSelectLocationButton: String? {
        switch self {
        case .disconnected, .disconnecting:
            return NSLocalizedString("Select location", comment: "")
        case .connecting, .connected, .reconnecting:
            return NSLocalizedString("Switch location", comment: "")
        }
    }

    var localizedTitleForConnectButton: String? {
        return NSLocalizedString("Secure connection", comment: "")
    }

    var localizedTitleForDisconnectButton: String? {
        switch self {
        case .connecting:
            return NSLocalizedString("Cancel", comment: "")
        case .connected, .reconnecting:
            return NSLocalizedString("Disconnect", comment: "")
        case .disconnecting, .disconnected:
            return nil
        }
    }

    func actionButtons(traitCollection: UITraitCollection) -> [ConnectMainContentView.ActionButton] {
        switch (traitCollection.userInterfaceIdiom, traitCollection.horizontalSizeClass) {
        case (.phone, _), (.pad, .compact):
            switch self {
            case .disconnected, .disconnecting:
                return [.selectLocation, .connect]

            case .connecting, .connected, .reconnecting:
                return [.selectLocation, .disconnect]
            }

        case (.pad, .regular):
            switch self {
            case .disconnected, .disconnecting:
                return [.connect]

            case .connecting, .connected, .reconnecting:
                return [.disconnect]
            }

        default:
            return []
        }
    }

}

extension CLLocationCoordinate2D {
    func approximatelyEqualTo(_ other: CLLocationCoordinate2D) -> Bool {
        return fabs(self.latitude - other.latitude) <= .ulpOfOne &&
            fabs(self.longitude - other.longitude) <= .ulpOfOne
    }
}

extension MKCoordinateRegion {
    var mapRect: MKMapRect {
        let topLeft = CLLocationCoordinate2D(latitude: self.center.latitude + (self.span.latitudeDelta/2), longitude: self.center.longitude - (self.span.longitudeDelta/2))
        let bottomRight = CLLocationCoordinate2D(latitude: self.center.latitude - (self.span.latitudeDelta/2), longitude: self.center.longitude + (self.span.longitudeDelta/2))

        let a = MKMapPoint(topLeft)
        let b = MKMapPoint(bottomRight)

        return MKMapRect(x: min(a.x, b.x),
                         y: min(a.y, b.y),
                         width: abs(a.x - b.x),
                         height: abs(a.y - b.y)
        )
    }
}
