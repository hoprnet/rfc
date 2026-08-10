# RFC-0012: Protocol for Incentivization of eXits

- **RFC Number:** 0012
- **Title:** Protocol for Incentivization of eXits
- **Status:** Draft
- **Author(s):** Lukas Pohanka (@NumberFour8), Qianchen Yu (@QYuQianchen)
- **Created:** 2025-03-28
- **Updated:** 2026-07-30
- **Version:** v0.5.0 (Draft)
- **Supersedes:** none
- **Related Links:** [RFC-0003](../RFC-0003-hopr-overview/0003-hopr-overview.md),
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md),
  [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md), [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md),
  [RFC-0011](../RFC-0011-application-protocol/0011-application-protocol.md)

# 1 Abstract

This RFC describes the Protocol for Incentivization of eXits (PIX). It integrates within the ecosystem of HOPR protocol (RFC-0004) and additional
protocols built on top of it (RFC-0008, RFC-0009 and RFC-0011).

This document uses notation and terms established in RFC-0001 and RFC-0002. It is assumed that the protocol is executed within a network of HOPR
mixnet nodes (see RFC-0003).

## 1.1 Motivation

The HOPR protocol as defined in RFC-0004 and the Proof of Relay as defined in RFC-0005 allow incentivization of individual mixnet nodes. The recipient
of the mixnet traffic (sometimes called the Exit node), however, does not receive any incentives at all. This might be a limiting factor in situations
when the sender of the mixnet traffic (sometimes called the Entry node) asks for certain actions to be performed by the Exit node on the Entry's
behalf. In that case, the Exit node does not receive any in-protocol incentives for this particular action.

This is the primary motivation of this RFC, to build an additional sub-protocol that allows incentivization of the Exit node, and is, to some degree
conditional.

## 1.2 Notation

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are
to be interpreted as described in [02] when, and only when, they appear in all capitals, as shown here.

All terminology used in this document, including general mix network concepts and HOPR-specific definitions, is provided in
[RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md). That document serves as the authoritative reference for the terminology and
conventions adopted across the HOPR RFC series. Additionally, the following packet-protocol-specific terms are defined:

- **`||`** denotes byte-string concatenation.

- **`i=0..k`** denotes an index `i` taking all values from `0` to `k-1` (inclusive).

- **`|x|`** denotes the size of the `x` object in bytes.

- Multi-byte numeric values (such as `u16`, `u32` and `u64`) are always encoded as bytes with most-significant byte first (Big Endian).

- If character strings (delimited via double-quotes, such as `"xyz-abc-123"`) are used in place of byte strings, their ASCII single-byte encoding is
  assumed. Non-ASCII character strings are not used throughout this document.

- _CSPRNG_ stands for Cryptographically Secure Pseudorandom Number Generator.

- **SSA** stands for _Session Stealth Address_ - a commitment value derived from polynomial coefficient commitments and an Exit commitment, used as
  the address for allocating PIX incentives.

- **PoK** stands for _Proof of Knowledge_ - a non-interactive zero-knowledge proof that the prover knows the discrete logarithm of a published group
  element.

- **Full-matrix mode** and **constant-term mode** denote the two ways an instantiation MAY commit to the polynomials, as defined in Section 2.3.3.
  Full-matrix mode publishes a commitment to every coefficient - a Feldman commitment - which allows an individual share to be verified in isolation.
  Constant-term mode publishes only the commitments to the constant terms, and establishes validity once a polynomial has been interpolated.

## 1.3 Goals

The PIX is a protocol between Entry (sender of mixnet traffic) and Exit (the recipient of mixnet traffic) that takes place within a certain time
period when these two entities have some logical communication bound between each other.

The PIX protocol aims to fulfil the following goals:

1. Establishes means to deliver incentives from Entry to Exit
2. During the execution of the Protocol and claiming of incentives, the Exit node MUST NOT learn anything new about the Entry node (the Protocol
   itself discloses no additional information about the Entry)
3. The Exit node MUST be able to claim the incentives only at a point when it has delivered certain amount of traffic (via Return Path in HOPR
   packets, as per RFC-0003) back to the Entry. The amount of traffic SHOULD BE agreed within the protocol upfront.
4. The Entry node MUST NOT be able to retract the incentives once it has committed them for the given Exit and agreed traffic amount.
5. The amount of delivered traffic MAY NOT be the only condition to allow the incentive claim by the Exit, but the Entry MUST NOT have any influence
   on setting the outcome of that additional condition.

# 2 Protocol

## 2.1 Setup

Let `C` be an algebraic curve over a finite field `F`, with (sub)group of large order, such that the Diffie-Hellman problem in that (sub)group is
difficult (and MUST BE equivalent to at least 128-bit security). Most commonly, `C` could be an elliptic curve or an Edwards curve with large
prime-order (sub)group.

Let `P[x, t]` denote a polynomial of degree `t` over the finite field `F`, with variable `x`.

Let `H` be a cryptographic hash function, with a fixed size.

The `E(iv, k, m)` and `D(iv, k, m)` operations denote encryption and decryption of a message `m` using a symmetric cipher with secret key `k` and IV
`iv`.

The Protocol for Incentivization of eXits (PIX) is strictly defined between 3 entities: Entry node `A` (also called Client), Exit node `B` (also
called Server) and certain "privacy pool" `W` and governs their interaction to fulfil the goals from Section 1.3. We assume the Entry and Exit nodes
to be HOPR nodes as defined in RFC-0002.

The path between `A` and `B` SHOULD BE at least 1-hop (one relayer on both forward and return paths). Per RFC-0004, acknowledgement challenge tracking
on 0-hop paths MAY BE omitted by the implementation, and therefore PIX cannot be instantiated in such case.

The specific selection of `C`, `F`, `H` , `E`, `D` and a choice of a privacy pool `W` define a concrete instantiation of PIX.

Let `PoK(x, X, d)` denote a non-interactive proof of knowledge of the discrete logarithm `x` of a group element `X = x * BP`, bound to auxiliary data
`d`, and let `PoKVerify(PoK, X, d)` denote its verification. The concrete construction used by this RFC is given in Section 2.3.3.1.

The points on `C` (group elements) can be represented in a certain encoded form (`EncodedPoint`) that SHOULD BE efficient for over-the-wire transfers
(typically in a compressed form). Assume that `BP` is the base point of large order on `C` (large order (sub)group generator).

A Key Derivation Function `KDF(c, k, s)` allows generation of secret key material from a high-entropy pre-key `k`, context string `c`, and a salt `s`:
`KDF(c, k, s)`. KDF will perform the necessary expansion to match the size required by the output. The Salt `s` argument is optional and MAY be
omitted.

Let the Hash to Field (Scalar) operation `HS(m, d, t)` which computes a field element of `F` from a message `m`, additional binding data `d` that is
hashed alongside `m`, and a domain-separation tag `t`. The `d` argument MAY be empty.

## 2.2 Privacy Pool operations

The Privacy Pool `W` is abstracted out from this RFC as a black-box. It is assumed, that `W` offers the following operations:

1. `Deposit(Amount) -> Deposit_Handle` : An operation that deposits certain `Amount` of funds (later used as PIX incentives) and this deposit is
   somewhat identifiable by the depositor. Note that the `Deposit_Handle` here is an abstraction and can in practice be realized, e.g. via
   zero-knowledge proving.
2. `Allocate(Amount, Deposit_Handle, Address)`: Performs allocation of specific `Amount` from a previously made deposit (that corresponds to a
   `Deposit_Handle`) to the given `Address`
3. `Withdraw(Address, PkPoP_Address, WithdrawalAddress)`: Performs withdrawal of a previous allocation to an `Address` (via `Allocate` call) while
   providing a proof-of-possession of a private key that corresponds to `Address`. If proof verification succeeds, the allocation is transferred to
   the `WithdrawalAddress`

To satisfy the goals of PIX in Section 1.3, `W` MUST ensure the anonymity of the depositor and allocator towards the withdrawer. That typically means
that the usage of `Deposit_Handle` must not be revealed or in any way made linkable to the Entry node.

## 2.3 Protocol flow

The protocol assumes that the price of incentives is globally known to both parties (e.g., via a price oracle).

The protocol starts by the Entry node `A` making a deposit via `Deposit` call to `W`, depositing a certain amount of incentives. It keeps its
`Deposit_Handle`.

This is typically done ahead of time, before `A` even knows about an Exit `B`.

At a later point, once `A` knows about `B` and it chooses it as its Exit node service provider, `A` MAY instantiate a Session with `B` as described in
RFC-0009. We assume this binding between `A` and `B` then uses a fixed return path pseudonym `P` of `A` (see RFC-0004) and it stays the same during
the course of PIX execution.

The Session initiation MAY be used to communicate certain PIX parameters from `A` to `B` beforehand (see Appendix 2).

The protocol follows to perform the first `SSA_Agreement_1` between `A` and `B`:

### 2.3.1 The `SSA_Agreement_i`:

1. The `B` sends the `ExitCommitmentRequest_i`
2. If `A` never receives `ExitCommitmentRequest_i` from `B`, it MUST not carry on with the next steps.
3. Upon receiving `ExitCommitmentRequest_i`, `A` SHOULD verify whether the message (see Section 2.3.2) is acceptable: a) the message MUST NOT be
   considered acceptable if `ExitCommitment_i` does not belong to the large order (sub)group of `C`. b) the message MUST NOT be considered acceptable
   if `params` do not match the quota `A` advertised at Session establishment (see Section 2.3.7). c) if the message is acceptable, `A` MUST respond
   by generating and sending `EntryCommitment_i` message to `B`. d) if the message not acceptable, `A` MUST terminate communication with `B`
   (cancelling the binding with common `P`)
4. `A` computes its own half of the SSA as `EntryCommitment_i = M_i_0_0 + M_i_0_1 + ... + M_i_0_(m-1)`, i.e. the sum of the commitments to the
   constant terms of all `m` polynomials, and the corresponding `PoK_i` (see Section 2.3.3.1). `A` knows the discrete logarithm of
   `EntryCommitment_i`, namely `SSA_Priv_i - b_i`.
5. `A` constructs the `EntryCommitment_i` message and sends it to `B`
6. `A` creates `SSA_i = EntryCommitment_i + ExitCommitment_i` and performs `Allocate(ChunkPrice, Deposit_Handle, SSA_i)` with `W`. `A` MUST NOT
   allocate before the whole `EntryCommitment_i` message has been sent, so that `B` is always able to derive `SSA_i` at the moment funds appear at it.
7. `B` MUST NOT continue communicating with `A` if `EntryCommitment_i` in not received within a certain time limit and terminates here.
8. Once `B` receives the full `EntryCommitment_i` message, the Exit node MUST (in this order): a) verify the number of received polynomials and the
   degree agreed in `params` are acceptable, otherwise it MUST terminate communications with `A` - note that in constant-term mode the degree is not
   observable from the message and is taken from `params` alone b) verify that every received coefficient commitment belongs to the large order
   (sub)group of `C`, otherwise it MUST terminate communications with `A` c) compute `EntryCommitment_i = M_i_0_0 + M_i_0_1 + ... + M_i_0_(m-1)` and
   verify `PoKVerify(PoK_i, EntryCommitment_i, P || i)`; if verification fails, or if no `PoK_i` was received, `B` MUST terminate communications with
   `A` **without** deriving or publishing any deposit address for `SSA_i` (see Section 2.3.3.1) d) create
   `SSA_i = EntryCommitment_i + ExitCommitment_i` e) store `A`'s pseudonym `P` and the polynomial coefficient commitment matrix `M_i` f) await
   allocation to be deposited to `SSA_i`

The `B` MAY choose not to continue communicating with `A` unless the deposit in `8f` is finished or to communicate only for a limited time until the
deposit is detected. `B` SHOULD bound that time and terminate communication with `A` if the allocation to `SSA_i` is not observed within it.

Once the `SSA_Agreement_i` process is finished by incentives being allocated to `SSA_i`, the bidirectional communication between `A` (with pseudonym
`P`) and `B` then continues as specified in the HOPR protocol (RFC-0004), with additional changes that MUST be implemented:

- `A` now MUST generate SURBs with additional recipient data (see RFC-0004) containing `EncryptedShare_i_u` and MUST produce at least `m*(t+1)` of
  them, that is `t+1` shares for each `u = 0..m`. Each MUST BE attached to a single SURB (along with `u`) sent to `B`.

- `B` receives the SURBs for pseudonym `P` from `A`. Once it is about to send a reply packet to `A`, it MUST pick a random SURB with pseudonym `P`,
  that contains `EncryptedShare_i_u`.

- If `B` never receives all `EncryptedShare_i_u` from `A` within a certain time limit, it MUST terminate communication with `A`.

- Once a reply packet is delivered to the first downstream relayer on the return path, the Exit `B` is able to decrypt `EncryptedShare_i_u` as
  described in Section 2.3.5, resulting in `Share_i_u`.

- The Exit MUST validate every `Share_i_u` (see Sections 2.3.5 and 2.3.6). Validation failures MUST be counted, and once their number exceeds an
  implementation-chosen threshold, the Exit MUST terminate communication with `A` (it SHOULD also dump all the SURBs indexed by `P`). In full-matrix
  mode a failed share MUST NOT occupy a share slot of its polynomial, so that a later valid share can still take its place. In constant-term mode no
  such slot exists: validity is only established once the polynomial has been interpolated, so the failure is attributed to the polynomial as a whole.

- Once `B` obtains `t+1` distinct shares for some fixed `i` and `u` - successfully verified ones, in full-matrix mode - these MAY be immediately
  turned into `SSA_Priv_i_u` as described in Section 2.3.6. Shares are distinct when their `x` values differ; a repeated `x` carries no new
  information and MUST be discarded.

- Once `SSA_Priv_i_u` is recovered for each `u = 0..m`, the Exit computes `SSA_Priv_i = SSA_Priv_i_0 + SSA_Priv_i_1 + ... + SSA_Priv_i_(m-1)`.

- The Exit MAY compute `PkPoP_SSA_i` using `SSA_Priv_i` and perform `Withdraw(SSA_i, PkPoP_SSA_i, WithdrawalAddress)` for a chosen `WithdrawalAddress`
  with `W`. It also MAY initiate `SSA_Agreement_(i+1)`, and the whole process restarts with `i+1`.

- The Exit SHOULD NOT wait for full recovery of `SSA_i` before initiating `SSA_Agreement_(i+1)`. Because the commitment exchange of the next agreement
  is itself many messages long (see Section 2.3.3), the Exit SHOULD initiate it once a configured fraction of the `m` polynomials of `SSA_i` has been
  recovered, so that the exchange overlaps the tail of the current agreement. At most one agreement SHOULD be pipelined ahead of the active one.

- If `i` reaches 2^32-1, the Exit MUST refuse further communication with `A`, forcing it to start over with a new pseudonym different from `P`.

- The Entry MUST create a new deposit with `W` once it allocates all incentives that were previously deposited, to ensure further allocations could be
  done.

The following sections give details how are the individual steps from the `SSA_Agreement_i` achieved.

### 2.3.2 Generation of `ExitCommitmentRequest_i` at the Exit

The Exit node generates the `ExitCommitmentRequest` as follows:

It chooses a random scalar `b_i` (via a CSPRNG) and computes `ExitCommitment_i = b_i * BP` where `BP` is the point of large order on curve `C`, and
stores `b_i` associated with the pseudonym `P` and `i`.

The index `i` is an unsigned 32-bit integer and MUST be non-zero; the value 0 is reserved as the "no share attached" marker (see Section 2.3.5). The
Exit is authoritative in assigning `i`, and successive `ExitCommitmentRequest` messages MUST use strictly increasing values. Gaps are permitted, so
the Exit MAY advance by more than one at a time.

The number of polynomials `m` and the polynomial degree `t` are **proposed by the Entry** ahead of the first `ExitCommitmentRequest_1`, as part of the
logical binding between the two nodes (see Appendix 2), and the Exit either accepts them or refuses to serve the Entry at all (see Section 2.3.7). The
Exit MUST echo the accepted values unchanged in every `ExitCommitmentRequest_i`, and the Entry MUST terminate communication if they differ from what
it proposed. Both `m` and `t+1` MUST BE unsigned 16-bit numbers, with `m >= 1` and `t >= 1`; an implementation MAY impose tighter upper bounds (see
Appendix 1).

It creates a 32-bit unsigned integer `params = (m << 16) | (t+1)`. In other words, `m` should be encoded as upper 16-bit half and `t+1` as lower
16-bit half of the `params` integer.

The message SHOULD BE constructed as follows:

```
struct ExitCommitmentRequest_i {
	P: Pseudonym,
	params: u32,
	i: u32,
	ExitCommitment_i: EncodedPoint 
}
```

The Exit node MAY choose to send multiple `ExitCommitment_i` messages (with strictly increasing `i`), to request the Entry to allocate more incentives
to individual `SSA_i`. The Entry MAY refuse to allocate more, and the Exit MAY refuse service (terminate communication with the Entry) if the Entry
allocates too few SSAs.

Implementations MAY choose to use an alternative `ExitCommitmentRequest` message format, where more commitments to (with strictly increasing `i`) are
requested, and the Entry then processes them as individual `ExitCommitmentRequest_i` messages.

### 2.3.3 Generation of `EntryCommitment_i` at the Entry

The Entry node creates this message once it learns `i` and the `params` value from the `ExitCommitmentRequest` message. This value allows it
determining whether the requested `t` and `m` values are acceptable, see Section 2.3.7.

The Entry generates `m` polynomials, each of degree `t` with (`t+1`) random coefficients (using a CSPRNG) from `F`:
`T_i_0_0, T_i_0_1, ... T_i_0_t, T_i_1_0, T_i_1_1, ... T_i_(m-1)_t` (`T_i_j_k` marks k-th coefficient of the j-th polynomial `T` for i-th SSA
agreement), The entire j-th polynomial of i-th SSA agreement is then `T_i_j[x] = T_i_j_0 + T_i_j_1 * x + ... + T_i_j_t * x^t`. Entry node stores these
polynomials also indexed by pseudonym `P`

The Entry then computes the commitments of each coefficient in every polynomial as: `M_i_r_s = T_i_s_r * BP` (for each `r = 0..t+1, s = 0..m`) - note
the index transposition. Naturally, these commitments form an `t+1`-by-`m` matrix (rows indexed by `r`, columns by `s`) denoted `M_i`.

In other words, each `r`-th row contains every `r`-th coefficient of all `m` polynomials.

**Commitment mode.** Only the first row `M_i_0` - the commitments to the constant terms - is REQUIRED. The rows `r = 1..t+1` are OPTIONAL, and an
instantiation MUST fix one of the following two modes:

- **Full-matrix mode** transfers all `t+1` rows. The full row set is a Feldman commitment to each polynomial, which lets the Exit verify an individual
  share the moment it arrives (Section 2.3.5, step 5). This isolates a faulty share: it is rejected on its own and replaced by a surplus share, so a
  single corrupt share does not cost the whole agreement.
- **Constant-term mode** transfers only the row `r = 0`. No individual share can then be checked, and validity is instead established once a
  polynomial has been interpolated, by opening its constant-term commitment (Section 2.3.6). This reduces the commitment transfer, the Exit's
  commitment storage and its commitment ingest cost by a factor of `t+1`, and removes per-share group arithmetic entirely. The price is that a faulty
  share is detected only after `t+1` shares of its polynomial have been delivered, and cannot be singled out from among them.

Both modes satisfy the goals of Section 1.3, because the incentive is protected by `PoK_i` (Section 2.3.3.1) and by the arity of the interpolation,
not by the per-coefficient commitments: an Entry that withholds valid shares cannot recover its own allocation either way.

Constant-term mode is RECOMMENDED where the Exit is the sole reconstructing party, as it is in this protocol. Classic verifiable secret sharing needs
per-share verification because the shares sit with mutually distrusting parties that reconstruct later; here the Exit holds every share, interpolates
locally, is the whole quorum, and consumes only the recovered constant term. Opening the constant-term commitment is therefore exact for the property
actually relied on. Full-matrix mode SHOULD be preferred where the Exit must tolerate corrupt shares from an otherwise cooperating Entry - that is,
where a share can be corrupted without the Entry being at fault.

The message format is identical in both modes; the mode only decides which rows are ever emitted. An Exit operating in constant-term mode MUST ignore
any `EntryCommitment_i_r` with `r != 0`, and SHOULD do so without decoding the commitments it carries. It MUST NOT treat such a message as an error,
at any point in the exchange, so that an Entry emitting the full matrix remains interoperable at the cost of its own bandwidth.

```
struct EntryCommitment_i {
	P: Pseudonym,
	i: u32,
	PoK_i: ProofOfKnowledge,
	M_i: Matrix (t+1)-by-m, or 1-by-m in constant-term mode
}
```

Since this message will in general not fit within the HOPR packet (that depends on the choice of `t` and `m`), the implementation SHOULD split the
message into multiple piece-wise messages, each carrying a contiguous slice of a single row:

```
struct EntryCommitment_i_r {
	P: Pseudonym
	i: u32,
	r: u16,
	PoK_i: Option<ProofOfKnowledge>,
	M_i_r: slice of the r-th row in Matrix M_i
}
```

Each such message carries the polynomial index alongside every commitment, so a slice need not be contiguous in `s` and the receiver does not depend
on the arrival order for correctness.

The messages MUST be emitted in two phases, the second of which is empty in constant-term mode:

1. **Constant terms first.** Every message of row `r = 0` is sent before any other row, so the Exit can compute `EntryCommitment_i`, check `PoK_i` and
   derive `SSA_i` as early as possible — that is the one row it needs in full before anything else can proceed. `PoK_i` MUST be present on every
   message of this phase, and MUST be absent from every message of the second phase; its presence is therefore implied by `r = 0` and requires no
   separate flag. Carrying it on every constant-term message rather than only one means no single lost message can strand an otherwise recoverable
   agreement; the Exit keeps the first valid proof it sees and ignores the rest.
2. **Remaining coefficients, blocked by polynomial** (full-matrix mode only). The rows `r = 1..t+1` are then emitted a _block of polynomials_ at a
   time: for a block of polynomial indices, every remaining coefficient of that block is sent before moving to the next block. This completes whole
   columns of `M_i` progressively, so a polynomial becomes fully committed — and therefore its shares verifiable — long before the last message
   arrives. Walking row-major instead would complete no column until the final message, forcing the Exit to defer every share received in the
   meantime.

The block size SHOULD equal the number of commitments that fit in a single message, so that every message stays full and block boundaries align with
those of the first phase.

In constant-term mode the first phase is the entire exchange, and every polynomial becomes reconstructible at the same instant: the message that
completes the constant-term row is simultaneously the one that yields `EntryCommitment_i`, `SSA_i` and the commitment against which each polynomial
will be opened. Shares received before it MUST still be retained, since until then there is no `SSA_i` for a recovered value to contribute to.

The implementers MAY choose to deny such `t` and `m` choices, where a single `EntryCommitment_i_r` message could carry no commitment at all.

#### 2.3.3.1 Proof of knowledge of the Entry commitment

`PoK_i` proves that the Entry knows the discrete logarithm of `EntryCommitment_i`.

Let `s = T_i_0_0 + T_i_1_0 + ... + T_i_(m-1)_0` be the sum of the constant terms of all `m` polynomials, so that `EntryCommitment_i = s * BP`. The
Entry computes `PoK_i = PoK(s, EntryCommitment_i, P || i)` as a non-interactive Schnorr proof:

1. Choose a nonce `r` uniformly at random from `F` using a CSPRNG and compute `R = r * BP`.
2. Compute the challenge `c = HS(P || i || EntryCommitment_i || R, "", "HASH_SSA_COMMITMENT_PROOF")`, where `i` is encoded as a 32-bit big-endian
   integer and the group elements in their encoded form.
3. Compute `z = r + c * s` over `F`.

```
struct ProofOfKnowledge {
	R: EncodedPoint,
	z: [u8; |z|]
}
```

The nonce `r` MUST be freshly generated for every proof and MUST NOT be derived from `P`, `i`, `EntryCommitment_i` or any other value that can repeat:
two proofs sharing an `r` under different challenges disclose `s` as `(z_1 - z_2) / (c_1 - c_2)`.

The Exit verifies `PoKVerify(PoK_i, EntryCommitment_i, P || i)` by decoding `R`, rejecting it if it does not belong to the large order (sub)group of
`C`, recomputing `c` and checking that

```
z * BP == R + c * EntryCommitment_i
```

A malformed proof and a proof that fails this equation MUST be treated identically.

Note: `ExitCommitment_i` is published before the Entry commits, so without `PoK_i` a malicious Entry could choose its constant-term commitments by
group subtraction such that it alone knows the discrete logarithm of `SSA_i`, withdraw its own allocation, and never be able to serve the polynomial
whose constant term it does not know. Since `EntryCommitment_i` and `SSA_i` differ by exactly `b_i`, proving knowledge of `s` and knowing the private
key of `SSA_i` are mutually exclusive for the Entry, which is what makes the proof sufficient. Proving knowledge of the sum is likewise sufficient: an
individual constant term whose discrete logarithm the Entry does not know leaves the deposit key unreachable. The Exit needs no matching proof as long
as it commits first, since it cannot adapt `ExitCommitment_i` to the Entry's commitment.

### 2.3.4 Generation of `EncryptedShare_i_u` at the Entry

Once the Entry `A` has sent `EntryCommitment_i` (or all piecewise `EntryCommitment_i_r`) to `B` and has allocated incentives to `SSA_i`, it MUST start
generating shares `EncryptedShare_i_u` for `u = 0..m`, each of which MUST BE from then on attached to a SURB sent to `B`.

`EncryptedShare_i_u` therefore denotes a share of the `u`-th polynomial belonging to the `i`-th SSA agreement bound to pseudonym `P`. Note `u` MUST be
an unsigned 16-bit number.

Individual shares of the same polynomial are **not** numbered on the wire: a share is identified by its `x` value, which is derived from the SURB the
share travels with and is therefore distinct for every share (see below). The Entry `A` MUST generate at least `t+1` shares for each `u`, `i` and
pseudonym `P`, and send them to the Exit `B`. Additional shares beyond `t+1` MAY be generated and are called _surplus shares_; they absorb packet
loss, which would otherwise leave a polynomial permanently short. In full-matrix mode they additionally absorb shares that fail verification, since
such a share is rejected before it occupies a slot. In constant-term mode they do not: a corrupt share is only detected once it has already been
interpolated together with `t` others.

To generate `EncryptedShare_i_u` for some `i > 0`, `0 <= u < m` and pseudonym `P`, the Entry `A` first computes `Share_i_u` as follows:

1. `A` chooses `x = HS(SenderKey, P || i || u, "HASH_SSA_POLY_SHARE_SCALAR")` where `SenderKey` is taken from the SURB the resulting
   `EncryptedShare_i_u` will be associated with - see RFC-0004, `i` is encoded as a 32-bit big-endian integer and `u` as a 16-bit big-endian integer.
   Binding `P`, `i` and `u` into the derivation means the same `SenderKey` yields a different `x` in a different agreement or for a different
   polynomial. If `x = 0`, the share MUST NOT be generated, as it would disclose the polynomial's constant term; the probability of this is
   negligible.
2. It evaluates polynomial `T_i_u` associated with pseudonym `P` at `x` over `F`: `y = T_i_u[x] = T_i_u_0 + T_i_u_1 * x + ... + T_i_u_t * x^t`
3. It constructs `Share_i_u` as:

```
Share_i_u {
	i: u32
	u: u16,
	y: [u8; |y|]
}
```

Note, that `|x| = |y|` since they both belong to the same finite field `F`.

The `KDF` is used to derive `(iv, k) = KDF("HASH_SSA_POLY_SHARE", ack_secret, P || i || u)` in order (first `iv` then `k`), where `ack_secret` is the
Acknowledgement secret for the first downstream relayer on the return path from `B` to `A` (see Section 5.2.3.1 in RFC-0005).

Subsequently, the value `y` is encrypted as `E_y = E(iv, k , y)`.

4. The `EncryptedShare_i_u` is constructed as:

```
EncryptedShare_i_u {
	i: u32
	u: u16,
	E_y: [u8; |E_y|]
}
```

The `EncryptedShare_i_u` is attached as additional recipient data (after `PoRValues` in section 3.4.3 of RFC-0004) to the corresponding SURB, with
individual members encoded in the given order. Only the ciphertext `E_y` is encrypted; `i` and `u` travel in the clear, as the Exit needs them to
select the verifier before it holds `ack_secret`.

### 2.3.5 `EncryptedShare_i` decryption and verification

A SURB that contains additional data of size `|EncryptedShare_i_u|`, the data are interpreted as `EncryptedShare_i_u`. If the `i` member is 0, the
SURB MUST be used as if it did not contain any `EncryptedShare`. If `i` >= 1, the Exit node assumes it could be valid `EncryptedShare_i_u`.

The `x` value depends only on the SURB's `SenderKey` and the indices carried in the clear, so `B` MAY compute it as soon as the SURB is received. The
plaintext `y`, however, additionally requires `ack_secret`.

As soon as the `B` uses the associated SURB to send reply data to `A`, the first down stream relayer on the return path sends an `Acknowledgement` (as
per RFC-0005) to `B`, disclosing `ack_secret`.

`B` then uses KDF to generate `iv,k` (as per Section 2.3.4).

Subsequently, it can obtain `Share_i_u = D(iv, k, E_y)`.

In the next step, `B` MUST verify that:

1. `i` belongs to a previously received `ExitCommitment_i` message from `A` (i.e. `i` is a valid index) whose `EntryCommitment_i` has been accepted
   per Section 2.3.1 step 8.
2. `0 <= u < m`, where `m` is the number of polynomials in the `SSA_Agreement_i`
3. Neither `x` nor `y` is zero.
4. No share with the same `x` has already been accepted for this `i` and `u`. A repeat MUST be discarded without further processing, as it carries no
   new information.
5. **Full-matrix mode only:** that `Share_i_u` corresponds to polynomial `T_i_u[x]`, by checking that `RHS - LHS = 0` (where 0 denotes the neutral
   element of `C`'s curve group):

```
LHS = M_i_0_u + x * M_i_1_u + x^2 * M_i_2_u + ... x^t * M_i_t_u
RHS = y * BP
```

Note this requires the whole `u`-th column of `M_i` to have arrived. Shares of a polynomial that is not yet fully committed MUST be retained and
verified once its column completes, rather than discarded (see Section 2.3.3).

On successful verification, `B` knows that `(x, y)` constitutes a valid share, that can be used to recover `SSA_Priv_i_u`. A share that fails
verification MUST NOT be retained, so a later valid share can still occupy its place.

In constant-term mode step 5 is not performed, and checks 1 to 4 are the whole of the per-share processing. Note that checks 3 and 4 remain REQUIRED
and become load-bearing rather than merely economical: a zero `x` would evaluate the polynomial at its constant term, and a repeated `x` makes the
interpolation of Section 2.3.6 singular. A share that passes them is retained unconditionally, and whether it belongs to the committed polynomial is
settled only by Section 2.3.6.

### 2.3.6 Recovery of `SSA_Priv_i_u` and `SSA_Priv_i` at the Exit

Once the Exit `B` determines at least `t+1` distinct `(x, y)`-pairs for a given `i`, `u`, as per previous section, it can recover `SSA_Priv_i_u` by
executing Lagrange interpolation of the `T_i_u[x]` polynomial using those pairs as inputs.

The interpolation will yield the constant term `T_i_u_0` which is equal to `SSA_Priv_i_u`.

`B` MUST then check that the recovered value opens the polynomial's constant-term commitment:

```
SSA_Priv_i_u * BP == M_i_0_u
```

In constant-term mode this is the only validity check the shares receive, and it is exact for the value the Exit actually consumes: it holds if and
only if interpolating the `t+1` submitted shares yields the committed constant term. In full-matrix mode it is implied by step 5 of Section 2.3.5
having passed for each of those shares, and MAY therefore be skipped.

If the check fails, at least one of the `t+1` shares did not come from the committed polynomial. In constant-term mode which one cannot be determined
from what the Exit holds, and `SSA_Priv_i` can never be completed, since it is the sum over _all_ `m` polynomials. The Exit MUST count this as a
validation failure per Section 2.3.1 and SHOULD terminate communication with `A` at once, rather than continue serving an agreement that is already
unrecoverable. Recovering from it instead would require error correction over the submitted shares - they form a Reed-Solomon codeword, so up to
`floor(surplus / 2)` corrupt shares are in principle correctable - which this RFC does not specify.

Once all polynomials `T_i_0`, `T_i_1`, ..., `T_i_(m-1)` are interpolated, the `SSA_Priv_i_0`, ..., `SSA_Priv_i_(m-1)` are determined. `B` SHOULD
release the coefficient commitments and the collected shares of a polynomial as soon as it is interpolated and checked, since neither is needed
afterwards.

The `SSA_Priv_i` is the sum `b_i + SSA_Priv_i_0 + SSA_Priv_i_1 + ... + SSA_Priv_i_(m-1)`, where `b_i` is the value generated in Section 2.3.2.

### 2.3.7 Expressed data quota

The `t` and `m` values from Section 2.3.2 directly constitute a _quota_ of data which is associated with the `SSA_i`. It follows from the protocol
that the Exit MUST be able to obtain `t+1` distinct verified shares for each of the `m` polynomials from the `B` before it can compute `SSA_Priv_i`.
This is done by using at least `m*(t+1)` SURBs that contain `EncryptedShare_i_u` to send data to the Entry.

As such, the quota (in bytes) can be computed as `Q = m * (t+1) * PacketMax` (see Section 2.2 of RFC-0004). This quota is directly translatable to
Exit's cost by multiplying `m * (t+1)` with the HOPR packet price. Since each `SSA_i` is associated with a certain deposit made by the Entry, the Exit
shall decide whether the deposit is enough to cover for the cost of the quota.

This plays an important role in the acceptability of the PIX parameters. The Entry advertises its `m` and `t+1` values to the Exit as part of the
logical binding between them, before the PIX protocol starts (see Appendix 2). The Exit computes the implied quota `Q` and MUST refuse the binding
altogether if `Q` falls outside the range it is willing to serve, or if `m` or `t+1` exceed the dimensions it is able to reconstruct with. Otherwise
it accepts the advertised values unchanged and echoes them in every `ExitCommitmentRequest_i`.

Only the product `m * (t+1)` is economically meaningful, but the split between the two governs the Exit's costs and is therefore not free. Which way
it pulls depends on the commitment mode of Section 2.3.3.

In **full-matrix mode**:

- the commitment transfer, the Exit's commitment storage and its commitment ingest cost are `m * (t+1)` group elements, i.e. invariant in the split;
- verifying one share costs `O(t)` scalar multiplications and there are `m * (t+1)` shares, so total verification work grows linearly in `t`.

The split SHOULD therefore keep `t` as small as the tolerance for lost and unverifiable shares allows, and place the remaining factor into `m`.

In **constant-term mode** that reasoning does not apply, and the pull is the other way:

- the commitment transfer, the Exit's commitment storage and its commitment ingest cost are `m` group elements - linear in `m` and independent of `t`;
- validity checking is one scalar multiplication per polynomial, i.e. `m` in total, likewise independent of `t`;
- interpolating one polynomial is `O(t^2)` field operations and there are `m` of them, so total interpolation work is `m * (t+1) * t`, i.e. linear in
  `t` - but in field arithmetic rather than group arithmetic, which is cheaper by orders of magnitude;
- detection latency for a faulty share is `t+1` delivered packets of its polynomial, so it too grows linearly in `t`.

The split SHOULD therefore balance the group operations that scale with `m` against the field operations and the detection latency that scale with
`t`. Because the two kinds of operation differ so greatly in cost, implementations SHOULD measure rather than assume where the optimum lies.

Since the Exit does not choose the parameters, an Entry MAY be refused service but cannot be made to accept a quota it did not propose. An Exit
running modified code that echoes different values than were advertised is rejected by the Entry at step 3b of Section 2.3.1, and would in any case
only break its own recovery.

# References

TBA

# Appendix 1

The HOPR PIX is the following instantiation of PIX:

- `C` is BabyJubJub. An alternative instantiation over secp256k1 is also defined; the two are not interoperable and the choice is fixed at build time.
- `H` is Blake3_256
- `E/D` is Chacha20
- `KDF` is instantiated using Blake3 in KDF mode [06], where the optional salt `s` is appended to the key material `k`: `KDF(c,k,s)` =
  `blake3_kdf(c, k || s)`. If `s` is omitted: `KDF(c,k) = blake3_kdf(c,k)`.
- `HS` is instantiated via `hash_to_scalar` using `expand_message_xmd` with Blake3_256 as defined in [04]. The message `m` and the binding data `d`
  are concatenated as the hash input, and the domain-separation tag is the concatenation of a fixed suite identifier and `t`. The suite identifier is
  the ASCII string `BabyJubJub_XMD:BLAKE3_SSWU_RO_`, or `Secp256k1_XMD:BLAKE3_SSWU_RO_` for the secp256k1 instantiation. It is a fixed constant of the
  protocol and MUST NOT be derived at runtime.
- The deposit address of `SSA_i` is derived from the group element by the privacy pool's own address convention: for secp256k1 it is the Ethereum
  address of the corresponding public key; for BabyJubJub it is the encoded public key itself.
- The commitment mode (Section 2.3.3) is **constant-term mode**: no Feldman commitments are transferred, and validity is enforced per polynomial once
  `t+1` of its shares have arrived. See Appendix 2 for the consequences.

Encoded sizes for the BabyJubJub instantiation (secp256k1 in parentheses where it differs):

| Value                                         | Size          |
| --------------------------------------------- | ------------- |
| `EncodedPoint` (compressed group element)     | 32 bytes (33) |
| Field element / scalar (`x`, `y`, `z`, `b_i`) | 32 bytes      |
| `ProofOfKnowledge` (`R` then `z`)             | 64 bytes (65) |
| `EncryptedShare_i_u` (`i`, `u`, then `E_y`)   | 38 bytes      |

Implementation limits and defaults:

| Parameter                                    | Default | Permitted range |
| -------------------------------------------- | ------- | --------------- |
| `m` (polynomials per SSA)                    | 8192    | 1 .. 16192      |
| `t+1` (shares per polynomial)                | 64      | 2 .. 4096       |
| surplus shares per polynomial (beyond `t+1`) | 32      | 0 .. 4096       |

With the defaults and a maximum HOPR packet payload of 1038 bytes, one SSA agreement covers a quota of `8192 * 64 * 1038` bytes ≈ 519 MiB.

The number of coefficient commitments that must be transferred in the `EntryCommitment_i` messages depends on the commitment mode:

| Mode                          | Commitments per agreement | Bytes at 32 per commitment |
| ----------------------------- | ------------------------- | -------------------------- |
| constant-term (this Appendix) | `8192`                    | ≈ 262 KB                   |
| full-matrix (Feldman)         | `8192 * 64 = 524288`      | ≈ 16.8 MB                  |

# Appendix 2

The HOPR PIX is instantiated in conjunction with the Start and Session protocol, as per RFC-0009 and RFC-0008. The `ExitCommitmentRequest_i` and
`EntryCommitment_i` messages are implemented as the `SsaRequest` and `SsaCommit` Start protocol messages respectively, with the pseudonym `P` replaced
with the corresponding Session ID (that itself consists of the pseudonym), that has been established beforehand. The HOPR PIX protocol is therefore
bound to a particular pre-established HOPR Session. A single `SsaRequest` MAY carry commitments to several SSAs; an Entry SHOULD accept at most two in
one message, which is what pipelining (Section 2.3.1) requires.

The `m` and `t+1` value advertisement (as described in Section 2.3.7) is encoded by the Entry within the `additional_data` field of the Start protocol
message. In version 3 of the Start protocol, the values are encoded as a 32-bit number `(m << 16) | (t+1)` and stored in the most-significant half of
the `additional_data` 64-bit field in the `StartSession` message. To further indicate that this advertisement is being sent, the Entry also sets the
`UsePIX` capability bit to 1 (the third most significant bit of the `capabilities` byte of the `StartSession` message, `0b0010_0000`).

The following behaviours are implementation choices of the HOPR instantiation, in the terms of Section 2.3:

- **Commitment mode: constant-term, no Feldman.** The implementation does **not** use Feldman commitments. The Entry emits only the row `r = 0` of
  `M_i` - one commitment per polynomial - and no share is verified in isolation. Validity is enforced per polynomial once `t+1` of its shares have
  been received (64 by default; this is the value the implementation configures as its _threshold_), by opening the polynomial's constant-term
  commitment as in Section 2.3.6. The `SsaCommit` message retains its `r` field unchanged, and the Exit ignores any message carrying `r != 0` -
  without decoding its commitments, and at any point in the exchange - so an Entry that emits the full matrix remains interoperable and only wastes
  its own bandwidth.
- **Detection latency and its bound.** Because validity is settled per polynomial rather than per share, a misbehaving Entry is detected on the
  `t+1`-th share of the first polynomial it corrupts, having by then been served `t+1` packets: 64 of the 524288 that make up one agreement, or 0.012%
  of the quota. A single corrupt share makes `SSA_i` unrecoverable rather than being absorbed by the surplus, so no fault isolation is retained.
- **Corrupt shares are treated as adversarial.** A share travels in the additional recipient data of a SURB, which reaches the Exit inside an
  authenticated HOPR packet (RFC-0004), and is decrypted with the `ack_secret` that the acknowledgement challenge it is filed under uniquely
  determines (RFC-0005). There is therefore no non-adversarial path to a share that fails to interpolate. This is what makes giving up the fault
  isolation of full-matrix mode acceptable in this instantiation: an Entry that corrupts shares forfeits an allocation it has already made.
- **Return path length.** A Session with `UsePIX` MUST use a return path with at least one intermediate hop. On a 0-hop return path no first
  downstream relayer exists, so no `ack_secret` is disclosed and no share can be decrypted (see Section 2.1).
- **Unverifiable-share tolerance.** Zero: the Exit closes the Session on the _first_ validation failure of Section 2.3.6. A failure means a whole
  polynomial did not open its commitment, which already makes `SSA_Priv_i` unrecoverable, so there is nothing a tolerance could preserve; closing at
  once is also what bounds the served packets to the `t+1` above.
- **Deposit deadline.** After deriving `SSA_i`, the Exit arms a timer and closes the Session if the allocation is not observed before it expires.
- **Early recovery threshold.** The Exit initiates `SSA_Agreement_(i+1)` once 85% of the `m` polynomials of `SSA_i` have been recovered.
- **Commitment lifetimes.** An incomplete `EntryCommitment_i` is discarded after 2 minutes, an SSA that has not been fully recovered after 10 minutes,
  and a polynomial's reconstruction state - its constant-term commitment and its collected shares - after 30 minutes unused.
