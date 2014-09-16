---
layout: post
title:  "Receipt Validation"
category: "17"
date: "2014-10-08 09:00:00"
author: "<a href=\"https://twitter.com/letiemble\">Laurent Etiemble</a>"
tags: article
---


## About receipts

Receipts were introduced along the release of the Mac App Store, as part of the OS X 10.6.6 update.
While iOS has always provided server-side receipts for in-app purchases, it was only with iOS 7 that the very same )format of receipt has been available.

A receipt is meant to be a trusted record of the application and in-app purchases that have been made by the user.
Like a physical receipt that you get when shopping in a store, it is the proof that the application or the in-app purchases have been paid for.

This is why receipt validation is important: verifying receipts helps your to protect your revenue and enforce of your business model directly into your application.

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


## Anatomy of a receipt

Let's take a technical look at the receipt file. Its structure is shown in the following figure:

**FIGURE GOES HERE**

A receipt file consist of a signed [PKCS #7][rfc-2315] container that embeds a [DER][wikipedia-x690-der] encoded [ASN.1][itu-t-x690] payload, a certificate chain, and a digital signature.

- **The payload:** it is a set of attributes that contains the receipt information; each attribute contains a type, a version and a value.
  Among the attribute values, you find the bundle identifier and the bundle version for which the receipt was issued.
- **The certificate chain:** it is the set of certificate that allows to verify the signature digest -- the leaf certificate is the certificate that has been used to digest the payload.
- **The signature:** it is the encrypted digest of the payload.
  By checking this digest, you can verify that the payload is not tampered with.

### The container

The container is made of a signed [PKCS #7][rfc-2315] envelop, which is signed by Apple with a dedicated certificate. The container's signature guarantees the authenticity and the integrity of the encapsulated payload.

To verifiy the signature, two checks are needed:

- The certificate chain is validated against well-known certificates (i.e. Apple CA Root): this is the **authenticity** check.
- A signature is computed by using the certificate chain and compared to the one found in the container: this is the **integrity** check.

### The Payload

The [ASN.1][wikipedia-asn1] payload is defined by the following structure:

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
  Apple has published a list of public attributes that can be used to extract information from the receipt. You may also find unlisted attributes while parsing a receipt: do not care (mostly because they are reserved by Apple for future use).
- **The version field:** not used for now (by may be in the future).
- **The value field:** it contains the data as an array of bytes (even if its name may suggest it, *THIS IS NOT* a string).

The payload is encoded using [DER][wikipedia-x690-der] (Distinguished Encoding Rules) -- this kind of encoding provides an unequivocal and a compact result for [ASN.1][wikipedia-asn1] structures. [DER][wikipedia-x690-der] uses a pattern of [type-length-value][wikipedia-type-length-value] triplets, and uses byte constants for each type tags.


## Validation of receipt

The steps to validate a receipt are the following:

- Locate the receipt. If no receipt is found, then the validation fails.
- Verify the receipt authenticity and integrity. The receipt must be properly signed by Apple and not tampered with.
- Parse the receipt to extract attributes such as the bundle identifier, the bundle version, etc.
- Verify that the bundle identifier found inside the receipt matches the bundle identifier of the application. Do the same for the bundle version.
- Compute the hash of the GUID of the device. The computed hash is based on a device specific information.

### Locating the receipt

The location of the receipt differs between OS X and iOS as shown in the following figure:

**FIGURE GOES HERE**

- On OS X, the receipt file is located inside the application bundle, under the `Contents/_MASReceipt` folder.
- On iOS, the receipt file is located in the application's data sandbox, under the `StoreKit` folder.

Once located, you must ensure that the receipt is present.

- If the receipt exists at the right place, it can be loaded.
- If the receipt does not exist, this is considered as a validation failure.

On OS X 10.7 and later or iOS 7 and later, the code is straightforward:

```objectivec
// CODE GOES HERE
```

But if you target OS X 10.6, the `appStoreReceiptURL` selector is not available. Therefore, you have to manually build the URL to the receipt:

```objectivec
// CODE GOES HERE
```

### Loading the receipt

In Objective-C, the loading the receipt is pretty straightforward:

```objectivec
// CODE GOES HERE
```

### Verifying receipt signature

Once the receipt is loaded, the first thing to do is to make sure that the receipt is authentic and unaltered.

```objectivec
// CODE GOES HERE
```

### Parsing the receipt

Once the receipt envelop has been verified, it is time to parse the receipt payload. In order to parse DER encoded ASN.1 payload, you have several options:

- OpenSSL: it contains everything to encode/decode ASN.1 content from DER or PEM sources.
- asn1c: it is not a parser per se. It is a tool to generate parsing code from an ASN.1 definition. With the generated code, you can encode/decode ASN.1 content using several encodings.
- Writing you own code: even if the receipt structure is simple, writing a DER parser by hand is a lot of work.

```objectivec
// CODE GOES HERE
```

### Verifying receipt information

The receipt contains the bundle identifier and the bundle version for which the receipt was issued. You need to make sure that these information match the one you are expected. **DO NOT USE** the Info.plist for the comparison, as the file can be easily modified.

```objectivec
// CODE GOES HERE
```

### Computing GUID hash

When the receipt is issued, three values are used to generate a SHA-1 hash:

- the bundle identifier (the type 2 attribute)
- the device GUID (only available on the device)
- an opaque value (the type 4 attribute)

These three values are concatenated, a SHA-1 hash is computed and stored into the receipt (type 5 attribute).

During the validation, the same computation must be done. If the resulting hashes match, then the receipt is valid. The figure below summarizes the computation:

**FIFURE GOES HERE**

In order to do the hash computation, you need to retrieve the device GUID.

#### Getting the device GUID (OS X)

On OS X, the device GUID is the [MAC][wikipedia-mac-address] address of the primary network card. A way to retrieve it is to use the IOKit API:

```objectivec
// CODE GOES HERE
```

#### Getting the device GUID (iOS)

On iOS, the device GUID is an alphanumeric string that uniquely identifies the device, relative to the application's vendor:

```objectivec
// CODE GOES HERE
```
	
#### Hash computation

The hash computation must be done on the raw attribute values, i.e. the **value** field of the attribute.

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
This is why it is important to protect the code against attackers.

### Kind of attacks

Here are some common attacks that can be performed against your application to bypass or hack the receipt validation code:

- Strings replacement
- Shared library replacement
- Function override
- Function injection

### Best practices

While implementing receipt validation, there some rules to follow.
Here are a few things to keep in mind:

- Dos
 - Obfuscate strings
 - Obfuscate the result of receipt validation
 - Inline code as many as possible
 - Protect the code flow


- Don'ts
 - Don't use shared library
 - Don't use a separate code
 - Don't factor receipt validation
 - Don't underestimate the determination of attackers



## Conclusion

You are now familiar with receipt validation. You know the what lies behind and how important it is.




[rfc-2315]: https://www.ietf.org/rfc/rfc2315.txt
[itu-t-x690]: http://www.itu.int/ITU-T/recommendations/rec.aspx?id=9608
[wikipedia-asn1]: http://en.wikipedia.org/wiki/Abstract_Syntax_Notation_One
[wikipedia-x690-der]: http://en.wikipedia.org/wiki/X.690#DER_encoding
[wikipedia-type-length-value]: http://en.wikipedia.org/wiki/Type-length-value
[wikipedia-mac-address]: http://en.wikipedia.org/wiki/MAC_address
