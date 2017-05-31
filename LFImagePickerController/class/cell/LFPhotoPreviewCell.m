//
//  LFPhotoPreviewCell.m
//  LFImagePickerController
//
//  Created by LamTsanFeng on 2017/2/14.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFPhotoPreviewCell.h"
#import "UIView+LFFrame.h"
#import "LFAssetManager.h"
#import "LFPhotoEditManager.h"
#import "LFPhotoEdit.h"
#import <PhotosUI/PhotosUI.h>

#import "LFGifPlayerManager.h"

@interface LFProgressView : UIView

@property (nonatomic, assign) double progress;
@property (nonatomic, strong) CAShapeLayer *progressLayer;

@end

@implementation LFProgressView

- (instancetype)init {
    self = [super init];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        
        _progressLayer = [CAShapeLayer layer];
        _progressLayer.fillColor = [[UIColor clearColor] CGColor];
        _progressLayer.strokeColor = [[UIColor whiteColor] CGColor];
        _progressLayer.opacity = 1;
        _progressLayer.lineCap = kCALineCapRound;
        _progressLayer.lineWidth = 5;
        
        [_progressLayer setShadowColor:[UIColor blackColor].CGColor];
        [_progressLayer setShadowOffset:CGSizeMake(1, 1)];
        [_progressLayer setShadowOpacity:0.5];
        [_progressLayer setShadowRadius:2];
    }
    return self;
}

- (void)drawRect:(CGRect)rect {
    CGPoint center = CGPointMake(rect.size.width / 2, rect.size.height / 2);
    CGFloat radius = rect.size.width / 2;
    CGFloat startA = - M_PI_2;
    CGFloat endA = - M_PI_2 + M_PI * 2 * _progress;
    _progressLayer.frame = self.bounds;
    UIBezierPath *path = [UIBezierPath bezierPathWithArcCenter:center radius:radius startAngle:startA endAngle:endA clockwise:YES];
    _progressLayer.path =[path CGPath];
    
    [_progressLayer removeFromSuperlayer];
    [self.layer addSublayer:_progressLayer];
}

- (void)setProgress:(double)progress {
    _progress = progress;
    [self setNeedsDisplay];
}

@end



@interface LFPhotoPreviewCell () <UIScrollViewDelegate, PHLivePhotoViewDelegate>
@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) PHLivePhotoView *livePhotoView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) UIView *imageContainerView;
@property (nonatomic, strong) LFProgressView *progressView;
@end

@implementation LFPhotoPreviewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        
        _scrollView = [[UIScrollView alloc] init];
        _scrollView.frame = CGRectMake(0, 0, self.width, self.height);
        _scrollView.bouncesZoom = YES;
        _scrollView.maximumZoomScale = 2.5;
        _scrollView.minimumZoomScale = 1.0;
        _scrollView.multipleTouchEnabled = YES;
        _scrollView.delegate = self;
        _scrollView.scrollsToTop = NO;
        _scrollView.showsHorizontalScrollIndicator = NO;
        _scrollView.showsVerticalScrollIndicator = NO;
        _scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _scrollView.delaysContentTouches = NO;
        _scrollView.canCancelContentTouches = YES;
        _scrollView.alwaysBounceVertical = NO;
        [self.contentView addSubview:_scrollView];
        
        _imageContainerView = [[UIView alloc] init];
        _imageContainerView.clipsToBounds = YES;
        _imageContainerView.contentMode = UIViewContentModeScaleAspectFill;
        [_scrollView addSubview:_imageContainerView];
        
        UIView *view = [self subViewInitDisplayView];
        if (view) {
            [_imageContainerView addSubview:view];
        }
        
        UITapGestureRecognizer *tap1 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTap:)];
        [self addGestureRecognizer:tap1];
        UITapGestureRecognizer *tap2 = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doubleTap:)];
        tap2.numberOfTapsRequired = 2;
        [tap1 requireGestureRecognizerToFail:tap2];
        [self addGestureRecognizer:tap2];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self resizeSubviews];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    [[LFGifPlayerManager shared] stopGIFWithKey:[NSString stringWithFormat:@"%zd", [self.model hash]]];
    _model = nil;
    [self subViewReset];
}

- (UIImage *)previewImage
{
    return self.imageView.image;
}

- (void)setPreviewImage:(UIImage *)previewImage
{
    self.imageView.image = previewImage;
    [self resizeSubviews];
}

- (void)setModel:(LFAsset *)model
{
    _model = model;
    /** 优先显示编辑图片 */
    LFPhotoEdit *photoEdit = [[LFPhotoEditManager manager] photoEditForAsset:model];
    if (photoEdit.editPreviewImage) {
        self.previewImage = photoEdit.editPreviewImage;
    } else if (model.previewImage) { /** 显示自定义图片 */
        self.previewImage = model.previewImage;
    } else {
        
        void (^completion)(id data,NSDictionary *info,BOOL isDegraded) = ^(id data,NSDictionary *info,BOOL isDegraded){
            if ([model isEqual:self.model]) {
                if ([data isKindOfClass:[UIImage class]]) { /** image */
                    self.previewImage = (UIImage *)data;
                } else if ([data isKindOfClass:[NSData class]]) { /** gif */
                    NSString *modelKey = [NSString stringWithFormat:@"%zd", [self.model hash]];
                    [[LFGifPlayerManager shared] transformGifDataToSampBufferRef:data key:modelKey execution:^(CGImageRef imageData, NSString *key) {
                        if ([modelKey isEqualToString:key]) {
                            self.imageView.layer.contents = (__bridge id _Nullable)(imageData);
                        }
                    } fail:^(NSString *key) {
                    }];
                    /** 这个方式加载GIF内存使用非常高 */
//                    self.previewImage = [UIImage LF_imageWithImageData:data];
                } else if ([data isKindOfClass:[PHLivePhoto class]]) { /** live photo */
                    self.livePhotoView.livePhoto = data;
                    [self.livePhotoView startPlaybackWithStyle:PHLivePhotoViewPlaybackStyleFull];
                }
                _progressView.hidden = YES;
                if (self.imageProgressUpdateBlock) {
                    self.imageProgressUpdateBlock(1);
                }
            }
        };
        
        void (^progressHandler)(double progress, NSError *error, BOOL *stop, NSDictionary *info) = ^(double progress, NSError *error, BOOL *stop, NSDictionary *info){
            if ([model isEqual:self.model]) {
                _progressView.hidden = NO;
                [self bringSubviewToFront:_progressView];
                progress = progress > 0.02 ? progress : 0.02;;
                _progressView.progress = progress;
                if (self.imageProgressUpdateBlock) {
                    self.imageProgressUpdateBlock(progress);
                }
            }
        };
        
        
        /** 如果已被设置图片，忽略这次图片获取 */
        if (self.previewImage == nil) {
            /** 普通图片处理 */
            [[LFAssetManager manager] getPhotoWithAsset:model.asset photoWidth:[UIScreen mainScreen].bounds.size.width completion:completion progressHandler:progressHandler networkAccessAllowed:YES];
        }
        
        if (self.displayGif && model.subType == LFAssetSubMediaTypeGIF) { /** GIF图片处理 */
            [[LFAssetManager manager] getPhotoDataWithAsset:model.asset completion:completion progressHandler:progressHandler networkAccessAllowed:YES];
        } else if (self.displayLivePhoto && model.subType == LFAssetSubMediaTypeLivePhoto) { /** live photo */
            [[LFAssetManager manager] getLivePhotoWithAsset:model.asset photoWidth:[UIScreen mainScreen].bounds.size.width completion:completion progressHandler:progressHandler networkAccessAllowed:YES];
        }
    }
}

- (void)willDisplayCell
{
    if (self.displayGif && self.model.subType == LFAssetSubMediaTypeGIF) { /** GIF图片处理 */
        [self setModel:self.model];
    } else if (self.displayLivePhoto && self.model.subType == LFAssetSubMediaTypeLivePhoto) { /** live photo */
        _livePhotoView.delegate = self;
        [_livePhotoView startPlaybackWithStyle:PHLivePhotoViewPlaybackStyleFull];
    }
}

- (void)didEndDisplayCell
{
    if (self.displayGif && self.model.subType == LFAssetSubMediaTypeGIF) { /** GIF图片处理 */
        [[LFGifPlayerManager shared] stopGIFWithKey:[NSString stringWithFormat:@"%zd", [self.model hash]]];
    } else if (self.displayLivePhoto && self.model.subType == LFAssetSubMediaTypeLivePhoto) { /** live photo */
        _livePhotoView.delegate = nil;
        [_livePhotoView stopPlayback];
    }
}

- (void)resizeSubviews {
    _imageContainerView.origin = CGPointZero;
    _imageContainerView.width = self.scrollView.width;
    
    CGSize imageSize = [self subViewImageSize];
    if (!CGSizeEqualToSize(imageSize, CGSizeZero)) {
        if (imageSize.height / imageSize.width > self.height / self.scrollView.width) {
            _imageContainerView.height = floor(imageSize.height / (imageSize.width / self.scrollView.width));
        } else {
            CGFloat height = imageSize.height / imageSize.width * self.scrollView.width;
            if (height < 1 || isnan(height)) height = self.height;
            height = floor(height);
            _imageContainerView.height = height;
            _imageContainerView.centerY = self.height / 2;
        }
        if (_imageContainerView.height > self.height && _imageContainerView.height - self.height <= 1) {
            _imageContainerView.height = self.height;
        }
        CGFloat contentSizeH = MAX(_imageContainerView.height, self.height);
        _scrollView.contentSize = CGSizeMake(self.scrollView.width, contentSizeH);
        [_scrollView scrollRectToVisible:self.bounds animated:NO];
        _scrollView.alwaysBounceVertical = _imageContainerView.height <= self.height ? NO : YES;
        _imageView.frame = _imageContainerView.bounds;
        _livePhotoView.frame = _imageContainerView.bounds;
    }
}

#pragma mark - UITapGestureRecognizer Event

- (void)doubleTap:(UITapGestureRecognizer *)tap {
    if (_scrollView.zoomScale > 1.0) {
        _scrollView.contentInset = UIEdgeInsetsZero;
        [_scrollView setZoomScale:1.0 animated:YES];
    } else {
        CGPoint touchPoint = [tap locationInView:self.imageView];
        CGFloat newZoomScale = _scrollView.maximumZoomScale;
        CGFloat xsize = self.frame.size.width / newZoomScale;
        CGFloat ysize = self.frame.size.height / newZoomScale;
        [_scrollView zoomToRect:CGRectMake(touchPoint.x - xsize/2, touchPoint.y - ysize/2, xsize, ysize) animated:YES];
    }
}

- (void)singleTap:(UITapGestureRecognizer *)tap {
    if (self.singleTapGestureBlock) {
        self.singleTapGestureBlock();
    }
}

#pragma mark - UIScrollViewDelegate

- (nullable UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView {
    return _imageContainerView;
}

- (void)scrollViewDidZoom:(UIScrollView *)scrollView {
    [self refreshImageContainerViewCenter];
}

#pragma mark - PHLivePhotoViewDelegate
- (void)livePhotoView:(PHLivePhotoView *)livePhotoView didEndPlaybackWithStyle:(PHLivePhotoViewPlaybackStyle)playbackStyle
{
    if (playbackStyle == PHLivePhotoViewPlaybackStyleFull) {
        [livePhotoView startPlaybackWithStyle:playbackStyle];
    }
}

#pragma mark - Private

- (void)refreshImageContainerViewCenter {
    CGFloat offsetX = (_scrollView.width > _scrollView.contentSize.width) ? ((_scrollView.width - _scrollView.contentSize.width) * 0.5) : 0.0;
    CGFloat offsetY = (_scrollView.height > _scrollView.contentSize.height) ? ((_scrollView.height - _scrollView.contentSize.height) * 0.5) : 0.0;
    self.imageContainerView.center = CGPointMake(_scrollView.contentSize.width * 0.5 + offsetX, _scrollView.contentSize.height * 0.5 + offsetY);
}

/** 创建显示视图 */
- (UIView *)subViewInitDisplayView
{
    if (_imageView == nil) {
        _imageView = [[UIImageView alloc] init];
        //        _imageView.backgroundColor = [UIColor colorWithWhite:1.000 alpha:0.500];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
    }
    
    return _imageView;
}

/** 图片大小 */
- (CGSize)subViewImageSize
{
    return self.imageView.image.size;
}

/** 重置视图 */
- (void)subViewReset
{
    self.imageView.image = nil;
    [_livePhotoView stopPlayback];
    _livePhotoView.livePhoto = nil;
    [_livePhotoView removeFromSuperview];
}

- (PHLivePhotoView *)livePhotoView
{
    if (_livePhotoView == nil) {
        _livePhotoView = [[PHLivePhotoView alloc] initWithFrame:_imageContainerView.bounds];
        _livePhotoView.muted = YES;
        _livePhotoView.contentMode = UIViewContentModeScaleAspectFill;
    }
    _livePhotoView.delegate = self;
    [_imageContainerView addSubview:_livePhotoView];
    return _livePhotoView;
}


@end

