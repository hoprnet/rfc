# RFC-0002: Common mixnet terms and keywords

- **RFC Number:** 0002
- **Title:** Common mixnet terms and keywords
- **Status:** Raw
- **Author(s):** \<Tino Breddin (tino@hoprnet.org)\>
- **Created:** \<2025-08-01\>
- **Updated:** \<2025-08-01\>
- **Version:** v0.0.1 (Raw)
- **Supersedes:** none
- **References:** none

## Abstract

This RFC provides a glossary of common terms and keywords related to mixnets and
the HOPR protocol specifically.
It aims to establish a shared vocabulary for developers, researchers, and users
involved in the HOPR project.

## Motivation

The HOPR project involves a diverse community of people with different
backgrounds and levels of technical expertise. A shared vocabulary is essential
for clear communication and a common understanding of the concepts and
technologies used in the project. This RFC aims to provide a single source of
truth for the terminology used in the HOPR ecosystem.

## Terminology

- **Node:** A process which implements the HOPR protocol and participates in 
  the mixnet. Nodes can be run by anyone. A node can be a sender, destination or
  a relay node which helps to relay messages through the network [1, 2].

- **Sender:** The node that sends a message through the mixnet.
  This is typically an application which wants to send a message anonymously [1, 2].

- **Destination:** The node that receives a message sent through the mixnet [1, 2].

- **Peer**: A node that is connected to another node in the p2p network.
  Each peer has a unique identifier and can communicate with other peers.

- **Cover Traffic:** Dummy data packets that are introduced into the network to
  further obscure what's happening. These data packets can be generated on any
  node and are used to make it harder to distinguish between real user traffic
  and dummy traffic [1, 3].

- **Message Path:** The path a message takes through the mixnet. A path can be
  direct from sender to destination, or it can go through multiple hops (relay
  nodes) before reaching the destination [1, 2].

- **Relay Node:** A node that forwards messages from one node to another
  in the mixnet. Relay nodes help to obscure the sender's identity by routing
  messages through multiple nodes [1, 2].

- **Hop:** A relay node in the message path. E.g. a 0-hop message is sent
  directly from the sender to the destination, while a 1-hop message goes
  through one relay node before reaching the destination [1, 2]. More hops in
  the path generally increase the anonymity of the message, but also increase 
  latency and cost.

- **Mix Nodes:** These are the proxy servers that make up the mixnet. They
  receive messages from multiple senders, shuffle them, and then send them back
  out in a random order [1].

- **Layered Encryption:** A technique where a message is wrapped in successive
  layers of encryption. Each intermediary node (or hop) can only decrypt its
  corresponding layer, revealing the next destination in the path [1, 4].

- **Metadata:** Data that provides information about other data. In the context
  of mixnets, this includes things like the sender's and receiver's IP
  addresses, the size of the message, and the time it was sent or received. 
  Mixnets work to shuffle this metadata to protect user privacy [1, 6].

- **Onion Routing:** A technique for anonymous communication over a network. It
  involves encrypting messages in layers, analogous to the layers of an onion,
  which are then routed through a series of network nodes [4].

- **Public Key Cryptography:** A cryptographic system that uses pairs of keys:
  public keys, which may be disseminated widely, and private keys, which are
  known only to the owner. This is used to encrypt messages sent through the
  mixnet [1].

- **Sphinx:** A packet format that ensures unlinkability and layered encryption.
  It uses a fixed-size packet structure to resist traffic analysis [2].

- **Symmetric Encryption:** A type of encryption where the same key is used to both encrypt and decrypt data [5].

- **Traffic Analysis:** The process of intercepting and examining messages in
  order to deduce information from patterns in communication. Mixnets are
  designed to make traffic analysis very difficult [1].

## References

1. Chaum, D. (1981). Untraceable Electronic Mail, Return Addresses, and Digital Pseudonyms. *Communications of the ACM, 24*(2), 84-90.
2. Danezis, G., & Goldberg, I. (2009). Sphinx: A Compact and Provably Secure Mix Format. *2009 30th IEEE Symposium on Security and Privacy*, 262-277.
3. El-Atawy, A., & Al-Shaer, E. (2010). A Survey on Mix Networks and Their Secure Applications. *ACM Computing Surveys (CSUR), 42*(4), 1-33.
4. Reed, M. G., Syverson, P. F., & Goldschlag, D. M. (1998). Anonymous Connections and Onion Routing. *IEEE Journal on Selected Areas in Communications, 16*(4), 482-494.
5. Shannon, C. E. (1949). Communication Theory of Secrecy Systems. *Bell System Technical Journal, 28*(4), 656-715.
6. Tyagi, S., Ponomarev, D., & Shmatikov, V. (2019). Distributed Differential Privacy via Mixnets. *Proceedings on Privacy Enhancing Technologies, 2019*(4), 269-286.
