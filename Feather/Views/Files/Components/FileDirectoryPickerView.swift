//
//  FileDirectoryPickerView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct FileDirectoryPickerView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: FilesViewModel
    @State private var currentDirectory: URL
    @State private var directoryStack: [URL] = []
    @State private var files: [FileItem] = []
    @State private var isLoading = false
    
    let operationType: FileOperationType
    
    init(viewModel: FilesViewModel, operationType: FileOperationType) {
        self.viewModel = viewModel
        self.operationType = operationType
        
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            _currentDirectory = State(initialValue: documentsDirectory)
        } else {
            _currentDirectory = State(initialValue: URL(fileURLWithPath: ""))
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else {
                    directoryListView
                }
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Select") {
                        switch operationType {
                        case .move:
                            viewModel.moveFiles(to: currentDirectory)
                        case .copy:
                            viewModel.copyFiles(to: currentDirectory)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(operationType == .move && currentDirectory.path == viewModel.currentDirectory.path)
                }
            }
            .onAppear {
                loadDirectories()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private var directoryListView: some View {
        List {
            if !directoryStack.isEmpty {
                Button {
                    navigateBack()
                } label: {
                    HStack {
                        Image(systemName: "arrow.left")
                            .foregroundColor(.accentColor)
                        Text("Back")
                            .foregroundColor(.primary)
                    }
                }
            }
            
            ForEach(files) { file in
                if file.isDirectory {
                    Button {
                        navigateToDirectory(file.url)
                    } label: {
                        HStack {
                            Image(systemName: "folder")
                                .foregroundColor(.accentColor)
                            Text(file.name)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.system(size: 14))
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }
    
    private func loadDirectories() {
        isLoading = true
        let fileManager = FileManager.default
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contents = try fileManager.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey])
                
                let dirFiles = contents.compactMap { url -> FileItem? in
                    do {
                        let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .creationDateKey, .fileSizeKey])
                        let isDirectory = resourceValues.isDirectory ?? false
                        
                        if isDirectory {
                            let creationDate = resourceValues.creationDate
                            let size = resourceValues.fileSize ?? 0
                            
                            return FileItem(
                                name: url.lastPathComponent,
                                url: url,
                                size: Int64(size),
                                creationDate: creationDate,
                                isDirectory: isDirectory
                            )
                        }
                        return nil
                    } catch {
                        print("Error getting file attributes: \(error)")
                        return nil
                    }
                }.sorted { $0.name.lowercased() < $1.name.lowercased() }
                
                DispatchQueue.main.async {
                    self.files = dirFiles
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    print("Error loading directories: \(error)")
                }
            }
        }
    }
    
    private func navigateToDirectory(_ directory: URL) {
        directoryStack.append(currentDirectory)
        currentDirectory = directory
        loadDirectories()
    }
    
    private func navigateBack() {
        if let previous = directoryStack.popLast() {
            currentDirectory = previous
            loadDirectories()
        }
    }
}

