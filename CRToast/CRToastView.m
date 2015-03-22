//
//  CRToastView.m
//  CRToastDemo
//
//  Created by Daniel on 12/19/14.
//  Copyright (c) 2014 Collin Ruffenach. All rights reserved.
//

#import "CRToastView.h"
#import "CRToast.h"
#import "CRToastLayoutHelpers.h"

@interface CRToastView ()
@property (strong, nonatomic) NSLayoutConstraint *imageViewLeading;
@property (strong, nonatomic) NSLayoutConstraint *imageViewTrailing;
@property (strong, nonatomic) NSLayoutConstraint *activityViewLeading;
@property (strong, nonatomic) NSLayoutConstraint *activityViewTrailing;
@end

static CGFloat const kCRStatusBarViewNoImageLeftContentInset = 10;
static CGFloat const kCRStatusBarViewNoImageRightContentInset = 10;

// UIApplication's statusBarFrame will return a height for the status bar that includes
// a 5 pixel vertical padding. This frame height is inappropriate to use when centering content
// vertically under the status bar. This adjustment is uesd to correct the frame height when centering
// content under the status bar.

static CGFloat const CRStatusBarViewUnderStatusBarYOffsetAdjustment = -5;

static CGFloat CRImageViewFrameXOffsetForAlignment(CRToastAccessoryViewAlignment alignment, CGSize contentSize) {
    CGFloat imageSize = contentSize.height;
    CGFloat xOffset = 0;

    if (alignment == CRToastAccessoryViewAlignmentLeft) {
        xOffset = 0;
    } else if (alignment == CRToastAccessoryViewAlignmentCenter) {
        // Calculate mid point of contentSize, then offset for x for full image width
        // that way center of image will be center of content view
        xOffset = (contentSize.width / 2) - (imageSize / 2);
    } else if (alignment == CRToastAccessoryViewAlignmentRight) {
        xOffset = contentSize.width - imageSize;
    }
    
    return xOffset;
}

static CGFloat CRContentXOffsetForViewAlignmentAndWidth(CRToastAccessoryViewAlignment alignment, CGFloat width) {
    return (width == 0 || alignment != CRToastAccessoryViewAlignmentLeft) ?
    kCRStatusBarViewNoImageLeftContentInset :
    width + kCRStatusBarViewNoImageLeftContentInset;
}

static CGFloat CRToastWidthOfViewWithAlignment(CGFloat height, BOOL showing, CRToastAccessoryViewAlignment alignment) {
    return (!showing || alignment == CRToastAccessoryViewAlignmentCenter) ?
    0 :
    height;
}

CGFloat CRContentWidthForAccessoryViewsWithAlignments(CGFloat fullContentWidth, CGFloat fullContentHeight, BOOL showingImage, CRToastAccessoryViewAlignment imageAlignment, BOOL showingActivityIndicator, CRToastAccessoryViewAlignment activityIndicatorAlignment) {
    CGFloat width = fullContentWidth;
    
    width -= CRToastWidthOfViewWithAlignment(fullContentHeight, showingImage, imageAlignment);
    width -= CRToastWidthOfViewWithAlignment(fullContentHeight, showingActivityIndicator, activityIndicatorAlignment);
    
    if (imageAlignment == activityIndicatorAlignment && showingActivityIndicator && showingImage) {
        width += fullContentWidth;
    }
    
    if (!showingImage && !showingActivityIndicator) {
        width -= (kCRStatusBarViewNoImageLeftContentInset + kCRStatusBarViewNoImageRightContentInset);
    }
    
    return width;
}

static CGFloat CRCenterXForActivityIndicatorWithAlignment(CRToastAccessoryViewAlignment alignment, CGFloat viewWidth, CGFloat contentWidth) {
    CGFloat center = 0;
    CGFloat offset = viewWidth / 2;
    
    switch (alignment) {
        case CRToastAccessoryViewAlignmentLeft:
            center = offset; break;
        case CRToastAccessoryViewAlignmentCenter:
            center = (contentWidth / 2); break;
        case CRToastAccessoryViewAlignmentRight:
            center = contentWidth - offset; break;
    }
    
    return center;
}

/**
 Calculate the constraints necessary for a given accessory view max height

 @note This does not create any kind of `X` constraint. That is to be determined at another time.

 @param accessoryView @c UIView subclass, which should be the accessory view, for creating the constraints with
 @param maxHeight        maximum height the accessory should be constrained to keeping a 1:1 aspect ratio
 @param shouldHaveWidth  @c YES if the view should have 1:1 aspect ratio with height. @c NO to have @c 0 width set
 @return @c NSArray of @c NSLayoutConstraints which may be applied to the @c CRToastView for laying out the accessory view
 */
static NSArray * CRConstraitsForAccessoryViewWithMaxHeight(UIView *accessoryView, CGFloat maxHeight, BOOL shouldHaveWidth) {

    NSLayoutConstraint *centerY = [NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:accessoryView.superview attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
    NSLayoutConstraint *maximumHeight = [NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:maxHeight];

    NSLayoutConstraint *width;
    if (shouldHaveWidth) {
        width = [NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:accessoryView attribute:NSLayoutAttributeHeight multiplier:1 constant:0];
    } else {
        width = [NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1 constant:0];
    }

    return @[centerY, maximumHeight, width];
}

/**
 <#Description#>

 @param accessoryView <#accessoryView description#>
 @param alignment     <#alignment description#>

 @return <#return value description#>
 */
static NSLayoutConstraint * CRConstraintForAccessoryViewXPositionWithAlignment(UIView *accessoryView, CRToastAccessoryViewAlignment alignment) {
    NSLayoutAttribute accessoryViewToAttribute;
    NSLayoutAttribute superViewToAttribute;
    switch (alignment) {
        case CRToastAccessoryViewAlignmentLeft:
            accessoryViewToAttribute = NSLayoutAttributeLeft;
            superViewToAttribute     = NSLayoutAttributeLeftMargin;
            break;
        case CRToastAccessoryViewAlignmentCenter:
            accessoryViewToAttribute = NSLayoutAttributeCenterX;
            superViewToAttribute     = NSLayoutAttributeCenterX;
            break;
        case CRToastAccessoryViewAlignmentRight:
            accessoryViewToAttribute = NSLayoutAttributeRight;
            superViewToAttribute     = NSLayoutAttributeRightMargin;
            break;
    }

    return [NSLayoutConstraint constraintWithItem:accessoryView attribute:accessoryViewToAttribute relatedBy:NSLayoutRelationEqual toItem:accessoryView.superview attribute:superViewToAttribute multiplier:1 constant:0];
}

/**
 <#Description#>

 @param accessoryView <#accessoryView description#>
 @param relatedToView <#relatedToView description#>

 @return <#return value description#>
 */
static NSLayoutConstraint * CRConstraintForCenteredAccessoryViewWithRelationToCenteredView(UIView *accessoryView, UIView *relatedToView) {
    return [NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:relatedToView attribute:NSLayoutAttributeLeftMargin multiplier:1 constant:10];
}

/**
 <#Description#>

 @param bounds               <#bounds description#>
 @param heightOffset         <#heightOffset description#>
 @param showingAccessoryView <#showingAccessoryView description#>

 @return <#return value description#>
 */
static CGSize CRSizeForLabelsWithinBounds(CGRect bounds, CGFloat heightOffset, BOOL showingAccessoryView) {
    CGFloat height = CGRectGetHeight(bounds) - heightOffset;
    CGFloat width = CGRectGetWidth(bounds);
    if (showingAccessoryView) {
        width -= (height * 2);
    }
    return CGSizeMake(width, height);
}

/**
 <#Description#>

 @param label                    <#label description#>
 @param labelAlignment           <#labelAlignment description#>
 @param imageView                <#imageView description#>
 @param imageAlignment           <#imageAlignment description#>
 @param showingImage             <#showingImage description#>
 @param activityIndicator        <#activityIndicator description#>
 @param activityIdicatorAligment <#activityIdicatorAligment description#>
 @param showingActivityIndicator <#showingActivityIndicator description#>

 @return <#return value description#>
 */
static NSLayoutConstraint * CRConstraintForLabelXPosition(UILabel *label, NSTextAlignment labelAlignment, UIImage *imageView, CRToastAccessoryViewAlignment imageAlignment, BOOL showingImage, UIActivityIndicatorView *activityIndicator, CRToastAccessoryViewAlignment activityIdicatorAligment, BOOL showingActivityIndicator) {
    if (!showingImage && !showingActivityIndicator) {
        //
    }

    if (labelAlignment == NSTextAlignmentLeft &&
        ((activityIdicatorAligment == CRToastAccessoryViewAlignmentLeft && showingActivityIndicator) ||
         (imageAlignment == CRToastAccessoryViewAlignmentLeft && showingImage))) {

    }

    if (labelAlignment == NSTextAlignmentCenter &&
        ((activityIdicatorAligment == CRToastAccessoryViewAlignmentCenter && showingActivityIndicator) ||
         (imageAlignment == CRToastAccessoryViewAlignmentCenter && showingImage))) {

    }

    if (labelAlignment == NSTextAlignmentRight &&
        ((activityIdicatorAligment == CRToastAccessoryViewAlignmentRight && showingActivityIndicator) ||
         (imageAlignment == CRToastAccessoryViewAlignmentRight && showingImage))) {

    }

    return [NSLayoutConstraint constraintWithItem:label attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:label.superview attribute:NSLayoutAttributeLeftMargin multiplier:0 constant:0];
}

@implementation CRToastView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = YES;
        self.accessibilityLabel = NSStringFromClass([self class]);
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        imageView.userInteractionEnabled = NO;
        imageView.contentMode = UIViewContentModeCenter;
        imageView.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:imageView];
        self.imageView = imageView;
        
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        activityIndicator.userInteractionEnabled = NO;
        activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:activityIndicator];
        self.activityIndicator = activityIndicator;
        
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
        label.userInteractionEnabled = NO;
//        label.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:label];
        self.label = label;
        
        UILabel *subtitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        subtitleLabel.userInteractionEnabled = NO;
//        subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:subtitleLabel];
        self.subtitleLabel = subtitleLabel;
        
        self.isAccessibilityElement = YES;
    }
    return self;
}

/* AUTOLAYOUT CRAP
 Image/Activity Indicator
 - Always Center Y to container

 Lables
 - Take Priority if two items are center aligned
 - Center Content with insets correctly if center aligned and only one item on left or right
 */
- (void)applyConstraintsToViews {
    // Array of Constraints for Image
    CGRect contentFrame = self.bounds;
    CGFloat statusBarYOffset = self.toast.displayUnderStatusBar ? (CRGetStatusBarHeight()+CRStatusBarViewUnderStatusBarYOffsetAdjustment) : 0;
    CGFloat maxHeight = CGRectGetHeight(contentFrame) - statusBarYOffset;

    CGSize imageSize = self.imageView.image.size;
    BOOL showingImage = imageSize.width != 0;
    [self addConstraints:CRConstraitsForAccessoryViewWithMaxHeight(self.imageView, maxHeight, showingImage)];

    // Array of Constraints for Activity Indicator
    BOOL showingActivityIndicator = self.toast.showActivityIndicator;
    [self addConstraints:CRConstraitsForAccessoryViewWithMaxHeight(self.activityIndicator, maxHeight, showingActivityIndicator)];

    if (self.toast.text || self.toast.subtitleText) {

        // Add constraints for label & subtitle label
//        [self addConstraints:CRConstraintsForLabelsWithToast(self.label, self.subtitleLabel, self.toast)];

        CGSize fitSize = CRSizeForLabelsWithinBounds(contentFrame, maxHeight, (showingImage || showingActivityIndicator));
        [self.label sizeThatFits:fitSize];
        [self.subtitleLabel sizeThatFits:fitSize];


        UIView *associatedView;
        if (showingActivityIndicator) {
            associatedView = self.activityIndicator;
        } else if (showingImage) {
            associatedView = self.imageView;
        } else {
            associatedView = self;
        }

        NSLayoutConstraint *labelXPosition;
        NSLayoutConstraint *subtitleXPosition;
        switch (self.toast.textAlignment) {
            case NSTextAlignmentLeft:
                labelXPosition = [NSLayoutConstraint constraintWithItem:self.label attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:associatedView attribute:NSLayoutAttributeRight multiplier:1 constant:10];
                break;
            case NSTextAlignmentCenter:
                labelXPosition = [NSLayoutConstraint constraintWithItem:self.label attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:self.label.superview attribute:NSLayoutAttributeCenterX multiplier:1 constant:0];
                break;
            case NSTextAlignmentRight:
                labelXPosition = [NSLayoutConstraint constraintWithItem:self.label attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:associatedView attribute:NSLayoutAttributeRight multiplier:1 constant:10];
                break;
            default:
                break;
        }
        switch (self.toast.subtitleTextAlignment) {
            case NSTextAlignmentLeft:

                break;
            case NSTextAlignmentCenter:

                break;
            case NSTextAlignmentRight:

                break;
            default:
                break;
        }
//        CGFloat statusBarYOffset = self.toast.displayUnderStatusBar ? (CRGetStatusBarHeight()+CRStatusBarViewUnderStatusBarYOffsetAdjustment) : 0;


        if (self.toast.textAlignment == NSTextAlignmentCenter && (self.toast.imageAlignment == CRToastAccessoryViewAlignmentCenter || self.toast.activityViewAlignment == CRToastAccessoryViewAlignmentCenter)) {
            [self addConstraint:CRConstraintForCenteredAccessoryViewWithRelationToCenteredView(self.imageView, self.label)];
            [self addConstraint:CRConstraintForCenteredAccessoryViewWithRelationToCenteredView(self.activityIndicator, self.label)];
        } else {
            [self addConstraint:CRConstraintForAccessoryViewXPositionWithAlignment(self.imageView, self.toast.imageAlignment)];
            [self addConstraint:CRConstraintForAccessoryViewXPositionWithAlignment(self.activityIndicator, self.toast.activityViewAlignment)];
        }

    } else {
        // We have no text, lets just align and look good.
        [self addConstraint:CRConstraintForAccessoryViewXPositionWithAlignment(self.imageView, self.toast.imageAlignment)];
        [self addConstraint:CRConstraintForAccessoryViewXPositionWithAlignment(self.activityIndicator, self.toast.activityViewAlignment)];
    }
    /*
     CGFloat height = MIN([self.toast.text boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
     options:NSStringDrawingUsesLineFragmentOrigin
     attributes:@{NSFontAttributeName : self.toast.font}
     context:nil].size.height,
     CGRectGetHeight(contentFrame));
     */
    // Array of Constraints for Label
    // Array of Constraints for SubTitle Label
}

/*
- (void)layoutSubviews {
#warning FUCK THIS NOISE! Use autolayout
    [super layoutSubviews];
    CGRect contentFrame = self.bounds;
    CGSize imageSize = self.imageView.image.size;
    
    CGFloat statusBarYOffset = self.toast.displayUnderStatusBar ? (CRGetStatusBarHeight()+CRStatusBarViewUnderStatusBarYOffsetAdjustment) : 0;
    contentFrame.size.height = CGRectGetHeight(contentFrame) - statusBarYOffset;
    
    self.backgroundView.frame = self.bounds;
    
    CGFloat imageXOffset = CRImageViewFrameXOffsetForAlignment(self.toast.imageAlignment, contentFrame.size);
    self.imageView.frame = CGRectMake(imageXOffset,
                                      statusBarYOffset,
                                      imageSize.width == 0 ?
                                      0 :
                                      CGRectGetHeight(contentFrame),
                                      imageSize.height == 0 ?
                                      0 :
                                      CGRectGetHeight(contentFrame));
    
    CGFloat imageWidth = imageSize.width == 0 ? 0 : CGRectGetMaxX(_imageView.frame);
    CGFloat x = CRContentXOffsetForViewAlignmentAndWidth(self.toast.imageAlignment, imageWidth);
    
    if (self.toast.showActivityIndicator) {
        CGFloat centerX = CRCenterXForActivityIndicatorWithAlignment(self.toast.activityViewAlignment, CGRectGetHeight(contentFrame), CGRectGetWidth(contentFrame));
        self.activityIndicator.center = CGPointMake(centerX,
                                     CGRectGetMidY(contentFrame) + statusBarYOffset);
        
        [self.activityIndicator startAnimating];
        x = MAX(CRContentXOffsetForViewAlignmentAndWidth(self.toast.activityViewAlignment, CGRectGetHeight(contentFrame)), x);

        [self bringSubviewToFront:self.activityIndicator];
    }
    
    BOOL showingImage = imageSize.width > 0;
    
    CGFloat width = CRContentWidthForAccessoryViewsWithAlignments(CGRectGetWidth(contentFrame),
                                                                  CGRectGetHeight(contentFrame),
                                                                  showingImage,
                                                                  self.toast.imageAlignment,
                                                                  self.toast.showActivityIndicator,
                                                                  self.toast.activityViewAlignment);
    
    if (self.toast.subtitleText == nil) {
        self.label.frame = CGRectMake(x,
                                      statusBarYOffset,
                                      width,
                                      CGRectGetHeight(contentFrame));
    } else {
        CGFloat height = MIN([self.toast.text boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
                                                           options:NSStringDrawingUsesLineFragmentOrigin
                                                        attributes:@{NSFontAttributeName : self.toast.font}
                                                           context:nil].size.height,
                             CGRectGetHeight(contentFrame));
        CGFloat subtitleHeight = [self.toast.subtitleText boundingRectWithSize:CGSizeMake(width, MAXFLOAT)
                                                                       options:NSStringDrawingUsesLineFragmentOrigin
                                                                    attributes:@{NSFontAttributeName : self.toast.subtitleFont }
                                                                       context:nil].size.height;
        if ((CGRectGetHeight(contentFrame) - (height + subtitleHeight)) < 5) {
            subtitleHeight = (CGRectGetHeight(contentFrame) - (height))-10;
        }
        CGFloat offset = (CGRectGetHeight(contentFrame) - (height + subtitleHeight))/2;
        
        self.label.frame = CGRectMake(x,
                                      offset+statusBarYOffset,
                                      CGRectGetWidth(contentFrame)-x-kCRStatusBarViewNoImageRightContentInset,
                                      height);
        
        
        self.subtitleLabel.frame = CGRectMake(x,
                                              height+offset+statusBarYOffset,
                                              CGRectGetWidth(contentFrame)-x-kCRStatusBarViewNoImageRightContentInset,
                                              subtitleHeight);
    }
}
*/

#pragma mark - Overrides

- (void)setToast:(CRToast *)toast {
    _toast = toast;
    _label.text = toast.text;
    _label.font = toast.font;
    _label.textColor = toast.textColor;
    _label.textAlignment = toast.textAlignment;
    _label.numberOfLines = toast.textMaxNumberOfLines;
    _label.shadowOffset = toast.textShadowOffset;
    _label.shadowColor = toast.textShadowColor;
    if (toast.subtitleText != nil) {
        _subtitleLabel.text = toast.subtitleText;
        _subtitleLabel.font = toast.subtitleFont;
        _subtitleLabel.textColor = toast.subtitleTextColor;
        _subtitleLabel.textAlignment = toast.subtitleTextAlignment;
        _subtitleLabel.numberOfLines = toast.subtitleTextMaxNumberOfLines;
        _subtitleLabel.shadowOffset = toast.subtitleTextShadowOffset;
        _subtitleLabel.shadowColor = toast.subtitleTextShadowColor;
    }
    _imageView.image = toast.image;
    _imageView.contentMode = toast.imageContentMode;
    _activityIndicator.activityIndicatorViewStyle = toast.activityIndicatorViewStyle;
    self.backgroundColor = toast.backgroundColor;
    
    if (toast.backgroundView) {
        _backgroundView = toast.backgroundView;
        if (!_backgroundView.superview) {
            [self insertSubview:_backgroundView atIndex:0];
        }
    }

    [self applyConstraintsToViews];
}

@end
