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
For the sake of the demonstration, imagine that such method exists (for example `[[NSBundle mainBundle] validateReceipt]`).
An attacker would look for this selector inside the binary and patch the code to skip the call.
Moreover, if every developer use the same validation method, hacking would be too easy.
Apple made the choice to use standard cryptography and encoding techniques, and to give hints to let developers implement the parsing and the validation.

This means that you are left to implement validation on your own: it is far from easy and require a good understanding of cryptography and of a variety of secure coding techniques.
Of course there are several off-the-shelf implementations available (for example [on GitHub][github-?-receipt-validation]), but they are often reference implementation.
So it's important to develop a solution that is unique and secure enough to resist to common attacks.

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
- Check the expiration date of the receipt if the Volume Purchase Program is used.

**NOTE:** The following sections describe how to perform the various steps of the validation.
The code snippets are meant to illustrate each step; do not consider them as the only solution.

### Locating the receipt

The location of the receipt differs between OS X and iOS as shown in the following figure:

![Receipt Locations](http://f.cl.ly/items/1d1K2B3I0Z251v080t0W/ReceiptLocation.png "Receipt Locations")

- On OS X, the receipt file is located inside the application bundle, under the `Contents/_MASReceipt` folder.
- On iOS, the receipt file is located in the application's data sandbox, under the `StoreKit` folder.

Once located, you must ensure that the receipt is present.

- If the receipt exists at the right place, it can be loaded.
- If the receipt does not exist, this is considered as a validation failure.

On OS X 10.7 and later or iOS 7 and later, the code is straightforward:

```
// OS X 10.7 and later / iOS 7 and later
NSBundle *mainBundle = [NSBundle mainBundle];
NSURL *receiptURL = [mainBundle appStoreReceiptURL];
NSError *receiptError;
BOOL isPresent = [receiptURL checkResourceIsReachableAndReturnError:&receiptError];
if (!isPresent) {
    // Validation fails
}
```

But if you target OS X 10.6, the `appStoreReceiptURL` selector is not available. Therefore, you have to manually build the URL to the receipt:

```
// OS X 10.6 and later
NSBundle *mainBundle = [NSBundle mainBundle];
NSURL *bundleURL = [mainBundle bundleURL];
NSURL *receiptURL = [bundleURL URLByAppendingPathComponent:@"Contents/_MASReceipt/receipt"];
NSError *receiptError;
BOOL isPresent = [receiptURL checkResourceIsReachableAndReturnError:&receiptError];
if (!isPresent) {
	// Validation fails
}
```

### Loading the receipt

The loading the receipt is pretty straightforward.
Here is the code to load and parse the PKCS #7 envelop with [OpenSSL][openssl]:

```
// Load the receipt file
NSData *receiptData = [NSData dataWithContentsOfURL:receiptURL];

// Create a memory buffer to extract the PKCS #7 container
BIO *receiptBIO = BIO_new(BIO_s_mem());
BIO_write(receiptBIO, [receiptData bytes], (int) [receiptData length]);
PKCS7 *receiptPKCS7 = d2i_PKCS7_bio(receiptBIO, NULL);
if (!receiptPKCS7) {
    // Validation fails
}

// Check that the container has a signature
if (!PKCS7_type_is_signed(receiptPKCS7)) {
    // Validation fails
}

// Check that the signed container has actual data
if (!PKCS7_type_is_data(receiptPKCS7->d.sign->contents)) {
    // Validation fails
}
```

### Verifying receipt signature

Once the receipt is loaded, the first thing to do is to make sure that the receipt is authentic and unaltered.
Here is the code to check the PKCS #7 signature with [OpenSSL][openssl]:

```
// Load the Apple Root CA (downloaded from https://www.apple.com/certificateauthority/)
NSURL *appleRootURL = [[NSBundle mainBundle] URLForResource:@"AppleIncRootCertificate" withExtension:@"cer"];
NSData *appleRootData = [NSData dataWithContentsOfURL:appleRootURL];
BIO *appleRootBIO = BIO_new(BIO_s_mem());
BIO_write(appleRootBIO, (const void *) [appleRootData bytes], (int) [appleRootData length]);
X509 *appleRootX509 = d2i_X509_bio(appleRootBIO, NULL);

// Create a certificate store
X509_STORE *store = X509_STORE_new();
X509_STORE_add_cert(store, appleRootX509);

// Be sure to load the digests before the verification
OpenSSL_add_all_digests();

// Check the signature
int result = PKCS7_verify(receiptPKCS7, NULL, store, NULL, NULL, 0);
if (result != 1) {
    // Validation fails
}
```

### Parsing the receipt

Once the receipt envelop has been verified, it is time to parse the receipt payload.
Here is the code to decode the DER-encoded ASN.1 payload with [OpenSSL][openssl]:

```
// Get a pointer to the ASN.1 payload
ASN1_OCTET_STRING *octets = receiptPKCS7->d.sign->contents->d.data;
const unsigned char *ptr = octets->data;
const unsigned char *end = ptr + octets->length;
const unsigned char *str_ptr;

int type = 0, str_type = 0;
int xclass = 0, str_xclass = 0;
long length = 0, str_length = 0;

// Store for the receipt information
NSString *bundleIdString = nil;
NSString *bundleVersionString = nil;
NSData *bundleIdData = nil;
NSData *hashData = nil;
NSData *opaqueData = nil;
NSDate *expirationDate = nil;

// Date formatter to handle RFC 3339 dates in GMT time zone
NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
[formatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"];
[formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];

// Decode payload (a SET is expected)
ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
if (type != V_ASN1_SET) {
    // Validation fails
}

while (ptr < end) {
    ASN1_INTEGER *integer;
    
    // Parse the attribute sequence (a SEQUENCE is expected)
    ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
    if (type != V_ASN1_SEQUENCE) {
        // Validation fails
    }
    
    const unsigned char *seq_end = ptr + length;
    long attr_type = 0;
    long attr_version = 0;
    
    // Parse the attribute type (an INTEGER is expected)
    ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
    if (type != V_ASN1_INTEGER) {
        // Validation fails
    }
    integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
    attr_type = ASN1_INTEGER_get(integer);
    ASN1_INTEGER_free(integer);
    
    // Parse the attribute version (an INTEGER is expected)
    ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
    if (type != V_ASN1_INTEGER) {
        // Validation fails
    }
    integer = c2i_ASN1_INTEGER(NULL, &ptr, length);
    attr_version = ASN1_INTEGER_get(integer);
    ASN1_INTEGER_free(integer);
    
    // Check the attribute value (an OCTET STRING is expected)
    ASN1_get_object(&ptr, &length, &type, &xclass, end - ptr);
    if (type != V_ASN1_OCTET_STRING) {
        // Validation fails
    }
    
    switch (attr_type) {
        case 2:
            // Bundle identifier
            str_ptr = ptr;
            ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
            if (str_type == V_ASN1_UTF8STRING) {
                // We store both the decoded string and the raw data for later
                // The raw is data will be used when computing the GUID hash
                bundleIdString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
                bundleIdData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
            }
            break;
            
        case 3:
            // Bundle version
            str_ptr = ptr;
            ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
            if (str_type == V_ASN1_UTF8STRING) {
                // We store the decoded string for later
                bundleVersionString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSUTF8StringEncoding];
            }
            break;
            
        case 4:
            // Opaque value
            opaqueData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
            break;
            
        case 5:
            // Computed GUID (SHA-1 Hash)
            hashData = [[NSData alloc] initWithBytes:(const void *)ptr length:length];
            break;
            
        case 21:
            // Expiration date
            str_ptr = ptr;
            ASN1_get_object(&str_ptr, &str_length, &str_type, &str_xclass, seq_end - str_ptr);
            if (str_type == V_ASN1_IA5STRING) {
                // The date is stored as a string that needs to be parsed
                NSString *dateString = [[NSString alloc] initWithBytes:str_ptr length:str_length encoding:NSASCIIStringEncoding];
                expirationDate = [formatter dateFromString:dateString];
            }
            break;
            
            // You can parse more attributes...
            
        default:
            break;
    }
    
    // Move past the value
    ptr += length;
}

// Be sure that all information is present
if (bundleIdString == nil ||
    bundleVersionString == nil ||
    opaqueData == nil ||
    hashData == nil) {
    // Validation fails
}
```

### Verifying receipt information

The receipt contains the bundle identifier and the bundle version for which the receipt was issued.
You need to make sure that these information match the one you are expected.

```
// Check the bundle identifier
if (![bundleIdString isEqualTo:@"io.objc.myapplication"]) {
    // Validation fails
}

// Check the bundle version
if (![bundleVersionString isEqualTo:@"1.0"]) {
    // Validation fails
}
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

```
#import <IOKit/IOKitLib.h>
```

```
// Open a MACH port
mach_port_t master_port;
kern_return_t kernResult = IOMasterPort(MACH_PORT_NULL, &master_port);
if (kernResult != KERN_SUCCESS) {
    // Validation fails
}

// Create a search for primary interface
CFMutableDictionaryRef matching_dict = IOBSDNameMatching(master_port, 0, "en0");
if (!matching_dict) {
    // Validation fails
}

// Perform the search
io_iterator_t iterator;
kernResult = IOServiceGetMatchingServices(master_port, matching_dict, &iterator);
if (kernResult != KERN_SUCCESS) {
    // Validation fails
}

// Iterate over the result
CFDataRef guid_cf_data = nil;
io_object_t service, parent_service;
while((service = IOIteratorNext(iterator)) != 0) {
    kernResult = IORegistryEntryGetParentEntry(service, kIOServicePlane, &parent_service);
    if (kernResult == KERN_SUCCESS) {
        // Store the result
        if (guid_cf_data) CFRelease(guid_cf_data);
        guid_cf_data = (CFDataRef) IORegistryEntryCreateCFProperty(parent_service, CFSTR("IOMACAddress"), NULL, 0);
        IOObjectRelease(parent_service);
    }
    IOObjectRelease(service);
    if (guid_cf_data) {
        break;
    }
}
IOObjectRelease(iterator);

NSData *guidData = [NSData dataWithData:(__bridge NSData *) guid_cf_data];
```

#### Getting the device GUID (iOS)

On iOS, the device GUID is an alphanumeric string that uniquely identifies the device, relative to the application's vendor:

```
UIDevice *device = [UIDevice currentDevice];
NSUUID *uuid = [device identifierForVendor];
uuid_t uuid;
[identifier getUUIDBytes:uuid];
NSData *guidData = [NSData dataWithBytes:(const void *)uuid length:16];
```
	
#### Hash computation

The hash computation must be done on the ASN.1 attribute's raw values (i.e. the binary data of the OCTET-STRING) and not on the interpreted values.
Here is the code to perform the SHA-1 hashing and the comparison with [OpenSSL][openssl]:

```
unsigned char hash[20];

// Create a hashing context for computation
SHA_CTX ctx;
SHA1_Init(&ctx);
SHA1_Update(&ctx, [guidData bytes], (size_t) [guidData length]);
SHA1_Update(&ctx, [opaqueData bytes], (size_t) [opaqueData length]);
SHA1_Update(&ctx, [bundleIdData bytes], (size_t) [bundleIdData length]);
SHA1_Final(hash, &ctx);

// Do the comparison
NSData *computedHashData = [NSData dataWithBytes:hash length:20];
if (![computedHashData isEqualToData:hashData]) {
    // Validation fails
}
```

### Volume Purchase Program

If your app supports the Volume Purchase Program, another check is needed: the receipt’s expiration date. This date can be found in the type 21 attribute.

```
// If an expiration date is present, check it
if (expirationDate) {
    NSDate *currentDate = [NSDate date];
    if ([expirationDate compare:currentDate] == NSOrderedAscending) {
        // Validation fails
    }
}
```


## Handling validation result

So far, if all the checks are ok, then the validation passes.
If any check fails, the receipt must be considered as invalid.

There are several ways to handle an invalid receipt, depending on the platform and the time when the validation is done.

### Handling on OS X

On OS X, a receipt validation **MUST** be performed at application startup, before the main method is called. If the receipt is invalid (missing, incorrect or tampered), the application **MUST** exits with a code **173**. This particular code tells the system that the application needs to retrieve a receipt. Once the new receipt has been issued, the application is restarted.

Note that when the application exit with a code **173**, an App Store credential dialog will be displayed to sign-in. This requires an active Internet connection so the receipt can be issued and retrieved.

You can also perform receipt validation during the lifetime of the application.
It is up to you to decide how the application will handle an invalid receipt: ignore it, disable features or crash in a bad way.

### Handling on iOS

The receipt validation can be performed at any time. If the receipt is missing, you can trigger a receipt refresh request in order to tells the system that the application needs to retrieve a receipt.

Note that after triggering a receipt refresh, an App Store credential dialog will be displayed to sign-in. This requires an active Internet connection so the receipt can be issued and retrieved.

You can also perform receipt validation during the lifetime of the application.
It is up to you to decide how the application will handle an invalid receipt: ignore it or disable features.


## Testing

When it comes to testing, the major hurdle is to retrieve a test receipt in sandbox environment.

Apple is making a distinction between the production and the sandbox environment by looking at the certificate used to sign the application:

- If the application is signed with a developer certificate, then the receipt request will be directed to the sandbox environment.
- If the application is signed with an Apple certificate, then the receipt request will be directed to the production environment.

It is important to codesign your application with a valid developer certificate; otherwise the `storeagent` daemon (the daemon responsible for communication with the App Store) will not recognize your application as an App Store application.

And with sandbox environment come test users.

### Configuring Test Users

In order to simulate real users in sandbox environment, you have to define test users.
The test users behave the same way as real users except that nobody get charged when they make a purchase.

The configuration of the test users is made through the [iTunes Connect portal][itunes-connect].
You can define as many as test users you want.
Each test user requires a valid email address that must not be a real iTunes account.
If your email provider supports the `+` sign in email addresses, you can use email aliases for the test accounts: foo+us@objc.io, foo+uk@objc.io, and foo+fr@objc.io emails will be sent to foo@objc.io.

### Testing on OS X

To test on OS X:

- Launch the application from the Finder. **DO NOT LAUNCH it from Xcode !!!** It is important to launch it from the finder so the `launchd` daemon can trigger the receipt retrieval.
- The lack of receipt should make the application exit with a code 173. This application's exit trigger the request for a valid receipt. An App Store login window should appear; use the test account credentials to sign-in and retrieve the test receipt.
- If the credentials are valid and the bundle information match the one you entered, then a receipt is generated and installed in the application bundle. After the receipt is retrieved, the application is re-launched automatically.

Once a receipt has been retrieved, you can now launch the application from Xcode to debug or fine-tune the receipt validation code.

### Testing on iOS

To test on iOS:

- Launch the application on a real device. **DO NOT LAUNCH it in the simulator !!!**. The simulator lacks the API required to issue receipts.
- The lack of receipt should make the application trigger a receipt refresh request. An AppStore login window should appear; use the test account credentials to sign-in and retrieve the test receipt.
- If the credentials are valid and the bundle information match the one you entered, then a receipt is generated and installed in the application sandbox. After the receipt is retrieved, you can perform another validation to ensure that everything is ok.

Once a receipt has been retrieved, you can now launch the application from Xcode to debug or fine-tune the receipt validation code.


## Security

The receipt validation code must be considered as a highly sensitive code.
If it is bypassed or hacked, you loose the ability to check if the users have the right to use your application or if they have paid for what they have.
This is why it is important to protect the validation code against attackers.

**Note:** There are many ways of attacking an application, so don't try to be fully hacker-proof. The rule is simple: make the hack of your application as costly as possible.

### Kind of attacks

All attacks begin with an analysis of the target:

- **Static analysis:**
  it is performed on the binaries that compose your application. It uses tools like `strings`, `otool`, dis-assembler, etc.
- **Dynamic analysis:**
  it is performed by monitoring the behavior of the application at runtime, by attaching a debugger and setting breakpoint on known functions for example.

Once the analysis is done, some common attacks can be performed against your application to bypass or hack the receipt validation code:

- **Receipt replacement:**
  if you fail to validate properly the receipt, an attacker can put a receipt from another application that appears to be legitimate.
- **Strings replacement:**
  if you fail to hide/obfuscate the strings involved in the validation (i.e. `en0`, `_MASReceipt`, bundle identifier, or bundle version), you give the attacker the ability to replace *your* strings *by* his strings.
- **Code bypass:**
  if your validation code uses well-know functions or patterns, an attacker can easily locate the place where the application validates the receipt and bypass it by modifying some assembly code.
- **Shared library swap:**
  if you are using an external shared library for cryptography (like OpenSSL), an attacker can replace *your* copy of OpenSSL by *his* copy and thus bypass anything that relies on the cryptographic functions.
- **Function override/injection:**
  this kind of attack consists in patching well-known functions (user or system ones) at runtime by prepending a shared library to the application's shared library path. The [mach_override][github-mach-override] project make that dead simple.

### Secure practices

While implementing receipt validation, there are some secure practices to follow.
Here is a few things to keep in mind:

#### DOs

- **Validate several times:**
  validate the receipt at startup and periodically during the application lifetime.
  The more validation code you have, the more an attacker has to work.
- **Obfuscate strings:**
  never let the strings used in validation in clear form as it can help an attacker to locate or hack the validation code. String obfuscation can use xoring, value shifting, bit masking, or anything else that makes the string human-unreadable.
- **Obfuscate the result of receipt validation:**
  don't wrap the validation into a simple boolean test; it is easy to bypass. Instead, you can use blocks, function callback, or any indirection that makes the result not obvious.
- **Harden the code flow:**
  by using opaque predicate (i.e. condition known at runtime), make your validation code flow hard to follow. Opaque predicate are typically made of function call results which are not known at compile time. You can also use loops, goto statement, static variables, or any control flow structure where you don't need to.
- **Use static libraries:**
  if you include third-party code, link it statically whenever it is possible; statically code  is harder to patch and you do not depend on external code that can change.
- **Tamper-proof the sensitive functions:**
  make sure that sensitive functions have not been replaced or patched. As a function can have several behaviors based on its input arguments, make calls with invalid arguments; if it does not return an error or the right return code, then it may be have been replaced or patched.

#### DON'Ts

- **Avoid Objective-C:**
  Objective-C carries a lot of runtime information that make it vulnerable to symbol analysis/injection/replacement. If you still want to use Objective-C, obfuscate the selectors and the calls.
- **Don't use shared libraries for secure code:**
  a shared library can be swapped or patched.
- **Don't use a separate code:**
  bury the validation code into your business logic to make it hard to locate and patch.
- **Don't factor receipt validation:**
  vary and multiply validation code implementations to avoid the pattern detection.
- **Don't underestimate the determination of attackers:**
  with enough time and resources, an attacker will ultimately succeed into cracking your application.
  What you can do is to make it painful and costly.


## Conclusion

You are now familiar with receipt validation and know the what lies behind and how important it is.
Be sure to take some time to implement it properly as it can protect your revenue's streams.




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
[itunes-connect]: http://itunesconnect.apple.com/
