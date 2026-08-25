#import <Foundation/Foundation.h>

NSInteger AlbrhiTestsPassed = 0;
NSInteger AlbrhiTestsFailed = 0;

void Test_Transport(void);

int main(void) {
    @autoreleasepool {
        Test_Transport();
        printf("\n%ld passed, %ld failed\n", (long)AlbrhiTestsPassed, (long)AlbrhiTestsFailed);
        return AlbrhiTestsFailed == 0 ? 0 : 1;
    }
}
