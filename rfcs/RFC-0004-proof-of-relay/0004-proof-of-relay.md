# RFC-0004: Proof of Relay

- **RFC Number:** 0004  
- **Title:** Proof of Relay 
- **Status:** Implementation
- **Author(s):** Lukas Pohanka (@NumberFour8), Qianchen Yu (@QYuQianchen)
- **Created:** 2025/04/02  
- **Updated:** 2025/08/22  
- **Version:** v1.0.0 (Finalized)  
- **Supersedes:** N/A
- **References:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md), [RFC-0003](../RFC-0003-hopr-packet-protocol/0003-hopr-packet-protocol.md)

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
- **ADD(A,B)** represents an addition of two EC points `A` and `B` from the corresponding finite field.
- **Public key** refers to a non-identity EC group element (or its equivalent) of a large order.
- **Private key** refers to a scalar from a finite field of the chosen EC group. It represents a private key for a certain public key.
- **Hash `H(x)`** refers to a cryptographic hash function taking an input of any size, and returning a fixed length output. Security of `H`
against cryptographic attacks SHALL NOT be less than `L`.
- **Verifiable Random Function (VRF)** produces a pseudo-random value that is publicly verifiable but cannot be forged or precomputed.


## 3 Payment channels

Let A, B and C be peers participating in the mixnet. Each node is in possesion of its own private key (`Kpriv_A`, `Kpriv_B`, `Kpriv_C`)
and the corresponding public key (`P_A`, `P_B`, `P_C`). The public keys of participating nodes are publicly exposed.

Assume that node A wishes to communicate with node C, using node B as a relay.
Node A then opens a logical payment channel with node B (denoted A -> B), staking some funds into this channel. 
Such channel will hold the current balance and additional state information shared between A and B and is strictly directed in the direction A -> B.

For the purpose of this RFC, the amount of funds MUST be strictly greater than 0 and MUST be strictly less than 2^96.

There MUST NOT be more than a single payment channel between any two nodes A and B in this direction. Since
channel is uni-directional, there MAY BE channel A -> B and also B -> A at the same time.

Each channel has a unique channel ID, typically deterministic. 
The channel ID of the channel A -> B MAY be computed as a truncated version of `H(f(P_A)||f(P_B))` for efficient representation, where `||` stands for byte-wise concatenation.

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
In such state, the node A MUST NOT be allowed to communicate with C via B, and B MUST NOT be allowed to claim any unclaimed
rewards from the channel. 
The `balance` in the channel A -> B MUST be reset to `0` and its `channel_epoch` MUST be incremented by `1`.

At any point of time when the channel is at the state other than `CLOSED`, the channel destination B MAY unilaterally transition the 
channel A -> B to state `CLOSED`. 
Node B SHALL claim unclaimed rewards before the state transition, because any unclaimed rewards becomes unclaimable after
the state transit, resulting a lost for node B.


## 4 Ticket

Tickets are always created by a node that is the source (`A`) of an existing channel. It is created whenever `A` wishes to send a HOPR packet to a certain destination (`C`), while having the
existing channel's destination (`B`) act as a relay.

Their creation MAY happen at the same time as the HOPR packet, or MAY be precomputed in advance when usage of a certain path is known in-prior.

A Ticket:
1. MUST be tied (via a cryptographic challenge) to a single HOPR packet (from RFC-0003)
2. the cryptographic challenge MUST be solvable by the ticket recipient (`B`) once it delivers the corresponding HOPR packet to `C`
3. the solution of the cryptographic challenge MAY unlock a reward for ticket's recipient `B` at expense of `A`
4. MUST NOT contain information about packet's destination (`C`)

## 4.1 Ticket structure encoding

The Ticket has the following structure:

```
Ticket {
	channel_id: [u8; 20],
	amount: u96,
	index: u48,
	index_offset: u32,
	encoded_win_prob: [u8; 7],
	channel_epoch: u24,
	signature: ECDSASignature
}
```

All multi-byte unsigned integers MUST use the big-endian encoding when serialized.
The `ECDSASignature` uses the [ERC-2098 encoding](https://eips.ethereum.org/EIPS/eip-2098), the public key recovery bit is stored
in the most significant bit of the `r` value (which is guaranteed to be unused). Both `r` and `s` use big-endian encoding when serialized.

```
ECDSASignature {
	r: u256
	s: u256
}
```


## 4.2 Construction of Proof-of-Relay (PoR) secrets

### 4.2.1 Secret Sharing

In the PoR mechanism, a cryptographic secret is established between relay nodes and their adjacent nodes on the route.
The construction algorithm utilizes two key derivations:

* **HASH\_KEY\_ACK\_KEY**: Each node `n_i` derives `s_ack_i` from the shared secret (`s_i`) provided by the SPHINX packet. 
This secret acknowledgment key (`s_ack_{i+1}`) is held by the next downstream node (n_{i+1}) and sent as an acknowledgement upon successful packet delivery.
`s_ack_i = KDF("HASH_KEY_ACK_KEY", s_i)`

* **HASH\_KEY\_OWN\_KEY**: Each node ni also derives its own secret key (`s_own_i`) directly from the shared secret (`s_i`) provided by the SPHINX packet: `s_own_i = KDF("HASH_KEY_OWN_KEY", s_i)`

Both keys together form a 2-out-of-2 secret sharing scheme, wherein the relay node MUST possess both `s_own_i` and `s_ack_{i+1}` to reconstruct `s_response_i` and claim rewards.

### 4.2.2 Generation of Hint and Challenges

Hints and challenges are generated through elliptic curve operations:

* **Generation of Challenges**: Each challenge `C_i` is generated by combining the secrets derived from the node’s own key (`s_own_i`) and the next downstream node's acknowledgment key (`s_ack_{i+1}`):

  ```
  C_i = MUL(s_own_i + s_ack_{i+1}, G)
  ```

* **Generation of Hint**: To prove to the relay node that the challenge is valid and solvable, the sender generates a hint derived solely from the acknowledgment key (`s_ack_i+1`):

  ```
  hint_i = MUL(s_ack_{i+1}, G)
  ```

The relay node receiving the challenge and hint MUST verify the following condition immediately upon receipt:

```
ADD(MUL(s_own_i, G), hint_i) = C_i
```

This ensures the relay node is assured of the challenge’s solvability, thus validating the sender's possession of the necessary secrets.
This verification step confirms the challenge’s solvability without revealing `s_ack_{i+1}`, leveraging the infeasibility of inverting scalar multiplication on the chosen elliptic curve. 
The sender MUST embed `hint_i` within the SPHINX packet’s readable section for node `n_i`, enabling immediate validation of the embedded challenge.

### 4.3 Challenge Response

Each packet sent through the network includes a cryptographic challenge (`C_i`), derived from:

```
C_i = MUL(s_own_i + s_ack_{i+1}, G} = MUL(response_i, G)
```

where `G` is the base point on the elliptic curve used in the key exchange. 
Relay node B MUST solve this challenge (`response_i`) by combining both its own secret (`s_own_i`) and the secret acknowledgment key (`s_ack_{i+1}`) received from node C upon successful packet delivery.


## 5 Ticket and Channel interactions

### 5.1 Probablistic winning tickets

Probabilistic Payment Channels leverage probabilistic micropayments, reducing the number of on-chain transactions.
Payments are structured so that only a fraction (probability) results in an actual on-chain transfer, whereas most payments remain off-chain, 
significantly reducing transaction fees and maintaining privacy.

Probabilistic tickets issued between nodes have a consistent payout and do not require sequential processing or frequent on-chain operations.
The ticket winning probability is determined based on the anticipated throughput of the channel, allowing nodes with higher traffic 
to use lower winning probabilities and those with lower traffic to select probabilities closer to 1.
Both ticket issuer and receiver MUST NOT know the outcome (winning or losing) of the ticket before redemption to maintain fairness.

A ticket is a winner if:
```
keccak256(ticketHash || porSecret || vrfParams) < ticket.winProb
```
where
- `ticketHash` is the hash of the received ticket, known by both ticket issuer and recipient. 
- The `porSecret` is known by the ticket issuer and can be reconstructed by the ticket recipient as part of the PoR scheme upon receiving the acknowledgment for the forwarded ticket, as detailed in the next section. 
- The `vrfParams` refers to the deterministic pseudo-random value that is chosen by the ticket recipient, and is verifiable by using its public key. This value is unique for each ticket and adds entropy that can only be known by the ticket redeemer.

### 3.3 Verify winning tickets with VRF

The VRF verification algorithm for ticket validation is:

1. Compute `ticketHash` from the received ticket.
2. Generate pseudo-random curve point (`bX`, `bY`):
```
(bX, bY) = hashToCurve(signer || ticketHash, domainSeparator)
```
3. Execute elliptic curve operations:
```
sB = scalarMult(s, bX, bY)
hV = scalarMult(h, vx, vy)
R = sB - hV
```
Compute verification scalar (`hCheck`):
```
hCheck = hashToScalar(signer || vx || vy || Rx || Ry || ticketHash, domainSeparator)
```
Validate VRF proof by ensuring: `hCheck == h`


## References

Include all relevant references, such as:

- Other RFCs: RFC-0003 HOPR Packet Protocol
- External documentation: Coefficients used for simplified SWU mapping used by the hash to curve function: https://www.ietf.org/archive/id/draft-irtf-cfrg-hash-to-curve-16.html#name-suites-for-secp256k1
