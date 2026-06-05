//
//  BagRunnerStore.swift
//  Baggage Runner
//
//  Created by Codex on 2026-05-25.
//

import Combine
import Foundation

final class BagRunnerStore: ObservableObject {
    @Published var flights: [InboundFlight] = [] {
        didSet { save() }
    }

    @Published var settings = BagRunnerSettings() {
        didSet { save() }
    }

    var sortedFlights: [InboundFlight] {
        flights.sorted { $0.parkingBrakesSetTime > $1.parkingBrakesSetTime }
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL
        load()

        if flights.isEmpty {
            flights = Self.sampleFlights
        }
    }

    func flight(with id: UUID) -> InboundFlight? {
        flights.first { $0.id == id }
    }

    func upsertFlight(_ flight: InboundFlight) {
        if let index = flights.firstIndex(where: { $0.id == flight.id }) {
            flights[index] = flight
        } else {
            flights.append(flight)
        }
    }

    func deleteFlights(at offsets: IndexSet) {
        let orderedIDs = sortedFlights.map(\.id)
        let idsToDelete = offsets.map { orderedIDs[$0] }
        flights.removeAll { idsToDelete.contains($0.id) }
    }

    func upsertConnection(_ connection: ConnectionBagGroup, in flightID: UUID) {
        guard let flightIndex = flights.firstIndex(where: { $0.id == flightID }) else { return }

        if let connectionIndex = flights[flightIndex].connections.firstIndex(where: { $0.id == connection.id }) {
            flights[flightIndex].connections[connectionIndex] = connection
        } else {
            flights[flightIndex].connections.append(connection)
        }
    }

    func deleteConnection(_ connectionID: UUID, from flightID: UUID) {
        guard let flightIndex = flights.firstIndex(where: { $0.id == flightID }) else { return }
        flights[flightIndex].connections.removeAll { $0.id == connectionID }
    }

    func save() {
        do {
            let payload = BagRunnerPayload(flights: flights, settings: settings)
            let data = try JSONEncoder.bagRunner.encode(payload)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            print("Unable to save BagRunner data: \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            let payload = try JSONDecoder.bagRunner.decode(BagRunnerPayload.self, from: data)
            flights = payload.flights
            settings = payload.settings
        } catch {
            flights = []
            settings = BagRunnerSettings()
        }
    }

    private static var defaultFileURL: URL {
        URL.documentsDirectory.appending(path: "BagRunnerData.json")
    }

    private static var sampleFlights: [InboundFlight] {
        let now = Date()
        return [
            InboundFlight(
                flightNumber: "AC123",
                origin: "YYZ",
                arrivalGate: "B12",
                parkingBrakesSetTime: now.addingTimeInterval(-6 * 60),
                totalBags: 86,
                localBagCount: 52,
                connections: [
                    ConnectionBagGroup(
                        outboundFlightNumber: "WS456",
                        destination: "YVR",
                        connectionType: .domestic,
                        departureTime: now.addingTimeInterval(58 * 60),
                        departureGate: "C32",
                        bagCount: 7,
                        status: .pending,
                        notes: "Paperwork marked priority."
                    ),
                    ConnectionBagGroup(
                        outboundFlightNumber: "KL678",
                        destination: "AMS",
                        connectionType: .international,
                        departureTime: now.addingTimeInterval(126 * 60),
                        departureGate: "E70",
                        bagCount: 11,
                        status: .pickedUp,
                        notes: ""
                    )
                ],
                notes: "MVP sample flight. Delete when ready."
            )
        ]
    }
}

private struct BagRunnerPayload: Codable {
    var flights: [InboundFlight]
    var settings: BagRunnerSettings
}

private extension JSONEncoder {
    static var bagRunner: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var bagRunner: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
