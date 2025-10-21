# RFC-0003: HOPR Overview

- **RFC Number:** 0003
- **Title:** HOPR Overview
- **Status:** Draft
- **Author(s):** Tino Breddin (@tolbrino)
- **Created:** 2025-09-11
- **Updated:** 2025-09-11
- **Version:** v0.1.0 (Draft)
- **Supersedes:** none
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md),
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md),
  [RFC-0007](../RFC-0007-economic-reward-system/0007-economic-reward-system.md), [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md),
  [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md)

## 1. Abstract

This RFC provides an introductory overview of the HOPR network (also referred to as HOPRnet) and its protocol stack. HOPR is a decentralised,
incentivised mixnet that enables privacy-preserving communication by routing messages through multiple relay nodes using onion routing.

HOPR's key innovation is the proof-of-relay mechanism, which addresses the challenge of creating economically sustainable anonymous communication
networks. By combining cryptographic proofs with economic incentives, HOPR enables scalable privacy infrastructure that becomes stronger with increased
adoption, unlike volunteer-based networks that struggle with sustainability and performance issues.

This document serves as the primary entry point for understanding the HOPR ecosystem. It provides high-level architectural explanations and introduces
the core protocol components, whilst referencing individual RFCs for detailed implementation specifications. It is designed for researchers, developers,
and infrastructure providers who seek to understand or implement privacy-preserving communication solutions.

## 2. Motivation

In today's digital landscape, privacy-preserving communication is increasingly important for protecting user data, enabling free speech, and
maintaining confidentiality in business and personal communications. Traditional internet protocols provide insufficient privacy protection because
metadata and traffic patterns can be analyzed to reveal sensitive information about users and their communications.

HOPR addresses these privacy challenges by implementing a decentralized mixnet that:

- **Provides metadata privacy**: Unlike traditional networks that expose communication patterns, HOPR obscures sender-receiver relationships through
  traffic mixing and onion routing [01, 02]
- **Offers economic incentives**: node operators receive payment for relaying traffic, creating a sustainable ecosystem for privacy infrastructure
- **Ensures decentralization**: No single entity controls the network, preventing censorship and single points of failure
- **Maintains accessibility**: Applications can integrate privacy features without requiring users to understand complex cryptographic concepts

The HOPR protocol is designed to be transport-agnostic, allowing it to operate over standard internet infrastructures while providing strong privacy
guarantees. By combining proven cryptographic techniques with novel incentive mechanisms, HOPR creates a practical solution for privacy-preserving
communications at scale.

## 3. Terminology

For all terminology used in this document, including both general mixnet concepts and HOPR-specific terms, refer to
[RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md).

## 4. Network Overview

The HOPR network is a decentralised, peer-to-peer mixnet that provides privacy-preserving communication through multi-hop routing. The network
architecture consists of several key components that work together to ensure metadata privacy whilst incentivising participation through economic rewards.

### 4.1 Network Architecture

The HOPR network comprises different node roles based on their function in message routing:

- **Entry nodes**: nodes that initiate communication sessions and inject messages into the network
- **Relay nodes**: intermediate nodes that forward messages along routing paths and receive payment for their relay services
- **Exit nodes**: final relay nodes in a path that deliver messages to their intended destinations  
- **Payment infrastructure**: on-chain payment channels that enable efficient microtransactions between nodes without requiring a blockchain transaction
  for each payment

Every HOPR node can simultaneously act as an entry node, relay node, and exit node depending on the context of different message flows. The distinction
between these roles is functional rather than structural. A node's role at any given time will depend on that node's position within a specific routing path.

### 4.2 Path Construction

Messages in the HOPR network are routed through multi-hop paths to provide privacy protection. Path construction consists of three phases:

1. **Path discovery**: nodes discover available relay nodes through automated probing mechanisms detailed in
   [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md). This process identifies which nodes are reachable, reliable, and
   have open payment channels.
2. **Path selection**: senders choose routing paths based on multiple criteria, including privacy requirements, expected latency, relay costs, and node
   reliability. The selection algorithm balances these trade-offs according to application needs.
3. **Onion routing**: messages are encrypted in multiple layers using a modified version of the Sphinx packet format [02, 03], with each relay node able to decrypt only one layer to reveal the next hop whilst keeping the sender, final destination, and full path hidden.

### 4.3 Economic Incentives

The HOPR network employs economic incentives to ensure sustainable operation and encourage node participation:

- **Micropayments**: relay nodes receive small probabilistic payments for each message they forward. Payments are made through tickets that have a
  winning probability, enabling efficient micropayments without excessive on-chain transactions.
- **Proof of relay**: cryptographic proofs ensure that relay nodes actually forward messages before receiving payment. This mechanism is detailed in
  [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md) and prevents nodes from claiming payment without providing service.
- **Payment channels**: unidirectional payment channels between nodes enable efficient microtransactions without requiring each transaction to be written to a blockchain [04]. Channels are established on-chain but each allows for many off-chain payments, settling only periodically or when the channel closes.
- **Staking rewards**: nodes that stake tokens and maintain open payment channels receive additional rewards as described in
  [RFC-0007](../RFC-0007-economic-reward-system/0007-economic-reward-system.md). This creates incentives for network participation beyond per-message
  payments.

### 4.4 Privacy Properties

The network architecture provides several key privacy guarantees through its layered security approach:

- **Sender anonymity**: relay nodes cannot determine the original sender of a message due to onion routing. Each node only knows the immediate previous
  hop, not the ultimate source [05].
- **Receiver anonymity**: intermediate nodes cannot identify the final recipient of a message. Only the exit node knows the final destination, but not
  the original sender [05].
- **Unlinkability**: observers cannot link multiple messages from the same sender or to the same receiver [05]. Different messages may take different
  paths, and the encryption scheme prevents correlation.
- **Traffic analysis resistance**: random delays introduced by the mixer component ([RFC-0006](../RFC-0006-hopr-mixer/0006-hopr-mixer.md)) and packet
  mixing prevent timing correlation attacks [06]. This ensures that an observer cannot correlate incoming and outgoing packets based on timing patterns.

These properties hold even against an adversary who controls a large subset of the network nodes, provided at least one honest node exists in each routing
path.

## 5. Protocol Overview

The HOPR protocol stack consists of multiple layers that work together to provide privacy-preserving communication with economic incentives. This
section provides a high-level overview of the protocol components and their interactions.

### 5.1 Protocol Architecture

The HOPR protocol is organized into five layers, arranged as follows:

```
┌─────────────────────────────────────┐
│        Application Layer            │
├─────────────────────────────────────┤
│      Session Management Layer       │
├─────────────────────────────────────┤
│       HOPR Application Protocol     │
├─────────────────────────────────────┤
│        HOPR Packet Protocol         │
├─────────────────────────────────────┤
│        Transport Layer              │
└─────────────────────────────────────┘
```

From top to bottom, these layers provide the following functionalities:

**Application layer**: Support for applications and services
**Session management layer**: Session establishment and data transfer
**HOPR application protocol**: Message routing and protocol multiplexing
**HOPR packet protocol**: Onion routing and encryption
**Transport layer**: Network communication

### 5.2 Core Protocol Components

#### 5.2.1 HOPR Packet Protocol

The HOPR packet protocol ([RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)) defines the fundamental packet format and
processing rules that enable onion routing:

- **Onion encryption**: multi-layer encryption ensures that each relay node can decrypt only one layer to reveal the next hop's address, maintaining
  sender and destination anonymity throughout the routing process.
- **Sphinx-based design**: the HOPR packet format is based on the Sphinx packet format [03] with extensions for incentivisation. Sphinx provides compact headers and strong cryptographic guarantees about packet unlinkability.
- **Fixed packet size**: all packets have identical size (including header, payload, and proof-of-relay information) to prevent traffic analysis based on
  packet size [06]. To achieve this, variable-length messages are padded to the maximum size.
- **Single-use reply blocks (SURBs)**: SURBs enable recipients to send reply messages back to anonymous senders without knowing their identity, supporting bidirectional communication whilst preserving anonymity.

#### 5.2.2 Proof of Relay

The proof of relay mechanism ([RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md)) ensures that relay nodes actually forward packets before
receiving payment:

- **Cryptographic proofs**: each packet contains cryptographic challenges that can only be solved by a node that successfully delivers the packet to the
  next hop. The solution serves as mathematical proof that the relay service was performed.
- **Payment integration**: proofs are cryptographically bound to payment tickets. Relay nodes can only claim payment by presenting valid proofs,
  ensuring that compensation is tied to actual work performed.
- **Fraud prevention**: the mechanism detects and prevents attempts to claim payment without providing relay services. Invalid proofs are rejected,
  and repeated fraud attempts can result in channel closure and stake slashing.

#### 5.2.3 Traffic Mixing

The HOPR mixer ([RFC-0006](../RFC-0006-hopr-mixer/0006-hopr-mixer.md)) provides traffic analysis resistance through temporal mixing:

- **Temporal mixing**: introduces random delays to packets before forwarding, breaking timing correlations between incoming and outgoing packets [01,
  06]. This prevents attackers from linking packets based on timing patterns.
- **Configurable delays**: supports configurable minimum delay and delay range parameters, allowing nodes to balance privacy protection against latency
  requirements based on their threat model and application needs.
- **Per-packet randomisation**: each packet receives an independently generated random delay, ensuring that timing patterns cannot be exploited even when
  observing multiple packets.
  
The mixer operates as a priority queue ordered by release timestamps, efficiently managing packets even under high-load conditions.

#### 5.2.4 Session Management

Session protocols provide higher-level communication primitives on top of the basic packet transport:

- **Session establishment**: [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md) defines how nodes establish communication
  sessions with capability negotiation, session identifier exchange, and keep-alive mechanisms.
- **Data transfer**: [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md) provides both reliable and unreliable data transmission modes.
  Reliable mode includes acknowledgements, retransmissions, and in-order delivery, whilst unreliable mode offers lower latency for applications that can
  tolerate packet loss.
- **Message fragmentation**: sessions handle segmentation of large messages into multiple packets and reassembly at the destination, transparently
  managing the fixed packet size constraint.
- **Connection management**: session lifecycle management including error handling, timeout management, and graceful termination.

#### 5.2.5 Economic System

The economic reward system ([RFC-0007](../RFC-0007-economic-reward-system/0007-economic-reward-system.md)) incentivises network participation through
multiple mechanisms:

- **Staking rewards**: nodes that stake tokens receive rewards proportional to their stake, encouraging long-term network commitment and providing
  economic security.
- **Payment channels**: unidirectional payment channels enable efficient micropayments between nodes [04]. Channels are funded on-chain but support many
  off-chain transactions, minimising blockchain costs.
- **Fair distribution**: rewards are distributed equitably based on staked amounts and network participation, ensuring that nodes with open channels and
  good connectivity receive appropriate compensation.
- **Quality-of-service incentives**: the reward system considers node reliability and availability, incentivising operators to maintain high-quality
  service.

### 5.3 Protocol Flow

A typical message transmission through the HOPR network follows this flow:

1. **Path discovery**: the sender discovers available relay nodes through active probing and constructs a routing path based on network topology, channel
   availability, and performance metrics.
2. **Session establishment**: if reliable delivery or bidirectional communication is required, the sender establishes a session with the recipient using
   the session start protocol. For simple one-way messages, this step may be skipped.
3. **Packet construction**: the message (possibly fragmented into multiple packets) is encrypted in multiple layers using onion encryption. Each layer
   includes routing information for one hop and cryptographic challenges for proof of relay.
4. **Routing**: packets are forwarded through the selected path, with each relay node:
   - Removing one layer of encryption to reveal the next hop's address
   - Applying random delays through the mixer component
   - Solving cryptographic challenges to generate proofs of relay
   - Claiming payment tickets upon successful delivery to the next hop
5. **Delivery**: the exit node delivers the packet to the intended recipient, who can decrypt the final layer to access the message content.

### 5.4 Integration Points

The HOPR protocol provides multiple integration points to support various applications and use cases:

- **Application protocol**: [RFC-0011](../RFC-0011-application-protocol/0011-application-protocol.md) defines a lightweight multiplexing layer that
  allows multiple higher-level protocols to coexist over the HOPR packet transport, similar to port numbers in TCP/UDP.
- **Transport independence**: the protocol can operate over different network transports (TCP, UDP, QUIC, etc.), making it deployable in various network
  environments without requiring specific infrastructure.
- **API compatibility**: through the session protocols, HOPR provides familiar networking APIs (stream-based and datagram-based) to ease application
  integration and lower the barrier to adoption.
- **Extensibility**: the modular design allows for protocol extensions and improvements without breaking existing implementations. New features can be
  negotiated during session establishment through capability flags.

## 6. References

[01] Chaum, D. (1981). [Untraceable Electronic Mail, Return Addresses, and Digital Pseudonyms](https://www.freehaven.net/anonbib/cache/chaum-mix.pdf).
_Communications of the ACM, 24_(2), 84-90.

[02] Reed, M. G., Syverson, P. F., & Goldschlag, D. M. (1998).
[Anonymous Connections and Onion Routing](https://www.onion-router.net/Publications/JSAC-1998.pdf). _IEEE Journal on Selected Areas in Communications,
16_(4), 482-494.

[03] Danezis, G., & Goldberg, I. (2009). [Sphinx: A Compact and Provably Secure Mix Format](https://cypherpunks.ca/~iang/pubs/Sphinx_Oakland09.pdf).
_2009 30th IEEE Symposium on Security and Privacy_, 262-277.

[04] Poon, J., & Dryja, T. (2016).
[The Bitcoin Lightning Network: Scalable Off-Chain Instant Payments](https://lightning.network/lightning-network-paper.pdf). Lightning Network
Whitepaper.

[05] Pfitzmann, A., & Köhntopp, M. (2001).
[Anonymity, Unobservability, and Pseudonymity—A Proposal for Terminology](https://www.freehaven.net/anonbib/cache/terminology.pdf). In _Designing
Privacy Enhancing Technologies_ (pp. 1-9). Springer.

[06] Raymond, J. F. (2001).
[Traffic Analysis: Protocols, Attacks, Design Issues, and Open Problems](https://www.freehaven.net/anonbib/cache/raymond-thesis.pdf). In _Designing
Privacy Enhancing Technologies_ (pp. 10-29). Springer.
