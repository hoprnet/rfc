# RFC-0002: Common mixnet terms and keywords

- **RFC Number:** 0002
- **Title:** Common mixnet terms and keywords
- **Status:** Raw
- **Author(s):** Tino Breddin (@tolbrino)
- **Created:** 2025-08-01
- **Updated:** 2025-08-01
- **Version:** v0.0.1 (Raw)
- **Supersedes:** none
- **References:** none

## 1. Abstract

This RFC provides a glossary of common terms and keywords related to mixnets and
the HOPR protocol specifically.
It aims to establish a shared vocabulary for developers, researchers, and users
involved in the HOPR project.

## 2. Motivation

The HOPR project involves a diverse community of people with different
backgrounds and levels of technical expertise. A shared vocabulary is essential
for clear communication and a common understanding of the concepts and
technologies used in the project. This RFC aims to provide a single source of
truth for the terminology used in the HOPR ecosystem.

## 3. Terminology

- **Node:** A process which implements the HOPR protocol and participates in
  the mixnet. Nodes can be run by anyone. A node can be a sender, destination or
  a relay node which helps to relay messages through the network [01, 02].

- **Sender:** The node that sends a message through the mixnet.
  This is typically an application which wants to send a message anonymously [01, 02].

- **Destination:** The node that receives a message sent through the mixnet [01, 02].

- **Peer**: A node that is connected to another node in the p2p network.
  Each peer has a unique identifier and can communicate with other peers.

- **Cover Traffic:** Dummy data packets that are introduced into the network to
  further obscure what's happening. These data packets can be generated on any
  node and are used to make it harder to distinguish between real user traffic
  and dummy traffic [01, 03].

- **Message Path:** The path a message takes through the mixnet. A path can be
  direct from sender to destination, or it can go through multiple hops (relay
  nodes) before reaching the destination [01, 02].

- **Relay Node:** A node that forwards messages from one node to another
  in the mixnet. Relay nodes help to obscure the sender's identity by routing
  messages through multiple nodes [01, 02].

- **Hop:** A relay node in the message path. E.g. a 0-hop message is sent
  directly from the sender to the destination, while a 1-hop message goes
  through one relay node before reaching the destination [01, 02]. More hops in
  the path generally increase the anonymity of the message, but also increase
  latency and cost.

- **Mix Nodes:** These are the proxy servers that make up the mixnet. They
  receive messages from multiple senders, shuffle them, and then send them back
  out in a random order [01].

- **Layered Encryption:** A technique where a message is wrapped in successive
  layers of encryption. Each intermediary node (or hop) can only decrypt its
  corresponding layer, revealing the next destination in the path [01, 04].

- **Metadata:** Data that provides information about other data. In the context
  of mixnets, this includes things like the sender's and receiver's IP
  addresses, the size of the message, and the time it was sent or received.
  Mixnets work to shuffle this metadata to protect user privacy [01, 06].

- **Onion Routing:** A technique for anonymous communication over a network. It
  involves encrypting messages in layers, analogous to the layers of an onion,
  which are then routed through a series of network nodes [04].

- **Public Key Cryptography:** A cryptographic system that uses pairs of keys:
  public keys, which may be disseminated widely, and private keys, which are
  known only to the owner. This is used to encrypt messages sent through the
  mixnet [01].

- **Sphinx:** A packet format that ensures unlinkability and layered encryption.
  It uses a fixed-size packet structure to resist traffic analysis [02].

- **Symmetric Encryption:** A type of encryption where the same key is used to both encrypt and decrypt data [05].

- **Traffic Analysis:** The process of intercepting and examining messages in
  order to deduce information from patterns in communication. Mixnets are
  designed to make traffic analysis very difficult [01].

## 4. References

[01] Chaum, D. (1981). [Untraceable Electronic Mail, Return Addresses, and Digital Pseudonyms](https://www.freehaven.net/anonbib/cache/chaum-mix.pdf). _Communications of the ACM, 24_(2), 84-90.

[02] Danezis, G., & Goldberg, I. (2009). [Sphinx: A Compact and Provably Secure Mix Format](https://cypherpunks.ca/~iang/pubs/Sphinx_Oakland09.pdf). _2009 30th IEEE Symposium on Security and Privacy_, 262-277.

[03] El-Atawy, A., & Al-Shaer, E. (2010). [A Survey on Mix Networks and Their Secure Applications](https://dl.acm.org/doi/10.1145/1749603.1749605). _ACM Computing Surveys (CSUR), 42_(4), 1-33.

[04] Reed, M. G., Syverson, P. F., & Goldschlag, D. M. (1998). [Anonymous Connections and Onion Routing](https://www.onion-router.net/Publications/JSAC-1998.pdf). _IEEE Journal on Selected Areas in Communications, 16_(4), 482-494.

[05] Shannon, C. E. (1949). [Communication Theory of Secrecy Systems](https://www.cs.ru.nl/~jhh/pub/secsem/shannon1949.pdf). _Bell System Technical Journal, 28_(4), 656-715.

[06] Tyagi, S., Ponomarev, D., & Shmatikov, V. (2019). [Distributed Differential Privacy via Mixnets](https://petsymposium.org/2019/files/papers/issue4/popets-2019-0069.pdf). _Proceedings on Privacy Enhancing Technologies, 2019_(4), 269-286.
