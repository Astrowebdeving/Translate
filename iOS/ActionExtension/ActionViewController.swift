//
//  ActionViewController.swift
//  TranslateLocal Action Extension
//
//  Allows users to translate selected text from Safari and other apps
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers

class ActionViewController: UIViewController {
    
    // MARK: - UI Elements
    
    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var headerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Translate"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        return label
    }()
    
    private lazy var doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Done", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var languageStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var sourceLanguageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Auto", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = .secondarySystemFill
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return button
    }()
    
    private lazy var arrowLabel: UILabel = {
        let label = UILabel()
        label.text = "→"
        label.font = .systemFont(ofSize: 16)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private lazy var targetLanguageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Japanese", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .medium)
        button.backgroundColor = .secondarySystemFill
        button.layer.cornerRadius = 8
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        button.showsMenuAsPrimaryAction = true
        button.menu = createLanguageMenu()
        return button
    }()
    
    private lazy var sourceTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.isEditable = false
        tv.backgroundColor = .secondarySystemBackground
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private lazy var translatedTextView: UITextView = {
        let tv = UITextView()
        tv.font = .systemFont(ofSize: 16)
        tv.isEditable = false
        tv.backgroundColor = UIColor.systemIndigo.withAlphaComponent(0.1)
        tv.layer.cornerRadius = 12
        tv.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private lazy var copyButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "doc.on.doc"), for: .normal)
        button.setTitle(" Copy", for: .normal)
        button.addTarget(self, action: #selector(copyTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // MARK: - Properties
    
    private var sourceText: String = ""
    private var targetLanguage: String = "ja"
    
    private let languageOptions = [
        ("ja", "Japanese", "日本語"),
        ("zh", "Chinese", "中文"),
        ("ko", "Korean", "한국어"),
        ("es", "Spanish", "Español"),
        ("fr", "French", "Français"),
        ("de", "German", "Deutsch"),
        ("en", "English", "English"),
    ]
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSelectedText()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        view.addSubview(containerView)
        
        headerStack.addArrangedSubview(UIView()) // Spacer
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(doneButton)
        
        languageStack.addArrangedSubview(sourceLanguageButton)
        languageStack.addArrangedSubview(arrowLabel)
        languageStack.addArrangedSubview(targetLanguageButton)
        languageStack.addArrangedSubview(UIView()) // Flexible spacer
        
        containerView.addSubview(headerStack)
        containerView.addSubview(languageStack)
        containerView.addSubview(sourceTextView)
        containerView.addSubview(translatedTextView)
        containerView.addSubview(activityIndicator)
        containerView.addSubview(copyButton)
        
        NSLayoutConstraint.activate([
            // Container
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            
            // Header
            headerStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Language selector
            languageStack.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
            languageStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            languageStack.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            // Source text
            sourceTextView.topAnchor.constraint(equalTo: languageStack.bottomAnchor, constant: 16),
            sourceTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            sourceTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            sourceTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            sourceTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
            
            // Translated text
            translatedTextView.topAnchor.constraint(equalTo: sourceTextView.bottomAnchor, constant: 12),
            translatedTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            translatedTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            translatedTextView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60),
            translatedTextView.heightAnchor.constraint(lessThanOrEqualToConstant: 150),
            
            // Activity indicator
            activityIndicator.centerXAnchor.constraint(equalTo: translatedTextView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: translatedTextView.centerYAnchor),
            
            // Copy button
            copyButton.topAnchor.constraint(equalTo: translatedTextView.bottomAnchor, constant: 12),
            copyButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            copyButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -16),
        ])
    }
    
    private func createLanguageMenu() -> UIMenu {
        let actions = languageOptions.map { (code, name, native) in
            UIAction(title: "\(name) (\(native))", state: code == targetLanguage ? .on : .off) { [weak self] _ in
                self?.targetLanguage = code
                self?.targetLanguageButton.setTitle(name, for: .normal)
                self?.translateText()
            }
        }
        return UIMenu(title: "Target Language", children: actions)
    }
    
    // MARK: - Content Loading
    
    private func loadSelectedText() {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            return
        }
        
        for item in extensionItems {
            guard let attachments = item.attachments else { continue }
            
            for attachment in attachments {
                // Load text
                if attachment.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let text = data as? String {
                                self?.handleText(text)
                            }
                        }
                    }
                    return
                }
                
                // Load plain text
                if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] data, error in
                        DispatchQueue.main.async {
                            if let text = data as? String {
                                self?.handleText(text)
                            }
                        }
                    }
                    return
                }
            }
        }
    }
    
    private func handleText(_ text: String) {
        sourceText = text
        sourceTextView.text = text
        translateText()
    }
    
    // MARK: - Translation
    
    private func translateText() {
        guard !sourceText.isEmpty else { return }
        
        activityIndicator.startAnimating()
        translatedTextView.text = ""
        
        // In a real implementation, this would:
        // 1. Use App Groups to access shared Core ML models
        // 2. Or use a shared framework containing the translation logic
        
        // Simulating translation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            
            self.activityIndicator.stopAnimating()
            
            // Placeholder - would be actual translation
            let placeholder = self.generatePlaceholderTranslation()
            self.translatedTextView.text = placeholder
        }
    }
    
    private func generatePlaceholderTranslation() -> String {
        // This is a placeholder - real implementation would use Core ML
        switch targetLanguage {
        case "ja":
            return "[Japanese translation would appear here]\n翻訳されたテキスト"
        case "zh":
            return "[Chinese translation would appear here]\n翻译文本"
        case "ko":
            return "[Korean translation would appear here]\n번역된 텍스트"
        case "es":
            return "[Spanish translation would appear here]\nTexto traducido"
        case "fr":
            return "[French translation would appear here]\nTexte traduit"
        case "de":
            return "[German translation would appear here]\nÜbersetzter Text"
        default:
            return "[Translation would appear here]"
        }
    }
    
    // MARK: - Actions
    
    @objc private func doneTapped() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
    
    @objc private func copyTapped() {
        UIPasteboard.general.string = translatedTextView.text
        
        // Show feedback
        let originalTitle = copyButton.title(for: .normal)
        copyButton.setTitle(" Copied!", for: .normal)
        copyButton.isEnabled = false
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.copyButton.setTitle(originalTitle, for: .normal)
            self?.copyButton.isEnabled = true
        }
    }
}
