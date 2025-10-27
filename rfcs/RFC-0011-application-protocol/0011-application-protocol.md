# RFC-0011: Application Layer protocol

- **RFC Number:** 0011
- **Title:** Application Layer protocol
- **Status:** Finalised
- **Author(s):** Lukas Pohanka (@NumberFour8)
- **Created:** 2025-08-22
- **Updated:** 2025-08-22
- **Version:** v1.0.0 (Finalised)
- **Supersedes:** none
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md),
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md),
  [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md),
  [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md)

## 1. Abstract

This RFC describes the HOPR application layer protocol, a thin multiplexing layer that sits between the HOPR packet protocol
[RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md) and higher-level protocols such as the session protocol
[RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md) or session start protocol
[RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md). The application protocol enables HOPR nodes to distinguish
between different upper-layer protocols running over the same packet transport, similar to how TCP and UDP use port numbers to multiplex multiple
applications over IP.

The protocol consists of a simple tagging mechanism using 64-bit identifiers, allowing up to 2^61 distinct protocol types whilst reserving space for
future extensions.

## 2. Motivation

The HOPR network supports multiple upper-layer protocols that serve different purposes, including session management, path discovery, and application
data transport. Without a standardised method to distinguish between these protocols, nodes would be unable to properly route and handle packets
intended for specific purposes. The application layer protocol solves this by providing a lightweight tagging mechanism similar to port numbers in
TCP/UDP, enabling protocol multiplexing over the fixed-size HOPR packet format.

Additionally, the protocol provides a bidirectional signalling mechanism through flag bits, allowing the packet layer and upper layers to exchange
control information (such as SURB availability notifications) without requiring separate packet types.

## 3. Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are
to be interpreted as described in [01] when, and only when, they appear in all capitals, as shown here.

Terms defined in [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md) might be also used.

## 4. Introduction

The HOPR network can host multiple upper-layer protocols that serve different purposes. Examples include session management
([RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md)), session establishment
([RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md)), and path discovery
([RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md)). The application layer protocol described in this RFC creates a thin
multiplexing layer between the HOPR packet protocol ([RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)) and these upper-layer
protocols.

The application layer protocol serves two primary purposes:

1. **Protocol multiplexing**: enabling a node to distinguish between different upper-layer protocols and dispatch packets to the appropriate protocol
   handlers based on protocol tags
2. **Inter-layer signalling**: providing a bidirectional communication channel for control signals between the HOPR packet protocol and upper-layer
   protocols through flag bits (e.g., SURB availability notifications)

## 5. Specification

The application layer protocol acts as a wrapper for arbitrary upper-layer `data`, adding a `Tag` that identifies the upper-layer protocol type:

```
ApplicationData {
	tag: Tag,           // 64-bit protocol identifier
	data: [u8; <length>]  // Variable-length protocol data
	flags: u8           // Control flags for inter-layer signalling
}
```

**Tag structure:**

The `Tag` MUST be represented by 64 bits, with the following structure:
- The 3 most significant bits MUST always be set to 0 in the current version (reserved for future use)
- The remaining 61 bits represent a unique identifier for the upper-layer protocol

This design provides 2^61 (approximately 2.3 × 10^18) possible protocol identifiers whilst reserving space for future protocol versioning or extensions.

**Protocol tag allocation:**

The `Tag` space is divided into ranges for different purposes:

- `0x0000000000000000`: reserved for the probing protocol (path discovery, see
  [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md))
- `0x0000000000000001`: reserved for the session start protocol (session establishment, see
  [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md))
- `0x0000000000000002` – `0x000000000000000d`: available for user-defined protocols (12 tags)
- `0x000000000000000e`: catch-all for unknown or experimental protocols
- `0x000000000000000f` – `0x1fffffffffffffff`: reserved for the session protocol (approximately 2^61 - 15 tags, see
  [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md))

This allocation ensures that core HOPR protocols have well-known identifiers whilst providing space for custom protocols and future extensions.

### 5.1 Wire format encoding

The individual fields of `ApplicationData` MUST be encoded in the following order:

1. `tag`: unsigned 8 bytes, big-endian order, the 3 most significant bits MUST be cleared
2. `data`: opaque bytes, the length MUST be at most the size of the HOPR protocol packet, the upper layer protocol SHALL be responsible for the framing
3. `field`: MUST NOT be serialised, it is a transient, implementation-local, per-packet field

The upper layer protocol MAY use the 4 most significant bits in `flags` to pass arbitrary signalling to the HOPR packet protocol. Conversely, the HOPR
packet protocol MAY use the 4 least significant bits in `flags` to pass arbitrary signalling to the upper-layer protocol.

The interpretation of `flags` is entirely implementation specific and MAY be ignored by either side.

## 6. Appendix 1

### HOPR packet protocol signals in the current implementation

The version 1 of the HOPR packet protocol (as in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)) MAY currently pass the
following signals to the upper-layer protocol:

1. `0x01`: SURB distress signal. Indicates that the level of SURBs at the counterparty has gone below a certain pre-defined threshold.
2. `0x03`: Out of SURBs signal. Indicates that the received packet has used the last SURB available to the sender.

It is OPTIONAL for any upper-layer protocol to react to these signals if they are passed to them.

## 7. References

[01] Bradner, S. (1997). [Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119). _IETF RFC 2119_.
