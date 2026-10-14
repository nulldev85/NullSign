//
//  iconPoc.m
//  nmsl
//
//  Created by s s on 2026/1/15.
//

#include "iconPoc.h"
#include <dlfcn.h>

#define PrivClass(name) ((Class)objc_lookUpClass(#name))

@interface IFColor : NSObject
- (instancetype)initWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
- (instancetype)initWithCGColor:(CGColorRef)color;
@end

@interface IFBundle : NSObject
- (instancetype)initWithURL:(NSURL*)url;
- (NSDictionary*)iconDictionary;
@end

@interface IFImage : NSObject
- (CGImageRef)CGImage;
@end

@interface ISImageDescriptor : NSObject
@property (nonatomic, assign, readwrite) NSInteger appearance;
@property (nonatomic, assign, readwrite) NSInteger appearanceVariant NS_AVAILABLE_IOS(18_0);
@property (nonatomic, assign, readwrite) NSUInteger specialIconOptions NS_AVAILABLE_IOS(18_0);
@property (nonatomic, assign, readwrite) BOOL drawBorder;
@property (atomic, assign, readwrite) BOOL ignoreCache;
@property (nonatomic, assign) CGFloat scale;
@property (nonatomic, strong, readwrite) IFColor *tintColor;
@property (nonatomic, assign, readwrite) NSUInteger variantOptions;
+ (instancetype)imageDescriptorNamed:(NSString *)name;
@end

@interface ISIcon : NSObject
- (CGImageRef)CGImageForImageDescriptor:(ISImageDescriptor *)imageDescriptor;
@end

@interface ISConcreteIcon : ISIcon
@end

@interface ISBundleIcon : ISIcon

@property (readonly) NSString *tag;
@property (readonly) NSString *tagClass;
@property (readonly) NSString *type;
@property (readonly) NSURL *url;

+ (bool)supportsSecureCoding;

- (double)_aspectRatio;
- (id)_makeAppResourceProvider;
- (id)_makeDocumentResourceProvider;
- (id)description;
- (void)encodeWithCoder:(id)arg1;
- (id)initWithBundleURL:(id)arg1;
- (id)initWithBundleURL:(id)arg1 fileExtension:(id)arg2;
- (id)initWithBundleURL:(id)arg1 type:(id)arg2;
- (id)initWithBundleURL:(id)arg1 type:(id)arg2 tag:(id)arg3 tagClass:(id)arg4;
- (id)initWithCoder:(id)arg1;
- (id)makeResourceProvider;
- (id)tag;
- (id)tagClass;
- (id)type;
- (id)url;

@end

@interface ISGenerationRequest : NSObject
@property (retain) ISConcreteIcon *icon;
@property (retain) ISImageDescriptor *imageDescriptor;
@property unsigned long long lsDatabaseSequenceNumber;
@property (retain) NSUUID *lsDatabaseUUID;

+ (bool)supportsSecureCoding;

- (id)_decorationRecipeKeyFromType:(id)arg1;
- (void)encodeWithCoder:(id)arg1;
- (id)generateImage;
- (id)generateImageReturningRecordIdentifiers:(id*)arg1;
- (id)icon;
- (id)imageDescriptor;
- (id)init;
- (id)initWithCoder:(id)arg1;
- (unsigned long long)lsDatabaseSequenceNumber;
- (id)lsDatabaseUUID;
- (void)setIcon:(ISConcreteIcon*)arg1;
- (void)setImageDescriptor:(ISImageDescriptor*)arg1;
- (void)setLsDatabaseSequenceNumber:(unsigned long long)arg1;
- (void)setLsDatabaseUUID:(NSUUID*)arg1;

@end

@interface ISRecordResourceProvider : NSObject
-(id)initWithRecord:(id)arg1 options:(unsigned long long)arg2 ;
-(void)resolveResources;
-(id)suggestedRecipe;
-(void)setSuggestedRecipe:(id)suggestedRecipe;
-(void)setResourceType:(NSUInteger)type;
-(void)setIconShape:(NSUInteger)type;
@end

@interface ISiOSAppRecipe : NSObject
- (instancetype)init;
@end

// tvOS app icons are compiled as CoreUI layer stacks. UIKit's public image
// loader only searches the current iOS app's catalog, so it cannot flatten a
// layer stack stored in an imported Apple TV app's Assets.car.
@interface CUICatalog : NSObject
- (instancetype)initWithURL:(NSURL *)url error:(NSError **)error;
- (NSArray<NSString *> *)allImageNames;
- (id)imageWithName:(NSString *)name scaleFactor:(CGFloat)scale;
- (id)imageWithName:(NSString *)name
		 scaleFactor:(CGFloat)scale
		 deviceIdiom:(NSInteger)deviceIdiom;
@end

@interface CUINamedImage : NSObject
- (CGImageRef)image;
- (CGImageRef)croppedImage;
- (CGFloat)scale;
@end

static UIImage *FRUIImageFromCoreUIImage(id namedImage) {
	if (!namedImage) return nil;
	// A layer-stack descriptor can share a catalog name with a bitmap. Never
	// treat arbitrary CoreUI objects as images or invoke their flattening API.
	Class imageClass = objc_lookUpClass("CUINamedImage");
	if (!imageClass || ![namedImage isKindOfClass:imageClass]) return nil;

	CGImageRef imageRef = nil;
	if ([namedImage respondsToSelector:@selector(image)]) {
		imageRef = [(CUINamedImage *)namedImage image];
	}
	if (!imageRef && [namedImage respondsToSelector:@selector(croppedImage)]) {
		imageRef = [(CUINamedImage *)namedImage croppedImage];
	}
	if (!imageRef || CGImageGetWidth(imageRef) <= 1 || CGImageGetHeight(imageRef) <= 1 ||
		CGImageGetWidth(imageRef) > 4096 || CGImageGetHeight(imageRef) > 4096) {
		return nil;
	}

	// Keep the catalog's pixel dimensions. Imported tvOS artwork can report a
	// display scale intended for Apple TV rather than the current iPhone.
	return [UIImage imageWithCGImage:imageRef scale:1 orientation:UIImageOrientationUp];
}

static UIImage *FRLargestCatalogImage(CUICatalog *catalog, NSString *name) {
	NSMutableArray *lookups = [NSMutableArray array];
	if ([catalog respondsToSelector:@selector(imageWithName:scaleFactor:deviceIdiom:)]) {
		// CoreUI's catalog idioms are not UIKit's enum values. Compiled tvOS
		// renditions use idiom 3; keep 2/0/6 for older catalogs and marketing
		// variants encountered in the wild.
		for (NSNumber *idiom in @[@3, @2, @0, @6]) {
			for (NSNumber *scale in @[@1, @2, @3]) {
				id match = [catalog imageWithName:name
								 scaleFactor:scale.doubleValue
								 deviceIdiom:idiom.integerValue];
				if (match) [lookups addObject:match];
			}
		}
	}
	if ([catalog respondsToSelector:@selector(imageWithName:scaleFactor:)]) {
		for (NSNumber *scale in @[@1, @2, @3]) {
			id match = [catalog imageWithName:name scaleFactor:scale.doubleValue];
			if (match) [lookups addObject:match];
		}
	}

	UIImage *largest = nil;
	NSUInteger largestArea = 0;
	for (id lookup in lookups) {
		UIImage *image = FRUIImageFromCoreUIImage(lookup);
		if (!image.CGImage) continue;
		NSUInteger area = CGImageGetWidth(image.CGImage) * CGImageGetHeight(image.CGImage);
		if (area > largestArea) {
			largest = image;
			largestArea = area;
		}
	}
	return largest;
}

static UIImage *FRCompositeTVIconLayers(CUICatalog *catalog, NSString *iconName) {
	// Xcode compiles a pre-flattened rendition beside the layer-stack
	// descriptor. It is the most faithful and cheapest representation to use.
	UIImage *flattened = FRLargestCatalogImage(catalog, iconName);
	if (flattened) return flattened;

	NSArray<NSString *> *roles = @[@"Background", @"Middle", @"Foreground"];
	NSMutableArray<UIImage *> *layers = [NSMutableArray array];
	NSArray<NSString *> *allNames = [catalog respondsToSelector:@selector(allImageNames)]
		? [catalog allImageNames]
		: @[];

	for (NSString *role in roles) {
		NSMutableArray<NSString *> *candidates = [NSMutableArray arrayWithObjects:
			[NSString stringWithFormat:@"%@/%@/Content", iconName, role],
			[NSString stringWithFormat:@"%@/%@", iconName, role], nil];

		// Asset catalogs occasionally retain a generator-specific suffix. Match
		// it by role, but only inside the requested brand asset.
		NSString *prefix = [iconName stringByAppendingString:@"/"];
		for (NSString *catalogName in allNames) {
			if ([catalogName rangeOfString:prefix options:NSCaseInsensitiveSearch].location == 0 &&
				[catalogName rangeOfString:role options:NSCaseInsensitiveSearch].location != NSNotFound &&
				![candidates containsObject:catalogName]) {
				[candidates addObject:catalogName];
			}
		}

		UIImage *layer = nil;
		for (NSString *candidate in candidates) {
			layer = FRLargestCatalogImage(catalog, candidate);
			if (layer) break;
		}
		if (layer) [layers addObject:layer];
	}

	if (layers.count == 0) return nil;

	CGSize canvasSize = CGSizeZero;
	for (UIImage *layer in layers) {
		if (layer.size.width * layer.size.height > canvasSize.width * canvasSize.height) {
			canvasSize = layer.size;
		}
	}
	if (canvasSize.width <= 1 || canvasSize.height <= 1) return nil;

	UIGraphicsBeginImageContextWithOptions(canvasSize, NO, 1);
	for (UIImage *layer in layers) {
		CGFloat scale = MIN(canvasSize.width / layer.size.width, canvasSize.height / layer.size.height);
		CGSize size = CGSizeMake(layer.size.width * scale, layer.size.height * scale);
		CGRect rect = CGRectMake(
			(canvasSize.width - size.width) / 2,
			(canvasSize.height - size.height) / 2,
			size.width,
			size.height
		);
		[layer drawInRect:rect];
	}
	UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	return result;
}


@interface LSApplicationRecordFake : NSObject
@property NSBundle* bundle;
@end


@implementation LSApplicationRecordFake
- (instancetype)initWithBundle:(NSBundle *)bundle {
    self.bundle = bundle;
    return self;
}
- (BOOL)_is_canProvideIconResources {
    return YES;
}
- (NSDictionary *)iconDictionary {
    IFBundle* ifBundle = [[PrivClass(IFBundle) alloc] initWithURL:self.bundle.bundleURL];
    return [ifBundle iconDictionary];
}
- (NSURL *)iconResourceBundleURL {
    return self.bundle.bundleURL;
}
- (NSData *)persistentIdentifier {
    return [NSData data];
}
- (NSUInteger) _IS_platformToIFPlatform {
    return 4;
}
- (int)developerType {
	return 0;
}
- (id)appClipMetadata {
    return nil;
}

-(BOOL)isKindOfClass:(Class)aClass {
    const char* className = class_getName(aClass);
    if(strcmp(className, "LSBundleRecord") == 0) {
        return true;
    } else if (strcmp(className, "LSApplicationRecord") == 0) {
        return true;
    } else {
        return [super isKindOfClass:aClass];
    }
}
@end



@interface ISBundleIconFake : NSObject
@end

@implementation ISBundleIconFake

- (id)makeResourceProvider {
    NSURL* url = [(ISBundleIcon*)self url];
    NSBundle* bundle = [[NSBundle alloc] initWithURL:url];
    // to make IconServices generate an app icon, we need ISRecordResourceProvider instead of ISBundleResourceProvider, but it requires a LSApplicationRecord, so we create a fake LSApplicationRecordFake with necessary methods to make it initialize correctly
    LSApplicationRecordFake* record = [[LSApplicationRecordFake alloc] initWithBundle:bundle];
    ISRecordResourceProvider* provider = [[PrivClass(ISRecordResourceProvider) alloc] initWithRecord:record options:0];
    
    // set suggestedRecipe so -[ISRecipeFactory _recipe] skips all checks and directly use ISiOSAppRecipe
	if (@available(iOS 17.0, *)) {
		[provider setSuggestedRecipe:[[PrivClass(ISiOSAppRecipe) alloc] init]];
		[provider setResourceType:1];
	} else {
		[provider setIconShape:7];
	}
    return provider;
}

@end

@interface IFBundleFake : NSObject
@end

@implementation IFBundleFake
- (NSUInteger)platform {
    return 4;
}
@end


UIImage* tvOSIconTest(NSURL *bundleURL, NSArray<NSString *> *iconNames) {
	@try {
	NSURL *catalogURL = [bundleURL URLByAppendingPathComponent:@"Assets.car"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:catalogURL.path]) {
		return nil;
	}

	// Read ordinary compiled bitmaps only. IconServices' foreign layer-stack
	// flattening would reintroduce the previous crash-prone rendering path.
	dlopen("/System/Library/PrivateFrameworks/CoreUI.framework/CoreUI", RTLD_LAZY | RTLD_GLOBAL);

	Class catalogClass = objc_lookUpClass("CUICatalog");
	if (!catalogClass) {
		return nil;
	}

	NSError *error = nil;
	CUICatalog *catalog = [[catalogClass alloc] initWithURL:catalogURL error:&error];
	if (!catalog || error) {
		return nil;
	}

	for (NSString *name in iconNames) {
		// Use the pre-flattened bitmap when available, otherwise draw the
		// ordinary Background/Middle/Foreground images with our own compositor.
		UIImage *composited = FRCompositeTVIconLayers(catalog, name);
		if (composited.size.width > 1 && composited.size.height > 1) {
			return composited;
		}
	}

	return nil;
	} @catch (NSException *exception) {
		// Imported apps are untrusted input. A private CoreUI mismatch must
		// degrade to the normal placeholder, never terminate NullSign.
		(void)exception;
		return nil;
	}
}


UIImage* iconTest(NSURL *bundleURL) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void* handle = dlopen("/System/Library/PrivateFrameworks/IconServices.framework/IconServices", RTLD_LAZY|RTLD_GLOBAL);
        assert(handle);

        method_exchangeImplementations(class_getInstanceMethod(PrivClass(ISBundleIcon), @selector(makeResourceProvider)), class_getInstanceMethod(ISBundleIconFake.class, @selector(makeResourceProvider)));
        // stop IFBundle from connecting to lsd database
        method_exchangeImplementations(class_getInstanceMethod(PrivClass(IFBundle), @selector(platform)), class_getInstanceMethod(IFBundleFake.class, @selector(platform)));
    });

//    NSBundle* bundle = [NSBundle bundleWithURL:[docPathUrl URLByAppendingPathComponent:@"me.oatmealdome.DolphiniOS-njb.app"]];
//    ISBundleIcon* icon = [[PrivClass(ISBundleIcon) alloc] initWithBundleURL:[docPathUrl URLByAppendingPathComponent:@"com.aigch.OpenParsec1.app"]];
    ISBundleIcon* icon = [[PrivClass(ISBundleIcon) alloc] initWithBundleURL:bundleURL];
//    ISBundleIcon* icon = [[PrivClass(ISBundleIcon) alloc] initWithBundleURL:[docPathUrl URLByAppendingPathComponent:@"org.mozilla.ios.Firefox.app"]];
    ISImageDescriptor *descriptor = [PrivClass(ISImageDescriptor) imageDescriptorNamed:@"com.apple.IconServices.ImageDescriptor.HomeScreen"];
    descriptor.drawBorder = YES;
    descriptor.ignoreCache = YES;
    descriptor.scale = UIScreen.mainScreen.scale;
	descriptor.tintColor =
		[[PrivClass(IFColor) alloc]
			initWithCGColor:FRCreateCGColorFromHex()];

    descriptor.variantOptions = 0;
    // 0 = light mode, 1 = dark mode
//    descriptor.appearance = 0;
	NSInteger style =
		[NSUserDefaults.standardUserDefaults integerForKey:@"Feather.userInterfaceStyle"];
	NSInteger variant =
		[NSUserDefaults.standardUserDefaults integerForKey:@"Feather.shouldTintIcons"];
	NSInteger lightDark =
		[NSUserDefaults.standardUserDefaults integerForKey:@"Feather.shouldChangeIconsBasedOffStyle"];

	// Resolve "system / unspecified" dynamically
	if (style == UIUserInterfaceStyleUnspecified) {
		style = UIScreen.mainScreen.traitCollection.userInterfaceStyle;
	}

	// IconServices: 0 = light, 1 = dark
	descriptor.appearance = 0;
	if (lightDark == 1) {
		descriptor.appearance =
		(style == UIUserInterfaceStyleDark) ? 1 : 0;
	}

    if (@available(iOS 18.0, *)) {
        // 0 = normal, 2 = tinted mode, 3 = liquid glass (gray scale)
		if (@available(iOS 18.2, *)) {
			descriptor.appearanceVariant = (variant == 0) ? 0 : 2;
		}
        descriptor.specialIconOptions = 2;
    }

    ISGenerationRequest* request = [[PrivClass(ISGenerationRequest) alloc] init];
    [request setIcon:(ISConcreteIcon*)icon];
    [request setImageDescriptor:descriptor];
    IFImage* ifImage = [request generateImageReturningRecordIdentifiers:nil];
    CGImageRef imageRef = [ifImage CGImage];
    return [UIImage imageWithCGImage:imageRef];

}

static CGColorRef FRCreateCGColorFromHex(void) {
	NSString *hex =
		[NSUserDefaults.standardUserDefaults
			stringForKey:@"Feather.userTintColor"];

	if (hex.length == 0) {
		return UIColor.systemGreenColor.CGColor;
	}

	NSString *sanitized =
		[[hex stringByTrimmingCharactersInSet:
			NSCharacterSet.whitespaceAndNewlineCharacterSet]
			stringByReplacingOccurrencesOfString:@"#" withString:@""];

	unsigned long long rgb = 0;
	[[NSScanner scannerWithString:sanitized] scanHexLongLong:&rgb];

	CGFloat r = 0, g = 0, b = 0, a = 1;

	if (sanitized.length == 6) {
		r = ((rgb & 0xFF0000) >> 16) / 255.0;
		g = ((rgb & 0x00FF00) >> 8)  / 255.0;
		b = (rgb & 0x0000FF) / 255.0;
	} else if (sanitized.length == 8) {
		r = ((rgb & 0xFF000000) >> 24) / 255.0;
		g = ((rgb & 0x00FF0000) >> 16) / 255.0;
		b = ((rgb & 0x0000FF00) >> 8)  / 255.0;
		a = (rgb & 0x000000FF) / 255.0;
	} else {
		return UIColor.systemGreenColor.CGColor;
	}

	return [UIColor colorWithRed:r green:g blue:b alpha:a].CGColor;
}
