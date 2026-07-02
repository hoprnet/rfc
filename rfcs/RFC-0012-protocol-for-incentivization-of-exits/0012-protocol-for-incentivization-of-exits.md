# RFC-0012: Protocol for Incentivization of eXits

- **RFC Number:** 0012
- **Title:** Protocol for Incentivization of eXits
- **Status:** Draft
- **Author(s):** Lukas Pohanka (@NumberFour8), Qiannchen Yu (@QYuQianchen)
- **Created:** 2025-03-28
- **Updated:** 2026-05-26
- **Version:** v0.3.0 (Draft)
- **Supersedes:** none
- **Related Links:** [RFC-0003](../RFC-0003-hopr-overview/0003-hopr-overview.md), [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md), [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md), [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md)

# 1 Abstract

This RFC describes the Protocol for Incentivization of eXits (PIX). It integrates within the ecosystem of HOPR protocol (RFC-0004) and additional protocols built on top of it (RFC-0008, RFC-0009 and RFC-0011).

This documents uses notation and terms established in RFC-0001 and RFC-0002. It is assumed that the protocol is executed within a network of HOPR mixnet nodes (see RFC-0003).


## 1.1 Motivation

The HOPR protocol as defined in RFC-0004 and the Proof of Relay as defined in RFC-0005 allow incentivization of individual mixnet nodes. The recipient of the mixnet traffic (sometimes called the Exit node), however, does not receive any incentives at all. This might be a limiting factor in situations when the sender of the mixnet traffic (sometimes called the Entry node) asks for certain actions to be performed by the Exit node on the Entry's behalf. In that case, the Exit node does not receive any in-protocol incentives for this particular action.

This is the primary motivation of this RFC, to build an additional sub-protocol that allows incentivization of the Exit node, and is, to some degree conditional.


## 1.2 Notation

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [02] when, and only when, they appear in all capitals, as shown here.

All terminology used in this document, including general mix network concepts and HOPR-specific definitions, is provided in [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md). That document serves as the authoritative reference for the terminology and conventions adopted 
across the HOPR RFC series. Additionally, the following packet-protocol-specific terms are defined:

- **`||`** denotes byte-string concatenation.

- **`i=0..k`** denotes an index `i` taking all values from `0` to `k-1` (inclusive).

- **`|x|`** denotes the size of the `x` object in bytes.

- Multi-byte numeric values (such as `u16`, `u32` and `u64`) are always encoded as bytes with most-significant byte first (Big Endian).

- If character strings (delimited via double-quotes, such as `"xyz-abc-123"`) are used in place of byte strings, their ASCII single-byte encoding is assumed. 
Non-ASCII character strings are not used throughout this document.

- *CSPRNG* stands for Cryptographically Secure Pseudorandom Number Generator.

- **SSA** stands for *Session Stealth Address* - a commitment value derived from polynomial coefficient commitments and an Exit commitment, used as the address for allocating PIX incentives.

## 1.3 Goals

The PIX is a protocol between Entry (sender of mixnet traffic) and Exit (the recipient of mixnet traffic) that takes place within a certain time period when these two entities have some logical communication bound between each other.

The PIX protocol aims to fulfill the following goals:

1. Establishes means to deliver incentives from Entry to Exit
2. During the execution of the Protocol and claiming of incentives, the Exit node MUST NOT learn anything new about the Entry node (the Protocol itself discloses no additional information about the Entry)
3. The Exit node MUST be able to claim the incentives only at a point when it has delivered certain amount of traffic (via Return Path in HOPR packets, as per RFC-0003) back to the Entry. The amount of traffic SHOULD BE agreed within the protocol upfront.
4. The Entry node MUST NOT be able to retract the incentives once it has committed them for the given Exit and agreed traffic amount.
5. The amount of delivered traffic MAY NOT be the only condition to allow the incentive claim by the Exit, but the Entry MUST NOT have any influence on setting the outcome of that additional condition.

# 2 Protocol

## 2.1 Setup

Let `C` be an algebraic curve over a finite field `F`, with (sub)group of large order, such that the Diffie-Hellman problem in that (sub)group is difficult (and MUST BE equivalent to at least 128-bit security). Most commonly, `C` could be an elliptic curve or an Edwards curve with large prime-order (sub)group.

Let `P[x, t]` denote a polynomial of degree `t` over the finite field `F`, with variable `x`.

Let `H` be a cryptographic hash function, with a fixed size.

The `E(iv, k, m)` and `D(iv, k, m)` operations denote encryption and decryption of a message `m` using a symmetric cipher with secret key `k` and IV `iv`.

The Protocol for Incentivization of eXits (PIX) is strictly defined between 3 entities: Entry node `A` (also called Client), Exit node `B` (also called Server) and certain "privacy pool" `W` and governs their interaction to fulfill the goals from Section 1.3. We assume the Entry and Exit nodes to be HOPR nodes as defined in RFC-0002.

The path between `A` and `B` SHOULD BE at least 1-hop (one relayer on both forward and return paths).
Per RFC-0004, acknowledgement challenge tracking on 0-hop paths MAY BE omitted by the implementation, and therefore PIX cannot be instantiated in such case.

The specific selection of `C`, `F`, `H` , `E`, `D` and a choice of a privacy pool `W` define a concrete instantiation of PIX.

The points on `C` (group elements) can be represented in a certain encoded form (`EncodedPoint`) that SHOULD BE efficient for over-the-wire transfers (typically in a compressed form). Assume that `BP` is the base point of large order on `C` (large order (sub)group generator).

A Key Derivation Function `KDF(c, k, s)` allows generation of secret key material from a high-entropy pre-key `k`, context string `c`, and a salt `s`: `KDF(c, k, s)`. KDF will perform the necessary expansion to match the size required by the output. The Salt `s` argument is optional and MAY be omitted.

Let the Hash to Field (Scalar) operation `HS(s,t)` which computes a field element of `F` from a secret `s` and an additional tag `t`.

## 2.2 Privacy Pool operations

The Privacy Pool `W` is abstracted out from this RFC as a black-box. It is assumed, that `W` offers the following operations:

1. `Deposit(Amount) -> Deposit_Handle`  :  An operation that deposits certain `Amount` of funds (later used as PIX incentives) and this deposit is somewhat identifiable by the depositor. Note that the `Deposit_Handle` here is an abstraction and can in practice be realized, e.g. via zero-knowledge proving.
2. `Allocate(Amount, Deposit_Handle, Address)`: Performs allocation of specific `Amount` from a previously made deposit (that corresponds to a `Deposit_Handle`) to the given `Address`
3. `Withdraw(Address, PkPoP_Address, WithdrawalAddress)`: Performs withdrawal of a previous allocation to an `Address` (via `Allocate` call) while providing a proof-of-possession of a private key that corresponds to `Address`. If proof verification succeeds, the allocation is transferred to the `WithdrawalAddress`

To satisfy the goals of PIX in Section 1.3, `W` MUST ensure the anonymity of the depositor and allocator towards the withdrawer.
That typically means that the usage of `Deposit_Handle` must not be revealed or in any way made linkable to the Entry node.


## 2.3 Protocol flow

The protocol assumes that the price of incentives is globally known to both parties (e.g., via a price oracle).

The protocol starts by the Entry node `A` making a deposit via `Deposit` call to `W`, depositing a certain amount of incentives. It keeps its `Deposit_Handle`.

This is typically done ahead of time, before `A` even knows about an Exit `B`.

At a later point, once `A` knows about `B` and it chooses it as its Exit node service provider, `A` MAY instantiate a Session with `B` as described in RFC-0009. We assume this binding between `A` and `B` then uses a fixed return path pseudonym `P` of `A` (see RFC-0004) and it stays the same during the course of PIX execution.

The Session initiation MAY be used to communicate certain PIX parameters from `A` to `B` beforehand (see Appendix 2).

The protocol follows to perform the first `SSA_Agreement_1` between `A` and `B`:


### 2.3.1 The `SSA_Agreement_i`:

1. The `B` sends the `ExitCommitmentRequest_i`
2. If `A` never receives `ExitCommitmentRequest_i` from `B`, it MUST not carry on with the next steps.
3. Upon receiving `ExitCommitmentRequest_i`, `A` SHOULD verify whether the message (see Section 2.3.2) is acceptable:
  a) the message MUST NOT be considered acceptable if `ExitCommitment_i` does not belong to the large order (sub)group of `C`.
  b) the message MAY NOT be considered acceptable if `params` do not constitute a quota acceptable for the Exit (see Section 2.3.7).
  c) if the message is acceptable, `A` MUST respond by generating and sending `EntryCommitment_i` message to `B`.
  d) if the message not acceptable, `A` MUST terminate communication with `B` (cancelling the binding with common `P`)
4. `A` creates `SSA_i = C_i_0_0 + C_i_1_0 + ... + C_i_m_0 + ExitCommitment_i` 
5. `A` performs `Allocate(ChunkPrice, Deposit_Handle, SSA_i)` with `W`
6. `A` constructs the `EntryCommitment_i` message and sends it to `B`
7. `B` MUST NOT continue communicating with `A` if `EntryCommitment_i` in not received within a certain time limit and terminates here.
8. Once `B` receives the full `EntryCommitment_i` message, the Exit node MUST (in this order):
  a) verify the degree and number of received polynomials is acceptable, otherwise it MUST terminate communications with `A`
  b) create `SSA_i = C_i_0_0 + C_i_1_0 + ... + C_i_m_0 + ExitCommitment_i`
  c) store `A`'s pseudonym `P`, polynomial coefficient commitments `CP_0_0, CP_0_1, ..., CP_0_m, CP_1_0, ..., CP_t_m`
  d) await allocation to be deposited to `SSA_i` 

The `B` MAY choose not to continue communicating with `A` unless the deposit in `6d` is finished or to communicate only for a limited time until the deposit is detected.

Once the `SSA_Agreement_i` process is finished by incentives being allocated to `SSA_i`, the bidirectional communication between `A` (with pseudonym `P`) and `B` then continues as specified in the HOPR protocol (RFC-0004), with additional changes that MUST be implemented:

- `A` now MUST generate SURBs with additional recipient data (see RFC-0004) containing `EncryptedShare_i_u_v` and MUST produce at least `m*(t+1)` of them (i.e. `u = 0..m-1`, `v = 0..t`). Each MUST BE attached to a single SURB (along with `u` and `v`) sent to `B`.

- `B` receives the SURBs for pseudonym `P` from `A`. Once it is about to send a reply packet to `A`, it MUST pick a random SURB with pseudonym `P`, that contains `EncryptedShare_i_u_v`.

- If `B` never receives all `EncryptedShare_i_u_v` from `A` within a certain time limit, it MUST terminate communication with `A`.

- Once a reply packet is delivered to the first downstream relayer on the return path, the Exit `B` is able to decrypt `EncryptedShare_i_u_v` as described in Section 2.3.5, resulting in `Share_i_r_s`.
  
- The Exit MUST verify `Share_i_u_v` (see Section 2.3.5). If the verification fails (the implementors MAY choose a threshold), the Exit MUST terminate communication with `A` (it SHOULD also dump all the SURBs indexed by `P`). 

- Once `B` uses at least `t+1` SURBs for some fixed (but previously agreed-upon) `i` and `u`, it MUST obtain at least `Share_i_u_0, ..., Share_i_u_t` successfully verified shares. These then MAY be immediately turned into `SSA_Priv_i_r` as described in Section 2.3.6.

- Once `SSA_Priv_i_u` is recovered for each `u=0..m-1`, the Exit computes `SSA_Priv_i = SSA_Priv_i_0 + SSA_Priv_i_1 + ... SSA_Priv_i_(m-1)`.

- The Exit MAY compute `PkPoP_SSA_i` using `SSA_Priv_i` and perform `Withdraw(SSA_i, PkPoP_SSA_i, WithdrawalAddress)` for a chosen `WithdrawalAddress` with `W`. It also MAY initiate `SSA_Agreement_(i+1)`, and the whole process restarts with `i+1`.
  
- If `i` reaches 2^32-1, the Exit MUST refuse further communication with `A`, forcing it to start over with a new pseudonym different from `P`.

- The Entry MUST create a new deposit with `W` once it allocates all incentives that were previously deposited, to ensure further allocations could be done.


The following sections give details how are the individual steps from the `SSA_Agreement_i` achieved.

### 2.3.2 Generation of `ExitCommitmentRequest_i` at the Exit

The Exit node generates the `ExitCommitmentRequest` as follows:

It chooses a random scalar `b_i` (via a CSPRNG) and computes `ExitCommitment_i = b_i * BP` where `BP` is the point of large order on curve `C`, and stores `b_i` associated with the pseudonym `P` and `i`.

The Exit node chooses number `2 <= t < 2^16` which will be a degree of polynomials. And `2 <= m < 2^16` - the number of polynomials.
Both MUST BE unsigned 16-bit numbers.

It creates a 32-bit unsigned integer `params = (m << 16) || (t+1)`. In other words, `m` should be encoded as upper 16-bit half and `t+1` as lower 16-bit half of the `params` integer.

The message SHOULD BE constructed as follows:

```
struct ExitCommitmentRequest_i {
	P: Pseudonym,
	params: u32,
	i: u32,
	ExitCommitment_i: EncodedPoint 
}
```

The Exit node MAY choose to send multiple `ExitCommitment_i` messages (with strictly increasing `i`), to request the Entry to allocate more incentives to individual `SSA_i`.
The Entry MAY refuse to allocate more, and the Exit MAY refuse service (terminate communication with the Entry) if the Entry allocates too few SSAs.

Implementations MAY choose to use an alternative `ExitCommitmentRequest` message format, where more commitments to (with strictly increasing `i`) are requested, and the Entry then processes them as individual `ExitCommitmentRequest_i` messages.

### 2.3.3 Generation of `EntryCommitment_i` at the Entry

The Entry node creates this message once it learns `i` and the `params` value from the `ExitCommitmentRequest` message. 
This value allows it determining whether the requested `t` and `m` values are acceptable, see Section 2.3.7.

The Entry generates `m` polynomials, each of degree `t` with (`t+1`) random coefficients (using a CSPRNG) from `F`: `T_i_0_0, T_i_0_1, ... T_i_0_t, T_i_1_0, T_i_1_2, ... T_i_m-1_t` 
(`T_i_j_k` marks k-th coefficient of the j-th polynomial `T` for i-th SSA agreement), The entire j-th polynomial of i-th SSA agreement is then `T_i_j[x] = T_i_0_0 + T_i_0_1 * x + ... + T_i_j_t * x^t`.
Entry node stores these polynomials also indexed by pseudonym `P`


The Entry then computes the commitments of each coefficient in every polynomial as:
`M_i_r_s = T_i_s_r * BP` (for each `r=0..t, s=0..m-1`) - note the index transposition.
Naturally, these commitments form an `t+1`-by-`m` matrix (rows indexed by `r`, columns by `s`) denoted `M_i`.

In other words, each `r`-th row contains every `r`-th coefficient of all `m` polynomials.

```
struct EntryCommitment_i {
	P: Pseudonym,
	i: u32,
	M_i: Matrix (t+1)-by-m
}
```

Since this message might not fit within the HOPR packet (that depends on the choice of `t` and `m`), 
the implementation SHOULD split the message in `t` multiple piece-wise messages 
`EntryCommitment_i_0`, `EntryCommitment_i_1`, ... `EntryCommitment_i_t` as follows:

```
struct EntryCommitment_i_r {
	P: Pseudonym
	i: u32,
	r: u16,
	M_i_r: r-th row in Matrix M_i 
}
```

In other words, the `EntryCommitment_i_r` message contains the `r`-th row of the `M_i` matrix.
If the HOPR packet cannot even fit the entire row, then the rows SHOULD be also sent piecewise, with columns in the ascending order.

The implementors MAY choose to deny such `t` and `m` choices, where `EntryCommitment_i_r` could not fit within a single HOPR packet.

### 2.3.4 Generation of `EncryptedShare_i_u_v` at the Entry

Once the Entry `A` has sent `EntryCommitment_i` (or all piecewise `EntryCommitment_i_r` for `r = 0..t`) to `B` 
and has allocated incentives to `SSA_i`, it MUST start generating `EncryptedShare_i_u_v` for `u = 0..m-1, v = 0..`, 
each of which MUST BE from then on attached to a SURBs sent to `B`. 

`EncryptedShare_i_u_v` therefore denotes the `v`-th share of the `u`-th polynomial belonging to the `i`-th SSA agreement bound to pseudonym `P`.

Note `u` and `v` MUST be unsigned 16-bit numbers, but otherwise is the `v` index is unbounded. 
The Entry `A` MUST generate at least `t+1` shares (to `v = 0..t`) for each `u`, `i` and pseudonym `P`, and send them to the Exit `B`.
All additional shares with `v > t` MAY be generated and are called *surplus shares*.

To generate `EncryptedShare_i_u_v` for some `i > 0`, `0 <= u < m`,`0 <= v < 2^16` and pseudonym `P`, the Entry `A` first computes `Share_i_u_v` as follows:

1. `A` chooses `x = HS(SenderKey, "HASH_SSA_POLY_SHARE_SCALAR")` where `SenderKey` is taken from the SURB the resulting `EncryptedShare_i_u_v` will be associated with - see RFC-0004. 
2. It evaluates polynomial `T_i_u` associated with pseudonym `P` at `x` over `F`: `y = T_i_u[x] = T_i_u_0 + T_i_u_1 * x + ... + T_i_u_t * x^t`
3. It constructs `Share_i_r_s` as:
```
Share_i_r_s {
	i: u32
	u: u16,
	v: u16,
	y: [u8; |y|]
}
```

Note, that `|x| = |y|` since they both belong to the same finite field `F`.

The `KDF` is used to derive `(iv, k) = KDF("HASH_SSA_POLY_SHARE", ack_secret, P || i || u || v)` in order (first `iv` then `k`), 
where `ack_secret` is the Acknowledgement secret for the first downstream relayer on the return path from `B` to `A` (see Section 5.2.3.1 in RFC-0005).

Subsequently, the value `y` is encrypted as `E_y = E(iv, k , y)`.

4. The `EncryptedShare_i_u_v` is constructed as:
```
EncryptedShare_i_r_s {
	i: u32
	u: u16,
	v: u16,
	E_y: [u8; |E_y|]
}
```

The `EncryptedShare_i_u_v` is attached as additional recipient data (after `PoRValues` in section 3.4.3 of RFC-0004) to the corresponding SURB,
with individual members encoded in the given order.


### 2.3.5 `EncryptedShare_i` decryption and verification

A SURB that contains additional data of size `|EncryptedShare_i_u_v|`, the data are interpreted as `EncryptedShare_i_u_v`.
If the `i` member is 0, the SURB MUST be used as if it did not contain any `EncryptedShare`. If `i` >= 1, the Exit node assumes it could be valid `EncryptedShare_i_u_v`.

As soon as the `B` uses the associated SURB to send reply data to `A`, the first down stream relayer on the return path sends an `Acknowledgement` (as per RFC-0005) to `B`, disclosing `ack_secret`.

`B` then uses KDF to generate `iv,k` and computes the `x` value (both as per Section 2.3.4).

Subsequently, it can obtain `Share_i_u_v = D(iv, k, E_y)`. 

In the next step, `B` MUST verify that:

1. `i` belongs to a previously received `ExitCommitment_i` message from `A` (i.e. `i` is a valid index).
2. `0 <= u < m-1` and `0 <= v < 2^16`, where `m` is the number of polynomials in the `SSA_Agreement_i`
3. The `Share_i_u_v` corresponds to polynomial `T_i_u[x]` by checking that `RHS - LHS = 0` (where 0 denotes the neutral element of `C`'s curve group):
```
  LHS = M_i_0_u + x * M_i_1_u + x^2 * M_i_2_u + ... x^t * M_i_t_u
  RHS = y * BP
```

On successful verification, `B` knows that `(x, y) = (x_i_u_v, y_i_u_v)` constitutes a valid share, that can be used to recover `SSA_Priv_i_u`.


### 2.3.6 Recovery of `SSA_Priv_i_r` and `SSA_Priv_i` at the Exit

Once the Exit `B` determines at least `t+1` `(x_i_u_v, y_i_u_v)`-pairs (`v = 0..t`) for a given `i`, `u`, as per previous section, 
it can recover `SSA_Priv_i_u` by executing Lagrange interpolation of the `T_i_u[x]` polynomial using points 
`(x_i_u_0, y_i_u_0)`, `(x_i_u_1, y_i_u_1)`, ..., `(x_i_u_t, y_i_u_t)` as inputs.

The interpolation will yield the constant term `T_i_u_0` which is equal to `SSA_Priv_i_u`.

Once all polynomials `T_i_0`, `T_i_1`, ..., `T_i_m` are interpolated, the `SSA_Priv_i_0`, ..., `SSA_Priv_i_m` are determined.

The `SSA_Priv_i` is the sum `b_i + SSA_Priv_i_0 + SSA_Priv_i_1 + ... + SSA_Priv_i_m`,
where `b_i` is the value generated in Section 2.3.2.

#### 2.3.7 Expressed data quota

The `t` and `m` values from Section 2.3.2 directly constitute a *quota* of data which is associated with the `SSA_i`. 
It follows from the protocol that the Exit MUST be able to obtain all `m*(t+1)` shares (`Share_i_0_0`, ..., `Share_i_m-1_t`) from the `B` before it can compute `SSA_Priv_i`. 
This is done by using the `m*(t+1)` SURBs that contain `EncryptedShare_i_u_v` to send data to the Entry.

As such, the quota (in bytes) can be computed as `Q = m * (t+1) * PacketMax` (see Section 2.2 of RFC-0004). This quota is directly translatable to Exit's cost by multiplying `m * (t+1)` with
the HOPR packet price. Since each `SSA_i` is associated with a certain deposit made by the Entry, the Exit shall decide whether the deposit is enough to cover for the cost of the quota.

This plays an important role in the acceptability of the PIX parameters. The Entry MAY use a prior advertisement for its `m` and `t+1` preferred values to the Exit, 
as part of the logical binding between them before the PIX protocol starts. The Exit however MAY NOT honor the pre-advertised values, 
and set different values for the `t` and `m` parameters in the `ExitCommitmentRequest_i` message.

However, the Entry MAY still deem the Exit chosen `m` and `t+1` values acceptable if they evaluate to the same quota as the prior advertised values, or they fall
within some acceptable tolerance.

# References

TBA

# Appendix 1

The HOPR PIX is the following instantiation of PIX:

- `C` is sep256k1
- `H` is Blake3_256
- `E/D` is Chacha20
- `KDF` is instantiated using Blake3 in KDF mode [06], where the optional salt `s` is prepended to the key material `k`: `KDF(c,k,s)` = `blake3_kdf(c, s || k)`. If S is omitted: `KDF(c,k) = blake3_kdf(c,k)`.
- `HS` is instantiated via `hash_to_field` using `secp256k1_XMD:Blake3-256_SSWU_RO_` as defined in [04]. `s` is used as the secret input, and `t` as an additional domain separator.

# Appendix 2

The HOPR PIX is instantiated in conjunction with the Start and Session protocol, as per RFC-0009 and RFC-0008. 
The `ExitCommitmentRequest_i` and `EntryCommitment_i` messages are implemented as new Start protocol messages, with the pseudonym `P` replaced with the corresponding Session ID (that itself consists of the pseudonym), that has been established beforehand. 
The HOPR PIX protocol is therefore bound to a particular pre-established HOPR Session.

The `m` and `t+1` value advertisement (as described in Section 2.3.7) MAY be encoded by the Entry within the `additional_data` field of the Start protocol message. 
In version 3 of the Start protocol, the values are encoded as a 32-bit number `(m << 16) || (t+1)` and stored in the most-significant half of the `additional_data` 64-bit field in the `StartSession` messsage.
To further indicate that this advertisement is being sent, the Entry also sets the `UsePIX` capability bit to 1 (the third most significant bit of the `capabilities` byte of the `StartSession` message).

