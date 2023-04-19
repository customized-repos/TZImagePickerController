//
//  CompressHelper.m
//  CompressTest
//
//  Created by IMAC on 2019/7/4.
//  Copyright © 2019 leslie. All rights reserved.
//

#import "CompressHelper.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>

@implementation CompressSetting

- (instancetype)initWithInputURL:(NSURL *)inputURL outputURL:(NSURL *)outputURL {
    self = [super init];
    if (self) {
        _inputURL = inputURL;
        _outputURL = outputURL;
        _videoQuality = VideoQualityTypeHigh;
        _videoFrameRate = 30;
        _audioSampleRate = 44100;
        _videoBitRate = 3100 * 1000;
    }
    return self;
}
- (instancetype)initWithInputAsst:(AVAsset *)inputAsset outputURL:(NSURL *)outputURL {
    self = [super init];
       if (self) {
           _inputAsset = inputAsset;
           _outputURL = outputURL;
           _videoQuality = VideoQualityTypeHigh;
           _videoFrameRate = 30;
           _audioSampleRate = 44100;
           _videoBitRate = 3100 * 1000;
       }
       return self;
}

/// 最低码率
- (int)standRateByVideoTrack:(AVAssetTrack*)videoTrack {
    /// 压缩视频最低码率
    int standRate = 0;
    if (_videoQuality == VideoQualityTypeHigh) {
        standRate = 3500 * 1000;
    }
    else if (_videoQuality == VideoQualityTypeStandard) {
        standRate = 2300 * 1000;
    }
    else {
        standRate = 1000 * 1000;
    }
    return standRate;
}

- (CGSize)standVideoSize {
    CGSize refSize;
    switch (_videoQuality) {
        case VideoQualityTypeHigh:
            refSize = CGSizeMake(1920, 1080);
            break;
        case VideoQualityTypeStandard:
            refSize = CGSizeMake(1280, 720);
            break;
        case VideoQualityTypeLow:
            refSize = CGSizeMake(640, 480);
            break;
    }
    return refSize;
}

- (int)calculateAverageBitRateByVideoTrack:(AVAssetTrack*)videoTrack videoSize:(CGSize)videoSize  {
    int standRate = [self standRateByVideoTrack:videoTrack];
    if (videoTrack.estimatedDataRate < standRate) {
        return videoTrack.estimatedDataRate;
    } else {
        return standRate;
    }
//    CGFloat maxFrameRate = (CGFloat)((int)videoTrack.minFrameDuration.timescale / videoTrack.minFrameDuration.value);
//    CGSize naturalSize = videoTrack.naturalSize;
//    //假设帧率减小清晰度不变的情况下(增加码率)，根据原视频质量减小码率
//    CGFloat factor = fmin((videoSize.width * videoSize.height) / (naturalSize.width * naturalSize.height) * maxFrameRate / (_videoFrameRate > 0 ? _videoFrameRate : maxFrameRate), 1.0);
//    CGFloat ouputVideoBitRate = factor * (CGFloat)videoTrack.estimatedDataRate * [self getExtraCompressionFactorByVideoTrack:videoTrack videoSize:videoSize];
//    return (int)ouputVideoBitRate;
}

- (CGFloat)getExtraCompressionFactorByVideoTrack:(AVAssetTrack *)videoTrack videoSize:(CGSize)videoSize  {
    CGFloat factor = 3.0 / ((CGFloat)videoTrack.estimatedDataRate / (videoSize.width * videoSize.height));//参看往上中画质码率:像素=3:1
    return fmin(factor, 1.0);
}

- (CGSize)getVideoSizeByVideoTrack:(AVAssetTrack *)videoTrack  {
    CGSize naturalSize = videoTrack.naturalSize;
    CGSize refSize = [self standVideoSize];
    // 没有达到该质量，直接返回
    if (naturalSize.width * naturalSize.height < refSize.width * refSize.height) {
        return naturalSize;
    }
    CGFloat lagerSide = fmax(refSize.width, refSize.height);
    CGFloat smallerSide = fmin(refSize.width, refSize.height);
    if (naturalSize.width >= lagerSide) {
        return CGSizeMake(lagerSide, lagerSide / naturalSize.width * naturalSize.height);
    } else if (naturalSize.height >= lagerSide) {
        return CGSizeMake(lagerSide / naturalSize.height * naturalSize.width, lagerSide);
    } else if (naturalSize.width < naturalSize.height) {
        return CGSizeMake(smallerSide, smallerSide / naturalSize.width * naturalSize.height);
    } else {
        return CGSizeMake(smallerSide / naturalSize.height * naturalSize.width, smallerSide);
    }
}

//- (BOOL)shouldCompress:(AVAssetTrack *)videoTrack {
//    CGSize naturalSize = videoTrack.naturalSize;
//    CGSize refSize = [self standVideoSize];
//
//    CGFloat largeNatSide = fmax(naturalSize.width, naturalSize.height);
//    CGFloat largeRefSide = fmax(refSize.width, refSize.height);
//    return NO;
//}
@end

@implementation CompressHelper

+ (void)compressVideoBySetting:(CompressSetting *)setting completionHandler:(void (^)(NSError * _Nullable error))handler compressProgressHandeler:(void (^)(float progress))progressHandeler {
    if ([[NSFileManager defaultManager] fileExistsAtPath:[setting.outputURL path]]) {
        NSError *error;
        [[NSFileManager defaultManager] removeItemAtURL:setting.outputURL error:&error];
    }
    dispatch_queue_t inputSerialQueue = dispatch_queue_create("inputSerialQueue", DISPATCH_QUEUE_SERIAL);
    AVAsset *asset;
    if (setting.inputURL != nil) {
        asset = [AVAsset assetWithURL:setting.inputURL];
    } else if (setting.inputAsset != nil) {
        asset = setting.inputAsset;
    } else {
        /// 初始化异常
        handler([[NSError alloc] initWithDomain:@"初始化资源没有配置正确" code:0 userInfo:nil]);
        return;
    }
    NSError *error;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:asset error:&error];
    if (error) {
        handler(error);
        return;
    }
    AVAssetWriter *assetWriter = [AVAssetWriter assetWriterWithURL:setting.outputURL fileType:AVFileTypeMPEG4 error:&error];
    if (error) {
        handler(error);
        return;
    }
    AVAssetTrack *videoTrack = [asset tracksWithMediaType:AVMediaTypeVideo].firstObject;
    if (!videoTrack) {
        handler([NSError errorWithDomain:@"TZImagePickerController.CompressHelper"
                                    code:0
                                userInfo:@{
                                           NSLocalizedDescriptionKey: NSLocalizedString(@"Obtain VideoTrack Failed.", nil)
                                           }]);
        return;
    }
    AVAssetReaderVideoCompositionOutput *videoOutput = [[AVAssetReaderVideoCompositionOutput alloc] initWithVideoTracks:@[videoTrack] videoSettings:[self videoReaderOutputSettings]];
    if (setting.videoFrameRate > 0) {
        // 固定帧率
        AVMutableVideoCompositionLayerInstruction *videolayerInstruction = [AVMutableVideoCompositionLayerInstruction videoCompositionLayerInstructionWithAssetTrack:videoTrack];
        AVMutableVideoCompositionInstruction *videoCompositionInstruction = [[AVMutableVideoCompositionInstruction alloc] init];
        videoCompositionInstruction.timeRange = CMTimeRangeMake(kCMTimeZero, asset.duration);
        videoCompositionInstruction.layerInstructions = @[videolayerInstruction];
        AVMutableVideoComposition *videoComposition = [[AVMutableVideoComposition alloc] init];
        videoComposition.renderSize = CGSizeMake(videoTrack.naturalSize.width, videoTrack.naturalSize.height);
        videoComposition.frameDuration = CMTimeMake(1, setting.videoFrameRate);
        videoComposition.instructions = @[videoCompositionInstruction];
        videoOutput.videoComposition = videoComposition;
    }
    AVAssetWriterInput *videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:[self videoWriterOutputSettingsByCompressSetting:setting videoTrack:videoTrack]];
    videoInput.transform = [self videoTransformByVideoTrack:videoTrack];// 旋转视频
    if ([assetReader canAddOutput:videoOutput]) {
        [assetReader addOutput:videoOutput];
    }
    if ([assetWriter canAddInput:videoInput]) {
        [assetWriter addInput:videoInput];
    }
    /// 是否有音频轨道
    bool haveAudioTrack = YES;
    AVAssetTrack *audioTrack = [asset tracksWithMediaType:AVMediaTypeAudio].firstObject;
    AVAssetReaderTrackOutput *audioOutput;
    AVAssetWriterInput *audioInput;
    if (!audioTrack) {
        haveAudioTrack = NO;
    }
    if (haveAudioTrack) {
        audioOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:[self audioReaderOutputSettings]];
        audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:[self audioWriterOutputSettingsByCompressSetting:setting audioTrack:audioTrack]];
        if ([assetReader canAddOutput:audioOutput]) {
            [assetReader addOutput:audioOutput];
        }
        if ([assetWriter canAddInput:audioInput]) {
            [assetWriter addInput:audioInput];
        }
    }

    [assetReader startReading];
    [assetWriter startWriting];
    [assetWriter startSessionAtSourceTime:kCMTimeZero];
    dispatch_group_t group = dispatch_group_create();
    dispatch_group_enter(group);
    /// 总时长
    CGFloat totalSeconds = CMTimeGetSeconds(asset.duration);
    [videoInput requestMediaDataWhenReadyOnQueue:inputSerialQueue usingBlock:^{
        while (videoInput.isReadyForMoreMediaData) {
            CMSampleBufferRef sampleBuffer;
            if (assetReader.status == AVAssetReaderStatusReading && (sampleBuffer = [videoOutput copyNextSampleBuffer])) {
                BOOL result = [videoInput appendSampleBuffer:sampleBuffer];
                CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                CGFloat currentSeconds = CMTimeGetSeconds(currentTime);
                progressHandeler(currentSeconds / totalSeconds);
                CFRelease(sampleBuffer);
                if (!result) {
                    [assetReader cancelReading];
                    dispatch_group_leave(group);
                    break;
                }
            } else {
                [videoInput markAsFinished];
                dispatch_group_leave(group);
                break;
            }
        }
    }];
    if (haveAudioTrack) {
        dispatch_group_enter(group);
        [audioInput requestMediaDataWhenReadyOnQueue:inputSerialQueue usingBlock:^{
            while (audioInput.isReadyForMoreMediaData) {
                CMSampleBufferRef sampleBuffer;
                if (assetReader.status == AVAssetReaderStatusReading && (sampleBuffer = [audioOutput copyNextSampleBuffer])) {
                    BOOL result = [audioInput appendSampleBuffer:sampleBuffer];
                    CFRelease(sampleBuffer);
                    if (!result) {
                        [assetReader cancelReading];
                        dispatch_group_leave(group);
                        break;
                    }
                } else {
                    [audioInput markAsFinished];
                    dispatch_group_leave(group);
                    break;
                }
            }
        }];
    }

    dispatch_group_notify(group, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        if (assetReader.status == AVAssetReaderStatusReading) {
            [assetReader cancelReading];
        }
        switch (assetWriter.status) {
                case AVAssetWriterStatusWriting:
            {
                [assetWriter finishWritingWithCompletionHandler:^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        handler(assetWriter.error);
                    });
                }];
            }
                break;
            default:
                if ([[NSFileManager defaultManager] fileExistsAtPath:setting.outputURL.relativePath]) {
                    [[NSFileManager defaultManager] removeItemAtURL:setting.outputURL error:nil];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler([NSError errorWithDomain:@"TZImagePickerController.CompressHelper"
                                                code:0
                                            userInfo:@{
                                                       NSLocalizedDescriptionKey: NSLocalizedString(@"Request Media Data Failed.", nil)
                                                       }]);
                });
                break;
        }
    });
}

+ (NSDictionary *)videoReaderOutputSettings {
    return @{(NSString *)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)};
}

+ (NSDictionary *)videoWriterOutputSettingsByCompressSetting:(CompressSetting *)setting videoTrack:(AVAssetTrack *)videoTrack {
    CGSize videoSize = [setting getVideoSizeByVideoTrack:videoTrack];
    int bitRate = [setting calculateAverageBitRateByVideoTrack:videoTrack videoSize:videoSize];
    NSDictionary *compressionPropertier = @{
                                            AVVideoAverageBitRateKey: @(bitRate),
                                            AVVideoProfileLevelKey: (NSString *)kVTProfileLevel_H264_High_AutoLevel,
                                            AVVideoAllowFrameReorderingKey: @(YES)
                                            };
    NSDictionary *compressionSetting;
    if (@available(iOS 11.0, *)) {
        compressionSetting = @{
                               AVVideoCodecKey: AVVideoCodecTypeH264,
                               AVVideoWidthKey: @(videoSize.width),
                               AVVideoHeightKey: @(videoSize.height),
                               AVVideoCompressionPropertiesKey: compressionPropertier,
                               AVVideoScalingModeKey: AVVideoScalingModeResizeAspect
                               };
    } else {
        compressionSetting = @{AVVideoCodecKey: AVVideoCodecH264,
                               AVVideoWidthKey: @(videoSize.width),
                               AVVideoHeightKey: @(videoSize.height),
                               AVVideoCompressionPropertiesKey: compressionPropertier,
                               AVVideoScalingModeKey: AVVideoScalingModeResizeAspect
                               };
    }
    return compressionSetting;
}

+ (NSDictionary *)audioReaderOutputSettings {
    return @{AVFormatIDKey: @(kAudioFormatLinearPCM)};
}

+ (NSDictionary *)audioWriterOutputSettingsByCompressSetting:(CompressSetting *)setting audioTrack:(AVAssetTrack *)audioTrack {
    AudioChannelLayout layout;
    bzero(&layout, sizeof(layout));//内存清零
    CMFormatDescriptionRef formatDes = (__bridge CMFormatDescriptionRef)(audioTrack.formatDescriptions.firstObject);
    AUAudioChannelCount channelCount = 1;
    if (formatDes) {
        size_t size = sizeof(AudioFormatListItem);
        const AudioFormatListItem *originLayout = CMAudioFormatDescriptionGetFormatList(formatDes, &size);
        layout.mChannelLayoutTag = originLayout->mChannelLayoutTag;
        channelCount = originLayout->mASBD.mChannelsPerFrame;
    } else {
        layout.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    }
    /// audioBitRate固定70000
    NSDictionary *compressionSetting = @{
                                         AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                                         AVSampleRateKey: @(MIN(setting.audioSampleRate, (int)audioTrack.naturalTimeScale)),
                                         AVEncoderBitRateKey : @(70000),
                                         AVChannelLayoutKey:[NSData dataWithBytes:&layout length:sizeof(layout)],
                                         AVNumberOfChannelsKey: @(channelCount)
                                         };
    return compressionSetting;
}

+ (CGAffineTransform)videoTransformByVideoTrack:(AVAssetTrack *)videoTrack {
    CGAffineTransform videoTransform = videoTrack.preferredTransform;
    if (videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0) {
        CGAffineTransform trans = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height, 0.0);
        return CGAffineTransformRotate(trans, M_PI_2);
    }
    if (videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0) {
        CGAffineTransform trans = CGAffineTransformMakeTranslation(videoTrack.naturalSize.height, 0.0);
        return CGAffineTransformRotate(trans, -M_PI_2);
    }
    if (videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0) {
        return CGAffineTransformMakeRotation(M_PI);
    }
    return CGAffineTransformIdentity;
}

@end
