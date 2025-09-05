# RFC-0007: Session Data Protocol

- **RFC Number:** 0007
- **Title:** Session Data Protocol
- **Status:** Draft
- **Author(s):** Tino Breddin (@tolbrino)
- **Created:** 2025-08-15
- **Updated:** 2025-08-20
- **Version:** v0.1.0 (Draft)
- **Supersedes:** N/A
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md), [RFC-0003](../RFC-0003-hopr-packet-protocol/0003-hopr-packet-protocol.md), [RFC-0012](../RFC-0012-session-start-protocol/0012-session-start-protocol.md)

## 1. Abstract

This RFC specifies the HOPR Session Data Protocol, which provides reliable and unreliable data transmission capabilities over the HOPR mixnet. The protocol implements TCP-like [01] features including message segmentation, reassembly, acknowledgement, and retransmission while maintaining simplicity and efficiency. This protocol works in conjunction with the HOPR Session Start Protocol (see RFC-0012) to provide complete session management capabilities for applications within the HOPR mixnet ecosystem.

## 2. Motivation

The HOPR mixnet uses HOPR packets (see RFC-0003) to send data between nodes. This fundamental packet sending mechanisms however works, similar to UDP [03], as a fire-and-forget mechanisms and does not provide any higher-level features any application developer would expect. To ease adoption a HOPR node needs a way for existing applications to use it without having to implement TCP [01] or UDP all over again.
Since HOPR protocol is not IP-based, such implementation would require IP protocol emulation.

The HOPR Session Data Protocol fills that gap by providing reliable and unreliable data transmission capabilities to applications. Session establishment and lifecycle management is handled by the HOPR Session Start Protocol (see RFC-0012), while this protocol focuses exclusively on data transmission.

## 3. Terminology

- **Frame**: A logical unit of data transmission in the Session Protocol. Frames can be of arbitrary length and are identified by a unique Frame ID.

- **Segment**: A fixed-size fragment of a frame. Frames are split into segments for transmission, with each segment carrying metadata about its position within the frame.

- **Frame ID**: A 32-bit unsigned integer that uniquely identifies a frame within a session (1-indexed).

- **Sequence Number (SeqNum)**: An 8-bit unsigned integer indicating a segment's position within its frame (0-indexed).

- **Sequence Indicator (SeqIndicator)**: An 8-bit value. FIXME: add spec

- **Session Socket**: The endpoint abstraction that implements the Session Protocol, available in both reliable and unreliable variants.

- **MTU (Maximum Transmission Unit)**: The maximum size of a single HOPR protocol message, denoted as `C` throughout this specification.

- **Terminating Segment**: A special segment that signals the end of a frame.

- **Terminating Frame**: A special frame that signals the end of a session.

## 4. Specification

### 4.1 Protocol Overview

The HOPR Session Data Protocol operates at version 1 and consists of three message types that work together to provide reliable or unreliable data transmission:

1. **Segment Messages**: Carry actual data fragments
2. **Retransmission Request Messages**: Request missing segments
3. **Frame Acknowledgement Messages**: Confirm successful frame receipt

The protocol supports two operational modes:

- **Unreliable Mode**: Fast, stateless operation similar to UDP [03]
- **Reliable Mode**: Stateful operation with acknowledgements and retransmissions

Session establishment and lifecycle management is handled by the HOPR Session Start Protocol.

### 4.2 Session Data Protocol Message Format

All Session Data Protocol messages follow a common structure:

```mermaid
packet
title "Common Structure"
+8: "Version"
+8: "Type"
+16: "Length"
+32: "Payload (variable-length)"
+32: "..."
```

- **Version** (1 byte): Protocol version, MUST be 0x01 for version 1
- **Type** (1 byte): Message type discriminant
  - 0x00: Segment
  - 0x01: Retransmission Request
  - 0x02: Frame Acknowledgement
- **Length** (2 bytes): Big-endian payload length in bytes (max 2047)
- **Payload** (variable): Message-specific data

### 4.3 Segment Message

#### 4.3.1 Segment Structure

```mermaid
packet
title "Segment"
+32: "Frame ID"
+8: "Sequence Index"
+8: "Sequence Flags"
+48: "Segment Data (variable-length)"
+32: "..."
```

- **Frame ID** (4 bytes): Big-endian frame identifier (MUST be > 0)
- **Sequence Index** (1 byte): Segment position within frame (0-based)
- **Sequence Flags** (1 byte):
  - Bit 7: Termination flag (1 = terminating segment)
  - Bit 6: Reserved (MUST be 0)
  - Bits 0-5: Total segments in frame minus 1 (max value: 63)
- **Segment Data** (variable): payload data

#### 4.3.2 Segmentation Rules

1. Frames MUST be segmented when larger than `(C - 10)` bytes, where 10 is the segment overhead
2. Maximum segments per frame is 64 (limited by 6-bit sequence length field)
3. Each segment except the last SHOULD be of equal size
4. Empty segments MUST be valid (this is used e.g. for terminating segments)
5. Frame IDs MUST be monotonically increasing within a Session

### 4.4 Retransmission Request Message

#### 4.4.1 Request Structure

```mermaid
packet
title "Retransmission Request Message"
+32: "Frame ID 1"
+8: "Missing Bitmap 1"
+32: "Frame ID 2"
+8: "Missing Bitmap 2"
+32: "Frame ID 3"
+8: "Missing Bitmap 3"
+32: "..."
```

The message contains a sequence of 5-byte entries:

- **Frame ID** (4 bytes): Big-endian frame identifier
- **Missing Bitmap** (1 byte): Bitmap of missing segments
  - Bit N set = segment N is missing (N: 0-7)

The above message MUST be used only for Frames with up to 7 Segments (due to the bitmap size limitation).
Since this message is used only with _reliable_ Sessions, the number of Segments per Frame MUST be limited to 7.
The _unreliable_ Sessions SHOULD not have this limitation.

#### 4.4.2 Request Rules

1. Entries MUST be ordered by Frame ID (ascending)
2. Frame ID of 0 indicates padding (ignored)
3. Maximum entries per message: `(C - 4) / 5`
4. Only the first 8 segments per frame can be requested

### 4.5 Frame Acknowledgement Message

#### 4.5.1 Acknowledgement Structure

```mermaid
packet
title "Frame Acknowledgement Message"
+32: "Frame ID 1"
+32: "Frame ID 2"
+32: "Frame ID 3"
+32: "..."
```

- Contains a list of 4-byte Frame IDs that have been fully received
- Frame IDs MUST be in ascending order
- Frame ID of 0 indicates padding (ignored)
- Maximum frame IDs per message: `(C - 4) / 4`

### 4.6 Protocol State Machines

#### 4.6.1 Unreliable Socket State Machine

```mermaid
stateDiagram-v2
    [*] --> Active: new
    Active --> Active: write_frame
    Active --> Active: read_frame
    Active --> Terminated: receive_terminating
    Active --> Terminated: send_terminating
    Terminated --> [*]
```

#### 4.6.2 Reliable Socket State Machine

```mermaid
stateDiagram-v2
    [*] --> Active: new
    Active --> Active: write_frame
    Active --> Active: read_frame
    Active --> Active: send_ack
    Active --> Active: receive_ack
    Active --> Active: send_request
    Active --> Active: receive_request
    Active --> Active: retransmit
    Active --> Closing: send_terminating
    Active --> Closing: receive_terminating
    Closing --> Terminated: acks_complete
    Terminated --> [*]
```

### 4.7 Timing and Reliability Parameters

#### 4.7.1 Unreliable Mode

- No acknowledgements or retransmissions
- Frames may be delivered out-of-order
- No delivery guarantees
- Suitable for real-time or loss-tolerant applications

#### 4.7.2 Reliable Mode

- **Frame Timeout**: Default 800ms before requesting retransmission
- **Acknowledgement Window**: Max 255 unacknowledged frames
- **Retransmission Limit**: Implementation-defined (suggested: 3)
- **Acknowledgement Batching**: Delayed up to 100ms for efficiency

### 4.8 Session Termination

1. Either party MAY send a terminating segment (empty segment with termination flag set)
2. Upon receiving a terminating segment:
   - Unreliable sockets SHOULD close immediately
   - Reliable sockets MUST complete pending acknowledgements before closing
3. No data frames MUST be sent after a terminating segment

### 4.9 Example Message Exchanges

#### 4.9.1 Simple Frame Transmission (Unreliable Mode)

Sending a 300-byte frame with MTU=256 (246 bytes available per segment after 10-byte overhead):

```mermaid
sequenceDiagram
    participant S as Sender
    participant R as Receiver
    
    S->>R: Segment(frame_id=1, seq_idx=0, seq_flags=0b00000001, data[246])
    S->>R: Segment(frame_id=1, seq_idx=1, seq_flags=0b00000001, data[54])
```

#### 4.9.2 Frame with Retransmission (Reliable Mode)

Reliable transmission where the middle segment is lost and retransmitted:

```mermaid
sequenceDiagram
    participant S as Sender
    participant R as Receiver
    
    S->>R: Segment(frame_id=1, seq_idx=0, seq_flags=0b00000010, data[246])
    S-xR: Segment(frame_id=1, seq_idx=1, seq_flags=0b00000010, data[246]) - LOST
    S->>R: Segment(frame_id=1, seq_idx=2, seq_flags=0b00000010, data[100])
    
    R->>S: RetransmissionRequest(frame_id=1, missing_bitmap=0b00000010)
    S->>R: Segment(frame_id=1, seq_idx=1, seq_flags=0b00000010, data[246]) - RETRANSMITTED
    R->>S: FrameAcknowledgement(frame_ids=[1])
```

#### 4.9.3 Multiple Frame Acknowledgement (Reliable Mode)

Efficiently acknowledging multiple received frames in a batch:

```mermaid
sequenceDiagram
    participant S as Sender
    participant R as Receiver
    
    S->>R: Segment(frame_id=10, seq_idx=0, seq_flags=0b00000000, data[200])
    S->>R: Segment(frame_id=11, seq_idx=0, seq_flags=0b00000000, data[150])
    S->>R: Segment(frame_id=12, seq_idx=0, seq_flags=0b00000000, data[100])
    
    R->>S: FrameAcknowledgement(frame_ids=[10, 11, 12])
```

#### 4.9.4 Session Termination (Reliable Mode)

Graceful session termination with acknowledgement:

```mermaid
sequenceDiagram
    participant S as Sender
    participant R as Receiver
    
    S->>R: Segment(frame_id=5, seq_idx=0, seq_flags=0b00000000, data[100])
    S->>R: Segment(frame_id=6, seq_idx=0, seq_flags=0b10000000, data[])
    R->>S: FrameAcknowledgement(frame_ids=[5, 6])
```

#### 4.9.5 Session Termination (Unreliable Mode)

Immediate session termination without acknowledgement:

```mermaid
sequenceDiagram
    participant S as Sender
    participant R as Receiver
    
    S->>R: Segment(frame_id=7, seq_idx=0, seq_flags=0b10000000, data[])
```

## 5. Design Considerations

### 5.1 Maximum Segments Limitation

The protocol limits frames to 64 segments due to the 6-bit sequence length field. This provides a good balance between:

- Frame size flexibility (up to 64 × MTU)
- Protocol overhead (1 byte for sequence information)
- Implementation complexity (simple bitmap for retransmissions)

### 5.2 Frame ID Space

The 32-bit Frame ID space allows for over 4 billion frames per session. Frame IDs MUST be monotonically increasing to enable:

- Duplicate detection
- Out-of-order delivery handling
- Simple state management

The Session MUST terminate when Frame ID of 0 is encountered by the receiving side, indicating an overflow.

### 5.3 Retransmission Request Design

Limiting retransmission requests to the first 8 segments per frame:

- Keeps message format simple (1-byte bitmap)
- Covers the common case (most frames have ≤8 segments)
- Frames requiring >8 segments can use smaller frame sizes

### 5.4 Protocol Overhead

- Minimum overhead per segment: 10 bytes (4 header + 6 segment header)
- Maximum protocol efficiency: (C - 10) / C
- For C = 1024: ~99% efficiency
- For C = 256: ~96% efficiency

## 6. Compatibility

### 6.1 Version Compatibility

- Version 1 is the initial Session Data protocol version
- Future versions MUST use different version numbers
- Implementations MUST reject messages with unknown versions
- Version negotiation is out of scope for this specification

### 6.2 Transport Requirements

- Requires bidirectional communication channel
- No assumptions about ordering or reliability

## 7. Security Considerations

### 7.1 Protocol Security

- The protocol provides NO encryption or authentication
- Security MUST be provided by the underlying transport
- Frame IDs are predictable and MUST NOT be used for security

## 8. Future Work

- Enhanced acknowledgement schemes for better efficiency
- Forward error correction for high-loss environments

## 9. Implementation Notes

### 9.1 Testing Recommendations

- Test with various MTU sizes (256, 512, 1024, 1500, 9000)
- Simulate packet loss, reordering, and duplication
- Verify termination handling under all conditions
- Stress test with maximum frame sizes and counts

## 10. References

[01] Postel, J. (1981). [Transmission Control Protocol](https://datatracker.ietf.org/doc/html/rfc793). _IETF RFC 793_.

[02] Bormann, C. & Hoffman, P. (2013). [Concise Binary Object Representation (CBOR)](https://datatracker.ietf.org/doc/html/rfc7049). _IETF RFC 7049_.

[03] Postel, J. (1980). [User Datagram Protocol](https://datatracker.ietf.org/doc/html/rfc768). _IETF RFC 768_.
