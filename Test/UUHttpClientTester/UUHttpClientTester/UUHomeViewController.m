//
//  UUHomeViewController.m
//  UUHttpClientTester
//
//  Created by Ryan DeVore on 2/28/14.
//  Copyright (c) 2014 Three Jacks Software. All rights reserved.
//

#import "UUHomeViewController.h"
#import "UUAppDelegate.h"

@interface UUVariableHeightTableCell : UITableViewCell

@end

@implementation UUVariableHeightTableCell

- (void) layoutSubviews
{
    [super layoutSubviews];
    
    CGRect r = CGRectMake(10, 5, 300, self.bounds.size.height);
    self.textLabel.frame = r;
    [self.textLabel sizeToFit];
}

@end


@interface UUHomeViewController ()

@property (nonatomic, strong) NSArray* tableData;

@end

@implementation UUHomeViewController

- (void) viewDidLoad
{
    [super viewDidLoad];
    
    [self.tableView registerClass:[UUVariableHeightTableCell class] forCellReuseIdentifier:@"CellId"];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.tableData = [[UUSqliteLog sharedInstance] readAppLog];
    [self.tableView reloadData];
}

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tableData.count;
}

- (NSDictionary*) labelAttributes
{
    NSMutableDictionary* md = [NSMutableDictionary dictionary];
    [md setObject:[UIFont systemFontOfSize:12] forKey:NSFontAttributeName];
    
    NSMutableParagraphStyle* ps = [[NSMutableParagraphStyle alloc] init];
    ps.lineBreakMode = NSLineBreakByWordWrapping;
    [md setObject:ps forKey:NSParagraphStyleAttributeName];
    
    return [md copy];
}

- (UITableViewCell*) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString* cellId = @"CellId";
    
    UUVariableHeightTableCell* cell = [tableView dequeueReusableCellWithIdentifier:cellId forIndexPath:indexPath];
    if (!cell)
    {
        cell = [[UUVariableHeightTableCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    NSDictionary* d = self.tableData[indexPath.row];

    cell.textLabel.numberOfLines = 0;
    cell.textLabel.attributedText = [[NSAttributedString alloc] initWithString:[d valueForKey:@"msg"] attributes:[self labelAttributes]];
    
    return cell;
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary* d = self.tableData[indexPath.row];
    NSString* msg = [d valueForKey:@"msg"];
    
    CGSize s = CGSizeMake(300, FLT_MAX);
    CGRect r = [msg boundingRectWithSize:s options:NSStringDrawingUsesLineFragmentOrigin attributes:[self labelAttributes] context:nil];
    return r.size.height + 10;
}

- (IBAction)onDoStuffClicked:(id)sender
{
    [UUAppDelegate doBackgroundUploadDownload];
}

- (IBAction)onExportLogClicked:(id)sender
{
    NSArray* logEntries = [[UUSqliteLog sharedInstance] readAppLog];
    

    NSString* path = [NSTemporaryDirectory() stringByAppendingString:@"upload.txt"];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:nil])
    {
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
    
    [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    
    NSFileHandle* fh = [NSFileHandle fileHandleForWritingAtPath:path];
    
    NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy'-'MM'-'dd'T'HH':'mm':'ss'";
    
    for (NSDictionary* d in logEntries)
    {
        NSDate* timestamp = [d valueForKey:@"timestamp"];
        NSString* msg = [d valueForKey:@"msg"];
        NSString* line = [NSString stringWithFormat:@"%@\t%@\n", [formatter stringFromDate:timestamp], msg];
        //NSLog(@"%@", line);
        NSData* encodedLine = [line dataUsingEncoding:NSUTF8StringEncoding];
        [fh writeData:encodedLine];
    }
    
    [fh closeFile];
    
    NSURL* url = [NSURL fileURLWithPath:path];
    NSArray *activityItems = @[@"upload.txt", url];
    
    UIActivityViewController* vc = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    [self presentViewController:vc animated:YES completion:nil];
}


@end