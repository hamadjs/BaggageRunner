//
//  BagRunnerModels.swift
//  Baggage Runner
//
//  Created by Codex on 2026-05-25.
//

import SwiftUI

struct InboundFlight: Codable, Identifiable, Equatable {
    var id = UUID()
    var flightNumber: String
    var origin: String
    var arrivalGate: String
    var parkingBrakesSetTime: Date
    var totalBags: Int
    var localBagCount: Int
    var connections: [ConnectionBagGroup]
    var notes: String

    var connectingBagCount: Int {
        connections.reduce(0) { $0 + $1.bagCount }
    }

    func bagAvailableTime(settings: BagRunnerSettings) -> Date {
        parkingBrakesSetTime.addingTimeInterval(TimeInterval(settings.offloadMinutes * 60))
    }

    func localDueTime(settings: BagRunnerSettings) -> Date {
        parkingBrakesSetTime.addingTimeInterval(TimeInterval(settings.localDeliveryTargetMinutes * 60))
    }

    func connections(
        for urgency: ConnectionUrgency,
        settings: BagRunnerSettings,
        now: Date
    ) -> [ClassifiedConnection] {
        classifiedConnections(settings: settings, now: now)
            .filter { $0.urgency == urgency }
    }

    func classifiedConnections(settings: BagRunnerSettings, now: Date) -> [ClassifiedConnection] {
        let availableTime = bagAvailableTime(settings: settings)

        return connections
            .map { group in
                ClassifiedConnection(
                    group: group,
                    urgency: group.urgency(from: availableTime, settings: settings)
                )
            }
            .sorted { first, second in
                if first.urgency.sortOrder == second.urgency.sortOrder {
                    return first.group.departureTime < second.group.departureTime
                }

                return first.urgency.sortOrder < second.urgency.sortOrder
            }
    }

    func hotConnectionCount(settings: BagRunnerSettings) -> Int {
        let availableTime = bagAvailableTime(settings: settings)

        return connections
            .filter { $0.urgency(from: availableTime, settings: settings) == .hot }
            .reduce(0) { $0 + $1.bagCount }
    }

    func mostUrgentConnection(settings: BagRunnerSettings, now: Date) -> ClassifiedConnection? {
        classifiedConnections(settings: settings, now: now).first
    }
}

struct ConnectionBagGroup: Codable, Identifiable, Equatable {
    var id = UUID()
    var outboundFlightNumber: String
    var destination: String
    var connectionType: ConnectionType
    var departureTime: Date
    var departureGate: String
    var bagCount: Int
    var status: BagStatus
    var notes: String

    func operationalWindowMinutes(from bagAvailableTime: Date) -> Int {
        Int(departureTime.timeIntervalSince(bagAvailableTime) / 60)
    }

    func urgency(from bagAvailableTime: Date, settings: BagRunnerSettings) -> ConnectionUrgency {
        let window = operationalWindowMinutes(from: bagAvailableTime)

        if window <= connectionType.hotThreshold(settings: settings) {
            return .hot
        }

        if window <= connectionType.warmThreshold(settings: settings) {
            return .warm
        }

        return .cold
    }
}

struct ClassifiedConnection: Identifiable {
    var id: UUID { group.id }
    let group: ConnectionBagGroup
    let urgency: ConnectionUrgency
}

struct BagRunnerSettings: Codable, Equatable {
    var offloadMinutes = 15
    var domesticHotMinutes = 60
    var internationalHotMinutes = 70
    var domesticWarmMinutes = 120
    var internationalWarmMinutes = 130
    var localDeliveryTargetMinutes = 20
}

enum ConnectionType: String, Codable, CaseIterable, Identifiable {
    case domestic
    case international

    var id: String { rawValue }

    var title: String {
        switch self {
        case .domestic: "Domestic"
        case .international: "International"
        }
    }

    func hotThreshold(settings: BagRunnerSettings) -> Int {
        switch self {
        case .domestic: settings.domesticHotMinutes
        case .international: settings.internationalHotMinutes
        }
    }

    func warmThreshold(settings: BagRunnerSettings) -> Int {
        switch self {
        case .domestic: settings.domesticWarmMinutes
        case .international: settings.internationalWarmMinutes
        }
    }
}

enum ConnectionUrgency: String, CaseIterable, Identifiable {
    case hot
    case warm
    case cold

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hot: "Hot"
        case .warm: "Warm"
        case .cold: "Cold"
        }
    }

    var sortOrder: Int {
        switch self {
        case .hot: 0
        case .warm: 1
        case .cold: 2
        }
    }

    var tint: Color {
        switch self {
        case .hot: .red
        case .warm: .orange
        case .cold: .blue
        }
    }

    var foreground: Color {
        switch self {
        case .hot: .red
        case .warm: .orange
        case .cold: .blue
        }
    }
}

enum BagStatus: String, Codable, CaseIterable, Identifiable {
    case pending
    case pickedUp
    case delivered
    case issue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: "Pending"
        case .pickedUp: "Picked up"
        case .delivered: "Delivered"
        case .issue: "Issue"
        }
    }

    var systemImage: String {
        switch self {
        case .pending: "clock"
        case .pickedUp: "figure.walk.motion"
        case .delivered: "checkmark.circle"
        case .issue: "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .pending: .secondary
        case .pickedUp: .blue
        case .delivered: .green
        case .issue: .red
        }
    }
}

extension Date {
    func relativeCountdown(from now: Date) -> String {
        let seconds = Int(timeIntervalSince(now))
        let absoluteMinutes = abs(seconds) / 60
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        let text: String

        if hours > 0 {
            text = "\(hours)h \(minutes)m"
        } else {
            text = "\(minutes)m"
        }

        return seconds >= 0 ? text : "\(text) late"
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

