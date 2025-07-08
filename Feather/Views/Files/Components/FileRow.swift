//
//  FileRow.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI

struct FileRow: View {
    let file: FileItem
    let isSelected: Bool
    let showChevron: Bool
    
    init(file: FileItem, isSelected: Bool, showChevron: Bool = true) {
        self.file = file
        self.isSelected = isSelected
        self.showChevron = showChevron
    }
    
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if file.isDirectory {
                    if file.isAppDirectory {
                        Image(systemName: "app.badge")
                            .foregroundColor(.accentColor)
                    } else {
                        Image(systemName: "folder")
                            .foregroundColor(.accentColor)
                    }
                } else if file.isArchive {
                    Image(systemName: "doc.zipper")
                        .foregroundColor(.accentColor)
                } else if file.isPlistFile {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.accentColor)
                } else if file.isP12Certificate {
                    Image(systemName: "key")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "doc")
                        .foregroundColor(.accentColor)
                }
            }
            .font(.title2)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
            .animation(.spring(), value: file.isDirectory)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if !file.isDirectory {
                        Text(file.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let dateString = file.formattedDate {
                        if !file.isDirectory {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(dateString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 22))
                    .transition(.scale.combined(with: .opacity))
            } else if file.isDirectory && showChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14, weight: .semibold))
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovering ? Color.gray.opacity(0.1) : Color.clear)
                .animation(.easeInOut(duration: 0.2), value: isHovering)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
} 
