---
layout: post
title:  "Behavior-Driven Development"
category: "15"
date: "2014-08-11 11:00:00"
author: "<a href=\"https://twitter.com/eldudi\">Pawel Dudek</a>"
tags: article
---

Starting your adventure with testing is not an easy task, especially if you don't have someone to help you out. If you've ever tried it, then you probably remember that moment when you thought: "This is it. I am starting testing now. I've heard so much about TDD and how beneficial it is, so I'm starting to do it right now."

Then you sat down in front of your computer. You opened your IDE. You created a new test file for one of your components.

And then void. You might have written a few tests that check some basic functionality, but you felt that something was wrong. You felt there was a question lurking somewhere in your head. A question that needed answering before you could really move forward:

**What should I test?**

The answer to that question is not simple. In fact, it is a rather complicated issue. The good news is that you were not the first one to ask. And you will definitely not be the last one. 

But you still wanted to pursue the idea of having tests. So you wrote tests that just called your methods (unit testing right?):

    -(void)testDownloadData;

There is one fundamental issue with tests like this: they don't really tell you what should happen. They don't tell you what is actually being expected. It is not *clear* what the requirements are. 

Moreover, when one of these tests fails, you have to dive into the code and *understand* why it failed. In an ideal world, you shouldn't have to do that in order to know what broke. 

This is where behavior-driven development (BDD) comes it. It aims at solving these exact issues by helping developers determine *what* should be tested. Moreover, it provides a DSL that encourages developers to *clarify* their requirements, and it introduces an ubiquitous language that helps you to easily *understand* what the purpose of a test is. 

## What Should I Test?

The answer to this profound question is strikingly simple, however it does require a shift in how you perceive your test suite. As the first word in BDD suggests, you should no longer focus on *tests*, but you should instead focus on *behaviors*. This seemingly meaningless change provides an exact answer to the aforementioned question: you should test behaviors.

But what is a behavior? Well, to answer this question, we have to get a little bit more technical. 

Let's consider an object that is a part of an app you wrote. It has an interface that defines its methods and dependencies. These methods and these dependencies declare *contract* of your object. They define how it should interact with the rest of your application and what capabilities and functionalities it has. They define its *behavior*.

And that is what you should be aiming at: testing how your object behaves. 

## BDD DSL

Before we talk about benefits of BDD DSL, let's first go through its basics and see how a simple test suite for class `Car` looks:

    SpecBegin(Car)
        describe(@"Car", ^{
        
            __block Car *car;
        
            // Will be run before each enclosed it
            beforeEach(^{
                car = [Car new];
            });
            
            // Will be run after each enclosed it
            afterEach(^{
                car = nil;
            });
        
            // An actual test
            it(@"should be red", ^{
                expect(car.color).to.equal([UIColor redColor]);
            });
            
            describe(@"when it is started", ^{
            
                beforeEach(^{
                    [car start];
                });
            
                it(@"should have engine running", ^{
                    expect(car.engine.running).to.beTruthy();
                });
            });
            
            describe(@"move to", ^{
                
                context(@"when the engine is running", ^{
                
                    beforeEach(^{
                        car.engine.running = YES;
                        [car moveTo:CGPointMake(42,0)];
                    });
                    
                    it(@"should move to given position", ^{
                        expect(car.position).to.equal(CGPointMake(42, 0));
                    });
                });
            
                context(@"when the engine is not running", ^{
                
                    beforeEach(^{
                        car.engine.running = NO;
                        [car moveTo:CGPointMake(42,0)];
                    });
                    
                    it(@"should not move to given position", ^{
                        expect(car.position).to.equal(CGPointZero);
                    });
                });
            });
        });
    SpecEnd
    
`SpecBegin` declares a test class named `CarSpec`. `SpecEnd` closes that class declaration. 

The `describe` block declares a group of examples.

The `context` block behaves similarly to `describe` (syntax sugar).

`it` is a single example (a single test). 

`beforeEach` is a block that gets called before every block that is nested on the same level as or below it. 

As you probably noticed, nearly all components defined in this DSL consist of two parts: a string value that defines what is being tested, and a block that either has the test itself or more components. These strings have two very important functions.

First of all, in `describe` blocks, these strings group behaviors that are tied to a certain part of tested functionality (for instance, moving a car). Since you can specify as many nested blocks as you wish, you can write different specifications based on contexts in which the object or its dependencies are. 

That is exactly what happens in the `move to:` `describe` block: we created two `context` blocks to provide different expectations based on different states (engine either running or not) in which `Car` could be. This is an example of how BDD DSL encourages the defining of *clear* requirements of how the given object should behave in the given conditions. 

Second of all, these strings are used to create sentences that inform you which test failed. For instance, let's assume that our test for moving with engine not started failed. We would then receive the `Car move to when engine is not running should not move to given position` error message. These sentences really help us with *understanding* what has failed and what was the expected behavior, without actually reading any code, and thus they minimize cognitive load. Moreover, they provide a standard language that is easily understandable by each member of your team, including those who are less technical. 

Remember that you can also write tests with clear requirements and understandable names without BDD-style syntax (XCtest for instance). However, BDD has been built from the ground up with these capabilities in mind and it provides syntax and functionality that will make such an approach easier.
    
If you wish to learn more about BDD syntax, you should check out the [Specta guide for writing specs](https://github.com/specta/specta#writing-specs).

### BDD Frameworks

As an iOS or Mac developer, you can choose from a variety of BDD frameworks:

* [Cedar](https://github.com/pivotal/cedar)
* [Kiwi](https://github.com/kiwi-bdd/Kiwi)
* [Specta](https://github.com/specta/specta)
 
When it comes to syntax, all these frameworks are nearly the same. The main difference between them lies in their configurability and bundled components. 

**Cedar** comes bundled with [matchers](https://github.com/pivotal/cedar/wiki/Writing-specs#matchers) and [doubles](https://github.com/pivotal/cedar/wiki/Writing-specs#doubles). Though it's not exactly true, for the sake of this article, let's consider doubles as mocks (you can learn the difference between mocks and doubles [here](/issue-15/mocking-stubbing.html)). 

Apart from these helpers, Cedar has an additional configuration feature: focusing tests. Focusing tests means that Cedar will execute only a specific test or a test group. Focusing can be achieved by adding an `f` before the `it`, `describe`, or `context` block. 

There's an opposite configuration capability: you can `x`' a test to turn it off. XCTest has similar configuration capabilities, however, they are achieved by operating on schemes (or by manually pressing "Run this test"). Cedar configuration capabilities are simpler and faster to configure.

Cedar uses a bit of hackery when it comes to integration with XCTest, and thus it's prone to breaking, should Apple decide to change some of its internal implementation. However, from a user perspective, Cedar will work just as if it was integrated with XCTest.

**Kiwi** also comes bundled with [matchers](https://github.com/kiwi-bdd/Kiwi/wiki/Expectations), as well as [stubs and mocks](https://github.com/kiwi-bdd/Kiwi/wiki/Mocks-and-Stubs). Unlike Cedar, Kiwi is tightly integrated with XCTest, however, it lacks the configuration capabilities available in Cedar. 

**Specta** offers a different approach when it comes to testing tools, as it does not come bundled with any matchers, mocks, or stubs. It does, however, offer a separate library `Expecta` that provides a variety of matchers. 

Specta is tightly integrated with XCTest and offers configuration capabilities similar to Cedar - focusing and x'ing tests. 

As mentioned before, Cedar, Kiwi, and Specta offer similar syntax. I would not say that there is a framework that is better than all the others; they all have their small pros and cons. Choosing a BDD framework to work with comes down to personal preference. 

It is also worth mentioning that there are already two BDD frameworks that are dedicated to Swift:

* [Quick](https://github.com/Quick/Quick)
* [Sleipnir](https://github.com/railsware/Sleipnir)

## Examples

There's one last thing I'd like to point out before we move to examples. Remember that one of the key aspects of writing good behavioral tests is identifying dependencies (you can read more on this subject [here](/issue-15/dependency-injection.html)) and exposing them in your interface. 

Most of your tests will assert either whether a specific interaction happened, or whether a specific value was returned (or passed to another object), based on your tested object state. Extracting dependencies will allow you to easily mock values and states. Moreover, it will greatly simplify asserting whether a specific action happened or a specific value was calculated.

Keep in mind that you shouldn't put *all* of your object dependencies and properties in the interface (which, especially when you start testing, is really tempting). This will decrease the readability and clarity of purpose of your object, whereas your interface should clearly state what it was designed for. 

#### Message Formatter

Let's start with a simple example. We'll build a component that is responsible for formatting a text message for a given event object: 

    @interface EventDescriptionFormatter : NSObject
    @property(nonatomic, strong) NSDateFormatter *dateFormatter;
    
    - (NSString *)eventDescriptionFromEvent:(id <Event>)event;
    
    @end

This is how our interface looks. The event protocol defines three basic properties of an event:

    @protocol Event <NSObject>
    
    @property(nonatomic, readonly) NSString *name;
    
    @property(nonatomic, readonly) NSDate *startDate;
    @property(nonatomic, readonly) NSDate *endDate;
    
    @end

Our goal is to test whether `EventDescriptionFormatter` returns a formatted description that looks like `My Event starts at Aug 21, 2014, 12:00 AM and ends at Aug 21, 2014, 1:00 AM.` 

Please note that this (and all other examples in this article) use mocking frameworks. If you've never used a mocking framework before, you should consult [this article](/issue-15/mocking-stubbing.html).

We'll start by mocking our only dependency in the component, which is the date formatter. We'll use the created mock to return fixture strings for the start and end dates. Then we'll check whether the string returned from the event formatter is constructed using the values that we have just mocked: 

    __block id mockDateFormatter;
    __block NSString *eventDescription;
    __block id mockEvent;

    beforeEach(^{
        // Prepare mock date formatter
        mockDateFormatter = mock([NSDateFormatter class]);
        descriptionFormatter.dateFormatter = mockDateFormatter;

        NSDate *startDate = [NSDate mt_dateFromYear:2014 month:8 day:21];
        NSDate *endDate = [startDate mt_dateHoursAfter:1];

        // Pepare mock event
        mockEvent = mockProtocol(@protocol(Event));
        [given([mockEvent name]) willReturn:@"Fixture Name"];
        [given([mockEvent startDate]) willReturn:startDate];
        [given([mockEvent endDate]) willReturn:endDate];

        [given([mockDateFormatter stringFromDate:startDate]) willReturn:@"Fixture String 1"];
        [given([mockDateFormatter stringFromDate:endDate]) willReturn:@"Fixture String 2"];

        eventDescription = [descriptionFormatter eventDescriptionFromEvent:mockEvent];
    });

    it(@"should return formatted description", ^{
        expect(eventDescription).to.equal(@"Fixture Name starts at Fixture String 1 and ends at Fixture String 2.");
    });
        
Note that we have only tested whether our `EventDescriptionFormatter` uses its `NSDateFormatter` for formatting the dates. We haven't actually tested the format style. Thus, to have a fully tested component, we need to add two more tests that check format style:

    it(@"should have appropriate date style on date formatter", ^{
        expect(descriptionFormatter.dateFormatter.dateStyle).to.equal(NSDateFormatterMediumStyle);
    });

    it(@"should have appropriate time style on date formatter", ^{
        expect(descriptionFormatter.dateFormatter.timeStyle).to.equal(NSDateFormatterMediumStyle);
    });
    
Even though we have a fully tested component, we wrote quite a few tests. And this is a really small component, isn't it? Let's try approaching this issue from a slightly different angle.

The example above doesn't exactly test *behavior* of `EventDescriptionFormatter`. It mostly tests its internal implementation by mocking the `NSDateFormatter`. In fact, we don't actually care whether there's a date formatter underneath at all. From an interface perspective, we could've been formatting the date manually by using date components. All we care about at this point is whether we got our string right. And that is the behavior that we want to test.

We can easily achieve this by not mocking the `NSDateFormatter`. As said before, we don't even care whether its there, so let's actually remove it from the interface: 

    @interface EventDescriptionFormatter : NSObject
    
    - (NSString *)eventDescriptionFromEvent:(id <Event>)event;
    
    @end
    
The next step is, of course, refactoring our tests. Now that we no longer need to know the internals of the event formatter, we can focus on the actual behavior:

    describe(@"event description from event", ^{

        __block NSString *eventDescription;
        __block id mockEvent;
        
        beforeEach(^{
            NSDate *startDate = [NSDate mt_dateFromYear:2014 month:8 day:21];
            NSDate *endDate = [startDate mt_dateHoursAfter:1];
            
            mockEvent = mockProtocol(@protocol(Event));
            [given([mockEvent name]) willReturn:@"Fixture Name"];
            [given([mockEvent startDate]) willReturn:startDate];
            [given([mockEvent endDate]) willReturn:endDate];
        
            eventDescription = [descriptionFormatter eventDescriptionFromEvent:mockEvent];
        });
        
        it(@"should return formatted description", ^{
            expect(eventDescription).to.equal(@"Fixture Name starts at Aug 21, 2014, 12:00 AM and ends at Aug 21, 2014, 1:00 AM.");
        });
    });

Note how simple our test has become. We only have a minimalistic setup block where we prepare a data model and call a tested method. By focusing more on the result of behavior, rather than the way it actually works, we have simplified our test suite while still retaining functional test coverage of our object. This is exactly what BDD is about—trying to think about results of behaviors, and not the actual implementation.

#### Data Downloader

In this example, we will build a simple data downloader. We will specifically focus on one single behavior of our data downloader: making a request and canceling the download. Let's start with defining our interface:

    @interface CalendarDataDownloader : NSObject
    
    @property(nonatomic, weak) id <CalendarDataDownloaderDelegate> delegate;
    
    @property(nonatomic, readonly) NetworkLayer *networkLayer;
    
    - (instancetype)initWithNetworkLayer:(NetworkLayer *)networkLayer;
    
    - (void)updateCalendarData;
    
    - (void)cancel;
    
    @end
    
And of course, the interface for our network layer: 

    @interface NetworkLayer : NSObject
    
    // Returns an identifier that can be used for canceling a request.
    - (id)makeRequest:(id <NetworkRequest>)request completion:(void (^)(id <NetworkRequest>, id, NSError *))completion;
    
    - (void)cancelRequestWithIdentifier:(id)identifier;
    
    @end

We will first check whether the actual download took place. The mock network layer has been created and injected in a `describe` block above: 

    describe(@"update calendar data", ^{
        beforeEach(^{
            [calendarDataDownloader updateCalendarData];
        });

        it(@"should make a download data request", ^{
            [verify(mockNetworkLayer) makeRequest:instanceOf([CalendarDataRequest class]) completion:anything()];
        });
    });
    
This part was pretty simple. The next step is to check whether that request was canceled when we called the cancel method. We need to make sure we don't call the cancel method with no identifier. Specifications for such behavior can look like this:

    describe(@"cancel ", ^{
        context(@"when there's an identifier", ^{
            beforeEach(^{
                calendarDataDownloader.identifier = @"Fixture Identifier";
                [calendarDataDownloader cancel];
            });

            it(@"should tell the network layer to cancel request", ^{
                [verify(mockNetworkLayer) cancelRequestWithIdentifier:@"Fixture Identifier"];
            });

            it(@"should remove the identifier", ^{
                expect(calendarDataDownloader.identifier).to.beNil();
            });
        });

        context(@"when there's no identifier", ^{
            beforeEach(^{
                calendarDataDownloader.identifier = nil;
                [calendarDataDownloader cancel];
            });

            it(@"should not ask the network layer to cancel request", ^{
                [verifyCount(mockNetworkLayer, never()) cancelRequestWithIdentifier:anything()];
            });
        });
    });
    
The request identifier is a private property of `CalendarDataDownloader`, so we will need to expose it in our tests:

    @interface CalendarDataDownloader (Specs)
    @property(nonatomic, strong) id identifier;
    @end
    
You can probably gauge that there's something wrong with these tests. Even though they are valid and they check for specific behavior, they expose the internal workings of our `CalendarDataDownloader`. There's no need for our tests to have knowledge of how the `CalendarDataDownloader` holds its request identifier. Let's see how we can write our tests without exposing internal implementation:

    describe(@"update calendar data", ^{
        beforeEach(^{
            [given([mockNetworkLayer makeRequest:instanceOf([CalendarDataRequest class])
                                      completion:anything()]) willReturn:@"Fixture Identifier"];
            [calendarDataDownloader updateCalendarData];
        });

        it(@"should make a download data request", ^{
            [verify(mockNetworkLayer) makeRequest:instanceOf([CalendarDataRequest class]) completion:anything()];
        });

        describe(@"canceling request", ^{
            beforeEach(^{
                [calendarDataDownloader cancel];
            });

            it(@"should tell the network layer to cancel previous request", ^{
                [verify(mockNetworkLayer) cancelRequestWithIdentifier:@"Fixture Identifier"];
            });

            describe(@"canceling it again", ^{
                beforeEach(^{
                    [calendarDataDownloader cancel];
                });

                it(@"should tell the network layer to cancel previous request", ^{
                    [verify(mockNetworkLayer) cancelRequestWithIdentifier:@"Fixture Identifier"];
                });
            });
        });
    });
    
We started by stubbing the `makeRequest:completion:` method. We returned a fixture identifier. In the same `describe` block, we defined a cancel `describe` block, which calls the `cancel` method on our `CalendarDataDownloader` object. We then check out whether the fixture string was passed to our mocked network layer `cancelRequestWithIdentifier:` method. 

Note that, at this point, we don't actually need a test that checks whether the network request was made—we would not get an identifier and the `cancelRequestWithIdentifier:` would never be called. However, we retained that test to make sure we know what happened should that functionality break.

We've managed to test the exact same behavior without exposing the internal implementation of `CalendarDataDownloader`. Moreover, we've done so with only three tests instead of four. And we've leveraged BDD DSL nesting capabilities to chain simulation of behaviors—we first simulated the download, and then, in the same `describe` block, we simulated the canceling of a request. 

### Testing View Controllers

It seems that the most common attitude to testing view controllers among iOS developers is that people don't see value in it—which I find odd, as controllers often represent the core aspect of an application. They are the place where all components are glued together. They are the place that connects the user interface with the application logic and model. As a result, damage caused by an involuntary change can be substantial. 

This is why I strongly believe that view controllers should be tested as well. However, testing view controllers is not an easy task. The following upload photo and sign-in view controller examples should help with understanding how BDD can be leveraged to simplify building test suites for view controllers.

#### Upload Photo View Controller

In this example, we will build a simple photo uploader view controller with a send button as `rightBarButtonItem`. After the button is pressed, the view controller will inform its photo uploader component that a photo should be uploaded. 

Simple, right? Let's start with the interface of `PhotoUploaderViewController`:

    @interface PhotoUploadViewController : UIViewController
    @property(nonatomic, readonly) PhotoUploader *photoUploader;
    
    - (instancetype)initWithPhotoUploader:(PhotoUploader *)photoUploader;
    
    @end
    
There's not much happening here, as we're only defining an external dependency on `PhotoUploader`. Our implementation is also pretty simple. For the sake of simplicity, we won't actually grab a photo from anywhere; we'll just create an empty `UIImage`: 

    @implementation PhotoUploadViewController
    
    - (instancetype)initWithPhotoUploader:(PhotoUploader *)photoUploader {
        self = [super init];
        if (self) {
            _photoUploader = photoUploader;
    
            self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Upload", nil) style:UIBarButtonItemStyleBordered target:self action:@selector(didTapUploadButton:)];
        }
    
        return self;
    }
    
    #pragma mark -
    
    - (void)didTapUploadButton:(UIBarButtonItem *)uploadButton {
        void (^completion)(NSError *) = ^(NSError* error){};
        [self.photoUploader uploadPhoto:[UIImage new] completion:completion];
    }
    
    @end

Let's see how we could test this component. First of all, we'll need to check whether our bar button item is properly set up by asserting that the title, target, and action have been properly initialized: 

    describe(@"right bar button item", ^{

        __block UIBarButtonItem *barButtonItem;

        beforeEach(^{
            barButtonItem = [[photoUploadViewController navigationItem] rightBarButtonItem];
        });

        it(@"should have a title", ^{
            expect(barButtonItem.title).to.equal(@"Upload");
        });

        it(@"should have a target", ^{
            expect(barButtonItem.target).to.equal(photoUploadViewController);
        });

        it(@"should have an action", ^{
            expect(barButtonItem.action).to.equal(@selector(didTapUploadButton:));
        });
    });
    
But this is only half of what actually needs to be tested—we are now sure that the appropriate method will be called when the button is pressed, but we're not sure whether the appropriate action will be taken (in fact, we don't even know whether that method actually exists). So let's test that as well:

    describe(@"tapping right bar button item", ^{
        beforeEach(^{
            [photoUploadViewController didTapUploadButton:nil];
        });

        it(@"should tell the mock photo uploader to upload the photo", ^{
            [verify(mockPhotoUploader) uploadPhoto:instanceOf([UIImage class])
                                        completion:anything()];
        });
    });

Unfortunately for us, the `didTapUploadButton:` is not visible in the interface. We can work around this issue by defining a category visible in our tests that exposes this method:

    @interface PhotoUploadViewController (Specs)
    - (void)didTapUploadButton:(UIBarButtonItem *)uploadButton;
    @end
    
At this point, we can say that `PhotoUploadViewController` is fully tested. 

But what is wrong with the example above? The problem is that we are testing the internal implementation of `PhotoUploadViewController`. We shouldn't actually *care* what the target/action values on the bar button item are. We should only care about what happens when it is pressed. Everything else is an implementation detail.

Let's go back to our `PhotoUploadViewController` and see how we could rewrite our tests to make sure we're testing our interface, and not implementation.

First of all, we don't need to know that the `didTapUploadButton:` method exists at all. It is just an implementation detail. We care only for the behavior: when the user taps the upload button, the `UploadManager` should receive an `uploadPhoto:` message. This is great, as it means we don't really need our `Specs` category on `PhotoUploadViewController`. 

Second of all, we don't need to know what target/action is defined on our `rightBarButtonItem`. Our *only* concern is what happens when it is tapped. Let's simulate that action in tests. We can use a helper category on `UIBarButtonItem` to do this:

    @interface UIBarButtonItem (Specs)
    
    - (void)specsSimulateTap;
    
    @end
    
Its implementation is pretty simple, as we're performing `action` on the `target` of the `UIBarButtonItem`:

    @implementation UIBarButtonItem (Specs)
    
    - (void)specsSimulateTap {
        [self.target performSelector:self.action withObject:self];
    }
    
    @end

Now that we have a helper method that simulates a tap, we can simplify our tests to one top-level `describe` block:

    describe(@"right bar button item", ^{

        __block UIBarButtonItem *barButtonItem;

        beforeEach(^{
            barButtonItem = [[photoUploadViewController navigationItem] rightBarButtonItem];
        });

        it(@"should have a title", ^{
            expect(barButtonItem.title).to.equal(@"Upload");
        });

        describe(@"when it is tapped", ^{
            beforeEach(^{
                [barButtonItem specsSimulateTap];
            });

            it(@"should tell the mock photo uploader to upload the photo", ^{
                [verify(mockPhotoUploader) uploadPhoto:instanceOf([UIImage class])
                                            completion:anything()];
            });
        });
    });

Note that we have managed to remove two tests and we still have a fully tested component. Moreover, our test suite is less prone to breaking, as we no longer rely on the existence of the `didTapUploadButton:` method. Last but not least, we have focused more on the behavioral aspect of our controller, rather than its internal implementation.

#### Sign-In View Controller

In this example, we will build a simple app that requires users to enter their username and password in order to sign in to an abstract service.  

We will start out by building a `SignInViewController` with two text fields and a sign-in button. We want to keep our controller as small as possible, so we will abstract a class responsible for signing in to a separate component called `SignInManager`. 
    
Our requirements are as follows: when the user presses our sign-in button, and when the username and password are present, our view controller will tell its sign-in manager to perform the sign in with the password and username. If there is no username or password (or both are gone), the app will show an error label above text fields. 

The first thing that we will want to test is the view part:

    @interface SignInViewController : UIViewController
    
    @property(nonatomic, readwrite) IBOutlet UIButton *signInButton;
    
    @property(nonatomic, readwrite) IBOutlet UITextField *usernameTextField;
    @property(nonatomic, readwrite) IBOutlet UITextField *passwordTextField;
    
    @property(nonatomic, readwrite) IBOutlet UILabel *fillInBothFieldsLabel;
    
    @property(nonatomic, readonly) SignInManager *signInManager;
    
    - (instancetype)initWithSignInManager:(SignInManager *)signInManager;
    
    - (IBAction)didTapSignInButton:(UIButton *)signInButton;
    
    @end
    
First, we will check some basic information about our text fields:

        beforeEach(^{
            // Force view load from xib
            [signInViewController view];
        });

        it(@"should have a placeholder on user name text field", ^{
            expect(signInViewController.usernameTextField.placeholder).to.equal(@"Username");
        });

        it(@"should have a placeholder on password text field", ^{
             expect(signInViewController.passwordTextField.placeholder).to.equal(@"Password");
        });
        
Next, we will check whether the sign-in button is correctly configured and has it actions wired:

        describe(@"sign in button", ^{

            __block UIButton *button;

            beforeEach(^{
                button = signInViewController.signInButton;
            });

            it(@"should have a title", ^{
                expect(button.currentTitle).to.equal(@"Sign In");
            });

            it(@"should have sign in view controller as only target", ^{
                expect(button.allTargets).to.equal([NSSet setWithObject:signInViewController]);
            });

            it(@"should have the sign in action as action for login view controller target", ^{
                NSString *selectorString = NSStringFromSelector(@selector(didTapSignInButton:));
                expect([button actionsForTarget:signInViewController forControlEvent:UIControlEventTouchUpInside]).to.equal(@[selectorString]);
            });
        });
        
And last but not least, we will check how our controller behaves when the button is tapped:

    describe(@"tapping the logging button", ^{
         context(@"when login and password are present", ^{

             beforeEach(^{
                 signInViewController.usernameTextField.text = @"Fixture Username";
                 signInViewController.passwordTextField.text = @"Fixture Password";

                 // Make sure state is different than the one expected
                 signInViewController.fillInBothFieldsLabel.alpha = 1.0f;

                 [signInViewController didTapSignInButton:nil];
             });

             it(@"should tell the sign in manager to sign in with given username and password", ^{
                 [verify(mockSignInManager) signInWithUsername:@"Fixture Username" password:@"Fixture Password"];
             });
         });

         context(@"when login or password are not present", ^{
             beforeEach(^{
                 signInViewController.usernameTextField.text = @"Fixture Username";
                 signInViewController.passwordTextField.text = nil;

                 [signInViewController didTapSignInButton:nil];
             });

             it(@"should not tell the sign in manager to sign in", ^{
                 [verifyCount(mockSignInManager, never()) signInWithUsername:anything() password:anything()];
             });
         });

         context(@"when neither login or password are present", ^{
             beforeEach(^{
                 signInViewController.usernameTextField.text = nil;
                 signInViewController.passwordTextField.text = nil;

                 [signInViewController didTapSignInButton:nil];
             });

             it(@"should not tell the sign in manager to sign in", ^{
                 [verifyCount(mockSignInManager, never()) signInWithUsername:anything() password:anything()];
             });
         });
     });

The code presented in the example above has quite a few issues. First of all, we've exposed a lot of internal implementation of `SignInViewController`, including buttons, text fields, and methods. The truth is that we didn't really need to do all of this. 

Let's see how we can refactor these tests to make sure we are not touching internal implementation. We will start by removing the need to actually know what target and method are hooked to the sign-in button:

    @interface UIButton (Specs)
    
    - (void)specsSimulateTap;
    
    @end
    
    @implementation UIButton (Specs)
    
    - (void)specsSimulateTap {
        [self sendActionsForControlEvents:UIControlEventTouchUpInside];
    }
    
    @end

Now we can just call this method on our button and assert whether the sign-in manager received the appropriate message. But we can still improve how this test is written. 

Let's assume that we do not want to know who has the sign-in button. Perhaps it is a direct subview of the view controller's view. Or perhaps we encapsulated it within a separate view that has its own delegate. We shouldn't actually care where it is; we should only care about whether it is somewhere within our view controller's view and what happens when it is tapped. We can use a helper method to grab the sign-in button, no matter where it is:

    @interface UIView (Specs)
    
    - (UIButton *)specsFindButtonWithTitle:(NSString *)title;
    
    @end
    
Our method will traverse subviews of the view and return the first button that has a title that matches the title argument. We can write similar methods for text fields or labels:

    @interface UIView (Specs)
    
    - (UITextField *)specsFindTextFieldWithPlaceholder:(NSString *)placeholder;
    - (UILabel *)specsFindLabelWithText:(NSString *)text;
    
    @end
    
Let's see how our tests look now:

    describe(@"view", ^{

        __block UIView *view;
        
        beforeEach(^{
            view = [signInViewController view];
        });

        describe(@"login button", ^{

            __block UITextField *usernameTextField;
            __block UITextField *passwordTextField;
            __block UIButton *signInButton;

            beforeEach(^{
                signInButton = [view specsFindButtonWithTitle:@"Sign In"];
                usernameTextField = [view specsFindTextFieldWithPlaceholder:@"Username"];
                passwordTextField = [view specsFindTextFieldWithPlaceholder:@"Password"];
            });

            context(@"when login and password are present", ^{
                beforeEach(^{
                    usernameTextField.text = @"Fixture Username";
                    passwordTextField.text = @"Fixture Password";

                    [signInButton specsSimulateTap];
                });

                it(@"should tell the sign in manager to sign in with given username and password", ^{
                    [verify(mockSignInManager) signInWithUsername:@"Fixture Username" password:@"Fixture Password"];
                });
            });

            context(@"when login or password are not present", ^{
                beforeEach(^{
                    usernameTextField.text = @"Fixture Username";
                    passwordTextField.text = nil;

                    [signInButton specsSimulateTap];
                });

                it(@"should not tell the sign in manager to sign in", ^{
                    [verifyCount(mockSignInManager, never()) signInWithUsername:anything() password:anything()];
                });
            });

            context(@"when neither login or password are present", ^{
                beforeEach(^{
                    usernameTextField.text = nil;
                    passwordTextField.text = nil;

                    [signInButton specsSimulateTap];
                });

                it(@"should not tell the sign in manager to sign in", ^{
                    [verifyCount(mockSignInManager, never()) signInWithUsername:anything() password:anything()];
                });
            });
        });
    });
    
Looks much simpler, doesn't it? Note that by looking for a button with "Sign In" as the title, we also tested whether such a button exists at all. Moreover, by simulating a tap, we tested whether the action is correctly hooked up. And in the end, by asserting that our `SignInManager` should be called, we tested whether or not that part is correctly implemented—all of this using three simple tests.

What is also great is that we no longer need to expose any of those properties. As a matter of fact, our interface could be as simple as this:

    @interface SignInViewController : UIViewController
    
    @property(nonatomic, readonly) SignInManager *signInManager;
    
    - (instancetype)initWithSignInManager:(SignInManager *)signInManager;
    
    @end
    
In these tests, we have leveraged the capabilities of BDD DSL. Note how we used `context` blocks to define different requirements for how `SignInViewController` should behave, based on its text fields state. This is a great example of how you can use BDD to make your tests simpler and more readable while retaining their functionality.

## Conclusion

Behavior-driven development is not as hard as it might initially look. All you need to do is change your mindset a bit—think more of how an object should behave (and how its interface should look) and less of how it should be implemented. By doing so, you will end up with a more robust codebase, along with a great test suite. Moreover, your tests will become less prone to breaking during refactors, and they will focus on testing the contract of your object rather than its internal implementation.

And with the great tools provided by the iOS community, you should be able to start BDDing your apps in no time. Now that you know *what* to test, there's really no excuse, is there?

### Links

If you're interested in the roots of BDD and how it came to be, you should definitely read [this article](http://dannorth.net/introducing-bdd/).
For those of you who understand TDD, but don't exactly know how this differs from TDD, I recommend [this article](http://blog.mattwynne.net/2012/11/20/tdd-vs-bdd/).
Last but not least, you can find an example project with the tests presented above [here](https://github.com/objcio/issue-15-bdd).

