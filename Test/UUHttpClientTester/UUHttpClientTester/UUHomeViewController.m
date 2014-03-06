//
//  UUHomeViewController.m
//  UUHttpClientTester
//
//  Created by Ryan DeVore on 2/28/14.
//  Copyright (c) 2014 Three Jacks Software. All rights reserved.
//

#import "UUHomeViewController.h"
#import "UUAppDelegate.h"

@interface UUHomeViewController ()

@property (nonatomic, strong) NSArray* tableData;

@end

@implementation UUHomeViewController

- (int) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tableData.count;
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* cellId = @"CellId";
    
    UITableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:cellId forIndexPath:indexPath];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    NSDictionary* d = self.tableData[indexPath.row];
    cell.textLabel.text = [d valueForKey:@"msg"];
    
    return cell;
}

- (IBAction)onDoStuffClicked:(id)sender
{
    [UUAppDelegate doBackgroundUploadDownload];
}


@end
