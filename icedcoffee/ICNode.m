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

#import "ICNode.h"

#import "icGL.h"
#import "icTypes.h"
#import "icUtils.h"
#import "kazmath/kazmath.h"

#import "ICScene.h"
#import "ICCamera.h"
#import "ICShaderCache.h"
#import "ICShaderProgram.h"
#import "ICNodeVisitorPicking.h"
#import "ICHostViewController.h"
#import "ICRenderTexture.h"


@interface ICNode (Private)
- (void)setParent:(ICNode *)parent;
- (void)setChildren:(NSMutableArray *)children;
- (void)setNeedsDisplayForNode:(ICNode *)node;
@end


@implementation ICNode

#pragma mark - Lifecycle

- (id)init
{
    if ((self = [super init])) {
        self.children = nil; // lazy allocation
        self.computesTransform = YES;
        self.isVisible = YES;
        
        kmVec3 defaultPosition;
        kmVec3Fill(&defaultPosition, 0, 0, 0);
        [self setPosition:defaultPosition];
        
        // Anchor point is the same as default position initially
        [self setAnchorPoint:defaultPosition];
        // Content size is null also
        [self setSize:defaultPosition];
        
        kmVec3 defaultScale;
        kmVec3Fill(&defaultScale, 1, 1, 1);
        [self setScale:defaultScale];
        
        kmVec3 defaultAxis;
        kmVec3Fill(&defaultAxis, 0, 1, 0);
        [self setRotationAngle:0 axis:defaultAxis];
        
        kmMat4 identity;
        kmMat4Identity(&identity);
        self.transform = identity;
        
        // Auto center anchor point when content size is set
        self.autoCenterAnchorPoint = YES;
        
        // Enable user interaction by default
        self.userInteractionEnabled = YES;        
    }
    return self;
}

- (void)dealloc
{
    self.children = nil;
    [super dealloc];
}


#pragma mark - Composition

@synthesize parent = _parent;
@synthesize children = _children;

- (void)addChild:(ICNode *)child
{
    [child setParent:self];
    
    if (!_children) {
        _children = [[NSMutableArray alloc] initWithCapacity:1];
    }
    [(NSMutableArray *)_children addObject:child];
}

- (void)insertChild:(ICNode *)child atIndex:(uint)index
{
    if (!_children) {
        _children = [[NSMutableArray alloc] initWithCapacity:1];
    }
    [(NSMutableArray *)_children insertObject:child atIndex:index];
}

- (void)removeChild:(ICNode *)child
{
    if (_children) {
        [(NSMutableArray *)_children removeObject:child];
    }
}

- (void)removeChildAtIndex:(uint)index
{
    if (_children) {
        [(NSMutableArray *)_children removeObjectAtIndex:index];
    }
}

- (void)removeAllChildren
{
    if (_children) {
        [(NSMutableArray *)_children removeAllObjects];
    }
}

- (BOOL)hasChildren
{
    return _children.count > 0;
}

- (NSArray *)childrenOfType:(Class)classType
{
    NSMutableArray *children = [NSMutableArray array];
    for (ICNode *child in _children) {
        if ([child isKindOfClass:classType]) {
            [children addObject:child];
        }
    }
    return children;
}

- (NSArray *)childrenNotOfType:(Class)classType
{
    NSMutableArray *children = [NSMutableArray array];
    for (ICNode *child in _children) {
        if (![child isKindOfClass:classType]) {
            [children addObject:child];
        }
    }
    return children;
}

- (NSArray *)children
{
    return _children;
}

- (NSArray *)ancestorsOfType:(Class)classType stopAfterFirstAncestor:(BOOL)stopAfterFirstAncestor
{
    ICNode *node = self;
    NSMutableArray* ancestors = [[[NSMutableArray alloc] init] autorelease];
    while((node = [node parent])) {
        if(!classType || [node isKindOfClass:classType]) {
            [ancestors addObject:node];
            if(stopAfterFirstAncestor)
                break;
        }
    }
    return ancestors;        
}

- (NSArray *)ancestorsOfType:(Class)classType
{
    return [self ancestorsOfType:classType stopAfterFirstAncestor:NO];
}

- (ICNode *)firstAncestorOfType:(Class)classType
{
    NSArray *ancestors = [self ancestorsOfType:classType stopAfterFirstAncestor:YES];
    if ([ancestors count]) {
        return [ancestors objectAtIndex:0];
    }
    return nil;
}

- (NSArray *)ancestors
{
    return [self ancestorsOfType:nil];
}

- (void)accumulateDescendants:(NSMutableArray*)descendants
                     withNode:(ICNode *)node
                    notOfType:(Class)classType
{
    if([node hasChildren]) {
        int i;
        for(i=0; i<[[node children] count]; i++) {
            if(!classType || ![[[node children] objectAtIndex:i] isKindOfClass: classType])
                [descendants addObject: [[node children] objectAtIndex: i]];
            [self accumulateDescendants: descendants
                               withNode: [[node children] objectAtIndex: i]
                              notOfType: classType];
        }
    }
}

- (NSArray *)descendantsNotOfType:(Class)classType
{
    NSMutableArray* descendants = [[[NSMutableArray alloc] init] autorelease];
    [self accumulateDescendants:descendants withNode:self notOfType:classType];
    return descendants;
}

- (void)accumulateDescendants:(NSMutableArray*)descendants
                     withNode:(ICNode *)node
                       ofType:(Class)classType
{
    if([node hasChildren]) {
        int i;
        for(i=0; i<[[node children] count]; i++) {
            if(!classType || [[[node children] objectAtIndex:i] isKindOfClass:classType])
                [descendants addObject:[[node children] objectAtIndex:i]];
            [self accumulateDescendants:descendants
                               withNode:[[node children] objectAtIndex:i]
                                 ofType:classType];
        }
    }
}

- (NSArray *)descendantsOfType:(Class)classType
{
    NSMutableArray* descendants = [[[NSMutableArray alloc] init] autorelease];
    [self accumulateDescendants:descendants withNode:self ofType:classType];
    return descendants;
}

- (NSArray *)descendants
{
    return [self descendantsOfType:nil];
}

- (uint)level
{
    uint level = 0;
    ICNode *parent = _parent;
    do {
        if (parent)
            level++;
    } while ((parent = [parent parent]));
    
    return level;
}

- (ICNode *)root
{
    return [self.ancestors lastObject];
}

- (ICScene *)rootScene
{
    ICNode *potentialScene = [self root];
    if ([potentialScene isKindOfClass:[ICScene class]]) {
        return (ICScene *)potentialScene;
    }
    return nil;
}

- (ICScene *)parentScene
{
    NSArray *sceneAncestors = [self ancestorsOfType:[ICScene class]];
    if ([sceneAncestors count] > 0)
        return [sceneAncestors objectAtIndex:0];
    return nil;
}

- (ICHostViewController *)hostViewController
{
    return [[self rootScene] hostViewController];
}


#pragma mark - Transforms

@synthesize transform = _transform;

- (const kmMat4 *)transformPtr
{
    return &_transform;
}

- (kmMat4)nodeToParentTransform
{
    if (_computesTransform && _transformDirty) {
        [self computeTransform];
    }
    return _transform;
}

- (kmMat4)parentToNodeTransform
{
    if (_computesTransform && _transformDirty) {
        [self computeTransform];
    }
    kmMat4 inverseTransform;
    kmMat4Inverse(&inverseTransform, &_transform);
    return inverseTransform;
}

// This will stop at ICScene objects to ensure that a scene always represents
// word coordinates, even if scenes are nested
- (kmMat4)nodeToWorldTransform
{
    kmMat4 nodeToParentTransform = [self nodeToParentTransform];
    for (ICNode *parent = _parent; parent != nil; parent = parent.parent) {
        kmMat4 parentNodeToParentTransform = [parent nodeToParentTransform];
        kmMat4Multiply(&nodeToParentTransform, &nodeToParentTransform, &parentNodeToParentTransform);
        if ([parent isKindOfClass:[ICScene class]]) {
            break; // scene represents world coordinates
        }
    }
    return nodeToParentTransform;
}

- (kmMat4)worldToNodeTransform
{
    kmMat4 inverseTransform;
    kmMat4 nodeToWorldTransform = [self nodeToWorldTransform];
    kmMat4Inverse(&inverseTransform, &nodeToWorldTransform);
    return inverseTransform;
}

- (kmVec3)convertToNodeSpace:(kmVec3)worldVect
{
    kmVec3 result;
    kmMat4 transform = [self worldToNodeTransform];
    kmVec3Transform(&result, &worldVect, &transform);
    return result;
}

- (kmVec3)convertToWorldSpace:(kmVec3)nodeVect
{
    kmVec3 result;
    kmMat4 transform = [self nodeToWorldTransform];
    kmVec3Transform(&result, &nodeVect, &transform);
    return result;
}

- (void)setPosition:(kmVec3)position
{
    _position = position;
    _transformDirty = YES;
}

- (void)setPositionX:(float)positionX
{
    [self setPosition:kmVec3Make(positionX, _position.y, _position.z)];
}

- (void)setPositionY:(float)positionY
{
    [self setPosition:kmVec3Make(_position.x, positionY, _position.z)];
}

- (void)setPositionZ:(float)positionZ
{
    [self setPosition:kmVec3Make(_position.x, _position.y, positionZ)];
}

- (void)centerNode
{
    kmVec3 center = (kmVec3){floorf(self.parent.size.x/2 - self.size.x/2),
                             floorf(self.parent.size.y/2 - self.size.y/2),
                             0};
    [self setPosition:center];
}

- (void)centerNodeVertically
{
    kmVec3 center = (kmVec3){_position.x,
                             floorf(self.parent.size.y/2 - self.size.y/2),
                             0};
    [self setPosition:center];
}

- (void)centerNodeHorizontally
{
    kmVec3 center = (kmVec3){floorf(self.parent.size.x/2 - self.size.x/2),
                             _position.y,
                             0};
    [self setPosition:center];
}

- (kmVec3)position
{
    return _position;
}

- (void)setAnchorPoint:(kmVec3)anchorPoint
{
    _anchorPoint = anchorPoint;
    _transformDirty = YES;
}

- (void)centerAnchorPoint
{
    kmVec3 ap = (kmVec3){_size.x/2, _size.y/2, _size.z/2};
    [self setAnchorPoint:ap];
}

- (kmVec3)anchorPoint
{
    return _anchorPoint;
}

- (void)setSize:(kmVec3)size
{
    _size = size;
    if (_autoCenterAnchorPoint) {
        _anchorPoint = (kmVec3){ _size.x/2, _size.y/2, _size.z/2 };
    }
}

- (kmVec3)size
{
    return _size;
}

- (void)setWidth:(float)width
{
    [self setSize:kmVec3Make(width, _size.y, _size.z)];
}

- (void)setHeight:(float)height
{
    [self setSize:kmVec3Make(_size.x, height, _size.z)];
}

- (void)setDepth:(float)depth
{
    [self setSize:kmVec3Make(_size.x, _size.y, depth)];
}

- (void)setScale:(kmVec3)scale
{
    _scale = scale;
    _transformDirty = YES;
}

- (void)setScaleX:(float)scaleX
{
    _scale.x = scaleX;
    _transformDirty = YES;
}

- (void)setScaleY:(float)scaleY
{
    _scale.y = scaleY;
    _transformDirty = YES;    
}

- (void)setScaleXY:(float)scaleXY
{
    _scale.x = _scale.y = scaleXY;
    _transformDirty = YES;
}

- (void)setScaleZ:(float)scaleZ
{
    _scale.z = scaleZ;
    _transformDirty = YES;    
}

- (kmVec3)scale
{
    return _scale;
}

- (void)setRotationAngle:(float)angle axis:(kmVec3)axis
{
    _rotationAxis = axis;
    _rotationAngle = angle;
    _transformDirty = YES;
}

- (void)getRotationAngle:(float *)angle axis:(kmVec3 *)axis
{
    *angle = _rotationAngle;
    *axis = _rotationAxis;
}

// respected by visitor
@synthesize computesTransform = _computesTransform;

- (void)computeTransform
{
    if (_transformDirty) {
        kmMat4 translate, anchorPoint, reAnchorPoint, scale, rotate;
                
        kmMat4Translation(&translate, _position.x, _position.y, _position.z);
        kmMat4Translation(&anchorPoint, -_anchorPoint.x, -_anchorPoint.y, -_anchorPoint.z);
        kmMat4Translation(&reAnchorPoint, _anchorPoint.x, _anchorPoint.y, _anchorPoint.z);
        kmMat4Scaling(&scale, _scale.x, _scale.y, _scale.z);
        kmMat4RotationAxisAngle(&rotate, &_rotationAxis, _rotationAngle);
        
        kmMat4Identity(&_transform);
        kmMat4Multiply(&_transform, &_transform, &anchorPoint);
        kmMat4Multiply(&_transform, &scale, &_transform);
        kmMat4Multiply(&_transform, &rotate, &_transform);
        kmMat4Multiply(&_transform, &reAnchorPoint, &_transform);
        kmMat4Multiply(&_transform, &translate, &_transform);
        
        _transformDirty = NO;
    }
}

@synthesize autoCenterAnchorPoint = _autoCenterAnchorPoint;


#pragma mark - Order

- (NSUInteger)order
{
    return [self.parent.children indexOfObject:self];
}

- (void)orderFront
{
    [(NSMutableArray *)self.parent.children exchangeObjectAtIndex:[self order]
                                                withObjectAtIndex:[self.parent.children count]-1];
}

- (void)orderForward
{
    NSUInteger order = [self order];
    if ([self.parent.children count] <= order+1)
        return;
    
    [(NSMutableArray *)self.parent.children exchangeObjectAtIndex:order
                                                withObjectAtIndex:order+1];
}

- (void)orderBackward
{
    NSUInteger order = [self order];
    if (order == 0)
        return;
    
    [(NSMutableArray *)self.parent.children exchangeObjectAtIndex:order
                                                withObjectAtIndex:order-1];
}

- (void)orderBack
{
    [(NSMutableArray *)self.parent.children exchangeObjectAtIndex:[self order]
                                                withObjectAtIndex:0];
}


#pragma mark - Bounds

- (kmAABB)aabb
{
    kmVec3 vertices[2];
    vertices[0] = _position;
    kmVec3Add(&vertices[1], &_position, &_size);
    return icComputeAABBFromVertices(vertices, 2);
}

- (CGRect)frameRect
{
    kmVec3 world[8], view[8];
    
    world[0] = _position;
    world[1] = (kmVec3){_position.x + _size.x, _position.y, _position.z};
    world[2] = (kmVec3){_position.x + _size.x, _position.y + _size.y, _position.z};
    world[3] = (kmVec3){_position.x + _size.x, _position.y + _size.y, _position.z + _size.z};
    world[4] = (kmVec3){_position.x, _position.y + _size.y, _position.z};
    world[5] = (kmVec3){_position.x, _position.y + _size.y, _position.z + _size.z};
    world[6] = (kmVec3){_position.x, _position.y, _position.z + _size.z};
    world[7] = (kmVec3){_position.x + _size.x, _position.y, _position.z + _size.z};

    ICScene *scene = [self parentScene];
    if (!scene && [self isKindOfClass:[ICScene class]] && !_parent) {
        scene = (ICScene *)self;
    } else if (!scene) {
        NSAssert(nil, @"Could not get scene for frame rect calculation");
    }
    
    for (int i=0; i<8; i++) {
        kmVec3 w = world[i];
        if (_parent)
            w = [self convertToWorldSpace:world[i]];
        [scene.camera projectWorld:w toView:&view[i]];
        view[i].x = (int)view[i].x;
        view[i].y = (int)view[i].y;
        view[i].x /= IC_CONTENT_SCALE_FACTOR();
        view[i].y /= IC_CONTENT_SCALE_FACTOR();
    }
    
    kmAABB aabb = icComputeAABBFromVertices(view, 8);
    return CGRectMake(aabb.min.x, aabb.min.y, aabb.max.x - aabb.min.x,  aabb.max.y - aabb.min.y);
}


#pragma mark - Drawing/Picking

@synthesize shaderProgram = _shaderProgram;
@synthesize isVisible = _isVisible;

- (void)applyStandardDrawSetupWithVisitor:(ICNodeVisitor *)visitor
{
    if (visitor.visitorType == kICDrawingNodeVisitor) {
        [self.shaderProgram use];
        icGLUniformModelViewProjectionMatrix(self.shaderProgram);
    } else if (visitor.visitorType == kICPickingNodeVisitor) {
        ICShaderProgram *p = [[ICShaderCache currentShaderCache] shaderProgramForKey:kICShader_Picking];
        [p use];
        icGLUniformModelViewProjectionMatrix(p);
        GLuint pickColorLocation = glGetUniformLocation(p.program, "u_pickColor");
        icColor4B pickColor = [(ICNodeVisitorPicking *)visitor pickColor];
        glUniform4f(pickColorLocation,
                    (float)pickColor.r/IC_PICK_COLOR_RESOLUTION,
                    (float)pickColor.g/IC_PICK_COLOR_RESOLUTION,
                    (float)pickColor.b/IC_PICK_COLOR_RESOLUTION,
                    (float)pickColor.a/IC_PICK_COLOR_RESOLUTION);
    }    
}

- (void)drawWithVisitor:(ICNodeVisitor *)visitor
{
    // Implement custom drawing code in subclass
}

- (void)childrenDidDrawWithVisitor:(ICNodeVisitor *)visitor
{
    // Implement custom code to reset states after drawing children in subclass
}

// Private
- (void)setNeedsDisplayForNode:(ICNode *)node
{
    [[self parent] setNeedsDisplayForNode:node];
}

- (void)setNeedsDisplay
{
    [self setNeedsDisplayForNode:self];
}


#pragma mark - User Interaction Support

@synthesize userInteractionEnabled = _userInteractionEnabled;


#pragma mark - Debugging

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ = %08X | name = %@ | parent = %@>",
            [self class], self, self.name, [_parent class]];
}

// private
- (void)debugLogBranchWithRoot:(ICNode *)root node:(ICNode *)node
{
    uint level = [node level] - [root level];
    NSMutableString *indent = [NSMutableString stringWithCapacity:level];
    for (uint i=0; i<level; i++) {
        [indent appendString:@" "];
    }
    NSLog(@"%@ - %@", indent, [node description]);
    for (ICNode *child in _children) {
        [child debugLogBranchWithRoot:root node:child];
    }
}

- (void)debugLogBranch
{
    [self debugLogBranchWithRoot:self node:self];
}


#pragma mark - Private

- (void)setParent:(ICNode *)parent
{
    _parent = parent;
    self.nextResponder = parent;
}

- (void)setChildren:(NSMutableArray *)children
{
    [_children release];
    _children = [children retain];
}

@end