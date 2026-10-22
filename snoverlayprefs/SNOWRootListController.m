#import "SNOWRootListController.h"
#import <spawn.h>
#import <rootless.h>

@implementation SNOWRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}
	return _specifiers;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	UIBarButtonItem *respringItem = [[UIBarButtonItem alloc] initWithTitle:@"Respring"
																	 style:UIBarButtonItemStylePlain
																	target:self
																	action:@selector(respring)];
	self.navigationItem.rightBarButtonItem = respringItem;
}

- (void)respring {
	pid_t pid;
	const char *args[] = {"killall", "-9", "backboardd", NULL};
	posix_spawn(&pid, ROOT_PATH("/usr/bin/killall"), NULL, NULL, (char *const *)args, NULL);
}

@end
