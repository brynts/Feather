//
//  FilesView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI
import UniformTypeIdentifiers
import QuickLook
import NimbleViews

struct FilesView: View {
    let directoryURL: URL?
    let isRootView: Bool
    
    @StateObject private var viewModel: FilesViewModel
    @StateObject private var downloadManager = DownloadManager.shared
    @State private var searchText = ""
    @Namespace private var animation
    @State private var showingActionSheet = false
    @State private var selectedFileForAction: FileItem?
    @State private var extractionProgress: Double = 0
    @State private var isExtracting = false
    @State private var navigateToPlistEditor = false
    @State private var plistFileURL: URL?
    @State private var navigateToHexEditor = false
    @State private var hexEditorFileURL: URL?
    @State private var navigateToTextEditor = false
    @State private var textEditorURL: URL?
    @State private var showFilePreview = false
    @State private var previewFile: FileItem?
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    
    @Environment(\.editMode) private var editMode
    
    init() {
        self.directoryURL = nil
        self.isRootView = true
        self._viewModel = StateObject(wrappedValue: FilesViewModel())
    }
    
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        self.isRootView = false
        self._viewModel = StateObject(wrappedValue: FilesViewModel(directory: directoryURL))
    }
    
    private var filteredFiles: [FileItem] {
        let filesToDisplay = viewModel.files.filter { fileItem in
            if isRootView {
                return fileItem.name.lowercased() != "inbox"
            }
            return true
        }
            
        if searchText.isEmpty {
            return filesToDisplay
        } else {
            return filesToDisplay.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    private var isEditing: Bool {
        viewModel.isEditMode == .active
    }
    
    private var allItemsSelected: Bool {
        !filteredFiles.isEmpty && viewModel.selectedItems.count == filteredFiles.count
    }
    
    var body: some View {
        Group {
            if isRootView {
                NavigationView {
                    filesBrowserContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .accentColor(.accentColor)
            } else {
                filesBrowserContent
            }
        }
        .onAppear {
            setupView()
        }
        .onDisappear {
            if !isRootView {
                NotificationCenter.default.removeObserver(self)
            }
        }
    }
    
    private var filesBrowserContent: some View {
        ZStack {
            contentView
                .navigationTitle(navigationTitle)
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: String(localized: "Search files"))
                .refreshable {
                    if isRootView {
                        await withCheckedContinuation { continuation in
                            viewModel.loadFiles()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                continuation.resume()
                            }
                        }
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        addButton
                        editButton
                    }
                    
                    if isEditing {
                        ToolbarItemGroup(placement: .bottomBar) {
                            selectAllButton
                            Spacer()
                            copyButton
                            Spacer()
                            moveButton
                            Spacer()
                            shareButton
                            Spacer()
                            deleteButton
                        }
                    }
                }
            
            if isExtracting {
                extractionProgressView
            }
        }
        .sheet(isPresented: $viewModel.showingImporter) {
            FileImporterRepresentableView(
                allowedContentTypes: [UTType.item],
                allowsMultipleSelection: true,
                onDocumentsPicked: { urls in
                    viewModel.importFiles(urls: urls)
                }
            )
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: shareItems)
        }
        .sheet(isPresented: $viewModel.showDirectoryPicker) {
            if let operation = viewModel.activeOperation {
                FileDirectoryPickerView(viewModel: viewModel, operationType: operation)
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            fileActionSheet()
        }
        .fullScreenCover(isPresented: $navigateToPlistEditor) {
            if let fileURL = plistFileURL {
                PlistEditorView(fileURL: fileURL)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .fullScreenCover(isPresented: $navigateToHexEditor) {
            if let fileURL = hexEditorFileURL {
                HexEditorView(fileURL: fileURL)
                    .edgesIgnoringSafeArea(.all)
            }
        }
        .fullScreenCover(isPresented: $navigateToTextEditor) {
            if let fileURL = textEditorURL {
                TextEditorView(fileURL: fileURL)
            }
        }
        .alert(String(localized: "New Folder"), isPresented: $viewModel.showingNewFolderDialog) {
            TextField(String(localized: "Folder name"), text: $viewModel.newFolderName)
                .autocapitalization(.words)
                .disableAutocorrection(true)
            Button(String(localized: "Cancel"), role: .cancel) { viewModel.newFolderName = "" }
            Button(String(localized: "Create")) { viewModel.createNewFolder() }
        } message: {
            Text(String(localized: "Enter a name for the new folder"))
        }
        .alert("New File", isPresented: $viewModel.showingNewFileDialog) {
            TextField("File name", text: $viewModel.newFileItemName)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("Cancel", role: .cancel) { viewModel.newFileItemName = "" }
            Button("Create") { viewModel.createNewFile() }
        } message: {
            Text("Enter a name for the new file. Include the extension (e.g., file.txt).")
        }
        .alert(String(localized: "Rename File"), isPresented: $viewModel.showRenameDialog) {
            TextField(String(localized: "File name"), text: $viewModel.newFileName)
                .disableAutocorrection(true)
            Button(String(localized: "Cancel"), role: .cancel) {
                viewModel.itemToRename = nil
                viewModel.newFileName = ""
            }
            Button(String(localized: "Rename")) { viewModel.renameFile() }
        } message: {
            Text(String(localized: "Enter a new name"))
        }
        .alert(isPresented: $viewModel.showingError) {
            Alert(
                title: Text(String(localized: "Success")),
                message: Text(viewModel.error ?? String(localized: "An unknown error occurred")),
                dismissButton: .default(Text(String(localized: "OK")))
            )
        }
        .alert(String(localized: "Enter Certificate Password"), isPresented: $viewModel.showPasswordAlert) {
            TextField(String(localized: "Password (leave empty if none)"), text: $viewModel.certificatePassword)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button(String(localized: "Cancel"), role: .cancel) {
                viewModel.selectedP12File = nil
                viewModel.selectedProvisionFile = nil
                viewModel.certificatePassword = ""
            }
            Button(String(localized: "Import")) { viewModel.completeCertificateImport() }
        } message: {
            Text(String(localized: "Enter the password for the certificate. Leave it blank if no password is required."))
        }
        .onAppear {
            if !isRootView {
                setupNotifications()
            }
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if filteredFiles.isEmpty {
                emptyStateView
            } else {
                fileListView
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: filteredFiles)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.isLoading)
    }
    
    private var loadingView: some View {
        ProgressView()
            .scaleEffect(1.5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.7))
            
            Text(String(localized: "This folder is empty"))
                .font(.title3.bold())
            
            Text(String(localized: "Import files using the + button above"))
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: filteredFiles.isEmpty)
    }
    
    private var fileListView: some View {
        List {
            ForEach(filteredFiles) { file in
                let isNavigable = file.isDirectory

                if !isEditing && isNavigable {
                    NavigationLink(destination: FilesView(directoryURL: file.url)) {
                        FileRow(file: file, isSelected: viewModel.selectedItems.contains(file), showChevron: false)
                    }
                    .contextMenu {
                        FileContextMenu(viewModel: viewModel, file: file, showingActionSheet: $showingActionSheet, selectedFileForAction: $selectedFileForAction)
                    }
                    .swipeActions(edge: .trailing) {
                        swipeActions(for: file)
                    }
                    .listRowBackground(selectionBackground(for: file))
                } else {
                    Button(action: {
                        handleFileTap(file)
                    }) {
                        FileRow(file: file, isSelected: viewModel.selectedItems.contains(file), showChevron: false)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        FileContextMenu(viewModel: viewModel, file: file, showingActionSheet: $showingActionSheet, selectedFileForAction: $selectedFileForAction)
                    }
                    .swipeActions(edge: .trailing) {
                        swipeActions(for: file)
                    }
                    .listRowBackground(selectionBackground(for: file))
                }
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, $viewModel.isEditMode)
    }
    
    private var navigationTitle: String {
        if let directoryURL = directoryURL {
            return directoryURL.lastPathComponent
        } else {
            return viewModel.currentDirectory.lastPathComponent
        }
    }
    
    private var extractionProgressView: some View {
        FileUIHelpers.extractionProgressView(progress: extractionProgress)
    }
    
    private func setupView() {
        viewModel.loadFiles()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionStarted"), object: nil, queue: .main) { _ in
            self.isExtracting = true
            self.extractionProgress = 0.1
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionCompleted"), object: nil, queue: .main) { _ in
            self.extractionProgress = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    self.isExtracting = false
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("ExtractionFailed"), object: nil, queue: .main) { _ in
            self.isExtracting = false
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NavigateToPlistEditor"), object: nil, queue: .main) { notification in
            if let fileURL = notification.userInfo?["fileURL"] as? URL {
                self.plistFileURL = fileURL
                self.navigateToPlistEditor = true
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name("NavigateToHexEditor"), object: nil, queue: .main) { notification in
            if let fileURL = notification.userInfo?["fileURL"] as? URL {
                self.hexEditorFileURL = fileURL
                self.navigateToHexEditor = true
            }
        }
    }
    
    private var addButton: some View {
        Menu {
            Button {
                viewModel.showingImporter = true
            } label: {
                Label(String(localized: "Import Files"), systemImage: "doc.badge.plus")
            }
            
            Button {
                viewModel.showingNewFolderDialog = true
            } label: {
                Label(String(localized: "New Folder"), systemImage: "folder.badge.plus")
            }
            
            Button {
                viewModel.showingNewFileDialog = true
            } label: {
                Label("New File", systemImage: "doc.text")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
    }
    
    private var editButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.isEditMode = isEditing ? .inactive : .active
                if !isEditing {
                    viewModel.selectedItems.removeAll()
                }
            }
        } label: {
            Text(isEditing ? String(localized: "Done") : String(localized: "Edit"))
                .fontWeight(.medium)
        }
    }
    
    private var selectAllButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if allItemsSelected {
                    viewModel.selectedItems.removeAll()
                } else {
                    viewModel.selectedItems = Set(filteredFiles)
                }
            }
        } label: {
            Text(allItemsSelected ? String(localized: "Deselect All") : String(localized: "Select All"))
                .fontWeight(.medium)
        }
        .disabled(filteredFiles.isEmpty)
    }
    
    private var copyButton: some View {
        Button {
            viewModel.activeOperation = .copy
            viewModel.showDirectoryPicker = true
        } label: {
            Label(String(localized: "Copy"), systemImage: "doc.on.doc")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var moveButton: some View {
        Button {
            viewModel.activeOperation = .move
            viewModel.showDirectoryPicker = true
        } label: {
            Label(String(localized: "Move"), systemImage: "tray.and.arrow.up")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var shareButton: some View {
        Button {
            if !viewModel.selectedItems.isEmpty {
                let urls = viewModel.selectedItems.map { $0.url }
                
                for url in urls {
                    url.startAccessingSecurityScopedResource()
                }
                
                shareItems = urls
                showingShareSheet = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    for url in urls {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private var deleteButton: some View {
        Button(role: .destructive) {
            viewModel.deleteSelectedItems()
        } label: {
            Image(systemName: "trash")
        }
        .disabled(viewModel.selectedItems.isEmpty)
    }
    
    private func handleFileTap(_ file: FileItem) {
        if isEditing {
            if viewModel.selectedItems.contains(file) {
                viewModel.selectedItems.remove(file)
            } else {
                viewModel.selectedItems.insert(file)
            }
        } else {
            if !file.isDirectory {
                FileUIHelpers.handleFileTap(
                    file,
                    viewModel: viewModel,
                    selectedFileForAction: $selectedFileForAction,
                    showingActionSheet: $showingActionSheet
                )
            }
        }
    }
    
    private func fileActionSheet() -> ActionSheet {
        guard let file = selectedFileForAction else {
            return ActionSheet(title: Text(String(localized: "Error")), message: Text(String(localized: "No file selected")), buttons: [.cancel()])
        }
        
        var buttons: [ActionSheet.Button] = []
        
        buttons.append(.default(Text("Edit Text")) {
            self.textEditorURL = file.url
            self.navigateToTextEditor = true
        })
        
        if !file.isDirectory {
            buttons.append(.default(Text(String(localized: "Preview"))) {
                presentQuickLook(for: file)
            })
        }
        
        if file.isPlistFile {
            buttons.append(.default(Text(String(localized: "Plist Editor"))) {
                plistFileURL = file.url
                navigateToPlistEditor = true
            })
        }
        
        if !file.isDirectory {
            buttons.append(.default(Text(String(localized: "Hex Editor"))) {
                hexEditorFileURL = file.url
                navigateToHexEditor = true
            })
        }
        
        if file.isP12Certificate {
            buttons.append(.default(Text(String(localized: "Import Certificate"))) {
                viewModel.importCertificate(file)
            })
        }
        
        if let ext = file.fileExtension?.lowercased(), ext == "ipa" {
            buttons.append(.default(Text(String(localized: "Import to Library"))) {
                importIpaToLibrary(file)
            })
        }
        if let ext = file.fileExtension?.lowercased(), ext == "app" {
            buttons.append(.default(Text(String(localized: "Package as IPA"))) {
                packageAppAsIPA(file)
            })
        }
        
        if file.isArchive {
            buttons.append(.default(Text(String(localized: "Extract"))) {
                extractArchive(file)
            })
        }
        
        buttons.append(.default(Text(String(localized: "Rename"))) {
            viewModel.itemToRename = file
            viewModel.newFileName = file.name
            viewModel.showRenameDialog = true
        })
        
        buttons.append(.default(Text(String(localized: "Share"))) {
            FileUIHelpers.shareFile(file, shareItems: $shareItems, showingShareSheet: $showingShareSheet)
        })
        
        buttons.append(.destructive(Text(String(localized: "Delete"))) {
            withAnimation {
                viewModel.deleteFile(file)
            }
        })
        
        buttons.append(.cancel())
        
        return ActionSheet(
            title: Text(file.name),
            message: Text(String(localized: "Choose an action")),
            buttons: buttons
        )
    }
    
    private func extractArchive(_ file: FileItem) {
        guard file.isArchive else { return }
        
        isExtracting = true
        extractionProgress = 0.0
        
        ExtractionService.extractArchive(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    self.extractionProgress = progress
                }
            }
        ) { result in
            DispatchQueue.main.async {
                self.isExtracting = false
                
                switch result {
                case .success:
                    withAnimation {
                        self.viewModel.loadFiles()
                    }
                    self.viewModel.error = String(localized: "File extracted successfully")
                    self.viewModel.showingError = true
                    
                case .failure(let error):
                    self.viewModel.error = String(localized: "Error extracting archive: \(error.localizedDescription)")
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func packageAppAsIPA(_ file: FileItem) {
        guard file.isAppDirectory else { return }
        
        isExtracting = true
        extractionProgress = 0.0
        
        ExtractionService.packageAppAsIPA(
            file,
            to: viewModel.currentDirectory,
            progressCallback: { progress in
                DispatchQueue.main.async {
                    self.extractionProgress = progress
                }
            }
        ) { result in
            DispatchQueue.main.async {
                self.isExtracting = false
                
                switch result {
                case .success(let ipaFileName):
                    self.viewModel.loadFiles()
                    self.viewModel.error = "Successfully packaged \(file.name) as \(ipaFileName)"
                    self.viewModel.showingError = true
                    
                case .failure(let error):
                    self.viewModel.error = "Failed to package IPA: \(error.localizedDescription)"
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func importIpaToLibrary(_ file: FileItem) {
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let id = "FeatherManualDownload_\(UUID().uuidString)"
                
                let download = self.downloadManager.startArchive(from: file.url, id: id)
                
                try self.downloadManager.handlePachageFile(url: file.url, dl: download)
                
            } catch {
                DispatchQueue.main.async {
                    self.isExtracting = false
                    self.viewModel.error = "Failed to import to Library: \(error.localizedDescription)"
                    self.viewModel.showingError = true
                }
            }
        }
    }
    
    private func presentQuickLook(for file: FileItem) {
        let previewController = QuickLookController.shared
        previewController.previewFile(file.url)
    }
    
    private func selectionBackground(for file: FileItem) -> some View {
        FileUIHelpers.selectionBackground(for: file, selectedItems: viewModel.selectedItems)
    }
    
    @ViewBuilder
    private func swipeActions(for file: FileItem) -> some View {
        FileUIHelpers.swipeActions(for: file, viewModel: viewModel)
    }
}

