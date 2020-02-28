//
//  UIViewController+ImagePicker.swift
//  StreamChat
//
//  Created by Alexey Bukhtin on 03/06/2019.
//  Copyright © 2019 Stream.io Inc. All rights reserved.
//

import UIKit
import Photos.PHPhotoLibrary
import RxSwift
import StreamChatCore

public class StreamPickersController {
    
    
    public static func presentImagePicker(vc: UIViewController,
                                          composerView: ComposerView,
                                          channel: Channel?,
                                          composerAddFileViewSourceType sourceType: ComposerAddFileView.SourceType,
                                          disposeBag: DisposeBag) {
        
        if composerView.imageUploaderItems.count > 0 || composerView.fileUploaderItems.count > 0 {
            vc.showAlertError("Sorry, only one file per message.")
            return
        }
        guard case .photo(let pickerSourceType) = sourceType else {
            return
        }
        
        
        self.showImagePicker(vc: vc, sourceType: pickerSourceType) { pickedImage, status in
            guard status == .authorized else {
                self.showImpagePickerAuthorizationStatusAlert(vc: vc, status)
                return
            }
            
            guard let channel = channel else {
                return
            }
            
            if let pickedImage = pickedImage, let uploaderItem = UploaderItem(channel: channel, pickedImage: pickedImage) {
                do {
                    try self.validateFile(uploaderItem)
                    composerView.addImageUploaderItem(uploaderItem)
                } catch {
                    vc.showAlertError(error.localizedDescription)
                }
            }
        }
    }
    
    public static func showDocument(vc: UIViewController, composerView: ComposerView, channel: Channel?, disposeBag: DisposeBag) {
        if  composerView.imageUploaderItems.count > 0 || composerView.fileUploaderItems.count > 0{
            vc.showAlertError("Sorry, only one file per message.")
            return
        }
        
        let documentPickerViewController = UIDocumentPickerViewController(documentTypes: [.anyFileType], in: .import)
        documentPickerViewController.allowsMultipleSelection = true
        
        documentPickerViewController.rx.didPickDocumentsAt
            .takeUntil(documentPickerViewController.rx.deallocated)
            .subscribe(onNext: { items in
                if let channel = channel {
                    items.forEach { url in
                        let item = UploaderItem(channel: channel, url: url)
                        
                        do {
                            try self.validateFile(item)
                            return composerView.addFileUploaderItem(item)
                        } catch {
                            vc.showAlertError(error.localizedDescription)
                        }
                    }
                }
            })
            .disposed(by: disposeBag)
        vc.present(documentPickerViewController, animated: true)
    }
    
    
    public static func showImagePicker(vc: UIViewController,
                                       sourceType: UIImagePickerController.SourceType,
                                       _ completion: @escaping (_ imagePickedInfo: PickedImage?, _ authorizationStatus: PHAuthorizationStatus) -> Void) {
        
        
        if UIImagePickerController.isSourceTypeAvailable(sourceType) {
            showAuthorizeImagePicker(vc: vc, sourceType: sourceType, completion)
            return
        }
        
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        showAuthorizeImagePicker(vc: vc, sourceType: sourceType, completion)
                    } else {
                        completion(nil, status)
                    }
                }
            }
        case .restricted, .denied:
            completion(nil, status)
        case .authorized:
            showAuthorizeImagePicker(vc: vc, sourceType: sourceType, completion)
        @unknown default:
            print(#file, #function, #line, "Unknown authorization status: \(status.rawValue)")
            return
        }
    }
    
    private static func showAuthorizeImagePicker(vc: UIViewController,
                                                 sourceType: UIImagePickerController.SourceType,
                                                 _ completion: @escaping (_ imagePickedInfo: PickedImage?, _ authorizationStatus: PHAuthorizationStatus) -> Void) {
        
        let delegateKey = String(ObjectIdentifier(self).hashValue) + "ImagePickerDelegate"
        let imagePickerViewController = UIImagePickerController()
        imagePickerViewController.sourceType = sourceType
        
        if sourceType != .camera || Bundle.main.hasInfoDescription(for: .microphone) {
            imagePickerViewController.mediaTypes = UIImagePickerController.availableMediaTypes(for: sourceType) ?? [.imageFileType]
        }
        
        let delegate = ImagePickerDelegate(completion) {
            objc_setAssociatedObject(self, delegateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            completion(nil, .notDetermined)
        }
        
        imagePickerViewController.delegate = delegate
        
        if case .camera = sourceType {
            imagePickerViewController.cameraCaptureMode = .photo
            imagePickerViewController.cameraDevice = .front
            
            if UIImagePickerController.isFlashAvailable(for: .front) {
                imagePickerViewController.cameraFlashMode = .on
            }
        }
        
        objc_setAssociatedObject(self, delegateKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        vc.present(imagePickerViewController, animated: true)
    }
    
    public static func showImpagePickerAuthorizationStatusAlert(vc: UIViewController, _ status: PHAuthorizationStatus) {
        var message = ""
        
        switch status {
        case .notDetermined:
            message = "Permissions are not determined."
        case .denied:
            message = "You have explicitly denied this application access to photos data."
        case .restricted:
            message = "This application is not authorized to access photo data."
        default:
            return
        }
        
        let alert = UIAlertController(title: "The Photo Library Permissions", message: message, preferredStyle: .alert)
        alert.addAction(.init(title: "Ok", style: .default, handler: nil))
        vc.present(alert, animated: true)
    }
    
    
    
    private static func validateFile(_ item: UploaderItem) throws {
        guard item.fileSize <= 26_214_400 else { //25MB
            throw AttachmentError.size
        }
        
        let execExtensions = ["action", "apk", "app", "bat", "bin", "cmd", "com", "command", "cpl", "csh", "exe",
                              "gadget", "inf1", "ins", "inx", "ipa", "isu", "job", "jse", "ksh", "lnk", "msc", "msi",
                              "msp", "mst", "osx", "out", "paf", "pif", "prg", "ps1", "reg", "rgs", "run", "scr",
                              "sct", "shb", "shs", "u3p", "vb", "vbe", "vbs", "vbscript", "workflow", "ws", "wsf",
                              "wsh", "0xe", "73k", "89k", "a6p", "ac", "acc", "acr", "actm", "ahk", "air", "app",
                              "arscript", "as", "asb", "awk", "azw2", "beam", "btm", "cel", "celx", "chm", "cof",
                              "crt", "dek", "dld", "dmc", "docm", "dotm", "dxl", "ear", "ebm", "ebs", "ebs2", "ecf",
                              "eham", "elf", "es", "ex4", "exopc", "ezs", "fas", "fky", "fpi", "frs", "fxp", "gs",
                              "ham", "hms", "hpf", "hta", "iim", "ipf", "isp", "jar", "js", "jsx", "kix", "lo", "ls",
                              "mam", "mcr", "mel", "mpx", "mrc", "ms", "ms", "mxe", "nexe", "obs", "ore", "otm", "pex",
                              "plx", "potm", "ppam", "ppsm", "pptm", "prc", "pvd", "pwc", "pyc", "pyo", "qpx", "rbx",
                              "rox", "rpj", "s2a", "sbs", "sca", "scar", "scb", "script", "smm", "spr", "tcp", "thm",
                              "tlb", "tms", "udf", "upx", "url", "vlx", "vpm", "wcm", "widget", "wiz", "wpk", "wpm",
                              "xap", "xbap", "xlam", "xlm", "xlsm", "xltm", "xqt", "xys", "zl9"]
        
        if let fileExtension = item.url?.pathExtension.lowercased() {
            guard !execExtensions.contains(fileExtension) else {
                throw AttachmentError.extensionNotAllowed
            }
        }
    }
}

// MARK: - Image Picker Delegate

fileprivate final class ImagePickerDelegate: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    typealias Cancel = () -> Void
    let completion: (_ imagePickedInfo: PickedImage?, _ authorizationStatus: PHAuthorizationStatus) -> Void
    let cancellation: Cancel
    
    init(_ completion: @escaping (_ imagePickedInfo: PickedImage?, _ authorizationStatus: PHAuthorizationStatus) -> Void, cancellation: @escaping Cancel) {
        self.completion = completion
        self.cancellation = cancellation
    }
    
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        picker.dismiss(animated: true) { [weak self] in
            self?.completion(PickedImage(info: info), .authorized)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        cancellation()
        picker.dismiss(animated: true)
    }
}
