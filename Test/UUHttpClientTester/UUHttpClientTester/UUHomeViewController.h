//
//  UUHomeViewController.h
//  UUHttpClientTester
//
//  Created by Ryan DeVore on 2/28/14.
//  Copyright (c) 2014 Three Jacks Software. All rights reserved.
//

@import UIKit;

@interface UUHomeViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;

- (IBAction)onDoStuffClicked:(id)sender;

@end
