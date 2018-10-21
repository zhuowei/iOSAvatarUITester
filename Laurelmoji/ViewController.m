//
//  ViewController.m
//  Laurelmoji
//
//  Created by Zhuowei Zhang on 2018-06-30.
//  Copyright © 2018 Zhuowei Zhang. All rights reserved.
//

#import "ViewController.h"
@import Darwin;
@import SceneKit;
@import ObjectiveC.runtime;
@import GLKit;
@import ARKit;

@interface ARFaceAnchor (Laurel)
@property (nonatomic) simd_float4x4 transform;
- (instancetype)init;
+ (NSDictionary<NSString*, NSNumber*>*)blendShapeMapping;
@end

@interface WDBSimFaceAnchor : ARFaceAnchor
@property (strong, nonatomic) NSDictionary<ARBlendShapeLocation,NSNumber *>* blendShapes2;
@end

@interface ARFrame (Laurel)
@property (strong, nonatomic) NSArray<ARAnchor*>* anchors;
- (instancetype)initWithTimestamp:(double)timestamp context:(id)arg1;
@end

@interface ARCamera (Laurel)
@end

@interface WDBSimFrame: ARFrame
@end

@interface AVTFaceTracker : NSObject<ARSessionDelegate>
@end

@interface AVTView : SCNView
@property (strong, nonatomic) AVTFaceTracker* faceTracker;
@end

@interface AVTMultiAvatarController : NSObject
- (UIView*)view;
@end

@interface AVTUIControllerPresentation : NSObject
@property(readonly, nonatomic) UIViewController *controller;
@end

@protocol AVTPresenterDelegate <NSObject>
@required
- (void)presentAvatarUIController:(AVTUIControllerPresentation*)viewController animated:(bool)animated;
- (void)dismissAvatarUIControllerAnimated:(bool)animated;
@end

@interface AVTCarouselController : NSObject
@property(strong, nonatomic) UIView *avtViewContainer;
@property(strong, nonatomic) AVTMultiAvatarController *multiAvatarController;
@property(weak, nonatomic) id <AVTPresenterDelegate> presenterDelegate;
@property(readonly, nonatomic) AVTView *focusedDisplayView;
+ (AVTCarouselController*)displayingCarouselForRecordDataSource:(id)arg1;
- (UIView*)view;
@end

@interface AVTAvatarStore : NSObject
+ (AVTAvatarStore*)defaultBackendForDomainIdentifier:(NSString*)arg1 environment:(NSString*)arg2;
@end

@interface AVTUIEnvironment : NSObject
+ (AVTUIEnvironment*)defaultEnvironment;
@end

@interface AVTAvatarRecordDataSource : NSObject
+ (AVTAvatarRecordDataSource*)defaultUIDataSourceWithDomainIdentifier:(NSString*)arg1;
@end

@interface AVTAvatarLibraryViewController : UIViewController
- (instancetype)initWithAvatarStore:(AVTAvatarStore*)store;;
@end

@interface AVTAvatarPose
- (void)setNeckPosition:(SCNVector3)position;
- (void)setNeckOrientation:(SCNQuaternion)orientation;
@end

void setNeckPosition(AVTAvatarPose* pose, float x, float y, float z) {
    [pose setNeckPosition:SCNVector3Make(x, y, z)];
}

void setNeckOrientation(AVTAvatarPose* pose, float radians, float x, float y, float z) {
    GLKQuaternion quat = GLKQuaternionMakeWithAngleAndAxis(radians, x, y, z);
    [pose setNeckOrientation:SCNVector4Make(quat.q[0], quat.q[1], quat.q[2], quat.q[3])];
}

static void cleanupScene(SCNScene* scene) {
    [scene.rootNode enumerateHierarchyUsingBlock:^(SCNNode * _Nonnull node, BOOL * _Nonnull stop) {
        SCNGeometry* geometry = node.geometry;
        if (!geometry) return;
        geometry.subdivisionLevel = 0;
    }];
}

void (*SCNRenderer__drawScene_real)(SCNRenderer* self, SEL sel, id c3dScene);
void SCNRenderer__drawScene_hook(SCNRenderer* self, SEL sel, id c3dScene) {
    SCNScene* scene = self.scene;
    if (scene) {
        cleanupScene(scene);
    }
    SCNRenderer__drawScene_real(self, sel, c3dScene);
}

static void hookSceneKit() {
    Method method = class_getInstanceMethod([SCNRenderer class], @selector(_drawScene:));
    SCNRenderer__drawScene_real = (void*)method_getImplementation(method);
    method_setImplementation(method, (IMP)&SCNRenderer__drawScene_hook);
}

static NSDictionary* populateMapping() {
    NSArray<NSString*>* blendShapes = @[ARBlendShapeLocationEyeBlinkLeft, ARBlendShapeLocationEyeBlinkRight,
                                       ARBlendShapeLocationEyeLookDownLeft, ARBlendShapeLocationEyeLookDownRight,
                                       ARBlendShapeLocationEyeLookInLeft, ARBlendShapeLocationEyeLookInRight,
                                       ARBlendShapeLocationEyeLookOutLeft, ARBlendShapeLocationEyeLookOutRight,
                                       ARBlendShapeLocationEyeLookUpLeft, ARBlendShapeLocationEyeLookUpRight,
                                       ARBlendShapeLocationMouthClose, ARBlendShapeLocationMouthFunnel,
                                       ARBlendShapeLocationMouthPressLeft, ARBlendShapeLocationMouthPressRight,
                                       ARBlendShapeLocationMouthPucker, ARBlendShapeLocationMouthRollLower,
                                       ARBlendShapeLocationMouthShrugLower, ARBlendShapeLocationTongueOut,
                                        ARBlendShapeLocationJawOpen,
                                       ];
    int theid = 0;
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    for (NSString* a in blendShapes) {
        dict[a] = [NSNumber numberWithInteger:theid++];
    }
    return dict;
}

static NSDictionary* blendShapeDict;

static NSDictionary* getBlendShapeDict() {
    if (!blendShapeDict) blendShapeDict = populateMapping();
    return blendShapeDict;
}

static NSDictionary* ARFaceAnchor_blendShapeMapping_hook(Class self, SEL sel) {
    return getBlendShapeDict();
}

static void hookARBlendMapping() {
    Method method = class_getClassMethod([ARFaceAnchor class], @selector(blendShapeMapping));
    method_setImplementation(method, (IMP)&ARFaceAnchor_blendShapeMapping_hook);
}

@interface ViewController () <AVTPresenterDelegate>
@property (strong, nonatomic) AVTCarouselController* carouselController;
@end
extern void bundlehook_init(void);
@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    void* avatarUi = dlopen("/System/Library/PrivateFrameworks/AvatarUI.framework/AvatarUI", RTLD_LOCAL | RTLD_NOW);
    if (!avatarUi) abort();
    
    static BOOL hooked = NO;
    if (hooked) return;
    hooked = YES;
    
    bundlehook_init();
    hookSceneKit();
    hookARBlendMapping();
}
- (IBAction)startClicked3:(id)sender {
    AVTUIEnvironment* environment = [NSClassFromString(@"AVTUIEnvironment") defaultEnvironment];
    AVTAvatarStore* store = [NSClassFromString(@"AVTAvatarStore") defaultBackendForDomainIdentifier:@"com.worthdoingbadly.Laurelmoji" environment:environment];
    AVTAvatarLibraryViewController* vc = [[NSClassFromString(@"AVTAvatarLibraryViewController") alloc] initWithAvatarStore:store];
    [self presentViewController:vc animated:true completion:nil];
}
- (IBAction)startClicked:(id)sender {
    if (self.carouselController) {
        [self resetIt];
        return;
    }
    /*
    AVTUIEnvironment* environment = [NSClassFromString(@"AVTUIEnvironment") defaultEnvironment];
    AVTAvatarStore* source = [NSClassFromString(@"AVTAvatarStore") defaultBackendForDomainIdentifier:@"com.worthdoingbadly.Laurelmoji" environment:environment];
    */
    AVTAvatarRecordDataSource* source = [NSClassFromString(@"AVTAvatarRecordDataSource") defaultUIDataSourceWithDomainIdentifier:@"com.worthdoingbadly.Laurelmoji"];
    AVTCarouselController* controller = (AVTCarouselController*)[NSClassFromString(@"AVTCarouselController") displayingCarouselForRecordDataSource:source];
    controller.presenterDelegate = self;
    UIView* view = controller.view;
    //UIView* avtViewContainer = controller.avtViewContainer;
    [self.view insertSubview:view belowSubview:sender];
    //[self.view addSubview:avtViewContainer];
    //[self.view addSubview:controller.multiAvatarController.view];
    self.carouselController = controller;
}

- (void)presentAvatarUIController:(AVTUIControllerPresentation *)presentation animated:(bool)animated {
    [self presentViewController:presentation.controller animated:animated completion:nil];
}
- (void)dismissAvatarUIControllerAnimated:(bool)animated {
    [self dismissViewControllerAnimated:animated completion:nil];
}

- (void)resetIt {
    static double timestamp = 0;
    WDBSimFrame* frame = [[WDBSimFrame alloc]initWithTimestamp:timestamp++ context:nil];
    WDBSimFaceAnchor* faceAnchor = [[WDBSimFaceAnchor alloc]init];
    frame.anchors = @[faceAnchor];
    //faceAnchor.transform = matrix_identity_float4x4;
    simd_float3 zaxis = {0, 0, 1};
    simd_quatf rotation = simd_quaternion((float)M_PI_2, zaxis);
    faceAnchor.transform = simd_matrix4x4(rotation);
    faceAnchor.blendShapes2 = @{
                               ARBlendShapeLocationEyeBlinkLeft: @0,
                               ARBlendShapeLocationEyeBlinkRight: @0,
                               ARBlendShapeLocationMouthClose: @0,
                               ARBlendShapeLocationMouthPressLeft: @0,
                               ARBlendShapeLocationMouthPressRight: @0,
                               ARBlendShapeLocationMouthPucker: @1,
                               ARBlendShapeLocationMouthFunnel: @0,
                               ARBlendShapeLocationMouthShrugLower: @0,
                               ARBlendShapeLocationTongueOut: @1,
                               ARBlendShapeLocationJawOpen: @1,
                               };
    [self.carouselController.focusedDisplayView.faceTracker session:@"nope" didUpdateFrame:frame];
}
@end
@interface WDBDankArray: NSArray
@property (strong, nonatomic) NSArray* backingArray;
@end
@interface WDBDankDictionary: NSDictionary
@property (strong, nonatomic) NSDictionary* backingDictionary;
@end
static id dankify(NSObject* input) {
    if ([input isKindOfClass:[NSDictionary class]]) {
        WDBDankDictionary* dankDict = [WDBDankDictionary new];
        dankDict.backingDictionary = input;
        return dankDict;
    }
    if ([input isKindOfClass:[NSArray class]]) {
        WDBDankArray* dankArray = [WDBDankArray new];
        dankArray.backingArray = input;
        return dankArray;
    }
    return input;
}
@implementation WDBDankArray
- (id)objectAtIndexedSubscript:(NSUInteger)idx {
    NSLog(@"%@: Object at indexed subscript: %u", self, (unsigned)idx);
    return dankify(self.backingArray[idx]);
}
- (NSUInteger)count {
    return self.backingArray.count;
}
@end

@implementation WDBDankDictionary
- (id)objectForKeyedSubscript:(id)key {
    NSLog(@"%@: Object for keyed subscript: %@", self, key);
    return dankify(self.backingDictionary[key]);
}
- (NSUInteger)count {
    return self.backingDictionary.count;
}
@end
@implementation WDBSimFrame
- (CGAffineTransform)displayTransformForOrientation:(UIInterfaceOrientation)orientation viewportSize:(CGSize)viewportSize {
    abort();
}
- (ARCamera*)camera {
    NSLog(@"Camera!");
    return [super camera];
}
@end

@implementation WDBSimFaceAnchor
- (simd_float4x4)transform {
    NSLog(@"Transform!");
    return [super transform];
}
- (NSDictionary<ARBlendShapeLocation,NSNumber *>*)blendShapes{
    NSLog(@"Blend shapes!");
    return self.blendShapes2;
}
- (BOOL)isTracked {
    return YES;
}
- (ARFaceGeometry *)geometry {
    NSLog(@"Geometry!");
    abort();
}
- (id)trackingData {
    NSLog(@"trackingData");
    NSDictionary* blendShapeDict = getBlendShapeDict();
    float blendshapes[blendShapeDict.count];
    for (int i = 0; i < blendShapeDict.count; i++) {
        blendshapes[i] = 0;
    }
    return @{
             @"raw_data": @{
                     @"pose": @{
                             @"rotation": @[@[@1, @0, @0], @[@0, @1, @0], @[@0, @0, @1]],
                     },
                     @"animation": @{
                             @"tongue_out": @0,
                             @"blendshapes": [NSData dataWithBytes:blendshapes length:blendShapeDict.count*sizeof(float)]
                             }
                     }
             };
}
@end
