//
//  LSIWeatherViewController.m
//
//  Created by Paul Solt on 2/6/20.
//  Copyright © 2020 Lambda, Inc. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import "LSIWeatherViewController.h"
#import "LSIWeatherIcons.h"
#import "LSIErrors.h"
#import "LSILog.h"
#import "LSIWeatherForcast.h"
#import "LSIFileHelper.h"
#import "LSICardinalDirection.h"

@interface LSIWeatherViewController () {
    BOOL _requestedLocation;
}

@property CLLocationManager *locationManager;
@property CLLocation *location;
@property (nonatomic) CLPlacemark *placemark;
@property (weak, nonatomic) IBOutlet UIImageView *iconImage;
@property (weak, nonatomic) IBOutlet UILabel *cityStateLabel;
@property (weak, nonatomic) IBOutlet UILabel *summaryLabel;
@property (weak, nonatomic) IBOutlet UILabel *tempertureLabel;
@property (weak, nonatomic) IBOutlet UILabel *windLabel;
@property (weak, nonatomic) IBOutlet UILabel *humidityLabel;
@property (weak, nonatomic) IBOutlet UILabel *chanceOfRainLabel;
@property (weak, nonatomic) IBOutlet UILabel *feelsLikeLabel;
@property (weak, nonatomic) IBOutlet UILabel *pressureLabel;
@property (weak, nonatomic) IBOutlet UILabel *uvindexLabel;
@property (weak, nonatomic) IBOutlet UIToolbar *settingsButton;




@end

// NOTE: You must declare the Category before the main implementation,
// otherwise you'll see errors about the type not being correct if you
// try to move delegate methods out of the main implementation body
@interface LSIWeatherViewController (CLLocationManagerDelegate) <CLLocationManagerDelegate>

@end


@implementation LSIWeatherViewController



- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return self;
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return self;
}


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.locationManager.delegate = self;
    [self.locationManager requestWhenInUseAuthorization];
    [self.locationManager startUpdatingLocation];
    
    
    // TODO: Transparent toolbar with info button (Settings)
    // TODO: Handle settings button pressed
}

//https://developer.apple.com/documentation/corelocation/converting_between_coordinates_and_user-friendly_place_names
- (void)requestCurrentPlacemarkForLocation:(CLLocation *)location
                            withCompletion:(void (^)(CLPlacemark *, NSError *))completionHandler {
    if (location) {
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];
                
        [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> * _Nullable placemarks, NSError * _Nullable error) {
            if (error) {
                completionHandler(nil, error);
                return;
            }
            
            if (placemarks.count >= 1) {
                CLPlacemark *place = placemarks.firstObject;
                
                completionHandler(place, nil);
                return;
                
            } else {
                NSError *placeError = errorWithMessage(@"No places match current location", LSIPlaceError);
                
                completionHandler(nil, placeError);
                return;
            }
        }];
        
    } else {
        NSLog(@"ERROR: Missing location, please provide location");
    }
}

- (void)requestUserFriendlyLocation:(CLLocation *)location {
    if(!_requestedLocation) {
        _requestedLocation = YES;
        __block BOOL requestedLocation = _requestedLocation;
        
        [self requestCurrentPlacemarkForLocation:location withCompletion:^(CLPlacemark *place, NSError *error) {
            
            NSLog(@"Location: %@, %@", place.locality, place.administrativeArea);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                self.location = location;
                self.placemark = place;
                [self updateViews];
            });
            requestedLocation = NO;
        }];
    }
}

- (void)requestWeatherForLocation:(CLLocation *)location {
    
    // TODO: 1. Parse CurrentWeather.json from App Bundle and update UI
    
    
    
    
    // TODO: 2. Refactor and Parse Weather.json from App Bundle and update UI
}

- (void)updateViews {
    if (self.placemark) {
        //Update the City, State label
        self.cityStateLabel.text = [NSString stringWithFormat:@"%@, %@", _placemark.locality, _placemark.administrativeArea];
    }
    
    //Update the UI based on the current forecast
    NSData *data = loadFile(@"CurrentWeather.json", [LSIWeatherForcast class]);
    NSError *error = nil;
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"error parsing json: %@", error);
    }
    NSLog(@"json: %@", json);
    
    LSIWeatherForcast *weatherForcast = [[LSIWeatherForcast alloc] initWithDictionary:json];
    //topView
    self.iconImage.image = [LSIWeatherIcons weatherImageForIconName:weatherForcast.icon];
    self.summaryLabel.text = weatherForcast.summary;
    self.tempertureLabel.text = [ NSString stringWithFormat:@"%0.0f°F", weatherForcast.temperature.doubleValue];
    //bottomView
    NSString *bearing = [LSICardinalDirection directionForHeading:weatherForcast.windBearing.doubleValue];
    self.windLabel.text = [NSString stringWithFormat:@"%@ %0.0f mph", bearing, weatherForcast.windSpeed.doubleValue];
    self.humidityLabel.text = [NSString stringWithFormat:@"%0.0f%%", weatherForcast.humidity.doubleValue * 100];
    self.chanceOfRainLabel.text = [NSString stringWithFormat:@"%0.0f%%", weatherForcast.precipProbability.doubleValue * 100];
    self.feelsLikeLabel.text = [NSString stringWithFormat:@"%0.0f°F", weatherForcast.apparentTemperature.doubleValue];
    self.pressureLabel.text = [NSString stringWithFormat:@"%0.0f inHG", weatherForcast.pressure.doubleValue / 33.8641757];
    self.uvindexLabel.text = [NSString stringWithFormat:@"%i", weatherForcast.uvIndex.intValue];
}

@end

/// MARK: CLLocationManagerDelegate Methods

@implementation LSIWeatherViewController(CLLocationManagerDelegate)

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"locationManager Error: %@", error);
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    NSLog(@"locationManager: found location %@", locations.firstObject);
    
    CLLocation *location = locations.firstObject;
    
    // 1. Request Weather for location
    
    [self requestWeatherForLocation: location];
    
    // 2. Request User-Friendly Place Names for Lat/Lon coordinate
    
    [self requestUserFriendlyLocation: location];
    
    // Stop updating location after getting one (NOTE: this is faster than doing a single location request)
    [manager stopUpdatingLocation];
}

@end
