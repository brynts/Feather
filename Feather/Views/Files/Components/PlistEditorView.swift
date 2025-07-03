//
//  PlistEditorView.swift
//  Ksign
//
//  Created by Nagata Asami on 5/22/25.
//

import SwiftUI
import UIKit

struct PlistEditorView: UIViewControllerRepresentable {
    let fileURL: URL
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> PlistEditorViewController {
        let controller = PlistEditorViewController(fileURL: fileURL)
        controller.dismissAction = {
            self.presentationMode.wrappedValue.dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: PlistEditorViewController, context: Context) {
        // ts not happening
    }
}
class PlistEditorViewController: UIViewController {
    
    // MARK: - Properties
    private let fileURL: URL
    private var plistDict: [String: Any] = [:]
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var keys: [String] = []
    var dismissAction: (() -> Void)?
    
    private let customHeaderView = UIView()
    private let titleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let saveButton = UIButton(type: .system)
    private let addButton = UIButton(type: .system)
    
    private let headerView = UIView()
    private let rootLabel = UILabel()
    private let countLabel = UILabel()
    private let expandCollapseButton = UIButton(type: .system)
    private var isExpanded = true
    
    // MARK: - Initialization
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init(nibName: nil, bundle: nil)
        
        self.edgesForExtendedLayout = []
        self.extendedLayoutIncludesOpaqueBars = false
        self.modalPresentationCapturesStatusBarAppearance = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCustomHeader()
        setupViews()
        loadPlistData()
        
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
        
        saveButton.setImage(UIImage(systemName: "square.and.arrow.down.fill"), for: .normal)
        saveButton.tintColor = UIColor(named: "AccentColor")
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        customHeaderView.addSubview(saveButton)

        addButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        addButton.tintColor = UIColor(named: "AccentColor")
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        customHeaderView.addSubview(addButton)
        
        backButton.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        addButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            backButton.leadingAnchor.constraint(equalTo: customHeaderView.leadingAnchor, constant: 16),
            backButton.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: -8),
            backButton.widthAnchor.constraint(equalToConstant: 30),
            backButton.heightAnchor.constraint(equalToConstant: 30),
            
            titleLabel.centerXAnchor.constraint(equalTo: customHeaderView.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: -12),
            
            saveButton.trailingAnchor.constraint(equalTo: customHeaderView.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: -8),
            saveButton.widthAnchor.constraint(equalToConstant: 30),
            saveButton.heightAnchor.constraint(equalToConstant: 30),
            
            addButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -16),
            addButton.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor, constant: -8),
            addButton.widthAnchor.constraint(equalToConstant: 30),
            addButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupViews() {
        view.backgroundColor = .systemBackground
        
        setupHeaderView()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PlistKeyValueCell.self, forCellReuseIdentifier: "PlistCell")
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupHeaderView() {
        headerView.backgroundColor = .systemGroupedBackground
        view.addSubview(headerView)
        
        headerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: customHeaderView.bottomAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        rootLabel.text = "Root"
        rootLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        rootLabel.textColor = .label
        
        countLabel.textAlignment = .right
        countLabel.font = UIFont.systemFont(ofSize: 16)
        countLabel.textColor = .secondaryLabel
        
        expandCollapseButton.setImage(UIImage(systemName: "chevron.down"), for: .normal)
        expandCollapseButton.addTarget(self, action: #selector(toggleExpandCollapse), for: .touchUpInside)
        
        headerView.addSubview(expandCollapseButton)
        headerView.addSubview(rootLabel)
        headerView.addSubview(countLabel)
        
        expandCollapseButton.translatesAutoresizingMaskIntoConstraints = false
        rootLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            expandCollapseButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            expandCollapseButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            expandCollapseButton.widthAnchor.constraint(equalToConstant: 22),
            expandCollapseButton.heightAnchor.constraint(equalToConstant: 22),
            
            rootLabel.leadingAnchor.constraint(equalTo: expandCollapseButton.trailingAnchor, constant: 16),
            rootLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            countLabel.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            countLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor)
        ])
    }
    
    // MARK: - Actions
    @objc private func backButtonTapped() {
        dismissAction?()
    }
    
    @objc private func toggleExpandCollapse() {
        isExpanded = !isExpanded
        let imageName = isExpanded ? "chevron.down" : "chevron.right"
        expandCollapseButton.setImage(UIImage(systemName: imageName), for: .normal)
        tableView.reloadData()
    }
    
    // MARK: - Plist Operations
    private func loadPlistData() {
        do {
            let data = try Data(contentsOf: fileURL)
            
            var format = PropertyListSerialization.PropertyListFormat.xml
            if let dict = try PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: &format) as? [String: Any] {
                self.plistDict = dict
                self.keys = Array(dict.keys).sorted()
                countLabel.text = "Dictionary (\(keys.count) item\(keys.count == 1 ? "" : "s"))"
                tableView.reloadData()
            } else {
                showAlert(title: "Error", message: "The file is not a valid property list.")
            }
        } catch {
            showAlert(title: "Error", message: "Failed to load property list: \(error.localizedDescription)")
        }
    }
    
    private func savePlistData() {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plistDict, format: .xml, options: 0)
            try data.write(to: fileURL)
            showAlert(title: "Success", message: "Property list saved successfully.")
        } catch {
            showAlert(title: "Error", message: "Failed to save property list: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Action Handlers
    @objc private func saveButtonTapped() {
        savePlistData()
    }
    
    @objc private func addButtonTapped() {
        let alertController = UIAlertController(title: "Add New Entry", message: nil, preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Key"
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Value"
        }
        
        let addAction = UIAlertAction(title: "Add", style: .default) { [weak self] _ in
            guard let self = self,
                  let keyField = alertController.textFields?[0],
                  let valueField = alertController.textFields?[1],
                  let key = keyField.text, !key.isEmpty,
                  let valueText = valueField.text, !valueText.isEmpty else {
                return
            }
            
            // Add new key-value pair
            self.plistDict[key] = valueText
            self.keys = Array(self.plistDict.keys).sorted()
            self.countLabel.text = "Dictionary (\(self.keys.count) item\(self.keys.count == 1 ? "" : "s"))"
            self.tableView.reloadData()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(addAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    private func editValue(for key: String) {
        guard let value = plistDict[key] else { return }
        
        let alertController = UIAlertController(title: "Edit Value", message: "Key: \(key)", preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Value"
            textField.text = "\(value)"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let textField = alertController.textFields?.first,
                  let valueText = textField.text, !valueText.isEmpty else {
                return
            }
            
            // Attempt to convert the text to the correct type
            let newValue: Any
            
            if let originalValue = value as? Bool {
                newValue = (valueText.lowercased() == "true" || valueText == "1")
            } else if let originalValue = value as? Int {
                newValue = Int(valueText) ?? originalValue
            } else if let originalValue = value as? Double {
                newValue = Double(valueText) ?? originalValue
            } else {
                // Default to string
                newValue = valueText
            }
            
            self.plistDict[key] = newValue
            self.tableView.reloadData()
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        present(alertController, animated: true)
    }
    
    private func deleteKey(_ key: String) {
        plistDict.removeValue(forKey: key)
        if let index = keys.firstIndex(of: key) {
            keys.remove(at: index)
            countLabel.text = "Dictionary (\(keys.count) item\(keys.count == 1 ? "" : "s"))"
            tableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default))
        present(alertController, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension PlistEditorViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isExpanded ? keys.count : 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PlistCell", for: indexPath) as! PlistKeyValueCell
        
        let key = keys[indexPath.row]
        let value = plistDict[key]
        
        cell.configure(key: key, value: value)
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension PlistEditorViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let key = keys[indexPath.row]
        editValue(for: key)
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let key = keys[indexPath.row]
            deleteKey(key)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}

// MARK: - Custom Cell for Plist Key-Value Pairs
class PlistKeyValueCell: UITableViewCell {
    
    private let keyLabel = UILabel()
    private let typeLabel = UILabel()
    private let valueLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        keyLabel.font = UIFont.systemFont(ofSize: 17)
        keyLabel.textColor = .label
        
        typeLabel.font = UIFont.systemFont(ofSize: 15)
        typeLabel.textColor = .secondaryLabel
        typeLabel.textAlignment = .center
        
        valueLabel.font = UIFont.systemFont(ofSize: 16)
        valueLabel.textColor = .label
        valueLabel.textAlignment = .right
        valueLabel.numberOfLines = 1
        
        contentView.addSubview(keyLabel)
        contentView.addSubview(typeLabel)
        contentView.addSubview(valueLabel)
        
        keyLabel.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            keyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            keyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            keyLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.33),
            
            typeLabel.leadingAnchor.constraint(equalTo: keyLabel.trailingAnchor, constant: 8),
            typeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            typeLabel.widthAnchor.constraint(equalTo: contentView.widthAnchor, multiplier: 0.28),
            
            valueLabel.leadingAnchor.constraint(equalTo: typeLabel.trailingAnchor, constant: 8),
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    func configure(key: String, value: Any?) {
        keyLabel.text = key
        
        if let value = value {
            let valueString = "\(value)"
            valueLabel.text = valueString
            
            let typeString: String
            if value is String {
                typeString = "String"
            } else if value is Int {
                typeString = "Integer"
            } else if value is Double {
                typeString = "Number"
            } else if value is Bool {
                typeString = "Boolean"
            } else if value is [Any] {
                typeString = "Array"
            } else if value is [String: Any] {
                typeString = "Dictionary"
            } else if value is Data {
                typeString = "Data"
            } else if value is Date {
                typeString = "Date"
            } else {
                typeString = "Unknown"
            }
            
            typeLabel.text = typeString
        } else {
            valueLabel.text = "nil"
            typeLabel.text = "nil"
        }
    }
} 
