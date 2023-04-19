//
//  CompressHelper.h
//  CompressTest
//
//  Created by IMAC on 2019/7/4.
//  Copyright © 2019 leslie. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    VideoQualityTypeHigh,//>= 1920, 1080
    VideoQualityTypeStandard,//>= 1280, 720
    VideoQualityTypeLow//640, 480
} VideoQualityType;

@interface CompressSetting : NSObject
@property (nonatomic, assign) VideoQualityType videoQuality;
/// 视频帧率 '<= 0不更改视频帧率'
@property (nonatomic, assign) CGFloat videoFrameRate;
@property (nonatomic, assign) int videoBitRate;

@property (nonatomic, assign) int audioSampleRate;

@property (nonatomic, strong) NSURL *inputURL;
@property (nonatomic, strong) AVAsset *inputAsset;
@property (nonatomic, strong) NSURL *outputURL;

- (instancetype)initWithInputURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL;
- (instancetype)initWithInputAsst:(AVAsset *)inputAsset outputURL:(NSURL *)outputURL;

@end



@interface CompressHelper : NSObject

+ (void)compressVideoBySetting:(CompressSetting *)setting completionHandler:(void (^)(NSError * _Nullable error))handler compressProgressHandeler:(void (^)(float progress))progressHandeler;

@end

NS_ASSUME_NONNULL_END
