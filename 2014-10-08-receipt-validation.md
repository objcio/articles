---
layout: post
title:  "Receipt Validation"
category: "17"
date: "2014-10-08 09:00:00"
author: "<a href=\"https://twitter.com/letiemble\">Laurent Etiemble</a>"
tags: article
---


## Introduction

### About Receipts

Receipts were introduced along the release of the Mac App Store, as part of the OS X 10.6.6 update.
While iOS has always provided server-side receipts for in-app purchases, it was only with iOS 7 that the very same )format of receipt has been available.

A receipt is meant to be a trusted record of the application and in-app purchases that have been made by the user.
Like a physical receipt that you get when shopping in a store, it is the proof that the application or the in-app purchases have been paid for.

Here are some key points about receipts:

- A receipt is created and signed by Apple through the App Store.
- A receipt is issued for a version of an application and a device.
- A receipt is stored **locally** on the device.
- A receipt is issued **each time** an installation or an update occurs:
	- When an application is installed,  a receipt is issued that match the application and the device.
	- When an application is updated, a receipt is issued that match the new application's version.
- A receipt is issued **each time** a transaction occurs:
	- When an in-app purchase occurs, a receipt is issued so it can be accessed to verify that purchase.
	- When previous transactions are restored, a receipt is issued so it can be accessed to verify those purchases.

### About Validation

Receipt validation is therefore important: verifying receipts helps your to protect your revenue and enforce of your business model directly into your application.

You may wonder Why Apple hasn't provide an API to validate the receipt.
For the sake of the demonstration, imagine that such method exists (for example `[[NSBundle mainBundle] validateReceipt]`):
an attacker would simply look for this selector inside the binary and patch it the call to skip the call.
Moreover, if everyone developer use the same validation method, hacking would be easy as pie.
The choice of Apple was to use standard cryptography and encoding techniques, and to give hints to implement the parsing and the validation.

The consequence is that you are left to implement validation on your own:
it is far from easy and require a good understanding of cryptography and of a variety of secure coding techniques.
Of course there are several off-the-shelf implementations available (for example [on GitHub][github-?-receipt-validation]), but they are often reference implementation.
It's important to develop a solution that is unique and secure enough to resist to common attacks.

## Anatomy of a receipt

Let's take a technical look at the receipt file. Its structure is shown in the following figure:

![Receipt Structure](http://f.cl.ly/items/2E0T2T1y2z2L0X1E3F1Y/ReceiptStructure.png "Receipt Structure")

A receipt file consist of a signed [PKCS #7][rfc-2315] container that embeds a [DER][wikipedia-x690-der] encoded [ASN.1][itu-t-x690] payload, a certificate chain, and a digital signature.

- **The payload:** it is a set of attributes that contains the receipt information; each attribute contains a type, a version and a value.
  Among the attribute values, you find the bundle identifier and the bundle version for which the receipt was issued.
- **The certificate chain:** it is the set of certificate that allows to verify the signature digest -- the leaf certificate is the certificate that has been used to digest the payload.
- **The signature:** it is the encrypted digest of the payload.
  By checking this digest, you can verify that the payload is not tampered with.

### The container

The container is made of a signed PKCS #7 envelop, which is signed by Apple with a dedicated certificate. The container's signature guarantees the authenticity and the integrity of the encapsulated payload.

To verifiy the signature, two checks are needed:

- The certificate chain is validated against well-known certificates (i.e. Apple CA Root): this is the **authenticity** check.
- A signature is computed by using the certificate chain and compared to the one found in the container: this is the **integrity** check.

### The Payload

The ASN.1 payload is defined by the following structure:

```asn1
ReceiptModule DEFINITIONS ::=
BEGIN

ReceiptAttribute ::= SEQUENCE {
	type    INTEGER,
	version INTEGER,
	value   OCTET STRING
}

Payload ::= SET OF ReceiptAttribute

END
```

A receipt attribute has three fields:

- **The type field:** each attribute is identified by its type.
  Apple has published a list of public attributes that can be used to extract information from the receipt.
  You may also find unlisted attributes while parsing a receipt: do not care (mostly because they are reserved by Apple for future use).
- **The version field:** not used for now (by may be in the future).
- **The value field:** it contains the data as an array of bytes (even if its name may suggest it, *THIS IS NOT* a string).

The payload is encoded using DER (Distinguished Encoding Rules): this kind of encoding provides an unequivocal and a compact result for ASN.1 structures. DER uses a pattern of [type-length-value][wikipedia-type-length-value] triplets, and uses byte constants for each type tags.

To better illustrate the concept, here are some concrete examples of DER encoded content applied to a receipt.

The figure below shows how a receipt module is encoded:

- The first byte identifies an ASN.1 set
- The three following bytes encode the length of the set's content
- The content of the set is the receipt attributes

![ASN.1 DER - Receipt Module](http://f.cl.ly/items/2Z2W311y2n3P3B1K2T3B/ASN.1-DER-Receipt.png "ASN.1 DER - Receipt Module")

The figure below shows how a receipt's attribute is encoded:

- The first byte identifies an ASN.1 sequence
- The second byte encodes the length of the sequence's content
- The content of the sequence is:
 - The attribute's type encoded as an ASN.1 INTEGER (the first byte identifies an ASN.1 INTEGER, the second byte encodes its length and the third byte contains the value)
 - The attribute's version encoded as an ASN.1 INTEGER (the first byte identifies an ASN.1 INTEGER, the second byte encodes its length and the third byte contains the value)
 - The attribute's value encoded as an ASN.1 OCTET-STRING (the first byte identifies an ASN.1 OCTET-STRING, the second byte encodes its length and the remaining bytes contains the data)

![ASN.1 DER - Receipt's attribute](http://f.cl.ly/items/3X2T2J1I2R1r0n111v0x/ASN.1-DER-Attribute-OCTETSTRING.png "ASN.1 DER - Receipt's attribute")

By using an ASN.1 OCTET-STRING for the attribute's value, it is very easy to embed various values like UTF-8 strings, ASCII strings, or numbers. The attribute's value can also contains a receipt module in the case of in-app purchase. Some examples are shown in the figures below:

![ASN.1 DER - Receipt's attribute containing an integer](http://f.cl.ly/items/0Y2t0s1i1Z1h3l0f2B3p/ASN.1-DER-Attribute-INTEGER.png "ASN.1 DER - Receipt's attribute containing an integer")

![ASN.1 DER - Receipt's attribute containing an IA5 string](http://f.cl.ly/items/3H372i0S0o2V2J1D0U0K/ASN.1-DER-Attribute-IA5STRING.png "ASN.1 DER - Receipt's attribute containing an IA5 string")

![ASN.1 DER - Receipt's attribute containing an UTF-8 string](http://f.cl.ly/items/0M3S0M2P0l1c2y1A1t1A/ASN.1-DER-Attribute-UTF8STRING.png "ASN.1 DER - Receipt's attribute containing an UTF-8 string")

![ASN.1 DER - Receipt's attribute containing an In-App purchase set string](http://f.cl.ly/items/1O3g3b002t1t2r3Y3M3u/ASN.1-DER-Attribute-SET.png "ASN.1 DER - Receipt's attribute containing an In-App purchase set")

## Validating the receipt

The steps to validate a receipt are the following:

- Locate the receipt. If no receipt is found, then the validation fails.
- Verify the receipt authenticity and integrity. The receipt must be properly signed by Apple and not tampered with.
- Parse the receipt to extract attributes such as the bundle identifier, the bundle version, etc.
- Verify that the bundle identifier found inside the receipt matches the bundle identifier of the application. Do the same for the bundle version.
- Compute the hash of the GUID of the device. The computed hash is based on a device specific information.

**NOTE:** The following sections describe how to perform the various steps of the validation.
The code snippets are meant to illustrate each step.
Do not use them as is.

### Locating the receipt

The location of the receipt differs between OS X and iOS as shown in the following figure:

![Receipt Locations](http://f.cl.ly/items/1d1K2B3I0Z251v080t0W/ReceiptLocation.png "Receipt Locations")

- On OS X, the receipt file is located inside the application bundle, under the `Contents/_MASReceipt` folder.
- On iOS, the receipt file is located in the application's data sandbox, under the `StoreKit` folder.

Once located, you must ensure that the receipt is present.

- If the receipt exists at the right place, it can be loaded.
- If the receipt does not exist, this is considered as a validation failure.

On OS X 10.7 and later or iOS 7 and later, the code is straightforward:

```objectivec
// OS X 10.7 and later / iOS 7 and later
NSBundle *mainBundle = [NSBundle mainBundle];
NSURL *receiptUrl = [mainBundle appStoreReceiptURL];
NSError *error;
BOOL isPresent = [receiptUrl checkResourceIsReachableAndReturnError:&error];
if (!isPresent) {
	// Validation fails
}
```

But if you target OS X 10.6, the `appStoreReceiptURL` selector is not available. Therefore, you have to manually build the URL to the receipt:

```objectivec
// OS X 10.6 and later
NSBundle *mainBundle = [NSBundle mainBundle];
NSURL *bundleUrl = [mainBundle bundleURL];
NSURL *receiptUrl = [bundleUrl URLByAppendingPathComponent:@"Contents/_MASReceipt/receipt"];
NSError *error;
BOOL isPresent = [receiptUrl checkResourceIsReachableAndReturnError:&error];
if (!isPresent) {
	// Validation fails
}
```

### Loading the receipt

In Objective-C, the loading the receipt is pretty straightforward:

```objectivec
NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
```

### Verifying receipt signature

Once the receipt is loaded, the first thing to do is to make sure that the receipt is authentic and unaltered.
Here is the code to parse the PKCS #7 envelop with [OpenSSL][openssl]:

```objectivec
// CODE GOES HERE
```

### Parsing the receipt

Once the receipt envelop has been verified, it is time to parse the receipt payload.
Here is the code to decode the DER-encoded ASN.1 payload with [OpenSSL][openssl]:

```objectivec
// CODE GOES HERE
```

### Verifying receipt information

The receipt contains the bundle identifier and the bundle version for which the receipt was issued.
You need to make sure that these information match the one you are expected.

```objectivec
// CODE GOES HERE
```

### Computing GUID hash

When the receipt is issued, three values are used to generate a SHA-1 hash:

- the device GUID (only available on the device)
- an opaque value (the type 4 attribute)
- the bundle identifier (the type 2 attribute)

A SHA-1 hash is computed on the concatenation of these three values, and stored into the receipt (type 5 attribute).

During the validation, the same computation must be done.
If the resulting hashes match, then the receipt is valid.
The figure below describes the computation:

![GUID Computation](http://f.cl.ly/items/090I1w1A0V1N01262M2a/GUIDComputation.png "GUID Computation")

In order to do the hash computation, you need to retrieve the device GUID.

#### Getting the device GUID (OS X)

On OS X, the device GUID is the [MAC][wikipedia-mac-address] address of the primary network card. A way to retrieve it is to use the [IOKit framework][apple-iokit]:

```objectivec
#import <IOKit/IOKitLib.h>

...

CFDataRef guid_cf_data = nil;

// Open a MACH port
mach_port_t master_port;
kern_return_t kernResult = IOMasterPort(MACH_PORT_NULL, &master_port);
if (kernResult != KERN_SUCCESS) {
    // Error handling
}

// Create a search for primary interface
CFMutableDictionaryRef matching_dict = IOBSDNameMatching(master_port, 0, @"en0");
if (!matching_dict) {
    // Error handling
}

// Perform the search
kernResult = IOServiceGetMatchingServices(master_port, matching_dict, &iterator);
if (kernResult != KERN_SUCCESS) {
    // Error handling
}

// Iterate over the result
io_iterator_t iterator;
io_object_t service, parent_service;
while((service = IOIteratorNext(iterator)) != 0) {
    kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent_service);
    if (kernResult == KERN_SUCCESS) {
        // Store the result
        if (guid_cf_data) CFRelease(guid_cf_data);
        guid_cf_data = (CFDataRef) IORegistryEntryCreateCFProperty(parent_service, @"IOMACAddress", NULL, 0);
        IOObjectRelease(parent_service);
    }
    IOObjectRelease(iterator);
}
IOObjectRelease(service);

NSData *guid_data = [NSData dataWithData:(NSData *)guid_cf_data];
```

#### Getting the device GUID (iOS)

On iOS, the device GUID is an alphanumeric string that uniquely identifies the device, relative to the application's vendor:

```objectivec
UIDevice *device = [UIDevice currentDevice];
NSUUID *uuid = [device identifierForVendor];
uuid_t uuid;
[identifier getUUIDBytes:uuid];
NSData *guid_data = [NSData dataWithBytes:(const void *)uuid length:16];
```
	
#### Hash computation

The hash computation must be done on the ASN.1 attribute's values (i.e. the binary data of the OCTET-STRING) and not on the interpreted values.
Here is the code to decode the DER-encoded ASN.1 payload with [OpenSSL][openssl]:

```objectivec
// CODE GOES HERE
```

### Volume Purchase Program

If your app supports the Volume Purchase Program, another check is needed: the receipt’s expiration date. This date can be found in the type 21 attribute.

```objectivec
// CODE GOES HERE
```

So far, if all the checks succeed, validation passes.


## Testing

Once the receipt validation is implemented, you need to test it.



### Configuring Test Users

The configuration of the test users is made through the iTunes Connect portal.



### Testing on OS X

Testing on OS X is straightforward.



### Testing on iOS

iOS testing is only possible on a physical device.
It does not work inside the simulator.



## Security

The receipt validation must be considered as a sensitive code.
If it is bypassed or hacked, you loose the ability to check if the users have the right to use your application or if they have paid for what they have.
This is why it is important to protect the validation code against attackers.

**Note:** There are many ways of hacking an application, so don't try to be hacker-proof. The rule is simple: make the hack of your application as costly as possible to discourage [script-kiddies][wikipedia-script-kiddie].

### Kind of attacks

All attacks begin with an analysis of the target:

- **static analysis:** it is performed on the binaries that compose your application. It uses tools like `strings`, `otool`, dis-assembler, etc.
- **dynamic analysis:** it is performed by monitoring the behavior of the application at runtime, by attaching a debugger and setting breakpoint on known functions for example.

Once the analysis is done, some common attacks can be performed against your application to bypass or hack the receipt validation code:

- **Receipt replacement:** if fail to validate properly the receipt, an attacker can put a receipt from another application that appears to be legitimate.
- **Strings replacement:** if you fail to hide/obfuscate the strings involved in the validation (i.e. `en0`, `_MASReceipt`, bundle identifier, or bundle version), you give the attacker the ability to replace your strings by his strings.
- **Code bypass:** if your validation code uses well-know functions or patterns, an attacker can easily locate the place where the application validates the receipt and bypass it by modifying some assembly code.
- **Shared library swap:** if you are using an external shared library for cryptography (like OpenSSL), an attacker can replace your copy of OpenSSL by his copy and thus bypass anything that relies on the cryptographic functions.
- **Function override/injection:** this kind of attack consists in patching well-known functions (user or system ones) at runtime by prepending a shared libary to your application. The [mach_override][github-mach-override] project make it very easy.

### Secure practices

While implementing receipt validation, there are some secure practices to follow.
Here are a few things to keep in mind:

- **Dos**
 - Validate several times.
   Validate the receipt at startup and periodically during the application lifetime.
   The more validation points you have, the more an attacker has to work.
 - Obfuscate strings.
   Never let the strings used in validation in clear form as it can help an attacker to locate or hack the validation code
 - Obfuscate the result of receipt validation
 - Harden the code flow.
   By using opaque predicate (condition known at runtime), make your validation code flow hard to follow. You can also use loops, goto statement, static variables, etc.
 - Use static libraries.
   If you include third-party code, link it statically: it is harder to patch and you can trust called code.

- **Don'ts**
 - Avoid Objective-C.
   Objective-C publishes a lot of runtime information that make it vulnerable to symbol injection/replacement. If you still want to use Objective-C, obfuscate all the selectors and the calls.
 - Don't use shared libraries.
   A shared library can be swapped or patched.
 - Don't use a separate code.
   Mix the validation code into your business logic to make it hard to locate and patch.
 - Don't factor receipt validation.
   Vary and multiply validation code implementations to avoid the pattern detection.
 - Don't underestimate the determination of attackers.
   With enough time and resources, an attacker will always succeed into cracking your application. You can only make it painful and costly.


## Conclusion

You are now familiar with receipt validation.
You know the what lies behind and how important it is.




[rfc-2315]: https://www.ietf.org/rfc/rfc2315.txt
[apple-iokit]: https://developer.apple.com/library/mac/documentation/IOKit/Reference/IOKitLib_header_reference/Reference/reference.html
[itu-t-x690]: http://www.itu.int/ITU-T/recommendations/rec.aspx?id=9608
[wikipedia-asn1]: http://en.wikipedia.org/wiki/Abstract_Syntax_Notation_One
[wikipedia-x690-der]: http://en.wikipedia.org/wiki/X.690#DER_encoding
[wikipedia-type-length-value]: http://en.wikipedia.org/wiki/Type-length-value
[wikipedia-mac-address]: http://en.wikipedia.org/wiki/MAC_address
[wikipedia-script-kiddie]:http://en.wikipedia.org/wiki/Script_kiddie
[github-mach-override]: https://github.com/rentzsch/mach_override
[github-?-receipt-validation]: https://github.com/search?utf8=%E2%9C%93&q=receipt+validation
[gnu-libtasn1]: http://www.gnu.org/software/libtasn1/
[asn1-compiler]: http://lionet.info/asn1c/compiler.html
[openssl]: https://www.openssl.org/
