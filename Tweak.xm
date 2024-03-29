#define CHECK_TARGET
#import <PSHeader/PS.h>
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#import <IOKit/hid/IOHIDEvent.h>
#import <theos/IOSMacros.h>

#define IOHIDEventFieldOffsetOf(field) (field & 0xffff)
#define kIOHIDEventFieldDigitizerAuxiliaryPressure 0xB000B
#define kIOHIDEventFieldDigitizerTiltX 0xB000D
#define kIOHIDEventFieldDigitizerDensity 0xB0012

typedef NS_ENUM(uint32_t, IOHIDDigitizerEventUpdateMask) {
    kIOHIDDigitizerEventUpdateAuxiliaryPressureMask         = 1<<IOHIDEventFieldOffsetOf(kIOHIDEventFieldDigitizerAuxiliaryPressure),
    kIOHIDDigitizerEventUpdateTiltXMask                     = 1<<IOHIDEventFieldOffsetOf(kIOHIDEventFieldDigitizerTiltX),
    kIOHIDDigitizerEventUpdateDensityMask                   = 1<<IOHIDEventFieldOffsetOf(kIOHIDEventFieldDigitizerDensity),
};

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

@interface PNPChargingStatusView : UIView
@property (assign,nonatomic) NSInteger chargingState; 
- (void)beginPairing;
@end

CFArrayRef (*_IOHIDEventGetChildren)(IOHIDEventRef);
IOHIDEventType (*_IOHIDEventGetType)(IOHIDEventRef);
CFIndex (*_IOHIDEventGetIntegerValue)(IOHIDEventRef, IOHIDEventField);

%group SpringBoard

%hook UIGestureRecognizer

- (void)sb_setStylusTouchesAllowed:(BOOL)allowed {
    %orig(YES);
}

%end

%hook SBSystemGestureManager

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture1 shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)gesture2 {
    return NO;
}

%end

%end

bool hasEdgePendingOrLocked(UITouchesEvent *event) {
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

%group UIKitFunction

bool (*_UIEventHasEdgePendingOrLocked)(UITouchesEvent *) = NULL;
%hookf(bool, _UIEventHasEdgePendingOrLocked, UITouchesEvent *event) {
    return hasEdgePendingOrLocked(event);
}

%end

%group FrontBoardFunction

bool (*FBUIEventHasEdgePendingOrLocked)(UITouchesEvent *) = NULL;
%hookf(bool, FBUIEventHasEdgePendingOrLocked, UITouchesEvent *event) {
    return hasEdgePendingOrLocked(event);
}

%end

%group SharingHUD

%hook PNPChargingStatusView

- (void)updateChargingState:(NSInteger)state {
    %orig;
    if (state == 3) [self beginPairing];
}

%end

%end

%group UIKit

BOOL blacklistedApp = NO;

%hook UIPanGestureRecognizer

- (void)setAllowedTouchTypes:(NSArray <NSNumber *> *)types {
    if (!blacklistedApp && types && types.count && ![types containsObject:@(UITouchTypePencil)]) {
        NSMutableArray *finalTypes = [NSMutableArray arrayWithArray:types];
        [finalTypes addObject:@(UITouchTypePencil)];
        %orig(finalTypes);
    } else
        %orig(types);
}

%end

%hook UIScreenEdgePanGestureRecognizer

+ (BOOL)_shouldSupportStylusTouches {
    return YES;
}

%end

%end

%ctor {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;
    if ([bundleIdentifier isEqualToString:@"com.apple.Sharing.SharingHUDService"]) {
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
            MSImageRef fb = MSGetImageByName("/System/Library/PrivateFrameworks/FrontBoard.framework/FrontBoard");
            FBUIEventHasEdgePendingOrLocked = (bool (*)(UITouchesEvent *))MSFindSymbol(fb, "__FBUIEventHasEdgePendingOrLocked");
            if (FBUIEventHasEdgePendingOrLocked) {
                %init(FrontBoardFunction);
            }
            MSImageRef uc = MSGetImageByName("/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore");
            _UIEventHasEdgePendingOrLocked = (bool (*)(UITouchesEvent *))MSFindSymbol(uc, "__UIEventHasEdgePendingOrLocked");
            if (_UIEventHasEdgePendingOrLocked) {
                %init(UIKitFunction);
            }
            %init(SpringBoard);
        } else {
            blacklistedApp = [bundleIdentifier isEqualToString:@"com.goodnotesapp.x"];
        }
        %init(UIKit);
    }
}
