//
//  SimulatorsController.swift
//  ControlRoom
//
//  Created by Dave DeLong on 2/12/20.
//  Copyright © 2020 Paul Hudson. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

/// Handles decoding the device list from simctl
private struct DeviceList: Decodable {
    var devices: [String: [Simulator]]
}

/// A centralized class that loads simulator data and handles filtering.
class SimulatorsController: ObservableObject {

    /// Tracks the state of fetching simulator data from simctl.
    enum LoadingStatus {
        /// Loading is in progress
        case loading

        /// Loading succeeded
        case success

        /// Loading failed
        case failed
    }

    /// The current loading state; defaults to .loading
    @Published var loadingStatus: LoadingStatus = .loading

    /// An array of all simulators that match the user's current filter.
    @Published var simulators = [Simulator]()

    /// An array of all simulators that were loaded from simctl.
    private var allSimulators = [Simulator]()

    /// A string that filters the list of available simulators.
    var filterText = "" {
        willSet { objectWillChange.send() }
        didSet { filterSimulators() }
    }

    /// The simulator the user is actively working with.
    var selectedSimulator: Simulator? {
        willSet { objectWillChange.send() }
    }

    init() {
        loadSimulators()
    }

    /// Fetches all simulators from simctl.
    private func loadSimulators() {
        loadingStatus = .loading

        Command.simctl("list", "devices", "available", "-j") { result in
            switch result {
            case .success(let data):
                let list = try? JSONDecoder().decode(DeviceList.self, from: data)
                let parsed = list?.devices.values.flatMap { $0 }
                self.handleParsedSimulators(parsed)
            case .failure:
                self.handleParsedSimulators(nil)
            }
        }
    }

    /// Filters the loaded simulators and updates our UI.
    private func handleParsedSimulators(_ newSimulators: [Simulator]?) {
        objectWillChange.send()

        if let new = newSimulators {
            allSimulators = [.default] + new
            filterSimulators()
            loadingStatus = .success
        } else {
            loadingStatus = .failed
        }
    }

    /// Filters the list of simulators using `filterText`, and assigns the result to `simulators`.
    private func filterSimulators() {
        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.isEmpty == false {
            simulators = allSimulators.filter { $0.name.localizedCaseInsensitiveContains(trimmed) }
        } else {
            simulators = allSimulators
        }

        if let current = selectedSimulator {
            if simulators.firstIndex(of: current) == nil {
                // the current simulator is not in the list of filtered simulators
                // deselect it
                selectedSimulator = nil
            }
        }

        if selectedSimulator == nil {
            selectedSimulator = simulators.first
        }
    }
}
