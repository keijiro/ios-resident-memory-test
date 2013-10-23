//
//  MemoryConsumerViewController.m
//  MemoryConsumer
//
//  Created by Takahashi Keijiro on 10/23/13.
//  Copyright (c) 2013 Radium Software. All rights reserved.
//

#import "MemoryConsumerViewController.h"

static void *AllocateDirtyBlock(NSUInteger size)
{
    Byte *block = malloc(size);
    for (NSUInteger offset = 0; offset < size; offset++) {
        block[offset] = offset & 0xff;
    }
    return block;
}

@interface MemoryConsumerViewController ()

@end

@implementation MemoryConsumerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)allocateSmallMemoryBlocks:(id)sender {
    for (int i = 0; i < 1024 * 1024; i++) {
        if (_pointerArray[i] == NULL) {
            _pointerArray[i] = AllocateDirtyBlock(8);
        }
    }
}

- (IBAction)allocateLargeMemoryBlocks:(id)sender {
    for (int i = 0; i < 64; i++) {
        if (_pointerArray[i] == NULL) {
            _pointerArray[i] = AllocateDirtyBlock(256 * 1024);
        }
    }
}

- (IBAction)freeAll:(id)sender {
    for (int i = 0; i < 1024 * 1024; i++) {
        if (_pointerArray[i] != NULL) {
            free(_pointerArray[i]);
            _pointerArray[i] = NULL;
        }
    }
}

@end
