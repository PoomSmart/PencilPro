#define CHECK_TARGET
#import "../PS.h"
#import "../libsubstitrate/substitrate.h"
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBDeviceApplicationSceneEntity.h>
#import <SpringBoard/SBMainWorkspace.h>
#import <SpringBoard/SBWorkspaceTransitionRequest.h>
#import <UIKit/UIKit.h>
#import <IOKit/hid/IOHIDEvent.h>
#import <Cephei/HBPreferences.h>

#define IOHIDEventFieldOffsetOf(field) (field & 0xffff)
#define kIOHIDEventFieldDigitizerAuxiliaryPressure 0xB000B
#define kIOHIDEventFieldDigitizerTiltX 0xB000D
#define kIOHIDEventFieldDigitizerDensity 0xB0012

typedef NS_ENUM(uint32_t, IOHIDDigitizerEventUpdateMask) {
    kIOHIDDigitizerEventUpdateAuxiliaryPressureMask         = 1<<IOHIDEventFieldOffsetOf(kIOHIDEventFieldDigitizerAuxiliaryPressure),
    kIOHIDDigitizerEventUpdateTiltXMask                     = 1<<IOHIDEventFieldOffsetOf(kIOHIDEventFieldDigitizerTiltX),
    kIOHIDDigitizerEventUpdateDensityMask                   = 1<<IOHIDEventFieldOffsetOf(kIOHIDEventFieldDigitizerDensity),
};

HBPreferences *preferences;
NSString *tweakIdentifier = @"com.PS.PencilPro";
BOOL enabled;
NSString *quickNoteAppID = @"xyz.willy.Zebra";

@interface UIEvent (Private)
- (IOHIDEventRef)_hidEvent;
@end

@interface UITouchesEvent : UIEvent
@end

@interface UIPencilEvent : UIEvent {
	NSMutableSet* _trackedInteractions;
}
@property (nonatomic, retain) NSMutableSet *trackedInteractions;
- (NSMutableSet *)trackedInteractions;
- (id)_init;
- (id)collectAllActiveInteractions;
- (void)_sendEventToInteractions;
- (void)registerInteraction:(id)arg1;
- (void)deregisterInteraction:(id)arg1;
- (void)setTrackedInteractions:(NSMutableSet *)arg1;
@end

@interface UIOpenURLAction : NSObject
- (id)initWithURL:(NSURL *)url;
@end

@interface PNPChargingStatusView : UIView
@property (assign,nonatomic) NSInteger chargingState; 
- (void)beginPairing;
@end

CFArrayRef (*_IOHIDEventGetChildren)(IOHIDEventRef);
IOHIDEventType (*_IOHIDEventGetType)(IOHIDEventRef);
CFIndex (*_IOHIDEventGetIntegerValue)(IOHIDEventRef, IOHIDEventField);

/*
73613	default	14:32:48.230762+0700	MobileNotes	39 Get type
73613	default	14:32:48.231064+0700	MobileNotes	0 Get int 1
73613	default	14:32:48.231132+0700	MobileNotes	2 Get int 2
*/

/*%hook UIPencilEvent

- (void)_sendEventToInteractions {
	IOHIDEventRef eventRef = [self _hidEvent];
	NSLog(@"Pencil %u Get type", _IOHIDEventGetType(eventRef));
	NSLog(@"Pencil %ld Get int 1", _IOHIDEventGetIntegerValue(eventRef, 0x270000));
	NSLog(@"Pencil %ld Get int 2", _IOHIDEventGetIntegerValue(eventRef, 0x270001));
	NSLog(@"Pencil %ld Get int 3", _IOHIDEventGetIntegerValue(eventRef, 0x270002));
	%orig;
}

%end*/

/*%hook LSApplicationWorkspace

- (NSURL *)URLOverrideForURL:(NSURL *)url {
	return %orig([url.absoluteString containsString:@"mobilenotes-quicknote"] ? [NSURL URLWithString:@"zbra://"] : url);
}

%end

%hook UIOpenURLAction

- (id)initWithURL:(NSURL *)url {
	return %orig([url.absoluteString containsString:@"mobilenotes-quicknote"] ? [NSURL URLWithString:@"zbra://"] : url);
}

%end*/

/*%hook SBDashBoardViewController

- (void)launchQuickNote {
	NSLog(@"PencilPro: Quick Note App: %@", quickNoteAppID);
	if (quickNoteAppID.length == 0) {
		%orig;
		return;
	}
	SBApplication *toApp = [(SBApplicationController *)[%c(SBApplicationController) sharedInstance] applicationWithBundleIdentifier:quickNoteAppID];
	SBMainWorkspace *workspace = [%c(SBMainWorkspace) sharedInstance];
    SBDeviceApplicationSceneEntity *app = [[%c(SBDeviceApplicationSceneEntity) alloc] initWithApplicationForMainDisplay:toApp];
    SBWorkspaceTransitionRequest *request = [workspace createRequestForApplicationActivation:app options:0];
    [workspace executeTransitionRequest:request];
	[app release];
}

%end*/

%group SpringBoard

%hook UIGestureRecognizer

- (void)sb_setStylusTouchesAllowed:(BOOL)allowed {
	%orig(YES);
}

%end

bool (*_FBUIEventHasEdgePendingOrLocked)(UITouchesEvent *);
bool FBUIEventHasEdgePendingOrLocked(UITouchesEvent *event) {
	IOHIDEventRef eventRef = [event _hidEvent];
	if (eventRef == NULL)
		return false;
	CFArrayRef children = _IOHIDEventGetChildren(eventRef);
	if (children == NULL)
		return false;
	CFIndex count = CFArrayGetCount(children);
	if (count <= 0)
		return false;
	uint8_t i = 1;
	CFIndex j = 0;
	while (true) {
		IOHIDEventRef ref = (IOHIDEventRef)CFArrayGetValueAtIndex(children, j);
		if (_IOHIDEventGetType(ref) == kIOHIDEventTypeDigitizer) {
			CFIndex mask = _IOHIDEventGetIntegerValue(ref, kIOHIDEventFieldDigitizerEventMask);
			// & 0x42800
			if (mask & (kIOHIDDigitizerEventUpdateDensityMask | kIOHIDDigitizerEventUpdateTiltXMask | kIOHIDDigitizerEventUpdateAuxiliaryPressureMask))
				break;
			// Pencil
			if (mask & 0x70000007)
				break;
    	}
		j = i++;
		if (count <= j)
			return false;
	}
	return true;
}

%hook FBExclusiveTouchGestureRecognizer

- (void)setMaximumAbsoluteAccumulatedMovement:(CGPoint)point {
	%orig(point.x && point.y ? CGPointMake(500, 500) : point);
}

%end

%hook SBSystemGestureManager

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture1 shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)gesture2 {
	return NO;
}

/*- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture1 shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)gesture2 {

}*/

%end

%end

/*%hook _FBSystemGestureManager

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture1 shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)gesture2 {
	BOOL orig = %orig(gesture1, gesture2);
	// gesture1: FBExclusiveTouchGestureRecognizer
	// gesture2: UIScreenEdgePanGestureRecognizer
	// will 0
	HBLogInfo(@"%d %@ | %@", orig, gesture1, gesture2);
	return orig;
}

%end*/

/*%hook SBInProcessSecureAppAction

- (id)initWithType:(NSInteger)type applicationSceneEntity:(SBDeviceApplicationSceneEntity *)entity handler:(void *)handler {
	NSLog(@"Pencil %ld %@", type, entity);
	return %orig;
}

%end*/

/*NSString *(*_SBSIdentifierForSecureAppType)(NSInteger type);
NSString *SBSIdentifierForSecureAppType(NSInteger type) {
	return type == 10 ? quickNoteAppID : _SBSIdentifierForSecureAppType(type);
}

NSInteger (*_SBSSecureAppTypeForIdentifier)(NSString *identifier);
NSInteger SBSSecureAppTypeForIdentifier(NSString *identifier) {
	return quickNoteAppID.length && [identifier isEqualToString:quickNoteAppID] ? 10 : _SBSSecureAppTypeForIdentifier(identifier);
}*/

%group SharingHUD

%hook PNPChargingStatusView

- (void)updateChargingState:(NSInteger)state {
	%orig;
	if (state == 3) [self beginPairing];
}

%end

%end

void initPrefs(BOOL SB) {
	//dlopen("/Library/Frameworks/Cephei.framework/Cephei", RTLD_LAZY);
	//NSLog(@"PencilPro: init(%d)", SB);
	/*preferences = [[%c(HBPreferences) alloc] initWithIdentifier:tweakIdentifier];
    [preferences registerBool:&enabled default:YES forKey:@"enabled"];
	if (SB) {
		[preferences registerObject:&quickNoteAppID default:@"xyz.willy.Zebra" forKey:@"quickNoteAppID"];
	}*/
}

%ctor {
	if ([NSBundle.mainBundle.bundleIdentifier isEqualToString:@"com.apple.Sharing.SharingHUDService"]) {
		dlopen("/System/Library/PrivateFrameworks/PencilPairingUI.framework/PencilPairingUI", RTLD_LAZY);
		%init(SharingHUD);
	}
	else if (isTarget(TargetTypeApps)) {
		void *IOKit = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
		if (IOKit) {
			_IOHIDEventGetChildren = (CFArrayRef (*)(IOHIDEventRef))dlsym(IOKit, "IOHIDEventGetChildren");
			_IOHIDEventGetType = (IOHIDEventType (*)(IOHIDEventRef))dlsym(IOKit, "IOHIDEventGetType");
			_IOHIDEventGetIntegerValue = (CFIndex (*)(IOHIDEventRef, IOHIDEventField))dlsym(IOKit, "IOHIDEventGetIntegerValue");
		}
		if (IN_SPRINGBOARD) {
			_PSHookFunctionCompat("/System/Library/PrivateFrameworks/FrontBoard.framework/FrontBoard", "__FBUIEventHasEdgePendingOrLocked", FBUIEventHasEdgePendingOrLocked);
			%init(SpringBoard);
			//_PSHookFunctionCompat("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", "_SBSSecureAppTypeForIdentifier", SBSSecureAppTypeForIdentifier);
			//_PSHookFunctionCompat("/System/Library/PrivateFrameworks/SpringBoardServices.framework/SpringBoardServices", "_SBSIdentifierForSecureAppType", SBSIdentifierForSecureAppType);
		}
		initPrefs(YES);
		%init;
	}
}