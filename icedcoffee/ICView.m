//  
//  Copyright (C) 2012 Tobias Lensing, http://icedcoffee-framework.org
//  
//  Permission is hereby granted, free of charge, to any person obtaining a copy of
//  this software and associated documentation files (the "Software"), to deal in
//  the Software without restriction, including without limitation the rights to
//  use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//  of the Software, and to permit persons to whom the Software is furnished to do
//  so, subject to the following conditions:
//  
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//  
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//  

#import "ICView.h"
#import "ICScene.h"
#import "ICUIScene.h"
#import "ICSprite.h"

@implementation ICView

@synthesize backing = _backing;
@synthesize clipsChildren = _clipsChildren;
@synthesize needsLayout = _needsLayout;
@synthesize autoresizingMask = _autoresizingMask;
@synthesize autoresizesSubviews = _autoresizesSubviews;

+ (id)view
{
    return [[[[self class] alloc] init] autorelease];
}

+ (id)viewWithSize:(CGSize)size
{
    return [[[[self class] alloc] initWithSize:size] autorelease];
}

- (id)init
{
    return [self initWithSize:CGSizeMake(0, 0)];
}

- (id)initWithSize:(CGSize)size
{
    if ((self = [super init])) {
        self.autoresizesSubviews = YES;
        self.size = kmVec3Make(size.width, size.height, 0);
        _clippingMask = [[ICSprite alloc] init];
        _clippingMask.size = self.size;
        _clippingMask.color = (icColor4B){255,255,255,255};
    }
    return self;
}

- (void)dealloc
{
    [_backing release];
    _backing = nil;
    
    [_clippingMask release];
    _clippingMask = nil;
    
    [super dealloc];
}

// FIXME: test this thoroughly
- (void)resizeWithOldSuperViewSize:(kmVec3)oldSuperviewSize
{
    if (oldSuperviewSize.x == 0 || oldSuperviewSize.y == 0)
        return;

    NSUInteger autoresizingMask = self.autoresizingMask;
    if (autoresizingMask) {
        kmVec3 newSuperviewSize = self.superview.size;
        kmVec3 leftTop = kmNullVec3, rightBottom = kmNullVec3, newSize = kmNullVec3;
        
        if (autoresizingMask & ICAutoResizingMaskLeftMarginFlexible) {
            leftTop.x = self.position.x / oldSuperviewSize.x * newSuperviewSize.x;
        } else {
            leftTop.x = self.position.x;
        }
        
        if (autoresizingMask & ICAutoResizingMaskTopMarginFlexible) {
            leftTop.y = self.position.y / oldSuperviewSize.y * newSuperviewSize.y;
        } else {
            leftTop.y = self.position.y;
        }

        if (autoresizingMask & ICAutoResizingMaskRightMarginFlexible) {
            rightBottom.x = (self.position.x + self.size.x) / oldSuperviewSize.x * newSuperviewSize.x;
        } else {
            rightBottom.x = newSuperviewSize.x - (oldSuperviewSize.x - (self.position.x + self.size.x));
        }

        if (autoresizingMask & ICAutoResizingMaskBottomMarginFlexible) {
            rightBottom.y = (self.position.y + self.size.y) / oldSuperviewSize.y * newSuperviewSize.y;
        } else {
            rightBottom.y = newSuperviewSize.y - (oldSuperviewSize.y - (self.position.y + self.size.y));
        }
        
        if (autoresizingMask & ICAutoResizingMaskWidthSizable) {
            newSize.x = rightBottom.x - leftTop.x;
        } else {
            newSize.x = self.size.x;
            if (autoresizingMask & ICAutoResizingMaskLeftMarginFlexible &&
                autoresizingMask & ICAutoResizingMaskRightMarginFlexible)
                leftTop.x = leftTop.x + (rightBottom.x - leftTop.x) / 2 - self.size.x / 2;
        }
        
        if (autoresizingMask & ICAutoResizingMaskHeightSizable) {
            newSize.y = rightBottom.y - leftTop.y;
        } else {
            newSize.y = self.size.y;
            if (autoresizingMask & ICAutoResizingMaskTopMarginFlexible &&
                autoresizingMask & ICAutoResizingMaskBottomMarginFlexible)
                leftTop.y = leftTop.y + (rightBottom.y - leftTop.y) / 2 - self.size.y / 2;
        }
        
        leftTop.x = roundf(leftTop.x);
        leftTop.y = roundf(leftTop.y);
        newSize.x = roundf(newSize.x);
        newSize.y = roundf(newSize.y);

        [self setPosition:leftTop];
        [self setSize:newSize];
    }
}

- (void)resizeSubviewsWithOldSuperviewSize:(kmVec3)oldSuperviewSize
{
    for (ICView *subview in [self subviews]) {
        [subview resizeWithOldSuperViewSize:oldSuperviewSize];
    }
}

- (void)setSize:(kmVec3)size
{
    if (size.x != self.size.x || size.y != self.size.y || size.z != self.size.z) {    
        kmVec3 oldSize = self.size;
        
        // Update the view's size
        [super setSize:size];
        [_backing setSize:size];
        
        if (_autoresizesSubviews) {
            [self resizeSubviewsWithOldSuperviewSize:oldSize];
        }
        
        // Mark the view for layouting
        [self setNeedsLayout:YES];
    }
}

- (void)setWantsRenderTextureBacking:(BOOL)wantsRenderTextureBacking
{
    if (wantsRenderTextureBacking) {
        [self setBacking:[ICRenderTexture renderTextureWithWidth:self.size.x
                                                          height:self.size.y
                                                     pixelFormat:kICPixelFormat_Default
                                               depthBufferFormat:kICDepthBufferFormat_Default
                                             stencilBufferFormat:kICStencilBufferFormat_Default]];
        _backing.frameUpdateMode = kICFrameUpdateMode_OnDemand;
    } else {
        [self setBacking:nil];
    }
}

// FIXME: doesn't support exchanging an existing backing yet
- (void)setBacking:(ICRenderTexture *)renderTexture
{
    if (_backing && renderTexture) {
        NSAssert(nil, @"Replacing an existing backing is currently not supported");
    }
    
    if (renderTexture && !renderTexture.subScene) {
        renderTexture.subScene = [ICScene scene];
        renderTexture.subScene.clearColor = (icColor4B){0,0,0,0};
    }
    
    if (_backing && !renderTexture) {
        // Move render texture children back to self
        for (ICNode *child in _backing.subScene.children) {
            [super addChild:child];
        }
        [_backing.subScene removeAllChildren];
    }
    
    if (!_backing && renderTexture) {
        for (ICNode *child in _children) {
            [renderTexture.subScene addChild:child];
        }
        [super removeAllChildren];
    }
    
    if (_backing) {
        [super removeChild:_backing];        
    }
    
    [_backing release];
    _backing = [renderTexture retain];
    
    if (_backing)
        [super addChild:_backing];
}

- (ICRenderTexture *)backing
{
    return _backing;
}

- (BOOL)clipsChildren
{
    if (_backing)
        return YES;
    
    return _clipsChildren;
}

- (void)setClipsChildren:(BOOL)clipsChildren
{
    _clipsChildren = clipsChildren;
}

- (void)setNeedsDisplay
{
    [_backing setNeedsDisplay];
    [super setNeedsDisplay];
}

- (void)drawWithVisitor:(ICNodeVisitor *)visitor
{
    if (_needsLayout) {
        [self layoutChildren];
    }
    
    if (_clipsChildren && !_backing) {
        glClearStencil(0);
        glClear(GL_STENCIL_BUFFER_BIT);
        
        glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE);
        glDepthMask(GL_FALSE);
        glEnable(GL_STENCIL_TEST);
        
        glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE);
        glStencilFunc(GL_ALWAYS, 1, 1);
        
        // Draw solid sprite in rectangular region of the view
        [_clippingMask drawWithVisitor:visitor];
        
        glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
        glDepthMask(GL_TRUE);
        glStencilFunc(GL_EQUAL, 1, 1);
    }
}

- (void)childrenDidDrawWithVisitor:(ICNodeVisitor *)visitor
{
    if (_clipsChildren && !_backing) {
        glDisable(GL_STENCIL_TEST);
    }    
}

- (ICView *)superview
{
    return (ICView *)[self firstAncestorOfType:[ICView class]];
}

- (NSArray *)subviews
{
    return [self childrenOfType:[ICView class]];
}

- (void)addChild:(ICNode *)child
{
    if (!_backing) {
        [super addChild:child];
    } else {
        [self.backing.subScene addChild:child];
    }
}

- (void)insertChild:(ICNode *)child atIndex:(uint)index
{
    if (!_backing) {
        [super insertChild:child atIndex:index];
    } else {
        [self.backing.subScene insertChild:child atIndex:index];
    }
}

- (void)removeChild:(ICNode *)child
{
    if (!_backing) {
        [super removeChild:child];
    } else {
        [self.backing.subScene removeChild:child];
    }
}

- (void)removeChildAtIndex:(uint)index
{
    if (!_backing) {
        [super removeChildAtIndex:index];
    } else {
        [self.backing.subScene removeChildAtIndex:index];
    }
}

- (void)removeAllChildren
{
    if (!_backing) {
        [super removeAllChildren];
    } else {
        [self.backing.subScene removeAllChildren];
    }
}

- (NSArray *)childrenOfType:(Class)classType
{
    NSArray *viewChildren = _backing ? _backing.subScene.children : [super children];
    NSMutableArray *children = [NSMutableArray array];
    for (ICNode *child in viewChildren) {
        if ([child isKindOfClass:classType]) {
            [children addObject:child];
        }
    }
    return children;
}

- (NSArray *)children
{
    if (!_backing) {
        return [super children];
    } else {
        return self.backing.subScene.children;
    }
}

- (void)setAutoResizingMask:(NSUInteger)autoresizingMask
{
    _autoresizingMask = autoresizingMask;
}

- (void)setNeedsLayout
{
    [self setNeedsLayout:YES];
}

- (void)setNeedsLayout:(BOOL)needsLayout
{
    _needsLayout = needsLayout;
    if (needsLayout) {
        [self setNeedsDisplay];
    }
}

- (void)layoutChildren
{
    // Override in subclass
}

@end
