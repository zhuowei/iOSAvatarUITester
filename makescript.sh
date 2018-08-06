#!/bin/bash
set -e
rm -r builddir AvatarResources || true
IOS_BASE="/Volumes/PeaceSeed16A5327f.D22D221DeveloperOS"
mkdir builddir
cp -r "$IOS_BASE/System/Library/PrivateFrameworks/AvatarKit.framework/"* builddir/
cp -r "$IOS_BASE/System/Library/PrivateFrameworks/AvatarUI.framework/"* builddir/
rm -r builddir/Info.plist builddir/_CodeSignature
mv builddir AvatarResources