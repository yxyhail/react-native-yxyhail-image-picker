//
//  RNImagePicker.h
//  RNImagePicker
//
//  Created by yxyhail on 2020/8/24.
//  Copyright © 2020 yxyhail. All rights reserved.
//

#if __has_include("RCTBridgeModule.h")
#import "RCTBridgeModule.h"
#else
#import <React/RCTBridgeModule.h>
#endif
#import <UIKit/UIKit.h>
#import "TZImagePickerController.h"

#import <Foundation/Foundation.h>

@interface RNImagePicker : NSObject<RCTBridgeModule, TZImagePickerControllerDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIActionSheetDelegate>

@end
