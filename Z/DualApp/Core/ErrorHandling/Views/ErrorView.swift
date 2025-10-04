//
//  ErrorView.swift
//  DualApp
//
//  Created by DualApp Team on 10/3/25.
//

import SwiftUI

// MARK: - Error View

struct ErrorView: View {
    let errorRecord: ErrorRecord
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @State private var showingDetails = false
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Error modal
            VStack(spacing: 0) {
                // Header
                errorHeader
                
                // Content
                errorContent
                
                // Actions
                errorActions
            }
            .background(
                LiquidGlassComponents.container(
                    variant: .modal,
                    intensity: 0.8,
                    palette: errorSeverityPalette,
                    animationType: .pulse
                ) {
                    EmptyView()
                }
            )
            .cornerRadius(16)
            .shadow(color: errorSeverityColor.opacity(0.3), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(showingDetails ? 1.0 : 0.95)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingDetails)
        }
    }
    
    // MARK: - Error Header
    
    private var errorHeader: some View {
        HStack {
            Image(systemName: errorRecord.severity.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(errorSeverityColor)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(errorSeverityTitle)
                    .textStyle(TypographyPresets.Glass.title)
                    .foregroundColor(errorSeverityColor)
                
                Text(errorRecord.category.rawValue.capitalized)
                    .textStyle(TypographyPresets.Glass.caption)
                    .foregroundColor(DesignColors.textOnGlassTertiary)
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignColors.textOnGlassSecondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Error Content
    
    private var errorContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Error message
            Text(errorRecord.localizedDescription)
                .textStyle(TypographyPresets.Glass.body)
                .foregroundColor(DesignColors.textOnGlass)
                .fixedSize(horizontal: false, vertical: true)
            
            // Recovery suggestion
            if let suggestion = errorRecord.recoverySuggestion {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested Solution")
                        .textStyle(TypographyPresets.Glass.caption)
                        .foregroundColor(DesignColors.textOnGlassTertiary)
                    
                    Text(suggestion)
                        .textStyle(TypographyPresets.Glass.body)
                        .foregroundColor(DesignColors.textOnGlassSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Error details toggle
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingDetails.toggle()
                }
            }) {
                HStack {
                    Text("Error Details")
                        .textStyle(TypographyPresets.Glass.caption)
                        .foregroundColor(DesignColors.textOnGlassSecondary)
                    
                    Spacer()
                    
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignColors.textOnGlassTertiary)
                }
            }
            
            // Error details
            if showingDetails {
                VStack(alignment: .leading, spacing: 12) {
                    errorDetailRow("Time", errorRecord.timestamp, style: .time)
                    errorDetailRow("Component", errorRecord.context?.component ?? "Unknown", style: .text)
                    errorDetailRow("Operation", errorRecord.context?.operation ?? "Unknown", style: .text)
                    
                    if let additionalInfo = errorRecord.context?.additionalInfo, !additionalInfo.isEmpty {
                        Text("Additional Information")
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlassTertiary)
                            .padding(.top, 8)
                        
                        ForEach(Array(additionalInfo.keys.sorted()), id: \.self) { key in
                            if let value = additionalInfo[key] {
                                errorDetailRow(key, value, style: .text)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Error Actions
    
    private var errorActions: some View {
        HStack(spacing: 12) {
            // Dismiss button
            LiquidGlassComponents.button(
                "Dismiss",
                variant: .standard,
                size: .medium,
                intensity: 0.6,
                palette: .monochrome,
                animationType: .none,
                hapticStyle: .light,
                action: onDismiss
            )
            
            // Retry button
            if let onRetry = onRetry {
                LiquidGlassComponents.button(
                    "Retry",
                    variant: .standard,
                    size: .medium,
                    intensity: 0.6,
                    palette: errorSeverityPalette,
                    animationType: .shimmer,
                    hapticStyle: .medium,
                    action: onRetry
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
    
    // MARK: - Helper Properties
    
    private var errorSeverityColor: Color {
        return errorRecord.severity.color
    }
    
    private var errorSeverityPalette: LiquidGlassPalette {
        switch errorRecord.severity {
        case .info:
            return .ocean
        case .warning:
            return .sunset
        case .error:
            return .galaxy
        case .critical:
            return .galaxy
        }
    }
    
    private var errorSeverityTitle: String {
        switch errorRecord.severity {
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical Error"
        }
    }
    
    // MARK: - Helper Methods
    
    private func errorDetailRow(_ title: String, _ value: Any, style: DetailStyle) -> some View {
        HStack {
            Text(title + ":")
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Group {
                switch style {
                case .time:
                    if let date = value as? Date {
                        Text(date, style: .relative)
                    } else {
                        Text(String(describing: value))
                    }
                case .text:
                    Text(String(describing: value))
                }
            }
            .textStyle(TypographyPresets.Glass.caption)
            .foregroundColor(DesignColors.textOnGlassSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    enum DetailStyle {
        case time
        case text
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let errorRecord: ErrorRecord
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @State private var isVisible = false
    @State private var offset: CGFloat = -100
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: errorRecord.severity.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(errorSeverityColor)
            
            // Message
            VStack(alignment: .leading, spacing: 2) {
                Text(errorRecord.localizedDescription)
                    .textStyle(TypographyPresets.Glass.caption)
                    .foregroundColor(DesignColors.textOnGlass)
                    .lineLimit(2)
                
                if let suggestion = errorRecord.recoverySuggestion {
                    Text(suggestion)
                        .textStyle(TypographyPresets.Glass.caption)
                        .foregroundColor(DesignColors.textOnGlassTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 8) {
                if let onRetry = onRetry {
                    Button(action: onRetry) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignColors.textOnGlassSecondary)
                    }
                }
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(DesignColors.textOnGlassSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LiquidGlassComponents.container(
                variant: .minimal,
                intensity: 0.7,
                palette: errorSeverityPalette,
                animationType: .pulse
            ) {
                EmptyView()
            }
        )
        .cornerRadius(8)
        .shadow(color: errorSeverityColor.opacity(0.2), radius: 8, x: 0, y: 4)
        .offset(y: offset)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
                offset = 0
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var errorSeverityColor: Color {
        return errorRecord.severity.color
    }
    
    private var errorSeverityPalette: LiquidGlassPalette {
        switch errorRecord.severity {
        case .info:
            return .ocean
        case .warning:
            return .sunset
        case .error:
            return .galaxy
        case .critical:
            return .galaxy
        }
    }
}

// MARK: - Error Modal View

struct ErrorModalView: View {
    let errorRecord: ErrorRecord
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @State private var showingDetails = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Header
                modalHeader
                
                // Content
                modalContent
                
                // Actions
                modalActions
            }
            .background(
                LiquidGlassComponents.container(
                    variant: .modal,
                    intensity: 0.9,
                    palette: errorSeverityPalette,
                    animationType: .shimmer
                ) {
                    EmptyView()
                }
            )
            .cornerRadius(20)
            .shadow(color: errorSeverityColor.opacity(0.4), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 20)
            .scaleEffect(showingDetails ? 1.0 : 0.98)
            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingDetails)
        }
    }
    
    // MARK: - Modal Header
    
    private var modalHeader: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: errorRecord.severity.icon)
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(errorSeverityColor)
            
            // Title
            Text(errorSeverityTitle)
                .textStyle(TypographyPresets.Glass.title)
                .foregroundColor(errorSeverityColor)
            
            // Category
            Text(errorRecord.category.rawValue.capitalized)
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Modal Content
    
    private var modalContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Error message
                Text(errorRecord.localizedDescription)
                    .textStyle(TypographyPresets.Glass.body)
                    .foregroundColor(DesignColors.textOnGlass)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Recovery suggestion
                if let suggestion = errorRecord.recoverySuggestion {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Suggested Solution")
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlassTertiary)
                        
                        Text(suggestion)
                            .textStyle(TypographyPresets.Glass.body)
                            .foregroundColor(DesignColors.textOnGlassSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                
                // Error details
                errorDetailsSection
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: 300)
    }
    
    // MARK: - Error Details Section
    
    private var errorDetailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingDetails.toggle()
                }
            }) {
                HStack {
                    Text("Error Details")
                        .textStyle(TypographyPresets.Glass.caption)
                        .foregroundColor(DesignColors.textOnGlassSecondary)
                    
                    Spacer()
                    
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignColors.textOnGlassTertiary)
                }
            }
            
            // Details content
            if showingDetails {
                VStack(alignment: .leading, spacing: 12) {
                    errorDetailRow("Time", errorRecord.timestamp, style: .time)
                    errorDetailRow("Component", errorRecord.context?.component ?? "Unknown", style: .text)
                    errorDetailRow("Operation", errorRecord.context?.operation ?? "Unknown", style: .text)
                    
                    if let additionalInfo = errorRecord.context?.additionalInfo, !additionalInfo.isEmpty {
                        Text("Additional Information")
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlassTertiary)
                            .padding(.top, 8)
                        
                        ForEach(Array(additionalInfo.keys.sorted()), id: \.self) { key in
                            if let value = additionalInfo[key] {
                                errorDetailRow(key, value, style: .text)
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Modal Actions
    
    private var modalActions: some View {
        HStack(spacing: 16) {
            // Dismiss button
            LiquidGlassComponents.button(
                "Dismiss",
                variant: .standard,
                size: .medium,
                intensity: 0.6,
                palette: .monochrome,
                animationType: .none,
                hapticStyle: .light,
                action: onDismiss
            )
            
            // Retry button
            if let onRetry = onRetry {
                LiquidGlassComponents.button(
                    "Retry",
                    variant: .standard,
                    size: .medium,
                    intensity: 0.6,
                    palette: errorSeverityPalette,
                    animationType: .shimmer,
                    hapticStyle: .medium,
                    action: onRetry
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
    
    // MARK: - Helper Properties
    
    private var errorSeverityColor: Color {
        return errorRecord.severity.color
    }
    
    private var errorSeverityPalette: LiquidGlassPalette {
        switch errorRecord.severity {
        case .info:
            return .ocean
        case .warning:
            return .sunset
        case .error:
            return .galaxy
        case .critical:
            return .galaxy
        }
    }
    
    private var errorSeverityTitle: String {
        switch errorRecord.severity {
        case .info:
            return "Information"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical Error"
        }
    }
    
    // MARK: - Helper Methods
    
    private func errorDetailRow(_ title: String, _ value: Any, style: DetailStyle) -> some View {
        HStack {
            Text(title + ":")
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
                .frame(width: 80, alignment: .leading)
            
            Spacer()
            
            Group {
                switch style {
                case .time:
                    if let date = value as? Date {
                        Text(date, style: .relative)
                    } else {
                        Text(String(describing: value))
                    }
                case .text:
                    Text(String(describing: value))
                }
            }
            .textStyle(TypographyPresets.Glass.caption)
            .foregroundColor(DesignColors.textOnGlassSecondary)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    enum DetailStyle {
        case time
        case text
    }
}

// MARK: - Error Recovery View

struct ErrorRecoveryView: View {
    let errorRecord: ErrorRecord
    let recoverySteps: [RecoveryStep]
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    
    @State private var currentStepIndex = 0
    @State private var isExecutingStep = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Header
                recoveryHeader
                
                // Content
                recoveryContent
                
                // Actions
                recoveryActions
            }
            .background(
                LiquidGlassComponents.container(
                    variant: .modal,
                    intensity: 0.9,
                    palette: .sunset,
                    animationType: .shimmer
                ) {
                    EmptyView()
                }
            )
            .cornerRadius(20)
            .shadow(color: DesignColors.warning.opacity(0.4), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Recovery Header
    
    private var recoveryHeader: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(DesignColors.warning)
            
            // Title
            Text("Error Recovery")
                .textStyle(TypographyPresets.Glass.title)
                .foregroundColor(DesignColors.warning)
            
            // Error message
            Text(errorRecord.localizedDescription)
                .textStyle(TypographyPresets.Glass.body)
                .foregroundColor(DesignColors.textOnGlassSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Recovery Content
    
    private var recoveryContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Progress indicator
            HStack {
                Text("Step \(currentStepIndex + 1) of \(recoverySteps.count)")
                    .textStyle(TypographyPresets.Glass.caption)
                    .foregroundColor(DesignColors.textOnGlassTertiary)
                
                Spacer()
                
                ProgressView(value: Double(currentStepIndex + 1), total: Double(recoverySteps.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: DesignColors.warning))
                    .frame(width: 100)
            }
            
            // Current step
            if currentStepIndex < recoverySteps.count {
                let currentStep = recoverySteps[currentStepIndex]
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentStep.title)
                        .textStyle(TypographyPresets.Glass.body)
                        .foregroundColor(DesignColors.textOnGlass)
                    
                    Text(currentStep.description)
                        .textStyle(TypographyPresets.Glass.caption)
                        .foregroundColor(DesignColors.textOnGlassSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
    
    // MARK: - Recovery Actions
    
    private var recoveryActions: some View {
        HStack(spacing: 16) {
            // Cancel button
            LiquidGlassComponents.button(
                "Cancel",
                variant: .standard,
                size: .medium,
                intensity: 0.6,
                palette: .monochrome,
                animationType: .none,
                hapticStyle: .light,
                action: onDismiss
            )
            
            // Previous button
            if currentStepIndex > 0 {
                LiquidGlassComponents.button(
                    "Previous",
                    variant: .standard,
                    size: .medium,
                    intensity: 0.6,
                    palette: .ocean,
                    animationType: .none,
                    hapticStyle: .light,
                    action: {
                        currentStepIndex -= 1
                    }
                )
            }
            
            // Next/Execute button
            if currentStepIndex < recoverySteps.count - 1 {
                LiquidGlassComponents.button(
                    "Next",
                    variant: .standard,
                    size: .medium,
                    intensity: 0.6,
                    palette: .sunset,
                    animationType: .shimmer,
                    hapticStyle: .medium,
                    action: {
                        currentStepIndex += 1
                    }
                )
            } else {
                LiquidGlassComponents.button(
                    "Execute",
                    variant: .standard,
                    size: .medium,
                    intensity: 0.6,
                    palette: .sunset,
                    animationType: .shimmer,
                    hapticStyle: .medium,
                    action: {
                        isExecutingStep = true
                        
                        // Execute the recovery step
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isExecutingStep = false
                            onDismiss()
                        }
                    }
                )
                .disabled(isExecutingStep)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
    }
}

// MARK: - Recovery Step Model

struct RecoveryStep: Sendable, Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let action: () async throws -> Bool
}

// MARK: - Error Report View

struct ErrorReportView: View {
    let errorReport: ErrorReport
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            // Modal content
            VStack(spacing: 0) {
                // Header
                reportHeader
                
                // Content
                reportContent
            }
            .background(
                LiquidGlassComponents.container(
                    variant: .modal,
                    intensity: 0.9,
                    palette: .galaxy,
                    animationType: .shimmer
                ) {
                    EmptyView()
                }
            )
            .cornerRadius(20)
            .shadow(color: DesignColors.error.opacity(0.4), radius: 30, x: 0, y: 15)
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Report Header
    
    private var reportHeader: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "doc.text")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(DesignColors.error)
            
            // Title
            Text("Error Report")
                .textStyle(TypographyPresets.Glass.title)
                .foregroundColor(DesignColors.error)
            
            // Timestamp
            Text("Generated at \(errorReport.generatedAt, style: .relative)")
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
        }
        .padding(.top, 32)
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    // MARK: - Report Content
    
    private var reportContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Summary
                reportSummarySection
                
                // Error categories
                reportCategoriesSection
                
                // Error sources
                reportSourcesSection
                
                // System health
                reportSystemHealthSection
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: 400)
    }
    
    // MARK: - Report Sections
    
    private var reportSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Summary")
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
            
            HStack(spacing: 16) {
                reportStatItem("Total", "\(errorReport.totalErrors)", DesignColors.textOnGlass)
                reportStatItem("Critical", "\(errorReport.criticalErrors)", DesignColors.error)
                reportStatItem("Errors", "\(errorReport.errorErrors)", DesignColors.warning)
                reportStatItem("Warnings", "\(errorReport.warningErrors)", DesignColors.info)
            }
        }
    }
    
    private var reportCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Categories")
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
            
            ForEach(Array(errorReport.errorCategories.keys.sorted(by: { $0.rawValue < $1.rawValue })), id: \.self) { category in
                if let count = errorReport.errorCategories[category] {
                    HStack {
                        Text(category.rawValue.capitalized)
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlassSecondary)
                        
                        Spacer()
                        
                        Text("\(count)")
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlass)
                    }
                }
            }
        }
    }
    
    private var reportSourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Sources")
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
            
            ForEach(Array(errorReport.errorSources.keys.sorted()), id: \.self) { source in
                if let count = errorReport.errorSources[source] {
                    HStack {
                        Text(source)
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlassSecondary)
                        
                        Spacer()
                        
                        Text("\(count)")
                            .textStyle(TypographyPresets.Glass.caption)
                            .foregroundColor(DesignColors.textOnGlass)
                    }
                }
            }
        }
    }
    
    private var reportSystemHealthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Health")
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
            
            HStack {
                Image(systemName: errorReport.systemHealth.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(errorReport.systemHealth.color)
                
                Text(errorReport.systemHealth.rawValue.capitalized)
                    .textStyle(TypographyPresets.Glass.caption)
                    .foregroundColor(errorReport.systemHealth.color)
                
                Spacer()
                
                Text(errorReport.systemHealth.description)
                    .textStyle(TypographyPresets.Glass.caption)
                    .foregroundColor(DesignColors.textOnGlassSecondary)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func reportStatItem(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .textStyle(TypographyPresets.Glass.body)
                .foregroundColor(color)
            
            Text(title)
                .textStyle(TypographyPresets.Glass.caption)
                .foregroundColor(DesignColors.textOnGlassTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview {
    ErrorView(
        errorRecord: ErrorRecord(
            error: NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "This is a test error message"]),
            timestamp: Date(),
            context: ErrorContext(
                component: "TestComponent",
                operation: "TestOperation",
                additionalInfo: ["TestKey": "TestValue"]
            ),
            isCritical: false,
            recoveryAttempts: 0
        ),
        onDismiss: {},
        onRetry: {}
    )
    .preferredColorScheme(.dark)
}