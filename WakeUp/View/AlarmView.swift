//
//  AlarmView.swift
//  WakeUp
//
//  Created by David Kim on 1/3/25.
//

import SwiftUI
import Foundation



@available(iOS 14.0, *)
struct AlarmView: View {
    @StateObject private var alarmManager = AlarmManager.shared
    @State private var showingEditSheet = false
    @State private var selectedAlarm: Alarm?
    
    var body: some View {
        NavigationView {
            VStack {
                // Main Content Area
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(alarmManager.alarms) { alarm in
                            AlarmCard(
                                alarm: alarm,
                                onEdit: {
                                    selectedAlarm = alarm
                                    showingEditSheet = true
                                },
                                onToggle: { isEnabled in
                                    Task {
                                        do {
                                            try await alarmManager.toggleAlarm(alarm, isEnabled: isEnabled)
                                        } catch {
                                            print("Error toggling alarm: \(error)")
                                        }
                                    }
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        do {
                                            try await alarmManager.removeAlarm(alarm)
                                        } catch {
                                            print("Error removing alarm: \(error)")
                                        }
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        
                        if alarmManager.alarms.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "alarm")
                                    .font(.system(size: 50))
                                    .foregroundColor(.teal)
                                Text("No Alarms Set")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 100)
                        }
                    }
                    .padding()
                }
                
                // Custom Tab Bar
                HStack(spacing: 40) {
                    // Create New Alarm Button
                    NavigationLink(destination: CreateAlarmView()) {
                        VStack {
                            Image(systemName: "alarm.fill")
                                .font(.system(size: 24))
                            Text("Create New Alarm")
                                .font(.caption)
                        }
                        .foregroundColor(.teal)
                    }
                    
                    // Objects Button
                    NavigationLink(destination: ObjectsView()) {
                        VStack {
                            Image(systemName: "building.2.fill")
                                .font(.system(size: 24))
                            Text("Objects")
                                .font(.caption)
                        }
                        .foregroundColor(.teal)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    Rectangle()
                        .fill(Color(.systemBackground))
                        .shadow(color: .gray.opacity(0.2), radius: 10, y: -5)
                )
            }
            .navigationTitle("Alarms")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingEditSheet) {
                if let alarm = selectedAlarm {
                    NavigationView {
                        CreateAlarmView()
                            .environmentObject(alarmManager)
                            .onAppear {
                                // Set the initial values for editing
                                // This will be handled in CreateAlarmView
                            }
                    }
                }
            }
        }
    }
}

// Alarm Card View
struct AlarmCard: View {
    let alarm: Alarm
    let onEdit: () -> Void
    let onToggle: (Bool) -> Void
    @State private var isEnabled: Bool
    
    init(alarm: Alarm, onEdit: @escaping () -> Void, onToggle: @escaping (Bool) -> Void) {
        self.alarm = alarm
        self.onEdit = onEdit
        self.onToggle = onToggle
        _isEnabled = State(initialValue: alarm.isEnabled)
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(alarm.time)
                    .font(.system(size: 32, weight: .bold))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(alarm.label)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    // Display selected days
                    if !alarm.selectedDays.isEmpty {
                        Text(formatSelectedDays())
                            .font(.caption)
                            .foregroundColor(.teal)
                    }
                }
            }
            
            Spacer()
            
            HStack {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundColor(.teal)
                }
                .padding(.trailing, 8)
                
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: { newValue in
                        isEnabled = newValue
                        onToggle(newValue)
                    }
                ))
                .tint(.teal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color(.systemBackground))
                .shadow(color: .gray.opacity(0.2), radius: 5)
        )
    }
    
    private func formatSelectedDays() -> String {
        let sortedDays = alarm.selectedDays.sorted { $0.rawValue < $1.rawValue }
        return sortedDays.map { $0.shortName }.joined(separator: " · ")
    }
}

#Preview {
    AlarmView()
        .environmentObject(AlarmManager.shared)
}
