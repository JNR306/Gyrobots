//
//  ManualLocationPickerView.swift
//  Gyrobots
//
//  Created by Mert on 1.02.2026.
//


import SwiftUI
import MapKit
import CoreLocation

struct ManualLocationPickerView: View {
    let onCancel: () -> Void
    let onUse: (CLLocationCoordinate2D) -> Void
    let onUseRealGPS: () -> Void

    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 50.7753, longitude: 6.0839), // Aachen-ish default
            span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
        )
    )
    @State private var selected: CLLocationCoordinate2D? = nil

    var body: some View {
        NavigationStack {
            MapReader { proxy in
                ZStack {
                    Map(position: $camera) {
                        if let selected {
                            Marker("Selected", coordinate: selected)
                        }
                    }
                    .mapStyle(.standard)
                    .simultaneousGesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if let coord = proxy.convert(value.location, from: .local) {
                                    selected = coord
                                }
                            }
                    )

                    VStack {
                        Spacer()
                        Text(selectedText)
                            .font(.footnote)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.bottom, 12)
                    }
                }
            }
            .navigationTitle("Pick Demo Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        guard let selected else { return }
                        onUse(selected)
                    }
                    .disabled(selected == nil)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Use Real GPS") { onUseRealGPS() }
                }
            }
        }
    }

    private var selectedText: String {
        if let selected {
            return String(format: "Lat: %.5f  Lon: %.5f", selected.latitude, selected.longitude)
        } else {
            return "Tap on the map to pick a location"
        }
    }
}
