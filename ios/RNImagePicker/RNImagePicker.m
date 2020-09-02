//
//  RNImagePicker.m
//  RNImagePicker
//
//  Created by yxyhail on 2020/8/24.
//  Copyright © 2020 yxyhail. All rights reserved.
//

#import "RNImagePicker.h"

#import "TZImageManager.h"
#import "NSDictionary+SYSafeConvert.h"
#import "TZImageCropManager.h"
#import "FLAnimatedImage.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <React/RCTUtils.h>

@interface RNImagePicker ()

@property (nonatomic, strong) UIImagePickerController *imagePickerVc;
@property (nonatomic, strong) NSDictionary *cameraOptions;
/**
 保存Promise的resolve block
 */
@property (nonatomic, copy) RCTPromiseResolveBlock resolveBlock;
/**
 保存Promise的reject block
 */
@property (nonatomic, copy) RCTPromiseRejectBlock rejectBlock;
/**
 保存回调的callback
 */
@property (nonatomic, copy) RCTResponseSenderBlock callback;
/**
 保存选中的图片数组
 */
@property (nonatomic, strong) NSMutableArray *selectedAssets;
@property (nonatomic, strong) NSMutableArray *selectedAssetsCache;
@property (nonatomic, strong) NSMutableArray *originSelectedAssets;
@property (nonatomic, strong) NSArray *selectedPhotos;
@end

@implementation RNImagePicker

- (instancetype)init {
  self = [super init];
  if (self) {
    _selectedAssets = [NSMutableArray array];
    _selectedAssetsCache = [NSMutableArray array];
    _selectedPhotos = [NSMutableArray array];
    _originSelectedAssets = [NSMutableArray array];
  }
  return self;
}

- (void)dealloc {
  _selectedAssets = nil;
  _selectedAssetsCache = nil;
  _selectedPhotos = nil;
  _originSelectedAssets=nil;
}

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(showImagePicker:(NSDictionary *)options
                  callback:(RCTResponseSenderBlock)callback) {
  self.cameraOptions = options;
  self.callback = callback;
  self.resolveBlock = nil;
  self.rejectBlock = nil;
  [self openImagePicker];
}

RCT_REMAP_METHOD(asyncShowImagePicker,
                 options:(NSDictionary *)options
                 showImagePickerResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
  self.cameraOptions = options;
  self.resolveBlock = resolve;
  self.rejectBlock = reject;
  self.callback = nil;
  [self openImagePicker];
}

RCT_EXPORT_METHOD(openCamera:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback) {
  self.cameraOptions = options;
  self.callback = callback;
  self.resolveBlock = nil;
  self.rejectBlock = nil;
  [self takePhoto];
}

RCT_REMAP_METHOD(previewImage,index:(NSInteger )index) {
  NSLog(@"previewImage:%ld",index);
  [self pushPreviewImage:index];
}

RCT_REMAP_METHOD(sortList,order:(NSArray *) order){
  NSLog(@"sortList:%@",order);
  [self reSortList:order];
}

RCT_REMAP_METHOD(asyncOpenCamera,
                 options:(NSDictionary *)options
                 openCameraResolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject) {
  self.cameraOptions = options;
  self.resolveBlock = resolve;
  self.rejectBlock = reject;
  self.callback = nil;
  [self takePhoto];
}

RCT_EXPORT_METHOD(deleteCache) {
  NSFileManager *fileManager = [NSFileManager defaultManager];
  [fileManager removeItemAtPath: [NSString stringWithFormat:@"%@SyanImageCaches", NSTemporaryDirectory()] error:nil];
}

RCT_EXPORT_METHOD(removePhotoAtIndex:(NSInteger)index originIndex:(NSInteger)originIndex) {
  NSLog(@"remove:selectedAssets:%@",_selectedAssets);
  if (self.selectedAssets && self.selectedAssets.count > index) {
    [self.selectedAssets removeObjectAtIndex:index];
  }
  NSLog(@"remove:selectedAssets after:%@",_selectedAssets);
  
  NSLog(@"remove:selectedAssetsCache:%@",_selectedAssetsCache);
  NSLog(@"remove:index:%ld",index);
  if(self.selectedAssetsCache && self.selectedAssetsCache.count>index){
    [self.selectedAssetsCache removeObjectAtIndex:index];
  }
  NSLog(@"remove:selectedAssetsCache after:%@",_selectedAssetsCache);
  NSLog(@"remove:originSelectedAssets:%@",_originSelectedAssets);
  NSLog(@"remove:originIndex:%ld",originIndex);
  if(self.originSelectedAssets && self.originSelectedAssets.count>originIndex){
    [self.originSelectedAssets removeObjectAtIndex:originIndex];
  }
  NSLog(@"remove:originSelectedAssets after:%@",_originSelectedAssets);
}

RCT_EXPORT_METHOD(removeAllPhoto) {
  if (self.selectedAssets) {
    [self.selectedAssets removeAllObjects];
  }
  if(self.selectedAssetsCache){
    [self.selectedAssetsCache removeAllObjects];
  }
}

// openVideoPicker
RCT_EXPORT_METHOD(openVideoPicker:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback) {
  [self openTZImagePicker:options callback:callback];
}

- (void)openTZImagePicker:(NSDictionary *)options callback:(RCTResponseSenderBlock)callback {
  NSInteger imageCount = [options sy_integerForKey:@"imageCount"];
  BOOL isCamera        = [options sy_boolForKey:@"isCamera"];
  BOOL isCrop          = [options sy_boolForKey:@"isCrop"];
  BOOL isGif = [options sy_boolForKey:@"isGif"];
  BOOL allowPickingVideo = [options sy_boolForKey:@"allowPickingVideo"];
  BOOL allowPickingMultipleVideo = [options sy_boolForKey:@"allowPickingMultipleVideo"];
  BOOL allowPickingImage = [options sy_boolForKey:@"allowPickingImage"];
  BOOL allowTakeVideo = [options sy_boolForKey:@"allowTakeVideo"];
  BOOL showCropCircle  = [options sy_boolForKey:@"showCropCircle"];
  BOOL isRecordSelected = [options sy_boolForKey:@"isRecordSelected"];
  BOOL allowPickingOriginalPhoto = [options sy_boolForKey:@"allowPickingOriginalPhoto"];
  BOOL sortAscendingByModificationDate = [options sy_boolForKey:@"sortAscendingByModificationDate"];
  NSInteger CropW      = [options sy_integerForKey:@"CropW"];
  NSInteger CropH      = [options sy_integerForKey:@"CropH"];
  NSInteger circleCropRadius = [options sy_integerForKey:@"circleCropRadius"];
  NSInteger videoMaximumDuration = [options sy_integerForKey:@"videoMaximumDuration"];
  NSInteger   quality  = [self.cameraOptions sy_integerForKey:@"quality"];
  
  TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:imageCount delegate:self];
  
  imagePickerVc.maxImagesCount = imageCount;
  imagePickerVc.allowPickingGif = isGif; // 允许GIF
  imagePickerVc.allowTakePicture = isCamera; // 允许用户在内部拍照
  imagePickerVc.allowPickingVideo = allowPickingVideo; // 不允许视频
  imagePickerVc.allowPickingImage = allowPickingImage;
  imagePickerVc.allowTakeVideo = allowTakeVideo; // 允许拍摄视频
  imagePickerVc.videoMaximumDuration = videoMaximumDuration;
  imagePickerVc.allowPickingMultipleVideo = isGif || allowPickingMultipleVideo ? YES : NO;
  imagePickerVc.allowPickingOriginalPhoto = allowPickingOriginalPhoto; // 允许原图
  imagePickerVc.sortAscendingByModificationDate = sortAscendingByModificationDate;
  imagePickerVc.alwaysEnableDoneBtn = YES;
  imagePickerVc.allowCrop = isCrop;   // 裁剪
  imagePickerVc.autoDismiss = NO;
  imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
  
  if (isRecordSelected) {
    imagePickerVc.selectedAssets = self.selectedAssets; // 当前已选中的图片
  }
  
  
  if (imageCount == 1) {
    // 单选模式
    imagePickerVc.showSelectBtn = NO;
    
    if(isCrop){
      if(showCropCircle) {
        imagePickerVc.needCircleCrop = showCropCircle; //圆形裁剪
        imagePickerVc.circleCropRadius = circleCropRadius; //圆形半径
      } else {
        CGFloat x = ([[UIScreen mainScreen] bounds].size.width - CropW) / 2;
        CGFloat y = ([[UIScreen mainScreen] bounds].size.height - CropH) / 2;
        imagePickerVc.cropRect = CGRectMake(x,y,CropW,CropH);
      }
    }
  }
  
  __weak TZImagePickerController *weakPicker = imagePickerVc;
  [imagePickerVc setDidFinishPickingPhotosWithInfosHandle:^(NSArray<UIImage *> *photos,NSArray *assets,BOOL isSelectOriginalPhoto,NSArray<NSDictionary *> *infos) {
    [self handleAssets:assets photos:photos quality:quality isSelectOriginalPhoto:isSelectOriginalPhoto completion:^(NSArray *selecteds) {
      callback(@[[NSNull null], selecteds]);
      [weakPicker dismissViewControllerAnimated:YES completion:nil];
      [weakPicker hideProgressHUD];
    } fail:^(NSError *error) {
      [weakPicker dismissViewControllerAnimated:YES completion:nil];
      [weakPicker hideProgressHUD];
    }];
  }];
  
  [imagePickerVc setDidFinishPickingVideoHandle:^(UIImage *coverImage, PHAsset *asset) {
    [weakPicker showProgressHUD];
    [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPresetHighestQuality success:^(NSString *outputPath) {
      NSLog(@"视频导出成功:%@", outputPath);
      callback(@[[NSNull null], @[[self handleVideoData:outputPath asset:asset coverImage:coverImage quality:quality]]]);
      [weakPicker dismissViewControllerAnimated:YES completion:nil];
      [weakPicker hideProgressHUD];
    } failure:^(NSString *errorMessage, NSError *error) {
      NSLog(@"视频导出失败:%@,error:%@",errorMessage, error);
      callback(@[@"视频导出失败"]);
      [weakPicker dismissViewControllerAnimated:YES completion:nil];
      [weakPicker hideProgressHUD];
    }];
  }];
  
  __weak TZImagePickerController *weakPickerVc = imagePickerVc;
  [imagePickerVc setImagePickerControllerDidCancelHandle:^{
    callback(@[@"取消"]);
    [weakPicker dismissViewControllerAnimated:YES completion:nil];
    [weakPickerVc hideProgressHUD];
  }];
  [[self topViewController] presentViewController:imagePickerVc animated:YES completion:nil];
}

- (void)reSortList: (NSArray *) order {
  NSLog(@"before___reSortList:%@",_selectedAssetsCache);
  
  NSMutableArray* cache = [NSMutableArray array];
//  [cache insertObject:@"1222" atIndex:1];
  
  NSLog(@"order.count:%@",order);
  
  for (int i=0; i<order.count; i++) {
    NSInteger cacheIndex = [order[i] intValue];
    NSLog(@"index:%ld",cacheIndex);
    PHAsset *asset = _originSelectedAssets[cacheIndex];
//    NSLog(@"oooooooooo asset.hash:%s",asset.hash);
//    [_selectedAssetsCache removeObjectAtIndex:cacheIndex];
//    NSLog(@"removeObjectAtIndex___reSortList:%@",_selectedAssetsCache);
//    if(cacheIndex > i){
//      [_selectedAssetsCache insertObject:asset atIndex:i];
//      NSLog(@"insertObject___reSortList:%@",_selectedAssetsCache);
//    }else{
//      [_selectedAssetsCache insertObject:asset atIndex:i];
//      NSLog(@"insertObject___reSortList:%@",_selectedAssetsCache);
//    }
    [cache addObject:asset];
  }
  [_selectedAssetsCache removeAllObjects];
  _selectedAssetsCache = [NSMutableArray arrayWithArray:cache];
  _selectedAssets = [NSMutableArray arrayWithArray:cache];
  NSLog(@"reSortList:%@",_selectedAssetsCache);
}

- (void)pushPreviewImage: (NSInteger)index {
  NSLog(@"*********************index:%ld",index);
  PHAsset *asset = _selectedAssetsCache[index];
  BOOL isVideo = NO;
  isVideo = asset.mediaType == PHAssetMediaTypeVideo;
//          if ([[asset valueForKey:@"filename"] containsString:@"GIF"] && self.allowPickingGifSwitch.isOn && !self.allowPickingMuitlpleVideoSwitch.isOn) {
  if([[asset valueForKey:@"filename"] containsString:@"GIF"] && (false) && (true)){
    TZGifPhotoPreviewController *vc = [[TZGifPhotoPreviewController alloc] init];
    TZAssetModel *model = [TZAssetModel modelWithAsset:asset type:TZAssetModelMediaTypePhotoGif timeLength:@""];
    vc.model = model;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
//    [self presentViewController:vc animated:YES completion:nil];
    //        } else if (isVideo && !self.allowPickingMuitlpleVideoSwitch.isOn) { // perview video / 预览视频
  }else if(isVideo){
    TZVideoPlayerController *vc = [[TZVideoPlayerController alloc] init];
    TZAssetModel *model = [TZAssetModel modelWithAsset:asset type:TZAssetModelMediaTypeVideo timeLength:@""];
    vc.model = model;
    vc.modalPresentationStyle = UIModalPresentationFullScreen;
//    [self presentViewController:vc animated:YES completion:nil];
  } else { // preview photos / 预览照片
    NSLog(@"pushPreView assetName:%@",[asset valueForKey:@"filename"]);
    NSLog(@"pushPreView cache:%@",_selectedAssetsCache);
    NSLog(@"pushPreView index:%ld",index);
    TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithSelectedAssets:_selectedAssetsCache selectedPhotos:nil index:index];
    //            imagePickerVc.maxImagesCount = self.maxCountTF.text.integerValue;
    imagePickerVc.maxImagesCount = 9;
    //            imagePickerVc.allowPickingGif = self.allowPickingGifSwitch.isOn;
    imagePickerVc.allowPickingGif = false;
    imagePickerVc.autoSelectCurrentWhenDone = NO;
    //            imagePickerVc.allowPickingOriginalPhoto = self.allowPickingOriginalPhotoSwitch.isOn;
    imagePickerVc.allowPickingOriginalPhoto = NO;
    //            imagePickerVc.allowPickingMultipleVideo = self.allowPickingMuitlpleVideoSwitch.isOn;
    imagePickerVc.allowPickingMultipleVideo = NO;
    //            imagePickerVc.showSelectedIndex = self.showSelectedIndexSwitch.isOn;
    imagePickerVc.showSelectedIndex = true;
    imagePickerVc.isSelectOriginalPhoto = NO;
    imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
    [imagePickerVc setDidFinishPickingPhotosHandle:^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto) {
//      self->_selectedPhotos = [NSMutableArray arrayWithArray:photos];
//      self->_selectedAssets = [NSMutableArray arrayWithArray:assets];
//      self->_isSelectOriginalPhoto = isSelectOriginalPhoto;
//      [self->_collectionView reloadData];
//      self->_collectionView.contentSize = CGSizeMake(0, ((self->_selectedPhotos.count + 2) / 3 ) * (self->_margin + self->_itemWH));
    }];
//    [self presentViewController:imagePickerVc animated:YES completion:nil];
    [[self topViewController] presentViewController:imagePickerVc animated:YES completion:nil];
  }
}
  
  - (void)openImagePicker {
    // 照片最大可选张数
    NSInteger imageCount = [self.cameraOptions sy_integerForKey:@"imageCount"];
    // 显示内部拍照按钮
    BOOL isCamera        = [self.cameraOptions sy_boolForKey:@"isCamera"];
    BOOL isCrop          = [self.cameraOptions sy_boolForKey:@"isCrop"];
    BOOL isGif           = [self.cameraOptions sy_boolForKey:@"isGif"];
    BOOL showCropCircle  = [self.cameraOptions sy_boolForKey:@"showCropCircle"];
    //    BOOL isRecordSelected = [self.cameraOptions sy_boolForKey:@"isRecordSelected"];
    
    BOOL isRecordSelected = YES;
    BOOL allowPickingOriginalPhoto = [self.cameraOptions sy_boolForKey:@"allowPickingOriginalPhoto"];
    BOOL allowPickingMultipleVideo = [self.cameraOptions sy_boolForKey:@"allowPickingMultipleVideo"];
    BOOL sortAscendingByModificationDate = [self.cameraOptions sy_boolForKey:@"sortAscendingByModificationDate"];
    NSInteger CropW      = [self.cameraOptions sy_integerForKey:@"CropW"];
    NSInteger CropH      = [self.cameraOptions sy_integerForKey:@"CropH"];
    NSInteger circleCropRadius = [self.cameraOptions sy_integerForKey:@"circleCropRadius"];
    NSInteger   quality  = [self.cameraOptions sy_integerForKey:@"quality"];
    
    if((true)){
      NSLog(@"ImagePicker new code:@%ld",imageCount);
      TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:imageCount columnNumber:4 delegate:self pushPhotoPickerVc:YES];
      
      // imagePickerVc.barItemTextColor = [UIColor blackColor];
      // [imagePickerVc.navigationBar setTitleTextAttributes:@{NSForegroundColorAttributeName : [UIColor blackColor]}];
      // imagePickerVc.navigationBar.tintColor = [UIColor blackColor];
      // imagePickerVc.naviBgColor = [UIColor whiteColor];
      // imagePickerVc.navigationBar.translucent = NO;
      
#pragma mark - 五类个性化设置，这些参数都可以不传，此时会走默认设置
      imagePickerVc.isSelectOriginalPhoto = NO;
      
      NSLog(@"_selectedAssets:%@",_selectedAssets);
      //    if (self.maxCountTF.text.integerValue > 1) {
      // 1.设置目前已经选中的图片数组
      imagePickerVc.selectedAssets = _selectedAssets; // 目前已经选中的图片数组
      //    }
      //    imagePickerVc.allowTakePicture = self.showTakePhotoBtnSwitch.isOn; // 在内部显示拍照按钮
      //    imagePickerVc.allowTakeVideo = self.showTakeVideoBtnSwitch.isOn;   // 在内部显示拍视频按
      imagePickerVc.allowTakePicture = true;
      imagePickerVc.allowTakeVideo = NO;
      imagePickerVc.videoMaximumDuration = 10; // 视频最大拍摄时间
      [imagePickerVc setUiImagePickerControllerSettingBlock:^(UIImagePickerController *imagePickerController) {
        imagePickerController.videoQuality = UIImagePickerControllerQualityTypeHigh;
      }];
      imagePickerVc.autoSelectCurrentWhenDone = NO;
      
      // imagePickerVc.photoWidth = 1600;
      // imagePickerVc.photoPreviewMaxWidth = 1600;
      
      // 2. Set the appearance
      // 2. 在这里设置imagePickerVc的外观
      // imagePickerVc.navigationBar.barTintColor = [UIColor greenColor];
      // imagePickerVc.oKButtonTitleColorDisabled = [UIColor lightGrayColor];
      // imagePickerVc.oKButtonTitleColorNormal = [UIColor greenColor];
      // imagePickerVc.navigationBar.translucent = NO;
      imagePickerVc.iconThemeColor = [UIColor colorWithRed:31 / 255.0 green:185 / 255.0 blue:34 / 255.0 alpha:1.0];
      imagePickerVc.showPhotoCannotSelectLayer = YES;
      imagePickerVc.cannotSelectLayerColor = [[UIColor whiteColor] colorWithAlphaComponent:0.8];
      /*
       [imagePickerVc setPhotoPickerPageUIConfigBlock:^(UICollectionView *collectionView, UIView *bottomToolBar, UIButton *previewButton, UIButton *originalPhotoButton, UILabel *originalPhotoLabel, UIButton *doneButton, UIImageView *numberImageView, UILabel *numberLabel, UIView *divideLine) {
       [doneButton setTitleColor:[UIColor redColor] forState:UIControlStateNormal];
       }];
       */
      /*
       [imagePickerVc setAssetCellDidSetModelBlock:^(TZAssetCell *cell, UIImageView *imageView, UIImageView *selectImageView, UILabel *indexLabel, UIView *bottomView, UILabel *timeLength, UIImageView *videoImgView) {
       cell.contentView.clipsToBounds = YES;
       cell.contentView.layer.cornerRadius = cell.contentView.tz_width * 0.5;
       }];
       */
      
      // 3. Set allow picking video & photo & originalPhoto or not
      // 3. 设置是否可以选择视频/图片/原图
      //    imagePickerVc.allowPickingVideo = self.allowPickingVideoSwitch.isOn;
      //    imagePickerVc.allowPickingImage = self.allowPickingImageSwitch.isOn;
      //    imagePickerVc.allowPickingOriginalPhoto = self.allowPickingOriginalPhotoSwitch.isOn;
      //    imagePickerVc.allowPickingGif = self.allowPickingGifSwitch.isOn;
      //    imagePickerVc.allowPickingMultipleVideo = self.allowPickingMuitlpleVideoSwitch.isOn; // 是否可以多选视频
      
      imagePickerVc.allowPickingVideo = true;
      imagePickerVc.allowPickingImage = true;
      imagePickerVc.allowPickingOriginalPhoto = NO;
      imagePickerVc.allowPickingGif = false;
      imagePickerVc.allowPickingMultipleVideo =false;
      
      // 4. 照片排列按修改时间升序
      //    imagePickerVc.sortAscendingByModificationDate = self.sortAscendingSwitch.isOn;
      imagePickerVc.sortAscendingByModificationDate = NO;
      
      // imagePickerVc.minImagesCount = 3;
      // imagePickerVc.alwaysEnableDoneBtn = YES;
      
      // imagePickerVc.minPhotoWidthSelectable = 3000;
      // imagePickerVc.minPhotoHeightSelectable = 2000;
      
      /// 5. Single selection mode, valid when maxImagesCount = 1
      /// 5. 单选模式,maxImagesCount为1时才生效
      imagePickerVc.showSelectBtn = NO;
      //    imagePickerVc.allowCrop = self.allowCropSwitch.isOn;
      imagePickerVc.allowCrop = false;
      //    imagePickerVc.needCircleCrop = self.needCircleCropSwitch.isOn;
      imagePickerVc.needCircleCrop = false;
      // 设置竖屏下的裁剪尺寸
      //        NSInteger left = 30;
      //        NSInteger widthHeight = self.view.tz_width - 2 * left;
      //        NSInteger top = (self.view.tz_height - widthHeight) / 2;
      //        imagePickerVc.cropRect = CGRectMake(left, top, widthHeight, widthHeight);
      //        imagePickerVc.scaleAspectFillCrop = YES;
      // 设置横屏下的裁剪尺寸
      // imagePickerVc.cropRectLandscape = CGRectMake((self.view.tz_height - widthHeight) / 2, left, widthHeight, widthHeight);
      /*
       [imagePickerVc setCropViewSettingBlock:^(UIView *cropView) {
       cropView.layer.borderColor = [UIColor redColor].CGColor;
       cropView.layer.borderWidth = 2.0;
       }];*/
      
      // imagePickerVc.allowPreview = NO;
      // 自定义导航栏上的返回按钮
      /*
       [imagePickerVc setNavLeftBarButtonSettingBlock:^(UIButton *leftButton){
       [leftButton setImage:[UIImage imageNamed:@"back"] forState:UIControlStateNormal];
       [leftButton setImageEdgeInsets:UIEdgeInsetsMake(0, -10, 0, 20)];
       }];
       imagePickerVc.delegate = self;
       */
      
      // Deprecated, Use statusBarStyle
      // imagePickerVc.isStatusBarDefault = NO;
      imagePickerVc.statusBarStyle = UIStatusBarStyleLightContent;
      
      // 设置是否显示图片序号
      //    imagePickerVc.showSelectedIndex = self.showSelectedIndexSwitch.isOn;
      imagePickerVc.showSelectedIndex = true;
      
      // 设置拍照时是否需要定位，仅对选择器内部拍照有效，外部拍照的，请拷贝demo时手动把pushImagePickerController里定位方法的调用删掉
      // imagePickerVc.allowCameraLocation = NO;
      
      // 自定义gif播放方案
      [[TZImagePickerConfig sharedInstance] setGifImagePlayBlock:^(TZPhotoPreviewView *view, UIImageView *imageView, NSData *gifData, NSDictionary *info) {
        FLAnimatedImage *animatedImage = [FLAnimatedImage animatedImageWithGIFData:gifData];
        FLAnimatedImageView *animatedImageView;
        for (UIView *subview in imageView.subviews) {
          if ([subview isKindOfClass:[FLAnimatedImageView class]]) {
            animatedImageView = (FLAnimatedImageView *)subview;
            animatedImageView.frame = imageView.bounds;
            animatedImageView.animatedImage = nil;
          }
        }
        if (!animatedImageView) {
          animatedImageView = [[FLAnimatedImageView alloc] initWithFrame:imageView.bounds];
          animatedImageView.runLoopMode = NSDefaultRunLoopMode;
          [imageView addSubview:animatedImageView];
        }
        animatedImageView.animatedImage = animatedImage;
      }];
      
      // 设置首选语言 / Set preferred language
      // imagePickerVc.preferredLanguage = @"zh-Hans";
      
#pragma mark - 到这里为止
      
      // You can get the photos by block, the same as by delegate.
      // 你可以通过block或者代理，来得到用户选择的照片.
      [imagePickerVc setDidFinishPickingPhotosHandle:^(NSArray<UIImage *> *photos, NSArray *assets, BOOL isSelectOriginalPhoto) {
        
      }];
      
      imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
      //        [self presentViewController:imagePickerVc animated:YES completion:nil];
      
      __weak TZImagePickerController *weakPicker = imagePickerVc;
      [imagePickerVc setDidFinishPickingPhotosWithInfosHandle:^(NSArray<UIImage *> *photos,NSArray *assets,BOOL isSelectOriginalPhoto,NSArray<NSDictionary *> *infos) {
        if (isRecordSelected) {
          self.selectedAssets = [NSMutableArray arrayWithArray:assets];
        }
        self.selectedAssetsCache = [NSMutableArray  arrayWithArray:assets];
        self.originSelectedAssets = [NSMutableArray arrayWithArray:assets];
        NSLog(@"++++++++++++++++++++++++++%@",assets);
        [weakPicker showProgressHUD];
        if (imageCount == 1 && isCrop) {
          [self invokeSuccessWithResult:@[[self handleCropImage:photos[0] phAsset:assets[0] quality:quality]]];
        } else {
          [infos enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self handleAssets:assets photos:photos quality:quality isSelectOriginalPhoto:isSelectOriginalPhoto completion:^(NSArray *selecteds) {
              self.selectedPhotos = [NSMutableArray arrayWithArray:selecteds];
              NSLog(@"++++++++++++++_selectedPhotos:%@",self.selectedPhotos);
              [self invokeSuccessWithResult:selecteds];
            } fail:^(NSError *error) {
              
            }];
          }];
        }
        [weakPicker hideProgressHUD];
      }];
      
      __weak TZImagePickerController *weakPickerVc = imagePickerVc;
      [imagePickerVc setImagePickerControllerDidCancelHandle:^{
        [self invokeError];
        [weakPickerVc hideProgressHUD];
      }];
      
      
      [[self topViewController] presentViewController:imagePickerVc animated:YES completion:nil];
    }else{
      
      NSLog(@"ImagePicker origin code");
      TZImagePickerController *imagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:imageCount delegate:self];
      
      imagePickerVc.maxImagesCount = imageCount;
      imagePickerVc.allowPickingGif = isGif; // 允许GIF
      imagePickerVc.allowTakePicture = isCamera; // 允许用户在内部拍照
      imagePickerVc.allowPickingVideo = NO; // 不允许视频
      imagePickerVc.allowPickingOriginalPhoto = allowPickingOriginalPhoto; // 允许原图
      imagePickerVc.sortAscendingByModificationDate = sortAscendingByModificationDate;
      imagePickerVc.alwaysEnableDoneBtn = YES;
      imagePickerVc.allowPickingMultipleVideo = isGif ? YES : allowPickingMultipleVideo;
      imagePickerVc.allowCrop = isCrop;   // 裁剪
      imagePickerVc.modalPresentationStyle = UIModalPresentationFullScreen;
      
      if (isRecordSelected) {
        imagePickerVc.selectedAssets = self.selectedAssets; // 当前已选中的图片
      }
      
      if (imageCount == 1) {
        // 单选模式
        imagePickerVc.showSelectBtn = NO;
        
        if(isCrop){
          if(showCropCircle) {
            imagePickerVc.needCircleCrop = showCropCircle; //圆形裁剪
            imagePickerVc.circleCropRadius = circleCropRadius; //圆形半径
          } else {
            CGFloat x = ([[UIScreen mainScreen] bounds].size.width - CropW) / 2;
            CGFloat y = ([[UIScreen mainScreen] bounds].size.height - CropH) / 2;
            imagePickerVc.cropRect = CGRectMake(x,y,CropW,CropH);
          }
        }
      }
      
      __weak TZImagePickerController *weakPicker = imagePickerVc;
      [imagePickerVc setDidFinishPickingPhotosWithInfosHandle:^(NSArray<UIImage *> *photos,NSArray *assets,BOOL isSelectOriginalPhoto,NSArray<NSDictionary *> *infos) {
        if (isRecordSelected) {
          self.selectedAssets = [NSMutableArray arrayWithArray:assets];
        }
        [weakPicker showProgressHUD];
        if (imageCount == 1 && isCrop) {
          [self invokeSuccessWithResult:@[[self handleCropImage:photos[0] phAsset:assets[0] quality:quality]]];
        } else {
          [infos enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self handleAssets:assets photos:photos quality:quality isSelectOriginalPhoto:isSelectOriginalPhoto completion:^(NSArray *selecteds) {
              [self invokeSuccessWithResult:selecteds];
            } fail:^(NSError *error) {
              
            }];
          }];
        }
        [weakPicker hideProgressHUD];
      }];
      
      __weak TZImagePickerController *weakPickerVc = imagePickerVc;
      [imagePickerVc setImagePickerControllerDidCancelHandle:^{
        [self invokeError];
        [weakPickerVc hideProgressHUD];
      }];
      
      [[self topViewController] presentViewController:imagePickerVc animated:YES completion:nil];
    }
  }
  
  - (UIImagePickerController *)imagePickerVc {
    if (_imagePickerVc == nil) {
      _imagePickerVc = [[UIImagePickerController alloc] init];
      _imagePickerVc.delegate = self;
    }
    return _imagePickerVc;
  }
  
#pragma mark - UIImagePickerController
  - (void)takePhoto {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied) {
      // 无相机权限 做一个友好的提示
      UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法使用相机" message:@"请在iPhone的""设置-隐私-相机""中允许访问相机" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
      [alert show];
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
      // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
      [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
        if (granted) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self takePhoto];
          });
        }
      }];
      // 拍照之前还需要检查相册权限
    } else if ([PHPhotoLibrary authorizationStatus] == 2) { // 已被拒绝，没有相册权限，将无法保存拍的照片
      UIAlertView * alert = [[UIAlertView alloc]initWithTitle:@"无法访问相册" message:@"请在iPhone的""设置-隐私-相册""中允许访问相册" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:@"设置", nil];
      [alert show];
    } else if ([PHPhotoLibrary authorizationStatus] == 0) { // 未请求过相册权限
      [[TZImageManager manager] requestAuthorizationWithCompletion:^{
        [self takePhoto];
      }];
    } else {
      [self pushImagePickerController];
    }
  }
  
  // 调用相机
  - (void)pushImagePickerController {
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable: UIImagePickerControllerSourceTypeCamera]) {
      self.imagePickerVc.sourceType = sourceType;
      [[self topViewController] presentViewController:self.imagePickerVc animated:YES completion:nil];
    } else {
      NSLog(@"模拟器中无法打开照相机,请在真机中使用");
    }
  }
  
  - (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
      NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
      if ([type isEqualToString:@"public.image"]) {
        
        TZImagePickerController *tzImagePickerVc = [[TZImagePickerController alloc] initWithMaxImagesCount:1 delegate:nil];
        tzImagePickerVc.sortAscendingByModificationDate = NO;
        [tzImagePickerVc showProgressHUD];
        UIImage *image = [info objectForKey:UIImagePickerControllerOriginalImage];
        
        // save photo and get asset / 保存图片，获取到asset
        [[TZImageManager manager] savePhotoWithImage:image location:NULL completion:^(PHAsset *asset, NSError *error){
          if (error) {
            [tzImagePickerVc hideProgressHUD];
            NSLog(@"图片保存失败 %@",error);
          } else {
            [tzImagePickerVc hideProgressHUD];
            
            TZAssetModel *assetModel = [[TZImageManager manager] createModelWithAsset:asset];
            BOOL isCrop          = [self.cameraOptions sy_boolForKey:@"isCrop"];
            BOOL showCropCircle  = [self.cameraOptions sy_boolForKey:@"showCropCircle"];
            NSInteger CropW      = [self.cameraOptions sy_integerForKey:@"CropW"];
            NSInteger CropH      = [self.cameraOptions sy_integerForKey:@"CropH"];
            NSInteger circleCropRadius = [self.cameraOptions sy_integerForKey:@"circleCropRadius"];
            NSInteger   quality = [self.cameraOptions sy_integerForKey:@"quality"];
            
            if (isCrop) {
              TZImagePickerController *imagePicker = [[TZImagePickerController alloc] initCropTypeWithAsset:assetModel.asset photo:image completion:^(UIImage *cropImage, id asset) {
                [self invokeSuccessWithResult:@[[self handleCropImage:cropImage phAsset:asset quality:quality]]];
              }];
              imagePicker.allowPickingImage = YES;
              if(showCropCircle) {
                imagePicker.needCircleCrop = showCropCircle; //圆形裁剪
                imagePicker.circleCropRadius = circleCropRadius; //圆形半径
              } else {
                CGFloat x = ([[UIScreen mainScreen] bounds].size.width - CropW) / 2;
                CGFloat y = ([[UIScreen mainScreen] bounds].size.height - CropH) / 2;
                imagePicker.cropRect = CGRectMake(x,y,CropW,CropH);
              }
              [[self topViewController] presentViewController:imagePicker animated:YES completion:nil];
            } else {
              [self invokeSuccessWithResult:@[[self handleCropImage:image phAsset:asset quality:quality]]];
            }
          }
        }];
      }
    }];
  }
  
  - (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self invokeError];
    if ([picker isKindOfClass:[UIImagePickerController class]]) {
      [picker dismissViewControllerAnimated:YES completion:nil];
    }
  }
  
#pragma mark - UIAlertViewDelegate
  - (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) { // 去设置界面，开启相机访问权限
      [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
    }
  }
  
  - (BOOL)isAssetCanSelect:(PHAsset *)asset {
    BOOL allowPickingGif = [self.cameraOptions sy_boolForKey:@"isGif"];
    BOOL isGIF = [[TZImageManager manager] getAssetType:asset] == TZAssetModelMediaTypePhotoGif;
    if (!allowPickingGif && isGIF) {
      return NO;
    }
    return YES;
  }
  
  /// 异步处理获取图片
  - (void)handleAssets:(NSArray *)assets photos:(NSArray*)photos quality:(CGFloat)quality isSelectOriginalPhoto:(BOOL)isSelectOriginalPhoto completion:(void (^)(NSArray *selecteds))completion fail:(void(^)(NSError *error))fail {
    NSMutableArray *selectedPhotos = [NSMutableArray array];
    
    [assets enumerateObjectsUsingBlock:^(PHAsset * _Nonnull asset, NSUInteger idx, BOOL * _Nonnull stop) {
      if (asset.mediaType == PHAssetMediaTypeVideo) {
        [[TZImageManager manager] getVideoOutputPathWithAsset:asset presetName:AVAssetExportPresetHighestQuality success:^(NSString *outputPath) {
          [selectedPhotos addObject:[self handleVideoData:outputPath asset:asset coverImage:photos[idx] quality:quality]];
          if ([selectedPhotos count] == [assets count]) {
            completion(selectedPhotos);
          }
          if (idx + 1 == [assets count] && [selectedPhotos count] != [assets count]) {
            fail(nil);
          }
        } failure:^(NSString *errorMessage, NSError *error) {
          
        }];
      } else {
        BOOL isGIF = [[TZImageManager manager] getAssetType:asset] == TZAssetModelMediaTypePhotoGif;
        if (isGIF || isSelectOriginalPhoto) {
          [[TZImageManager manager] requestImageDataForAsset:asset completion:^(NSData *imageData, NSString *dataUTI, UIImageOrientation orientation, NSDictionary *info) {
            [selectedPhotos addObject:[self handleOriginalPhotoData:imageData phAsset:asset isGIF:isGIF quality:quality]];
            if ([selectedPhotos count] == [assets count]) {
              completion(selectedPhotos);
            }
            if (idx + 1 == [assets count] && [selectedPhotos count] != [assets count]) {
              fail(nil);
            }
          } progressHandler:^(double progress, NSError *error, BOOL *stop, NSDictionary *info) {
            
          }];
        } else {
          [selectedPhotos addObject:[self handleCropImage:photos[idx] phAsset:asset quality:quality]];
          if ([selectedPhotos count] == [assets count]) {
            completion(selectedPhotos);
          }
        }
      }
    }];
  }
  
  /// 处理裁剪图片数据
  - (NSDictionary *)handleCropImage:(UIImage *)image phAsset:(PHAsset *)phAsset quality:(CGFloat)quality {
    [self createDir];
    
    NSMutableDictionary *photo  = [NSMutableDictionary dictionary];
    NSString *filename = [NSString stringWithFormat:@"%@%@", [[NSUUID UUID] UUIDString], [phAsset valueForKey:@"filename"]];
    NSString *fileExtension    = [filename pathExtension];
    NSMutableString *filePath = [NSMutableString string];
    BOOL isPNG = [fileExtension hasSuffix:@"PNG"] || [fileExtension hasSuffix:@"png"];
    
    if (isPNG) {
      [filePath appendString:[NSString stringWithFormat:@"%@SyanImageCaches/%@", NSTemporaryDirectory(), filename]];
    } else {
      [filePath appendString:[NSString stringWithFormat:@"%@SyanImageCaches/%@.jpg", NSTemporaryDirectory(), [filename stringByDeletingPathExtension]]];
    }
    
    NSData *writeData = isPNG ? UIImagePNGRepresentation(image) : UIImageJPEGRepresentation(image, quality/100);
    [writeData writeToFile:filePath atomically:YES];
    
    photo[@"uri"]       = filePath;
    photo[@"width"]     = @(image.size.width);
    photo[@"height"]    = @(image.size.height);
    NSInteger size = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil].fileSize;
    photo[@"size"] = @(size);
    photo[@"mediaType"] = @(phAsset.mediaType);
    if ([self.cameraOptions sy_boolForKey:@"enableBase64"]) {
      photo[@"base64"] = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", [writeData base64EncodedStringWithOptions:0]];
    }
    
    return photo;
  }
  
  /// 处理原图数据
  - (NSDictionary *)handleOriginalPhotoData:(NSData *)data phAsset:(PHAsset *)phAsset isGIF:(BOOL)isGIF quality:(CGFloat)quality {
    [self createDir];
    
    NSMutableDictionary *photo  = [NSMutableDictionary dictionary];
    NSString *filename = [NSString stringWithFormat:@"%@%@", [[NSUUID UUID] UUIDString], [phAsset valueForKey:@"filename"]];
    NSString *fileExtension    = [filename pathExtension];
    UIImage *image = nil;
    NSData *writeData = nil;
    NSMutableString *filePath = [NSMutableString string];
    
    BOOL isPNG = [fileExtension hasSuffix:@"PNG"] || [fileExtension hasSuffix:@"png"];
    
    if (isGIF) {
      image = [UIImage sd_tz_animatedGIFWithData:data];
      writeData = data;
    } else {
      image = [UIImage imageWithData: data];
      writeData = isPNG ? UIImagePNGRepresentation(image) : UIImageJPEGRepresentation(image, quality/100);
    }
    
    if (isPNG || isGIF) {
      [filePath appendString:[NSString stringWithFormat:@"%@SyanImageCaches/%@", NSTemporaryDirectory(), filename]];
    } else {
      [filePath appendString:[NSString stringWithFormat:@"%@SyanImageCaches/%@.jpg", NSTemporaryDirectory(), [filename stringByDeletingPathExtension]]];
    }
    
    [writeData writeToFile:filePath atomically:YES];
    
    photo[@"uri"]       = filePath;
    photo[@"width"]     = @(image.size.width);
    photo[@"height"]    = @(image.size.height);
    NSInteger size      = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:nil].fileSize;
    photo[@"size"]      = @(size);
    photo[@"mediaType"] = @(phAsset.mediaType);
    if ([self.cameraOptions sy_boolForKey:@"enableBase64"] && !isGIF) {
      photo[@"base64"] = [NSString stringWithFormat:@"data:image/jpeg;base64,%@", [writeData base64EncodedStringWithOptions:0]];
    }
    
    return photo;
  }
  
  /// 处理视频数据
  - (NSDictionary *)handleVideoData:(NSString *)outputPath asset:(PHAsset *)asset coverImage:(UIImage *)coverImage quality:(CGFloat)quality {
    NSMutableDictionary *video = [NSMutableDictionary dictionary];
    video[@"uri"] = outputPath;
    video[@"fileName"] = [asset valueForKey:@"filename"];
    NSInteger size = [[NSFileManager defaultManager] attributesOfItemAtPath:outputPath error:nil].fileSize;
    video[@"size"] = @(size);
    video[@"duration"] = @(asset.duration);
    video[@"width"] = @(asset.pixelWidth);
    video[@"height"] = @(asset.pixelHeight);
    video[@"type"] = @"video";
    video[@"mime"] = @"video/mp4";
    // iOS only
    video[@"coverUri"] = [self handleCropImage:coverImage phAsset:asset quality:quality][@"uri"];
    video[@"favorite"] = @(asset.favorite);
    video[@"mediaType"] = @(asset.mediaType);
    
    return video;
  }
  
  /// 创建SyanImageCaches缓存目录
  - (BOOL)createDir {
    NSString * path = [NSString stringWithFormat:@"%@SyanImageCaches", NSTemporaryDirectory()];;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir;
    if  (![fileManager fileExistsAtPath:path isDirectory:&isDir]) {
      //先判断目录是否存在，不存在才创建
      BOOL res = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
      return res;
    } else return NO;
  }
  
  
  - (void)invokeSuccessWithResult:(NSArray *)photos {
    if (self.callback) {
      self.callback(@[[NSNull null], photos]);
      self.callback = nil;
    }
    if (self.resolveBlock) {
      self.resolveBlock(photos);
      self.resolveBlock = nil;
    }
  }
  
  - (void)invokeError {
    if (self.callback) {
      self.callback(@[@"取消"]);
      self.callback = nil;
    }
    if (self.rejectBlock) {
      self.rejectBlock(@"", @"取消", nil);
      self.rejectBlock = nil;
    }
  }
  
  + (BOOL)requiresMainQueueSetup
  {
    return YES;
  }
  
  - (UIViewController *)topViewController {
    UIViewController *rootViewController = RCTPresentedViewController();
    return rootViewController;
  }
  
  - (dispatch_queue_t)methodQueue {
    return dispatch_get_main_queue();
  }
  
  @end
