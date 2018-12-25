//
//  ViewController.swift
//  CaltrainHelper
//
//  Created by Jiaqi Chen on 11/4/18.
//  Copyright © 2018 Jiaqi Chen. All rights reserved.
//

import UIKit
import CoreLocation
import os
import Alamofire
import SwiftyJSON

class CaltrainTableViewCell: UITableViewCell {
    @IBOutlet weak var calTrainNumberLabel: UILabel!
    @IBOutlet weak var etaLabel: UILabel!
    @IBOutlet weak var caltrainTypeLabel: UILabel!
}

class ViewController: UIViewController, CLLocationManagerDelegate, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var directionControl: UISegmentedControl!
    @IBOutlet weak var locateButton: UIButton!
    @IBOutlet weak var caltrainStationTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    // final static variables
    let googleApiKey = "AIzaSyAzXsL8UH-bKvPGxdA_T758Wrto12J63Fk"
    let transitApiKey = "50d88fda-9e5b-4287-b431-5f6405ba576c"
    var caltrainAgencyCode = "CT"
    let refreshControl = UIRefreshControl()
    
    //global variables
    var locationManager: CLLocationManager = CLLocationManager()
    var caltrainStations: [CaltrainStation] = []
    var incommingTrains: [Caltrain] = []
    var currentLocation: CLLocation? = nil {
        willSet(newLocation) {}
        didSet {
            os_log("Current location set to: %s,%s", String(currentLocation!.coordinate.latitude), String(currentLocation!.coordinate.longitude))
            determineNearestStation()
        }
    }
    var currentNearestCaltrainStation: CaltrainStation? = nil {
        didSet {
            os_log("Current nearest caltrain station set to:%s", String(currentNearestCaltrainStation!.getName()))
            caltrainStationTextField.text = currentNearestCaltrainStation!.getName()
            if currentNearestCaltrainStation?.getName() == "San Francisco" {
                directionControl.setEnabled(false, forSegmentAt: 0) // there is no north bound traffic beyound SF
                directionControl.setEnabled(true, forSegmentAt: 1)
                directionControl.selectedSegmentIndex = 1 // south bound direction selected by default
            } else {
                if currentNearestCaltrainStation?.getName() == "Tamien" { // there is no south bound traffic beyound Tamien
                    directionControl.setEnabled(true, forSegmentAt: 0)
                    directionControl.setEnabled(false, forSegmentAt: 1)
                } else {
                    directionControl.setEnabled(true, forSegmentAt: 0)
                    directionControl.setEnabled(true, forSegmentAt: 1)
                }
                directionControl.selectedSegmentIndex = 0 // north bound direction selected by default
            }
            determinIncommingTrains()
        }
    }
    
    @IBAction func locateButtonTapped(_ sender: Any) {
        locationManager.startUpdatingLocation()
    }
    
    @IBAction func DirectionControlAction(_ sender: Any) {
        if directionControl.selectedSegmentIndex == 0 &&
            currentNearestCaltrainStation?.getName() == "San Francisco" {
            return
        }
        determinIncommingTrains()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        caltrainStationTextField.delegate = self
        tableView.delegate = self
        tableView.dataSource = self
        if #available(iOS 10.0, *) {
            tableView.refreshControl = refreshControl
        } else {
            tableView.addSubview(refreshControl)
        }
        refreshControl.addTarget(self, action: #selector(refreshIncommingTrainData(_:)), for: .valueChanged)
        refreshControl.tintColor = UIColor(red:0.25, green:0.72, blue:0.85, alpha:1.0)
        refreshControl.attributedTitle = NSAttributedString(string: "Fetching Data...")
        
        initializeStations()
        determineCurrentLocation()
        createCaltrainStationPicker()
        createCaltrainStationTextFieldToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func refreshIncommingTrainData(_ sender: Any) {
        determinIncommingTrains()
    }
    
    func determineCurrentLocation() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.requestAlwaysAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Call stopUpdatingLocation() to stop listening for location updates,
        // other wise this function will be called every time when user location changes.
        if let userLocarion = locations.first {
            os_log("New location detected: %s,%s", String(userLocarion.coordinate.latitude), String(userLocarion.coordinate.longitude))
            currentLocation = userLocarion
        } else {
            os_log("Error getting current location")
        }
        manager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error)
    {
        os_log("Error getting current location: %s", error.localizedDescription)
    }
    
    func initializeStations() {
        caltrainStations = [
            //zone one
            CaltrainStation(name: "San Francisco", latitude: 37.779806, longtitude: -122.392545, nbStopCode: -1, sbStopCode: 70012),
            CaltrainStation(name: "22nd St", latitude: 37.761385, longtitude: -122.392416, nbStopCode: 70021, sbStopCode: 70022),
            CaltrainStation(name: "Bayshore", latitude: 37.713311, longtitude: -122.400377, nbStopCode: 70031, sbStopCode: 70032),
            CaltrainStation(name: "South San Francisco", latitude: 37.6585682, longtitude: -122.4043898, nbStopCode: 70041, sbStopCode: 70042),
            CaltrainStation(name: "San Bruno", latitude: 37.6297005, longtitude: -122.411359, nbStopCode: 70051, sbStopCode: 70052),
            //zone two
            CaltrainStation(name: "Millbrae", latitude: 37.603641, longtitude: -122.386107, nbStopCode: 70061, sbStopCode: 70062),
            CaltrainStation(name: "Burlingame", latitude: 37.583647, longtitude: -122.344909, nbStopCode: 70081, sbStopCode: 70082),
            CaltrainStation(name: "San Mateo", latitude: 37.568209, longtitude: -122.323933, nbStopCode: 70091, sbStopCode: 70092),
            CaltrainStation(name: "Hayward Park", latitude: 37.552938, longtitude: -122.309338, nbStopCode: 70101, sbStopCode: 70102),
            CaltrainStation(name: "Hillsdale", latitude: 37.5378688, longtitude: -122.297349, nbStopCode: 70111, sbStopCode: 70112),
            CaltrainStation(name: "Belmont", latitude: 37.52089, longtitude: -122.275738, nbStopCode: 70121, sbStopCode: 70122),
            CaltrainStation(name: "San Carlos", latitude: 37.507933, longtitude: -122.260266, nbStopCode: 70131, sbStopCode: 70132),
            CaltrainStation(name: "Redwood City", latitude: 37.486159, longtitude: -122.231936, nbStopCode: 70141, sbStopCode: 70142),
            // zone three
            CaltrainStation(name: "Menlo Park", latitude: 37.454856, longtitude: -122.182297, nbStopCode: 70161, sbStopCode: 70162),
            CaltrainStation(name: "Palo Alto", latitude: 37.443475, longtitude: -122.164614, nbStopCode: 70171, sbStopCode: 70172),
            CaltrainStation(name: "California Ave", latitude: 37.429365, longtitude: -122.141927, nbStopCode: 70191, sbStopCode: 70192),
            CaltrainStation(name: "San Antonio", latitude: 37.407323, longtitude: -122.107069, nbStopCode: 70201, sbStopCode: 70202),
            CaltrainStation(name: "Mountain View", latitude: 37.394459, longtitude: -122.075956, nbStopCode: 70211, sbStopCode: 70212),
            CaltrainStation(name: "Sunnyvale", latitude: 37.378789, longtitude: -122.031423, nbStopCode: 70221, sbStopCode: 70222),
            //zone four
            CaltrainStation(name: "Lawrence", latitude: 37.370598, longtitude: -121.997114, nbStopCode: 70231, sbStopCode: 70232),
            CaltrainStation(name: "Santa Clara", latitude: 37.353238, longtitude: -121.93608, nbStopCode: 70241, sbStopCode: 70242),
            CaltrainStation(name: "College Park", latitude: 37.342384, longtitude: -121.9146, nbStopCode: 70251, sbStopCode: 70252),
            CaltrainStation(name: "San Jose Diridon", latitude: 37.329239, longtitude: -121.903011, nbStopCode: 70261, sbStopCode: 70262),
            CaltrainStation(name: "Tamien", latitude: 37.31174, longtitude: -121.883721, nbStopCode: 70271, sbStopCode: 70272),
        ]
    }
    
    func determinIncommingTrains() {
        let apiCallGroup = DispatchGroup()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        
        apiCallGroup.enter()
        
        var stopCode: Int
        if directionControl.selectedSegmentIndex == 1 {
            stopCode = currentNearestCaltrainStation!.getSbCode()
        } else {
            stopCode = currentNearestCaltrainStation!.getNbCode()
        }
        
        let transitApiUrl = "https://api.511.org/transit/VehicleMonitoring?api_key=\(transitApiKey)&agency=\(caltrainAgencyCode)"
        os_log("Checking caltrain information for stop: %d", stopCode)
        Alamofire.request(
            transitApiUrl,
            method: .get)
            .validate()
            .responseJSON { response in
                self.incommingTrains = []
                guard response.result.isSuccess else {
                    os_log("Error getting transit data for stop: %d", stopCode)
                    return
                }
                let jsonResponse = JSON(response.result.value!)
                let vehicleActivities = jsonResponse["Siri"]["ServiceDelivery"]["VehicleMonitoringDelivery"]["VehicleActivity"]
                for vehicleActivity in vehicleActivities.arrayValue {
                    let monitoredVehicleJourney = vehicleActivity["MonitoredVehicleJourney"]
                    let caltrainType = monitoredVehicleJourney["LineRef"].stringValue
                    let vehicleRef = monitoredVehicleJourney["VehicleRef"].intValue
                    let onwardCalls = monitoredVehicleJourney["OnwardCall"]["OnwardCall"].arrayValue
                    for onwardCall in onwardCalls {
                        if onwardCall["StopPointRef"].intValue == stopCode{
                            let aimedDepartureTimeString = onwardCall["ExpectedDepartureTime"].stringValue
                            let aimedDepartureTime: Date? = dateFormatter.date(from: aimedDepartureTimeString)
                            let timeInterval: Double = aimedDepartureTime!.timeIntervalSince(Date())
                            let minutes: Int? = timeInterval/60.0 < 1 ? 1 : Int(String(format: "%.0f", timeInterval/60.0))
                            self.incommingTrains.append(Caltrain(number: vehicleRef, eta: minutes!, type: caltrainType))
                        }
                    }
                }
                apiCallGroup.leave()
        }
        
        apiCallGroup.notify(queue: .main) {
            self.incommingTrains = self.incommingTrains.sorted(by: {$0.getEta() < $1.getEta()})
            self.tableView.reloadData()
            self.refreshControl.endRefreshing()
        }
    }
    
    func determineNearestStation() {
        var minDistance = INTPTR_MAX
        var localNearestStation: CaltrainStation?
        
        let apiCallGroup = DispatchGroup()
        
        for caltrainStation in self.caltrainStations {
            apiCallGroup.enter()
            let destination = "\(caltrainStation.getLatitude()),\(caltrainStation.longtitude)"
            let origin = "\(currentLocation!.coordinate.latitude),\(currentLocation!.coordinate.longitude)"
            let distanceUrl = "https://maps.googleapis.com/maps/api/distancematrix/json?units=imperial&origins=\(origin)&destinations=\(destination)&key=\(googleApiKey)"
            
            Alamofire.request(
                distanceUrl,
                method: .get)
                .validate()
                .responseJSON { response in
                    guard response.result.isSuccess else {
                        os_log("Error getting distance between %s and %s", origin, destination)
                        return
                    }
                    let jsonResponse = JSON(response.result.value!)
                    let distance = jsonResponse["rows"][0]["elements"][0]["distance"]["value"].intValue
                    if distance < minDistance {
                        minDistance = distance
                        localNearestStation = caltrainStation
                    }
                    apiCallGroup.leave()
            }
        }
        
        apiCallGroup.notify(queue: .main) {
            self.currentNearestCaltrainStation = localNearestStation
        }
    }
    
    func createCaltrainStationPicker() {
        let stationPicker = UIPickerView()
        stationPicker.delegate = self
        caltrainStationTextField.inputView = stationPicker
    }
    
    func createCaltrainStationTextFieldToolbar() {
        let toolBar = UIToolbar()
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(ViewController.dismissKeyboard))
        
        toolBar.setItems([doneButton], animated: false)
        toolBar.isUserInteractionEnabled = true
        caltrainStationTextField.inputAccessoryView = toolBar
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
}

extension ViewController: UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return caltrainStations.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return caltrainStations[row].getName()
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentNearestCaltrainStation = caltrainStations[row]
        caltrainStationTextField.text = currentNearestCaltrainStation!.getName()
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.incommingTrains.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CaltrainCell", for: indexPath) as! CaltrainTableViewCell
        
        cell.calTrainNumberLabel.text = String(self.incommingTrains[indexPath.row].getNumber())
        cell.etaLabel.text = "\(self.incommingTrains[indexPath.row].getEta()) min"
        cell.caltrainTypeLabel.text = self.incommingTrains[indexPath.row].getType()
        return cell
    }
}

