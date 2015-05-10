---
title:  "Android’s Notification Center"
category: "11"
date: "2014-04-01 08:00:00"
tags: article
author:
  - name: Kevin Grant
    url: https://twitter.com/kevingrant5
---


Notifications from our devices are almost second nature for us these days. Hardly an hour goes by that we aren’t pulling out our phones, checking our status bars, and then putting our phones back in our pockets. For Android users, this is especially true, as it is one of the primary ways of interacting with their devices. Unlock your screen, read a few emails, approve some friend requests, and like your buddy’s check-in, across three different applications, all directly from the notification bar.

But this is an entirely different world for some. Particularly, iOS has a long history of not getting notifications quite right, and iOS developers didn’t have the same kind of fine-grained control over their apps' notifications. It wasn’t possible to receive silent notifications, to possibly wait and post them later. Things have changed in iOS 7, but the bad taste still remains in the mouths of some, and notifications are still lacking some key features that Android developers have been enjoying for years.

It’s been long touted that Android 'got' notifications right from the beginning. All of your notifications were centralized in one logical place on your phone, right in the system bar, next to your battery and signal strength settings. But to understand what Android’s notification system is capable of, it’s important to understand its roots, and how the system evolved.

Since Android let developers fully control their own background processes, they were able to create and show notifications at any time, for any reason. There was never a notion of delivering a notification to the application or to the status bar. It was delivered wherever you wanted it.

You could access this from anywhere, at any time. Since the majority of applications didn’t force a fullscreen design, users could pull down the notification 'drawer' whenever they wanted. For many people, Android was their first smartphone, and this type of notification system deviated from the notification paradigm that existed before, one where you had to arduously open every single application that had information for you, whether it be missed calls, SMSes, or emails.

Notifications in Android 1.6 (Donut): 

![Notifications in Android 1.6](/images/issue-11/android-g1-50.jpg) 

Notifications in Android 4.4 (KitKat):

![Notifications in Android 4.4](/images/issue-11/modern_notes.png)


## A Brief History

Notifications on Android today have come a long way since their debut in 2008.

### Android 1.5 - 2.3

This is where Android began for most of us (including me). We had a few options available to us, which consisted mainly of an icon, a title, a description, and the time. If you wanted to implement your own custom control, for example, for a music player, you could. The system maintained the desired width and height constraints, but you could put whatever views in there you wanted. Using these custom layouts is how the first versions of many custom music players implemented their custom controls in the notification:

    private void showNotification() {
      // Create the base notification (the R.drawable is a reference fo a png file)
      Notification notification = new Notification(R.drawable.stat_notify_missed_call,
          "Ticket text", System.currentTimeMillis());

      // The action you want to perform on click
      Intent intent = new Intent(this, Main.class);

      // Holds the intent in waiting until it’s ready to be used
      PendingIntent pi = PendingIntent.getActivity(this, 1, intent, 0);

      // Set the latest event info
      notification.setLatestEventInfo(this, "Content title", "Content subtext", pi);

      // Get an instance of the notification manager
      NotificationManager noteManager = (NotificationManager)
          getSystemService(Context.NOTIFICATION_SERVICE);

      // Post to the system bar
      noteManager.notify(1, notification);
    }

Code: Function on how notifications were created in 1.5-2.3.


What the code looks like run on Android 1.6:

![Notifications in Donut 1.6](/images/issue-11/gb/donut.png) 

What the code looks like run on Android 2.3:

![Notifications in Gingerbread 2.3](/images/issue-11/gb/gingerbread_resized.png)


### Android 3.0 - 3.2

Notifications in Android 3.0 actually took a slight turn for the worse. Android’s tablet version, in response to Apple’s iPad, was a fresh take on how to run Android on a large screen. Instead of a single unified drawer, Android tried to make use of its extra space and provide a separate notification experience, one where you still had a drawer, but you would also receive 'growl-like' notifications. Fortunately for developers, this also came with a brand new API, the `NotificationBuilder`, which allowed us to utilize a [builder pattern](http://en.wikipedia.org/wiki/Builder_pattern) to create our notifications. Even though it’s slightly more involved, the builder abstracts away the complexity of creating notification objects that differ ever so slightly with every new version of the operating system:

    // The action you want to perform on click
    Intent intent = new Intent(this, Main.class);

    // Holds the intent in waiting until it’s ready to be used
    PendingIntent pi = PendingIntent.getActivity(this, 1, intent, 0);

    Notification noti = new Notification.Builder(getContext())
      .setContentTitle("Honeycomb")
      .setContentText("Notifications in Honeycomb")
      .setTicker("Ticker text")
      .setSmallIcon(R.drawable.stat_notify_missed_call)
      .setContentIntent(pi)
      .build();

    // Get an instance of the notification manager
    NotificationManager noteManager = (NotificationManager)
        getSystemService(Context.NOTIFICATION_SERVICE);

    // Post to the system bar
    noteManager.notify(1, notification);

What a notification looks like when initially received in Honeycomb:

![Honeycomb notifications ticket text](/images/issue-11/hc/initially-received-hc.png)


What a notification looks like when you click on it in the navigation bar:

![Honeycomb notifications tapping notification](/images/issue-11/hc/selecting_notification_hc.png)

What a notification looks like when you select the clock:

![Honeycomb notifications tapping clock](/images/issue-11/hc/selecting_clock_hc.png)


These redundant notifications led to user confusion about what notifications were representing, and presented many design challenges for the developer, who was trying to get to the right information to the user at the right time.

### Finally, 4.0-4.4

As with the rest of the operating system, Android began to really flesh out and unify its notification experience in 4.0 and beyond. While 4.0 in particular didn’t bring anything exciting to the table, 4.1 brought us roll-up notifications (a way to visualize more than one notification in a single cell), expandable notifications (for example, reading the first paragraph of an email), picture notifications, and actionable notifications. Needless to say, this created an entirely new way of enriching a user’s out-of-app experience. If someone ‘friended’ me on Facebook, I could simply press an 'accept friend request' button right from the notification bar, without ever opening the application. If I received an email I didn’t actually have to read, I could archive it immediately without ever opening my email.

Here are a few examples of the 4.0+ API’s that are utilized in the [Tumblr application for Android](https://play.google.com/store/apps/details?id=com.tumblr). Using these notifications is incredibly simple; it only requires adding an extra notification style onto the `NotificationBuilder`.

#### Big Text Notifications

If the text is short enough, why do I have to open the app to read it? Big text solves that problem by giving you some more room to read. No wasted application opens for no reason:

    Notification noti = new Notification.Builder()
      ... // The same notification properties as the others
      .setStyle(new Notification.BigTextStyle().bigText("theblogofinfinite replied..."))
      .build();

Big text notification contracted:

![Notifications in Cupcake 1.5](/images/issue-11/ics/shrunk_text.png)

Big text notification expanded:

![Notifications in Cupcake 1.5](/images/issue-11/ics/bigtext.png)


#### Big Picture Notifications

These wonderful notifications offer a content-first experience without ever requiring the user to open an application. This provides an immense amount of context, and is a beautiful way to interact with your notifications:

    Notification noti = new Notification.Builder()
      ... // The same notification properties as the others
      .setStyle(new Notification.BigPictureStyle().bigPicture(mBitmap))
      .build();

![Big picture notification](/images/issue-11/ics/big_pic.png)


#### Roll-Up Notifications

Roll-up notification is bringing multiple notifications into one. The rollup cheats a little bit because it doesn’t actually stack existing notifications. You’re still responsible for building it yourself, so really it’s just more of a nice way of presenting it:

    Notification noti = new Notification.Builder()
      ... // The same notification properties as the others
      .setStyle(new Notification.InboxStyle()
         .addLine("Soandso likes your post")
         .addLine("Soandso reblogged your post")
         .setContentTitle("3 new notes")
         .setSummaryText("+3 more"))
      .build();

![Rollup notification](/images/issue-11/ics/rollup.png)


#### Action Notifications

Adding actions to a notification is just as easy as you’d imagine. The builder pattern ensures that it will use whatever default styles are suggested by the system, ensuring that the user always feels at home in his or her notification drawer:

    Notification noti = new Notification.Builder()
      ... // The same notification properties as the others
      .addAction(R.drawable.ic_person, "Visit blog", mPendingBlogIntent)
      .addAction(R.drawable.ic_follow, "Follow", mPendingFollowIntent)
      .build();

![Action notification](/images/issue-11/ics/actions.png)

These sorts of interactions lent to an application design that put the user in charge, and made performing simple actions incredibly easier, and faster. At a time when Android had suffered from sluggish performance, these sorts of quick actions were greatly welcomed, since you didn’t actually have to open an application to still be able to use it.

### Android Wear

It’s no secret to anyone in the tech world right now that Android wear is a fascinating introduction into the wearables space. Whether or not it will succeed as a consumer product is certainly up for debate. What isn’t up for debate is the barrier to entry for developers who want to support Android Wear. Living up to its legacy, Android Wear appears to have gotten notifications correct, in regards to syncing with your device. As a matter of fact, if you phone is connected to an Android Wear device, it will push any notifications created with a builder directly to the device, with no code modification necessary. The ongoing simplicity of the `NotificationBuilder` pattern will ensure that whatever devices that come out and support Android or Android Wear will almost immediately have an breadth of app developers who are already comfortable using the APIs to send and receive data.

![Action notification](/images/issue-11/watch/picture.png)
![Action notification](/images/issue-11/watch/hunkosis.png)

NotificationBuilder provides out-of-the-box support for Android Wear, no code required!

## Custom Notifications

Even though Android’s `NotificationBuilder` provides an enormous level of customizability, sometimes that just isn’t enough, and that's where custom notification layouts come in. It’s hard to imagine what you would do if you had complete control over a notification. How would you change it, what would it really do beyond a normal notification? Thinking creatively within these constraints can be difficult, but many Android developers have stepped up to the plate.

Custom music player notification:

![Custom music player notification](/images/issue-11/custom/music_player.png) 

Custom weather notification:

![Custom weather notification](/images/issue-11/custom/weather.jpg) 

Custom battery notification:

![Custom battery notification](/images/issue-11/custom/battery_widget.png)

Custom notifications are limited to a subset of view components that are supported by [Remote Views](http://developer.android.com/reference/android/widget/RemoteViews.html), and those view components themselves cannot be extended or overridden too heavily. Regardless of this slight limitation, you can see that you can still create sophisticated notifications using these basic components.

Creating these custom views takes a bit more work however. Custom notification views are created using Android's XML layout system, and you are responsible for making sure your notifications look decent on all the different versions of Android. It’s a pain, but when you see some of these beautiful notifications, you can instantly understand their value:

    <?xml version="1.0" encoding="utf-8"?>
    <LinearLayout xmlns:android="http://schemas.android.com/apk/res/android"
    	android:layout_width="match_parent"
    	android:layout_height="match_parent"
    	android:orientation="horizontal">

    	<ImageView
    		android:id="@+id/avatar"
    		android:layout_width="32dp"
    		android:layout_height="32dp"
    		android:layout_gravity="center_vertical" />

    	<TextView
    		android:layout_width="wrap_content"
    		android:layout_height="wrap_content"
    		android:layout_gravity="center_vertical"
    		android:text="You received a notification" />

    </LinearLayout>
An extremely basic custom-notification layout that shows an image, with some text beside it.

## Notification Behavior

### Push Notifications

Now that we’ve had our extensive history lesson, let's get into some interesting behavior about how notifications work. As it might be apparent from the information we’ve already covered, developers have *complete* control over this notification system. That means notifications can be shown or dismissed at any time, for any reason. There is no need for this notification to be received from Google through a push notification service. In fact, even when receiving push notifications, they aren’t just shown in the status bar by default -- you have to catch that push notification and decide what to do with it.

For example, a common notification interaction looks like this:

1. Receive push notification from remote server
2. Inspect payload, fire off a background service to fetch data instructed by payload
3. Receive / parse response
4. Build and show notification

What is interesting, however, is that for steps two and three, there is no time limit that is imposed on this background service. If the push notification told you to download a 1GB file, then that's OK! For most use cases, there is no requirement by the system to show you relatively short running services in the background. Long-running background services (think music player), however, do require an icon to be shown in the status bar. This was great forethought from the Android engineers to make sure that the user would know about anything that was doing background work for too long.

But even these four steps are more than an average developer would like to handle. Wouldn’t it be great if you could just send the whole payload? [GCM (Google Cloud Messaging)](http://developer.android.com/google/gcm/index.html) allows payloads of up to 4KB. On average, that's between 1,024 and 4,096 UTF-8 characters (depending on the characters). Unless you're pushing down images, you could probably fit whatever you wanted into a single push. Sounds great!

### Notification Callbacks

So what kind of control do we have as developers over how the user is interacting with the notifications? Sure, we’ve seen that there is a possibility to add custom controls and buttons onto them, and we’ve already seen how to interact with a general click, but is there anything else? Actually, there is! There is a 'delete' action, `setDeleteIntent`, that gets fired when the user dismisses the notification from the drawer. Hooking into delete is a great way to make sure we don’t ever show the user this information again:

    // In Android, we can create arbitrary names of actions, and let
    // individual components decide if they want to receive these actions.
    Intent clearIntent = new Intent("clear_all_notifications");
    PendingIntent clearNotesFromDb = PendingIntent.getBroadcast(aContext, 1, clearIntent, 0)

    Notification noti = new Notification.Builder(getContext())
      ...
      .setDeleteIntent(clearNotesFromDb)
      .build();

### Recreating the Navigation Hierarchy

Let’s talk a little more about the default notification click. Now, you could certainly perform some sort of default behavior when clicking on a notification. You could just open the application, and be done with it. The user can figure out where to go from there. But it would be so much nicer if we opened up directly to the relevant screen. If we receive an email notification, let's jump directly to that email. If one of my friends checks in on Foursquare, let's open right to that restaurant and see where he or she is. This is a great feature because it allows your notifications to act as deep links into the content that they are referring to. But often, when deep linking into these parts of your application, you run into a problem where your navigation hierarchy is all out of order. You have no way of actually navigating 'back.' Android helps you solve this problem by allowing you to create a stack of screens before you start anything. This is accomplished via the help of the TaskStackBuilder class. Using it is a little magical and requires some prior knowledge to how applications are structured, but feel free to take a look at Google’s developer site for a
[brief implementation](http://developer.android.com/guide/topics/ui/notifiers/notifications.html#SimpleNotification).

For our Gmail example, instead of just telling our application that we want to open an email, we tell it, "Open the email app, and then open this specific email." The user will never see all of the screens being created; instead, he or she will only see the end result. This is fantastic, because now, when selecting back, the user doesn’t leave the application. He or she simply ends up returning to the apps home screen.

## What’s Missing

I’ve detailed quite a bit about what notifications in Android have to offer, and I’ve even demonstrated how powerful they can be. But no system is perfect, and Android’s notification system is not without its shortcomings.

### Standards

One of the unfortunate problems Android users face is that there is no centralized control for how notifications work. This means that if there is an application prompting you with a notification, short of uninstalling the application, there isn’t much you can do. Starting in Android 4.1, users received a buried binary setting to 'Turn off notifications' for a specific app. This prevents this application from placing *any* notification in the status bar. While it may seem helpful, the user case is actually fairly limited, since rarely do you want to disable all of an application's notifications completely, but rather a single element of it, for instance the LED or the annoying sound.

![Turn off notifications](/images/issue-11/disable_notifications.png)
Starting in Android 4.1, users received a binary setting to 'Turn off notifications,' but there is still no centralized way to disable LEDs or sounds unless provided explicitly by the developer.

### What to Display

You might think that we’re taking for granted all of the control that we have over notifications already, but certainly there is always room for more. While the current system offers a lot of functionality and customizability, I’d like to see it taken a step further. The `NotificationBuilder`, as we saw earlier, forces your notification into a certain structure that encourages all notifications to look and feel the same. And if you use a custom layout and build the notification yourself, there are only a handful of supported components that you are allowed to use. If you have a complex component that needs to be custom drawn, it’s probably safe to assume that you can’t do it. And if you wanted to do something next level, like incorporating frame animations, or even a video, forget about it.

## Wrapping Up

Android has quite a bit to offer its users and developers in terms of notifications. Right from the get-go, Android made a conscious effort to support notifications in a big and bold way, something that remains unrivaled, even today. Looking at how Android has approached Android Wear, it’s easy to see that there is a huge emphasis on easily accessible APIs for working with the notification manager. While there are some shortcomings around fine-grained notification management and lack of complete UI control, it’s seemingly safe to say that if you are looking for a notifications-first ecosystem, Android might be worth a shot.

#### References

- [A Visual History of Android](http://www.theverge.com/2011/12/7/2585779/android-history)
- [Android Notifications Docs](http://developer.android.com/guide/topics/ui/notifiers/notifications.html)
- [Creating Notifications for Android Wear](http://developer.android.com/wear/notifications/creating.html)
