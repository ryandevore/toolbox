//
//  UUHomeViewController.m
//  UUHttpClientTester
//
//  Created by Ryan DeVore on 2/28/14.
//  Copyright (c) 2014 Three Jacks Software. All rights reserved.
//

#import "UUHomeViewController.h"
#import "UUAppDelegate.h"
#import "UUHttpBackgroundSession.h"

// Define this to be the full path to the PHP test page.
#define TEST_SERVER_END_POINT @"http://localhost/server.php"

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
    NSString* fileName = @"testData.dat";
    long fileSize = 1024 * 1000 * 1;
    [self uploadFile:fileName fileSize:fileSize completion:^
    {
        [self downloadFile:fileName];
    }];
}

- (void) uploadFile:(NSString*)fileName fileSize:(long)fileSize completion:(void (^)())completion
{
    NSURL* uploadFile = [self generateRandomFileOfSize:fileSize];
    
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?fileName=%@", TEST_SERVER_END_POINT, fileName]];
    
    [UUHttpBackgroundSession post:url file:uploadFile completion:^(id response, NSError *error)
     {
         UUDebugLog(@"Upload complete.\nResponse: %@\nError: %@\n", response, error);
         completion();
     }];
}

- (void) downloadFile:(NSString*)fileName
{
    NSURL* url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?fileName=%@", TEST_SERVER_END_POINT, fileName]];
    
    [UUHttpBackgroundSession get:url completion:^(id response, NSError *error)
    {
        UUDebugLog(@"Download complete.\nResponse: %@\nError: %@\n", response, error);
    }];
}

- (NSURL*) generateRandomFileOfSize:(long)byteSize
{
    NSString* dir = NSTemporaryDirectory();
    NSString* path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%f", [NSDate timeIntervalSinceReferenceDate]]];
    path = [path stringByAppendingPathExtension:@"tmp"];
    
    FILE* f = fopen([path UTF8String], "wb");
    
    long written = 0;
    long chunkSize = 1024;
    
    void* buf = malloc(chunkSize);
    
    while (written < byteSize)
    {
        arc4random_buf(buf, chunkSize);
        fwrite(buf, 1, chunkSize, f);
        written += chunkSize;
    }
    
    free(buf);
    
    NSLog(@"path: %@", path);
    return [NSURL fileURLWithPath:path];
}


@end
