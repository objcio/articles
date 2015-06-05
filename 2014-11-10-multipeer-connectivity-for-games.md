---
title:  "Multipeer Connectivity in Games"
category: "18"
date: "2014-11-10 08:00:00"
tags: article
author:
  - name: JP Simard
    url: https://twitter.com/simjp
---

Since its unveiling at WWDC 2013, [Multipeer Connectivity][mpc] (or MPC as we'll refer to it here) has garnered much hype, but relatively few products have successfully integrated it in meaningful ways. So let's see what MPC is and how to leverage it to build impressive experiences, especially in games.

## What is Multipeer Connectivity?

Multipeer Connectivity is an Apple framework that offers transport-agnostic mechanisms for network discoverability, creation, and communication. It's the spiritual successor to [Bonjour][bonjour], which was mostly useful for device discoverability on LAN and Wi-Fi networks.

A key benefit of MPC is that ad-hoc peer-to-peer networks can be created regardless of whether or not existing Wi-Fi or Bluetooth personal area networks are available. Once connected, peers can securely share messages, streams, or file resources.

Most MPC functionality is also available through the higher-level [GameKit framework][gamekit]. Using GameKit to power your game can allow developers to work with very useful game concepts to abstract the underlying networking protocols.

Even though most games will benefit more from integrating GameKit and its game-related abstractions over direct use of MPC, this article should serve as a useful guide for more advanced MPC usage.

## When Should It Be Used?

When your game or app may run on multiple devices in close proximity to each other, MPC has the potential of drastically improving the user experience. Whether you're building a remote control or multiplayer game, MPC helps reduce user experience friction, server costs, and even latency.

For example, a remote control app that avoids any user configuration and automatically connects to the service being controlled immediately after installation can transform your app from good to great. This is true whether it is a remote control for a game, presentation software, a media player, or something else. An open-source example of this is [DeckRocket][deckrocket], an iOS remote for the [Deckset][deckset] presentation app.

Multiplayer game scenarios can also benefit from MPC's zero-configuration and offline connectivity features. For example, a card game app containing game logic, rules, and scorekeeping could allow any two players to instantly start playing, regardless of Internet connectivity. In this article, we'll take some real-world examples from the CardsAgainst app, an open-source iOS version of the popular [Cards Against Humanity][cah] game. The full source to the CardsAgainst app can be found on [GitHub][cardsagainst].

Other examples in this article will be taken from [PeerKit][peerkit], an open-source framework for building event-driven, zero-configuration MPC apps.

## Discovery Setup

There are several ways to integrate the device discovery aspect of MPC into your app or game. We'll look at three different design patterns that cover a fairly wide variety of use cases.

### The Default Way

Apple provides a built-in view controller to facilitate discovering peers and initiating a common session. Simply present an [`MCBrowserViewController`][MCBrowserViewController] with a `serviceType` and `session`, and MPC will do the rest. Note that `serviceType` is limited to 15 ASCII letters, numbers, and dashes. A common approach is to use a style similar to reverse-DNS notation (e.g. `io-objc-mpc`):

```objc
let session = MCSession(peer: MCPeerID(displayName: "Mary"))
let serviceType = "io-objc-mpc" // Limited to 15 ASCII characters
window!.rootViewController = MCBrowserViewController(serviceType: serviceType, session: session)
```

![](/images/issue-18/browser.png)

Since `MCBrowserViewController` is not easily customizable, it's likely that you'll want to provide your own mechanism for selecting peers. That brings us to the next approach.

### The Dedicated Advertiser/Browser Approach

If your game already requires a mechanism to elect a primary node to coordinate game logic, and secondary nodes to simply attach to the primary one, then you should leverage this information by only advertising from the primary node and browsing from secondary nodes:

![](/images/issue-18/dedicated.gif)

```objc
// Advertise from the primary node
advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
advertiser.delegate = self
advertiser.startAdvertisingPeer()

// Browse from secondary nodes
mcBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
mcBrowser.delegate = self
mcBrowser.startBrowsingForPeers()
```

However, there are often cases in which it is preferable to establish a connection earlier in the app's lifecycle, without any user input. The next approach demonstrates how to accomplish this.

### The Zero-Config Approach

MPC makes it possible to create truly frictionless user experiences. When integrated properly into your app, your users may start communicating immediately after installing the app from the App Store, with no configuration necessary. This is a powerful way to delight them.

![](/images/issue-18/zero-config.gif)

To do this, it's possible to both advertise and browse for sessions simultaneously. We'll call this behavior transceiving (transmitting and receiving).

One challenge that arises when all peers transceive is contention. There can be many peers attempting to mutually connect to each other's advertised sessions. This is a thoroughly researched type of problem called [leader election][leader-election], with several well-known solutions.

A simple but effective way to elect an MPC leader is to include the running time of each node as metadata when inviting peers to join sessions, with advertisers always joining the oldest session:

```objc
// Browser Delegate Code
func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
    var runningTime = -timeStarted.timeIntervalSinceNow
    let context = NSData(bytes: &runningTime, length: sizeof(NSTimeInterval))
    browser.invitePeer(peerID, toSession: mcSession, withContext: context, timeout: 30)
}

// Advertiser Delegate Code
func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
    var runningTime = -timeStarted.timeIntervalSinceNow
    var peerRunningTime = NSTimeInterval()
    context.getBytes(&peerRunningTime)
    let isPeerOlder = (peerRunningTime > runningTime)
    invitationHandler(isPeerOlder, mcSession)
    if isPeerOlder {
        advertiser.stopAdvertisingPeer()
    }
}
```

## Sending and Receiving

MPC offers several ways to send and receive data, each with their own advantages and trade-offs.

### Sending Data

When sending small amounts (up to a few kB) of event-driven data, such as game events (start/pause/quit), use the `sendData(_:toPeers:withMode:error:)` function.

To help encapsulate transmitted data, the CardsAgainst app defines an enum of possible game events, which can then be used to serialize and de-serialize accompanying data:

```objc
// Possible Game Events
enum Event: String {
    case StartGame = "StartGame",
    Answer = "Answer",
    CancelAnswer = "CancelAnswer",
    Vote = "Vote",
    NextCard = "NextCard",
    EndGame = "EndGame"
}

// Reliably send an event to given peers, optionally with accompanying data
func sendEvent(event: Event, object: AnyObject? = nil, toPeers peers: [MCPeerID] = session.connectedPeers as [MCPeerID]) {
    if peers.count == 0 {
        return
    }
    var rootObject: [String: AnyObject] = ["event": event.rawValue]
    if let object = object {
        rootObject["object"] = object
    }
    let data = NSKeyedArchiver.archivedDataWithRootObject(rootObject)
    session.sendData(data, toPeers: peers, withMode: .Reliable, error: nil)
}

// Usage
sendEvent(.StartGame, ["initialData": "hello objc.io!"])
```

See CardsAgainst's [`ConnectionManager.swift source`](https://github.com/jpsim/CardsAgainst/blob/master/CardsAgainst/Controllers/ConnectionManager.swift) for more information.

#### Reliable vs. Unreliable Transmissions

Much like the [TCP/UDP dichotomy][tcp-udp], MPC allows sending data in both reliable and unreliable modes. The [`MCSessionSendDataMode`](https://developer.apple.com/library/IOs/documentation/MultipeerConnectivity/Reference/MCSessionClassRef/index.html#//apple_ref/doc/c_ref/MCSessionSendDataMode) contains the values for both modes.

To send data with the `.Reliable` mode:

```objc
let message = "Hello objc.io!"
let data = message.dataUsingEncoding(NSUTF8StringEncoding)!
var error: NSError? = nil
if !session.sendData(data, toPeers: peers, withMode: .Reliable, error: &error) {
    println("error: \(error!)")
}
```

If you're sending data where each byte is essential to the proper functionality of your game, such as starting or pausing your game, use the `.Reliable` mode.

If speed is prioritized over accuracy or order of transmissions, such as sending sensor data, then the `.Unreliable` mode may be a better fit. Be sure to benchmark this against [streaming](#streaming) to pick the best option for your needs.

### Sending Files

When sending large amounts of data (hundreds of kB to several MB), such as files, the `sendResourceAtURL(_:withName:toPeer:withCompletionHandler:)` function should be used. This allows both the sender and receiver to monitor transfer progress through `NSProgress` objects.

Here's a sample taken from [DeckRocket](https://github.com/jpsim/DeckRocket/blob/96e875f784/OSX/DeckRocket/MultipeerClient.swift#L46-L56):

```objc
pdfProgress = session!.sendResourceAtURL(url, withName: filePath.lastPathComponent, toPeer: peer) { error in
    dispatch_async(dispatch_get_main_queue()) {
        self.pdfProgress!.removeObserver(self, forKeyPath: "fractionCompleted", context: &ProgressContext)
        if error != nil {
            HUDView.show("Error!\n\(error.localizedDescription)")
        } else {
            HUDView.show("Success!")
        }
    }
}
pdfProgress!.addObserver(self, forKeyPath: "fractionCompleted", options: .New, context: &ProgressContext)
```

### Streaming

For streaming data, such as sensor readings or continuously updating player position information, use the `startStreamWithName(_:toPeer:error:)` function to write to an `NSOutputStream`. The receiver will be able to read from an `NSInputStream`:

```objc
// Receiver
public func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {
    // Assuming a stream of UInt8's
    var buffer = [UInt8](count: 8, repeatedValue: 0)

    stream.open()

    // Read a single byte
    if stream.hasBytesAvailable {
        let result: Int = stream.read(&buffer, maxLength: buffer.count)
        println("result: \(result)")
    }
}
```

## Challenges

As powerful as MPC is, it comes with its own set of challenges. Following are descriptions of a few that you may encounter.

### Availability

MPC is only available on iOS 7, iOS 8, and OS X 10.10. So forget about using MPC with non-Apple hardware, or with anything but the very latest OS X release. Cross-platform apps and games will need to rely on other [alternatives](#alternatives).

### Reliability

Though Apple has made major improvements to MPC's reliability since its launch with iOS 7, reliability remains a sore point of MPC. Failed connections must be accounted for, and require quite a bit of legwork to cover many edge cases.

### Synchronization and Race Conditions

Writing real-time networking code is a lot like writing local multi-threaded code, except with arbitrary delays thrown in due to the lossy nature of wireless connectivity. Make sure to have appropriate locks around essential transmissions to confirm that every peer has acknowledged a critical event, before assuming that the event has been received and moving on.

Games often need to share state, such as whether or not the game is started or paused, or a player has quit. What happens if a player pauses your game just as another deals a fatal blow to an opponent? Asynchronous game logic contention is one area that MPC leaves up to you, the developer. Using frameworks like GameKit can actually go a long way toward centralizing this logic, but this comes at the expense of some flexibility.

## Alternatives

Writing a complex game in MPC will undoubtedly be challenging. Make sure to explore other options before making a decision.

### GameKit

It's clear that Apple has put a lot of thought into [GameKit][gamekit]. Though it enforces certain models and architectural paradigms, and requires relinquishing some control over session connectivity details, the framework also abstracts away much of the lower-level inner workings.

Building your game in GameKit will allow it to work both in peer-to-peer mode and over traditional networks.

### Websockets

The WebSocket protocol ([RFC 6455][websockets]) allows bidirectional communication between host and client. Each node requires a new websocket connection. The protocol is built over TCP, and therefore doesn't offer MPC's `.Unreliable` message-sending mode. Unlike MPC, websockets don't offer any network creation or device discovery mechanisms, so both host and client must be connected to the same network. Websockets are often used in conjunction with [Bonjour][bonjour].

Websockets can be appealing for building a cross-platform game or app, or if a connection with a custom backend is required.

Several websocket libraries are available both for Swift ([starscream][starscream]) and Objective-C ([SocketRocket][socketrocket], [jetfire][jetfire]).

## Summary

This article has hopefully shown that integrating Multipeer Connectivity into your game or app can be a relatively painless process that can greatly reduce user experience friction and delight your users.

For more information on MPC, the following resources might prove useful.

## Resources

* [Multipeer Connectivity Reference][mpc]
* [Multipeer Connectivity WWDC 2013 Session][mpc-apple-video]
* [GameKit Reference][gamekit]
* [NSHipster Article on Multipeer Connectivity][nshipster]
* [PeerKit: An open-source Swift framework for building event-driven, zero-config MPC apps][peerkit]
* [CardsAgainst: An open-source iOS game built with MPC][cardsagainst]
* [DeckRocket: An open-source presentation remote control app for iOS/OSX built with MPC][deckrocket]

[mpc]: https://developer.apple.com/library/IOs/documentation/MultipeerConnectivity/Reference/MultipeerConnectivityFramework/index.html
[gamekit]: https://developer.apple.com/LIBRARY/ios/documentation/GameKit/Reference/GameKit_Collection/index.html
[bonjour]: https://www.apple.com/support/bonjour
[cardsagainst]: https://github.com/jpsim/CardsAgainst
[peerkit]: https://github.com/jpsim/PeerKit
[deckrocket]: https://github.com/jpsim/DeckRocket
[deckset]: http://www.decksetapp.com
[cah]: http://cardsagainsthumanity.com
[MCBrowserViewController]: https://developer.apple.com/library/IOs/documentation/MultipeerConnectivity/Reference/MCBrowserViewController_class
[leader-election]: http://en.wikipedia.org/wiki/Leader_election
[tcp-udp]: http://en.wikipedia.org/wiki/User_Datagram_Protocol#Comparison_of_UDP_and_TCP
[websockets]: http://tools.ietf.org/html/rfc6455
[starscream]: https://github.com/daltoniam/starscream
[socketrocket]: https://github.com/square/SocketRocket
[jetfire]: https://github.com/acmacalister/jetfire
[mpc-apple-video]: https://developer.apple.com/videos/enterprise/#15
[nshipster]: http://nshipster.com/multipeer-connectivity
