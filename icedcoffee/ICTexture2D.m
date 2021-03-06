/*

===== IMPORTANT =====

This is sample code demonstrating API, technology or techniques in development.
Although this sample code has been reviewed for technical accuracy, it is not
final. Apple is supplying this information to help you plan for the adoption of
the technologies and programming interfaces described herein. This information
is subject to change, and software implemented based on this sample code should
be tested with final operating system software and final documentation. Newer
versions of this sample code may be provided with future seeds of the API or
technology. For information about updates to this and other developer
documentation, view the New & Updated sidebars in subsequent documentationd
seeds.

=====================

File: Texture2D.m
Abstract: Creates OpenGL 2D textures from images or text.

Version: 1.6

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple Inc.
("Apple") in consideration of your agreement to the following terms, and your
use, installation, modification or redistribution of this Apple software
constitutes aICeptance of these terms.  If you do not agree with these terms,
please do not use, install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and subject
to these terms, Apple grants you a personal, non-exclusive license, under
Apple's copyrights in this original Apple software (the "Apple Software"), to
use, reproduce, modify and redistribute the Apple Software, with or without
modifications, in source and/or binary forms; provided that if you redistribute
the Apple Software in its entirety and without modifications, you must retain
this notice and the following text and disclaimers in all such redistributions
of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may be used
to endorse or promote products derived from the Apple Software without specific
prior written permission from Apple.  Except as expressly stated in this notice,
no other rights or licenses, express or implied, are granted by Apple herein,
including but not limited to any patent rights that may be infringed by your
derivative works or by other works in which the Apple Software may be
incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE MAKES NO
WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION THE IMPLIED
WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND OPERATION ALONE OR IN
COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION, MODIFICATION AND/OR
DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED AND WHETHER UNDER THEORY OF
CONTRACT, TORT (INCLUDING NEGLIGENCE), STRICT LIABILITY OR OTHERWISE, EVEN IF
APPLE HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2008 Apple Inc. All Rights Reserved.

*/

/*
 * Support for RGBA_4_4_4_4 and RGBA_5_5_5_1 was copied from:
 * https://devforums.apple.com/message/37855#37855 by a1studmuffin
 */


#import <Availability.h>

#import "Platforms/icGL.h"
#import "Platforms/icNS.h"


#import "ICTexture2D.h"
#import "icMacros.h"
#import "icUtils.h"

#import "icConfig.h"
#import "ICConfiguration.h"
//#import "Support/ICUtils.h"


// FIXME: Removed FontLabel support as in cocos2d-2, but didn't add alternative yet
// FIXME: ICLabel support for 32-bit textures

// For Labels use 32-bit textures on iPhone 3GS / iPads since A8 textures are very slow
#if defined(__ARM_NEON__) && IC_USE_RGBA32_LABELS_ON_NEON_ARCH
#define USE_TEXT_WITH_A8_TEXTURES 0

#else
#define USE_TEXT_WITH_A8_TEXTURES 1
#endif


//CLASS IMPLEMENTATIONS:


// If the image has alpha, you can create RGBA8 (32-bit) or RGBA4 (16-bit) or RGB5A1 (16-bit)
// Default is: RGBA8888 (32-bit textures)
static ICPixelFormat defaultAlphaPixelFormat_ = kICPixelFormat_Default;

#pragma mark -
#pragma mark ICTexture2D - Main

@implementation ICTexture2D

@synthesize sizeInPixels = size_, pixelFormat = format_, pixelsWide = width_, pixelsHigh = height_, name = name_, maxS = maxS_, maxT = maxT_;
@synthesize hasPremultipliedAlpha = hasPremultipliedAlpha_;

- (id) initWithData:(const void*)data pixelFormat:(ICPixelFormat)pixelFormat pixelsWide:(NSUInteger)width pixelsHigh:(NSUInteger)height size:(CGSize)size
{
	if((self = [super init])) {        
		glGenTextures(1, &name_);
		glBindTexture(GL_TEXTURE_2D, name_);
        
		[self setAntiAliasTexParameters];
		
		// Specify OpenGL texture image
		
		switch(pixelFormat)
		{
			case kICPixelFormat_RGBA8888:
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data);
				break;
			case kICPixelFormat_RGBA4444:
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_SHORT_4_4_4_4, data);
				break;
			case kICPixelFormat_RGB5A1:
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, (GLsizei)width, (GLsizei)height, 0, GL_RGBA, GL_UNSIGNED_SHORT_5_5_5_1, data);
				break;
			case kICPixelFormat_RGB565:
				glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, (GLsizei)width, (GLsizei)height, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, data);
				break;
			case kICPixelFormat_A8:
				glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, (GLsizei)width, (GLsizei)height, 0, GL_ALPHA, GL_UNSIGNED_BYTE, data);
				break;
			default:
				[NSException raise:NSInternalInconsistencyException format:@""];
				
		}
        
        CHECK_GL_ERROR_DEBUG();

		size_ = size;
		width_ = width;
		height_ = height;
		format_ = pixelFormat;
		maxS_ = size.width / (float)width;
		maxT_ = size.height / (float)height;

		hasPremultipliedAlpha_ = NO;
	}					
	return self;
}

- (void) releaseData:(void*)data
{
	//Free data
	free(data);
}

- (void*) keepData:(void*)data length:(NSUInteger)length
{
	//The texture data mustn't be saved becuase it isn't a mutable texture.
	return data;
}

- (void)deleteGlTexture: (id)object
{
    glDeleteTextures(1, &name_);    
}

- (void) dealloc
{
	ICLOG_DEALLOC(@"IcedCoffee: deallocing %@", self);
	if(name_) {
        // FIXME: Texture can only be deleted on main thread currently
        [self performSelectorOnMainThread: @selector(deleteGlTexture:) withObject: nil waitUntilDone: YES];
    }
	
	[super dealloc];
}

- (NSString *) description
{
	return [NSString stringWithFormat:@"<%@ = %08X | Name = %i | Dimensions = %ix%i | Coordinates = (%.2f, %.2f)>", [self class], self, name_, width_, height_, maxS_, maxT_];
}

-(CGSize) size
{
	CGSize ret;
	ret.width = size_.width; // / IC_CONTENT_SCALE_FACTOR();
	ret.height = size_.height; // / IC_CONTENT_SCALE_FACTOR();
	
	return ret;
}
@end

#pragma mark -
#pragma mark ICTexture2D - Image

@implementation ICTexture2D (Image)
#ifdef __IC_PLATFORM_IOS
- (id) initWithCGImage:(CGImageRef)cgImage resolutionType:(icResolutionType)resolution
#elif defined(__IC_PLATFORM_MAC)
- (id) initWithCGImage:(CGImageRef)cgImage
#endif
{
	NSUInteger				POTWide, POTHigh;
	CGContextRef			context = nil;
	void*					data = nil;;
	CGColorSpaceRef			colorSpace;
	void*					tempData;
	unsigned int*			inPixel32;
	unsigned short*			outPixel16;
	BOOL					hasAlpha;
	CGImageAlphaInfo		info;
	CGSize					imageSize;
	ICPixelFormat	pixelFormat;
    
	if(cgImage == NULL) {
		ICLOG(@"IcedCoffee: ICTexture2D. Can't create Texture. cgImage is nil");
		[self release];
		return nil;
	}
    
	ICConfiguration *conf = [ICConfiguration sharedConfiguration];
    
	if( [conf supportsNPOT] ) {
		POTWide = CGImageGetWidth(cgImage);
		POTHigh = CGImageGetHeight(cgImage);
        
	}
	else
	{
		POTWide = icNextPOT(CGImageGetWidth(cgImage));
		POTHigh = icNextPOT(CGImageGetHeight(cgImage));
	}
    
	NSUInteger maxTextureSize = [conf maxTextureSize];
	if( POTHigh > maxTextureSize || POTWide > maxTextureSize ) {
		ICLOG(@"IcedCoffee: WARNING: Image (%lu x %lu) is bigger than the supported %ld x %ld",
			  (long)POTWide, (long)POTHigh,
			  (long)maxTextureSize, (long)maxTextureSize);
		[self release];
		return nil;
	}
    
	info = CGImageGetAlphaInfo(cgImage);
	hasAlpha = ((info == kCGImageAlphaPremultipliedLast) || (info == kCGImageAlphaPremultipliedFirst) || (info == kCGImageAlphaLast) || (info == kCGImageAlphaFirst) ? YES : NO);
    
	size_t bpp = CGImageGetBitsPerComponent(cgImage);
	colorSpace = CGImageGetColorSpace(cgImage);
    
	if(colorSpace) {
		if(hasAlpha || bpp >= 8)
			pixelFormat = defaultAlphaPixelFormat_;
		else {
			ICLOG(@"IcedCoffee: ICTexture2D: Using RGB565 texture since image has no alpha");
			pixelFormat = kICPixelFormat_RGB565;
		}
	} else {
		// NOTE: No colorspace means a mask image
		ICLOG(@"IcedCoffee: ICTexture2D: Using A8 texture since image is a mask");
		pixelFormat = kICPixelFormat_A8;
	}
    
	imageSize = CGSizeMake(CGImageGetWidth(cgImage), CGImageGetHeight(cgImage));
    
	// Create the bitmap graphics context
    
	switch(pixelFormat) {
		case kICPixelFormat_RGBA8888:
		case kICPixelFormat_RGBA4444:
		case kICPixelFormat_RGB5A1:
			colorSpace = CGColorSpaceCreateDeviceRGB();
			data = malloc(POTHigh * POTWide * 4);
			info = hasAlpha ? kCGImageAlphaPremultipliedLast : kCGImageAlphaNoneSkipLast;
            //			info = kCGImageAlphaPremultipliedLast;  // issue #886. This patch breaks BMP images.
			context = CGBitmapContextCreate(data, POTWide, POTHigh, 8, 4 * POTWide, colorSpace, info | kCGBitmapByteOrder32Big);
			CGColorSpaceRelease(colorSpace);
			break;
            
		case kICPixelFormat_RGB565:
			colorSpace = CGColorSpaceCreateDeviceRGB();
			data = malloc(POTHigh * POTWide * 4);
			info = kCGImageAlphaNoneSkipLast;
			context = CGBitmapContextCreate(data, POTWide, POTHigh, 8, 4 * POTWide, colorSpace, info | kCGBitmapByteOrder32Big);
			CGColorSpaceRelease(colorSpace);
			break;
		case kICPixelFormat_A8:
			data = malloc(POTHigh * POTWide);
			info = kCGImageAlphaOnly;
			context = CGBitmapContextCreate(data, POTWide, POTHigh, 8, POTWide, NULL, info);
			break;
		default:
			[NSException raise:NSInternalInconsistencyException format:@"Invalid pixel format"];
	}
    
    
	CGContextClearRect(context, CGRectMake(0, 0, POTWide, POTHigh));
	CGContextTranslateCTM(context, 0, POTHigh - imageSize.height);
	CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(cgImage), CGImageGetHeight(cgImage)), cgImage);
    
	// Repack the pixel data into the right format
    
	if(pixelFormat == kICPixelFormat_RGB565) {
		//Convert "RRRRRRRRRGGGGGGGGBBBBBBBBAAAAAAAA" to "RRRRRGGGGGGBBBBB"
		tempData = malloc(POTHigh * POTWide * 2);
		inPixel32 = (unsigned int*)data;
		outPixel16 = (unsigned short*)tempData;
		for(unsigned int i = 0; i < POTWide * POTHigh; ++i, ++inPixel32)
			*outPixel16++ = ((((*inPixel32 >> 0) & 0xFF) >> 3) << 11) | ((((*inPixel32 >> 8) & 0xFF) >> 2) << 5) | ((((*inPixel32 >> 16) & 0xFF) >> 3) << 0);
		free(data);
		data = tempData;
        
	}
	else if (pixelFormat == kICPixelFormat_RGBA4444) {
		//Convert "RRRRRRRRRGGGGGGGGBBBBBBBBAAAAAAAA" to "RRRRGGGGBBBBAAAA"
		tempData = malloc(POTHigh * POTWide * 2);
		inPixel32 = (unsigned int*)data;
		outPixel16 = (unsigned short*)tempData;
		for(unsigned int i = 0; i < POTWide * POTHigh; ++i, ++inPixel32)
			*outPixel16++ =
			((((*inPixel32 >> 0) & 0xFF) >> 4) << 12) | // R
			((((*inPixel32 >> 8) & 0xFF) >> 4) << 8) | // G
			((((*inPixel32 >> 16) & 0xFF) >> 4) << 4) | // B
			((((*inPixel32 >> 24) & 0xFF) >> 4) << 0); // A
        
        
		free(data);
		data = tempData;
        
	}
	else if (pixelFormat == kICPixelFormat_RGB5A1) {
		//Convert "RRRRRRRRRGGGGGGGGBBBBBBBBAAAAAAAA" to "RRRRRGGGGGBBBBBA"
		tempData = malloc(POTHigh * POTWide * 2);
		inPixel32 = (unsigned int*)data;
		outPixel16 = (unsigned short*)tempData;
		for(unsigned int i = 0; i < POTWide * POTHigh; ++i, ++inPixel32)
			*outPixel16++ =
			((((*inPixel32 >> 0) & 0xFF) >> 3) << 11) | // R
			((((*inPixel32 >> 8) & 0xFF) >> 3) << 6) | // G
			((((*inPixel32 >> 16) & 0xFF) >> 3) << 1) | // B
			((((*inPixel32 >> 24) & 0xFF) >> 7) << 0); // A
        
        
		free(data);
		data = tempData;
	}
	self = [self initWithData:data pixelFormat:pixelFormat pixelsWide:POTWide pixelsHigh:POTHigh size:imageSize];
    
	// should be after calling super init
	hasPremultipliedAlpha_ = (info == kCGImageAlphaPremultipliedLast || info == kCGImageAlphaPremultipliedFirst);
    
	CGContextRelease(context);
	[self releaseData:data];
    
#ifdef __CC_PLATFORM_IOS
	resolutionType_ = resolution;
#endif
    
	return self;
}
@end


// FIXME: good start, but lots of stuff missing

#pragma mark -
#pragma mark ICTexture2D - Text

@implementation ICTexture2D (Text)

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED

- (id) initWithString:(NSString*)string dimensions:(CGSize)dimensions alignment:(ICTextAlignment)alignment font:(id)uifont
{
	NSAssert( uifont, @"Invalid font");
	
	NSUInteger POTWide = dimensions.width; //icNextPOT(dimensions.width);
	NSUInteger POTHigh = dimensions.height; //icNextPOT(dimensions.height);
	unsigned char*			data;
	
	CGContextRef			context;
	CGColorSpaceRef			colorSpace;
	
#if USE_TEXT_WITH_A8_TEXTURES
	colorSpace = CGColorSpaceCreateDeviceGray();
	data = calloc(POTHigh, POTWide);
	context = CGBitmapContextCreate(data, POTWide, POTHigh, 8, POTWide, colorSpace, kCGImageAlphaNone);
#else
	colorSpace = CGColorSpaceCreateDeviceRGB();
	data = calloc(POTHigh, POTWide * 4);
	context = CGBitmapContextCreate(data, POTWide, POTHigh, 8, 4 * POTWide, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);				
#endif

	CGColorSpaceRelease(colorSpace);
	
	if( ! context ) {
		free(data);
		[self release];
		return nil;
	}
	
	CGContextSetGrayFillColor(context, 1.0f, 1.0f);
	CGContextTranslateCTM(context, 0.0f, POTHigh);
	CGContextScaleCTM(context, 1.0f, -1.0f); //NOTE: NSString draws in UIKit referential i.e. renders upside-down compared to CGBitmapContext referential
	
	UIGraphicsPushContext(context);

	// normal fonts
	if( [uifont isKindOfClass:[UIFont class] ] )
		[string drawInRect:CGRectMake(0, 0, dimensions.width, dimensions.height) withFont:uifont lineBreakMode:UILineBreakModeWordWrap alignment:alignment];
		
	UIGraphicsPopContext();
	
#if USE_TEXT_WITH_A8_TEXTURES
	self = [self initWithData:data pixelFormat:kICPixelFormat_A8 pixelsWide:POTWide pixelsHigh:POTHigh size:dimensions];
#else
	self = [self initWithData:data pixelFormat:kICPixelFormat_RGBA8888 pixelsWide:POTWide pixelsHigh:POTHigh size:dimensions];
#endif
	CGContextRelease(context);
	[self releaseData:data];
			
	return self;
}
				 
#elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED)

- (id) initWithString:(NSString*)string
           dimensions:(CGSize)dimensions
            alignment:(ICTextAlignment)alignment
     attributedString:(NSAttributedString*)stringWithAttributes
{				
	NSAssert( stringWithAttributes, @"Invalid stringWithAttributes");

	NSUInteger POTWide = dimensions.width; //icNextPOT(dimensions.width);
	NSUInteger POTHigh = dimensions.height; //icNextPOT(dimensions.height);
	unsigned char*			data;
	
	NSSize realDimensions = [stringWithAttributes size];

	//Alignment
	float xPadding = 0;
	
	// Mac crashes if the width or height is 0
	if( realDimensions.width > 0 && realDimensions.height > 0 ) {
		switch (alignment) {
			case ICTextAlignmentLeft: xPadding = 0; break;
			case ICTextAlignmentCenter: xPadding = (dimensions.width-realDimensions.width)/2.0f; break;
			case ICTextAlignmentRight: xPadding = dimensions.width-realDimensions.width; break;
			default: break;
		}
		
		//Disable antialias
/*		[[NSGraphicsContext currentContext] setShouldAntialias:NO];	*/
		
		NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(POTWide, POTHigh)];
		[image lockFocus];	
		
		[stringWithAttributes drawAtPoint:NSMakePoint(xPadding, POTHigh-dimensions.height)]; // draw at offset position	
		
		NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect (0.0f, 0.0f, POTWide, POTHigh)];
		[image unlockFocus];
		
		data = (unsigned char*) [bitmap bitmapData];  //Use the same buffer to improve the performance.
		
        NSInteger bytesPerRow = [bitmap bytesPerRow];
        int c = 0;
		for(int i = 0; i<POTHigh; i++) //Convert RGBA8888 to A8
            for(int j=0; j<POTWide; j++)
                data[c++] = data[i*bytesPerRow+j*4+3];
		
		//data = (unsigned char*)[self keepData:data length:textureSize];
		self = [self initWithData:data pixelFormat:kICPixelFormat_A8 pixelsWide:POTWide pixelsHigh:POTHigh size:dimensions];
		
		[bitmap release];
		[image release]; 
			
	} else {
		[self release];
		return nil;
	}
	
	return self;
}
#endif // __MAC_OS_X_VERSION_MAX_ALLOWED

- (id) initWithString:(NSString*)string fontName:(NSString*)name fontSize:(CGFloat)size
{
    CGSize dim;

#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
	id font;
	font = [UIFont fontWithName:name size:size];
	if( font )
		dim = [string sizeWithFont:font];
	
	if( ! font ) {
		NSLog(@"IcedCoffee: Unable to load font %@", name);
		[self release];
		return nil;
	}
	
	return [self initWithString:string dimensions:dim alignment:ICTextAlignmentCenter font:font];
	
#elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
	{

		NSAttributedString *stringWithAttributes =
		[[[NSAttributedString alloc] initWithString:string
										 attributes:[NSDictionary dictionaryWithObject:[[NSFontManager sharedFontManager]
																						fontWithFamily:name
																						traits:NSUnboldFontMask | NSUnitalicFontMask
																						weight:0
																						size:size]
																				forKey:NSFontAttributeName]
		  ]
		 autorelease];
	
        // Require that GL_UNPACK_ALIGNMENT is set to 1 (see http://www.opengl.org/wiki/Common_Mistakes)
		dim = NSSizeToCGSize( [stringWithAttributes size] );
        dim.width = ceilf(dim.width);
        dim.height = ceilf(dim.height);
        
        // In case standard alignment is set (4), the following would correct the width of
        // the alpha texture
        //int remainder = (int)dim.width % 4 ? 4 - (int)dim.width % 4 : 0;
        //dim.width = remainder ? dim.width + remainder : dim.width;
				
		return [self initWithString:string dimensions:dim alignment:ICTextAlignmentCenter attributedString:stringWithAttributes];
	}
#endif // __MAC_OS_X_VERSION_MAX_ALLOWED
    
}

- (id)initWithString:(NSString*)string
          dimensions:(CGSize)dimensions
           alignment:(ICTextAlignment)alignment
            fontName:(NSString*)name
            fontSize:(CGFloat)size
{
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
	id						uifont = nil;

	uifont = [UIFont fontWithName:name size:size];

	if( ! uifont ) {
		NSLog(@"IcedCoffee: Texture2d: Invalid Font: %@. Verify the .ttf name", name);
		[self release];
		return nil;
	}
	
	return [self initWithString:string dimensions:dimensions alignment:alignment font:uifont];
	
#elif defined(__MAC_OS_X_VERSION_MAX_ALLOWED)
	
	//String with attributes
	NSAttributedString *stringWithAttributes =
	[[[NSAttributedString alloc] initWithString:string
									 attributes:[NSDictionary dictionaryWithObject:[[NSFontManager sharedFontManager]
																					fontWithFamily:name
																					traits:NSUnboldFontMask | NSUnitalicFontMask
																					weight:0
																					size:size]
																			forKey:NSFontAttributeName]
	  ]
	 autorelease];
	
	return [self initWithString:string dimensions:dimensions alignment:alignment attributedString:stringWithAttributes];
		
#endif // Mac
}
@end


#pragma mark -
#pragma mark ICTexture2D - GLFilter

//
// Use to apply MIN/MAG filter
//
@implementation ICTexture2D (GLFilter)

-(void) generateMipmap
{
	NSAssert( width_ == icNextPOT((unsigned int)width_) && height_ == icNextPOT((unsigned int)height_), @"Mipmap texture only works in POT textures");
	glBindTexture( GL_TEXTURE_2D, name_ );
	glGenerateMipmap(GL_TEXTURE_2D);
}

-(void) setTexParameters: (ICTexParams*) texParams
{
	NSAssert( (width_ == icNextPOT((unsigned int)width_) && height_ == icNextPOT((unsigned int)height_)) ||
			 (texParams->wrapS == GL_CLAMP_TO_EDGE && texParams->wrapT == GL_CLAMP_TO_EDGE),
			 @"GL_CLAMP_TO_EDGE should be used in NPOT textures");
	glBindTexture( GL_TEXTURE_2D, self.name );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, texParams->minFilter );
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, texParams->magFilter );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, texParams->wrapS );
	glTexParameteri( GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, texParams->wrapT );
}

-(void) setAliasTexParameters
{
	ICTexParams texParams = { GL_NEAREST, GL_NEAREST, GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE };
	[self setTexParameters: &texParams];
}

-(void) setAntiAliasTexParameters
{
	ICTexParams texParams = { GL_LINEAR, GL_LINEAR, GL_CLAMP_TO_EDGE, GL_CLAMP_TO_EDGE };
	[self setTexParameters: &texParams];
}
@end


#pragma mark -
#pragma mark ICTexture2D - Pixel Format

//
// Texture options for images that contains alpha
//
@implementation ICTexture2D (PixelFormat)
+(void) setDefaultAlphaPixelFormat:(ICPixelFormat)format
{
	defaultAlphaPixelFormat_ = format;
}

+(ICPixelFormat) defaultAlphaPixelFormat
{
	return defaultAlphaPixelFormat_;
}
@end

