//
//  ViewController.swift
//  Twig
//
//  Created by Luka Kerr on 25/4/18.
//  Copyright © 2018 Luka Kerr. All rights reserved.
//

import Cocoa
import Highlightr
import Down

class MarkdownViewController: NSViewController, NSTextViewDelegate {

  @IBOutlet var markdownTextView: NSTextView!
  @IBOutlet weak var transparentView: NSVisualEffectView!
  
  private let highlightr = Highlightr()!
  private var debouncedGeneratePreview: Debouncer!
  
  // Cocoa binding for text inside markdownTextView
  @objc var attributedMarkdownTextInput: NSAttributedString {
    get {
      return NSAttributedString(string: markdownTextView.string)
    }
    set {
      syntaxHighlight(newValue.string)
      debouncedGeneratePreview.call()
      setWordCount()
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Setup notification observer for theme change
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(self.themeChanged),
      name: NSNotification.Name(rawValue: "preferencesChanged"),
      object: nil
    )
    
    debouncedGeneratePreview = Debouncer(delay: 0.2) {
      self.generatePreview(self.markdownTextView.string)
    }
    
    if let preview = getSplitViewController()?.splitViewItems.last {
      preview.isCollapsed = !preferences.showPreviewOnStartup
    }
    
    markdownTextView.delegate = self
    markdownTextView.font = preferences.font
    markdownTextView.insertionPointColor = .gray
    markdownTextView.textContainerInset = NSSize(width: 10.0, height: 10.0)
  }
  
  override func viewDidAppear() {
    highlightr.setTheme(to: theme.syntax)
    setBackgroundColor()
    generatePreview(markdownTextView.string)
  }
  
  override var acceptsFirstResponder: Bool {
    return true
  }
  
  @IBAction func togglePreview(sender: NSMenuItem) {
    if let preview = getSplitViewController()?.splitViewItems.last {
      preview.collapseBehavior = .preferResizingSplitViewWithFixedSiblings
      preview.animator().isCollapsed = !preview.isCollapsed
    }
  }
  
  @IBAction func exportPDF(sender: NSMenuItem) {
    if let pvc = getPreviewViewController() {
      Exporter.exportPDF(from: pvc.webPreview)
    }
  }
  
  @IBAction func exportHTML(sender: NSMenuItem) {
    if let pvc = getPreviewViewController() {
      Exporter.exportHTML(from: pvc.webPreview)
    }
  }
  
  // Syntax highlight the given markdown string and insert into text view
  private func syntaxHighlight(_ string: String) {
    self.highlightr.setTheme(to: theme.syntax)
    
    DispatchQueue.global(qos: .userInitiated).async {
      let highlightedCode = self.highlightr.highlight(string, as: "markdown")
      
      if let syntaxHighlighted = highlightedCode {
        let code = NSMutableAttributedString(attributedString: syntaxHighlighted)
        code.withFont(preferences.font)

        DispatchQueue.main.async {
          let cursorPosition = self.markdownTextView.selectedRanges[0].rangeValue.location
          self.markdownTextView.textStorage?.beginEditing()
          self.markdownTextView.textStorage?.setAttributedString(code)
          self.markdownTextView.textStorage?.endEditing()
          self.markdownTextView.setSelectedRange(NSMakeRange(cursorPosition, 0))
        }
      }
    }
  }
  
  private func generatePreview(_ string: String) {
    if let svc = self.getSplitViewController(),
      let preview = svc.splitViewItems.last {
      let previewViewController = preview.viewController as? PreviewViewController
      
      if preview.isCollapsed { return }
        
      DispatchQueue.global(qos: .userInitiated).async {
        if let parsed = try? Down(markdownString: string).toHTML() {
          DispatchQueue.main.async {
            previewViewController?.captureScroll() {
              previewViewController?.webPreview.loadHTMLString(html.getHTML(with: parsed), baseURL: nil)
            }
          }
        }
      }
    }
  }
  
  // On theme change, update window appearance and reparse with possible new syntax
  @objc private func themeChanged() {
    syntaxHighlight(markdownTextView.string)
    setBackgroundColor()
    generatePreview(markdownTextView.string)
  }
  
  private func setBackgroundColor() {
    guard let color = highlightr.theme.themeBackgroundColor else {
      return
    }
    
    theme.background = color.hex
    
    if color.isDark {
      transparentView.material = .dark
      theme.code = color.lighter.hex
      theme.text = "#FFF"
      self.view.window?.appearance = NSAppearance(named: .vibrantDark)
    } else {
      transparentView.material = .light
      theme.code = color.darker.hex
      theme.text = "#000"
      self.view.window?.appearance = NSAppearance(named: .vibrantLight)
    }
    self.view.window?.backgroundColor = color
  }
  
  private func setWordCount() {
    let wordCountView = self.view.window?.titlebarAccessoryViewControllers.first?.view.subviews.first as? NSTextField
    guard let wordCount = self.markdownTextView.textStorage?.words.count else { return }
    
    var countString = String(describing: wordCount) + " word"
    
    if wordCount > 1 {
      countString += "s"
    } else if wordCount < 1 {
      countString = ""
    }
    wordCountView?.stringValue = countString
  }
  
  private func getSplitViewController() -> NSSplitViewController? {
    return self.parent as? NSSplitViewController
  }
  
  private func getPreviewViewController() -> PreviewViewController? {
    return self.getSplitViewController()?.splitViewItems.last?.viewController as? PreviewViewController
  }

}
