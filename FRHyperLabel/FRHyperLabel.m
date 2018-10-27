//
//  FRHyperLabel.m
//  FRHyperLabelDemo
//
//  Created by Jinghan Wang on 23/9/15.
//  Copyright © 2015 JW. All rights reserved.
//

#import "FRHyperLabel.h"
#import <CoreText/CoreText.h>

@interface FRHyperLabel ()

@property (nonatomic) NSMutableDictionary *handlerDictionary;
@property (nonatomic) NSAttributedString *backupAttributedText;

/*
 * Problem:- if we use this label inside a scrollView, touchesBegan will call with a significant delay.(kind of longPress)
 *
 * Solution:- so we have to handle the user interaction events through a delegate.
 *
 * Note:- if we use TapGesture, we can't get UIGestureRecognizerStateBegan.
 * but we need that state for apperance change
 * so we are using LongPressGesture.
 */
@property (nonatomic) UILongPressGestureRecognizer *longPressGestureRecognizer;

@end

@implementation FRHyperLabel

static CGFloat highLightAnimationTime = 0.15;
static UIColor *FRHyperLabelLinkColorDefault;
static UIColor *FRHyperLabelLinkColorHighlight;

+ (void)initialize {
	if (self == [FRHyperLabel class]) {
		FRHyperLabelLinkColorDefault = [UIColor colorWithRed:28/255.0 green:135/255.0 blue:199/255.0 alpha:1];
		FRHyperLabelLinkColorHighlight = [UIColor colorWithRed:242/255.0 green:183/255.0 blue:73/255.0 alpha:1];
	}
}

- (instancetype)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (self) {
		[self checkInitialization];
	}
	return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
	self = [super initWithCoder:coder];
	if (self) {
		[self checkInitialization];
	}
	return self;
}

- (void)checkInitialization {
	if (!self.handlerDictionary) {
		self.handlerDictionary = [NSMutableDictionary new];
	}
	
	if (!self.userInteractionEnabled) {
		self.userInteractionEnabled = YES;
	}
	
	if (!self.linkAttributeDefault) {
		self.linkAttributeDefault = @{NSForegroundColorAttributeName: FRHyperLabelLinkColorDefault,
									  NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
	}
	
	if (!self.linkAttributeHighlight) {
		self.linkAttributeHighlight = @{NSForegroundColorAttributeName: FRHyperLabelLinkColorHighlight,
										NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)};
	}
    
    if (!self.longPressGestureRecognizer) {
        self.longPressGestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressGestureRecognizer:)];
        self.longPressGestureRecognizer.minimumPressDuration = 0.0;
        [self addGestureRecognizer:self.longPressGestureRecognizer];
    }
}

#pragma mark - APIs

- (void)clearActionDictionary {
    [self.handlerDictionary removeAllObjects];
}

//designated setter
- (void)setLinkForRange:(NSRange)range withAttributes:(NSDictionary *)attributes andLinkHandler:(void (^)(FRHyperLabel *label, NSRange selectedRange))handler {
	NSMutableAttributedString *mutableAttributedString = [[NSMutableAttributedString alloc]initWithAttributedString:self.attributedText];
	
	if (attributes) {
		[mutableAttributedString addAttributes:attributes range:range];
	}
	
	if (handler) {
		[self.handlerDictionary setObject:handler forKey:[NSValue valueWithRange:range]];
	}
	
	self.attributedText = mutableAttributedString;
}

- (void)setLinkForRange:(NSRange)range withLinkHandler:(void(^)(FRHyperLabel *label, NSRange selectedRange))handler {
	[self setLinkForRange:range withAttributes:self.linkAttributeDefault andLinkHandler:handler];
}

- (void)setLinkForSubstring:(NSString *)substring withAttribute:(NSDictionary *)attribute andLinkHandler:(void(^)(FRHyperLabel *label, NSString *substring))handler {
	NSRange range = [self.attributedText.string rangeOfString:substring];
	if (range.length) {
		[self setLinkForRange:range withAttributes:attribute andLinkHandler:^(FRHyperLabel *label, NSRange range){
			handler(label, [label.attributedText.string substringWithRange:range]);
		}];
	}
}

- (void)setLinkForSubstring:(NSString *)substring withLinkHandler:(void(^)(FRHyperLabel *label, NSString *substring))handler {
	[self setLinkForSubstring:substring withAttribute:self.linkAttributeDefault andLinkHandler:handler];
}

- (void)setLinksForSubstrings:(NSArray *)linkStrings withLinkHandler:(void(^)(FRHyperLabel *label, NSString *substring))handler {
	for (NSString *linkString in linkStrings) {
		[self setLinkForSubstring:linkString withLinkHandler:handler];
	}
}

#pragma mark - Gesture Handler

-(void)handleLongPressGestureRecognizer:(UIGestureRecognizer*)recognizer{
    
    CGPoint touchPoint = [recognizer locationInView:self];
    NSValue *rangeValue = [self attributedTextRangeForPoint:touchPoint];
    
    switch (recognizer.state) {
        case UIGestureRecognizerStateBegan:
        {
            self.backupAttributedText = self.attributedText;
            if (rangeValue) {
                NSRange range = [rangeValue rangeValue];
                NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]initWithAttributedString:self.attributedText];
                [attributedString addAttributes:self.linkAttributeHighlight range:range];
                
                [UIView transitionWithView:self duration:highLightAnimationTime options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                    self.attributedText = attributedString;
                } completion:nil];
            }
        }
            break;
            
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            [UIView transitionWithView:self duration:highLightAnimationTime options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
                self.attributedText = self.backupAttributedText;
            } completion:nil];
            
            if (recognizer.state == UIGestureRecognizerStateEnded) {
                if (rangeValue) {
                    void(^handler)(FRHyperLabel *label, NSRange selectedRange) = self.handlerDictionary[rangeValue];
                    handler(self, [rangeValue rangeValue]);
                }
            }
            
        }
            break;
            
        default:
            break;
    }
    
}

/*
#pragma mark - Event Handler

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	self.backupAttributedText = self.attributedText;
	for (UITouch *touch in touches) {
		CGPoint touchPoint = [touch locationInView:self];
		NSValue *rangeValue = [self attributedTextRangeForPoint:touchPoint];
		if (rangeValue) {
			NSRange range = [rangeValue rangeValue];
			NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc]initWithAttributedString:self.attributedText];
			[attributedString addAttributes:self.linkAttributeHighlight range:range];
			
			[UIView transitionWithView:self duration:highLightAnimationTime options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
				self.attributedText = attributedString;
			} completion:nil];
			return;
		}
	}
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	[UIView transitionWithView:self duration:highLightAnimationTime options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		self.attributedText = self.backupAttributedText;
	} completion:nil];
	[super touchesCancelled:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	[UIView transitionWithView:self duration:highLightAnimationTime options:UIViewAnimationOptionTransitionCrossDissolve animations:^{
		self.attributedText = self.backupAttributedText;
	} completion:nil];
	
	for (UITouch *touch in touches) {
		NSValue *rangeValue = [self attributedTextRangeForPoint:[touch locationInView:self]];
		if (rangeValue) {
			void(^handler)(FRHyperLabel *label, NSRange selectedRange) = self.handlerDictionary[rangeValue];
			handler(self, [rangeValue rangeValue]);
			return;
		}
	}
	[super touchesEnded:touches withEvent:event];
}
*/

#pragma mark - Substring Locator

- (NSInteger) characterIndexForPoint:(CGPoint) point {

	// use Text Kit API in iOS 7:
	// Create instances of NSLayoutManager, NSTextContainer and NSTextStorage
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
	NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
	NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:self.attributedText];

	// Configure layoutManager and textStorage
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];

	// Configure textContainer
	textContainer.lineFragmentPadding = 0.0;
	textContainer.lineBreakMode = self.lineBreakMode;
	textContainer.maximumNumberOfLines = self.numberOfLines;
	textContainer.size = self.bounds.size;

	CGSize labelSize = self.bounds.size;
	CGRect textBoundingBox = [layoutManager usedRectForTextContainer:textContainer];
	CGPoint textContainerOffset = CGPointMake((labelSize.width - textBoundingBox.size.width) * 0.5 - textBoundingBox.origin.x,
											  (labelSize.height - textBoundingBox.size.height) * 0.5 - textBoundingBox.origin.y);
	CGPoint locationOfTouch = CGPointMake(point.x - textContainerOffset.x,
										  point.y - textContainerOffset.y);

	NSInteger indexOfCharacter = NSNotFound;
	if (CGRectContainsPoint(textBoundingBox, locationOfTouch)) {
		indexOfCharacter = [layoutManager characterIndexForPoint:locationOfTouch
												 inTextContainer:textContainer
						fractionOfDistanceBetweenInsertionPoints:nil];
	}
    
	return indexOfCharacter;
}

- (NSValue *)attributedTextRangeForPoint:(CGPoint)point {

	NSInteger indexOfCharacter = [self characterIndexForPoint:point];
	
	for (NSValue *rangeValue in self.handlerDictionary) {
		NSRange range = [rangeValue rangeValue];
		if (NSLocationInRange(indexOfCharacter, range)) {
			return rangeValue;
		}
	}

	return nil;
}


#pragma mark - HitTest

-(UIView*)hitTest:(CGPoint)point withEvent:(UIEvent *)event{
    UIView *hitView = [super hitTest:point withEvent:event];
    
    if (hitView == self) {
        
        NSValue *rangeValue = [self attributedTextRangeForPoint:point];
        if (!rangeValue) {
            //we have to avoid getting touch to pass the hit to parent view.
            hitView = nil;
        }
        
    }
    
    return hitView;
    
}

@end
