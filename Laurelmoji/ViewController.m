//
//  ViewController.m
//  Laurelmoji
//
//  Created by Zhuowei Zhang on 2018-06-30.
//  Copyright © 2018 Zhuowei Zhang. All rights reserved.
//

#import "ViewController.h"
@import Darwin;
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

@interface ViewController () <AVTPresenterDelegate>
@property (strong, nonatomic) AVTCarouselController* carouselController;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    void* avatarUi = dlopen("/System/Library/PrivateFrameworks/AvatarUI.framework/AvatarUI", RTLD_LOCAL | RTLD_NOW);
    if (!avatarUi) abort();
}
- (IBAction)startClicked3:(id)sender {
    AVTUIEnvironment* environment = [NSClassFromString(@"AVTUIEnvironment") defaultEnvironment];
    AVTAvatarStore* store = [NSClassFromString(@"AVTAvatarStore") defaultBackendForDomainIdentifier:@"com.worthdoingbadly.Laurelmoji" environment:environment];
    AVTAvatarLibraryViewController* vc = [[NSClassFromString(@"AVTAvatarLibraryViewController") alloc] initWithAvatarStore:store];
    [self presentViewController:vc animated:true completion:nil];
}
- (IBAction)startClicked:(id)sender {
    /*
    AVTUIEnvironment* environment = [NSClassFromString(@"AVTUIEnvironment") defaultEnvironment];
    AVTAvatarStore* source = [NSClassFromString(@"AVTAvatarStore") defaultBackendForDomainIdentifier:@"com.worthdoingbadly.Laurelmoji" environment:environment];
    */
    AVTAvatarRecordDataSource* source = [NSClassFromString(@"AVTAvatarRecordDataSource") defaultUIDataSourceWithDomainIdentifier:@"com.worthdoingbadly.Laurelmoji"];
    AVTCarouselController* controller = (AVTCarouselController*)[NSClassFromString(@"AVTCarouselController") displayingCarouselForRecordDataSource:source];
    controller.presenterDelegate = self;
    UIView* view = controller.view;
    //UIView* avtViewContainer = controller.avtViewContainer;
    [self.view addSubview:view];
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
@end
