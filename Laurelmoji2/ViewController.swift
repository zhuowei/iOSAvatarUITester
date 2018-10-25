//
//  ViewController.swift
//  Laurelmoji2
//
//  Created by Zhuowei Zhang on 2018-08-05.
//  Copyright © 2018 Zhuowei Zhang. All rights reserved.
//

import UIKit
import ObjectiveC
import SceneKit

typealias BundleForClass_Type = @convention(c) (AnyClass, Selector, AnyClass) -> Bundle
private var NSBundle_bundleForClass_real:BundleForClass_Type!
private func NSBundle_bundleForClass_hook(bundleClass: AnyClass, selector: Selector, classToGet:AnyClass) -> Bundle {
    if let execNameCStr = class_getImageName(classToGet) {
        let execName = String(cString: execNameCStr)
        if execName == "/System/Library/PrivateFrameworks/AvatarUI.framework/AvatarUI" {
            let url = Bundle.main.url(forResource: "AvatarUI", withExtension: "framework")!
            return Bundle(url: url)!
        }
        if execName == "/System/Library/PrivateFrameworks/AvatarKit.framework/AvatarKit" {
            let url = Bundle.main.url(forResource: "AvatarKit", withExtension: "framework")!
            return Bundle(url: url)!
        }
    }
    return NSBundle_bundleForClass_real(bundleClass, selector, classToGet)
}

private func AVTUIEnvironment_storeLocation_hook(bundleClass: AnyClass, selector: Selector) -> NSURL {
    let manager = FileManager.default
    let documentDirectories = manager.urls(for: .documentDirectory, in: .userDomainMask)
    if documentDirectories.count < 1 {
        fatalError("No document directory?")
    }
    return documentDirectories[0].appendingPathComponent("Avatar", isDirectory: true) as NSURL
}

public func cleanupScene(scene: SCNScene) {
    scene.rootNode.enumerateHierarchy() { node, _ in
        guard let geometry = node.geometry else {
            return
        }
        geometry.program = nil
        geometry.shaderModifiers = nil
        geometry.subdivisionLevel = 0
        
        for material in geometry.materials {
            material.program = nil
            material.shaderModifiers = nil
        }
    }
}

typealias SCNScene_sceneWithURL_options_error_Type = @convention(c) (AnyClass, Selector, NSURL, NSDictionary, UnsafePointer<NSError>) -> SCNScene?
private var SCNScene_sceneWithURL_options_error_real:SCNScene_sceneWithURL_options_error_Type!
private func SCNScene_sceneWithURL_options_error_hook(self: AnyClass, sel: Selector, url: NSURL, options: NSDictionary, error: UnsafePointer<NSError>) -> SCNScene? {
    guard let scene = SCNScene_sceneWithURL_options_error_real(self, sel, url, options, error) else {
        return nil
    }
    cleanupScene(scene: scene)
    return scene
}

typealias SCNView_initWithFrame_options_Type = @convention(c) (SCNView, Selector, CGRect, NSDictionary?) -> SCNView;
private var SCNView_initWithFrame_options_real:SCNView_initWithFrame_options_Type!
private func SCNView_initWithFrame_options_hook(self: SCNView, sel: Selector, frame: CGRect, options: NSDictionary?) -> SCNView {
    let newOptions = options == nil ? NSMutableDictionary() : NSMutableDictionary(dictionary: options!)
    //newOptions[SCNView.Option.preferredRenderingAPI] = SCNRenderingAPI.openGLES2.rawValue as NSNumber
    let retval = SCNView_initWithFrame_options_real(self, sel, frame, newOptions)
    //retval.debugOptions = [SCNDebugOptions.renderAsWireframe, SCNDebugOptions.showBoundingBoxes, SCNDebugOptions.showSkeletons]
    retval.debugOptions = [SCNDebugOptions.showWireframe]
    retval.showsStatistics = true
    return retval
}

typealias SCNRenderer__drawScene_Type = @convention(c) (SCNView, Selector, AnyObject) -> Void;
private var SCNRenderer__drawScene_real:SCNRenderer__drawScene_Type!
private func SCNRenderer__drawScene_hook(self: SCNView, sel: Selector, c3dScene: AnyObject) {
    if let scene = self.value(forKey: "scene") as? SCNScene {
        cleanupScene(scene: scene)
    }
    SCNRenderer__drawScene_real(self, sel, c3dScene)
}

private var hooked = false;
private func hookMethods() {
    if hooked {
        return
    }
    hooked = true
    guard dlopen("/System/Library/PrivateFrameworks/AvatarUI.framework/AvatarUI", RTLD_LOCAL | RTLD_NOW) != nil else {
        let errS = dlerror()
        let err = errS == nil ? "" : String(cString: errS!)
        fatalError("Can't open library: \(err)")
    }
    hookAvatarEnv()
    hookBundle()
    hookSceneKit()
    hookSceneKitView()
    hookSceneKitView2()
    hookGPUAvailable()
}

private func hookAvatarEnv() {
    guard let method = class_getClassMethod(NSClassFromString("AVTUIEnvironment"), Selector(("storeLocation"))) else {
    fatalError("Can't find method")
    }
    let newFunc = AVTUIEnvironment_storeLocation_hook as @convention(c) (AnyClass, Selector) -> NSURL
    method_setImplementation(method, unsafeBitCast(newFunc, to: IMP.self))
}

private func hookBundle() {
    guard let method = class_getClassMethod(Bundle.self, Selector(("bundleForClass:"))) else {
        fatalError("Can't find method")
    }
    NSBundle_bundleForClass_real = unsafeBitCast(method_getImplementation(method), to:BundleForClass_Type.self)
    method_setImplementation(method, unsafeBitCast(NSBundle_bundleForClass_hook as BundleForClass_Type, to: IMP.self))
}

private func hookSceneKit() {
    guard let method = class_getClassMethod(SCNScene.self, Selector(("sceneWithURL:options:error:"))) else {
        fatalError("Can't find method")
    }
    SCNScene_sceneWithURL_options_error_real = unsafeBitCast(method_getImplementation(method), to: SCNScene_sceneWithURL_options_error_Type.self)
    method_setImplementation(method, unsafeBitCast(SCNScene_sceneWithURL_options_error_hook as SCNScene_sceneWithURL_options_error_Type, to: IMP.self))
}

private func hookSceneKitView() {
    guard let method = class_getInstanceMethod(SCNView.self, Selector(("initWithFrame:options:"))) else {
        fatalError("Can't find method")
    }
    SCNView_initWithFrame_options_real = unsafeBitCast(method_getImplementation(method), to: SCNView_initWithFrame_options_Type.self)
    method_setImplementation(method, unsafeBitCast(SCNView_initWithFrame_options_hook as SCNView_initWithFrame_options_Type, to: IMP.self))
}

private func hookSceneKitView2() {
    guard let method = class_getInstanceMethod(SCNRenderer.self, Selector(("_drawScene:"))) else {
        fatalError("Can't find method")
    }
    SCNRenderer__drawScene_real = unsafeBitCast(method_getImplementation(method), to: SCNRenderer__drawScene_Type.self)
    method_setImplementation(method, unsafeBitCast(SCNRenderer__drawScene_hook as SCNRenderer__drawScene_Type, to: IMP.self))
}

private func hookGPUAvailable() {
}

class ViewController: UIViewController {
    private var carouselController:NSObject?
    private var carouselSource:NSObject?
    private var carouselView:UIView?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor.lightGray
    }

    @IBAction
    func buttonClicked(_ sender: UIButton) {
        if hooked {
            return
        }
        launchLaurelmoji();
    }
    
    func launchLaurelmoji() {
        hookMethods()
        // do I use takeRetained or takeUnretained...
        guard let classAVTAvatarRecordDataSource = NSClassFromString("AVTAvatarRecordDataSource") as? NSObject.Type else {
            fatalError("Failed to get class AVTAvatarRecordDataSource")
        }
        guard let source = classAVTAvatarRecordDataSource.perform(
            Selector(("defaultUIDataSourceWithDomainIdentifier:")), with: Bundle.main.bundleIdentifier)?.takeUnretainedValue() as? NSObject else {
            fatalError("Failed to create AVTAvatarRecordDataSource")
        }
        guard let classAVTCarouselController = NSClassFromString("AVTCarouselController") as? NSObject.Type else {
            fatalError("Failed to get class AVTCarouselController")
        }
        guard let controller = classAVTCarouselController.perform(Selector(("displayingCarouselForRecordDataSource:")), with: source)?.takeUnretainedValue() as? NSObject else {
            fatalError("Failed to create AVTCarouselController")
        }
        guard let view = controller.value(forKey: "view") as? UIView else {
            fatalError("Failed to get view")
        }
        controller.setValue(self, forKey: "presenterDelegate")
        self.view.addSubview(view)
        self.carouselController = controller
        // make sure everything is retained
        self.carouselSource = source
        self.carouselView = view
    }
    
    @objc func presentAvatarUIController(_ presentation:NSObject, animated:Bool) {
        self.present(presentation.value(forKey: "controller") as! UIViewController, animated: animated, completion: nil)
    }
    @objc func dismissAvatarUIControllerAnimated(_ animated: Bool) {
        self.dismiss(animated: animated, completion: nil)
    }

}

