//
//  TextEditorView.swift
//  Feather
//
//  Created by Bryan Saputra on 07/07/25.
//


import SwiftUI

struct TextEditorView: View {
    let fileURL: URL
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var textContent: String = ""
    @State private var hasUnsavedChanges: Bool = false
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    Spacer()
                    ProgressView("Loading File...")
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    TextEditor(text: $textContent)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                        .onChange(of: textContent) { _ in
                            hasUnsavedChanges = true
                        }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveFileContent()
                    }
                    .disabled(!hasUnsavedChanges)
                }
            }
            .onAppear(perform: loadFileContent)
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func loadFileContent() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let content = try String(contentsOf: fileURL, encoding: .utf8)
                DispatchQueue.main.async {
                    self.textContent = content
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.alertMessage = "Failed to load file content: \(error.localizedDescription)"
                    self.showAlert = true
                    self.isLoading = false
                }
            }
        }
    }
    
    private func saveFileContent() {
        isLoading = true
        do {
            try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
            DispatchQueue.main.async {
                self.isLoading = false
                self.hasUnsavedChanges = false
            }
        } catch {
            DispatchQueue.main.async {
                self.alertMessage = "Failed to save file: \(error.localizedDescription)"
                self.showAlert = true
                self.isLoading = false
            }
        }
    }
}
