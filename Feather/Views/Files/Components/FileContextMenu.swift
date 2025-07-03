//
//  FileContextMenu.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

// File context menu
struct FileContextMenu: View {
    @ObservedObject var viewModel: FilesViewModel
    let file: FileItem
    @Binding var showingActionSheet: Bool
    @Binding var selectedFileForAction: FileItem?
    
    var body: some View {
        Button {
            selectedFileForAction = file
            showingActionSheet = true
        } label: {
            Label("Actions...", systemImage: "ellipsis.circle")
        }
        
        Button {
            viewModel.itemToRename = file
            viewModel.newFileName = file.name
            viewModel.showRenameDialog = true
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        
        if file.isArchive {
            Button {
                selectedFileForAction = file
                showingActionSheet = true
            } label: {
                Label("Extract", systemImage: "doc.zipper")
            }
        }
        
        if file.isPlistFile {
            Button {
                selectedFileForAction = file
                showingActionSheet = true
            } label: {
                Label("Edit as Property List", systemImage: "list.bullet")
            }
        }
        
        if file.isP12Certificate {
            Button {
                viewModel.importCertificate(file)
            } label: {
                Label("Import Certificate", systemImage: "key")
            }
        }
        
        if file.isAppDirectory {
            Button {
                selectedFileForAction = file
                showingActionSheet = true
            } label: {
                Label("Package as IPA", systemImage: "app.badge")
            }
        }
        
        Button {
            // ts not happening
        } label: {
            Label("Share", systemImage: "square.and.arrow.up")
        }
        
        Divider()
        
        Button(role: .destructive) {
            viewModel.deleteFile(file)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
} 
