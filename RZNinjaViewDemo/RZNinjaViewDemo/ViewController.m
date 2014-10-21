//
//  ViewController.m
//  RZNinjaViewDemo
//
//  Created by Rob Visentin on 10/19/14.
//  Copyright (c) 2014 Raizlabs. All rights reserved.
//

#import "ViewController.h"
#import "RZNinjaView.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet RZNinjaView *ninjaView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)resetPressed
{
    [self.ninjaView reset];
}

@end
