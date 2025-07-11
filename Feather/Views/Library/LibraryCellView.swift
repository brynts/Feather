//
//  LibraryAppIconView.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
struct LibraryCellView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var certInfo: Date.ExpirationInfo? {
        Storage.shared.getCertificate(from: app)?.expiration?.expirationInfo()
    }
    
    var certRevoked: Bool {
        Storage.shared.getCertificate(from: app)?.revoked == true
    }
    
    var app: AppInfoPresentable
    
    // MARK: - DIUBAH: Menerima semua binding dari LibraryView
    @Binding var selectedInfoAppPresenting: AnyApp?
    @Binding var selectedSigningAppPresenting: AnyApp?
    @Binding var selectedInstallAppPresenting: AnyApp?
    var selectedDylibsAppPresenting: Binding<AnyApp?>?
    @Binding var selectedAppForActionSheet: AnyApp?
    
    // MARK: Body
    var body: some View {
        let isRegular = horizontalSizeClass != .compact
        
        HStack(spacing: 18) {
            Button(action: {
                self.selectedAppForActionSheet = AnyApp(base: app)
            }) {
                HStack(spacing: 18) {
                    FRAppIconView(app: app, size: 57)
                    
                    NBTitleWithSubtitleView(
                        title: app.name ?? .localized("Unknown"),
                        subtitle: _desc,
                        linelimit: 0
                    )
                }
                .foregroundColor(.primary)
            }
            
            Spacer()
            
            _buttonActions(for: app)
        }
        .padding(isRegular ? 12 : 0)
        .background(
            isRegular
            ? RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.quaternarySystemFill))
            : nil
        )
        .swipeActions {
            _actions(for: app)
        }
    }
    
    private var _desc: String {
        if let version = app.version, let id = app.identifier {
            return "\(version) • \(id)"
        } else {
            return .localized("Unknown")
        }
    }
}


// MARK: - Extension: View
extension LibraryCellView {
    @ViewBuilder
    private func _actions(for app: AppInfoPresentable) -> some View {
        Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
            Storage.shared.deleteApp(for: app)
        }
    }
        
    @ViewBuilder
    private func _buttonActions(for app: AppInfoPresentable) -> some View {
        Group {
            if app.isSigned {
                Button {
                    selectedInstallAppPresenting = AnyApp(base: app)
                } label: {
                    FRExpirationPillView(
                        title: .localized("Install"),
                        revoked: certRevoked,
                        expiration: certInfo
                    )
                }
            } else {
                Button {
                    selectedSigningAppPresenting = AnyApp(base: app)
                } label: {
                    FRExpirationPillView(
                        title: .localized("Sign"),
                        revoked: false,
                        expiration: nil
                    )
                }
            }
        }
        .buttonStyle(.borderless)
    }
}
