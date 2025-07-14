//
//  LibraryLayoutStyle.swift
//  Feather
//
//  Created by Bryan Saputra on 14/07/25.
//


import Foundation

// Enum ini akan menyimpan pilihan layout yang tersedia.
// Menggunakan Int sebagai RawValue memudahkan penyimpanan di AppStorage.
enum LibraryLayoutStyle: Int, CaseIterable {
    case vertical = 0
    case horizontal = 1
    
    // Nama yang akan ditampilkan di UI Picker
    var displayName: String {
        switch self {
        case .vertical:
            return "Vertical"
        case .horizontal:
            return "Horizontal"
        }
    }
}
