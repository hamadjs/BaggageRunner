//
//  ContentView.swift
//  Baggage Runner
//
//  Created by Hamad Siddiqui on 2026-05-20.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = BagRunnerStore()

    var body: some View {
        TabView {
            FlightBoardView()
                .tabItem {
                    Label("Flights", systemImage: "airplane.arrival")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
        }
        .environmentObject(store)
    }
}

struct FlightBoardView: View {
    @EnvironmentObject private var store: BagRunnerStore
    @State private var showingAddFlight = false

    var body: some View {
        NavigationStack {
            List {
                if store.flights.isEmpty {
                    ContentUnavailableView(
                        "No inbound flights",
                        systemImage: "suitcase.rolling",
                        description: Text("Add an inbound flight to start tracking local and connecting bags.")
                    )
                } else {
                    ForEach(store.sortedFlights) { flight in
                        NavigationLink(value: flight.id) {
                            FlightSummaryRow(flight: flight)
                        }
                    }
                    .onDelete(perform: store.deleteFlights)
                }
            }
            .navigationTitle("BagRunner")
            .navigationDestination(for: UUID.self) { flightID in
                if let flight = store.flight(with: flightID) {
                    FlightDetailView(flight: flight)
                } else {
                    ContentUnavailableView("Flight not found", systemImage: "exclamationmark.triangle")
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddFlight = true
                    } label: {
                        Label("Add Flight", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFlight) {
                NavigationStack {
                    FlightEditorView(mode: .add)
                }
            }
        }
    }
}

struct FlightSummaryRow: View {
    @EnvironmentObject private var store: BagRunnerStore
    let flight: InboundFlight

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flight.flightNumber)
                            .font(.headline)
                        Text("\(flight.origin) to Gate \(flight.arrivalGate)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    LocalStatusBadge(flight: flight, now: context.date)
                }

                HStack(spacing: 16) {
                    Metric(label: "Total", value: "\(flight.totalBags)")
                    Metric(label: "Local", value: "\(flight.localBagCount)")
                    Metric(label: "Connect", value: "\(flight.connectingBagCount)")
                    Metric(label: "Hot", value: "\(flight.hotConnectionCount(settings: store.settings))")
                }

                if let next = flight.mostUrgentConnection(settings: store.settings, now: context.date) {
                    HStack(spacing: 8) {
                        UrgencyBadge(urgency: next.urgency)
                        Text("\(next.group.outboundFlightNumber) \(next.group.destination)")
                            .font(.caption.weight(.semibold))
                        Text(next.group.departureTime.relativeCountdown(from: context.date))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}

struct FlightDetailView: View {
    @EnvironmentObject private var store: BagRunnerStore
    let flight: InboundFlight
    @State private var showingAddConnection = false
    @State private var showingEditFlight = false

    var body: some View {
        List {
            TimelineView(.periodic(from: .now, by: 15)) { context in
                Section {
                    FlightOperationsCard(flight: flight, now: context.date)
                }

                Section("Local bags") {
                    LocalBagRow(flight: flight, now: context.date)
                }

                ForEach(ConnectionUrgency.allCases) { urgency in
                    let connections = flight.connections(
                        for: urgency,
                        settings: store.settings,
                        now: context.date
                    )

                    if !connections.isEmpty {
                        Section(urgency.title) {
                            ForEach(connections) { item in
                                ConnectionRow(flightID: flight.id, connection: item.group, urgency: item.urgency, now: context.date)
                            }
                        }
                    }
                }

                if flight.connections.isEmpty {
                    Section("Connections") {
                        ContentUnavailableView(
                            "No connecting bags",
                            systemImage: "arrow.triangle.branch",
                            description: Text("Add connecting bag groups from the paperwork.")
                        )
                    }
                }
            }
        }
        .navigationTitle(flight.flightNumber)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingEditFlight = true
                } label: {
                    Label("Edit Flight", systemImage: "pencil")
                }

                Button {
                    showingAddConnection = true
                } label: {
                    Label("Add Connection", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddConnection) {
            NavigationStack {
                ConnectionEditorView(flightID: flight.id, mode: .add)
            }
        }
        .sheet(isPresented: $showingEditFlight) {
            NavigationStack {
                FlightEditorView(mode: .edit(flight))
            }
        }
    }
}

struct FlightOperationsCard: View {
    @EnvironmentObject private var store: BagRunnerStore
    let flight: InboundFlight
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Bag available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(flight.bagAvailableTime(settings: store.settings), style: .time)
                        .font(.title3.weight(.semibold))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Brake set")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(flight.parkingBrakesSetTime, style: .time)
                        .font(.title3.weight(.semibold))
                }
            }

            HStack(spacing: 12) {
                Metric(label: "Offload", value: "\(store.settings.offloadMinutes)m")
                Metric(label: "Total", value: "\(flight.totalBags)")
                Metric(label: "Local", value: "\(flight.localBagCount)")
                Metric(label: "Connect", value: "\(flight.connectingBagCount)")
            }

            if !flight.notes.isEmpty {
                Text(flight.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

struct LocalBagRow: View {
    @EnvironmentObject private var store: BagRunnerStore
    let flight: InboundFlight
    let now: Date

    var body: some View {
        let dueTime = flight.localDueTime(settings: store.settings)
        let isLate = now > dueTime

        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isLate ? "clock.badge.exclamationmark" : "suitcase")
                .font(.title2)
                .foregroundStyle(isLate ? .red : .green)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 6) {
                Text("\(flight.localBagCount) local bags")
                    .font(.headline)
                Text("Due by \(dueTime.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(dueTime.relativeCountdown(from: now))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isLate ? .red : .primary)
        }
        .padding(.vertical, 4)
    }
}

struct ConnectionRow: View {
    @EnvironmentObject private var store: BagRunnerStore
    let flightID: UUID
    let connection: ConnectionBagGroup
    let urgency: ConnectionUrgency
    let now: Date
    @State private var showingEditConnection = false

    var body: some View {
        Button {
            showingEditConnection = true
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(connection.outboundFlightNumber) to \(connection.destination)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("\(connection.connectionType.title) • Gate \(connection.departureGate)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    UrgencyBadge(urgency: urgency)
                }

                HStack(spacing: 12) {
                    Metric(label: "Bags", value: "\(connection.bagCount)")
                    Metric(label: "Departs", value: connection.departureTime.formatted(date: .omitted, time: .shortened))
                    Metric(label: "Countdown", value: connection.departureTime.relativeCountdown(from: now))
                }

                HStack {
                    Label(connection.status.title, systemImage: connection.status.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(connection.status.tint)

                    Spacer()

                    Text("Window \(connection.operationalWindowMinutes(from: store.flight(with: flightID)?.bagAvailableTime(settings: store.settings) ?? now))m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !connection.notes.isEmpty {
                    Text(connection.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                store.deleteConnection(connection.id, from: flightID)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditConnection) {
            NavigationStack {
                ConnectionEditorView(flightID: flightID, mode: .edit(connection))
            }
        }
    }
}

struct FlightEditorView: View {
    enum Mode {
        case add
        case edit(InboundFlight)

        var title: String {
            switch self {
            case .add: "Add Flight"
            case .edit: "Edit Flight"
            }
        }
    }

    @EnvironmentObject private var store: BagRunnerStore
    @Environment(\.dismiss) private var dismiss
    let mode: Mode

    @State private var flightNumber = ""
    @State private var origin = ""
    @State private var arrivalGate = ""
    @State private var parkingBrakesSetTime = Date()
    @State private var totalBags = 0
    @State private var localBagCount = 0
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Inbound") {
                TextField("Inbound flight number", text: $flightNumber)
                    .textInputAutocapitalization(.characters)
                TextField("Origin", text: $origin)
                    .textInputAutocapitalization(.characters)
                TextField("Arrival gate", text: $arrivalGate)
                    .textInputAutocapitalization(.characters)
                DatePicker("Parking brakes set", selection: $parkingBrakesSetTime)
            }

            Section("Bags") {
                Stepper("Total bags: \(totalBags)", value: $totalBags, in: 0...999)
                Stepper("Local bags: \(localBagCount)", value: $localBagCount, in: 0...totalBags)
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(flightNumber.trimmed.isEmpty || origin.trimmed.isEmpty || arrivalGate.trimmed.isEmpty)
            }
        }
        .onAppear(perform: loadValues)
    }

    private func loadValues() {
        guard case let .edit(flight) = mode else { return }
        flightNumber = flight.flightNumber
        origin = flight.origin
        arrivalGate = flight.arrivalGate
        parkingBrakesSetTime = flight.parkingBrakesSetTime
        totalBags = flight.totalBags
        localBagCount = min(flight.localBagCount, flight.totalBags)
        notes = flight.notes
    }

    private func save() {
        let flight = InboundFlight(
            id: existingID,
            flightNumber: flightNumber.trimmed.uppercased(),
            origin: origin.trimmed.uppercased(),
            arrivalGate: arrivalGate.trimmed.uppercased(),
            parkingBrakesSetTime: parkingBrakesSetTime,
            totalBags: totalBags,
            localBagCount: min(localBagCount, totalBags),
            connections: existingConnections,
            notes: notes.trimmed
        )
        store.upsertFlight(flight)
    }

    private var existingID: UUID {
        if case let .edit(flight) = mode {
            flight.id
        } else {
            UUID()
        }
    }

    private var existingConnections: [ConnectionBagGroup] {
        if case let .edit(flight) = mode {
            flight.connections
        } else {
            []
        }
    }
}

struct ConnectionEditorView: View {
    enum Mode {
        case add
        case edit(ConnectionBagGroup)

        var title: String {
            switch self {
            case .add: "Add Connection"
            case .edit: "Edit Connection"
            }
        }
    }

    @EnvironmentObject private var store: BagRunnerStore
    @Environment(\.dismiss) private var dismiss
    let flightID: UUID
    let mode: Mode

    @State private var outboundFlightNumber = ""
    @State private var destination = ""
    @State private var connectionType: ConnectionType = .domestic
    @State private var departureTime = Date().addingTimeInterval(90 * 60)
    @State private var departureGate = ""
    @State private var bagCount = 1
    @State private var status: BagStatus = .pending
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Outbound") {
                TextField("Outbound flight number", text: $outboundFlightNumber)
                    .textInputAutocapitalization(.characters)
                TextField("Destination", text: $destination)
                    .textInputAutocapitalization(.characters)
                Picker("Type", selection: $connectionType) {
                    ForEach(ConnectionType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                DatePicker("Departure", selection: $departureTime)
                TextField("Departure gate", text: $departureGate)
                    .textInputAutocapitalization(.characters)
            }

            Section("Bags") {
                Stepper("Bag count: \(bagCount)", value: $bagCount, in: 1...999)
                Picker("Status", selection: $status) {
                    ForEach(BagStatus.allCases) { status in
                        Label(status.title, systemImage: status.systemImage).tag(status)
                    }
                }
            }

            Section("Notes") {
                TextField("Optional notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle(mode.title)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    save()
                    dismiss()
                }
                .disabled(outboundFlightNumber.trimmed.isEmpty || destination.trimmed.isEmpty || departureGate.trimmed.isEmpty)
            }
        }
        .onAppear(perform: loadValues)
    }

    private func loadValues() {
        guard case let .edit(connection) = mode else { return }
        outboundFlightNumber = connection.outboundFlightNumber
        destination = connection.destination
        connectionType = connection.connectionType
        departureTime = connection.departureTime
        departureGate = connection.departureGate
        bagCount = connection.bagCount
        status = connection.status
        notes = connection.notes
    }

    private func save() {
        let connection = ConnectionBagGroup(
            id: existingID,
            outboundFlightNumber: outboundFlightNumber.trimmed.uppercased(),
            destination: destination.trimmed.uppercased(),
            connectionType: connectionType,
            departureTime: departureTime,
            departureGate: departureGate.trimmed.uppercased(),
            bagCount: bagCount,
            status: status,
            notes: notes.trimmed
        )
        store.upsertConnection(connection, in: flightID)
    }

    private var existingID: UUID {
        if case let .edit(connection) = mode {
            connection.id
        } else {
            UUID()
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: BagRunnerStore

    var body: some View {
        NavigationStack {
            Form {
                Section("Turnaround timing") {
                    SettingsStepper(label: "Offload time", value: $store.settings.offloadMinutes, range: 0...90)
                    SettingsStepper(label: "Local delivery target", value: $store.settings.localDeliveryTargetMinutes, range: 1...90)
                }

                Section("Hot thresholds") {
                    SettingsStepper(label: "Domestic hot", value: $store.settings.domesticHotMinutes, range: 1...240)
                    SettingsStepper(label: "International hot", value: $store.settings.internationalHotMinutes, range: 1...240)
                }

                Section("Warm thresholds") {
                    SettingsStepper(label: "Domestic warm", value: $store.settings.domesticWarmMinutes, range: 1...360)
                    SettingsStepper(label: "International warm", value: $store.settings.internationalWarmMinutes, range: 1...360)
                }

                Section {
                    Button("Restore defaults") {
                        store.settings = BagRunnerSettings()
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: store.settings) { _, _ in
                store.save()
            }
        }
    }
}

struct SettingsStepper: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        Stepper(value: $value, in: range) {
            HStack {
                Text(label)
                Spacer()
                Text("\(value) min")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 52, alignment: .leading)
    }
}

struct UrgencyBadge: View {
    let urgency: ConnectionUrgency

    var body: some View {
        Text(urgency.title.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(urgency.foreground)
            .background(urgency.tint.opacity(0.16), in: Capsule())
    }
}

struct LocalStatusBadge: View {
    @EnvironmentObject private var store: BagRunnerStore
    let flight: InboundFlight
    let now: Date

    var body: some View {
        let dueTime = flight.localDueTime(settings: store.settings)
        let remaining = dueTime.timeIntervalSince(now)
        let isLate = remaining < 0

        Text(isLate ? "LOCAL LATE" : "LOCAL OK")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(isLate ? .red : .green)
            .background((isLate ? Color.red : Color.green).opacity(0.14), in: Capsule())
    }
}

#Preview {
    ContentView()
}

