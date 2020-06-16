#import "CDVRadar.h"

@implementation CDVRadar {
    CLLocationManager *locationManager;
    NSString *eventsCallbackId;
    NSString *locationCallbackId;
    NSString *clientLocationCallbackId;
    NSString *errorCallbackId;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [Radar setDelegate:self];
        locationManager = [CLLocationManager new];
    }
    return self;
}

- (void)didReceiveEvents:(NSArray<RadarEvent *> *)events user:(RadarUser *)user {
    if (!eventsCallbackId) {
        return;
    }

    NSDictionary *dict = @{@"events": [RadarEvent arrayForEvents:events], @"user": [user dictionaryValue]};

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:eventsCallbackId];
}

- (void)didUpdateLocation:(CLLocation *)location user:(RadarUser *)user {
    if (!locationCallbackId) {
        return;
    }

    NSDictionary *dict = @{@"location": [Radar dictionaryForLocation:location], @"user": [user dictionaryValue]};

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:locationCallbackId];
}

- (void)didUpdateClientLocation:(CLLocation *)location stopped:(BOOL)stopped source:(RadarLocationSource)source {
    if (!clientLocationCallbackId) {
        return;
    }

    NSDictionary *dict = @{@"location": [Radar dictionaryForLocation:location], @"stopped": @(stopped), @"source": [Radar stringForSource:source]};

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:clientLocationCallbackId];
}

- (void)didFailWithStatus:(RadarStatus)status {
    if (!errorCallbackId) {
        return;
    }

    NSDictionary *dict = @{@"status": [Radar stringForStatus:status]};

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
    [pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:errorCallbackId];
}

- (void)didLogMessage:(NSString *)message {

}

- (void)setUserId:(CDVInvokedUrlCommand *)command {
    NSString *userId = [command.arguments objectAtIndex:0];

    [Radar setUserId:userId];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setDescription:(CDVInvokedUrlCommand *)command {
    NSString *description = [command.arguments objectAtIndex:0];

    [Radar setDescription:description];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)setMetadata:(CDVInvokedUrlCommand *)command {
    NSDictionary *metadata = [command.arguments objectAtIndex:0];

    [Radar setMetadata:metadata];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getPermissionsStatus:(CDVInvokedUrlCommand *)command {
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];

    NSString *str;
    switch (status) {
        case kCLAuthorizationStatusDenied:
            str = @"DENIED";
            break;
        case kCLAuthorizationStatusRestricted:
            str = @"DENIED";
            break;
        case kCLAuthorizationStatusAuthorizedAlways:
            str = @"GRANTED_BACKGROUND";
            break;
        case kCLAuthorizationStatusAuthorizedWhenInUse:
            str = @"GRANTED_FOREGROUND";
            break;
        default:
            str = @"UNKNOWN";
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:str];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)requestPermissions:(CDVInvokedUrlCommand *)command {
    NSNumber *backgroundNumber = [command.arguments objectAtIndex:0];

    BOOL background = [backgroundNumber boolValue];

    if (background) {
        [locationManager requestAlwaysAuthorization];
    } else {
        [locationManager requestWhenInUseAuthorization];
    }

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)getLocation:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [Radar getLocationWithCompletionHandler:^(RadarStatus status, CLLocation *location, BOOL stopped) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (location) {
                [dict setObject:[Radar dictionaryForLocation:location] forKey:@"location"];
            }
            [dict setObject:@(stopped) forKey:@"stopped"];

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

- (void)trackOnce:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        RadarTrackCompletionHandler completionHandler = ^(RadarStatus status, CLLocation *location, NSArray<RadarEvent *> *events, RadarUser *user) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (location) {
                [dict setObject:[Radar dictionaryForLocation:location] forKey:@"location"];
            }
            if (events) {
                [dict setObject:[RadarEvent arrayForEvents:events] forKey:@"events"];
            }
            if (user) {
                [dict setObject:[user dictionaryValue] forKey:@"user"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };

        if (command.arguments && command.arguments.count) {
            NSDictionary *locationDict = [command.arguments objectAtIndex:0];
            NSNumber *latitudeNumber = locationDict[@"latitude"];
            NSNumber *longitudeNumber = locationDict[@"longitude"];
            NSNumber *accuracyNumber = locationDict[@"accuracy"];
            double latitude = [latitudeNumber doubleValue];
            double longitude = [longitudeNumber doubleValue];
            double accuracy = accuracyNumber ? [accuracyNumber doubleValue] : -1;
            CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:-1 horizontalAccuracy:accuracy verticalAccuracy:-1 timestamp:[NSDate date]];

            [Radar trackOnceWithLocation:location completionHandler:completionHandler];
        } else {
            [Radar trackOnceWithCompletionHandler:completionHandler];
        }
    }];
}

- (void)startTrackingEfficient:(CDVInvokedUrlCommand *)command {
    [Radar startTrackingWithOptions:RadarTrackingOptions.efficient];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)startTrackingResponsive:(CDVInvokedUrlCommand *)command {
    [Radar startTrackingWithOptions:RadarTrackingOptions.responsive];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)startTrackingContinuous:(CDVInvokedUrlCommand *)command {
    [Radar startTrackingWithOptions:RadarTrackingOptions.continuous];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)startTrackingCustom:(CDVInvokedUrlCommand *)command {
    NSDictionary *optionsDict = [command.arguments objectAtIndex:0];

    RadarTrackingOptions *options = [RadarTrackingOptions trackingOptionsFromDictionary:optionsDict];
    [Radar startTrackingWithOptions:options];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)stopTracking:(CDVInvokedUrlCommand *)command {
    [Radar stopTracking];

    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)onEvents:(CDVInvokedUrlCommand *)command {
    eventsCallbackId = command.callbackId;
}

- (void)onLocation:(CDVInvokedUrlCommand *)command {
    locationCallbackId = command.callbackId;
}

- (void)onClientLocation:(CDVInvokedUrlCommand *)command {
    clientLocationCallbackId = command.callbackId;
}

- (void)onError:(CDVInvokedUrlCommand *)command {
    errorCallbackId = command.callbackId;
}

- (void)offEvents:(CDVInvokedUrlCommand *)command {
    eventsCallbackId = nil;
}

- (void)offLocation:(CDVInvokedUrlCommand *)command {
    locationCallbackId = nil;
}

- (void)offClientLocation:(CDVInvokedUrlCommand *)command {
    clientLocationCallbackId = nil;
}

- (void)offError:(CDVInvokedUrlCommand *)command {
    errorCallbackId = nil;
}

- (void)getContext:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        RadarContextCompletionHandler completionHandler = ^(RadarStatus status, CLLocation * _Nullable location, RadarContext * _Nullable context) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (location) {
                [dict setObject:[Radar dictionaryForLocation:location] forKey:@"location"];
            }
            if (context) {
                [dict setObject:[context dictionaryValue] forKey:@"context"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };

        if (command.arguments && command.arguments.count) {
            NSDictionary *locationDict = [command.arguments objectAtIndex:0];
            NSNumber *latitudeNumber = locationDict[@"latitude"];
            NSNumber *longitudeNumber = locationDict[@"longitude"];
            double latitude = [latitudeNumber doubleValue];
            double longitude = [longitudeNumber doubleValue];
            CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];

            [Radar getContextForLocation:location completionHandler:completionHandler];
        } else {
            [Radar getContextWithCompletionHandler:completionHandler];
        }
    }];
}

- (void)searchPlaces:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        RadarSearchPlacesCompletionHandler completionHandler = ^(RadarStatus status, CLLocation * _Nullable location, NSArray<RadarPlace *> * _Nullable places) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (location) {
                [dict setObject:[Radar dictionaryForLocation:location] forKey:@"location"];
            }
            if (places) {
                [dict setObject:[RadarPlace arrayForPlaces:places] forKey:@"places"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };

        NSDictionary *optionsDict = [command.arguments objectAtIndex:0];

        CLLocation *near;
        NSDictionary *nearDict = optionsDict[@"near"];
        if (nearDict) {
            NSNumber *latitudeNumber = nearDict[@"latitude"];
            NSNumber *longitudeNumber = nearDict[@"longitude"];
            double latitude = [latitudeNumber doubleValue];
            double longitude = [longitudeNumber doubleValue];
            near = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];
        }
        NSNumber *radiusNumber = optionsDict[@"radius"];
        int radius;
        if (radiusNumber != nil && [radiusNumber isKindOfClass:[NSNumber class]]) {
            radius = [radiusNumber intValue];
        } else {
            radius = 1000;
        }
        NSArray *chains = optionsDict[@"chains"];
        NSArray *categories = optionsDict[@"categories"];
        NSArray *groups = optionsDict[@"groups"];
        NSNumber *limitNumber = optionsDict[@"limit"];
        int limit;
        if (limitNumber != nil && [limitNumber isKindOfClass:[NSNumber class]]) {
            limit = [limitNumber intValue];
        } else {
            limit = 10;
        }

        if (near) {
            [Radar searchPlacesNear:near radius:radius chains:chains categories:categories groups:groups limit:limit completionHandler:completionHandler];
        } else {
            [Radar searchPlacesWithRadius:radius chains:chains categories:categories groups:groups limit:limit completionHandler:completionHandler];
        }
    }];
}

- (void)searchGeofences:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        RadarSearchGeofencesCompletionHandler completionHandler = ^(RadarStatus status, CLLocation * _Nullable location, NSArray<RadarGeofence *> * _Nullable geofences) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (location) {
                [dict setObject:[Radar dictionaryForLocation:location] forKey:@"location"];
            }
            if (geofences) {
                [dict setObject:[RadarGeofence arrayForGeofences:geofences] forKey:@"geofences"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };

        NSDictionary *optionsDict = [command.arguments objectAtIndex:0];

        CLLocation *near;
        NSDictionary *nearDict = optionsDict[@"near"];
        if (nearDict) {
            NSNumber *latitudeNumber = nearDict[@"latitude"];
            NSNumber *longitudeNumber = nearDict[@"longitude"];
            double latitude = [latitudeNumber doubleValue];
            double longitude = [longitudeNumber doubleValue];
            near = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];
        }
        NSNumber *radiusNumber = optionsDict[@"radius"];
        int radius;
        if (radiusNumber != nil && [radiusNumber isKindOfClass:[NSNumber class]]) {
            radius = [radiusNumber intValue];
        } else {
            radius = 1000;
        }
        NSArray *tags = optionsDict[@"tags"];
        NSNumber *limitNumber = optionsDict[@"limit"];
        int limit;
        if (limitNumber != nil && [limitNumber isKindOfClass:[NSNumber class]]) {
            limit = [limitNumber intValue];
        } else {
            limit = 10;
        }

        if (near) {
            [Radar searchGeofencesNear:near radius:radius tags:tags limit:limit completionHandler:completionHandler];
        } else {
            [Radar searchGeofencesWithRadius:radius tags:tags limit:limit completionHandler:completionHandler];
        }
    }];
}

- (void)searchPoints:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        RadarSearchPointsCompletionHandler completionHandler = ^(RadarStatus status, CLLocation * _Nullable location, NSArray<RadarPoint *> * _Nullable points) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (location) {
                [dict setObject:[Radar dictionaryForLocation:location] forKey:@"location"];
            }
            if (points) {
                [dict setObject:[RadarPoint arrayForPoints:points] forKey:@"points"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };

        NSDictionary *optionsDict = [command.arguments objectAtIndex:0];

        CLLocation *near;
        NSDictionary *nearDict = optionsDict[@"near"];
        if (nearDict) {
            NSNumber *latitudeNumber = nearDict[@"latitude"];
            NSNumber *longitudeNumber = nearDict[@"longitude"];
            double latitude = [latitudeNumber doubleValue];
            double longitude = [longitudeNumber doubleValue];
            near = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];
        }
        NSNumber *radiusNumber = optionsDict[@"radius"];
        int radius;
        if (radiusNumber != nil && [radiusNumber isKindOfClass:[NSNumber class]]) {
            radius = [radiusNumber intValue];
        } else {
            radius = 1000;
        }
        NSArray *tags = optionsDict[@"tags"];
        NSNumber *limitNumber = optionsDict[@"limit"];
        int limit;
        if (limitNumber != nil && [limitNumber isKindOfClass:[NSNumber class]]) {
            limit = [limitNumber intValue];
        } else {
            limit = 10;
        }

        if (near) {
            [Radar searchPointsNear:near radius:radius tags:tags limit:limit completionHandler:completionHandler];
        } else {
            [Radar searchPointsWithRadius:radius tags:tags limit:limit completionHandler:completionHandler];
        }
    }];
}

- (void)autocomplete:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSDictionary *optionsDict = [command.arguments objectAtIndex:0];

        NSString *query = optionsDict[@"query"];
        CLLocation *near;
        NSDictionary *nearDict = optionsDict[@"near"];
        if (nearDict) {
            NSNumber *latitudeNumber = nearDict[@"latitude"];
            NSNumber *longitudeNumber = nearDict[@"longitude"];
            double latitude = [latitudeNumber doubleValue];
            double longitude = [longitudeNumber doubleValue];
            near = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];
        }
        NSNumber *limitNumber = optionsDict[@"limit"];
        int limit;
        if (limitNumber != nil && [limitNumber isKindOfClass:[NSNumber class]]) {
            limit = [limitNumber intValue];
        } else {
            limit = 10;
        }

        [Radar autocompleteQuery:query near:near limit:limit completionHandler:^(RadarStatus status, NSArray<RadarAddress *> * _Nullable addresses) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (addresses) {
                [dict setObject:[RadarAddress arrayForAddresses:addresses] forKey:@"addresses"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

- (void)geocode:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        NSString *query = [command.arguments objectAtIndex:0];

        [Radar geocodeAddress:query completionHandler:^(RadarStatus status, NSArray<RadarAddress *> * _Nullable addresses) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (addresses) {
                [dict setObject:[RadarAddress arrayForAddresses:addresses] forKey:@"addresses"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

- (void)reverseGeocode:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        RadarGeocodeCompletionHandler completionHandler = ^(RadarStatus status, NSArray<RadarAddress *> * _Nullable addresses) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (addresses) {
                [dict setObject:[RadarAddress arrayForAddresses:addresses] forKey:@"addresses"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };

        if (command.arguments && command.arguments.count) {
            NSDictionary *locationDict = [command.arguments objectAtIndex:0];
            NSNumber *latitudeNumber = locationDict[@"latitude"];
            NSNumber *longitudeNumber = locationDict[@"longitude"];
            double latitude = [latitudeNumber doubleValue];
            double longitude = [longitudeNumber doubleValue];
            CLLocation *location = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(latitude, longitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];

            [Radar reverseGeocodeLocation:location completionHandler:completionHandler];
        } else {
            [Radar reverseGeocodeWithCompletionHandler:completionHandler];
        }
    }];
}

- (void)ipGeocode:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        [Radar ipGeocodeWithCompletionHandler:^(RadarStatus status, RadarAddress * _Nullable address) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (address) {
                [dict setObject:[address dictionaryValue] forKey:@"address"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
    }];
}

- (void)getDistance:(CDVInvokedUrlCommand *)command {
    [self.commandDelegate runInBackground:^{
        RadarRouteCompletionHandler completionHandler = ^(RadarStatus status, RadarRoutes * _Nullable routes) {
            NSMutableDictionary *dict = [NSMutableDictionary new];
            [dict setObject:[Radar stringForStatus:status] forKey:@"status"];
            if (routes) {
                [dict setObject:[routes dictionaryValue] forKey:@"routes"];
            }

            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:dict];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        };

        NSDictionary *optionsDict = [command.arguments objectAtIndex:0];

        CLLocation *origin;
        NSDictionary *originDict = optionsDict[@"origin"];
        if (originDict) {
            NSNumber *originLatitudeNumber = originDict[@"latitude"];
            NSNumber *originLongitudeNumber = originDict[@"longitude"];
            double originLatitude = [originLatitudeNumber doubleValue];
            double originLongitude = [originLongitudeNumber doubleValue];
            origin = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(originLatitude, originLongitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];
        }
        NSDictionary *destinationDict = optionsDict[@"destination"];
        NSNumber *destinationLatitudeNumber = destinationDict[@"latitude"];
        NSNumber *destinationLongitudeNumber = destinationDict[@"longitude"];
        double destinationLatitude = [destinationLatitudeNumber doubleValue];
        double destinationLongitude = [destinationLongitudeNumber doubleValue];
        CLLocation *destination = [[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(destinationLatitude, destinationLongitude) altitude:-1 horizontalAccuracy:5 verticalAccuracy:-1 timestamp:[NSDate date]];
        NSArray *modesArr = optionsDict[@"modes"];
        RadarRouteMode modes = 0;
        if (modesArr != nil) {
            if ([modesArr containsObject:@"FOOT"] || [modesArr containsObject:@"foot"]) {
                modes = modes | RadarRouteModeFoot;
            }
            if ([modesArr containsObject:@"BIKE"] || [modesArr containsObject:@"bike"]) {
                modes = modes | RadarRouteModeBike;
            }
            if ([modesArr containsObject:@"CAR"] || [modesArr containsObject:@"car"]) {
                modes = modes | RadarRouteModeCar;
            }
        } else {
            modes = RadarRouteModeCar;
        }
        NSString *unitsStr = optionsDict[@"units"];
        RadarRouteUnits units;
        if (unitsStr != nil && [unitsStr isKindOfClass:[NSString class]]) {
            units = [unitsStr isEqualToString:@"METRIC"] || [unitsStr isEqualToString:@"metric"] ? RadarRouteUnitsMetric : RadarRouteUnitsImperial;
        } else {
            units = RadarRouteUnitsImperial;
        }

        if (origin) {
            [Radar getDistanceFromOrigin:origin destination:destination modes:modes units:units completionHandler:completionHandler];
        } else {
            [Radar getDistanceToDestination:destination modes:modes units:units completionHandler:completionHandler];
        }
    }];
}

@end
