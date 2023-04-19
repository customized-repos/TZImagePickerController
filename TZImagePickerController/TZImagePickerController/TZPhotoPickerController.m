//
//  TZPhotoPickerController.m
//  TZImagePickerController
//
//  Created by 谭真 on 15/12/24.
//  Copyright © 2015年 谭真. All rights reserved.
//

#import "TZPhotoPickerController.h"
#import "TZImagePickerController.h"
#import "TZPhotoPreviewController.h"
#import "TZAssetCell.h"
#import "TZAssetModel.h"
#import "UIView+TZLayout.h"
#import "TZImageManager.h"
#import "TZVideoPlayerController.h"
#import "TZGifPhotoPreviewController.h"
#import "TZLocationManager.h"
#import "LZImageCropping.h"
#import "ZLEditVideoController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "TZImageRequestOperation.h"
#import <PhotosUI/PhotosUI.h>
@interface TZPhotoPickerController ()<UICollectionViewDataSource,UICollectionViewDelegate,UIImagePickerControllerDelegate,UINavigationControllerDelegate, PHPhotoLibraryChangeObserver> {

    NSMutableArray *_models;
    
    UIView *_bottomToolBar;
    UIButton *_previewButton;
    UIButton *_doneButton;
    UIImageView *_numberImageView;
    UILabel *_numberLabel;
    UIButton *_originalPhotoButton;
    UILabel *_originalPhotoLabel;
    UIView *_divideLine;
    
    BOOL _shouldScrollToBottom;
    BOOL _showTakePhotoBtn;
    
    CGFloat _offsetItemCount;
}
@property CGRect previousPreheatRect;
@property (nonatomic, assign) BOOL isSelectOriginalPhoto;
@property (nonatomic, strong) TZCollectionView *collectionView;
@property (nonatomic, strong) UILabel *noDataLabel;
@property (strong, nonatomic) UICollectionViewFlowLayout *layout;
@property (nonatomic, strong) UIImagePickerController *imagePickerVc;
@property (strong, nonatomic) CLLocation *location;
@property (nonatomic, strong) NSOperationQueue *operationQueue;
@property (nonatomic, assign) BOOL isSavingMedia;
@property (nonatomic, assign) BOOL isFetchingMedia;

@end

static CGSize AssetGridThumbnailSize;
static CGFloat itemMargin = 5;

@implementation TZPhotoPickerController

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (UIImagePickerController *)imagePickerVc {
    if (_imagePickerVc == nil) {
        _imagePickerVc = [[UIImagePickerController alloc] init];
        _imagePickerVc.delegate = self;
        // set appearance / 改变相册选择页的导航栏外观
        _imagePickerVc.navigationBar.barTintColor = self.navigationController.navigationBar.barTintColor;
        _imagePickerVc.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
        UIBarButtonItem *tzBarItem, *BarItem;
        if (@available(iOS 9, *)) {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[TZImagePickerController class]]];
            BarItem = [UIBarButtonItem appearanceWhenContainedInInstancesOfClasses:@[[UIImagePickerController class]]];
        } else {
            tzBarItem = [UIBarButtonItem appearanceWhenContainedIn:[TZImagePickerController class], nil];
            BarItem = [UIBarButtonItem appearanceWhenContainedIn:[UIImagePickerController class], nil];
        }
        NSDictionary *titleTextAttributes = [tzBarItem titleTextAttributesForState:UIControlStateNormal];
        [BarItem setTitleTextAttributes:titleTextAttributes forState:UIControlStateNormal];
    }
    return _imagePickerVc;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([[TZImageManager manager] authorizationStatusAuthorized] || !SYSTEM_VERSION_GREATER_THAN_15) {
        [[PHPhotoLibrary sharedPhotoLibrary] registerChangeObserver:self];
    }
    self.isFirstAppear = YES;
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    _isSelectOriginalPhoto = tzImagePickerVc.isSelectOriginalPhoto;
    _shouldScrollToBottom = YES;
    self.view.backgroundColor = [TZCutomColor whiteColor];
    // 如果仅仅选择视频 title就固定显示"选择视频"
    // 其他情况显示当前相册名称
    if (tzImagePickerVc.allowPickingImage == NO && tzImagePickerVc.allowPickingGif == NO  && tzImagePickerVc.allowPickingVideo == YES) {
        self.navigationItem.title = @"选择视频";
    } else {
        self.navigationItem.title = _model.name;
    }
    UIButton *rightButton = [UIButton buttonWithType:UIButtonTypeCustom];
    rightButton.frame = CGRectMake(0, 0, 44, 44);
    rightButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [rightButton setTitle:tzImagePickerVc.cancelBtnTitleStr forState:UIControlStateNormal];
    if (_mainColor) {
        [rightButton setTitleColor:_mainColor forState:UIControlStateNormal];
    } else {
        [rightButton setTitleColor:[UIColor colorWithRed:89/255.0 green:182/255.0 blue:215/255.0 alpha:1] forState:UIControlStateNormal];
    }
    [rightButton addTarget:tzImagePickerVc action:@selector(cancelButtonClick) forControlEvents:UIControlEventTouchUpInside];
    
    UIButton *moreItemBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    moreItemBtn.frame = CGRectMake(0, 0, 60, 44);
    moreItemBtn.titleLabel.font = [UIFont systemFontOfSize:16];
    if (tzImagePickerVc.selectMoreInfoText != nil) {
        [moreItemBtn setTitle:tzImagePickerVc.selectMoreInfoText forState:UIControlStateNormal];
    } else {
        [moreItemBtn setTitle:@"选择素材" forState:UIControlStateNormal];
    }
    [moreItemBtn setTitleColor:TZCutomColor.blackColor forState:UIControlStateNormal];
    [moreItemBtn addTarget:tzImagePickerVc action:@selector(selectedMoreMediasBtnClick)
          forControlEvents:UIControlEventTouchUpInside];
    
    UIBarButtonItem *moreItem = [[UIBarButtonItem alloc] initWithCustomView:moreItemBtn];
    UIBarButtonItem *cancelItem = [[UIBarButtonItem alloc] initWithCustomView:rightButton];

    if (@available(iOS 14, *)) {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatusForAccessLevel:PHAccessLevelReadWrite];
        if(status == PHAuthorizationStatusLimited && tzImagePickerVc.showSelectMoreInfoBtn) {
            self.navigationItem.rightBarButtonItems = @[cancelItem, moreItem];
        } else {
            self.navigationItem.rightBarButtonItems = @[cancelItem];
        }
    } else {
        self.navigationItem.rightBarButtonItems = @[cancelItem];
    }

    if (tzImagePickerVc.backImage) {
        [[UINavigationBar appearance] setBackIndicatorImage:tzImagePickerVc.backImage];
        [[UINavigationBar appearance] setBackIndicatorTransitionMaskImage:tzImagePickerVc.backImage];
    }

    if (tzImagePickerVc.navLeftBarButtonSettingBlock) {
        UIButton *leftButton = [UIButton buttonWithType:UIButtonTypeCustom];
        leftButton.frame = CGRectMake(0, 0, 44, 44);
        [leftButton addTarget:self action:@selector(navLeftBarButtonClick) forControlEvents:UIControlEventTouchUpInside];
        tzImagePickerVc.navLeftBarButtonSettingBlock(leftButton);
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:leftButton];
    } else if (tzImagePickerVc.childViewControllers.count) {
        NSString *backTitle = @"选择相册";
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:backTitle style:UIBarButtonItemStylePlain target:self action:@selector(navLeftBarButtonClick)];
        [TZCommonTools configBarButtonItem:backItem tzImagePickerVc:tzImagePickerVc];
        [tzImagePickerVc.childViewControllers firstObject].navigationItem.backBarButtonItem = backItem;
    }
    if (_model.isCameraRoll) {
        if (tzImagePickerVc.allowPickingImage && tzImagePickerVc.allowTakePicture) {
            _showTakePhotoBtn = YES;
        } else if(tzImagePickerVc.allowPickingVideo && tzImagePickerVc.allowTakeVideo) {
            _showTakePhotoBtn = YES;
        }
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeStatusBarOrientationNotification:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
    
    self.operationQueue = [[NSOperationQueue alloc] init];
    self.operationQueue.maxConcurrentOperationCount = 3;
}

- (void)fetchAssetModels {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (_isFirstAppear && !_model.models.count) {
        [tzImagePickerVc showProgressHUD];
    }
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        CGFloat systemVersion = [[[UIDevice currentDevice] systemVersion] floatValue];
        if (!tzImagePickerVc.sortAscendingByModificationDate && self->_isFirstAppear && self->_model.isCameraRoll) {
            [[TZImageManager manager] getCameraRollAlbumWithFetchAssets:YES completion:^(TZAlbumModel *model) {
                self->_model = model;
                self->_models = [NSMutableArray arrayWithArray:self->_model.models];
                [self initSubviews];
            }];
        } else if (self->_showTakePhotoBtn || self->_isFirstAppear || !self.model.models || systemVersion >= 14.0) {
            [[TZImageManager manager] getAssetsFromFetchResult:self->_model.result completion:^(NSArray<TZAssetModel *> *models) {
                self->_models = [NSMutableArray arrayWithArray:models];

                [self initSubviews];
            }];
        } else {
            self->_models = [NSMutableArray arrayWithArray:self->_model.models];
            [self initSubviews];
        }
    });
}

- (void)initSubviews {
    dispatch_async(dispatch_get_main_queue(), ^{
        TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
        [tzImagePickerVc hideProgressHUD];
        
        [self checkSelectedModels];
        [self configCollectionView];
        self->_collectionView.hidden = YES;
        [self configBottomToolBar];
        
        [self prepareScrollCollectionViewToBottom];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    tzImagePickerVc.isSelectOriginalPhoto = _isSelectOriginalPhoto;
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    TZImagePickerController *tzImagePicker = (TZImagePickerController *)self.navigationController;
    if (tzImagePicker && [tzImagePicker isKindOfClass:[TZImagePickerController class]]) {
        return tzImagePicker.statusBarStyle;
    }
    return [super preferredStatusBarStyle];
}

- (void)configCollectionView {
    if (!_collectionView) {
        _layout = [[UICollectionViewFlowLayout alloc] init];
        _collectionView = [[TZCollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:_layout];
        if (@available(iOS 13.0, *)) {
            _collectionView.backgroundColor = UIColor.tertiarySystemBackgroundColor;
        } else {
            _collectionView.backgroundColor = [UIColor whiteColor];
        }
        _collectionView.dataSource = self;
        _collectionView.delegate = self;
        _collectionView.alwaysBounceHorizontal = NO;
        _collectionView.contentInset = UIEdgeInsetsMake(itemMargin, itemMargin, itemMargin, itemMargin);
        [self.view addSubview:_collectionView];
        [_collectionView registerClass:[TZAssetCell class] forCellWithReuseIdentifier:@"TZAssetCell"];
        [_collectionView registerClass:[TZAssetCameraCell class] forCellWithReuseIdentifier:@"TZAssetCameraCell"];
        [_collectionView registerClass:[TZAssetAddMoreCell class] forCellWithReuseIdentifier:@"TZAssetAddMoreCell"];
    } else {
        [_collectionView reloadData];
    }
    
    _collectionView.contentSize = CGSizeMake(self.view.tz_width, (([self getAllCellCount] + self.columnNumber - 1) / self.columnNumber) * self.view.tz_width);
    if (_models.count == 0) {
        _noDataLabel = [UILabel new];
        _noDataLabel.textAlignment = NSTextAlignmentCenter;
        _noDataLabel.text = [NSBundle tz_localizedStringForKey:@"No Photos or Videos"];
        CGFloat rgb = 153 / 256.0;
        _noDataLabel.textColor = [UIColor colorWithRed:rgb green:rgb blue:rgb alpha:1.0];
        _noDataLabel.font = [UIFont boldSystemFontOfSize:20];
        _noDataLabel.frame = _collectionView.bounds;
        [_collectionView addSubview:_noDataLabel];
    } else if (_noDataLabel) {
        [_noDataLabel removeFromSuperview];
        _noDataLabel = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Determine the size of the thumbnails to request from the PHCachingImageManager
    CGFloat scale = 2.0;
    if ([UIScreen mainScreen].bounds.size.width > 600) {
        scale = 1.0;
    }
    CGSize cellSize = ((UICollectionViewFlowLayout *)_collectionView.collectionViewLayout).itemSize;
    AssetGridThumbnailSize = CGSizeMake(cellSize.width * scale, cellSize.height * scale);
    
    if (!_models) {
        [self fetchAssetModels];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    self.isFirstAppear = NO;
    // [self updateCachedAssets];
}

- (void)configBottomToolBar {
    if (_bottomToolBar) return;
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (!tzImagePickerVc.showSelectBtn) return;
    
    _bottomToolBar = [[UIView alloc] initWithFrame:CGRectZero];
    _bottomToolBar.backgroundColor = [TZCutomColor toobarColor];
    _previewButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [_previewButton addTarget:self action:@selector(previewButtonClick) forControlEvents:UIControlEventTouchUpInside];
    _previewButton.titleLabel.font = [UIFont systemFontOfSize:16];
    [_previewButton setTitle:tzImagePickerVc.previewBtnTitleStr forState:UIControlStateNormal];
    [_previewButton setTitle:tzImagePickerVc.previewBtnTitleStr forState:UIControlStateDisabled];
    [_previewButton setTitleColor:[TZCutomColor blackColor] forState:UIControlStateNormal];
    [_previewButton setTitleColor:[TZCutomColor lightGrayColor] forState:UIControlStateDisabled];
    _previewButton.enabled = tzImagePickerVc.selectedModels.count;
    
    /*
    if (tzImagePickerVc.allowPickingOriginalPhoto) {
        _originalPhotoButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _originalPhotoButton.imageEdgeInsets = UIEdgeInsetsMake(0, [TZCommonTools tz_isRightToLeftLayout] ? 10 : -10, 0, 0);
        [_originalPhotoButton addTarget:self action:@selector(originalPhotoButtonClick) forControlEvents:UIControlEventTouchUpInside];
        _originalPhotoButton.titleLabel.font = [UIFont systemFontOfSize:16];
        [_originalPhotoButton setTitle:tzImagePickerVc.fullImageBtnTitleStr forState:UIControlStateNormal];
        [_originalPhotoButton setTitle:tzImagePickerVc.fullImageBtnTitleStr forState:UIControlStateSelected];
        [_originalPhotoButton setTitleColor:[UIColor lightGrayColor] forState:UIControlStateNormal];
        [_originalPhotoButton setTitleColor:[UIColor blackColor] forState:UIControlStateSelected];
        [_originalPhotoButton setImage:tzImagePickerVc.photoOriginDefImage forState:UIControlStateNormal];
        [_originalPhotoButton setImage:tzImagePickerVc.photoOriginSelImage forState:UIControlStateSelected];
        _originalPhotoButton.imageView.clipsToBounds = YES;
        _originalPhotoButton.imageView.contentMode = UIViewContentModeScaleAspectFit;
        _originalPhotoButton.selected = _isSelectOriginalPhoto;
        _originalPhotoButton.enabled = tzImagePickerVc.selectedModels.count > 0;
        
        _originalPhotoLabel = [[UILabel alloc] init];
        _originalPhotoLabel.textAlignment = NSTextAlignmentLeft;
        _originalPhotoLabel.font = [UIFont systemFontOfSize:16];
        if (@available(iOS 13.0, *)) {
            _originalPhotoLabel.textColor = [UIColor labelColor];
        } else {
            _originalPhotoLabel.textColor = [UIColor blackColor];
        }
        if (_isSelectOriginalPhoto) [self getSelectedPhotoBytes];
    }
     */
    
    _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _doneButton.titleLabel.font = [UIFont systemFontOfSize:14];
    [_doneButton addTarget:self action:@selector(doneButtonClick) forControlEvents:UIControlEventTouchUpInside];
    [_doneButton setTitle:tzImagePickerVc.doneBtnTitleStr forState:UIControlStateNormal];
    [_doneButton setTitle:tzImagePickerVc.doneBtnTitleStr forState:UIControlStateDisabled];
    [_doneButton setTitleColor:tzImagePickerVc.oKButtonTitleColorNormal forState:UIControlStateNormal];
    [_doneButton setTitleColor:tzImagePickerVc.oKButtonTitleColorDisabled forState:UIControlStateDisabled];
    _doneButton.enabled = tzImagePickerVc.selectedModels.count || tzImagePickerVc.alwaysEnableDoneBtn;
    if ((long)tzImagePickerVc.maxImagesCount > 1) {
        [_doneButton setTitle:[NSString stringWithFormat:@"完成(%ld/%ld)",tzImagePickerVc.selectedModels.count,(long)tzImagePickerVc.maxImagesCount] forState:UIControlStateNormal];
        [_doneButton setTitle:[NSString stringWithFormat:@"完成(%ld/%ld)",tzImagePickerVc.selectedModels.count,(long)tzImagePickerVc.maxImagesCount] forState:UIControlStateDisabled];
        if(tzImagePickerVc.selectedModels.count > 0) {
            _doneButton.backgroundColor = tzImagePickerVc.oKButtonBackGroundColorEnabled;
        } else {
            _doneButton.backgroundColor = tzImagePickerVc.oKButtonBackGroundColorDisabled;
        }
    } else {
        [_doneButton setTitle:@"完成" forState:UIControlStateNormal];
        _doneButton.backgroundColor = tzImagePickerVc.oKButtonBackGroundColorEnabled;
    }
    /*
    _numberImageView = [[UIImageView alloc] initWithImage:tzImagePickerVc.photoNumberIconImage];
    _numberImageView.hidden = tzImagePickerVc.selectedModels.count <= 0;
    _numberImageView.clipsToBounds = YES;
    _numberImageView.contentMode = UIViewContentModeScaleAspectFit;
    _numberImageView.backgroundColor = [UIColor clearColor];
    []
    _numberLabel = [[UILabel alloc] init];
    _numberLabel.font = [UIFont systemFontOfSize:15];
    _numberLabel.adjustsFontSizeToFitWidth = YES;
    _numberLabel.textColor = [UIColor whiteColor];
    _numberLabel.textAlignment = NSTextAlignmentCenter;
    _numberLabel.text = [NSString stringWithFormat:@"%zd",tzImagePickerVc.selectedModels.count];
    _numberLabel.hidden = tzImagePickerVc.selectedModels.count <= 0;
    _numberLabel.backgroundColor = [UIColor clearColor];
    */

    _divideLine = [[UIView alloc] init];
    _divideLine.backgroundColor = [TZCutomColor toobarColor];
    
    [_bottomToolBar addSubview:_divideLine];
    [_bottomToolBar addSubview:_previewButton];
    [_bottomToolBar addSubview:_doneButton];
//    [_bottomToolBar addSubview:_numberImageView];
//    [_bottomToolBar addSubview:_numberLabel];
//    [_bottomToolBar addSubview:_originalPhotoButton];
    [self.view addSubview:_bottomToolBar];
    [_originalPhotoButton addSubview:_originalPhotoLabel];
    
    if (tzImagePickerVc.photoPickerPageUIConfigBlock) {
        tzImagePickerVc.photoPickerPageUIConfigBlock(_collectionView, _bottomToolBar, _previewButton, _originalPhotoButton, _originalPhotoLabel, _doneButton, _numberImageView, _numberLabel, _divideLine);
    }
}

#pragma mark - Layout

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    
    CGFloat top = 0;
    CGFloat collectionViewHeight = 0;
    CGFloat naviBarHeight = self.navigationController.navigationBar.tz_height;
    BOOL isStatusBarHidden = [UIApplication sharedApplication].isStatusBarHidden;
    BOOL isFullScreen = self.view.tz_height == [UIScreen mainScreen].bounds.size.height;
    CGFloat toolBarHeight = 50 + [TZCommonTools tz_safeAreaInsets].bottom;
    if (self.navigationController.navigationBar.isTranslucent) {
        top = naviBarHeight;
        if (!isStatusBarHidden && isFullScreen) top += [TZCommonTools tz_statusBarHeight];

        collectionViewHeight = tzImagePickerVc.showSelectBtn ? self.view.tz_height - toolBarHeight - top : self.view.tz_height - top;;
    } else {
        collectionViewHeight = tzImagePickerVc.showSelectBtn ? self.view.tz_height - toolBarHeight : self.view.tz_height;
    }
    _collectionView.frame = CGRectMake(0, top, self.view.tz_width, collectionViewHeight);
    _noDataLabel.frame = _collectionView.bounds;
    CGFloat itemWH = (self.view.tz_width - (self.columnNumber + 1) * itemMargin) / self.columnNumber;
    _layout.itemSize = CGSizeMake(itemWH, itemWH);
    _layout.minimumInteritemSpacing = itemMargin;
    _layout.minimumLineSpacing = itemMargin;
    [_collectionView setCollectionViewLayout:_layout];
    if (_offsetItemCount > 0) {
        CGFloat offsetY = _offsetItemCount * (_layout.itemSize.height + _layout.minimumLineSpacing);
        [_collectionView setContentOffset:CGPointMake(0, offsetY)];
    }
    
    CGFloat toolBarTop = 0;
    if (!self.navigationController.navigationBar.isHidden) {
        toolBarTop = self.view.tz_height - toolBarHeight;
    } else {
        CGFloat navigationHeight = naviBarHeight + [TZCommonTools tz_statusBarHeight];
        toolBarTop = self.view.tz_height - toolBarHeight - navigationHeight;
    }
    _bottomToolBar.frame = CGRectMake(0, toolBarTop, self.view.tz_width, toolBarHeight);
    
    CGFloat previewWidth = [tzImagePickerVc.previewBtnTitleStr boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:16]} context:nil].size.width + 2;
    if (!tzImagePickerVc.allowPreview) {
        previewWidth = 0.0;
    }
    _previewButton.frame = CGRectMake(10, 3, previewWidth, 44);
    _previewButton.tz_width = !tzImagePickerVc.showSelectBtn ? 0 : previewWidth;
    if (tzImagePickerVc.allowPickingOriginalPhoto) {
        CGFloat fullImageWidth = [tzImagePickerVc.fullImageBtnTitleStr boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) options:NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:[UIFont systemFontOfSize:13]} context:nil].size.width;
        _originalPhotoButton.frame = CGRectMake(CGRectGetMaxX(_previewButton.frame), 0, fullImageWidth + 56, 50);
        _originalPhotoLabel.frame = CGRectMake(fullImageWidth + 46, 0, 80, 50);
    }
    [_doneButton sizeToFit];
    _doneButton.frame = CGRectMake(self.view.tz_width - _doneButton.tz_width - 20 - 12, 10, _doneButton.tz_width + 20, 30);
    _doneButton.layer.cornerRadius = 5;
    _doneButton.clipsToBounds = YES;

    _numberImageView.frame = CGRectMake(_doneButton.tz_left - 24 - 5, 13, 24, 24);
    _numberLabel.frame = _numberImageView.frame;
    _divideLine.frame = CGRectMake(0, 0, self.view.tz_width, 1);
    
    [TZImageManager manager].columnNumber = [TZImageManager manager].columnNumber;
    [TZImageManager manager].photoWidth = tzImagePickerVc.photoWidth;
    [self.collectionView reloadData];
    
    if (tzImagePickerVc.photoPickerPageDidLayoutSubviewsBlock) {
        tzImagePickerVc.photoPickerPageDidLayoutSubviewsBlock(_collectionView, _bottomToolBar, _previewButton, _originalPhotoButton, _originalPhotoLabel, _doneButton, _numberImageView, _numberLabel, _divideLine);
    }
}

#pragma mark - Notification

- (void)didChangeStatusBarOrientationNotification:(NSNotification *)noti {
    _offsetItemCount = _collectionView.contentOffset.y / (_layout.itemSize.height + _layout.minimumLineSpacing);
}

#pragma mark - Click Event
- (void)navLeftBarButtonClick{
    [self.navigationController popViewControllerAnimated:YES];
}
- (void)previewButtonClick {
    TZPhotoPreviewController *photoPreviewVc = [[TZPhotoPreviewController alloc] init];
    [self pushPhotoPrevireViewController:photoPreviewVc needCheckSelectedModels:YES];
}

- (void)originalPhotoButtonClick {
    _originalPhotoButton.selected = !_originalPhotoButton.isSelected;
    _isSelectOriginalPhoto = _originalPhotoButton.isSelected;
    _originalPhotoLabel.hidden = !_originalPhotoButton.isSelected;
    if (_isSelectOriginalPhoto) {
        [self getSelectedPhotoBytes];
    }
}

- (void)doneButtonClick {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    // 1.6.8 判断是否满足最小必选张数的限制
    if (tzImagePickerVc.minImagesCount && tzImagePickerVc.selectedModels.count < tzImagePickerVc.minImagesCount) {
        NSString *title = [NSString stringWithFormat:[NSBundle tz_localizedStringForKey:@"Select a minimum of %zd photos"], tzImagePickerVc.minImagesCount];
        [tzImagePickerVc showAlertWithTitle:title];
        return;
    }
    
    [tzImagePickerVc showProgressHUD];
    _doneButton.enabled = NO;
    self.isFetchingMedia = YES;
    NSMutableArray *assets = [NSMutableArray array];
    NSMutableArray *photos;
    NSMutableArray *infoArr;
    if (tzImagePickerVc.onlyReturnAsset) { // not fetch image
        for (NSInteger i = 0; i < tzImagePickerVc.selectedModels.count; i++) {
            TZAssetModel *model = tzImagePickerVc.selectedModels[i];
            [assets addObject:model.asset];
        }
    } else { // fetch image
        photos = [NSMutableArray array];
        infoArr = [NSMutableArray array];
        for (NSInteger i = 0; i < tzImagePickerVc.selectedModels.count; i++) { [photos addObject:@1];[assets addObject:@1];[infoArr addObject:@1]; }
        
        __block BOOL havenotShowAlert = YES;
        [TZImageManager manager].shouldFixOrientation = YES;
        __block UIAlertController *alertView;
        for (NSInteger i = 0; i < tzImagePickerVc.selectedModels.count; i++) {
            TZAssetModel *model = tzImagePickerVc.selectedModels[i];
            TZImageRequestOperation *operation = [[TZImageRequestOperation alloc] initWithAsset:model.asset completion:^(UIImage * _Nonnull photo, NSDictionary * _Nonnull info, BOOL isDegraded) {
                if (isDegraded) return;
                if (photo) {
                    if (![TZImagePickerConfig sharedInstance].notScaleImage) {
                        photo = [[TZImageManager manager] scaleImage:photo toSize:CGSizeMake(tzImagePickerVc.photoWidth, (int)(tzImagePickerVc.photoWidth * photo.size.height / photo.size.width))];
                    }
                    [photos replaceObjectAtIndex:i withObject:photo];
                }
                if (info)  [infoArr replaceObjectAtIndex:i withObject:info];
                [assets replaceObjectAtIndex:i withObject:model.asset];
                
                for (id item in photos) { if ([item isKindOfClass:[NSNumber class]]) return; }
                
                if (havenotShowAlert && alertView) {
                    [alertView dismissViewControllerAnimated:YES completion:^{
                        alertView = nil;
                        [self didGetAllPhotos:photos assets:assets infoArr:infoArr];
                    }];
                } else {
                    [self didGetAllPhotos:photos assets:assets infoArr:infoArr];
                }
            } progressHandler:^(double progress, NSError * _Nonnull error, BOOL * _Nonnull stop, NSDictionary * _Nonnull info) {
                // 如果图片正在从iCloud同步中,提醒用户
                if (progress < 1 && havenotShowAlert && !alertView) {
                    alertView = [tzImagePickerVc showAlertWithTitle:[NSBundle tz_localizedStringForKey:@"Synchronizing photos from iCloud"]];
                    havenotShowAlert = NO;
                    return;
                }
                if (progress >= 1) {
                    havenotShowAlert = YES;
                }
            }];
            [self.operationQueue addOperation:operation];
        }
    }
    if (tzImagePickerVc.selectedModels.count <= 0 || tzImagePickerVc.onlyReturnAsset) {
        [self didGetAllPhotos:photos assets:assets infoArr:infoArr];
    }
}

- (void)didGetAllPhotos:(NSArray *)photos assets:(NSArray *)assets infoArr:(NSArray *)infoArr {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    [tzImagePickerVc hideProgressHUD];
    _doneButton.enabled = YES;
    self.isFetchingMedia = NO;

    if (tzImagePickerVc.autoDismiss) {
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            [self callDelegateMethodWithPhotos:photos assets:assets infoArr:infoArr];
        }];
    } else {
        [self callDelegateMethodWithPhotos:photos assets:assets infoArr:infoArr];
    }
}

- (void)callDelegateMethodWithPhotos:(NSArray *)photos assets:(NSArray *)assets infoArr:(NSArray *)infoArr {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (tzImagePickerVc.allowPickingVideo && tzImagePickerVc.maxImagesCount == 1) {
        if ([[TZImageManager manager] isVideo:[assets firstObject]]) {
            BOOL triggered = NO;
            if ([tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingVideo:sourceAssets:)]) {
                [tzImagePickerVc.pickerDelegate imagePickerController:tzImagePickerVc didFinishPickingVideo:[photos firstObject] sourceAssets:[assets firstObject]];
                triggered = YES;
            }
            if (tzImagePickerVc.didFinishPickingVideoHandle) {
                tzImagePickerVc.didFinishPickingVideoHandle([photos firstObject], [assets firstObject]);
                triggered = YES;
            }
            if (triggered) return;
        }
    }
    
    if ([tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:)]) {
        [tzImagePickerVc.pickerDelegate imagePickerController:tzImagePickerVc didFinishPickingPhotos:photos sourceAssets:assets isSelectOriginalPhoto:_isSelectOriginalPhoto];
    }
    if ([tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:infos:)]) {
        [tzImagePickerVc.pickerDelegate imagePickerController:tzImagePickerVc didFinishPickingPhotos:photos sourceAssets:assets isSelectOriginalPhoto:_isSelectOriginalPhoto infos:infoArr];
    }
    if (tzImagePickerVc.didFinishPickingPhotosHandle) {
        tzImagePickerVc.didFinishPickingPhotosHandle(photos,assets,_isSelectOriginalPhoto);
    }
    if (tzImagePickerVc.didFinishPickingPhotosWithInfosHandle) {
        tzImagePickerVc.didFinishPickingPhotosWithInfosHandle(photos,assets,_isSelectOriginalPhoto,infoArr);
    }
}

#pragma mark - UICollectionViewDataSource && Delegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self getAllCellCount];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    // the cell lead to take a picture / 去拍照的cell
    if (indexPath.item == [self getTakePhotoCellIndex]) {
        TZAssetCameraCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TZAssetCameraCell" forIndexPath:indexPath];
        if (tzImagePickerVc.takeVideo) {
            cell.imageView.image = tzImagePickerVc.takeVideo;
        } else {
            cell.imageView.image = [UIImage tz_imageNamedFromMyBundle:tzImagePickerVc.takePictureImageName];
        }
        cell.imageView.backgroundColor = tzImagePickerVc.oKButtonBackGroundColorDisabled;
        return cell;
    }
    // the cell dipaly photo or video / 展示照片或视频的cell
    TZAssetCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"TZAssetCell" forIndexPath:indexPath];
    cell.allowPickingMultipleVideo = tzImagePickerVc.allowPickingMultipleVideo;
    cell.photoDefImage = tzImagePickerVc.photoDefImage;
    cell.photoSelImage = tzImagePickerVc.photoSelImage;
    cell.assetCellDidSetModelBlock = tzImagePickerVc.assetCellDidSetModelBlock;
    cell.assetCellDidLayoutSubviewsBlock = tzImagePickerVc.assetCellDidLayoutSubviewsBlock;
    cell.mainColor = tzImagePickerVc.mainColor;
    TZAssetModel *model;
    if (tzImagePickerVc.sortAscendingByModificationDate) {
        model = _models[indexPath.item];
    } else {
        NSInteger diff = [self getAllCellCount] - _models.count;
        model = _models[indexPath.item - diff];;
    }
    cell.allowPickingGif = tzImagePickerVc.allowPickingGif;
    cell.model = model;
    if (model.isSelected && tzImagePickerVc.showSelectedIndex) {
        cell.index = [tzImagePickerVc.selectedAssetIds indexOfObject:model.asset.localIdentifier] + 1;
    }
    cell.showSelectBtn = tzImagePickerVc.showSelectBtn;
    cell.allowPreview = tzImagePickerVc.allowPreview;
    
    BOOL notSelectable = [TZCommonTools isAssetNotSelectable:model tzImagePickerVc:tzImagePickerVc];
    if (notSelectable && tzImagePickerVc.showPhotoCannotSelectLayer && !model.isSelected) {
        cell.cannotSelectLayerButton.backgroundColor = tzImagePickerVc.cannotSelectLayerColor;
        cell.cannotSelectLayerButton.hidden = NO;
    } else {
        cell.cannotSelectLayerButton.hidden = YES;
    }
    
    __weak typeof(cell) weakCell = cell;
    __weak typeof(self) weakSelf = self;
    __weak typeof(_numberImageView.layer) weakLayer = _numberImageView.layer;
    cell.didSelectPhotoBlock = ^(BOOL isSelected) {
        __strong typeof(weakCell) strongCell = weakCell;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong typeof(weakLayer) strongLayer = weakLayer;
        TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)strongSelf.navigationController;
        // 1. cancel select / 取消选择
        if (isSelected) {
            strongCell.selectPhotoButton.selected = NO;
            model.isSelected = NO;
            NSMutableArray *selectedModels = [NSMutableArray arrayWithArray:tzImagePickerVc.selectedModels];
            for (TZAssetModel *model_item in selectedModels) {
                if ([model.asset.localIdentifier isEqualToString:model_item.asset.localIdentifier]) {
                    [tzImagePickerVc removeSelectedModel:model_item];
                    [strongSelf setAsset:model_item.asset isSelect:NO];
                    break;
                }
            }
            [self checkSelectedModels];
            [strongSelf refreshBottomToolBarStatus];
            if (tzImagePickerVc.showSelectedIndex || tzImagePickerVc.showPhotoCannotSelectLayer) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"TZ_PHOTO_PICKER_RELOAD_NOTIFICATION" object:strongSelf.navigationController];
            }
            [UIView showOscillatoryAnimationWithLayer:strongLayer type:TZOscillatoryAnimationToSmaller];
            if (strongCell.model.iCloudFailed) {
                NSString *title = [NSBundle tz_localizedStringForKey:@"iCloud sync failed"];
                [tzImagePickerVc showAlertWithTitle:title];
            }
        } else {
            // 2. select:check if over the maxImagesCount / 选择照片,检查是否超过了最大个数的限制
            if (tzImagePickerVc.selectedModels.count < tzImagePickerVc.maxImagesCount) {
                if ([[TZImageManager manager] isAssetCannotBeSelected:model.asset]) {
                    return;
                }
                if (!tzImagePickerVc.allowPreview) {
                    BOOL shouldDone = tzImagePickerVc.maxImagesCount == 1;
                    if (!tzImagePickerVc.allowPickingMultipleVideo && (model.type == TZAssetModelMediaTypeVideo || model.type == TZAssetModelMediaTypePhotoGif)) {
                        shouldDone = YES;
                    }
                    if (shouldDone) {
                        model.isSelected = YES;
                        [tzImagePickerVc addSelectedModel:model];
                        [strongSelf doneButtonClick];
                        return;
                    }
                }
                strongCell.selectPhotoButton.selected = YES;
                model.isSelected = YES;
                [tzImagePickerVc addSelectedModel:model];
                if (tzImagePickerVc.showSelectedIndex || tzImagePickerVc.showPhotoCannotSelectLayer) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"TZ_PHOTO_PICKER_RELOAD_NOTIFICATION" object:strongSelf.navigationController];
                }
                [strongSelf setAsset:model.asset isSelect:YES];
                [strongSelf refreshBottomToolBarStatus];
                [UIView showOscillatoryAnimationWithLayer:strongLayer type:TZOscillatoryAnimationToSmaller];
            } else {
                NSString *title = [NSString stringWithFormat:[NSBundle tz_localizedStringForKey:@"Select a maximum of %zd photos"], tzImagePickerVc.maxImagesCount];
                [tzImagePickerVc showAlertWithTitle:title];
            }
        }
    };
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    // take a photo / 去拍照
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (indexPath.item == [self getTakePhotoCellIndex]) {
        /// 拍视频：如实现了imagePickerControllerDidClickTakePhotoBtn即调用自定拍摄页面，否则使用系统页面
        if (tzImagePickerVc.takeVideo) {
            if([tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerControllerDidClickTakePhotoBtn:)]) {
                [tzImagePickerVc.pickerDelegate imagePickerControllerDidClickTakePhotoBtn:tzImagePickerVc];
            } else {
                [self takePhoto];
            }
        } else {
            [self takePhoto];
        }
        return;
    }
    // preview phote or video / 预览照片或视频
    NSInteger index = indexPath.item;
    if (!tzImagePickerVc.sortAscendingByModificationDate) {
        index -= [self getAllCellCount] - _models.count;
    }
    TZAssetModel *model = _models[index];
    
//    TZPhotoPreviewController *photoPreviewVc = [[TZPhotoPreviewController alloc] init];
//    photoPreviewVc.currentIndex = index;
//    photoPreviewVc.models = _models;
//    [self pushPhotoPrevireViewController:photoPreviewVc];
//    
//    return;
    if (model.type == TZAssetModelMediaTypeVideo && !tzImagePickerVc.allowPickingMultipleVideo) {
        if (tzImagePickerVc.selectedModels.count > 0) {
            TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
            [imagePickerVc showAlertWithTitle:[NSBundle tz_localizedStringForKey:@"Can not choose both video and photo"]];
        } else {
            /// 显示进度的比例
            __block float showProgressScale = 0;
            NSString *quickUpdateTimeNotice;
            if (tzImagePickerVc.couldQuickExportVideoMaxSeconds % 60 == 0) {
                quickUpdateTimeNotice = [NSString stringWithFormat:@"%d分钟", tzImagePickerVc.couldQuickExportVideoMaxSeconds / 60];
            } else {
                quickUpdateTimeNotice = [NSString stringWithFormat:@"%d秒", tzImagePickerVc.couldQuickExportVideoMaxSeconds];
            }
            /// 是否自定义弹窗样式
            BOOL canRespondsCustomActionSheet = [tzImagePickerVc.pickerDelegate respondsToSelector:@selector(selectedVideoShowCustomActionSheet:actionTitles:quickUploadBlock:editBlock:)];
            BOOL canRespondsCustomAlert = [tzImagePickerVc.pickerDelegate respondsToSelector:@selector(selectedVideoShowCustomAlertTitle:message:)];

            /// AVComposition资源导出
            void (^AVCompositionExpBlock)(AVComposition *) = ^(AVComposition *composition) {
                /// 首次渲染需要的时间比较长
                showProgressScale = 0.7;
                [[[TZImageManager alloc] init] convertAvcompositionToAvasset:composition compressProgressHandeler:^(float progress) {
                    NSString *info = [NSString stringWithFormat:@"当前进度:%ld%%", lround(progress * 100 * showProgressScale)];
                    [tzImagePickerVc updateProgressInfo: info];
                } completion:^(AVAsset *asset, NSURL *exportURL) {
                    NSLog(@"AVComposition导出完成, %@", exportURL.absoluteString);
                    NSString *videoPath = [exportURL.absoluteString stringByReplacingOccurrencesOfString:@"file://" withString:@""];
                    [self AVURLAssetExportWithAsset:(AVURLAsset*)asset sourePHAsset:model.asset soureExpVideoPath:videoPath showProgressScale: showProgressScale];
                }];
            };
            /// 快速上传
            VoidBlock quickUploadBlock = ^{
                NSLog(@"uploadAction");
                [tzImagePickerVc showProgressHUD];
                // 禁止用户操作
                tzImagePickerVc.view.userInteractionEnabled = NO;
                
                PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
                /// 设置为当前版本，包含用户编辑后信息，比如滤镜
                options.version = PHVideoRequestOptionsVersionCurrent;
//                options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;

                NSLog(@"%@", NSHomeDirectory());
                
                options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;

                options.networkAccessAllowed = YES;
                
                [[PHImageManager defaultManager] requestAVAssetForVideo:model.asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                    CGFloat totalSize = 0;
                    AVAssetTrack *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
                    for (AVAssetTrack *videoTrack in videoTracks) {
                        totalSize += videoTrack.estimatedDataRate * CMTimeGetSeconds(asset.duration) / 8;
                    }
                    
                    AVAssetTrack *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
                    for (AVAssetTrack *audioTrack in audioTracks) {
                        totalSize += audioTrack.estimatedDataRate * CMTimeGetSeconds(asset.duration) / 8;
                    }
                    totalSize = totalSize / 1000 / 1000;
                    
                    NSLog(@"视频体积 %f", totalSize);

                    BOOL directExport = NO;
                    if(tzImagePickerVc.directExportFileSizeMB < 0) {
                        directExport = YES;
                    } else {
                        if(totalSize <= tzImagePickerVc.directExportFileSizeMB) {
                            directExport = YES;
                        }
                    }
                    
                    if(directExport) {
                        NSLog(@"直接导出");
                        /// 直接导出
                        AVURLAsset *urlAsset = (AVURLAsset*)asset;
                        NSString *outputPath = urlAsset.URL.absoluteString;
                        outputPath = [outputPath stringByReplacingOccurrencesOfString:@"file://" withString:@""];
                        
                        NSString *soureExpVideoPath = nil;
                        
                        NSString *exportFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",@"exportVideo",@"mp4"]];
                        NSLog(@"exportFilePath:%@", exportFilePath);
                        
                        // 移除上一个
                        if ([[NSFileManager defaultManager] fileExistsAtPath:exportFilePath]) {
                            NSError *removeErr;
                            [[NSFileManager defaultManager] removeItemAtPath:exportFilePath error: &removeErr];
                        }
                        /// 如果有源视频先删除源视频
                        if ([[NSFileManager defaultManager] fileExistsAtPath:soureExpVideoPath]) {
                            NSError *removeErr;
                            [[NSFileManager defaultManager] removeItemAtPath:soureExpVideoPath error: &removeErr];
                        }
                        // 把文件移动到同一的路径下，修改为同一的名称。方便后续的操作
                        NSError *moveErr;
                        [[NSFileManager defaultManager] copyItemAtPath:outputPath toPath:exportFilePath error:&moveErr];
                        NSLog(@"moveErr: %@", moveErr);
                        if (moveErr != nil) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                tzImagePickerVc.view.userInteractionEnabled = YES;
                                [tzImagePickerVc hideProgressHUD];
                                [tzImagePickerVc showAlertWithTitle:@"视频出问题啦，请手动编辑"];
                            });
                        } else {
                            /// 导出封面
                            [self getJpegCoverFormAsset:model.asset videoExportFilePath:exportFilePath];
                        }
                    } else {
                        if ([asset isKindOfClass:[AVURLAsset class]]) {
                            [self AVURLAssetExportWithAsset:(AVURLAsset*)asset sourePHAsset:model.asset soureExpVideoPath:nil showProgressScale: showProgressScale];
                        } else if([asset isKindOfClass:[AVComposition class]]) {
                            AVCompositionExpBlock((AVComposition*)asset);
                        } else {
                            // 允许用户操作
                            dispatch_async(dispatch_get_main_queue(), ^{
                                tzImagePickerVc.view.userInteractionEnabled = YES;
                                [tzImagePickerVc hideProgressHUD];
                                [tzImagePickerVc showAlertWithTitle:@"封面获取出问题啦，请手动编辑"];
                            });
                        }
                    }
                }];
            };
            /// 编辑后上传
            VoidBlock editBlock = ^{
                NSLog(@"editAction");
                TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
                ZLEditVideoController *editVC = [[ZLEditVideoController alloc]init];
                if (imagePickerVc.videoEditVCbackImage) {
                    editVC.backImage = imagePickerVc.videoEditVCbackImage;
                }
                if (imagePickerVc.mainColor) {
                    editVC.mainColor = imagePickerVc.mainColor;
                }
                if (imagePickerVc.maxEditVideoTime > 0) {
                    editVC.maxEditVideoTime = imagePickerVc.maxEditVideoTime;
                }
                if (imagePickerVc.minEditVideoTime > 0) {
                    editVC.minEditVideoTime = imagePickerVc.minEditVideoTime;
                }
                editVC.asset = model.asset;
                __weak typeof(imagePickerVc) weakImagePickerVc = imagePickerVc;
                editVC.coverImageBlock = ^(UIImage *coverImage, NSURL *videoPath) {
                    [self finishEditVideoByImagePickerVC:weakImagePickerVc coverImage:coverImage videoURL:videoPath];
                };
                [self.navigationController pushViewController:editVC animated:YES];
            };
            /// 无效的操作
            VoidBlock disableBlock = ^{
                NSLog(@"当前操作不可用");
            };
            VoidBlock exportBlock = ^{
                if (tzImagePickerVc.exportVideoMode == TSExportVideoModeEditExport) {
                    /// 仅编辑
                    editBlock();
                } else if(tzImagePickerVc.exportVideoMode == TSExportVideoModeQuickNoLimitTimeExport) {
                    /// 仅不限时长快速上传
                    quickUploadBlock();
                } else if(tzImagePickerVc.exportVideoMode == TSExportVideoModeQuickLimitTimeExport) {
                    /// 仅限制时的快速上传，需要再判断时长
                    if (model.asset.duration <= tzImagePickerVc.couldQuickExportVideoMaxSeconds) {
                        quickUploadBlock();
                    } else {
                        if (canRespondsCustomAlert) {
                            [tzImagePickerVc.pickerDelegate selectedVideoShowCustomAlertTitle:@"温馨提示" message:@"仅支持%@内视频"];
                        } else {
                            /// 超过视频长度弹窗提示
                            UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"温馨提示" message:[NSString stringWithFormat:@"仅支持%@内视频", quickUpdateTimeNotice] preferredStyle:UIAlertControllerStyleAlert];
                            UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            }];
                            [alertVC addAction:sureAction];
                            [self presentViewController:alertVC animated:YES completion:nil];
                        }
                    }
                } else if(tzImagePickerVc.exportVideoMode == TSExportVideoModeQuickLimitTimeAndEditExport) {
                    /// 限时快速上传+编辑后上传同时有，需要再判断时长
                    if (model.asset.duration <= tzImagePickerVc.couldQuickExportVideoMaxSeconds) {
                        if (canRespondsCustomActionSheet){
                            [tzImagePickerVc.pickerDelegate selectedVideoShowCustomActionSheet:@"温馨提示" actionTitles:@[[NSString stringWithFormat:@"快速上传(支持%@以内)", quickUpdateTimeNotice], @"编辑后上传"] quickUploadBlock:quickUploadBlock editBlock:editBlock];
                        } else {
                            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"温馨提示" preferredStyle:UIAlertControllerStyleActionSheet];
                            UIAlertAction *uploadAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"快速上传(支持%@以内)", quickUpdateTimeNotice] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                quickUploadBlock();
                            }];
                            UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"编辑后上传" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                editBlock();
                            }];
                            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                                NSLog(@"cancel");
                            }];
                            [alertController addAction:uploadAction];
                            [alertController addAction:editAction];
                            [alertController addAction:cancelAction];
                            [self presentViewController:alertController animated:YES completion:nil];
                        }
                    } else {
                        if (canRespondsCustomActionSheet){
                            [tzImagePickerVc.pickerDelegate selectedVideoShowCustomActionSheet:@"温馨提示" actionTitles:@[[NSString stringWithFormat:@"快速上传(超过%@不可用)", quickUpdateTimeNotice], @"编辑后上传"] quickUploadBlock:disableBlock editBlock:editBlock];
                        } else {
                            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"温馨提示" preferredStyle:UIAlertControllerStyleActionSheet];
                            UIAlertAction *uploadAction = [UIAlertAction actionWithTitle:[NSString stringWithFormat:@"快速上传(超过%@不可用)", quickUpdateTimeNotice] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                disableBlock();
                            }];
                            UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"编辑后上传" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                                editBlock();
                            }];
                            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                                NSLog(@"cancel");
                            }];
                            [alertController addAction:uploadAction];
                            [alertController addAction:editAction];
                            [alertController addAction:cancelAction];
                            [self presentViewController:alertController animated:YES completion:nil];
                        }
                    }
                        
                } else if(tzImagePickerVc.exportVideoMode == TSExportVideoModeQuickNoLimitTimeAndEditExport) {
                    /// 不限时快速上传+编辑
                    if (canRespondsCustomActionSheet){
                        [tzImagePickerVc.pickerDelegate selectedVideoShowCustomActionSheet:@"温馨提示" actionTitles:@[@"快速上传", @"编辑后上传"] quickUploadBlock:quickUploadBlock editBlock:editBlock];
                    } else {
                        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"" message:@"温馨提示" preferredStyle:UIAlertControllerStyleActionSheet];
                        UIAlertAction *uploadAction = [UIAlertAction actionWithTitle:@"快速上传" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            quickUploadBlock();
                        }];
                        UIAlertAction *editAction = [UIAlertAction actionWithTitle:@"编辑后上传" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            editBlock();
                        }];
                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                            NSLog(@"cancel");
                        }];
                        [alertController addAction:uploadAction];
                        [alertController addAction:editAction];
                        [alertController addAction:cancelAction];
                        [self presentViewController:alertController animated:YES completion:nil];
                    }
                }
            };
        
            /// 判断当前视频资源是否可用
            PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
            options.deliveryMode = PHVideoRequestOptionsDeliveryModeFastFormat;
            options.networkAccessAllowed = NO;
            [[PHImageManager defaultManager] requestAVAssetForVideo:model.asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if ([info objectForKey:PHImageResultIsInCloudKey]) {
                        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"温馨提示" message:@"当前视频存储于iCloud，需下载后继续操作。下载可能需要较长时间。" preferredStyle:UIAlertControllerStyleAlert];
                        UIAlertAction *nextAction = [UIAlertAction actionWithTitle:@"下载" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            [tzImagePickerVc showProgressHUD];
                            // 禁止用户操作
                            tzImagePickerVc.view.userInteractionEnabled = NO;
                            
                            PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
                            /// 设置为当前版本，包含用户编辑后信息，比如滤镜
                            options.version = PHVideoRequestOptionsVersionCurrent;
                            options.deliveryMode = PHVideoRequestOptionsDeliveryModeHighQualityFormat;
                            options.networkAccessAllowed = YES;
                            [[PHImageManager defaultManager] requestAVAssetForVideo:model.asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    if (asset != nil) {
                                        tzImagePickerVc.view.userInteractionEnabled = YES;
                                        [tzImagePickerVc hideProgressHUD];
                                        exportBlock();
                                    } else {
                                        tzImagePickerVc.view.userInteractionEnabled = YES;
                                        [tzImagePickerVc hideProgressHUD];
                                        [tzImagePickerVc showAlertWithTitle:@"下载失败，请重试"];
                                    }
                                });
                            }];
                        }];
                        [alertVC addAction:nextAction];
                        
                        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                        }];
                        [alertVC addAction:cancelAction];
                        [self presentViewController:alertVC animated:YES completion:nil];
                    } else {
                        exportBlock();
                    }
                });
            }];
        }
    } else if (model.type == TZAssetModelMediaTypePhotoGif && tzImagePickerVc.allowPickingGif && !tzImagePickerVc.allowPickingMultipleVideo) {
        if (tzImagePickerVc.selectedModels.count > 0) {
            TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
            [imagePickerVc showAlertWithTitle:[NSBundle tz_localizedStringForKey:@"Can not choose both photo and GIF"]];
        } else {
            TZGifPhotoPreviewController *gifPreviewVc = [[TZGifPhotoPreviewController alloc] init];
            gifPreviewVc.model = model;
            UIBarButtonItem *backBtnItem = [[UIBarButtonItem alloc] init];
            backBtnItem.title = @" ";
            self.navigationItem.backBarButtonItem = backBtnItem;
            [self.navigationController pushViewController:gifPreviewVc animated:YES];
        }
    } else {
        TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
        if (imagePickerVc.shouldPick) {
            TZAssetModel *asset = _models[index];
            TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
            [[TZImageManager manager] getOriginalPhotoWithAsset:asset.asset completion:^(UIImage *photo, NSDictionary *info) {
                BOOL isDegraded = [info[@"PHImageResultIsDegradedKey"] boolValue];
                /// 低分辨率不跳转
                if (isDegraded) {
                    return;
                }
                LZImageCropping *imageBrowser = [[LZImageCropping alloc]init];
                TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
                //设置代理
                imageBrowser.delegate = self;
                if (tzImagePickerVc.isSquare) {
                    if (tzImagePickerVc.cropMaxSize.height > 0 && tzImagePickerVc.cropMaxSize.width > 0) {
                        imageBrowser.cropMaxSize  = tzImagePickerVc.cropMaxSize;
                    } else {
                        imageBrowser.cropSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width - 80, UIScreen.mainScreen.bounds.size.width - 80);
                    }
                } else {
                    if (tzImagePickerVc.clipSize.height > 0 && tzImagePickerVc.clipSize.width > 0) {
                        imageBrowser.cropSize  = tzImagePickerVc.clipSize;
                    } else {
                        imageBrowser.cropSize = CGSizeMake(UIScreen.mainScreen.bounds.size.width, UIScreen.mainScreen.bounds.size.width / 2.0);
                    }
                }
                [imageBrowser setImage:photo];
                imageBrowser.titleLabel.text = tzImagePickerVc.topTitle;
                imageBrowser.backImage = imagePickerVc.backImage;
                //设置自定义裁剪区域大小
                //是否需要圆形
                imageBrowser.isRound = NO;
                if (_mainColor) {
                    imageBrowser.mainColor = _mainColor;
                }
                [self.navigationController pushViewController:imageBrowser animated:YES];
            }];
        } else {
            TZPhotoPreviewController *photoPreviewVc = [[TZPhotoPreviewController alloc] init];
            photoPreviewVc.currentIndex = index;
            photoPreviewVc.models = _models;
            [self pushPhotoPrevireViewController:photoPreviewVc];
        }
    }
}

- (void)AVURLAssetExportWithAsset:(AVURLAsset *)avAsset sourePHAsset:(PHAsset*)phAsset soureExpVideoPath:(NSString *)soureExpVideoPath showProgressScale:(float)showProgressScale {
        dispatch_sync(dispatch_get_main_queue(), ^{
            TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
            [TZImageManager compressionVideoWithVideoAsset:avAsset quality:VideoQualityTypeHigh success:^(NSString *outputPath) {
                NSString *exportFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.%@",@"exportVideo",@"mp4"]];
                // 移除上一个
                if ([[NSFileManager defaultManager] fileExistsAtPath:exportFilePath]) {
                    NSError *removeErr;
                    [[NSFileManager defaultManager] removeItemAtPath:exportFilePath error: &removeErr];
                }
                /// 如果有源视频先删除源视频
                if ([[NSFileManager defaultManager] fileExistsAtPath:soureExpVideoPath]) {
                    NSError *removeErr;
                    [[NSFileManager defaultManager] removeItemAtPath:soureExpVideoPath error: &removeErr];
                }
                // 把文件移动到同一的路径下，修改为同一的名称。方便后续的操作
                NSError *moveErr;
                [[NSFileManager defaultManager] moveItemAtURL:[NSURL fileURLWithPath:outputPath] toURL:[NSURL fileURLWithPath:exportFilePath] error:&moveErr];
                /// 导出封面
                [self getJpegCoverFormAsset:phAsset videoExportFilePath:exportFilePath];
            } compressProgressHandeler:^(float progress) {
                NSString *info = [NSString stringWithFormat:@"当前进度:%ld%%", lround(progress * (1 - showProgressScale) * 100 + lround(showProgressScale * 100))];
                [tzImagePickerVc updateProgressInfo: info];
            } failure:^(NSString *errorMessage, NSError *error) {
                // 允许用户操作
                dispatch_async(dispatch_get_main_queue(), ^{
                    tzImagePickerVc.view.userInteractionEnabled = YES;
                    [tzImagePickerVc hideProgressHUD];
                    [tzImagePickerVc showAlertWithTitle:@"自动导出出问题啦，请手动编辑"];
                });
            }];
        });
}

/// 获取封面
- (void)getJpegCoverFormAsset:(PHAsset *)asset videoExportFilePath:(NSString *)exportFilePath {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    PHVideoRequestOptions* options = [[PHVideoRequestOptions alloc] init];
    /// 设置为当前版本，包含用户编辑后信息，比如滤镜
    options.version = PHVideoRequestOptionsVersionCurrent;
    options.deliveryMode = PHVideoRequestOptionsDeliveryModeAutomatic;
    options.networkAccessAllowed = YES;
    [[PHImageManager defaultManager] requestAVAssetForVideo:asset options:options resultHandler:^(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info) {
        AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
        generator.appliesPreferredTrackTransform = YES;
        generator.requestedTimeToleranceBefore = kCMTimeZero;
        generator.requestedTimeToleranceAfter = kCMTimeZero;
        generator.apertureMode = AVAssetImageGeneratorApertureModeProductionAperture;
        NSError *error = nil;
        UIImage *coverImage;

        CGFloat second = 0;
        for (int i = 0; i < 5; i ++) {
            CGImageRef img = [generator copyCGImageAtTime:CMTimeMake(second * asset.duration.timescale, asset.duration.timescale) actualTime:NULL error:&error];
            second = second + 0.2;
            if (img != nil) {
                coverImage = [UIImage imageWithCGImage:img];
                break;
            }
            NSLog(@"error\n\n -%@", error);
        }
        if (coverImage != nil && exportFilePath != nil) {
            /// 切换到主线程
            dispatch_sync(dispatch_get_main_queue(), ^{
                // 允许用户操作
                tzImagePickerVc.view.userInteractionEnabled = YES;
                [tzImagePickerVc hideProgressHUD];
                [tzImagePickerVc dismissViewControllerAnimated:YES completion:^{
                if ([tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishEditVideoCoverImage:videoURL:)]) {
                    [tzImagePickerVc.pickerDelegate imagePickerController:tzImagePickerVc didFinishEditVideoCoverImage:coverImage videoURL:[NSURL fileURLWithPath:exportFilePath]];
                }
                }];
            });
        } else {
            // 允许用户操作
            dispatch_async(dispatch_get_main_queue(), ^{
                tzImagePickerVc.view.userInteractionEnabled = YES;
                [tzImagePickerVc showAlertWithTitle:@"封面获取出问题啦，请手动编辑"];
            });
        }
    }];
}

- (void)finishEditVideoByImagePickerVC:(TZImagePickerController *)imagePickerVC coverImage:(UIImage *)coverImage videoURL:(NSURL *)videoURL {
    if (coverImage != nil && videoURL != nil) {
        [imagePickerVC showProgressHUD];
        [[[TZImageManager alloc] init] compressionVideoWithVideoURL:videoURL quality:VideoQualityTypeHigh success:^(NSString *outputPath) {
            [imagePickerVC hideProgressHUD];
            [imagePickerVC dismissViewControllerAnimated:YES completion:^{
                if ([imagePickerVC.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishEditVideoCoverImage:videoURL:)]) {
                    [imagePickerVC.pickerDelegate imagePickerController:imagePickerVC didFinishEditVideoCoverImage:coverImage videoURL:[NSURL fileURLWithPath:outputPath]];
                }
                /// 导航内视图全部pop以释放内存
                for (int i = 0; i < self.navigationController.viewControllers.count; i ++) {
                    [self.navigationController popViewControllerAnimated:YES];
                }
            }];
        } compressProgressHandeler:^(float progress) {
            NSString *info = [NSString stringWithFormat:@"当前进度:%ld%%", lround(progress * 100)];
            [imagePickerVC updateProgressInfo: info];
        } failure:^(NSString *errorMessage, NSError *error) {
            [imagePickerVC hideProgressHUD];
            [imagePickerVC dismissViewControllerAnimated:YES completion:^{
                if ([imagePickerVC.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishEditVideoCoverImage:videoURL:)]) {
                    [imagePickerVC.pickerDelegate imagePickerController:imagePickerVC didFinishEditVideoCoverImage:coverImage videoURL:videoURL];
                }
                /// 导航内视图全部pop以释放内存
                for (int i = 0; i < self.navigationController.viewControllers.count; i ++) {
                    [self.navigationController popViewControllerAnimated:YES];
                }
            }];
        }];
    } else {
        [imagePickerVC dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    // [self updateCachedAssets];
}
-(void)lzImageCropping:(LZImageCropping *)cropping didCropImage:(UIImage *)image {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if ([tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didFinishPickingPhotos:sourceAssets:isSelectOriginalPhoto:)]) {
        [tzImagePickerVc.pickerDelegate imagePickerController:tzImagePickerVc didFinishPickingPhotos:@[image] sourceAssets:@[] isSelectOriginalPhoto:_isSelectOriginalPhoto];
    }
}
#pragma mark - Private Method

- (NSInteger)getAllCellCount {
    NSInteger count = _models.count;
    if (_showTakePhotoBtn) {
        count += 1;
    }
    return count;
}

- (NSInteger)getTakePhotoCellIndex {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (!_showTakePhotoBtn) {
        return -1;
    }
    if (tzImagePickerVc.sortAscendingByModificationDate) {
        return [self getAllCellCount] - 1;
    } else {
        return 0;
    }
}


/// 拍照按钮点击事件
- (void)takePhoto {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if ((authStatus == AVAuthorizationStatusRestricted || authStatus ==AVAuthorizationStatusDenied)) {
        
        // 无权限 做一个友好的提示
        NSString *appName = [TZCommonTools tz_getAppName];

        NSString *title = [NSBundle tz_localizedStringForKey:@"Can not use camera"];
        NSString *message = [NSString stringWithFormat:[NSBundle tz_localizedStringForKey:@"Please allow %@ to access your camera in \"Settings -> Privacy -> Camera\""],appName];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *cancelAct = [UIAlertAction actionWithTitle:[NSBundle tz_localizedStringForKey:@"Cancel"] style:UIAlertActionStyleCancel handler:nil];
        [alertController addAction:cancelAct];
        UIAlertAction *settingAct = [UIAlertAction actionWithTitle:[NSBundle tz_localizedStringForKey:@"Setting"] style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        }];
        [alertController addAction:settingAct];
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
    } else if (authStatus == AVAuthorizationStatusNotDetermined) {
        // fix issue 466, 防止用户首次拍照拒绝授权时相机页黑屏
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            if (granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self pushImagePickerController];
                });
            }
        }];
    } else {
        [self pushImagePickerController];
    }
}

- (void)openSettingsApplication {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
}

- (void)addMorePhoto {
    if (@available(iOS 14, *)) {
        [[PHPhotoLibrary sharedPhotoLibrary] presentLimitedLibraryPickerFromViewController:self];
    }
}

// 调用相机
- (void)pushImagePickerController {
    // 提前定位
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (tzImagePickerVc.allowCameraLocation) {
        __weak typeof(self) weakSelf = self;
        [[TZLocationManager manager] startLocationWithSuccessBlock:^(NSArray<CLLocation *> *locations) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.location = [locations firstObject];
        } failureBlock:^(NSError *error) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.location = nil;
        }];
    }
    
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable: sourceType]) {
        self.imagePickerVc.sourceType = sourceType;
        NSMutableArray *mediaTypes = [NSMutableArray array];
        if (tzImagePickerVc.allowTakePicture) {
            [mediaTypes addObject:(NSString *)kUTTypeImage];
        }
        if (tzImagePickerVc.allowTakeVideo) {
            [mediaTypes addObject:(NSString *)kUTTypeMovie];
            self.imagePickerVc.videoMaximumDuration = tzImagePickerVc.videoMaximumDuration;
        }
        self.imagePickerVc.mediaTypes= mediaTypes;
        if (tzImagePickerVc.uiImagePickerControllerSettingBlock) {
            tzImagePickerVc.uiImagePickerControllerSettingBlock(_imagePickerVc);
        }
        [self presentViewController:_imagePickerVc animated:YES completion:nil];
    } else {
        NSLog(@"模拟器中无法打开照相机,请在真机中使用");
    }
}

- (void)refreshBottomToolBarStatus {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    
    _previewButton.enabled = tzImagePickerVc.selectedModels.count > 0;
    _doneButton.enabled = tzImagePickerVc.selectedModels.count > 0 || tzImagePickerVc.alwaysEnableDoneBtn;
    
//    _numberImageView.hidden = tzImagePickerVc.selectedModels.count <= 0;
//    _numberLabel.hidden = tzImagePickerVc.selectedModels.count <= 0;
//    _numberLabel.text = [NSString stringWithFormat:@"%zd",tzImagePickerVc.selectedModels.count];
    if ((long)tzImagePickerVc.maxImagesCount > 1) {
        if (tzImagePickerVc.selectedModels.count == 0) {
            [_doneButton setTitle:[NSString stringWithFormat:@"完成(%ld/%ld)",tzImagePickerVc.selectedModels.count,(long)tzImagePickerVc.maxImagesCount] forState: UIControlStateDisabled];
        } else {
            [_doneButton setTitle:[NSString stringWithFormat:@"完成(%ld/%ld)",tzImagePickerVc.selectedModels.count,(long)tzImagePickerVc.maxImagesCount] forState:UIControlStateNormal];
        }
        if(tzImagePickerVc.selectedModels.count > 0) {
            _doneButton.backgroundColor = tzImagePickerVc.oKButtonBackGroundColorEnabled;
        } else {
            _doneButton.backgroundColor = tzImagePickerVc.oKButtonBackGroundColorDisabled;
        }
    } else {
        [_doneButton setTitle:@"完成" forState:UIControlStateNormal];
        _doneButton.backgroundColor = tzImagePickerVc.oKButtonBackGroundColorEnabled;
    }
    _originalPhotoButton.enabled = tzImagePickerVc.selectedModels.count > 0;
    _originalPhotoButton.selected = (_isSelectOriginalPhoto && _originalPhotoButton.enabled);
    _originalPhotoLabel.hidden = (!_originalPhotoButton.isSelected);
    if (_isSelectOriginalPhoto) [self getSelectedPhotoBytes];
    
    if (tzImagePickerVc.photoPickerPageDidRefreshStateBlock) {
        tzImagePickerVc.photoPickerPageDidRefreshStateBlock(_collectionView, _bottomToolBar, _previewButton, _originalPhotoButton, _originalPhotoLabel, _doneButton, _numberImageView, _numberLabel, _divideLine);;
    }
}

- (void)pushPhotoPrevireViewController:(TZPhotoPreviewController *)photoPreviewVc {
    [self pushPhotoPrevireViewController:photoPreviewVc needCheckSelectedModels:NO];
}

- (void)pushPhotoPrevireViewController:(TZPhotoPreviewController *)photoPreviewVc needCheckSelectedModels:(BOOL)needCheckSelectedModels {
    __weak typeof(self) weakSelf = self;
    photoPreviewVc.isSelectOriginalPhoto = _isSelectOriginalPhoto;
    [photoPreviewVc setBackButtonClickBlock:^(BOOL isSelectOriginalPhoto) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.isSelectOriginalPhoto = isSelectOriginalPhoto;
        if (needCheckSelectedModels) {
            [strongSelf checkSelectedModels];
        }
        [strongSelf.collectionView reloadData];
        [strongSelf refreshBottomToolBarStatus];
    }];
    [photoPreviewVc setDoneButtonClickBlock:^(BOOL isSelectOriginalPhoto) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.isSelectOriginalPhoto = isSelectOriginalPhoto;
        [strongSelf doneButtonClick];
    }];
    [photoPreviewVc setDoneButtonClickBlockCropMode:^(UIImage *cropedImage, id asset) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSArray *assets = @[];
        if (asset) {
            assets = @[asset];
        }
        NSArray *photos = @[];
        if (cropedImage) {
            photos = @[cropedImage];
        }
        [strongSelf didGetAllPhotos:photos assets:assets infoArr:nil];
    }];
    [self.navigationController pushViewController:photoPreviewVc animated:YES];
}

- (void)getSelectedPhotoBytes {
    // 越南语 && 5屏幕时会显示不下，暂时这样处理
    if ([[TZImagePickerConfig sharedInstance].preferredLanguage isEqualToString:@"vi"] && self.view.tz_width <= 320) {
        return;
    }
    TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
    [[TZImageManager manager] getPhotosBytesWithArray:imagePickerVc.selectedModels completion:^(NSString *totalBytes) {
        self->_originalPhotoLabel.text = [NSString stringWithFormat:@"(%@)",totalBytes];
    }];
}

- (void)prepareScrollCollectionViewToBottom {
    if (_shouldScrollToBottom && _models.count > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self scrollCollectionViewToBottom];
            // try fix #1562：https://github.com/banchichen/TZImagePickerController/issues/1562
            if (@available(iOS 15.0, *)) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self scrollCollectionViewToBottom];
                });
            }
        });
    } else {
        _collectionView.hidden = NO;
    }
}

- (void)scrollCollectionViewToBottom {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    NSInteger item = 0;
    if (tzImagePickerVc.sortAscendingByModificationDate) {
        item = [self getAllCellCount] - 1;
    }
    [self->_collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForItem:item inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
    self->_shouldScrollToBottom = NO;
    self->_collectionView.hidden = NO;
}

- (void)checkSelectedModels {
    
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    NSMutableArray *selectedModels = tzImagePickerVc.selectedModels;

    NSMutableArray *checkSelectedModels = [[NSMutableArray alloc] init];
    for (int j = 0; j < selectedModels.count; j ++) {
        TZAssetModel *selectedModel = selectedModels[j];
        BOOL didFind = NO;
        
        for (int i = 0; i < _models.count; i ++) {
            TZAssetModel *orgModel = _models[i];
            if ([orgModel.asset.localIdentifier isEqualToString:selectedModel.asset.localIdentifier]) {
                didFind = YES;
                break;
            }
        }
        if (didFind) {
            [checkSelectedModels addObject:selectedModel];
        }
    }
    tzImagePickerVc.selectedModels = checkSelectedModels;
    
    NSMutableSet *selectedAssets = [NSMutableSet setWithCapacity:checkSelectedModels.count];
    NSMutableArray *selectedAssetArray = [[NSMutableArray alloc]init];
    for (TZAssetModel *model in checkSelectedModels) {
        [selectedAssets addObject:model.asset];
        [selectedAssetArray addObject:model.asset];
    }
    tzImagePickerVc.selectedAssets = selectedAssetArray;

    for (TZAssetModel *model in _models) {
        model.isSelected = NO;
        if ([selectedAssets containsObject:model.asset]) {
            model.isSelected = YES;
        }
    }
    [self refreshBottomToolBarStatus];
}

/// 选中/取消选中某张照片
- (void)setAsset:(PHAsset *)asset isSelect:(BOOL)isSelect {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    if (isSelect && [tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didSelectAsset:photo:isSelectOriginalPhoto:)]) {
        [self callDelegate:asset isSelect:YES];
    }
    if (!isSelect && [tzImagePickerVc.pickerDelegate respondsToSelector:@selector(imagePickerController:didDeselectAsset:photo:isSelectOriginalPhoto:)]) {
        [self callDelegate:asset isSelect:NO];
    }
}

/// 调用选中/取消选中某张照片的代理方法
- (void)callDelegate:(PHAsset *)asset isSelect:(BOOL)isSelect {
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    __weak typeof(self) weakSelf = self;
    __weak typeof(tzImagePickerVc) weakImagePickerVc= tzImagePickerVc;
    [[TZImageManager manager] getPhotoWithAsset:asset completion:^(UIImage *photo, NSDictionary *info, BOOL isDegraded) {
        if (isDegraded) return;
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong typeof(weakImagePickerVc) strongImagePickerVc = weakImagePickerVc;
        if (isSelect) {
            [strongImagePickerVc.pickerDelegate imagePickerController:strongImagePickerVc didSelectAsset:asset photo:photo isSelectOriginalPhoto:strongSelf.isSelectOriginalPhoto];
        } else {
            [strongImagePickerVc.pickerDelegate imagePickerController:strongImagePickerVc didDeselectAsset:asset photo:photo isSelectOriginalPhoto:strongSelf.isSelectOriginalPhoto];
        }
    }];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    NSString *type = [info objectForKey:UIImagePickerControllerMediaType];
    if ([type isEqualToString:@"public.image"]) {
        TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
        [imagePickerVc showProgressHUD];
        UIImage *photo = [info objectForKey:UIImagePickerControllerOriginalImage];
        NSDictionary *meta = [info objectForKey:UIImagePickerControllerMediaMetadata];
        if (photo) {
            self.isSavingMedia = YES;
            [[TZImageManager manager] savePhotoWithImage:photo meta:meta location:self.location completion:^(PHAsset *asset, NSError *error){
                self.isSavingMedia = NO;
                if (!error && asset) {
                    [self addPHAsset:asset];
                } else {
                    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
                    [tzImagePickerVc hideProgressHUD];
                }
            }];
            self.location = nil;
        }
    } else if ([type isEqualToString:@"public.movie"]) {
        TZImagePickerController *imagePickerVc = (TZImagePickerController *)self.navigationController;
        [imagePickerVc showProgressHUD];
        NSURL *videoUrl = [info objectForKey:UIImagePickerControllerMediaURL];
        if (videoUrl) {
            self.isSavingMedia = YES;
            [[TZImageManager manager] saveVideoWithUrl:videoUrl location:self.location completion:^(PHAsset *asset, NSError *error) {
                self.isSavingMedia = NO;
                if (!error && asset) {
                    [self addPHAsset:asset];
                } else {
                    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
                    [tzImagePickerVc hideProgressHUD];
                }
            }];
            self.location = nil;
        }
    }
}

- (void)addPHAsset:(PHAsset *)asset {
    TZAssetModel *assetModel = [[TZImageManager manager] createModelWithAsset:asset];
    TZImagePickerController *tzImagePickerVc = (TZImagePickerController *)self.navigationController;
    [tzImagePickerVc hideProgressHUD];
    if (tzImagePickerVc.sortAscendingByModificationDate) {
        [_models addObject:assetModel];
    } else {
        [_models insertObject:assetModel atIndex:0];
    }
    
    if (tzImagePickerVc.maxImagesCount <= 1) {
        if (tzImagePickerVc.allowCrop && asset.mediaType == PHAssetMediaTypeImage) {
            TZPhotoPreviewController *photoPreviewVc = [[TZPhotoPreviewController alloc] init];
            if (tzImagePickerVc.sortAscendingByModificationDate) {
                photoPreviewVc.currentIndex = _models.count - 1;
            } else {
                photoPreviewVc.currentIndex = 0;
            }
            photoPreviewVc.models = _models;
            [self pushPhotoPrevireViewController:photoPreviewVc];
        } else if (tzImagePickerVc.selectedModels.count < 1) {
            [tzImagePickerVc addSelectedModel:assetModel];
            [self doneButtonClick];
        }
        return;
    }
    
    if (tzImagePickerVc.selectedModels.count < tzImagePickerVc.maxImagesCount) {
        if (assetModel.type == TZAssetModelMediaTypeVideo && !tzImagePickerVc.allowPickingMultipleVideo) {
            // 不能多选视频的情况下，不选中拍摄的视频
        } else {
            if ([[TZImageManager manager] isAssetCannotBeSelected:assetModel.asset]) {
                return;
            }
            assetModel.isSelected = YES;
            [tzImagePickerVc addSelectedModel:assetModel];
            [self refreshBottomToolBarStatus];
        }
    }
    _collectionView.hidden = YES;
    [_collectionView reloadData];
    
    _shouldScrollToBottom = YES;
    [self prepareScrollCollectionViewToBottom];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc {
    [[PHPhotoLibrary sharedPhotoLibrary] unregisterChangeObserver:self];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // NSLog(@"%@ dealloc",NSStringFromClass(self.class));
}

#pragma mark - PHPhotoLibraryChangeObserver

- (void)photoLibraryDidChange:(PHChange *)changeInstance {
    if (self.isSavingMedia || self.isFetchingMedia) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        PHFetchResultChangeDetails *changeDetail = [changeInstance changeDetailsForFetchResult:self.model.result];
        if (changeDetail == nil) return;
        if (changeDetail.hasIncrementalChanges == NO) {
            [self.model refreshFetchResult];
            [self fetchAssetModels];
        } else {
            NSInteger insertedCount = changeDetail.insertedObjects.count;
            NSInteger removedCount = changeDetail.removedObjects.count;
            NSInteger changedCount = changeDetail.changedObjects.count;
            if (insertedCount > 0 || removedCount > 0 || changedCount > 0) {
                self.model.result = changeDetail.fetchResultAfterChanges;
                self.model.count = changeDetail.fetchResultAfterChanges.count;
                [self fetchAssetModels];
            }
        }
    });
}

#pragma mark - Asset Caching

- (void)resetCachedAssets {
    [[TZImageManager manager].cachingImageManager stopCachingImagesForAllAssets];
    self.previousPreheatRect = CGRectZero;
}

- (void)updateCachedAssets {
    BOOL isViewVisible = [self isViewLoaded] && [[self view] window] != nil;
    if (!isViewVisible) { return; }
    
    // The preheat window is twice the height of the visible rect.
    CGRect preheatRect = _collectionView.bounds;
    preheatRect = CGRectInset(preheatRect, 0.0f, -0.5f * CGRectGetHeight(preheatRect));
    
    /*
     Check if the collection view is showing an area that is significantly
     different to the last preheated area.
     */
    CGFloat delta = ABS(CGRectGetMidY(preheatRect) - CGRectGetMidY(self.previousPreheatRect));
    if (delta > CGRectGetHeight(_collectionView.bounds) / 3.0f) {
        
        // Compute the assets to start caching and to stop caching.
        NSMutableArray *addedIndexPaths = [NSMutableArray array];
        NSMutableArray *removedIndexPaths = [NSMutableArray array];
        
        [self computeDifferenceBetweenRect:self.previousPreheatRect andRect:preheatRect removedHandler:^(CGRect removedRect) {
            NSArray *indexPaths = [self aapl_indexPathsForElementsInRect:removedRect];
            [removedIndexPaths addObjectsFromArray:indexPaths];
        } addedHandler:^(CGRect addedRect) {
            NSArray *indexPaths = [self aapl_indexPathsForElementsInRect:addedRect];
            [addedIndexPaths addObjectsFromArray:indexPaths];
        }];
        
        NSArray *assetsToStartCaching = [self assetsAtIndexPaths:addedIndexPaths];
        NSArray *assetsToStopCaching = [self assetsAtIndexPaths:removedIndexPaths];
        
        // Update the assets the PHCachingImageManager is caching.
        [[TZImageManager manager].cachingImageManager startCachingImagesForAssets:assetsToStartCaching
                                                                       targetSize:AssetGridThumbnailSize
                                                                      contentMode:PHImageContentModeAspectFill
                                                                          options:nil];
        [[TZImageManager manager].cachingImageManager stopCachingImagesForAssets:assetsToStopCaching
                                                                      targetSize:AssetGridThumbnailSize
                                                                     contentMode:PHImageContentModeAspectFill
                                                                         options:nil];
        
        // Store the preheat rect to compare against in the future.
        self.previousPreheatRect = preheatRect;
    }
}

- (void)computeDifferenceBetweenRect:(CGRect)oldRect andRect:(CGRect)newRect removedHandler:(void (^)(CGRect removedRect))removedHandler addedHandler:(void (^)(CGRect addedRect))addedHandler {
    if (CGRectIntersectsRect(newRect, oldRect)) {
        CGFloat oldMaxY = CGRectGetMaxY(oldRect);
        CGFloat oldMinY = CGRectGetMinY(oldRect);
        CGFloat newMaxY = CGRectGetMaxY(newRect);
        CGFloat newMinY = CGRectGetMinY(newRect);
        
        if (newMaxY > oldMaxY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, oldMaxY, newRect.size.width, (newMaxY - oldMaxY));
            addedHandler(rectToAdd);
        }
        
        if (oldMinY > newMinY) {
            CGRect rectToAdd = CGRectMake(newRect.origin.x, newMinY, newRect.size.width, (oldMinY - newMinY));
            addedHandler(rectToAdd);
        }
        
        if (newMaxY < oldMaxY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, newMaxY, newRect.size.width, (oldMaxY - newMaxY));
            removedHandler(rectToRemove);
        }
        
        if (oldMinY < newMinY) {
            CGRect rectToRemove = CGRectMake(newRect.origin.x, oldMinY, newRect.size.width, (newMinY - oldMinY));
            removedHandler(rectToRemove);
        }
    } else {
        addedHandler(newRect);
        removedHandler(oldRect);
    }
}

- (NSArray *)assetsAtIndexPaths:(NSArray *)indexPaths {
    if (indexPaths.count == 0) { return nil; }
    
    NSMutableArray *assets = [NSMutableArray arrayWithCapacity:indexPaths.count];
    for (NSIndexPath *indexPath in indexPaths) {
        if (indexPath.item < _models.count) {
            TZAssetModel *model = _models[indexPath.item];
            [assets addObject:model.asset];
        }
    }
    
    return assets;
}

- (NSArray *)aapl_indexPathsForElementsInRect:(CGRect)rect {
    NSArray *allLayoutAttributes = [_collectionView.collectionViewLayout layoutAttributesForElementsInRect:rect];
    if (allLayoutAttributes.count == 0) { return nil; }
    NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:allLayoutAttributes.count];
    for (UICollectionViewLayoutAttributes *layoutAttributes in allLayoutAttributes) {
        NSIndexPath *indexPath = layoutAttributes.indexPath;
        [indexPaths addObject:indexPath];
    }
    return indexPaths;
}
#pragma clang diagnostic pop

@end



@implementation TZCollectionView

- (BOOL)touchesShouldCancelInContentView:(UIView *)view {
    if ([view isKindOfClass:[UIControl class]]) {
        return YES;
    }
    return [super touchesShouldCancelInContentView:view];
}

@end
