//
//  ContributionGraphView.swift
//  GitMac
//
//  GitHub-style contribution heatmap showing commits over time
//

import SwiftUI

struct ContributionGraphView: View {
    let contributionDays: [ContributionDay]
    let weeks: Int
    
    init(contributionDays: [ContributionDay], weeks: Int = 52) {
        self.contributionDays = contributionDays
        self.weeks = weeks
    }
    
    private let cellSize: CGFloat = 10
    private let cellSpacing: CGFloat = 2
    private let daysInWeek = 7
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            // Month labels
            monthLabels
            
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day labels
                dayLabels
                
                // Grid
                contributionGrid
            }
            
            // Legend
            legendView
        }
    }
    
    // MARK: - Components
    
    private var monthLabels: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: 24) // Offset for day labels
            
            ForEach(uniqueMonths, id: \.self) { month in
                Text(monthName(month))
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: calculateMonthWidth(month), alignment: .leading)
            }
        }
    }
    
    private var dayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<daysInWeek, id: \.self) { day in
                if day % 2 == 1 {
                    Text(dayName(day))
                        .font(.system(size: 9))
                        .foregroundColor(AppTheme.textMuted)
                        .frame(width: 20, height: cellSize, alignment: .trailing)
                } else {
                    Spacer()
                        .frame(width: 20, height: cellSize)
                }
            }
        }
    }
    
    private var contributionGrid: some View {
        HStack(alignment: .top, spacing: cellSpacing) {
            ForEach(weeklyData.indices, id: \.self) { weekIndex in
                VStack(spacing: cellSpacing) {
                    ForEach(weeklyData[weekIndex].indices, id: \.self) { dayIndex in
                        let day = weeklyData[weekIndex][dayIndex]
                        ContributionCell(
                            intensity: day?.intensity ?? 0,
                            commitCount: day?.commitCount ?? 0,
                            date: day?.date
                        )
                        .frame(width: cellSize, height: cellSize)
                    }
                }
            }
        }
    }
    
    private var legendView: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Spacer()
            
            Text("Less")
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
            
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                RoundedRectangle(cornerRadius: 2)
                    .fill(contributionColor(for: intensity))
                    .frame(width: cellSize, height: cellSize)
            }
            
            Text("More")
                .font(.system(size: 9))
                .foregroundColor(AppTheme.textMuted)
        }
    }
    
    // MARK: - Data Processing
    
    private var weeklyData: [[(ContributionDay)?]] {
        guard !contributionDays.isEmpty else { return [] }
        
        let calendar = Calendar.current
        var weeks: [[(ContributionDay)?]] = []
        var currentWeek: [(ContributionDay)?] = []
        
        // Start from the first day's weekday
        if let firstDay = contributionDays.first {
            let weekday = calendar.component(.weekday, from: firstDay.date)
            // Sunday = 1, so we need (weekday - 1) empty slots
            for _ in 0..<(weekday - 1) {
                currentWeek.append(nil)
            }
        }
        
        for day in contributionDays {
            currentWeek.append(day)
            
            if currentWeek.count == daysInWeek {
                weeks.append(currentWeek)
                currentWeek = []
            }
        }
        
        // Add remaining days
        if !currentWeek.isEmpty {
            while currentWeek.count < daysInWeek {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        
        // Limit to specified number of weeks
        let limitedWeeks = Array(weeks.suffix(self.weeks))
        return limitedWeeks
    }
    
    private var uniqueMonths: [Date] {
        let calendar = Calendar.current
        var months: [Date] = []
        var lastMonth = -1
        
        for week in weeklyData {
            if let firstDay = week.compactMap({ $0 }).first {
                let month = calendar.component(.month, from: firstDay.date)
                if month != lastMonth {
                    months.append(firstDay.date)
                    lastMonth = month
                }
            }
        }
        
        return months
    }
    
    // MARK: - Helpers
    
    private func monthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }
    
    private func dayName(_ day: Int) -> String {
        let names = ["S", "M", "T", "W", "T", "F", "S"]
        return names[day]
    }
    
    private func calculateMonthWidth(_ date: Date) -> CGFloat {
        // Approximate width based on weeks in month
        return (cellSize + cellSpacing) * 4
    }
    
    private func contributionColor(for intensity: Double) -> Color {
        if intensity == 0 {
            return AppTheme.backgroundTertiary
        }
        return AppTheme.success.opacity(0.2 + intensity * 0.8)
    }
}

// MARK: - Contribution Cell

struct ContributionCell: View {
    let intensity: Double
    let commitCount: Int
    let date: Date?
    
    @State private var isHovered = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(isHovered ? AppTheme.accent : Color.clear, lineWidth: 1)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            .help(tooltipText)
    }
    
    private var cellColor: Color {
        if intensity == 0 {
            return AppTheme.backgroundTertiary
        }
        return AppTheme.success.opacity(0.2 + intensity * 0.8)
    }
    
    private var tooltipText: String {
        guard let date = date else { return "No data" }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        if commitCount == 0 {
            return "No commits on \(formatter.string(from: date))"
        } else if commitCount == 1 {
            return "1 commit on \(formatter.string(from: date))"
        } else {
            return "\(commitCount) commits on \(formatter.string(from: date))"
        }
    }
}

// MARK: - Preview

#Preview("Contribution Graph") {
    let calendar = Calendar.current
    let today = Date()
    
    // Generate sample data
    let days = (0..<365).map { offset -> ContributionDay in
        let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
        let count = Int.random(in: 0...8)
        return ContributionDay(date: date, commitCount: count)
    }.reversed()
    
    return ContributionGraphView(contributionDays: Array(days))
        .padding()
        .background(AppTheme.background)
        .frame(width: 800)
}
