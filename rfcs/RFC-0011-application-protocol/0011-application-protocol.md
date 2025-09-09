# RFC-0011 Application Layer protocol

- **RFC Number:** 0011
- **Title:** Application Layer protocol
- **Status:** Draft
- **Author(s):** Lukas Pohanka (@NumberFour8)
- **Created:** 2025-08-22
- **Updated:** 2025-08-22
- **Version:** v0.1.0 (Draft)
- **Supersedes:** N/A
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md), [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md), [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md), [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md)

## 1. Abstract

This RFC describes the Application layer protocol used in the HOPR project. Typically, this protocol is used in between
the HOPR Packet protocol [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md) and some higher-level protocol, such as the Session protocol [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md)
or Start protocol [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md).
The goal of this protocol is for a HOPR node to make distinction between different protocol running on top of the HOPR packet protocol.

It can be seen similar to how standard TCP or UDP protocols distinguishes between applications using port numbers.

## 2. Motivation

The HOPR network supports multiple upper layer protocols that serve different purposes. Without a standardized method to distinguish between these protocols, nodes would be unable to properly route and handle packets intended for specific applications. The Application layer protocol solves this by providing a lightweight tagging mechanism similar to port numbers in TCP/UDP.

## 3. Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",
"MAY", and "OPTIONAL" in this document are to be interpreted as described
in [IETF RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) when, and only when, they appear in all
capitals, as shown here.

Terms defined in [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md) might be also used.

## 4. Introduction

The HOPR network can host multitude of upper layer protocols, that serve different purposes. Some of those are described in other RFCs, such as [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md), [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md) or [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md). The Application layer protocol described in this RFC creates a thin layer between the HOPR Packet protocol from [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md) and these upper layer protocols.

The Application layer protocol primarily serves two purposes:

1. node should be able to distinguish between upper protocols and dispatch their packets the respective protocol interpreters
2. create an inter-protocol communication link for signals between the HOPR Packet protocol and the upper layer protocol

## 5. Specification

The Application layer protocol acts as a wrapper to arbitrary upper layer `data` and adds a `Tag` that determineds the type of the upper-layer protocol:

```
ApplicationData {
	tag: Tag,
	data: [u8; <length>]
	flags: u8
}
```

The `Tag` itself MUST be represented by 64 bits and the 3 upper most significant bits MUST be always set to 0 in the current version.
The remaining 61 bits represent a unique identifier of the upper layer protocol.

The `Tag` range SHOULD be split as follows:

- `0x0000000000000000` identifies the Probing protocol (see [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md)).
- `0x0000000000000001` identifies the Start protocol (see [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md)).
- `0x0000000000000002` - `0x000000000000000d` identifies range for user protocols
- `0x000000000000000e` identifies a catch-all for unknown protocols
- `0x000000000000000f` - `0x1fffffffffffffff` identifes a space reserved for the Session protocol (see [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md)).

### 5.1 Wire format encoding

The individual fields of `ApplicationData` MUST be encoded in the following order:

1. `tag`: unsigned 8 bytes, big-endian order, the 3 most significant bits MUST be cleared
2. `data`: opaque bytes, the length MUST be most the size of the HOPR protocol packet, the upper layer protocol SHALL be responsible for the framing
3. `field`: MUST NOT be serialized, it is a transient, implementation-local, per-packet field

The upper layer protocol MAY use the 4 most significant bits in `flags` to pass arbitrary signaling to the HOPR Packet protocol.
Conversely, the HOPR packet protocol MAY use the 4 least significant bits in `flags` to pass arbibrary signalling to the upper-layer protocol.

The interpretation of `flags` is entirely implementation specific and MAY be ignored by either sides.

## 6. Appendix 1

### HOPR packet protocol signals in the current implementation

The version 1 of the HOPR packet protocol (as in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)) MAY currently pass the following signals to the upper-layer protocol:

1. `0x01`: SURB distress signal. Indicates that the level of SURBs at the counterparty has gone below a certain pre-defined threshold.
2. `0x03`: Out of SURBs signal. Indicates that the received packet has used the last SURB available to the Sender.

It is OPTIONAL for any upper-layer protocol to react to these signals if they are passed to them.

## 7. References

None.
