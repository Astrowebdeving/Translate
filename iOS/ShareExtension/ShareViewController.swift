//
//  ShareViewController.swift
//  TranslateLocal Share Extension
//
//  Allows users to share images/screenshots from other apps for translation
//

import UIKit
import Social
import MobileCoreServices
import UniformTypeIdentifiers

class ShareViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 20
        view.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "TranslateLocal"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var translateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Translate", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(translateTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .secondarySystemBackground
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private lazy var resultLabel: UILabel = {
        let label = UILabel()
        label.text = "Share an image to translate its text"
        label.font = .systemFont(ofSize: 15)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var languageSelector: UISegmentedControl = {
        let languages = ["EN→JA", "EN→ZH", "EN→ES", "EN→FR", "EN→DE"]
        let control = UISegmentedControl(items: languages)
        control.selectedSegmentIndex = 0
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()
    
    // MARK: - Properties
    
    private var sharedImage: UIImage?
    private var sharedText: String?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSharedContent()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        view.addSubview(containerView)
        containerView.addSubview(headerView)
        headerView.addSubview(titleLabel)
        headerView.addSubview(cancelButton)
        headerView.addSubview(translateButton)
        containerView.addSubview(languageSelector)
        containerView.addSubview(imageView)
        containerView.addSubview(resultLabel)
        containerView.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            containerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7),
            
            // Header
            headerView.topAnchor.constraint(equalTo: containerView.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 56),
            
            cancelButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            cancelButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            translateButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            translateButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            
            // Language selector
            languageSelector.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 16),
            languageSelector.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            languageSelector.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Image view
            imageView.topAnchor.constraint(equalTo: languageSelector.bottomAnchor, constant: 16),
            imageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            imageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalToConstant: 200),
            
            // Result label
            resultLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 16),
            resultLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            resultLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 16),
        ])
        
        // Add tap gesture to dismiss when tapping outside
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Content Loading
    
    private func loadSharedContent() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // Try to load image
                if attachment.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let url = data as? URL, let image = UIImage(contentsOfFile: url.path) {
                                self?.handleSharedImage(image)
                            } else if let image = data as? UIImage {
                                self?.handleSharedImage(image)
                            } else if let data = data as? Data, let image = UIImage(data: data) {
                                self?.handleSharedImage(image)
                            }
                        }
                    }
                    return
                }
                
                // Try to load text
                if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let text = data as? String {
                                self?.handleSharedText(text)
                            }
                        }
                    }
                    return
                }
                
                // Try URL (might be text content)
                if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let url = data as? URL {
                                self?.handleSharedURL(url)
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func handleSharedImage(_ image: UIImage) {
        sharedImage = image
        imageView.image = image
        resultLabel.text = "Tap Translate to extract and translate text"
    }
    
    private func handleSharedText(_ text: String) {
        sharedText = text
        imageView.isHidden = true
        resultLabel.text = text
        resultLabel.textColor = .label
    }
    
    private func handleSharedURL(_ url: URL) {
        // Could load webpage content for translation
        resultLabel.text = "URL sharing: \(url.absoluteString)"
    }
    
    // MARK: - Actions
    
    @objc private func cancelTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func translateTapped() {
        guard sharedImage != nil || sharedText != nil else {
            resultLabel.text = "No content to translate"
            return
        }
        
        activityIndicator.startAnimating()
        translateButton.isEnabled = false
        
        // In a real implementation, this would:
        // 1. Use App Groups to share the model with the main app
        // 2. Or use a shared framework for OCR and translation
        // 3. Process the image/text and show results
        
        // Simulating processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.activityIndicator.stopAnimating()
            self?.translateButton.isEnabled = true
            
            // Open main app with the content
            self?.openMainApp()
        }
    }
    
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        if !containerView.frame.contains(location) {
            cancelTapped()
        }
    }
    
    private func openMainApp() {
        // Create URL scheme to open main app
        // The main app would handle translatelocal://translate?...
        
        // For now, just show a message
        resultLabel.text = "Translation complete!\n\nOpen TranslateLocal app for full results."
        resultLabel.textColor = .systemGreen
        
        // Auto-dismiss after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
        }
    }
}
