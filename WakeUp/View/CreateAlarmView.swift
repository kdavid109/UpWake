//
//  CreateAlarmView.swift
//  WakeUp
//
//  Created by David Kim on 1/3/25.
//

import SwiftUI
import Foundation
import FirebaseAuth


@available(iOS 14.0, *)
struct CreateAlarmView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var alarmManager = AlarmManager.shared
    @State private var selectedHour: Double = 0
    @State private var selectedMinute: Double = 0
    @State private var alarmLabel: String = ""
    @State private var selectedDays: Set<Weekday> = []
    @State private var isDraggingHour = false
    @State private var isDraggingMinute = false
    @State private var isPM = false
    @Environment(\.colorScheme) var colorScheme
    @State private var selectedImages: [UIImage] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let clockSize: CGFloat = 280
    private let hourHandLength: CGFloat = 80
    private let minuteHandLength: CGFloat = 110
    
    // Add computed properties for stepper values
    private var hourValue: Int {
        get { Int(selectedHour / 30) % 12 == 0 ? 12 : Int(selectedHour / 30) % 12 }
        set { selectedHour = Double(newValue == 12 ? 0 : newValue) * 30 }
    }
    
    private var minuteValue: Int {
        get { Int(selectedMinute / 6) }
        set { selectedMinute = Double(newValue) * 6 }
    }
    
    private var formattedTime: String {
        let hour = hourValue
        let minute = minuteValue
        return String(format: "%d:%02d", hour, minute)
    }
    
    private var backgroundColor: Color {
        isPM ? Color.black.opacity(0.9) : .white
    }
    
    private var textColor: Color {
        .black
    }
    
    var body: some View {
        VStack {
            // AM/PM Toggle
            HStack {
                Spacer()
                Toggle(isOn: $isPM) {
                    HStack {
                        Text(isPM ? "PM" : "AM")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(isPM ? .white : .black)
                        Image(systemName: isPM ? "moon.fill" : "sun.max.fill")
                            .foregroundColor(isPM ? .white : .orange)
                    }
                }
                .toggleStyle(CustomToggleStyle())
                .padding(.horizontal)
                .onChange(of: isPM) { oldValue, newValue in
                    // Toggle all days when AM/PM is switched
                    if newValue {
                        // If switching to PM, select all days
                        selectedDays = Set(Weekday.allCases)
                    } else {
                        // If switching to AM, deselect all days
                        selectedDays.removeAll()
                    }
                }
            }
            .padding(.top)

            // Clock Face
            ZStack {
                // Clock Circle
                Circle()
                    .fill(backgroundColor)
                    .shadow(color: .gray.opacity(0.2), radius: 10)
                    .frame(width: clockSize, height: clockSize)
                
                // Hour Markers
                ForEach(0..<12) { hour in
                    Rectangle()
                        .fill(Color.teal)
                        .frame(width: 2, height: 15)
                        .offset(y: -clockSize/2 + 15)
                        .rotationEffect(.degrees(Double(hour) * 30))
                }
                
                // Minute Markers
                ForEach(0..<60) { minute in
                    if minute % 5 != 0 {
                        Rectangle()
                            .fill(isPM ? Color.gray.opacity(0.5) : Color.gray.opacity(0.3))
                            .frame(width: 1, height: 8)
                            .offset(y: -clockSize/2 + 8)
                            .rotationEffect(.degrees(Double(minute) * 6))
                    }
                }
                
                // Hour Hand
                Rectangle()
                    .fill(Color.teal)
                    .frame(width: 4, height: hourHandLength)
                    .offset(y: -hourHandLength/2)
                    .rotationEffect(.degrees(selectedHour))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingHour = true
                                let vector = CGVector(dx: value.location.x - clockSize/2,
                                                    dy: value.location.y - clockSize/2)
                                let angle = atan2(vector.dy, vector.dx) * 180 / .pi + 90
                                selectedHour = (angle + 360).truncatingRemainder(dividingBy: 360)
                            }
                            .onEnded { _ in isDraggingHour = false }
                    )
                
                // Minute Hand
                Rectangle()
                    .fill(Color.teal.opacity(0.8))
                    .frame(width: 3, height: minuteHandLength)
                    .offset(y: -minuteHandLength/2)
                    .rotationEffect(.degrees(selectedMinute))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingMinute = true
                                let vector = CGVector(dx: value.location.x - clockSize/2,
                                                    dy: value.location.y - clockSize/2)
                                let angle = atan2(vector.dy, vector.dx) * 180 / .pi + 90
                                selectedMinute = (angle + 360).truncatingRemainder(dividingBy: 360)
                            }
                            .onEnded { _ in isDraggingMinute = false }
                    )
                
                // Center Circle
                Circle()
                    .fill(Color.teal)
                    .frame(width: 15, height: 15)
            }
            .padding(.top, 20)
            
            // Time Display with Plus/Minus Buttons
            VStack(spacing: 10) {
                Text(formattedTime)
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(.teal)
                    .padding(.top, 30)
                
                // Custom Time Controls
                HStack(spacing: 40) {
                    // Hour Controls
                    HStack(spacing: 15) {
                        Button(action: {
                            let newValue = hourValue == 1 ? 12 : hourValue - 1
                            selectedHour = Double(newValue == 12 ? 0 : newValue) * 30
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.teal)
                        }
                        
                        Button(action: {
                            let newValue = hourValue == 12 ? 1 : hourValue + 1
                            selectedHour = Double(newValue == 12 ? 0 : newValue) * 30
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.teal)
                        }
                    }
                    
                    // Minute Controls
                    HStack(spacing: 15) {
                        Button(action: {
                            selectedMinute = Double(minuteValue == 0 ? 59 : minuteValue - 1) * 6
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.teal)
                        }
                        
                        Button(action: {
                            selectedMinute = Double(minuteValue == 59 ? 0 : minuteValue + 1) * 6
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.teal)
                        }
                    }
                }
            }
            
            // Alarm Label Input
            TextField("Alarm Label", text: $alarmLabel)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .foregroundColor(textColor)
            
            // Day Selection
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Weekday.allCases, id: \.rawValue) { day in
                        DayToggleButton(day: day, isSelected: selectedDays.contains(day)) {
                            if selectedDays.contains(day) {
                                selectedDays.remove(day)
                            } else {
                                selectedDays.insert(day)
                            }
                        }
                    }
                }
                .padding(.horizontal, 40)
            }
            .padding(.top, 10)
            
            // Create Button
            Button(action: {
                saveAlarm()
                dismiss()
            }) {
                Text("Create Alarm")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.teal)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 30)
            
            Spacer()
        }
        .navigationTitle("New Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .background(backgroundColor)
        .animation(.easeInOut(duration: 0.3), value: isPM)
        .onChange(of: hourValue) { oldValue, newValue in
            updateClockHands()
        }
        .onChange(of: minuteValue) { oldValue, newValue in
            updateClockHands()
        }
    }
    
    // Add this helper function to update clock hands
    private func updateClockHands() {
        if !isDraggingHour {
            let newHourValue = hourValue == 12 ? 0 : hourValue
            selectedHour = Double(newHourValue) * 30
        }
        if !isDraggingMinute {
            selectedMinute = Double(minuteValue) * 6
        }
    }
    
    private func saveAlarm() {
        let newAlarm = Alarm(
            time: formattedTime,
            label: alarmLabel,
            selectedDays: selectedDays,
            isEnabled: true
        )
        
        Task {
            do {
                try await alarmManager.addAlarm(newAlarm, images: selectedImages)
                // Handle successful save (e.g., dismiss view)
            } catch {
                DispatchQueue.main.async {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct CustomToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                configuration.label
                    .padding(.trailing, 5)
                
                RoundedRectangle(cornerRadius: 30)
                    .fill(configuration.isOn ? Color.indigo : Color.orange.opacity(0.7))
                    .frame(width: 50, height: 30)
                    .overlay(
                        Circle()
                            .fill(.white)
                            .padding(3)
                            .offset(x: configuration.isOn ? 10 : -10)
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct DayToggleButton: View {
    let day: Weekday
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(day.shortName)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.teal : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
    }
}

#Preview {
    if #available(iOS 14.0, *) {
        NavigationView {
            CreateAlarmView()
                .environmentObject(AlarmManager.shared)
        }
    } else {
        // Fallback for earlier versions
        Text("Requires iOS 14.0 or later")
    }
}
