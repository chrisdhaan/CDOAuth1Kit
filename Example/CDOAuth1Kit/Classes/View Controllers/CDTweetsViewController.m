//
//  CDViewController.m
//  CDOAuth1Kit
//
//  Created by Christopher de Haan on 08/28/2016.
//
//  Copyright (c) 2016 Christopher de Haan <contact@christopherdehaan.me>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "CDTweet.h"
#import "CDTweetsViewController.h"
#import "CDTwitterClient.h"
#import "UIImageView+AFNetworking.h"

static NSString * const kTweetCellName = @"TweetCell";

@interface CDTweetsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (strong, nonatomic) NSArray *tweets;

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@end

@implementation CDTweetsViewController

#pragma mark - Lifecycle Methods

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.title = @"Tweets";
    
    NSString *logInOutTitle = @"Log Out";
    if (![[CDTwitterClient sharedClient] isAuthorized]) {
        logInOutTitle = @"Log In";
    }
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(logInOutTitle, nil)
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(logInOut)];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"CDTwitterClientDidLogInNotification" object:nil queue:nil usingBlock:^(NSNotification *note) {
        [self loadTweets];
        
        [self.navigationItem.rightBarButtonItem setTitle:NSLocalizedString(@"Log Out", nil)];
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"CDTwitterClientDidLogOutNotification" object:nil queue:nil usingBlock:^(NSNotification *note) {
        self.tweets = [NSArray array];
        
        [self.tableView reloadData];
        
        [self.navigationItem.rightBarButtonItem setTitle:NSLocalizedString(@"Log In", nil)];
    }];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if ([[CDTwitterClient sharedClient] isAuthorized]) {
        [self loadTweets];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Private Methods

- (void)logInOut {
    if ([[CDTwitterClient sharedClient] isAuthorized]) {
        [[CDTwitterClient sharedClient] deauthorize];
    } else {
        [[CDTwitterClient sharedClient] authorize];
    }
}

- (void)loadTweets {
    if (![[CDTwitterClient sharedClient] isAuthorized]) {
        return;
    }
    
    [[CDTwitterClient sharedClient] loadTimelineWithCompletion:^(NSArray *tweets, NSError *error) {
        if (error) {
            NSLog(@"Error: %@", error.localizedDescription);
        } else {
            self.tweets = tweets;
            
            [self.tableView reloadData];
        }
    }];
}

#pragma mark - UITableView DataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tweets.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kTweetCellName forIndexPath:indexPath];
    
    CDTweet *tweet = self.tweets[indexPath.row];
    
    cell.textLabel.text = tweet.tweetText;
    cell.textLabel.numberOfLines = 0;
    cell.detailTextLabel.text = tweet.userScreenName;
    
    NSURL *userImageURL = tweet.userImageURL;
    
    if (userImageURL) {
        __weak UITableViewCell *weakCell = cell;
        [weakCell.imageView setImageWithURLRequest:[NSURLRequest requestWithURL:tweet.userImageURL]
                                  placeholderImage:nil
                                           success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                                               weakCell.imageView.image = image;
                                           }
                                           failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                                               NSLog(@"Failed to load image for cell. %@", error.localizedDescription);
                                           }];
    }
    
    [cell setNeedsUpdateConstraints];
    [cell updateConstraintsIfNeeded];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50;
}

@end
