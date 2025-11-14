# RFC-0005: Proof of Relay

- **RFC Number:** 0005
- **Title:** Proof of Relay
- **Status:** Finalised
- **Author(s):** Lukas Pohanka (@NumberFour8), Qianchen Yu (@QYuQianchen)
- **Created:** 2025-04-02
- **Updated:** 2025-10-27
- **Version:** v1.0.0 (Finalised)
- **Supersedes:** none
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md),
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)

## 1. Abstract

This RFC describes the structures and protocol for establishing a Proof of Relay (PoR) for HOPR packets sent between two peers via a relay node. The
PoR mechanism provides cryptographic proof that a relay node has successfully delivered a packet to its destination, which can then be used to claim
payment for the relay service. This solves the fundamental challenge of incentivising relay nodes in a trustless manner whilst preserving sender
anonymity.

## 2. Motivation

The Proof of Relay mechanism addresses the challenge of ensuring reliable packet delivery in a privacy-preserving mixnet with economic incentives. When
a sender (peer A) uses node B as a relay to deliver a packet to destination node C, the mechanism establishes that:

1. Node A has cryptographic guarantees that node B delivered A's packet to node C
2. After successful relaying to C, node B possesses a cryptographic proof of delivery
3. Node B can use this proof to claim a reward from node A through a payment channel
4. The identity of node A remains hidden from node C, preserving sender anonymity

Without such a mechanism, relay nodes could claim payment without actually forwarding packets, or senders would have to trust relay nodes without
verification. The PoR mechanism makes the payment conditional on proof of actual relay service, creating a trustless, incentive-compatible system.

## 3. Terminology

This document builds upon standard terminology established in [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md). References to "HOPR
packets" or "mixnet packets" refer to a particular structure (`HOPR_Packet`) defined in
[RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md).

In addition, this document defines the following proof-of-relay-specific terms:

- **Channel** (or **Payment channel**): a unidirectional relation between two parties (source node and destination node) that holds a monetary
  balance. The source can pay out funds to the destination when certain conditions are met (specifically, when valid proof-of-relay tickets are
  presented).
- **Ticket**: a cryptographic structure that enables probabilistic fund transfer within a payment channel. Tickets contain challenges that must be solved
  by the relay node to prove packet delivery.
- **DomainSeparator**: a unique identifier that binds cryptographic signatures to a specific execution context (contract address, chain ID, etc.) to
  prevent replay attacks across different domains where the channel ledger may be deployed.
- **Notice period (T_closure)**: the minimum elapsed time required for an outgoing channel to transition from the `PENDING_TO_CLOSE` state to the `CLOSED`
  state. This period allows relay nodes to claim pending rewards before channel closure.

The above terms are formally defined in the following sections.

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are
to be interpreted as described in [01].

### 3.1. Cryptographic and security parameters

This document uses certain cryptographic and mathematical terms. A security parameter `L` is defined, and corresponding cryptographic
primitives are instantiated to achieve this security level. The specific instantiation for the current version of this protocol is provided in
Appendix 1.

The security parameter `L` SHALL NOT be less than 2^128, meaning the chosen cryptographic primitive instantiations SHALL provide at least
128 bits of security against known attacks.

The following cryptographic primitives are required:

- **EC group**: a specific elliptic curve `E` group over a finite field, where the computational Diffie-Hellman problem has hardness at least
  equal to the security parameter `L`. Field elements are denoted using lowercase letters, whilst elliptic curve points (EC points) are denoted using
  uppercase letters.
- **MUL(a,B)**: scalar multiplication of an EC point `B` by a scalar `a` from the corresponding finite field.
- **ADD(A,B)**: addition of two EC points `A` and `B` on the elliptic curve.
- **Public key**: a non-identity EC group element of large order, used to identify a node and establish shared secrets.
- **Private key**: a scalar from the finite field of the chosen EC group, corresponding to a public key. Must be kept secret.
- **Hash `H(x)`**: a cryptographic hash function taking an input of any size and returning a fixed-length output. The security of `H` against
  preimage, collision, and second-preimage attacks SHALL be at least `L` bits.
- **Verifiable random function (VRF)**: a function that produces a pseudo-random value along with a proof of correct computation. The output is publicly
  verifiable but cannot be forged or precomputed without the secret key.

Nodes and clients MUST implement handling for each of the above to ensure compliance and fault tolerance within the HOPR PoR protocol.

The concrete choices of the above cryptographic primitives for the implementation of version 1.0 are given in Appendix 1.

## 4. Payment channels

Payment channels are the foundation of the HOPR incentive mechanism. They enable efficient micropayments between nodes without requiring a blockchain
transaction for each packet relayed.

Let A, B, and C be peers participating in the mixnet. Each node possesses its own private key (`Kpriv_A`, `Kpriv_B`, `Kpriv_C`) and the
corresponding public key (`P_A`, `P_B`, `P_C`). Public keys are publicly exposed to enable packet routing and shared secret establishment.

The public keys MUST be from an elliptic curve cryptosystem represented by elliptic curve `E`.

When node A wishes to communicate with node C using node B as a relay, node A opens a unidirectional payment channel with node B (denoted A ->
B), depositing funds into this channel on-chain. The channel holds the current balance and additional state information shared between A and B, and funds
flow strictly in the direction A -> B.

 MUST be strictly greater than 0 and strictly less than 2^96 (to fit within the ticket structure's amount field).

There MUST NOT be more than one payment channel between any two nodes A and B in a given direction. Since channels are unidirectional, there MAY
simultaneously exist both a channel A -> B and a channel B -> A.

Each channel has a unique, deterministic identifier: the channel ID. The channel ID for A -> B MUST be computed as:
`channel_id = H(f(P_A)||f(P_B))` where `||` denotes byte-wise concatenation and `f` represents a deterministic encoding function for public keys
(typically compressed EC point encoding). This construction is directional: the source node's public key appears first, followed by the destination node's
public key.

Channels transition through three distinct lifecycle states:

1. **OPEN**: the channel is active and can be used for packet relay payments
2. **PENDING_TO_CLOSE**: the channel is in the process of closing; nodes can still claim pending rewards during the notice period
3. **CLOSED**: the channel is permanently closed; no further operations are possible

These states can be represented using the `ChannelStatus` enumeration:

```
ChannelStatus { OPEN, PENDING_TO_CLOSE, CLOSED }
```

There is a structure called `channel` that MUST contain at least the following fields:

1. `source`: public key of the source node (A in this case)
2. `destination`: public key of the destination node (beneficiary, B in this case)
3. `balance` : an unsigned 96-bit integer
4. `ticket_index`: an unsigned 48-bit integer
5. `channel_epoch`: an unsigned 24-bit non-zero integer
6. `status`: one of the `ChannelStatus` values

```
Channel {
	source: [u8; |P_A|],
	destination: [u8; |P_B|],
	balance: u96,
	ticket_index: u48,
	channel_epoch: u24,
	status: ChannelStatus
}
```

Such structure is sufficient to describe the payment channel A -> B.

Channels are uniquely identified by the `channel_id` above. The fixed‑length byte string returned by the function is called `ChannelId`.

### 4.1. Payment channel life-cycle

A payment channel between nodes A -> B MUST always be initiated by node A. It MUST be initialised with a non-zero `balance`, a `ticket_index` equal to
`0`, `channel_epoch` equal to `1` and `status` equal to `Open`. To prevent spamming, the funding `balance` MUST be larger than `MIN_USED_BALANCE` and
smaller than `MAX_USED_BALANCE`.

In such state, the node A is allowed to communicate with node C via B and the node B can claim certain fixed amounts of `balance` to be paid out to it in
return - as a reward for the relaying work. This will be described in the later sections.

At any point in time, the channel initiator A can initiate a closure of the channel A -> B. Such transition MUST change the `status` field to
`PENDING_TO_CLOSE` and this change MUST be communicated to B. In such state, the node A MUST NOT be allowed to communicate with C via B, but B MUST be
allowed to still claim any unclaimed rewards from the channel. However, B MUST NOT be allowed to claim any rewards after `T_closure` has elapsed since
the transition to PENDING_TO_CLOSE. `T_closure` MUST be measured in block timestamps, and both parties MUST derive it from the same source.

After each claim is done by B, the `ticket_index` field MUST be incremented by 1, and such change MUST be communicated to both A and B. The increment
MAY be done by an independent trusted third party supervising the reward claims.

The initiator A SHALL transition the channel state to `CLOSED` (changing the `status` to `CLOSED`). Such transition MUST NOT be possible before
`T_closure` has elapsed. The transition MUST be communicated to B. In such state, the node A MUST NOT be allowed to communicate with C via B, and B
MUST NOT be allowed to claim any unclaimed rewards from the channel. The `balance` in the channel A -> B MUST be reset to `0` and its `channel_epoch`
MUST be incremented by `1`.

At any point in time when the channel is at the state other than `CLOSED`, the channel destination B MAY unilaterally transition the channel A -> B to
state `CLOSED`. Node B SHALL claim unclaimed rewards before the state transition, because any unclaimed rewards become unclaimable after the state
transition, resulting in a loss for node B. To prevent spamming, the reward amount MUST be larger than `MIN_USED_BALANCE` and smaller than
`MAX_USED_BALANCE`.

## 5. Tickets

Tickets are always created by a node that is the source (`A`) of an existing channel. It is created whenever `A` wishes to send a HOPR packet to a
certain destination (`C`), while having the existing channel's destination (`B`) act as a relay.

Their creation MAY happen at the same time as the HOPR packet, or MAY be precomputed in advance when usage of a certain path is known beforehand.

A ticket:

1. MUST be tied (via a cryptographic challenge) to a single HOPR packet (from
   [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md))
2. the cryptographic challenge MUST be solvable by the ticket recipient (`B`) once it delivers the corresponding HOPR packet to `C`
3. the solution of the cryptographic challenge MAY unlock a reward for ticket's recipient `B` at expense of `A`
4. MUST NOT contain information about packet's destination (`C`)

### 5.1. Ticket structure encoding

The ticket has the following structure:

```
Ticket {
	channel_id: ChannelId,
	amount: u96,
	index: u48,
	index_offset: u32,
	encoded_win_prob: u56,
	channel_epoch: u24,
	challenge: ECPoint,
	signature: ECDSASignature
}
```

All multi-byte unsigned integers MUST use big-endian encoding when serialised.

The `ECPoint` is an encoding of an Elliptic curve point on the chosen curve `E` that corresponds to a cryptographic challenge. Such challenge is later
solved by the ticket recipient once it forwards the attached packet to the next downstream node.

The encoding (for serialization) of the `ECPoint` MUST be unique and MAY be irreversible, in the sense that the original elliptic point on the curve
`E` is not recoverable, but the encoding uniquely identifies the said point.

The `ECDSASignature` SHOULD use the [ERC-2098 encoding](https://eips.ethereum.org/EIPS/eip-2098), the public key recovery bit is stored in the most
significant bit of the `s` value (which is guaranteed to be unused). Both `r` and `s` use big-endian encoding when serialised.

```
ECDSASignature {
	r: u256
	s: u256
}
```

The ECDSA signature of the ticket MUST be computed over the [EIP‑712](https://eips.ethereum.org/EIPS/eip-712) hash `H_ticket` of the `ticket`
typed-data using `domainSeparator` (`dst`):

```
H_1 = H(channel_id || amount || index || index_offset || channel_epoch || encoded_win_prob || challenge)
H_2 = H(0xfcb7796f00000000000000000000000000000000000000000000000000000000 || H_1)`
H_ticket = H(0x1901 || dst || H_2)
```

The `ticket` signature MUST be done over the same elliptic curve `E` using the private key of the ticket creator (issuer).

### 5.2. Construction of Proof-of-Relay (PoR) secrets

This section uses terms defined in Section 2.2 in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), namely the
`SharedSecret_i` generated for the `i`-th node on the path (`i` ranges from 0 (sender node) up to `n` (destination node), i.e. `n` is equal to the path
length). Note that for 0-hop path (a direct packet from sender to destination), `n` = 1.

In the PoR mechanism, a cryptographic secret is established between relay nodes and their adjacent nodes on the route.

Upon packet creation, the sender node creates two structures:

1. the list of `ProofOfRelayString_i` for each `i`-th node on the path for i > 0 up to `n-1`. For `n=1`, the list will be empty
2. the `ProofOfRelayValues` structure

Each `ProofOfRelayString_i` contains the `challenge` for the ticket for the `i+1`-th node and the `hint` value for the same node. The `hint` value is
later used by the `i+1`-th node to validate that the `challenge` is not bogus, before it delivers the packet to the next hop.

Due to this later verification, the `hint` MUST use an encoding useful for EC group computations on `E` (here denoted as `RawECPoint`).

```
ProofOfRelayString_i {
	challenge: ECPoint,
	hint: RawECPoint
}
```

The `ProofOfRelayValues` structure contains the `challenge` and `hint` to the first relayer on the path, plus it MUST contain information about the
path length. This information is later used to set the correct price of the first ticket.

Path length MUST always be less than 4 (i.e. maximum 3 hops).

```
ProofOfRelayValues {
	challenge: ECPoint,
	hint: RawECPoint,
	path_len: u8
}
```

#### 5.2.1. Creation of Proof of Relay strings and values

Let `HS` be the Hash to Field operation defined in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md) over the field of the
chosen `E`.

The generation process of `ProofOfRelayString_i` proceeds as follows for each `i` from 0 to `n-1`:

1. The `SharedKey_i+1_ack` is derived from the shared secret (`SharedSecret_i`) provided during the HOPR packet construction. `SharedKey_i+1_ack`
   denotes the secret acknowledgement key for the next downstream node (`i+1`).
   - if `i` < `n` : `SharedKey_i+1_ack = HS(SharedKey_i, "HASH_KEY_ACK_KEY")`
   - if `i` = `n` : the `SharedKey_i+1_ack` MUST be generated as a uniformly random byte-string with the byte-length of `E`'s field elements.
2. The own shared secret `SharedKey_i_own` from `SharedSecret_i` is generated as: `SharedKey_i_own = HS(SharedKey_i, "HASH_KEY_OWN_KEY")`
3. The `hint` value is computed:

   - if `i` = 0: `hint = HS(SharedKey_0, "HASH_KEY_ACK_KEY")`
   - if `i` > 0: `hint = SharedKey_i+1_ack` (from step 1)

4. For `i` > 0, the `ProofOfRelayString_i` is composed and added to the list:

   - `challenge` is computed as: `challenge = MUL(SharedKey_i_own + SharedKey_i+1_ack, G)` and encoded as `ECPoint`
   - `hint` is used from step 3.

5. For `i` = 0, the `ProofOfRelayValues` is created:
   - `challenge` is computed as: `challenge = MUL(SharedKey_i_own + SharedKey_i+1_ack, G)` and encoded as `ECPoint`
   - `hint` is used from step 3.
   - `path_length` is set to `n`

### 5.3 Creation of the ticket for the first relayer

The first ticket MUST be created by the packet Sender and MUST contain the `challenge` field equal to the `challenge` in the `ProofOfRelayValues` from
the previous step.

#### Multi-hop ticket: for `n` > 1

In this situation, the `Channel` between the Sender and the next hop MUST exist and be in the `OPEN` state.

1. The field `channel_id` MUST be set according to the `Channel` leading from the Sender to the first packet relayer.

2. The `amount` field SHOULD be set according to an expected packet price times the number of hops on the path (that is `n` - 1).

3. The `index` field MUST be set to the `ticket_index` + 1 from the corresponding `Channel`.

4. The `index_offset` MUST be set to 1 in the current implementation.

5. The `encoded_win_prob` SHOULD be set according to the expected ticket winning probability in the network.

6. The `channel_epoch` MUST be set to the `channel_epoch` from the corresponding `Channel`.

#### Zero-hop ticket: `n` = 1

This is a specific case when the packet is 0-hop (`n` = 1, it is sent directly from the Sender to the Recipient). If the `Channel` between the Sender
and Recipient does exist, it MUST be ignored.

The `Ticket` is still created:

1. The `channel_id` MUST be set to `H(P_S || P_R)` where `P_S` and `P_R` are public keys (or their encoding) of Sender and Recipient respectively.

2. The `amount`, `index` and `channel_epoch` MUST be 0

3. The `index_offset` MUST be 1

4. The `encoded_win_prob` MUST be set to a value equivalent to the 0 winning probability

In any case, once the `Ticket` structure is complete, it MUST be signed by the Sender, who MUST be always the first ticket's issuer.

As described in Section 2.5 in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), the complete encoded `Ticket` structure
becomes part of the outgoing `HOPR_Packet`.

### 5.4. Ticket processing at a node

This is inherently part of the packet processing from the [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md). Once a node
receives a `HOPR_Packet` structure, the `Ticket` is separated and its processing is a two-step process:

1. The ticket is pre-verified (this is already mentioned in section 4.4 of RFC 0003).
2. If the packet is to be forwarded to a next node, the ticket MUST be fully-verified
   - If successful, the ticket is replaced with a new ticket in the `HOPR_Packet` for the next hop

#### 5.4.1. Ticket pre-verification

Failure to validate in any of the verification steps MUST result in discarding the ticket and the corresponding `HOPR_Packet`, and interrupting the
processing further.

If the extracted `Ticket` structure cannot be deserialised, the corresponding `HOPR_Packet` MUST be discarded. If the `Ticket` has been issued for an
unknown channel, or it does not correspond to the channel between the packet sender and the node where it is being processed, or the channel is in the
`CLOSED` state, the corresponding `HOPR_Packet` MUST be discarded.

At this point, the node knows its `SharedSecret_i` with which it is able to decrypt the `HOPR_Packet` and the `ProofOfRelayString_i` has already been
extracted from the packet header (see section 4.2 in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)).

1. `SharedSecret_i` is used to derive `SharedSecret_i_own` as per Section 4.2.1
2. The `hint` is extracted from the `ProofOfRelayString_i`
3. Compute `challenge_check = ADD(SharedSecret_i_own, hint)`
4. The `HOPR_Packet` MUST be rejected if encoding of `challenge_check` does not match `challenge` from the `Ticket`

If the pre-verification fails at any point, it still applies that the discarded `HOPR_Packet` MUST be acknowledged (as per section 4.2.3.1).

#### 5.4.2. Ticket validation and replacement

Let `corr_channel` be the `Channel` that corresponds to the `channel_id` on the `Ticket`. This channel MUST exist and not be in the `CLOSED` state per
previous section, otherwise the entire `HOPR_Packet` has been discarded.

If the packet is to be forwarded (as per section 4.3.1 in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)), the `Ticket`
MUST be verified as follows:

1. the `signature` of the `Ticket` is verified - if the signature uses ERC-2098 encoding, the ticket issuer from the signature is recovered and
   compared to the public key of the packet sender (or its representation)
2. the `amount` MUST be checked, so that it is greater than some given minimum ticket amount (this SHOULD be done with respect to the path position)
3. the `channel_epoch` on the `Ticket` MUST be the current epoch of the `corr_channel`.
4. it MUST be checked that the packet sender has enough funds to cover the `amount` of the ticket

Once the above verifications have passed, verified ticket is stored as _unacknowledged_ by the node and SHOULD be indexed by `hint`. The stored
unacknowledged tickets are dealt with later (see 4.2.3).

A new `Ticket` for the packet forwarded to the next hop MUST be created.

The `HeaderPrefix` from the packet header contains the current path position. This information is further used to determine which type of ticket to
create.

The path position is used to derive the number of remaining hops.

If the number of remaining hops is > 1, it MUST be checked if a `Channel` for the next hop exists from the current node, and if it is in the `OPEN`
state. If not, the corresponding `HOPR_Packet` is discarded and the process is interrupted.

The process of `Ticket` creation from section 4.3 then applies, either with the `Channel` as the next hop channel in a multi-hop ticket (if the number
of remaining hops > 1), or creates a zero-hop ticket if the number of remaining hops is 1.

The following applies in addition to 4.3:

- the `amount` on the ticket in the multi-hop case MAY be adjusted (typically the `amount` from the previous ticket is diminished by the packet price)
- the `challenge` MUST be set to `challenge` from the `ProofOfRelayString_i` extracted from the `HOPR_Packet`

If the ticket validation fails at any point, it still applies that the discarded `HOPR_Packet` MUST be acknowledged (as per section 4.2.3.1).

#### 5.2.3. Ticket acknowledgement

The following sections first describe how acknowledgements are created when sent back to the original packet's sender, and secondly how a received
acknowledgement should be processed.

##### 5.2.3.1. Sending acknowledgement

Per section 4.3.3 in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), each packet without `NoAckFlag` set MUST be
acknowledged. Such an acknowledgement becomes a payload of a 0-hop packet sent from the original packet's recipient to the original packet's sender.

```
Acknowledgement {
	ack_secret: ECScalar,
	signature: ECDSASignature
}
```

There are two possibilities for how the `ack_secret` field is calculated:

1. if the `HOPR_Packet` being acknowledged has been successfully processed (along with a successfully validated ticket), the `ack_secret` MUST be
   calculated as:

`ack_secret = HS(SharedSecret_i, "HASH_KEY_ACK_KEY")`

This EC field element MUST be encoded as a big-endian integer (denoted as `ECScalar`).

2. if the processing of the `HOPR_Packet` failed for any reason (either failure of the packet processing in
   [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md) or during packet pre-verification or validation from Section 5.2):
   `ack_secret` is set to a random EC point on `E`.

The `signature` field contains the signature of the encoded `ack_secret` bytes. The signature is done over `H(ack_secret)` using the private key of the
acknowledging party. For this purpose, the same EC cryptosystem for signing and verification as with `Ticket` SHOULD be used. The same encoding MUST be used for the `signature` field as for the `Ticket`.

##### 5.2.3.2. Receiving an acknowledgement

After the `Ticket` has been extracted and validated by the relay node, it awaits until the packet acknowledgement is received back from the next hop.
The node SHOULD discard tickets that haven't been acknowledged for a certain given period of time.

Once an `Acknowledgement` is received, the node MUST:

1. validate the `signature` of `ack_secret`. If invalid, the `Acknowledgement` MUST be discarded.
2. decode `ack_secret` and calculate `hint = MUL(ack_secret, G)`

The node then searches for a previously stored _unacknowledged_ `Ticket` with the corresponding `hint` as index.

- If a `Ticket` with corresponding `hint` is found, it MUST be marked as _acknowledged_ and the `ack_secret` is then the missing part in the solution
  of the cryptographic challenge on that `Ticket` (which corresponds to the packet that has just been acknowledged).

Let `SharedSecret_i_own` be the value from 1) in Section 5.2.1. The `response` to the `Ticket` challenge corresponding to the acknowledged packet is:

`response = ack_secret + SharedSecret_i_own`

The response is a field element of `E`.

- If no matching `Ticket` was found, the received `Acknowledgement` SHOULD be discarded.

##### 5.2.3.3. Derivation of VRF parameters for an Acknowledged ticket

Once the ticket becomes acknowledged, the node then calculates the `vrf_V` value, which will be useful to determine if the ticket is suitable for value
extraction.

Let `HC(msg, ctx)` be a suitable Hash to Curve function for `E`, where `msg` is an arbitrary binary message, `ctx` is a domain separator and whose
output is a point on `E`. See Appendix 1 for a concrete choice of `HC`.

Let `P` be the ticket recipient's public key in the EC cryptosystem on `E`.

Let `a` be the corresponding private key as field element of `E`.

The field element MUST be representable as an unsigned big-endian integer so that it can be used e.g. as an input to a hash function `H`. Similarly, `P`
MUST be representable in an "uncompressed" form when given to a hash function as input.

Let `H_P` be an irreversible byte-representation of `P`.

Let `H_ticket` be the hash of a previously acknowledged ticket as per section 4.1.

Let `R` be a sequence of 64 uniformly randomly generated bytes using a CSPRNG.

```
B = HC(H_P || H_ticket, dst)
V = MUL(a, B)
r = HS(a || v || R, dst)
R_v = MUL(r, B)
h = HS(P || V || R_v || H_ticket)
s = r + h * a
```

The `vrf_V` is the uncompressed representation of the EC point `V` as `X || Y`, where `X` and `Y` are big-endian unsigned integer representation of
the EC point's coordinates.

## 6 Ticket and Channel interactions

### 6.1. Discovering acknowledged winning tickets

The acknowledged tickets are _probabilistic_ in the sense that the monetary value represented by the `amount` MUST be claimable only if the acknowledged
ticket is _winning_. This is determined using the `encoded_win_prob` field on the `Ticket`.

Let `luck` be an unsigned 56-bit integer in the big-endian encoding created by truncating the output of the following hash output:

`H(H_ticket || response || vrf_V)`

The `H_ticket` is the hash of the `Ticket` as defined in section 4.1.

The `response` is a field element of `E` and MUST be encoded as a big-endian unsigned integer (i.e. has the same encoding as `ECScalar`).

The `vrf_V` is a value computed by the ticket recipient during acknowledgement.

The `amount` on the `Ticket` MUST be claimable only if `luck` < `encoded_win_prob` on the `Ticket`. Such an acknowledged ticket is called a _winning_
ticket.

### 6.2. Claiming a winning ticket

The monetary value represented by the `amount` on a _winning_ ticket can be claimable at some third party which provides such a service. Such a third party
MUST have the ability to modify the global state of all the involved `Channels`.

Such `amount` SHOULD be claimable only if the `Channel` corresponding to the winning ticket has enough `balance` >= `amount`.

Any holder of a _winning_ ticket can claim the `amount` on the ticket by submitting the following:

- the entire encoded `Ticket` structure of the winning ticket
- `response` encoded as a field element of `E`
- the public key `P` of the recipient of the ticket
- values `V`, `h` and `s` computed in Section 5.2.3.3

If the third party wishes to verify the claim, it proceeds as follows. If any of the checks below fail, the `amount` MUST not be claimable.

1. Compute `H_ticket` as per 4.1 and verify the ticket's signature

2. The `Channel` matching `channel_id` MUST exist, MUST NOT be `CLOSED`, its `channel_epoch` MUST match with the one on the ticket and SHOULD have
   `balance` >= `amount`.

3. The `index` on the ticket MUST be greater than or equal to `ticket_index` on the `Channel`

4. The third party applies appropriate encoding to obtain `H_P` from `P`. It then performs the following computations:

```
B = HC(H_P || H_ticket, dst)
sB = MUL(s, B)
hV = MUL(h, V)
R = sB - hV
h_check = HS(P || V || R || H_ticket, dst)
```

Finally, the `h_check` MUST be equal to `h`.

5. The result of `MUL(response, G)` MUST be equal to the `challenge` from the `Ticket`. If unique encoding of `ECPoint` was used, their encoding MAY
   be compared instead.

6. The `luck` value computed using the given `V` MUST be less than the `encoded_win_prob` from the `Ticket`

To satisfy the claim, the third party MAY also adjust the balance on a `Channel` that is in the opposite direction of the claim (ticket receiver ->
ticket issuer), if such a channel exists and is in an `OPEN` state.

Upon successful redemption, the third party MUST ensure that:

1. The `balance` on the `Channel` from which the claim has been made MUST be decreased by `amount`
2. The `ticket_index` on the `Channel` is set to `index` + `index_offset` (where `index` and `index_offset` are from the claimed ticket)

## 7. Appendix 1

The current implementation of the Proof of Relay protocol (which is in correspondence with the HOPR Packet protocol from
[RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)):

- Hash function `H` is Keccak256
- Elliptic curve `E` is chosen as secp256k1
- HS is instantiated via `hash_to_field` using `secp256k1_XMD:SHA3-256_SSWU_RO_` as defined in [02]
- HC is instantiated via `hash_to_curve` using `secp256k1_XMD:SHA3-256_SSWU_RO_` as defined in [02]
- The one-way encoding `ECPoint` is done as `Keccak256(P)` where `P` denotes secp256k1 point in uncompressed form. The output of the hash has the
  first 12 bytes removed, which leaves the length at 20 bytes.

- **MIN_USED_BALANCE** = `1e-18` HOPR.
- **MAX_USED_BALANCE** = `1e7` HOPR.

## 8. Appendix 2

This appendix describes the ticket states which are implementation specific for the current Proof Of Relay implementation as part of the HOPR
protocol.

- **Ticket** (unsigned or signed, but not yet verified)

  - Contains all ticket fields (channel_id, amount, index, index_offset, winProb, channel_epoch, challenge, signature).
  - A Ticket without a signature MUST NOT be accepted by peers and MUST NOT be transmitted except for internal construction.

- **VerifiedTicket** (signed and verified)

  - The signature MUST verify against `get_hash(domainSeparator)` and recover the ticket issuer’s address.
  - `verified_hash` MUST equal `Ticket::get_hash(domainSeparator)`; `verified_issuer` MUST equal the recovered signer.

- **UnacknowledgedTicket** (VerifiedTicket + own half-key)

  - Produced when the recipient binds its own PoR half-key to the VerifiedTicket while waiting for the downstream acknowledgement.

- **AcknowledgedTicket** (VerifiedTicket + PoR response)

  - Produced once the recipient learns the downstream half-key and reconstructs `Response`.

- **RedeemableTicket** (winning, issuer-verified, VRF-bound)

  - Produced from an AcknowledgedTicket by attaching VRF parameters derived with the redeemer’s chain key and the `domainSeparator`.
  - A RedeemableTicket MUST be suitable for on-chain submission.

- **TransferableWinningTicket** (wire format for aggregation/transfer)

  - A compact, verifiable representation of a **winning** ticket intended for off-chain aggregation.

### 8.1. Allowed transitions

![Mermaid Diagram 1](mermaid_1.png)

1. `Ticket --sign--> VerifiedTicket`

   - Pre-conditions:

     - Ticket MUST include all mandatory fields and satisfy bounds (amount ≤ 10^25; index ≤ 2^48; index_offset ≥ 1; channel_epoch ≤ 2^24).

   - Post-conditions:

     - A valid ECDSA signature over `get_hash(domainSeparator)` is attached.

2. `Ticket --verify(issuer, domainSeparator)--> VerifiedTicket`

   - MUST recover `issuer` from `signature` over `get_hash(domainSeparator)`.
   - On failure, verification MUST be rejected.

3. `VerifiedTicket --into_unacknowledged(own_key)--> UnacknowledgedTicket`

   - Binds the recipient’s PoR half-key. No additional checks REQUIRED.

4. `UnacknowledgedTicket --acknowledge(ack_key)--> AcknowledgedTicket`

   - Compute `Response = combine(own_key, ack_key)`.
   - The derived challenge `Response.to_challenge()` MUST equal `ticket.challenge`.
   - On mismatch, the transition MUST fail with `InvalidChallenge` and the ticket MUST remain unacknowledged.

5. `AcknowledgedTicket(Untouched) --into_redeemable(chain_keypair, domainSeparator)--> RedeemableTicket`

   - The caller (redeemer) MUST NOT be the ticket issuer (Loopback prevention).
   - Derive VRF parameters over `(verified_hash, redeemer, domainSeparator)`.
   - The resulting RedeemableTicket MAY be submitted on-chain if winning (see §3).

6. `AcknowledgedTicket(Untouched) --into_transferable(chain_keypair, domainSeparator)--> TransferableWinningTicket`

   - Equivalent to `into_redeemable` followed by conversion to transferable form; retains VRF and response.

7. `TransferableWinningTicket --into_redeemable(expected_issuer, domainSeparator)--> RedeemableTicket`

   - MUST verify: `signer == expected_issuer` and the embedded signature over `get_hash(domainSeparator)`.
   - MUST recompute “win” locally (see §3). On failure, MUST reject.

8. `VerifiedTicket --leak()--> Ticket`

   - Debug/escape hatch only. Implementations SHOULD avoid downgrading state in production flows.

## 9. Appendix 3

Domain separator (`dst`) for the current implementation (in Solidity) is derived as:

```
domainSeparator = keccak256(
  abi.encode(
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
    keccak256(bytes("HoprChannels")),
    keccak256(bytes(VERSION)),
    chainId,
    address(this)
  )
)
```

## 10. References

[01] Bradner, S. (1997). [Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119). _IETF RFC 2119_.

[02] Faz-Hernandez, A., et al. (2023). [Hashing to Elliptic Curves](https://www.rfc-editor.org/rfc/rfc9380.html). _IETF RFC 9380_.
