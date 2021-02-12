#import <React/RCTImageLoader.h>
#import "ZarMeasureView.h"


@implementation ZarMeasureView {
    CTZarMeasureView *_view;
    __weak RCTBridge *_bridge;
}


#pragma mark - initialization

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

- (instancetype)initWithBridge:(RCTBridge *)bridge
{
    if ((self = [super init])) {
        _bridge = bridge;
    }

    return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];

    if (@available(iOS 11.0, *)) {
        _view = [[CTZarMeasureView alloc] initWithFrame:frame];
//        _view.onReady = self.onCameraReady;
//        _view.onMountError = self.onMountError;
        
        [self addSubview:_view];
    } else {
        _view = nil;
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if(_view != nil){
        float rootViewWidth = self.frame.size.width;
        float rootViewHeight = self.frame.size.height;
        _view.frame = CGRectMake(0, 0, rootViewWidth, rootViewHeight);
    }
}


- (void)dealloc
{
    
}

- (void)willMoveToSuperview:(nullable UIView *)newSuperview;
{
    // cleanup on deallocate
    // cancel any request in progress
    if(newSuperview == nil){
    }

    [super willMoveToSuperview:newSuperview];
}


@end
