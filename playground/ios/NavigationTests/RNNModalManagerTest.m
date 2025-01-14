#import "RNNModalManager.h"
#import "RNNComponentViewController.h"
#import "RNNStackController.h"
#import <OCMock/OCMock.h>
#import <React/RCTModalHostViewManager.h>
#import <XCTest/XCTest.h>

@interface MockViewController : UIViewController

@property CGFloat presentViewControllerCalls;

@end
@implementation MockViewController

- (void)presentViewController:(UIViewController *)viewControllerToPresent
                     animated:(BOOL)flag
                   completion:(void (^)(void))completion {
    _presentViewControllerCalls++;
    completion();
}

@end

@interface RNNModalManagerTest : XCTestCase {
    CGFloat _modalDismissedCount;
}

@end

@implementation RNNModalManagerTest {
    RNNComponentViewController *_vc1;
    RNNComponentViewController *_vc2;
    RNNComponentViewController *_vc3;
    RNNModalManager *_modalManager;
    id _modalManagerEventHandler;
}

- (void)setUp {
    [super setUp];
    _vc1 = [RNNComponentViewController new];
    _vc2 = [RNNComponentViewController new];
    _vc3 = [RNNComponentViewController new];
    _vc1.layoutInfo = [RNNLayoutInfo new];
    _vc2.layoutInfo = [RNNLayoutInfo new];
    _vc3.layoutInfo = [RNNLayoutInfo new];
    _modalManagerEventHandler =
        [OCMockObject partialMockForObject:[RNNModalManagerEventHandler new]];
    _modalManager = [OCMockObject
        partialMockForObject:[[RNNModalManager alloc] initWithBridge:nil
                                                        eventHandler:_modalManagerEventHandler]];

    UIApplication.sharedApplication.delegate.window.rootViewController =
        [OCMockObject partialMockForObject:UIViewController.new];
}

- (void)tearDown {
    UIApplication.sharedApplication.delegate.window.rootViewController = UIViewController.new;
}

- (void)testDismissMultipleModalsInvokeDelegateWithCorrectParameters {
    OCMStub(
        UIApplication.sharedApplication.delegate.window.rootViewController.presentedViewController)
        .andReturn(MockViewController.new);
    [_modalManager showModal:_vc1 animated:NO completion:nil];
    [_modalManager showModal:_vc2 animated:NO completion:nil];
    [_modalManager showModal:_vc3 animated:NO completion:nil];

    [[_modalManagerEventHandler expect] dismissedMultipleModals:@[ _vc1, _vc2, _vc3 ]];
    [_modalManager dismissAllModalsAnimated:NO completion:nil];
    [_modalManagerEventHandler verify];
}

- (void)testDismissAllModals_InvokeCompletionWhenNoModalsPresented {
    XCTestExpectation *expectation =
        [self expectationWithDescription:@"Should invoke completion block"];

    [_modalManager dismissAllModalsAnimated:NO
                                 completion:^{
                                   [expectation fulfill];
                                 }];

    [self waitForExpectationsWithTimeout:10 handler:nil];
}

- (void)testDismissModal_InvokeDelegateWithCorrectParameters {
    [_modalManager showModal:_vc1 animated:NO completion:nil];
    [_modalManager showModal:_vc2 animated:NO completion:nil];
    [_modalManager showModal:_vc3 animated:NO completion:nil];

    [[_modalManagerEventHandler expect] dismissedModal:_vc3];
    [_modalManager dismissModal:_vc3 animated:NO completion:nil];
    [_modalManagerEventHandler verify];
}

- (void)testDismissPreviousModal_InvokeDelegateWithCorrectParameters {
    [_modalManager showModal:_vc1 animated:NO completion:nil];
    [_modalManager showModal:_vc2 animated:NO completion:nil];
    [_modalManager showModal:_vc3 animated:NO completion:nil];

    [[_modalManagerEventHandler expect] dismissedModal:_vc2];
    [_modalManager dismissModal:_vc2 animated:NO completion:nil];
    [_modalManagerEventHandler verify];
}

- (void)testDismissAllModals_AfterDismissingPreviousModal_InvokeDelegateWithCorrectParameters {
    OCMStub(
        UIApplication.sharedApplication.delegate.window.rootViewController.presentedViewController)
        .andReturn(MockViewController.new);
    [_modalManager showModal:_vc1 animated:NO completion:nil];
    [_modalManager showModal:_vc2 animated:NO completion:nil];
    [_modalManager showModal:_vc3 animated:NO completion:nil];

    [[_modalManagerEventHandler expect] dismissedModal:_vc2];
    [_modalManager dismissModal:_vc2 animated:NO completion:nil];
    [_modalManagerEventHandler verify];

    [[_modalManagerEventHandler expect] dismissedMultipleModals:@[ _vc1, _vc3 ]];
    [_modalManager dismissAllModalsAnimated:NO completion:nil];
    [_modalManagerEventHandler verify];
}

- (void)testDismissModal_DismissNilModalDoesntCrash {
    [[_modalManagerEventHandler reject] dismissedModal:OCMArg.any];
    [_modalManager dismissModal:nil animated:NO completion:nil];
    [_modalManagerEventHandler verify];
}

- (void)testShowModal_NilModalThrows {
    XCTAssertThrows([_modalManager showModal:nil animated:NO completion:nil]);
}

- (void)testShowModal_CallPresentViewController {
    OCMStub([_modalManager topPresentedVC]).andReturn([MockViewController new]);
    [_modalManager showModal:_vc1 animated:NO completion:nil];
    XCTAssertTrue(((MockViewController *)_modalManager.topPresentedVC).presentViewControllerCalls ==
                  1);
}

- (void)testPresentationControllerDidDismiss_ShouldInvokeDelegateDismissedModal {
    UIPresentationController *presentationController =
        [[UIPresentationController alloc] initWithPresentedViewController:_vc2
                                                 presentingViewController:_vc1];

    [[_modalManagerEventHandler expect] dismissedModal:_vc2];
    [_modalManager presentationControllerDidDismiss:presentationController];
    [_modalManagerEventHandler verify];
}

- (void)testPresentationControllerDidDismiss_ShouldInvokeDelegateDismissedModalWithPresentedChild {
    RNNStackController *nav = [[RNNStackController alloc] initWithRootViewController:_vc2];

    UIPresentationController *presentationController =
        [[UIPresentationController alloc] initWithPresentedViewController:nav
                                                 presentingViewController:_vc1];

    [[_modalManagerEventHandler expect] dismissedModal:_vc2];
    [_modalManager presentationControllerDidDismiss:presentationController];
    [_modalManagerEventHandler verify];
}

- (void)testApplyOptionsOnInit_shouldShowModalWithDefaultPresentationStyle {
    _vc1.options = [RNNNavigationOptions emptyOptions];
    [_modalManager showModal:_vc1 animated:NO completion:nil];
    XCTAssertEqual(_vc1.modalPresentationStyle, UIModalPresentationPageSheet);
}

- (void)testApplyOptionsOnInit_shouldShowModalWithDefaultTransitionStyle {
    _vc1.options = [RNNNavigationOptions emptyOptions];
    [_modalManager showModal:_vc1 animated:NO completion:nil];
    XCTAssertEqual(_vc1.modalTransitionStyle, UIModalTransitionStyleCoverVertical);
}

- (void)testTopPresentedVC_shouldNotReturnModalThatIsBeingDismissed {
    UIApplication.sharedApplication.delegate.window.rootViewController =
        [OCMockObject partialMockForObject:UIViewController.new];
    UIViewController *beingDismissedModal =
        [OCMockObject partialMockForObject:[UIViewController new]];
    [_modalManager showModal:beingDismissedModal animated:NO completion:nil];
    XCTAssertEqual(_modalManager.topPresentedVC, beingDismissedModal);
    OCMStub(beingDismissedModal.isBeingDismissed).andReturn(YES);
    XCTAssertNotEqual(_modalManager.topPresentedVC, beingDismissedModal);
}

@end
