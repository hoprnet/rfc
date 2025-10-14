# RFC-0002: Common mixnet terms and keywords

- **RFC Number:** 0002
- **Title:** Common mixnet terms and keywords
- **Status:** Draft
- **Author(s):** Tino Breddin (@tolbrino)
- **Created:** 2025-08-01
- **Updated:** 2025-09-04
- **Version:** v0.1.0 (Draft)
- **Supersedes:** none
- **Related Links:** none

## 1. Abstract

This RFC provides a glossary of common terms and keywords related to mixnets and the HOPR protocol specifically. It aims to establish a shared
vocabulary for developers, researchers, and users involved in the HOPR project.

## 2. Motivation

The HOPR project involves a diverse community of people with different backgrounds and levels of technical expertise. A shared vocabulary is essential
for clear communication and a common understanding of the concepts and technologies used in the project. This RFC aims to provide a single source of
truth for the terminology used in the HOPR ecosystem.

## 3. Terminology

- _Mixnet_ (also known as a _Mix network_): a routing protocol that creates hard-to-trace communications by using a chain of proxy servers known
  as mixes, which take in messages from multiple senders, shuffle them, and send them back out in random order to the next destination.

- _node_: a process that implements the HOPR protocol and participates in the mixnet. Nodes can be run by anyone. A node can be a sender,
  destination, or a relay node that helps to relay messages through the network. Also referred to as "peer" [01, 02].

- _sender_: the node that initiates communication by sending out a packet through the mixnet. This is typically an application that wants to send a
  message anonymously [01, 02].

- _destination_: the node that receives a message sent through the mixnet. Also referred to as "receiver" in some contexts [01, 02].

- _peer_: a node that is connected to another node in the p2p network. Each peer has a unique identifier and can communicate with other peers. The
  terms "peer" and "node" are often used interchangeably.

- _Cover Traffic_: artificial data packets introduced into the network to obscure traffic patterns with adaptive noise. These data packets can be
  generated on any node and are used to make it harder to distinguish between real user traffic and dummy traffic [01, 03].

- _path_: the route a message takes through the mixnet, defined as a sequence of hops between sender and destination. A path can be direct from
  sender to destination, or it can go through multiple relay nodes before reaching the destination. Also referred to as "message path" [01, 02].

- _forward path_: a path that is used to deliver a packet only in the direction from the sender to the destination.

- _return path_: a path that is used to deliver a packet in the opposite direction to the forward path. The return path MAY be disjoint from the
  forward path.

- _relay node_: a node that forwards messages from one node to another in the mixnet. Relay nodes help to obscure the sender's identity by routing
  messages through multiple nodes [01, 02].

- _hop_: a relay node in the message path that is neither the sender nor the destination. For example, a 0-hop message is sent directly from the sender to
  the destination, while a 1-hop message goes through one relay node before reaching the destination. The terms "hop" and "relay" are often used
  interchangeably [01, 02]. More hops in the path generally increase the anonymity of the message, but also increase latency and cost.

- _mix nodes_: the proxy servers that make up the mixnet. They receive messages from multiple senders, shuffle them, and then send them
  back out in random order [01].

- _Layered Encryption_: a technique where a message is wrapped in successive layers of encryption. Each intermediary node (or hop) can only decrypt
  its corresponding layer, revealing the next destination in the path [01, 04].

- _Metadata_: data that provides information about other data. In the context of mixnets, this includes things such as the sender's and destination's
  IP addresses, the size of the message, and the time it was sent or received. Mixnets work to shuffle this metadata to protect user privacy [01, 06].

- _Onion Routing_: a technique for anonymous communication over a network. It involves encrypting messages in layers, analogous to the layers of an
  onion, which are then routed through a series of network nodes [04].

- _Public Key Cryptography_: a cryptographic system that uses pairs of keys: public keys, which may be disseminated widely, and private keys, which
  are known only to the owner. This is used to encrypt messages sent through the mixnet [01].

- _Sphinx_: a packet format that ensures unlinkability and layered encryption. It uses a fixed-size packet structure to resist traffic analysis
  [02].

- _Symmetric Encryption_: a type of encryption where the same key is used to both encrypt and decrypt data [05].

- _Traffic Analysis_: the process of intercepting and examining messages in order to deduce information from patterns in communication. Mixnets are
  designed to make traffic analysis very difficult [01].

- _forward message_: a packet that is sent along the forward path. Also referred to as "forward packet".

- _reply message_: a packet that is sent along the return path. Also referred to as "reply packet".

- _HOPR network_: the decentralised network of HOPR nodes that relay messages to provide privacy-preserving communications with economic incentives.

- _HOPR node_: a participant in the HOPR network that implements the full HOPR protocol stack and can send, receive, and relay messages while
  participating in the payment system.

- _session_: an established communication channel between two HOPR nodes for exchanging multiple messages with state management and reliability
  features.

- _proof of relay_: a cryptographic proof that demonstrates a HOPR node has correctly relayed a message and is eligible to receive payment for the
  relay service.

- _channel_: a payment channel between two HOPR nodes that enables efficient micropayments for relay services without requiring blockchain
  transactions for each payment.

- _mixer_: a HOPR protocol component that introduces random delays and batching to packets to break timing correlation attacks and enhance traffic
  analysis resistance.

## 4. References

[01] Chaum, D. (1981). [Untraceable Electronic Mail, Return Addresses, and Digital Pseudonyms](https://www.freehaven.net/anonbib/cache/chaum-mix.pdf).
_Communications of the ACM, 24_(2), 84-90.

[02] Danezis, G., & Goldberg, I. (2009). [Sphinx: A Compact and Provably Secure Mix Format](https://cypherpunks.ca/~iang/pubs/Sphinx_Oakland09.pdf).
_2009 30th IEEE Symposium on Security and Privacy_, 262-277.

[03] K. Sampigethaya and R. Poovendran, A Survey on Mix Networks and Their Secure Applications. Proceedings of the IEEE, vol. 94, no. 12, pp.
2142-2181, Dec. 2006.

[04] Reed, M. G., Syverson, P. F., & Goldschlag, D. M. (1998).
[Anonymous Connections and Onion Routing](https://www.onion-router.net/Publications/JSAC-1998.pdf). _IEEE Journal on Selected Areas in Communications,
16_(4), 482-494.

[05] Shannon, C. E. (1949). Communication Theory of Secrecy Systems. _Bell System Technical Journal, 28_(4), 656-715. DOI:
10.1002/j.1538-7305.1949.tb00928.x

[06] Cheu, A., Smith, A., Ullman, J., Zeber, D., & Zhilyaev, M. (2019, April). Distributed differential privacy via shuffling. In Annual international
conference on the theory and applications of cryptographic techniques (pp. 375-403). Cham: Springer International Publishing.
