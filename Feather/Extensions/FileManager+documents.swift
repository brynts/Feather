//
//  FileManager+documents.swift
//  Feather
//
//  Created by samara on 11.04.2025.
//

import Foundation.NSFileManager

extension FileManager {
    static func forceWrite(content: String, to path: URL) throws {
        let data = Data(content.utf8)
        let folder = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try data.write(to: path, options: .atomic)
    }
    
    /// Base path: Documents/Feather
    private var featherDir: URL {
        URL.documentsDirectory.appendingPathComponent("Feather")
    }
    
	/// Gives apps Signed directory
	var archives: URL {
        featherDir.appendingPathComponent("Archives")
	}
	
	/// Gives apps Signed directory
	var signed: URL {
        featherDir.appendingPathComponent("Signed")
	}
	
	/// Gives apps Signed directory with a UUID appending path
	func signed(_ uuid: String) -> URL {
		signed.appendingPathComponent(uuid)
	}
	
	/// Gives apps Unsigned directory
	var unsigned: URL {
        featherDir.appendingPathComponent("Unsigned")
	}
	
	/// Gives apps Unsigned directory with a UUID appending path
	func unsigned(_ uuid: String) -> URL {
		unsigned.appendingPathComponent(uuid)
	}
	
	/// Gives apps Certificates directory
	var certificates: URL {
        featherDir.appendingPathComponent("Certificates")
	}
	/// Gives apps Certificates directory with a UUID appending path
	func certificates(_ uuid: String) -> URL {
		certificates.appendingPathComponent(uuid)
	}
    
    /// Gives apps Data directory
    var dataDir: URL {
        featherDir.appendingPathComponent("Data")
    }
}
