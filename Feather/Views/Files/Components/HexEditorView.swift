//
//  HexEditorView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI
import UIKit

struct HexEditorView: UIViewControllerRepresentable {
    let fileURL: URL
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> HexEditorViewController {
        let controller = HexEditorViewController(fileURL: fileURL)
        controller.dismissAction = {
            self.presentationMode.wrappedValue.dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: HexEditorViewController, context: Context) {
        // ts not happening
    }
}

class HexEditorViewController: UIViewController, UISearchBarDelegate, UITextViewDelegate {
    
    // MARK: - Properties
    private let fileURL: URL
    private var fileData: Data
    private let textView = UITextView()
    private var isEditingMode = false
    private var hasUnsavedChanges = false
    var dismissAction: (() -> Void)?
    
    private let customHeaderView = UIView()
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let editButton = UIButton(type: .system)
    
    private enum ViewMode: Int {
        case byte = 0
        case string = 1
    }
    private var currentViewMode: ViewMode = .byte
    private let viewModeControl = UISegmentedControl(items: ["Byte", "String"])
    
    private let searchBar = UISearchBar()
    private var searchMatches: [NSRange] = []
    private var currentMatchIndex: Int = -1
    private var isAddressSearch = false
    
    private let maxDisplayBytes = 10240 // 10KB at a time
    private var currentOffset = 0
    private var fileSize: Int = 0
    
    private let addressColor = UIColor(red: 0.4, green: 0.5, blue: 0.9, alpha: 1.0)
    private let hexColor = UIColor.label
    private let asciiColor = UIColor(red: 0.1, green: 0.6, blue: 0.3, alpha: 1.0)
    private let highlightColor = UIColor(red: 1.0, green: 0.8, blue: 0.0, alpha: 0.5)
    
    private var hexToAsciiMapping = [NSRange: NSRange]()
    private var asciiToHexMapping = [NSRange: NSRange]()
    private var currentHighlightedRange: NSRange?
    
    // MARK: - Initialization
    init(fileURL: URL) {
        self.fileURL = fileURL
        
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let fileSize = fileAttributes?[.size] as? NSNumber {
            self.fileSize = fileSize.intValue
        } else {
            self.fileSize = 0
        }
        
        self.fileData = Data()
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCustomHeader()
        setupViews()
        loadDataChunk()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Setup
    private func setupCustomHeader() {
        customHeaderView.backgroundColor = .systemBackground
        view.addSubview(customHeaderView)
        
        customHeaderView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            customHeaderView.topAnchor.constraint(equalTo: view.topAnchor),
            customHeaderView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            customHeaderView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            customHeaderView.heightAnchor.constraint(equalToConstant: 88)
        ])
        
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = UIColor(named: "AccentColor")
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        customHeaderView.addSubview(backButton)
        
        titleLabel.text = fileURL.lastPathComponent
        titleLabel.textColor = .label
        titleLabel.font = UIFont.boldSystemFont(ofSize: 17)
        titleLabel.textAlignment = .center
        customHeaderView.addSubview(titleLabel)
        
        editButton.setImage(UIImage(systemName: "pencil.circle.fill"), for: .normal)
        editButton.tintColor = UIColor(named: "AccentColor")
        editButton.addTarget(self, action: #selector(toggleEditing), for: .touchUpInside)
        customHeaderView.addSubview(editButton)
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        editButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: customHeaderView.leadingAnchor, constant: 16),
            backButton.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: -8),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.centerXAnchor.constraint(equalTo: customHeaderView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: -12),
            
            editButton.trailingAnchor.constraint(equalTo: customHeaderView.trailingAnchor, constant: -16),
            editButton.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: -8),
            editButton.widthAnchor.constraint(equalToConstant: 30),
            editButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        viewModeControl.selectedSegmentIndex = currentViewMode.rawValue
        viewModeControl.addTarget(self, action: #selector(viewModeChanged), for: .valueChanged)
        viewModeControl.translatesAutoresizingMaskIntoConstraints = false
        viewModeControl.backgroundColor = .systemBackground
        viewModeControl.selectedSegmentTintColor = .systemBlue
        view.addSubview(viewModeControl)
        
        searchBar.delegate = self
        searchBar.placeholder = "Search hex or ASCII"
        searchBar.showsCancelButton = true
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        searchBar.autocapitalizationType = .none
        searchBar.backgroundColor = .systemBackground
        view.addSubview(searchBar)
        
        textView.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        textView.isEditable = false
        textView.isSelectable = true
        textView.delegate = self
        textView.autocapitalizationType = .none
        textView.autocorrectionType = .no
        textView.spellCheckingType = .no
        textView.smartDashesType = .no
        textView.smartQuotesType = .no
        textView.smartInsertDeleteType = .no
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 5, bottom: 10, right: 5)
        
        view.addSubview(textView)
        
        NSLayoutConstraint.activate([
            viewModeControl.topAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: 8),
            viewModeControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            viewModeControl.widthAnchor.constraint(equalToConstant: 160),
            viewModeControl.heightAnchor.constraint(equalToConstant: 32),
            
            searchBar.topAnchor.constraint(equalTo: viewModeControl.bottomAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        
        textView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: searchBar.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func backButtonTapped() {
        if hasUnsavedChanges {
            showSaveDiscardPrompt()
        } else {
            dismissAction?()
        }
    }
    
    private func showSaveDiscardPrompt() {
        let alert = UIAlertController(title: "Unsaved Changes", message: "You have unsaved changes. Do you want to save them before closing?", preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            self?.saveByteEdits()
            self?.dismissAction?()
        })
        
        alert.addAction(UIAlertAction(title: "Discard", style: .destructive) { [weak self] _ in
            self?.dismissAction?()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - View Mode
    @objc private func viewModeChanged(_ sender: UISegmentedControl) {
        currentViewMode = ViewMode(rawValue: sender.selectedSegmentIndex) ?? .byte
        displayHexData()
    }
    
    // MARK: - Data Loading
    private func loadDataChunk() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            showError("File does not exist.")
            return
        }
        
        guard let fileHandle = try? FileHandle(forReadingFrom: fileURL) else {
            showError("Could not open file for reading.")
            return
        }
        
        do {
            try fileHandle.seek(toOffset: UInt64(currentOffset))
            
            fileData = fileHandle.readData(ofLength: min(maxDisplayBytes, fileSize - currentOffset))
            
            try fileHandle.close()
            
            updateNavigationState()
            
            displayHexData()
            
            resetSearch()
        } catch {
            showError("Error reading file: \(error.localizedDescription)")
        }
    }
    
    private func updateNavigationState() {  
        let endOffset = min(currentOffset + maxDisplayBytes, fileSize)
        let totalPages = (fileSize + maxDisplayBytes - 1) / maxDisplayBytes
        let currentPage = (currentOffset / maxDisplayBytes) + 1
        
        if fileSize > maxDisplayBytes {
            title = "\(fileURL.lastPathComponent) (\(currentPage)/\(totalPages))"
        } else {
            title = fileURL.lastPathComponent
        }
        
        if let prevButton = navigationItem.rightBarButtonItems?.first(where: { ($0.image?.description ?? "").contains("chevron.left") }) {
            prevButton.isEnabled = currentOffset > 0
        }
        
        if let nextButton = navigationItem.rightBarButtonItems?.first(where: { ($0.image?.description ?? "").contains("chevron.right") }) {
            nextButton.isEnabled = currentOffset + maxDisplayBytes < fileSize
        }
    }
    
    // MARK: - Hex Display
    private func displayHexData() {
        switch currentViewMode {
        case .byte:
            displayByteView()
        case .string:
            displayStringView()
        }
    }
    
    private func displayByteView() {
        let attributedString = NSMutableAttributedString()
        
        var lineHex = ""
        var lineAscii = ""
        var address = currentOffset
        
        hexToAsciiMapping.removeAll()
        asciiToHexMapping.removeAll()
        
        for (index, byte) in fileData.enumerated() {
            if index % 8 == 0 {
                if index > 0 {
                    let lineStart = attributedString.length
                    
                    let hexPart = NSAttributedString(string: lineHex, attributes: [.foregroundColor: hexColor, .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
                    attributedString.append(hexPart)
                    
                    let spacer = NSAttributedString(string: "  ", attributes: [.foregroundColor: UIColor.lightGray, .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
                    attributedString.append(spacer)
                    
                    let asciiPart = NSAttributedString(string: lineAscii, attributes: [.foregroundColor: asciiColor, .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)])
                    attributedString.append(asciiPart)
                    
                    attributedString.append(NSAttributedString(string: "\n"))
                    
                    lineHex = ""
                    lineAscii = ""
                }
                
                let addressString = NSAttributedString(
                    string: String(format: "%08X  ", address),
                    attributes: [.foregroundColor: addressColor, .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
                )
                attributedString.append(addressString)
                
                address += 8
            }
            
            let currentPosition = attributedString.length
            let asciiPartOffset = (8 * 3) + 2
            
            let hexStart = currentPosition + lineHex.count
            
            lineHex += String(format: "%02X ", byte)
            
            let asciiIndex = lineAscii.count
            
            let asciiChar = (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : "."
            lineAscii += String(asciiChar)
            
            // Define ranges for mapping
            let hexRange = NSRange(location: hexStart, length: 2) // Just the hex value, not the space
            
            hexToAsciiMapping[hexRange] = NSRange(location: 0, length: 0)  
            asciiToHexMapping[NSRange(location: 0, length: 0)] = hexRange   
            
            // Store the byte index information for later mapping
            if index % 8 == 7 || index == fileData.count - 1 {
                // This is the last byte in a line or the last byte in the file
                // Map all bytes in this line now that we know the positions
                mapHexToAsciiRanges(attributedString.length, lineHex: lineHex, lineAscii: lineAscii)
            }
        }
        
        if !lineHex.isEmpty {
            let lastLineStart = attributedString.length
            
            let bytesInLastLine = fileData.count % 8
            let padding = bytesInLastLine == 0 ? "" : String(repeating: "   ", count: 8 - bytesInLastLine)
            
            let hexPart = NSAttributedString(string: lineHex, attributes: [.foregroundColor: hexColor])
            attributedString.append(hexPart)
            
            let paddingPart = NSAttributedString(string: padding, attributes: [.foregroundColor: UIColor.clear])
            attributedString.append(paddingPart)
            
            let spacer = NSAttributedString(string: "  ", attributes: [.foregroundColor: UIColor.lightGray])
            attributedString.append(spacer)
            
            let asciiPart = NSAttributedString(string: lineAscii, attributes: [.foregroundColor: asciiColor])
            attributedString.append(asciiPart)
            
            if bytesInLastLine > 0 && bytesInLastLine < 8 {
                mapHexToAsciiRanges(lastLineStart, lineHex: lineHex, lineAscii: lineAscii)
            }
        }
        
        textView.attributedText = attributedString
    }
    
    private func mapHexToAsciiRanges(_ lineStart: Int, lineHex: String, lineAscii: String) {
        let addressOffset = 10
        let hexAsciiSpacing = 2
        
        let asciiStartOffset = lineStart + addressOffset + lineHex.count + hexAsciiSpacing
        
        let hexComponents = lineHex.split(separator: " ")
        
        for (index, _) in hexComponents.enumerated() {
            if index >= lineAscii.count { break }
            
            let hexPos = lineStart + addressOffset + (index * 3)
            let hexRange = NSRange(location: hexPos, length: 2)

            let asciiPos = asciiStartOffset + index
            let asciiRange = NSRange(location: asciiPos, length: 1)
            
            hexToAsciiMapping[hexRange] = asciiRange
            asciiToHexMapping[asciiRange] = hexRange
        }
    }
    
    private func displayStringView() {
        let attributedString = NSMutableAttributedString()
        
        let headerString = NSAttributedString(
            string: "String representation:\n\n",
            attributes: [.foregroundColor: UIColor.secondaryLabel, .font: UIFont.systemFont(ofSize: 14, weight: .medium)]
        )
        attributedString.append(headerString)
        
        var stringRepresentation = ""
        for byte in fileData {
            if byte >= 32 && byte <= 126 {
                stringRepresentation.append(Character(UnicodeScalar(byte)))
            } else if byte == 10 || byte == 13 {
                stringRepresentation.append("\n")
            } else {
                stringRepresentation.append(".")
            }
        }
        
        let contentString = NSAttributedString(
            string: stringRepresentation,
            attributes: [.foregroundColor: UIColor.label, .font: UIFont.systemFont(ofSize: 14)]
        )
        attributedString.append(contentString)
        
        textView.attributedText = attributedString
    }
    
    // MARK: - Edit Actions
    @objc private func toggleEditing() {
        if isEditingMode {
            disableEditing()
        } else {
            enableEditing()
        }
    }
    
    private func enableEditing() {
        isEditingMode = true
        
        if currentViewMode != .byte {
            currentViewMode = .byte
            viewModeControl.selectedSegmentIndex = currentViewMode.rawValue
            displayHexData()
        }
        
        viewModeControl.isEnabled = false
        viewModeControl.alpha = 0.5
        
        editButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .normal)
        editButton.tintColor = .white
        
        textView.isEditable = true
        
        searchBar.isUserInteractionEnabled = false
        searchBar.alpha = 0.5
    }
    
    private func disableEditing() {
        isEditingMode = false
        
        if hasUnsavedChanges {
            saveByteEdits()
        }

        viewModeControl.isEnabled = true
        viewModeControl.alpha = 1.0
        
        editButton.setImage(UIImage(systemName: "pencil.circle.fill"), for: .normal)
        editButton.tintColor = .white
        
        textView.isEditable = false
        
        searchBar.isUserInteractionEnabled = true
        searchBar.alpha = 1.0
    }
    
    // MARK: - Search Functionality
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        performSearch()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.text = ""
        resetSearch()
    }
    
    private func resetSearch() {
        searchMatches = []
        currentMatchIndex = -1
    }
    
    private func performSearch() {
        guard let searchText = searchBar.text, !searchText.isEmpty else {
            resetSearch()
            return
        }
        
        resetSearch()
        
        let text = textView.text ?? ""
        
        var searchRanges: [NSRange] = []
        var searchRange = NSRange(location: 0, length: text.count)
        
        while searchRange.location < text.count {
            let foundRange = (text as NSString).range(of: searchText, options: .caseInsensitive, range: searchRange)
            if foundRange.location != NSNotFound {
                searchRanges.append(foundRange)
                searchRange.location = foundRange.location + foundRange.length
                searchRange.length = text.count - searchRange.location
            } else {
                break
            }
        }
        
        searchMatches = searchRanges
        
        if !searchMatches.isEmpty {
            currentMatchIndex = 0
            highlightCurrentMatch()
        } else {
            showMessage("No matches found", title: "Search")
        }
    }
    
    @objc private func nextSearchMatch() {
        if searchMatches.isEmpty { return }
        
        currentMatchIndex = (currentMatchIndex + 1) % searchMatches.count
        highlightCurrentMatch()
    }
    
    @objc private func previousSearchMatch() {
        if searchMatches.isEmpty { return }
        
        currentMatchIndex = (currentMatchIndex - 1 + searchMatches.count) % searchMatches.count
        highlightCurrentMatch()
    }
    
    private func highlightCurrentMatch() {
        guard currentMatchIndex >= 0 && currentMatchIndex < searchMatches.count else { return }
        
        let range = searchMatches[currentMatchIndex]
        
        if let attributedText = textView.attributedText {
            let mutableAttributedText = NSMutableAttributedString(attributedString: attributedText)
            
            displayHexData()
            
            mutableAttributedText.addAttribute(.backgroundColor, value: UIColor.yellow, range: range)
            
            textView.attributedText = mutableAttributedText
            
            textView.scrollRangeToVisible(range)
        }
        
        title = "\(currentMatchIndex + 1) of \(searchMatches.count) - \(fileURL.lastPathComponent)"
    }
    
    // MARK: - Helper Methods
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showMessage(_ message: String, title: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Text View Delegate
    func textViewDidChange(_ textView: UITextView) {
        hasUnsavedChanges = true
    }
    
    // MARK: - Saving
    private func saveByteEdits() {
        if currentViewMode == .byte {
            let lines = textView.text.components(separatedBy: .newlines)
            var newChunkData = Data()
            
            for line in lines {
                if line.isEmpty { continue }
                
                if line.count < 10 { continue }
                let hexPart = line.dropFirst(10)
                
                let hexValues = hexPart.components(separatedBy: " ")
                
                for hexValue in hexValues {
                    if hexValue.isEmpty || hexValue.count != 2 { continue }

                    if let byteValue = UInt8(hexValue, radix: 16) {
                        newChunkData.append(byteValue)
                    }
                }
            }
            
            do {
                guard let fileHandle = try? FileHandle(forWritingTo: fileURL) else {
                    showError("Could not open file for writing.")
                    return
                }
                
                try fileHandle.seek(toOffset: UInt64(currentOffset))
                fileHandle.write(newChunkData)
                
                try fileHandle.close()
                
                fileData = newChunkData
                hasUnsavedChanges = false
                
                showMessage("File saved successfully.", title: "Success")
            } catch {
                showError("Failed to save file: \(error.localizedDescription)")
            }
        }
    }
} 
