# RFC-0003: HOPR Overview

- **RFC Number:** 0003
- **Title:** HOPR Overview
- **Status:** Draft
- **Author(s):** Tino Breddin (@tolbrino)
- **Created:** 2025-09-11
- **Updated:** 2025-09-11
- **Version:** v0.1.0 (Draft)
- **Supersedes:** none
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md), [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md), [RFC-0007](../RFC-0007-economic-reward-system/0007-economic-reward-system.md), [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md), [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md)

## 1. Abstract

This RFC provides a introductary overview of the HOPR network (sometimes referred to as HOPRnet) and protocol stack. HOPR is a decentralized, incentivized mixnet that enables privacy-preserving communication by routing messages through multiple relay nodes.

HOPR's innovation includes the proof-of-relay mechanism, which solves challenge of creating economically sustainable anonymous communication networks. HOPR enables scalable privacy infrastructure that grows stronger with increased adoption, unlike volunteer-based networks that struggle with sustainability and performance.

This document serves as the primary entry point for understanding the HOPR ecosystem, providing detailed architectural explanations while referencing specialized RFCs for implementation-specific details. It targets researchers, developers, and infrastructure providers seeking to understand or implement privacy-preserving communication solutions.

## 2. Motivation

In today's digital landscape, privacy-preserving communication is increasingly important for protecting user data, enabling free speech, and maintaining confidentiality in business and personal communications. Traditional internet protocols provide insufficient privacy protection, as metadata and traffic patterns can be analyzed to reveal sensitive information about users and their communications.

HOPR addresses these privacy challenges by implementing a decentralized mixnet that:

- **Provides metadata privacy**: Unlike traditional networks that expose communication patterns, HOPR obscures sender-receiver relationships through traffic mixing and onion routing
- **Offers economic incentives**: Node operators receive payment for relaying traffic, creating a sustainable ecosystem for privacy infrastructure
- **Ensures decentralization**: No single entity controls the network, preventing censorship and single points of failure
- **Maintains accessibility**: Applications can integrate privacy features without requiring users to understand complex cryptographic concepts

The HOPR protocol is designed to be transport-agnostic, allowing it to operate over standard internet infrastructures while providing strong privacy guarantees. By combining proven cryptographic techniques with novel incentive mechanisms, HOPR creates a practical solution for privacy-preserving communications at scale.

## 3. Terminology

For all terminology used in this document, including both general mixnet concepts and HOPR-specific terms, refer to [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md).

## 4. Network Overview

The HOPR network is a decentralized, peer-to-peer network that provides privacy-preserving communication. The network architecture consists of several key components working together to ensure metadata privacy and incentivize participation.

### 4.1 Network Architecture

The HOPR network is composed of:

- **Entry Nodes**: Nodes that initiate communication sessions and send messages into the network
- **Relay Nodes**: Intermediate nodes that forward messages along routing paths and receive payment for their services
- **Exit Nodes**: Final relay nodes that deliver messages to their intended destinations
- **Payment Infrastructure**: On-chain payment channels that enable microtransactions between nodes

### 4.2 Path Construction

Messages in the HOPR network are routed through multi-hop paths to provide privacy protection:

1. **Path Discovery**: Nodes discover available relay nodes through automated mechanisms detailed in [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md)
2. **Path Selection**: Senders choose routing paths based on privacy requirements, latency, and cost considerations
3. **Onion Routing**: Messages are encrypted in multiple layers, with each relay node able to decrypt only the information necessary to forward the message to the next hop

### 4.3 Economic Incentives

The HOPR network uses economic incentives to ensure sustainable operation:

- **Micropayments**: Relay nodes receive small payments for each message they forward
- **Proof of Relay**: Cryptographic proofs ensure that relay nodes actually forward messages before receiving payment
- **Payment Channels**: Direct payment channels between nodes enable efficient microtransactions without high blockchain fees

### 4.4 Privacy Properties

The network architecture provides several privacy guarantees:

- **Sender Anonymity**: Relay nodes cannot determine the original sender of a message
- **Receiver Anonymity**: Intermediate nodes cannot identify the final recipient
- **Unlinkability**: Observers cannot link multiple messages from the same sender or to the same receiver
- **Traffic Analysis Resistance**: Random delays and packet mixing prevent timing correlation attacks

## 5. Protocol Overview

The HOPR protocol stack consists of multiple layers that work together to provide privacy-preserving communication with economic incentives. This section provides a high-level overview of the protocol components and their interactions.

### 5.1 Protocol Architecture

The HOPR protocol is organized into several layers:

```
┌─────────────────────────────────────┐
│        Application Layer            │  ← Applications and Services
├─────────────────────────────────────┤
│      Session Management Layer       │  ← Session establishment and data transfer
├─────────────────────────────────────┤
│       HOPR Application Protocol     │  ← Message routing and protocol multiplexing
├─────────────────────────────────────┤
│        HOPR Packet Protocol         │  ← Onion routing and encryption
├─────────────────────────────────────┤
│        Transport Layer              │  ← Network communication
└─────────────────────────────────────┘
```

### 5.2 Core Protocol Components

#### 5.2.1 HOPR Packet Protocol

The HOPR Packet Protocol ([RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)) defines the fundamental packet format and processing rules:

- **Onion Encryption**: Multi-layer encryption that allows each relay node to decrypt only the information needed to forward the packet
- **Sphinx-based Design**: Based on the Sphinx packet format with extensions for incentivization
- **Fixed Packet Size**: All packets have the same size to prevent traffic analysis based on packet size

#### 5.2.2 Proof of Relay

The Proof of Relay mechanism ([RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md)) ensures that relay nodes actually forward packets:

- **Cryptographic Proofs**: Mathematical proofs that a node has correctly processed and forwarded a packet
- **Payment Integration**: Proofs are required before relay nodes receive payment for their services
- **Fraud Prevention**: Detects and prevents nodes from claiming payment without providing relay services

#### 5.2.3 Traffic Mixing

The HOPR Mixer ([RFC-0006](../RFC-0006-hopr-mixer/0006-hopr-mixer.md)) provides traffic analysis resistance:

- **Temporal Mixing**: Introduces random delays to break timing correlations
- **Batching**: Groups packets together before forwarding to obscure traffic patterns
- **Configurable Strategies**: Multiple mixing strategies for different privacy/latency trade-offs

#### 5.2.4 Session Management

Session protocols provide higher-level communication primitives:

- **Session Establishment**: [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md) defines how nodes establish communication sessions
- **Data Transfer**: [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md) provides reliable and unreliable data transmission modes
- **Connection Management**: Session lifecycle management and error handling

#### 5.2.5 Economic System

The economic reward system ([RFC-0007](../RFC-0007-economic-reward-system/0007-economic-reward-system.md)) incentivizes participation:

- **Token Economics**: Native token rewards for staked funds
- **Payment Channels**: Efficient micropayment infrastructure
- **Fair Distribution**: Ensures equitable reward distribution based amount of staked funds

### 5.3 Protocol Flow

A typical message transmission through the HOPR network follows this flow:

1. **Path Discovery**: Sender discovers available relay nodes and constructs a routing path
2. **Session Establishment**: If required, sender establishes a session with the recipient
3. **Packet Construction**: Message is encrypted in multiple layers and packaged into HOPR packets
4. **Routing**: Packets are forwarded through the selected path, with each relay node:
   - Decrypting one layer to reveal the next hop
   - Applying traffic mixing delays
   - Generating proofs of relay
   - Receiving micropayments for the service
5. **Delivery**: Final relay node delivers the packet to the intended recipient

### 5.4 Integration Points

The HOPR protocol is designed to support various applications and use cases:

- **Application Protocol**: [RFC-0011](../RFC-0011-application-protocol/0011-application-protocol.md) defines how higher-level protocols can utilize HOPR services
- **Transport Independence**: Protocol can operate over different network transports (TCP, UDP, etc.)
- **API Compatibility**: Through Sessions familiar networking APIs are provided to ease application integration
- **Extensibility**: Modular design allows for protocol extensions and improvements

## 6. References

TODO: any references needed?
