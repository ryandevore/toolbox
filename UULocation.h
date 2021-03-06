//
//  UULocation.h
//  Useful Utilities - CLLocationManager wrapper
//
//	License:
//  You are free to use this code for whatever purposes you desire. The only requirement is that you smile everytime you use it.
//
//  Contact: @cheesemaker or jon@silverpinesoftware.com


#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface UULocation : NSObject
	//The last reported location. If no location reported, this will be nil
	+ (UULocation*) lastReportedLocation;

	//Query location information. If the location name hasn't resolved, then the names will be nil
	@property (nonatomic, readonly) CLLocation* clLocation;
	@property (nonatomic, readonly) NSString* currentLocationName;
	@property (nonatomic, readonly) NSString* currentCityName;
	@property (nonatomic, readonly) NSString* currentStateName;
	- (BOOL) isValid;
@end


@protocol UULocationMonitoringDelegate <NSObject>
	@optional
		- (void) uuLocationChanged:(UULocation*)newLocation;
		- (void) uuLocationResolved:(UULocation*)resolvedLocation;
		- (void) uuLocationUpdateFailed:(NSError*)error;
@end


@interface UULocationMonitoring : NSObject
	+ (void) addDelegate:(NSObject<UULocationMonitoringDelegate>*)delegate;
	+ (void) removeDelegate:(NSObject<UULocationMonitoringDelegate>*)delegate;
@end


@interface UULocationMonitoringConfiguration : NSObject

	//Global settings interface.
	+ (BOOL) isAuthorizedToTrack;
	+ (BOOL) isTrackingDenied;

	+ (void) requestStartTracking:(BOOL)trackOnlyWhenInUse completionBlock:(void(^)(BOOL authorized))callback;
	+ (void) requestStopTracking;
	+ (void) startTrackingSignificantLocationChanges;
	+ (void) stopTrackingSignficantLocationChanges;

	+ (CLLocationDistance) distanceThreshold;
	+ (void) setDistanceThreshold:(CLLocationDistance) distanceThreshold;

	+ (NSTimeInterval) minimumTimeThreshold;
	+ (void) setMinimumTimeThreshold:(NSTimeInterval)timeThreshold;

	+ (BOOL) locationNameReportingEnabled;
	+ (void) setLocationNameReportingEnabled:(BOOL)enabled;

	+ (BOOL) delayLocationUpdates;
	+ (void) setDelayLocationUpdates:(BOOL)delayUpdates;

	+ (NSTimeInterval) locationUpdateDelay;
	+ (void) setLocationUpdateDelay:(NSTimeInterval)updateDelay;

@end