//
//  CertificateService.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import Foundation
import UniformTypeIdentifiers

final class CertificateService {
    
    // MARK: - Shared Instance
    static let shared = CertificateService()
    private init() {}
    
    // MARK: - Import Result
    enum ImportResult {
        case success(String)
        case failure(ImportError)
    }
    
    enum ImportError: LocalizedError {
        case invalidFile
        case invalidFileFormat
        case missingProvisionData
        case missingCertificateData
        case invalidPassword
        case multipleProvisionFiles
        case noProvisionFile
        case importFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidFile:
                return "Invalid or inaccessible file"
            case .invalidFileFormat:
                return "Invalid file format"
            case .missingProvisionData:
                return "Missing provisioning profile data"
            case .missingCertificateData:
                return "Missing certificate data"
            case .invalidPassword:
                return "Invalid certificate password"
            case .multipleProvisionFiles:
                return "Multiple .mobileprovision files found. Please import certificate using the Settings > Certificates section."
            case .noProvisionFile:
                return "No .mobileprovision file found in the same directory"
            case .importFailed(let message):
                return "Failed to import certificate: \(message)"
            }
        }
    }
    
    // MARK: - Public Methods
    
    func importP12Certificate(from file: FileItem, completion: @escaping (ImportResult) -> Void) {
        guard file.isP12Certificate else {
            completion(.failure(.invalidFile))
            return
        }
        
        let directory = file.url.deletingLastPathComponent()
        let fileManager = FileManager.default
        
        do {
            let directoryContents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            let provisionFiles = directoryContents.filter { url in
                url.pathExtension.lowercased() == "mobileprovision"
            }
            
            if provisionFiles.isEmpty {
                completion(.failure(.noProvisionFile))
                return
            }
            
            if provisionFiles.count > 1 {
                completion(.failure(.multipleProvisionFiles))
                return
            }
            
            let provisionURL = provisionFiles[0]
            let resourceValues = try provisionURL.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .isDirectoryKey])
            let provisionFile = FileItem(
                name: provisionURL.lastPathComponent,
                url: provisionURL,
                size: Int64(resourceValues.fileSize ?? 0),
                creationDate: resourceValues.creationDate,
                isDirectory: resourceValues.isDirectory ?? false
            )
            
            // Import with password prompt
            importP12Certificate(p12File: file, provisionFile: provisionFile, password: "", completion: completion)
            
        } catch {
            completion(.failure(.importFailed(error.localizedDescription)))
        }
    }
    
    func importP12Certificate(p12File: FileItem, provisionFile: FileItem, password: String, completion: @escaping (ImportResult) -> Void) {
        guard FR.checkPasswordForCertificate(
            for: p12File.url,
            with: password,
            using: provisionFile.url
        ) else {
            completion(.failure(.invalidPassword))
            return
        }
        
        FR.handleCertificateFiles(
            p12URL: p12File.url,
            provisionURL: provisionFile.url,
            p12Password: password,
            certificateName: p12File.name.replacingOccurrences(of: ".p12", with: "")
        ) { error in
            if let error = error {
                completion(.failure(.importFailed(error.localizedDescription)))
            } else {
                completion(.success("Certificate imported successfully"))
            }
        }
    }
}
