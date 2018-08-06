//: A UIKit based Playground for presenting user interface
  
import UIKit
import PlaygroundSupport
import ObjectiveC

private func AVTUIEnvironment_storeLocation_hook(bundleClass: AnyClass, selector: Selector) -> NSURL {
    let manager = FileManager.default
    let documentDirectories = manager.urls(for: .documentDirectory, in: .userDomainMask)
    if documentDirectories.count < 1 {
        fatalError("No document director?")
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
    guard let method = class_getClassMethod(NSClassFromString("AVTUIEnvironment"), Selector(("storeLocation"))) else {
        fatalError("Can't find method")
    }
    let newFunc = AVTUIEnvironment_storeLocation_hook as @convention(c) (AnyClass, Selector) -> NSURL
    method_setImplementation(method, unsafeBitCast(newFunc, to: IMP.self))
}

class MyViewController : UIViewController {
    private var carouselController:NSObject?
    override func viewDidLoad() {
        super.viewDidLoad()
        self.launchLaurelmoji()
    }
    private func launchLaurelmoji() {
        hookMethods()
        guard let classAVTAvatarRecordDataSource = NSClassFromString("AVTAvatarRecordDataSource") as? NSObject.Type else {
            fatalError("Failed to get class AVTAvatarRecordDataSource")
        }
        guard let source = classAVTAvatarRecordDataSource.perform(
            Selector(("defaultUIDataSourceWithDomainIdentifier:")), with: Bundle.main.bundleIdentifier)?.takeRetainedValue() as? NSObject else {
                fatalError("Failed to create AVTAvatarRecordDataSource")
        }
        guard let classAVTCarouselController = NSClassFromString("AVTCarouselController") as? NSObject.Type else {
            fatalError("Failed to get class AVTCarouselController")
        }
        guard let controller = classAVTCarouselController.perform(Selector(("displayingCarouselForRecordDataSource:")), with: source)?.takeRetainedValue() as? NSObject else {
            fatalError("Failed to create AVTCarouselController")
        }
        guard let view = controller.perform(Selector(("view")))?.takeRetainedValue() as? UIView else {
            fatalError("Failed to get view")
        }
        self.view.addSubview(view)
        self.carouselController = controller
    }
}
// Present the view controller in the Live View window
PlaygroundPage.current.liveView = MyViewController()
