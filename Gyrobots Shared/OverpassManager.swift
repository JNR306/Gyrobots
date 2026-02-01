//
//  OverpassManager.swift
//  Gyrobots
//
//  Created by Jan-Niklas Röhlig on 28.01.26.
//

import Foundation
import MapKit

final class OverpassManager {
    let endpoint = "https://overpass-api.de/api/interpreter"
    
    func getNearestElement(lat: Double, lon: Double) async throws -> OSMResponse {
        let query = """
            [out:json][timeout:10];

            is_in(\(lat), \(lon))->.a;

            (
              area.a["leisure"~"park|nature_reserve"];
              area.a["landuse"~"forest|park|grass"];
              area.a["natural"~"wood|sand|beach|desert"];
              area.a["boundary"="administrative"]["admin_level"="8"];
            );

            /*added by auto repair*/
            //(._;>;);
            /*end of auto repair*/

            out;
            """
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = URL(string: "\(endpoint)?data=\(encodedQuery)")!

        let (data, response) = try await URLSession.shared.data(from: url)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("HTTP Status Code: \(httpResponse.statusCode)")
        }
        
        let rawString = String(data: data, encoding: .utf8) ?? "Could not convert data to string"

        do {
            let decoded = try JSONDecoder().decode(OSMResponse.self, from: data)
            return decoded
        } catch {
            print(rawString)
            print("OVERPASS API DID NOT RESPOND")
            AppState.shared.cancelMultipeerAndReturnToMenu()
            throw error
        }
    }
}

struct OSMResponse: Codable, Sendable {
    let elements: [OSMElement]
}

struct OSMElement: Codable, Sendable {
    let type: String
    let id: Int
    let tags: [String: String]?
}


class LocationHelper: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let service = OverpassManager()
    
    private var isFetching = false
    
    var onResultFound: (@MainActor (OSMResponse?) -> Void)?
    
    func start(override: CLLocationCoordinate2D? = nil) {
        // Manual demo path: bypass GPS completely
        if let override {
            // Prevent overlapping calls
            guard !isFetching else { return }
            isFetching = true

            Task {
                await self.fetchAndSelectLevel(lat: override.latitude, lon: override.longitude)
            }
            return
        }

        // Normal GPS path (unchanged)
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, !isFetching else { return }
        isFetching = true
        manager.stopUpdatingLocation()

        Task {
            await self.fetchAndSelectLevel(
                lat: location.coordinate.latitude,
                lon: location.coordinate.longitude
            )
        }
    }

    @MainActor
    private func fetchAndSelectLevel(lat: Double, lon: Double) async {
        do {
            let response = try await service.getNearestElement(lat: lat, lon: lon)
            let elements = response.elements

            // 1. Check for Nature/Parks
            if let nature = elements.first(where: { element in
                let leisure = element.tags?["leisure"] ?? ""
                let landuse = element.tags?["landuse"] ?? ""
                return ["park", "nature_reserve"].contains(leisure)
                    || ["forest", "park", "grass"].contains(landuse)
            }) {
                print("Priority 1: Inside a Park/Forest - \(nature.tags?["name"] ?? "Unnamed")")
                AppState.shared.selectLevel(.FOREST)
            }
            // 2. Otherwise, check for Deserts/Beaches
            else if let desert = elements.first(where: { element in
                let natural = element.tags?["natural"] ?? ""
                return ["sand", "beach", "desert", "dune", "heath"].contains(natural)
            }) {
                print("Priority 2: Inside a Desert/Beach - \(desert.tags?["name"] ?? "Unnamed")")
                AppState.shared.selectLevel(.DESERT)
            }
            // 3. Finally, check for the City
            else if let city = elements.first(where: { element in
                element.tags?["boundary"] == "administrative" && element.tags?["admin_level"] == "8"
            }) {
                print("Priority 3: Inside City - \(city.tags?["name"] ?? "Unknown")")
                AppState.shared.selectLevel(.CITY)
            }
            else {
                print("No matching criteria found in elements.")
                AppState.shared.selectLevel(Level(rawValue: Int.random(in: 1...3)) ?? .CITY)
            }

            AppState.shared.wasLevelSetByLocation = true
            onResultFound?(response)
        } catch {
            print("Overpass Error: \(error)")
            AppState.shared.cancelMultipeerAndReturnToMenu()
            onResultFound?(nil)
        }

        isFetching = false
    }
}
