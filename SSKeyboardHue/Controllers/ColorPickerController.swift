//
//  ColorPickerController.swift
//  SSKeyboardHue
//
//  Created by Erik Bautista on 10/3/19.
//  Copyright © 2019 ErrorErrorError. All rights reserved.
//

import Cocoa

class ColorPickerController: NSViewController {
    var colorBackground = RGB(r: 30, g: 30, b: 30) // Dark Mode
    var textViewBackground = RGB(r: 52, g: 52, b: 52)
    @IBOutlet weak var colorWheelView: ColorWheelView!
    @IBOutlet weak var colorLabel: NSTextField!
    @IBOutlet weak var brightnessSlider: NSSlider!
    @IBOutlet weak var currentKeyMode: NSPopUpButtonCell!
    @IBOutlet weak var presetsTableView: NSTableView!
    @IBOutlet weak var presetDeleteButton: NSButton!
    @IBOutlet weak var presetsLabel: NSTextField!
    var hasResizeReactiveViews = false
    var filesList: [URL] = []
    var selectedFile: URL! {
        didSet {
            if (self.selectedFile != nil) {
                setKeyboardColorFromFile()
            }
        }
    }
    
    var hasSetExtended = false
    // Reactive View
    var activeColor: CustomColorWell!
    var restColor: CustomColorWell!
    var activeText: NSTextView!
    var restText: NSTextView!
    var speedSlider: NSSlider!
    var speedText: NSTextView!
    var speedBox: NSTextView!
    var presetsTableRect: NSRect!
    
    var originalFrame: NSRect!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        colorWheelView.delegate = self
        ColorController.shared.colorPicker = self
        colorLabel.roundCorners(cornerRadius: 10.0)
        colorLabel.layer?.backgroundColor = textViewBackground.nsColor.cgColor
        colorLabel.isBezeled = false
        
        currentKeyMode.addItem(withTitle: "Steady")
        currentKeyMode.addItem(withTitle: "ColorShift")
        currentKeyMode.addItem(withTitle: "Breathing")
        currentKeyMode.addItem(withTitle: "Reactive")
        currentKeyMode.addItem(withTitle: "Disabled")
        setUpReactiveViews()
        checkForPresets()
        presetDeleteButton.isEnabled = false
    }
    
    func checkForPresets() {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let docURL = URL(string: documentsDirectory)!
        let directoryPath = docURL.appendingPathComponent("presets")

        if FileManager.default.fileExists(atPath: directoryPath.absoluteString) {
            filesList = contentsOf(folder: directoryPath)
            self.presetsTableView.reloadData()
        }

    }
    
    func contentsOf(folder: URL) -> [URL] {
    
      let fileManager = FileManager.default
      do {
        let contents = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: .none, options: .skipsHiddenFiles)
        return contents
      } catch {
        return []
      }
    }

    private func setKeyboardColorFromFile() {
        let data = try? Data(contentsOf: selectedFile)
        let array = [UInt8](data!)
        
        if (KeyboardManager.shared.keyboardManager.getKeyboardModel() == PerKeyGS65 || KeyboardManager.shared.keyboardManager.getKeyboardModel() == PerKey) {
            for i in 0...(array.count/12) - 1 {
                let currentIndex  = i * 12
                let region = array[currentIndex]
                let keycode = array[currentIndex + 1]
                let keyViewArray = KeyboardManager.shared.keyboardView.subviews
                let mode = array[currentIndex + 11]
                let colorMain = RGB(r: array[currentIndex + 2], g: array[currentIndex + 3], b: array[currentIndex + 4])
                let colorActive = RGB(r: array[currentIndex + 5], g: array[currentIndex + 6], b: array[currentIndex + 7])
                let duration = UInt16(array[currentIndex + 9]) << 8 | UInt16(array[currentIndex + 8])
                let foundKeyArray = keyViewArray.filter {(findKey) -> Bool in
                    let castKey = findKey as! KeysView
                    return castKey.keyModel.getRegion() == region && castKey.keyModel.getKeyCode() == keycode
                }
                let keyFound = foundKeyArray[0] as! KeysView
                
                if (mode == 0x01) {
                    keyFound.setSteady(newColor: colorMain.nsColor)
                } else if (mode == 0x08) {
                    keyFound.setReactive(active: colorActive.nsColor, rest: colorMain.nsColor, speed: duration)
                } else if (mode == 0x03){
                    keyFound.setDisabled()
                } else {
                    /// Todo - Breathing and Waves
                }
                
            }
        } else {
            /// TODO - Implement ThreeRegion
        }
        
        KeyboardManager.shared.keyboardView.updateKeys(forceRefresh: true)
    }
    
    private func setUpReactiveViews() {
        activeColor = CustomColorWell(frame: NSRect(origin: CGPoint(x: 26, y: 360), size: CGSize(width: 25, height: 25)))
        activeColor.isBordered = false
        activeColor.color = RGB(r: 0xff, g: 0x00, b: 0x00).nsColor
        activeColor.roundCorners(cornerRadius: 5.0)
        activeColor.isHidden = true
        
        activeText = NSTextView(frame: NSRect(origin: CGPoint(x: 56, y: 350), size: CGSize(width: 45, height: 25)))
        activeText.isHidden = true
        activeText.string = "Active"
        activeText.isEditable = false
        activeText.textColor = NSColor.white
        
        restColor = CustomColorWell(frame: NSRect(origin: CGPoint(x: 116, y: 360), size: CGSize(width: 25, height: 25)))
        restColor.isBordered = false
        restColor.color = RGB(r: 0x00, g: 0x00, b: 0x00).nsColor
        restColor.roundCorners(cornerRadius: 5.0)
        restColor.isHidden = true
        
        restText = NSTextView(frame: NSRect(origin: CGPoint(x: 146, y: 350), size: CGSize(width: 35, height: 25)))
        restText.isHidden = true
        restText.string = "Rest"
        restText.isEditable = false
        restText.textColor = NSColor.white
        
        speedSlider = NSSlider(frame: NSRect(x: 25, y: 310, width: 150, height: 20))
        speedSlider.isHidden = true
        speedSlider.minValue = 100
        speedSlider.maxValue = 1000
        speedSlider.cell!.target = self
        speedSlider.cell!.action = #selector(setSpeed(_:))
        speedSlider.intValue = 300

        speedText = NSTextView(frame: NSRect(x:23, y: 340, width: 55, height: 10))
        speedText.isHidden = true
        speedText.string = "Speed"
        speedText.isEditable = false
        speedText.textColor = NSColor.white
        
        speedBox = NSTextView(frame: NSRect(x: 180, y: 317, width: 55, height: 10))
        speedBox.isHidden = true
        var trimmed = speedSlider.intValue.description
        trimmed.removeLast(2)
        speedBox.string = trimmed + "s"
        speedBox.isEditable = false
        speedBox.textColor = NSColor.white

        view.addSubview(activeText)
        view.addSubview(restText)
        view.addSubview(activeColor)
        view.addSubview(restColor)
        view.addSubview(speedSlider)
        view.addSubview(speedText)
        view.addSubview(speedBox)
    }
    private func showReactive(show: Bool) {
        let isHidden = (show) ? false : true
        activeColor.isHidden = isHidden
        restColor.isHidden = isHidden
        activeText.isHidden = isHidden
        restText.isHidden = isHidden
        speedSlider.isHidden = isHidden
        speedText.isHidden = isHidden
        speedBox.isHidden = isHidden
    }
    
    @IBAction func setKeyMode(_ sender: NSPopUpButtonCell) {
        if (presetsTableRect == nil) {
            presetsTableRect = presetsTableView.superview?.superview!.frame
        }
        
        if (sender.titleOfSelectedItem == "Reactive") {
            showReactive(show: true)
            presetsTableView.superview?.superview!.frame = NSRect(x: (presetsTableView.superview?.superview!.frame.origin.x)!, y: (presetsTableView.superview?.superview!.frame.origin.y)!, width: presetsTableRect.width, height: presetsTableRect.height - 80)
            if (!hasResizeReactiveViews) {
                presetsLabel.frame.origin.y -= 80
                presetDeleteButton.frame.origin.y -= 80
                hasResizeReactiveViews = true
            }
        } else {
            if (hasResizeReactiveViews) {
                presetsLabel.frame.origin.y += 80
                presetDeleteButton.frame.origin.y += 80
                hasResizeReactiveViews = false
            }
            showReactive(show: false)
            presetsTableView.superview?.superview!.frame = presetsTableRect
        }

        updateKeys(shouldUpdateKeys: true)
    }

    @IBAction  func setSpeed(_ sender: NSSlider) {
        let shouldSendKeyCommand = (NSApplication.shared.currentEvent?.type == NSEvent.EventType.leftMouseUp) ? true : false
        updateKeys(shouldUpdateKeys: shouldSendKeyCommand)
        var trimmed = speedSlider.intValue.description
        trimmed.removeLast(2)
        speedBox.string = trimmed + "s"
    }
    
    override func viewWillAppear() {
        view.layer?.backgroundColor = colorBackground.nsColor.cgColor
        view.roundCorners(cornerRadius: 10.0)
        ColorController.shared.setColor(NSColor.white.usingColorSpace(.genericRGB)!)
    }
    
    @IBAction func setBrightness(_ sender: NSSlider) {
        ColorController.shared.brightness = CGFloat((sender.maxValue-sender.doubleValue) / sender.maxValue)
        updateColorWheel(redrawCrosshair: false)
        updateLabel()
        let shouldSendKeyCommand = (NSApplication.shared.currentEvent?.type == NSEvent.EventType.leftMouseUp) ? true : false
        updateKeys(shouldUpdateKeys: shouldSendKeyCommand)
    }
    
    @IBAction func setColor(_ sender: NSTextField) {
        let color = NSColor(hexString: sender.stringValue)
        ColorController.shared.setColor(color)
        view.window?.makeFirstResponder(view)
        updateKeys(shouldUpdateKeys: true)
    }
    
    func updateColorWheel(redrawCrosshair: Bool = true) {
        colorWheelView.setColor(ColorController.shared.selectedColor, redrawCrosshair)
    }
    
    func updateLabel() {
        colorLabel.backgroundColor = ColorController.shared.selectedColor
        colorLabel.stringValue = "#"+ColorController.shared.selectedColor.rgbHexString
    }

    func updateSlider() {
        guard let sliderCell = brightnessSlider.cell as? GradientSliderCell else { fatalError() }
        sliderCell.colorA = ColorController.shared.masterColor
        brightnessSlider.drawCell(sliderCell)
        brightnessSlider.doubleValue = brightnessSlider.maxValue - (Double(ColorController.shared.brightness) *
            brightnessSlider.maxValue)
    }
    
    func updateKeys(shouldUpdateKeys: Bool) {
        if (KeyboardManager.shared.keyboardManager.getKeyboardModel() != ThreeRegion) {
            if (currentKeyMode.titleOfSelectedItem == "Steady") {
                for key in KeyboardManager.shared.keysSelected! {
                    (key as! KeysView).setSteady(newColor: ColorController.shared.selectedColor)
                }
            } else if (currentKeyMode.titleOfSelectedItem == "Reactive") {
                //Updates the reactiveBoxColor
                for selected in ColorController.shared.reactionBoxColors! {
                    (selected as! CustomColorWell).color = ColorController.shared.selectedColor
                }
                
                for key in KeyboardManager.shared.keysSelected! {
                    (key as! KeysView).setReactive(active: activeColor.color, rest: restColor.color, speed: UInt16(speedSlider.intValue))
                }
            } else if (currentKeyMode.titleOfSelectedItem == "Disabled") {
                for key in KeyboardManager.shared.keysSelected! {
                    (key as! KeysView).setDisabled()
                }
            }
        } else {
            // TODO - Three Region Keyboard
        }
        
        // Will only set color when the mouse is up
        if (shouldUpdateKeys) {
            // Will notify for keyboard GS65 and other PerKey to update the keys once mouse is up
            KeyboardManager.shared.keyboardView.updateKeys()
        }
    }
    
    
    @IBAction func deletePreset(_ sender: NSButton) {
        if (selectedFile != nil) {
            do {
                let fileManager = FileManager.default
                try fileManager.removeItem(at: selectedFile)
                selectedFile = nil
                checkForPresets()
                self.presetDeleteButton.isEnabled = false
            }
            catch let error as NSError {
                print("An error took place: \(error)")
            }
        }
    }
}

extension ColorPickerController: NSTableViewDataSource, NSTableViewDelegate {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return (filesList.count)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let file = filesList[row]
        
        guard let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "FileCell"), owner: self) as? NSTableCellView else { return nil }
        cell.textField?.stringValue = file.deletingPathExtension().lastPathComponent
        return cell
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if presetsTableView.selectedRow < 0 {
            selectedFile = nil
            presetDeleteButton.isEnabled = false
            return
        }
        presetDeleteButton.isEnabled = true
        selectedFile = filesList[presetsTableView.selectedRow]
    }
}

extension NSView {
    func roundCorners(cornerRadius: Double) {
        self.wantsLayer = true
        self.layer?.cornerRadius = CGFloat(cornerRadius)
        self.layer?.masksToBounds = true
    }
}

//This get's called if the colorWheelView's picker is moved.
extension ColorPickerController: ColorWheelViewDelegate {
    /// - postcondition: Mutates `ColorController.masterColor`
    func colorDidChange(_ newColor: NSColor, shouldUpdateKeyboard: Bool) {
        ColorController.shared.masterColor = newColor
        updateLabel()
        updateSlider()
        updateKeys(shouldUpdateKeys: shouldUpdateKeyboard)
    }
}

extension ColorPickerController: NSControlTextEditingDelegate {
    
    private func validateControlString(_ string: String) -> Bool {
        // String must be 6 characters and only contain numbers and letters 'a' through 'f',
        // or 7 characters if the first character is '#'
        switch string.count {
        case 6:
            guard string.containsOnlyHexCharacters else { return false }
            return true
        case 7:
            guard string.hasPrefix("#") else { return false }
            var trimmed = string; trimmed.remove(at: trimmed.startIndex)
            guard trimmed.containsOnlyHexCharacters else { return false }
            return true
        default:
            return false
        }
    }
    
    func control(_ control: NSControl, isValidObject obj: Any?) -> Bool {
        if control == colorLabel {
            guard let string = obj as? String else { return false }
            return validateControlString(string)
        }
        return false
    }
}

extension String {
    var containsOnlyHexCharacters: Bool {
        return !contains {
            switch $0 {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F", "a", "b",
                 "c", "d", "e", "f":
                return false
            default:
                return true
            }
        }
    }
}
