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

class ViewController: UIViewController, CLLocationManagerDelegate {
    @IBOutlet weak var directionControl: UISegmentedControl!
    @IBOutlet weak var locateButton: UIButton!
    @IBOutlet weak var caltrainStationTextField: UITextField!
    @IBOutlet weak var etaLabel: UILabel!
    @IBOutlet weak var scrollView: UIScrollView!
    
    // final static variables
    let googleApiKey = "AIzaSyAzXsL8UH-bKvPGxdA_T758Wrto12J63Fk"
    let transitApiKey = "50d88fda-9e5b-4287-b431-5f6405ba576c"
    var caltrainAgencyCode = "CT"
    
    //global variables
    var locationManager: CLLocationManager = CLLocationManager()
    var caltrainStations: [CaltrainStation] = []
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
                directionControl.setEnabled(false, forSegmentAt: 0) // there is no north bound traffic from SF
                directionControl.selectedSegmentIndex = 1 // south bound direction selected by default
            } else {
                directionControl.setEnabled(true, forSegmentAt: 0)
                directionControl.selectedSegmentIndex = 0 // north bound direction selected by default
            }
            determinETA()
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
        determinETA()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.etaLabel.text = "loading..."
        caltrainStationTextField.delegate = self
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
        ]
    }
    
    func determinETA() {
        let apiCallGroup = DispatchGroup()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        
        
        apiCallGroup.enter()
        
        var minTimeInterval: Double = Double.greatestFiniteMagnitude
        var stopCode: Int
        if directionControl.selectedSegmentIndex == 1 {
            stopCode = currentNearestCaltrainStation!.getSbCode()
        } else {
            stopCode = currentNearestCaltrainStation!.getNbCode()
        }
        
        let transitApiUrl = "https://api.511.org/transit/StopMonitoring?api_key=\(transitApiKey)&agency=\(caltrainAgencyCode)&stopCode=\(stopCode)"
        
        Alamofire.request(
            transitApiUrl,
            method: .get)
            .validate()
            .responseJSON { response in
                guard response.result.isSuccess else {
                    os_log("Error getting transit data for stop: %d", stopCode)
                    return
                }
                let jsonResponse = JSON(response.result.value!)
                let monitoredStopVisit = jsonResponse["ServiceDelivery"]["StopMonitoringDelivery"]["MonitoredStopVisit"]
                for stopVisit in monitoredStopVisit.arrayValue {
                    let monitoredVehicleJourney = stopVisit["MonitoredVehicleJourney"]
                    let monitoredCall = monitoredVehicleJourney["MonitoredCall"]
                    let aimedDepartureTimeString = monitoredCall["AimedDepartureTime"].stringValue
                    let aimedDepartureTime: Date? = dateFormatter.date(from: aimedDepartureTimeString)
                    
                    let timeInterval: Double = aimedDepartureTime!.timeIntervalSince(Date())
                    
                    if timeInterval < minTimeInterval {
                        minTimeInterval = timeInterval
                    }
                }
                apiCallGroup.leave()
        }
        
        apiCallGroup.notify(queue: .main) {
            let minutes: Double = minTimeInterval/60.0
            if minutes < 1 {
                self.etaLabel.text = "< 1 min"
            } else if minTimeInterval != Double.greatestFiniteMagnitude {
                self.etaLabel.text = "\(String(format: "%.0f", minutes)) min"
            } else {
                self.etaLabel.text = "No data"
            }
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
}

