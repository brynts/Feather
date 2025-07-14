//
//  ContentView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct LibraryView: View {
    @StateObject var downloadManager = DownloadManager.shared
    
    // MARK: State
    @State private var _selectedInfoAppPresenting: AnyApp?
    @State private var _selectedSigningAppPresenting: AnyApp?
    @State private var _selectedInstallAppPresenting: AnyApp?
    @State private var _selectedDylibsAppPresenting: AnyApp?
    @State private var _isImportingPresenting = false
    @State private var _isDownloadingPresenting = false
    @State private var _alertDownloadString: String = ""
    
    @State private var _searchText = ""
    @State private var _selectedAppForActionSheet: AnyApp?

    @State private var selectedTab: LibraryTab = .imported
    
    @State private var _selectedScope: Scope = .all
    
    @AppStorage("Feather.libraryLayoutStyle")
    private var libraryLayoutStyle: LibraryLayoutStyle.RawValue = LibraryLayoutStyle.vertical.rawValue

    @Namespace private var _namespace
    
    private func filteredAndSortedApps<T>(from apps: FetchedResults<T>) -> [T] where T: NSManagedObject {
        apps.filter {
            _searchText.isEmpty ||
            (($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
        }
    }
    
    private var _filteredSignedApps: [Signed] {
        filteredAndSortedApps(from: _signedApps)
    }
    
    private var _filteredImportedApps: [Imported] {
        filteredAndSortedApps(from: _importedApps)
    }
    
    // MARK: Fetch Requests
    @FetchRequest(
        entity: Signed.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
        animation: .snappy
    ) private var _signedApps: FetchedResults<Signed>
    
    @FetchRequest(
        entity: Imported.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
        animation: .snappy
    ) private var _importedApps: FetchedResults<Imported>
    
    enum LibraryTab: String, CaseIterable {
        case imported = "Imported"
        case signed = "Signed"
    }
    
    // MARK: Body
    var body: some View {
        NBNavigationView(.localized("Library")) {
            Group {
                if LibraryLayoutStyle(rawValue: libraryLayoutStyle) == .horizontal {
                    horizontalBody
                } else {
                    verticalBody
                }
            }
            .toolbar {
                NBToolbarMenu(
                    systemImage: "plus",
                    style: .icon,
                    placement: .topBarTrailing
                ) {
                    _importActions()
                }
            }
            .sheet(item: $_selectedInfoAppPresenting) { app in
                LibraryInfoView(app: app.base)
            }
            .sheet(item: $_selectedInstallAppPresenting) { app in
                InstallPreviewView(app: app.base, isSharing: app.archive)
                    .presentationDetents([.height(200)])
                    .presentationDragIndicator(.visible)
                    .compatPresentationRadius(21)
            }
            .sheet(item: $_selectedDylibsAppPresenting) { app in
                if let uuid = app.base.uuid {
                    let unsignedBaseURL = FileManager.default.unsigned(uuid)
                    
                    if let contents = try? FileManager.default.contentsOfDirectory(at: unsignedBaseURL, includingPropertiesForKeys: nil, options: []),
                       let appBundleURL = contents.first(where: { $0.pathExtension == "app" }) {
                        DylibsView(appPath: appBundleURL)
                    } else {
                        Text("Error: Could not find app bundle.")
                    }
                } else {
                    Text("Error: App has no UUID.")
                }
            }
            .fullScreenCover(item: $_selectedSigningAppPresenting) { app in
                SigningView(app: app.base)
                    .compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
            }
            .sheet(isPresented: $_isImportingPresenting) {
                FileImporterRepresentableView(
                    allowedContentTypes:  [.ipa, .tipa],
                    allowsMultipleSelection: true,
                    onDocumentsPicked: { urls in
                        guard !urls.isEmpty else { return }
                        
                        for url in urls {
                            let id = "FeatherManualDownload_\(UUID().uuidString)"
                            let dl = downloadManager.startArchive(from: url, id: id)
                            try? downloadManager.handlePachageFile(url: url, dl: dl)
                        }
                    }
                )
                .ignoresSafeArea()
            }
            .alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
                TextField(.localized("URL"), text: $_alertDownloadString)
                    .textInputAutocapitalization(.never)
                Button(.localized("Cancel"), role: .cancel) {
                    _alertDownloadString = ""
                }
                Button(.localized("OK")) {
                    if let url = URL(string: _alertDownloadString) {
                        _ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
                    }
                }
            }
            .confirmationDialog(
                _selectedAppForActionSheet?.base.name ?? "Actions...",
                isPresented: .init(
                    get: { _selectedAppForActionSheet != nil },
                    set: { if !$0 { _selectedAppForActionSheet = nil } }
                ),
                titleVisibility: .visible
            ) {
                _actionSheetButtons(for: _selectedAppForActionSheet?.base)
            }
        }
    }
    
    // MARK: - Horizontal Layout Body
    @ViewBuilder
    private var horizontalBody: some View {
        VStack {
            Picker("Pilih kategori", selection: $selectedTab) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            if selectedTab == .imported {
                if _filteredImportedApps.isEmpty {
                    if !_searchText.isEmpty {
                        noSearchResultsView
                    } else {
                        importedEmptyStateView
                    }
                } else {
                    list(for: _filteredImportedApps)
                }
            } else {
                if _filteredSignedApps.isEmpty {
                    if !_searchText.isEmpty {
                        noSearchResultsView
                    } else {
                        signedEmptyStateView
                    }
                } else {
                    list(for: _filteredSignedApps)
                }
            }
        }
        .searchable(text: $_searchText, placement: .navigationBarDrawer)
        .scrollDismissesKeyboard(.interactively)
    }
    
    // MARK: - Vertical Layout Body (Original)
    @ViewBuilder
    private var verticalBody: some View {
        NBListAdaptable {
            if !_filteredSignedApps.isEmpty || !_filteredImportedApps.isEmpty {
                if _selectedScope == .all || _selectedScope == .signed {
                    NBSection(.localized("Signed"), secondary: _filteredSignedApps.count.description) {
                        ForEach(_filteredSignedApps, id: \.uuid) { app in
                            cell(for: app)
                        }
                    }
                }
                
                if _selectedScope == .all || _selectedScope == .imported {
                    NBSection(.localized("Imported"), secondary: _filteredImportedApps.count.description) {
                        ForEach(_filteredImportedApps, id: \.uuid) { app in
                            cell(for: app)
                        }
                    }
                }
            }
        }
        .searchable(text: $_searchText, placement: .platform())
        .compatSearchScopes($_selectedScope) {
            ForEach(Scope.allCases, id: \.displayName) { scope in
                Text(scope.displayName).tag(scope)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .overlay {
            if _signedApps.isEmpty && _importedApps.isEmpty {
                importedEmptyStateView
            }
        }
    }
    
    // MARK: - Reusable Components
    
    @ViewBuilder
    private func list<T: AppInfoPresentable>(for apps: [T]) -> some View {
        NBListAdaptable {
            ForEach(apps, id: \.uuid) { app in
                cell(for: app)
            }
        }
    }

    @ViewBuilder
    private func cell<T: AppInfoPresentable>(for app: T) -> some View {
        LibraryCellView(
            app: app,
            selectedInfoAppPresenting: $_selectedInfoAppPresenting,
            selectedSigningAppPresenting: $_selectedSigningAppPresenting,
            selectedInstallAppPresenting: $_selectedInstallAppPresenting,
            selectedDylibsAppPresenting: $_selectedDylibsAppPresenting,
            selectedAppForActionSheet: $_selectedAppForActionSheet
        )
        .compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
    }

    @ViewBuilder
    private var importedEmptyStateView: some View {
        Spacer()
        if #available(iOS 17, *) {
            ContentUnavailableView {
                Label(.localized("No Apps"), systemImage: "questionmark.app.fill")
            } description: {
                Text(.localized("Get started by importing your first IPA file."))
            } actions: {
                Menu {
                    _importActions()
                } label: {
                    NBButton(.localized("Import"), style: .text)
                }
            }
        } else {
            VStack {
                Label(.localized("No Apps"), systemImage: "questionmark.app.fill")
                    .font(.title)
                Text(.localized("Get started by importing your first IPA file."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                Menu {
                    _importActions()
                } label: {
                    NBButton(.localized("Import"), style: .text)
                        .padding(.top)
                }
            }
        }
        Spacer()
    }
    
    @ViewBuilder
    private var signedEmptyStateView: some View {
        Spacer()
        if #available(iOS 17, *) {
            ContentUnavailableView {
                Label(.localized("No Signed Apps"), systemImage: "signature")
            } description: {
                Text(.localized("Please sign your first IPA file."))
            }
        } else {
            VStack {
                Label(.localized("No Signed Apps"), systemImage: "signature")
                    .font(.title)
                Text(.localized("Please sign your first IPA file."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        Spacer()
    }
    
    @ViewBuilder
    private var noSearchResultsView: some View {
        Spacer()
        if #available(iOS 17, *) {
            ContentUnavailableView.search(text: _searchText)
        } else {
            VStack {
                Label(.localized("No Results"), systemImage: "magnifyingglass")
                    .font(.title)
                Text("No results for '\(_searchText)'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        Spacer()
    }
}

// MARK: - Action Sheet Button
extension LibraryView {
    @ViewBuilder
    private func _actionSheetButtons(for app: AppInfoPresentable?) -> some View {
        if let app {
            Button(.localized("Get Info"), systemImage: "info.circle") {
                _selectedInfoAppPresenting = AnyApp(base: app)
            }
            
            if app.isSigned {
                if let id = app.identifier {
                    Button(.localized("Open"), systemImage: "app.badge.checkmark") {
                        UIApplication.openApp(with: id)
                    }
                }
                Button(.localized("Install"), systemImage: "square.and.arrow.down") {
                    _selectedInstallAppPresenting = AnyApp(base: app)
                }
                Button(.localized("Re-sign"), systemImage: "signature") {
                    _selectedSigningAppPresenting = AnyApp(base: app)
                }
                Button(.localized("Export"), systemImage: "square.and.arrow.up") {
                    _selectedInstallAppPresenting = AnyApp(base: app, archive: true)
                }
            } else {
                Button(.localized("Install"), systemImage: "square.and.arrow.down") {
                    _selectedInstallAppPresenting = AnyApp(base: app)
                }
                Button(.localized("Sign"), systemImage: "signature") {
                    _selectedSigningAppPresenting = AnyApp(base: app)
                }
                Button("Show Dylibs", systemImage: "hammer") {
                    _selectedDylibsAppPresenting = AnyApp(base: app)
                }
            }
            
            Divider()
            
            Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
                Storage.shared.deleteApp(for: app)
            }
        }
    }
}

// MARK: - Extension: View
extension LibraryView {
    @ViewBuilder
    private func _importActions() -> some View {
        Button(.localized("Import from Files"), systemImage: "folder") {
            _isImportingPresenting = true
        }
        Button(.localized("Import from URL"), systemImage: "globe") {
            _isDownloadingPresenting = true
        }
    }
}

// MARK: - Extension: View (Sort)
extension LibraryView {
    enum Scope: CaseIterable {
        case all
        case signed
        case imported
        
        var displayName: String {
            switch self {
            case .all: return .localized("All")
            case .signed: return .localized("Signed")
            case .imported: return .localized("Imported")
            }
        }
    }
}

