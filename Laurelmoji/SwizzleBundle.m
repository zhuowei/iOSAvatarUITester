//
//  SwizzleBundle.m
//  Laurelmoji
//
//  Created by Zhuowei Zhang on 2018-07-30.
//  Copyright © 2018 Zhuowei Zhang. All rights reserved.
//

@import Foundation;
@import ObjectiveC;

NSBundle* (*NSBundle_bundleForClass_real)(Class bundleClass, SEL selector, Class classToGet);

NSBundle* NSBundle_bundleForClass_hook(Class bundleClass, SEL selector, Class classToGet) {
    // if class's bundle doesn't exist, it returns the main bundle.
    // I could package the resources in main bundle, I suppose...
    const char* execName = class_getImageName(classToGet);
    if (strcmp(execName, "/System/Library/PrivateFrameworks/AvatarUI.framework/AvatarUI") == 0) {
        NSURL* urlToBundle = [[NSBundle mainBundle] URLForResource:@"AvatarUI" withExtension:@"framework"];
        return [NSBundle bundleWithURL:urlToBundle];
    }
    if (strcmp(execName, "/System/Library/PrivateFrameworks/AvatarKit.framework/AvatarKit") == 0) {
        NSURL* urlToBundle = [[NSBundle mainBundle] URLForResource:@"AvatarKit" withExtension:@"framework"];
        return [NSBundle bundleWithURL:urlToBundle];
    }
    NSBundle* retval = NSBundle_bundleForClass_real(bundleClass, selector, classToGet);
    return retval;
}

void bundlehook_init() {
    static bool hooked = false;
    if (hooked) return;
    hooked = true;
    Method method = class_getClassMethod([NSBundle class], @selector(bundleForClass:));
    NSBundle_bundleForClass_real = (void*)method_getImplementation(method);
    method_setImplementation(method, (IMP)&NSBundle_bundleForClass_hook);
}
