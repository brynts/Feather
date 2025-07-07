//
//  DylibsView.swift
//  Ksign
//
//  Created by Nagata Asami on 22/5/25.
//

import SwiftUI
import NimbleViews

struct DylibsView: View {
    var appPath: URL
    @Environment(\.dismiss) private var dismiss
    
    @State private var dylibs: [URL] = []
    @State private var bundles: [URL] = []
    @State private var appexs: [URL] = []
    @State private var selectedDylibs: [URL] = []
    @State private var isLoading = true
    @State private var showDirectoryPicker = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @State private var isDylibsExpanded = false
    @State private var isBundlesExpanded = false
    @State private var isAppexsExpanded = false
    
    var body: some View {
        NBNavigationView(.localized("Tweak Picker")) {
            VStack {
                HStack {
                    Button(.localized("Done")) {
                        dismiss()
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(.localized("Copy")) {
                        showDirectoryPicker = true
                    }
                    .disabled(selectedDylibs.isEmpty)
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else if dylibs.isEmpty && bundles.isEmpty && appexs.isEmpty {
                    if #available(iOS 17.0, *) {
                        ContentUnavailableView(
                            .localized("No files"),
                            systemImage: "doc.text.magnifyingglass",
                            description: Text(.localized("No Dylibs, Bundles or Appexs found in this app"))
                        )
                    } else {
                        VStack(spacing: 15) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            
                            Text(.localized("No files"))
                                .font(.headline)
                            
                            Text(.localized("No Dylibs, Bundles or Appexs found in this app"))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    List {
                        if !dylibs.isEmpty {
                            DisclosureGroup(isExpanded: $isDylibsExpanded) {
                                ForEach(dylibs, id: \.self) { fileURL in
                                    DylibRowView(
                                        fileURL: fileURL,
                                        isSelected: selectedDylibs.contains(fileURL),
                                        toggleSelection: { toggleDylibSelection(fileURL) }
                                    )
                                }
                            } label: {
                                Text("DYLIBS")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if !bundles.isEmpty {
                            DisclosureGroup(isExpanded: $isBundlesExpanded) {
                                ForEach(bundles, id: \.self) { fileURL in
                                    DylibRowView(
                                        fileURL: fileURL,
                                        isSelected: selectedDylibs.contains(fileURL),
                                        toggleSelection: { toggleDylibSelection(fileURL) }
                                    )
                                }
                            } label: {
                                Text("BUNDLES")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }

                        if !appexs.isEmpty {
                            DisclosureGroup(isExpanded: $isAppexsExpanded) {
                                ForEach(appexs, id: \.self) { fileURL in
                                    DylibRowView(
                                        fileURL: fileURL,
                                        isSelected: selectedDylibs.contains(fileURL),
                                        toggleSelection: { toggleDylibSelection(fileURL) }
                                    )
                                }
                            } label: {
                                Text("APPEXS")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .onAppear {
                loadDylibFiles()
            }
            .sheet(isPresented: $showDirectoryPicker) {
                DirectoryPickerView(onDirectorySelected: { url in
                    copyDylibsToDestination(destinationURL: url)
                })
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button(.localized("OK"), role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadDylibFiles() {
        isLoading = true
        dylibs = []
        bundles = []
        appexs = []

        DispatchQueue.global(qos: .userInitiated).async {
            var dylibs: [URL] = []
            var bundles: [URL] = []
            var appexs: Set<URL> = []
            let fileManager = FileManager.default

            func collect(from directory: URL) {
                guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else { return }
                for case let fileURL as URL in enumerator {
                    let ext = fileURL.pathExtension.lowercased()
                    if ext == "dylib", fileURL.isFileURL {
                        dylibs.append(fileURL)
                    } else if ext == "bundle", fileURL.isFileURL {
                        bundles.append(fileURL)
                    } else if ext == "appex" {
                        var isDir: ObjCBool = false
                        if fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), isDir.boolValue {
                            appexs.insert(fileURL)
                        }
                    }
                }
            }

            collect(from: appPath)
            collect(from: appPath.appendingPathComponent("Dylibs"))
            collect(from: appPath.appendingPathComponent("PlugIns"))

            DispatchQueue.main.async {
                self.dylibs = dylibs.sorted { $0.lastPathComponent < $1.lastPathComponent }
                self.bundles = bundles.sorted { $0.lastPathComponent < $1.lastPathComponent }
                self.appexs = Array(appexs).sorted { $0.lastPathComponent < $1.lastPathComponent }
                self.isLoading = false
            }
        }
    }
    
    private func toggleDylibSelection(_ fileURL: URL) {
        if let index = selectedDylibs.firstIndex(of: fileURL) {
            selectedDylibs.remove(at: index)
        } else {
            selectedDylibs.append(fileURL)
        }
    }
    
    private func copyDylibsToDestination(destinationURL: URL) {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationPath = destinationURL.path
        
        guard destinationPath.hasPrefix(documentsDirectory.path) else {
            alertTitle = .localized("Invalid Destination")
            alertMessage = .localized("The destination must be within the app's documents directory.")
            showAlert = true
            return
        }
        
        var successCount = 0
        var errorMessages: [String] = []
        
        for dylibURL in selectedDylibs {
            let fileName = dylibURL.lastPathComponent
            let destinationFileURL = destinationURL.appendingPathComponent(fileName)
            
            do {
                if fileManager.fileExists(atPath: destinationFileURL.path) {
                    try fileManager.removeItem(at: destinationFileURL)
                }
                
                try fileManager.copyItem(at: dylibURL, to: destinationFileURL)
                successCount += 1
            } catch {
                errorMessages.append("\(fileName): \(error.localizedDescription)")
            }
        }
        
        if errorMessages.isEmpty {
            alertTitle = .localized("Success")
            alertMessage = .localized("Successfully copied \(successCount) files")
        } else {
            alertTitle = .localized("Partial Success")
            alertMessage = .localized("Copied \(successCount) files") + "\n" + errorMessages.joined(separator: "\n")
        }
        
        showAlert = true
    }
}

struct DylibRowView: View {
    let fileURL: URL
    let isSelected: Bool
    let toggleSelection: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: fileURL.pathExtension.lowercased() == "framework" ? "shippingbox" : "doc.circle")
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading) {
                Text(fileURL.lastPathComponent)
                    .font(.body)
                
                Text(fileURL.pathExtension.uppercased())
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection()
        }
    }
}

struct DirectoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDirectory: URL?
    @State private var currentDirectory: URL
    let onDirectorySelected: (URL) -> Void
    
    init(onDirectorySelected: @escaping (URL) -> Void) {
        self.onDirectorySelected = onDirectorySelected
        
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        _currentDirectory = State(initialValue: documentsDirectory)
    }
    
    var body: some View {
        NBNavigationView(.localized("Select Destination")) {
            VStack {
                HStack {
                    Button(.localized("Cancel")) {
                        dismiss()
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Button(.localized("Select")) {
                        onDirectorySelected(currentDirectory)
                        dismiss()
                    }
                    .padding(.trailing)
                }
                .padding(.vertical, 8)
                
                List {
                    Section {
                        Text(currentDirectory.lastPathComponent)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Section(.localized("Directories")) {
                        ForEach(getDirectories(), id: \.absoluteString) { url in
                            HStack {
                                Image(systemName: "folder")
                                    .foregroundColor(.accentColor)
                                Text(url.lastPathComponent)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                currentDirectory = url
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func getDirectories() -> [URL] {
        let fileManager = FileManager.default
        
        do {
            let urls = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.isDirectoryKey])
            return urls.filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            return []
        }
    }
}
