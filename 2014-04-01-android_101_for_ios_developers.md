---
title:  "Android 101 for iOS Developers"
category: "11"
date: "2014-04-01 11:00:00"
tags: article
author: "<a href=\"https://twitter.com/smbarne\">Stephen Barnes</a>"
---


As the mobile software industry evolves, it is becoming increasingly impractical to target only iOS for a mobile product. Android market share is approaching 80 percent for smartphones,[^1] and the number of potential users that it can bring to a product can hardly be ignored.

In this article, I will introduce the core concepts of Android development within the context of iOS development. Android and iOS work on similar problem sets, but they approach many of these problems in different ways. Throughout the article, I will be using a companion project (available on [GitHub](https://github.com/objcio/issue-11-android-101)) to illustrate how to accomplish the same tasks when developing for both platforms.

In addition to a working knowledge of iOS development, I assume that you have a working knowledge of Java and are able to install and use the [Android Development Tools](http://developer.android.com/tools/index.html). Furthermore, if you are new to Android development, reading through the tutorial by Google about [building your first app](http://developer.android.com/training/basics/firstapp/index.html) could be very helpful.

### A Brief Word on UI Design

This article will not delve deeply into the user experience and design pattern differences between iOS and Android. However, it would be beneficial to understand some of the key UI paradigms in use on Android today: the action bar, the overflow menu, the back button, the share action, and more. If you are seriously considering Android development, I highly recommending looking into the [Nexus 5](https://play.google.com/store/devices/details?id=nexus_5_white_16gb) from the Google Play Store. Make it your full-time device for a week and force yourself to try the operating system to its fullest extent. A developer who doesn't know the key use patterns of his or her operating system is a liability to the product.

## Language Application Structure 

### Java

There are many differences between Objective-C and Java, and while it may be tempting to bring some of Objective-C's styling into Java, it can lead to a codebase that heavily clashes with the primary framework that drives it. In brief, here are a few gotchas to watch for:


- Leave class prefixes at home on Objective-C. Java has actual namespacing and package management, so there is no need for class prefixes here.
- Instance variables are prefixed with `m`, not `_`.
   - Take advantage of JavaDoc to write method and class descriptions for as much of your code as possible. It will make your life and the lives of others better.
- Null check! Objective-C gracefully handles message sending to nil objects, but Java does not.
- Say goodbye to properties. If you want setters and getters, you have to remember to actually create a getVariableName() method and call it explicitly. Referencing `this.object` will **not** call your custom getter. You must use `this.getObject`.
- Similarly, prefix method names with `get` and `set` to indicate getters and setters. Java methods are typically written as actions or queries, such as `getCell()`, instead of `cellForRowAtIndexPath:`.
   
### Project Structure

Android applications are primarily broken into two sections, the first of which is the Java source code. The source code is structured via the Java package hierarchy, and it can be structured as you please. However, a common practice is to use top-level categories for activities, fragments, views, adapters, and data (models and managers).

The second major section is the `res` folder, short for 'resource' folder. The `res` folder is a collection of images, XML layout files, and XML value files that make up the bulk of the non-code assets. On iOS, images are either `@2x` or not, but on Android there are a number of screen density folders to consider.[^2] Android uses folders to arrange images, strings, and other values for screen density. The `res` folder also contains XML layout files that can be thought of as `xib` files. Lastly, there are other XML files that store resources for string, integer, and style resources.

One last correlation in project structure is the `AndroidManifest.xml` file. This file is the equivalent of the `Project-Info.plist` file on iOS, and it stores information for activities, application names, and set Intents[^3] (system-level events) that the application can handle.
 For more information about Intents, keep on reading, or head over to the [Intents](/issue-11/android-intents.html) article.

## Activities

Activities are the basic visual unit of an Android app, just as `UIViewControllers` are the basic visual component on iOS. Instead of a `UINavigationController`, the Android OS keeps an activity stack that it manages. When an app is launched, the OS pushes the app's main activity onto the stack. Note that you can launch other apps' activities and have them placed onto the stack. By default, the back button on Android pops from the OS activity stack, so when a user presses back, he or she can go through multiple apps that have been launched.


Activities can also initialize other activities with [Intents](http://developer.android.com/reference/android/content/Intent.html) that contain extra data.  Starting Activities with Intents is somewhat similar to creating a new `UIViewController` with a custom `init` method. Because the most common way to launch new activities is to create an Intent with data, a great way to expose custom initializers on Android is to create static Intent getter methods. Activities can also return results when finished (goodbye modal delegates!) by placing extra data on an Intent when the activity is finished.

One large difference between Android apps and iOS apps is that any activity can be an entrance point into your application if it registers correctly in the `AndroidManifest` file. Setting an Intent filter in the AndroidManifest.xml file for a `media intent` on an activity effectively states to the OS that this activity is able to be launched as an entry point with media data inside of the Intent. A good example might be a photo-editing activity that opens a photo, modifies it, and returns the modified image when the activity finishes.

As a side note, model objects must implement the `Parcelable` interface if you want to send them between activities and fragments. Implementing the `Parcelable` interface is similar to conforming to the `<NSCopying>` protocol on iOS. Also note that `Parcelable` objects are able to be stored in an activity's or fragment's savedInstanceState, in order to more easily restore their states after they have been destroyed.

Let's next look at one activity launching another activity, and also responding to when the second activity finishes.

### Launching Another Activity for a Result

    // A request code is a unique value for returning activities
    private static final int REQUEST_CODE_NEXT_ACTIVITY = 1234;
    
    protected void startNextActivity() {
        // Intents need a context, so give this current activity as the context
        Intent nextActivityIntent = new Intent(this, NextActivity.class);
           startActivityForResult(nextActivityResult, REQUEST_CODE_NEXT_ACTIVITY);
    }
    
    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        switch (requestCode) {
        case REQUEST_CODE_NEXT_ACTIVITY:
            if (resultCode == RESULT_OK) {
                // This means our Activity returned successfully. For now, Toast this text.  
                // This just creates a simple pop-up message on the screen.
                    Toast.makeText(this, "Result OK!", Toast.LENGTH_SHORT).show();
                }
                return;
            }    
            super.onActivityResult(requestCode, resultCode, data);
    }

### Returning a Result on Activity Finish()

    public static final String activityResultString = "activityResultString";
    
    /*
     * On completion, place the object ID in the intent and finish with OK.
     * @param returnObject that was processed
     */
    private void onActivityResult(Object returnObject) {
            Intent data = new Intent();
            if (returnObject != null) {
                data.putExtra(activityResultString, returnObject.uniqueId);
            }
        
            setResult(RESULT_OK, data);
            finish();        
    }

## Fragments

The [Fragment](http://developer.android.com/guide/components/fragments.html) concept is unique to Android and came around somewhat recently in Android 3.0. Fragments are mini controllers that can be instantiated to fill activities. They store state information and may contain view logic, but there may be multiple fragments on the screen at the same time -- putting the activity in a fragment controller role. Also note that fragments do not have their own contexts and they rely heavily on activities for their connection to the application's state.

Tablets are a great fragment use case example: you can place a list fragment on the left and a detail fragment on the right.[^4] Fragments allow you to break up your UI and controller logic into smaller, reusable chunks. But beware! The fragment lifecycle, detailed below, is more nuanced.

<img alt="A multi-pane activity with two fragments" src="{{ site.images_path }}/issue-11/multipane_view_tablet.png">
 
Fragments are the new way of structuring apps on Android, just like `UICollectionView` is the new way of structuring list data instead of `UITableview` for iOS.[^5]  While it is initially easier to avoid using fragments and instead use nothing but activities, you could regret this decision later on. That said, resist the urge to give up on activities entirely by swapping fragments on a single activity -- this can leave you in a bind when wanting to take advantage of intents and using multiple fragments on the same activity.

Let's look at a sample `UITableViewController` and a sample `ListFragment` that show a list of prediction times for a subway trip, courtesy of the [MBTA](http://www.mbta.com/rider_tools/developers/default.asp?id=21898).

### Table View Controller Implementation

&nbsp;

<img alt="TripDetailsTableViewController" src="{{ site.images_path }}/issue-11/IMG_0095.PNG" width="50%">

&nbsp;

    @interface MBTASubwayTripTableTableViewController ()
    
    @property (assign, nonatomic) MBTATrip *trip;
    
    @end
    
    @implementation MBTASubwayTripTableTableViewController
    
    - (instancetype)initWithTrip:(MBTATrip *)trip
    {
        self = [super initWithStyle:UITableViewStylePlain];
        if (self) {
            _trip = trip;
            [self setTitle:trip.destination];
        }
        return self;
    }
    
    - (void)viewDidLoad
    {
        [super viewDidLoad];
        
        [self.tableView registerClass:[MBTAPredictionCell class] forCellReuseIdentifier:[MBTAPredictionCell reuseId]];
        [self.tableView registerNib:[UINib nibWithNibName:NSStringFromClass([MBTATripHeaderView class]) bundle:nil] forHeaderFooterViewReuseIdentifier:[MBTATripHeaderView reuseId]];
    }
    
    #pragma mark - UITableViewDataSource
    
    - (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
    {
        return 1;
    }
    
    - (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
    {
        return [self.trip.predictions count];
    }
    
    #pragma mark - UITableViewDelegate
    
    - (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
    {
        return [MBTATripHeaderView heightWithTrip:self.trip];
    }
    
    - (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
    {
        MBTATripHeaderView *headerView = [self.tableView dequeueReusableHeaderFooterViewWithIdentifier:[MBTATripHeaderView reuseId]];
        [headerView setFromTrip:self.trip];
        return headerView;
    }
    
    - (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[MBTAPredictionCell reuseId] forIndexPath:indexPath];
        
        MBTAPrediction *prediction = [self.trip.predictions objectAtIndex:indexPath.row];
        [(MBTAPredictionCell *)cell setFromPrediction:prediction];
        
        return cell;
    }
    
    - (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
    {
        return NO;
    }
    
    - (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
    {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    
    @end


### List Fragment Implementation

&nbsp;

<img alt="TripDetailFragment" src="{{ site.images_path }}/issue-11/Screenshot_2014-03-25-11-42-16.png" width="50%">

&nbsp;

    public class TripDetailFragment extends ListFragment {
    
        /**
         * The configuration flags for the Trip Detail Fragment.
         */
        public static final class TripDetailFragmentState {
            public static final String KEY_FRAGMENT_TRIP_DETAIL = "KEY_FRAGMENT_TRIP_DETAIL";
        }
    
        protected Trip mTrip;
    
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param trip the trip to show details
         * @return A new instance of fragment TripDetailFragment.
         */
        public static TripDetailFragment newInstance(Trip trip) {
            TripDetailFragment fragment = new TripDetailFragment();
            Bundle args = new Bundle();
            args.putParcelable(TripDetailFragmentState.KEY_FRAGMENT_TRIP_DETAIL, trip);
            fragment.setArguments(args);
            return fragment;
        }
    
        public TripDetailFragment() { }
    
        @Override
        public View onCreateView(LayoutInflater inflater, ViewGroup container,
                                 Bundle savedInstanceState) {
            Prediction[] predictions= mTrip.predictions.toArray(new Prediction[mTrip.predictions.size()]);
            PredictionArrayAdapter predictionArrayAdapter = new PredictionArrayAdapter(getActivity(), predictions);
            setListAdapter(predictionArrayAdapter);
            return super.onCreateView(inflater,container, savedInstanceState);
        }
    
        @Override
        public void onViewCreated(View view, Bundle savedInstanceState) {
            super.onViewCreated(view, savedInstanceState);
            TripDetailsView headerView = new TripDetailsView(getActivity());
            headerView.updateFromTripObject(mTrip);
            getListView().addHeaderView(headerView);
        }
    }

In the next section, let's decipher some of the unique Android components.

## Common Android Components

### List Views and Adapters

`ListViews` are the closest approximation to `UITableView` on Android, and they are one of the most common components that you will use. Just like `UITableView` has a helper view controller, `UITableViewController`, ListView also has a helper activity, `ListActivity`, and a helper fragment, `ListFragment`. Similar to `UITableViewController`, these helpers take care of the layout (similar to the xib) for you and provide convenience methods for managing adapters, which we'll discuss below. Our example above uses a `ListFragment` to display data from a list of `Prediction` model objects, similar to how the table view's datasource uses an array of `Prediction` model objects to populate the `UITableView`.

Speaking of datasources, on Android we don't have datasources and delegates for `ListView`. Instead, we have adapters. Adapters come in many forms, but their primary goal is similar to a datasource and table view delegate all in one. Adapters take data and adapt it to populate a `ListView` by instantiating views the `ListView` will display. Let's have a look at the array adapter used above:
     
    public class PredictionArrayAdapter extends ArrayAdapter<Prediction> {
    
        int LAYOUT_RESOURCE_ID = R.layout.view_three_item_list_view;
    
        public PredictionArrayAdapter(Context context) {
            super(context, R.layout.view_three_item_list_view);
        }
    
        public PredictionArrayAdapter(Context context, Prediction[] objects) {
            super(context, R.layout.view_three_item_list_view, objects);
        }
    
        @Override
        public View getView(int position, View convertView, ViewGroup parent)
        {
            Prediction prediction = this.getItem(position);
            View inflatedView = convertView;
            if(convertView==null)
            {
                LayoutInflater inflater = (LayoutInflater)getContext().getSystemService(Context.LAYOUT_INFLATER_SERVICE);
                inflatedView = inflater.inflate(LAYOUT_RESOURCE_ID, parent, false);
            }
    
            TextView stopNameTextView = (TextView)inflatedView.findViewById(R.id.view_three_item_list_view_left_text_view);
            TextView middleTextView = (TextView)inflatedView.findViewById(R.id.view_three_item_list_view_middle_text_view);
            TextView stopSecondsTextView = (TextView)inflatedView.findViewById(R.id.view_three_item_list_view_right_text_view);
    
            stopNameTextView.setText(prediction.stopName);
            middleTextView.setText("");
            stopSecondsTextView.setText(prediction.stopSeconds.toString());
    
            return inflatedView;
        }
    }

You'll note that the adapter has an important method named `getView`, which is very similar to `cellForRowAtIndexPath:`. Another similarity you'll notice is a pattern for reusing views, similar to iOS. Reusing views are just as important as on iOS, and this substantially helps performance! This adapter is rather simple, because it uses a built-in superclass, `ArrayAdapter<T>`, for adapters working with array data, but it illustrates how to populate a `ListView` from a dataset.
     
### AsyncTasks

In place of Grand Central Dispatch on iOS, on Android we have access to `AsyncTasks`. `AsyncTasks` is a different take on exposing asynchronous tools in a more friendly way. `AsyncTasks` is a bit out of scope for this article, but I highly recommend looking over some of the [documentation](http://developer.android.com/reference/android/os/AsyncTask.html).
 
## Activity Lifecycle

One of the primary things to watch out for coming from iOS development is the Android lifecycle. Let's start by looking at the [Activity Lifecycle Documentation](http://developer.android.com/training/basics/activity-lifecycle/index.html):

![Android Activity Lifecycle]({{ site.images_path }}/issue-11/Android-Activity-Lifecycle.png)

In essence, the activity lifecycle is very similar to the UIViewController lifecycle. The primary difference is that the Android OS can be ruthless with destroying activities, and it is very important to make sure that the data and the state of the activity are saved, so that they can be restored from the saved state if they exist in the `onCreate()`. The best way to do this is by using bundled data and restoring from the savedInstanceState and/or Intents. For example, here is the part of the `TripListActivity` from our sample project that is keeping track of the currently shown subway line:

 
    public static Intent getTripListActivityIntent(Context context, TripList.LineType lineType) {
        Intent intent = new Intent(context, TripListActivity.class);
        intent.putExtra(TripListActivityState.KEY_ACTIVITY_TRIP_LIST_LINE_TYPE, lineType.getLineName());
        return intent;
    }
    
    public static final class TripListActivityState {
        public static final String KEY_ACTIVITY_TRIP_LIST_LINE_TYPE = "KEY_ACTIVITY_TRIP_LIST_LINE_TYPE";
    }
        
    TripList.LineType mLineType;    
        
    @Override
    protected void onCreate(Bundle savedInstanceState) {
       super.onCreate(savedInstanceState);
       mLineType = TripList.LineType.getLineType(getIntent().getStringExtra(TripListActivityState.KEY_ACTIVITY_TRIP_LIST_LINE_TYPE));
    }    

A note on rotation: the lifecycle **completely** resets the view on rotation. That is, your activity will be destroyed and recreated when a rotation occurs. If data is properly saved in the saved instance state and the activity restores the state correctly after its creation, then the rotation will work seamlessly. Many app developers have issues with app stability when the app rotates, because an activity does not handle state changes properly. Beware! Do not lock your app's rotation to solve these issues, as this only hides the lifecycle bugs that will still occur at another point in time when the activity is destroyed by the OS.

## Fragment Lifecycle

The [Fragment Lifecycle](http://developer.android.com/training/basics/fragments/index.html) is similar to the activity lifecycle, with a few additions. 

![Android Fragment Lifecycle]({{ site.images_path }}/issue-11/fragment_lifecycle.png)

One of the problems that can catch developers off guard is regarding issues communicating between fragments and activities. Note that the `onAttach()` happens **before** `onActivityCreated()`. This means that the activity is not guaranteed to exist before the fragment is created. The `onActivityCreated()` method should be used when you set interfaces (delegates) to the parent activity, if needed.

Fragments are also created and destroyed aggressively by the needs of the operating system, and to keep their state, require the same amount of diligence as activities. Here is an example from our sample project, where the trip list fragment keeps track of the `TripList` data, as well as the subway line type:
 
    /**
     * The configuration flags for the Trip List Fragment.
     */
    public static final class TripListFragmentState {
        public static final String KEY_FRAGMENT_TRIP_LIST_LINE_TYPE = "KEY_FRAGMENT_TRIP_LIST_LINE_TYPE";
        public static final String KEY_FRAGMENT_TRIP_LIST_DATA = "KEY_FRAGMENT_TRIP_LIST_DATA";
    }
    
    /**
     * Use this factory method to create a new instance of
     * this fragment using the provided parameters.
     *
     * @param lineType the subway line to show trips for.
     * @return A new instance of fragment TripListFragment.
     */
    public static TripListFragment newInstance(TripList.LineType lineType) {
        TripListFragment fragment = new TripListFragment();
        Bundle args = new Bundle();
        args.putString(TripListFragmentState.KEY_FRAGMENT_TRIP_LIST_LINE_TYPE, lineType.getLineName());
        fragment.setArguments(args);
        return fragment;
    }
    
    protected TripList mTripList;
    protected void setTripList(TripList tripList) {
        Bundle arguments = this.getArguments();
        arguments.putParcelable(TripListFragmentState.KEY_FRAGMENT_TRIP_LIST_DATA, tripList);
        mTripList = tripList;
        if (mTripArrayAdapter != null) {
            mTripArrayAdapter.clear();
            mTripArrayAdapter.addAll(mTripList.trips);
        }
    }
    
    @Override
    public void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        if (getArguments() != null) {
            mLineType = TripList.LineType.getLineType(getArguments().getString(TripListFragmentState.KEY_FRAGMENT_TRIP_LIST_LINE_TYPE));
            mTripList = getArguments().getParcelable(TripListFragmentState.KEY_FRAGMENT_TRIP_LIST_DATA);
        }
    }    

Notice that the fragment always restores its state from the bundled arguments in `onCreate`, and that the custom setter for the `TripList` model object adds the object to the bundled arguments as well. This ensures that if the fragment is destroyed and recreated, such as when the device is rotated, the fragment always has the latest data to restore from.

## Layouts

Similar to other parts of Android development, there are pros and cons to specifying layouts in Android versus iOS. [Layouts](http://developer.android.com/guide/topics/ui/declaring-layout.html) are stored as human-readable XML files in the `res/layouts` folder.  


### Subway List View Layout

<img alt="Subway ListView" src="{{ site.images_path }}/issue-11/Screenshot_2014-03-24-13-12-00.png" width="50%">

    <RelativeLayout xmlns:android="http://schemas.android.com/apk/res/android"
        xmlns:tools="http://schemas.android.com/tools"
        android:layout_width="match_parent"
        android:layout_height="match_parent"
        tools:context="com.example.androidforios.app.activities.MainActivity$PlaceholderFragment">
    
        <ListView
            android:id="@+id/fragment_subway_list_listview"
            android:layout_width="match_parent"
            android:layout_height="match_parent"
            android:paddingBottom="@dimen/Button.Default.Height"/>
    
        <Button
            android:id="@+id/fragment_subway_list_Button"
            android:layout_width="match_parent"
            android:layout_height="@dimen/Button.Default.Height"
            android:minHeight="@dimen/Button.Default.Height"
            android:background="@drawable/button_red_selector"
            android:text="@string/hello_world"
            android:textColor="@color/Button.Text"
            android:layout_alignParentBottom="true"
            android:gravity="center"/>
    
    </RelativeLayout>

Here is the same view on iOS with a `UITableView` and a `UIButton` pinned to the bottom via Auto Layout in Interface Builder:

<img alt="iOS Subway Lines UIViewController" src="{{ site.images_path }}/issue-11/iOS_Screen1.png" width="50%">

![Interface Builder Constraints]({{ site.images_path }}/issue-11/iOSConstraints.png)

You'll notice that the Android layout file is much easier to **read** and understand what is going on. There are many parts to laying out views in Android, but we'll cover just a few of the important ones.

The primary structure that you will deal with will be subclasses of [ViewGroup](http://developer.android.com/reference/android/view/ViewGroup.html) -- [RelativeLayout](http://developer.android.com/reference/android/widget/RelativeLayout.html), [LinearLayout](http://developer.android.com/reference/android/widget/LinearLayout.html), and [FrameLayout](http://developer.android.com/reference/android/widget/FrameLayout.html) are the most common. These ViewGroups contain other views and expose properties to arrange them on screen.

A good example is the use of a `RelativeLayout` above. A relative layout allows us to use `android:layout_alignParentBottom="true"` in our layout above to pin the button to the bottom.

Lastly, to link layouts to fragments or activities, simply use that layout's resource ID during the `onCreateView`:
 
    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        return inflater.inflate(R.layout.fragment_subway_listview, container, false);
    }


### Layout Tips

- Always work in dp ([density-independent pixels](http://developer.android.com/training/multiscreen/screendensities.html)) instead of pixels directly.
- Don't bother nudging items for layouts in the visual editor -- often the visual editor will put individual points of spacing on objects instead of adjusting the height and width as you might like. Your best bet is to adjust the XML directly.
- If you ever see the `fill_parent` value for a layout height or width, this value was deprecated years ago in API 8 and replaced with `match_parent`.

See the the [responsive android applications](/issue-11/responsive-android-applications.html) article for more tips on this.
 

## Data

The [Data Storage Options](http://developer.android.com/guide/topics/data/data-storage.html) available on Android are also very similar to what is available on iOS:

 - [Shared Preferences](http://developer.android.com/guide/topics/data/data-storage.html#pref) <-> NSUserDefaults
 - In-memory objects
 - Saving to and fetching from file structure via the [internal](http://developer.android.com/guide/topics/data/data-storage.html#filesInternal) or [external](http://developer.android.com/guide/topics/data/data-storage.html#filesExternal) file storage <-> saving to the documents directory
 - [SQLite](http://developer.android.com/guide/topics/data/data-storage.html#db) <-> Core Data
 
The primary difference is the lack of Core Data. Instead, Android offers straight access to the SQLite database and returns [cursor](http://developer.android.com/reference/android/database/Cursor.html) objects for results. Head over to the article in this issue about [using SQLite on Android](/issue-11/sqlite-database-support-in-android.html) for more details.


## Android Homework

What we've discussed so far barely scratches the surface. To really take advantage of some of the things that make Android special, I recommend checking out some of these features:

 - [Action Bar, Overflow Menu, and the Menu Button](http://developer.android.com/guide/topics/ui/actionbar.html)
 - [Cross-App Data Sharing](https://developer.android.com/training/sharing/index.html)
 - [Respond to common OS actions](http://developer.android.com/guide/components/intents-common.html)
 - Take advantage of Java's features: generics, virtual methods and classes, etc.
 - [Google Compatibility Libraries](http://developer.android.com/tools/support-library/index.html)
 - The Android Emulator: install the [x86 HAXM plugin](http://software.intel.com/en-us/android/articles/intel-hardware-accelerated-execution-manager) to make the emulator buttery smooth.
 
## Final Words

Much of what was discussed in this article is implemented in the MBTA subway transit [sample project](https://github.com/objcio/issue-11-android-101) on GitHub. The project was built as a way to illustrate similar concepts such as application structure, handling data, and building UI on the same application for both platforms.

While some of the pure **implementation** details are very different on Android, it is very easy to bring problem-solving skills and patterns learned on iOS to bear. Who knows? Maybe understanding how Android works just a little bit better might prepare you for the next version of iOS.

[^1]: [Source](http://www.prnewswire.com/news-releases/strategy-analytics-android-captures-79-percent-share-of-global-smartphone-shipments-in-2013-242563381.html)

[^2]: See Google's documentation for supporting multiple screen sizes [here](http://developer.android.com/guide/practices/screens_support.html).
    
[^3]: [Intents documentation](http://developer.android.com/reference/android/content/Intent.html)

[^4]: See Google's documentation for [multi-pane tablet view](http://developer.android.com/design/patterns/multi-pane-layouts.html) for more information.
    
[^5]: Thanks, [NSHipster](http://nshipster.com/uicollectionview/).
