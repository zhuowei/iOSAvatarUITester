//: Launches the Animoji carousel and allows creating Memoji.
//: iOS 12 is required. by @zhuowei (https://worthdoingbadly.com/memoji/)
  
import UIKit
import PlaygroundSupport
import ObjectiveC

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

class ViewController: UIViewController {
    private var carouselController:NSObject?
    private var carouselSource:NSObject?
    private var carouselView:UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        DispatchQueue.main.async {
            self.launchLaurelmoji()
        }
    }
    
    override func loadView() {
        super.loadView()
        self.view = UIView()
        self.view.backgroundColor = UIColor.white
    }
    
    override func viewDidLayoutSubviews() {
        if let carouselView = self.carouselView {
            carouselView.frame = self.view.bounds
        }
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
// Present the view controller in the Live View window
PlaygroundPage.current.liveView = ViewController()
