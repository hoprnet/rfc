# RFC-0004: Proof of Relay

- **RFC Number:** 0004  
- **Title:** Proof of Relay 
- **Status:** Implementation
- **Author(s):** Lukas Pohanka (NumberFour8)
- **Created:** 2025/04/02  
- **Updated:** 2025/04/02  
- **Version:** v1.0.0 (Finalized)  
- **Supersedes:** N/A
- **References:** RFC-0002, RFC-0003

## Abstract

This RFC describes the structures and protocol for establishing a Proof of Relay (PoR) of HOPR packets
sent between two peers over a relay. In addition, such PoR can be used to unlock incentives for the node
relaying the packets to the destination.

## 1 Motivation

This RFC aims to solve the assurance of packet delivery between two peers inside a mixnet.
In particular, when data are sent from a sender (peer A), using
node B as a relay node, to deliver packet to the destination node C, the assurance is established
that:

1. node A has guarantees that node B delivered A's packets to node C
2. after successful relaying to C, node B posseses a cryptographic proof of the delivery
3. node B can use such proof to claim a reward from node A
4. the identity of node A is not revealed to node C


## 2 Terminology

This document builds upon standard terminology established in RFC-0002. Mentions to "HOPR packets" or
"mixnet packets" refer to a particular structure (`HOPR_Packet`) defined in RFC-0003.


In addition, this document also uses the following terms:

- **Channel (or Payment channel)**: a unidirectional directed relation of two parties (source node and destination node) that holds a monetary balance, that can be paid out by source to the destination, if certain conditions are met.

- **Ticket**: a structure that holds cryptographic material allowing probabilistic fund transfer within the Payment channel.

The above terms are formally defined in the following sections.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",
"MAY", and "OPTIONAL" in this document are to be interpreted as described
in [IETF RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).

### 2.1 Cryptographic and security parameters

The documents make use of certain cryptographic and mathematical terms. A security parameter `L` is chosen
and corresponding cryptographic primitives are used in a concrete instantiations of this RFC.
The speficic instantiation of the current version of this protocol is given in Appendix 1.

The security parameter `L` SHALL NOT be less than 2^128 - meaning the chosen cryptographic primitives
instantiations below SHALL NOT have less than 128-bits of security.

- **EC group** refers to a specific elliptic curve group over a finite field, where computational Diffie-Hellman problem is AT LEAST as
difficult as the chosen security parameter `L`. The elements of the field are denoted using lower-case letter, whereas the elements (also referred to as elliptic curve points, or EC points) of the EC group are denoted using upper-case letters.
- **MUL(a,B) (or simply a.B)** represents a multiplication of an EC point `B` by a scalar `a` from the corresponding finite field.
- **Public key** refers to a non-identity EC group element (or its equivalent) of a large order.
- **Private key** refers to a scalar from a finite field of the chosen EC group. It represents a private key for a certain public key.
- **Hash `H(x)`** referst to a cryptographic hash function taking an input of any size, and returning a fixed length output. Security of `H`
against cryptographic attacks SHALL NOT be less than `L`.



## 3 Payment channels

Let A, B and C be peers participating in the mixnet. Each node is in possesion of its own private key (`Kpriv_A`, `Kpriv_B`, `Kpriv_C`)
and the corresponding public key (`P_A`, `P_B`, `P_C`). The public keys of participating nodes are publicly exposed.

Assume that node A wishes to communicate with node C, using node B as a relay.
Node A then opens a logical payment channel with node B (denoted A -> B), staking some funds into this channel. 
Such channel will hold the current balance and additional state information shared between A and B and is strictly directed in the direction A -> B.

For the purpose of this RFC, the amount of funds MUST be strictly greater than 0 and MUST be strictly less than 2^96.

There MUST NOT be more than a single payment channel between any two nodes A and B in this direction. Since
channel is uni-directional, there MAY BE channel A -> B and also B -> A at the same time.


The channel MUST always be in one of the 3 logical states:

1. Open
2. Pending to close
3. Closed


Such state can be described using `ChannelStatus` enumeration:

````
ChannelStatus { OPEN, PENDING_TO_CLOSE, CLOSED }
````

There is a structure called `Channel` that MUST contain at least the following fields:

1. `source`: public key of the source node (A in this case)
2. `destination`: public key of the destination node (beneficiary, B in this case)
3. `balance` : an unsigned 96-bit non-zero integer
4. `ticket_index`: an unsigned 48-bit integer
5. `channel_epoch`: an unsigned 24-bit non-zero integer
6. `status`: one of the `ChannelStatus` values


````
Channel {
	source: [u8; |P_A|],
	destination: [u8; |P_B|],
	balance: [u8; 12]
	ticket_index: [u8; 6]
	channel_epoch: [u8; 3]
	status: ChannelStatus
}
````

Such structure is sufficient to describe the payment channel A -> B.

### 3.1 Payment channel life-cycle

A payment channel between nodes A -> B MUST always be initiated by node A. It MUST be initialized with a non-zero `balance`,
a `ticket_index` equal to `0`, `channel_epoch` equal to `1` and `status` equal to `Open`.

In such state, the node A is allowed communicate with node C via B and the node B can claim certain fixed amounts of `balance` to be paid out to it in return - as a reward for the relaying work. This will described in the later sections.

At any point in time, the channel initiator A can initiate a closure of the channel A -> B. Such transition MUST change
the `status` field to `PENDING_TO_CLOSE` and this change MUST be communicated to B.
In such state, the node A MUST NOT be allowed to communicate with C via B, but B MUST be allowed to still claim any unclaimed rewards from the channel. However, B MUST NOT be allowed to claim any rewards after a certain period `T_closure` has elapsed since the state transition.

After each claim is done by B, the `ticket_index` field MUST be incremented by 1, and such change MUST be communicated to both A and B.
The increment MAY be done by an independent trusted third party supervising the reward claims.

The initiator A SHALL transition the channel state to `CLOSED` (changing the `status` to `CLOSED`). Such transition MUST NOT be possible
before `T_closure` has elapsed. The transition MUST be communicated to B.
In such state, the 


## Design Considerations

Discuss critical design decisions, trade-offs, and justification for chosen approaches over alternatives.

## Compatibility

Address backward compatibility, migration paths, and impact on existing systems.

## Security Considerations

Identify potential security risks, threat models, and mitigation strategies.

## Drawbacks

Discuss potential downsides, risks, or limitations associated with the proposed solution.

## Alternatives

Outline alternative approaches that were considered and reasons for their rejection.

## Unresolved Questions

Highlight questions or issues that remain open for discussion.

## Future Work

Suggest potential areas for future exploration, enhancements, or iterations.

## References

Include all relevant references, such as:

- Other RFCs
- Research papers
- External documentation
