# RFC-0012: Protocol for Incentivization of eXits

- **RFC Number:** 0012
- **Title:** Protocol for Incentivization of eXits
- **Status:** Draft
- **Author(s):** Lukas Pohanka (@NumberFour8), Qiannchen Yu (@QYuQianchen)
- **Created:** 2025-03-28
- **Updated:** 2026-05-26
- **Version:** v0.3.0 (Draft)
- **Supersedes:** none
- **Related Links:** [RFC0003](../RFC-0003-hopr-overview/0003-hopr-overview.md)
[RFC0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)
[RFC0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md)
[RFC0008](../RFC-0008-session-protocol/0008-session-protocol.md)
[RFC0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md)


# 1 Abstract

This RFC describes the Protocol for Incentivization of eXits (PIX). It integrates within the ecosystem of HOPR protocol (RFC-0004) and additional protocols built on top of it (RFC-0008, RFC-0009 and RFC-0011).

This documents uses notation and terms established in RFC-0001 and RFC-0002. It is assumed that the protocol is executed within a network of HOPR mixnet nodes (see RFC-0003).


## 1.1 Motivation

The HOPR protocol as defined in RFC-0004 and the Proof of Relay as defined in RFC-0005 allow incentivization of individual mixnet nodes. The recipient of the mixnet traffic (sometimes called the Exit node), however, does not receive any incentives at all. This might be a limiting factor in situations, when the sender of the mixnet traffic (sometimes called the Entry node) asks for certain actions to be performed by the Exit node on the Entry's behalf. In that case, the Exit node does not receive any in-protocol incentives for this particular action.

This is the primary motivation of this RFC, to build an additional sub-protocol that allows incentivization of the Exit node, and is, to some degree conditional.


## 1.2 Goals

The PIX is a protocol between Entry (sender of mixnet traffic) and Exit (the recipient of mixnet traffic) that takes place within a certain time period when these two entities have some logical communication bound between each other.

The PIX protocol aims to fullfil the following goals:

1. Establishes means to deliver incentives from Entry to Exit
2. During the execution of the Protocol and claiming of incentives the Exit node MUST NOT learn anything new about the Entry node (the Protocol itself discloses no additional information about the Entry)
3. The Exit node MUST be able to claim the incentives only at a point when it has delivered certain amount of traffic (via Return Path in HOPR packets, as per RFC-0003) back to the Entry. The amount of traffic SHOULD BE agreed within the protocol upfront.
4. The Entry node MUST NOT be able to retract the incentives once it has committed them for the given Exit and agreed traffic amount.
5. The amount of delivered traffic MAY NOT be the only condition to allow the incentive claim by the Exit, but the Entry MUST NOT have any influence on setting the outcome of that additional condition.


## 1.3 Notation

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [02] when, and only when, they appear in all capitals, as shown here.

The RFC generally uses notation introduced in RFC-0001.

The `||` denotes byte-string concatenation.

The `i=0..k` denotes an index `i` taking all values from `0` to `k-1` (inclusive).

`|x|` denotes the size of the `x` object in bytes.

Multi-byte numeric values (such as `u16`, `u32` and `u64`) are always encoded as bytes with most-significant byte first (Big Endian).

# 2 Protocol

## 2.1 Setup

Let `C` be an algebraic curve over a finite field `F`, with (sub)group of large order, such that the Diffie-Hellman problem in that (sub)group is difficult (and MUST BE equivalent to at least 128-bit security). Most commonly, `C` could be an elliptic or Edwards curve.

Let `P[x, t]` denote a polynomial of degree `t` over the finite field `F`, with variable `x`.

Let `H` be a cryptographic hash function, with fixed size 256-bit output. 

The `E(iv, k, m)` and `D(iv, k, m)` operations denote encryption and decryption of a message `m` using a symmetric cipher with secret key `k` and IV `iv`.

The Protocol for Incentivization of eXits (PIX) is strictly defined between 3 entities: Entry node `A` (also called Client), Exit node `B` (also call Server) and certain "privacy pool" `W` and governs their interaction to fullfil the above goals. We assume the Entry and Exit nodes to be HOPR nodes as defined in RFC-0002.

The specific selection of `C`, `F`, `H` , `E`, `D` and a choice of a privacy pool `W` define a concrete instantiation of PIX.

The points on `C` can be represented in a certain encoded form (`EncodedPoint`) that SHOULD BE efficient for over-the-wire transfers (typically in a compressed form). Assume that `BP` is the base point of large order on `C` (large order (sub)group generator).

A Key Derivation Function (`KDF(c, k, s)`) allows generation of secret key material from a high-entropy pre-key `k`, context string `c`, and a salt `s`: `KDF(c, k, s)`. KDF will perform the necessary expansion to match the size required by the output. The Salt `s` argument is optional and MAY be omitted.

## 2.2 Privacy Pool operations

The Privacy Pool `W` is abstracted out from this RFC as a black-box. It is assumed, that `W` offers the following operations:

1. `Deposit(Amount) -> Deposit_Handle`  :  An operation that deposits certain `Amount` of funds (later used as PIX incentives) and this deposit is somewhat identifiable by the depositor. Note that the `Deposit_Handle` here is an abstraction and can in practice be realized, e.g. via zero-knowledge proving.
2. `Allocate(Amount, Deposit_Handle, Address)`: Performs allocation of specific `Amount` from a previously made deposit (that corresponds to a `Deposit_Handle`) to the given `Address`
3. `Withdraw(Address, PkPoP_Address, WithdrawalAddress)`: Performs withdrawal of a previous allocation to an `Address`  (via `Allocate` call) while providing a proof-of-possesion of a private key that corresponds to `Address`. If proof verification succeeds, the allocation is transfered to the `WithdrawalAddress`

In order to satisfy the goals of PIX in section 1.2, `W` MUST ensure the anonymity of the depositor and allocator towards the withdrawer.


## 2.2 Protocol flow

The protocol starts by the Entry node `A` making a deposit via `Deposit` call to `W`, depositing a certain amount of incentives. It keeps its `Deposit_Handle`.

This is typically done ahead of time, before `A` even knows about an Exit `B`.
The path between `A` and `B` SHOULD BE at least 1-hop (one relayer on both forward and return paths).


At a later point, once `A` knows about `B` and it chooses it as its Exit node service provider, `A` MAY instantiate a Session with `B` as described in RFC-0009. We assume this binding between `A` and `B` then uses a fixed return path pseudonym `P` of `A` (see RFC-0004) and it stays the same during the course of PIX execution.

The Session initiation MAY be used to communicate certain PIX parameters from `A` to `B` beforehand (see Appendix 2).

The protocol follows to perform the first `SSA_Agreement_1` between `A` and `B`:


### 2.2.1 The `SSA_Agreement_i`:

1. The `B` sends the `ExitCommitmentRequest_i`
2. Upon receiving `ExitCommitmentRequest_i`, `A` verifies the whether the parameters in the message are acceptable:
  a) if parameters are acceptable, it MUST respond by generating and sending `EntryCommitment_i` message to `B`. 
  b) if parameters are not acceptable, it terminates communication with `B` (cancelling the binding with common `P`)
3. `A` creates `SSA_i = CP_1[0] + CP_2[0] + ... CP_m[0] + ExitCommitment` 
4. `A` performs `Allocate(ChunkPrice, Deposit_Handle, SSA_i)` with `W`
5. Once `B` receives the full `EntryCommitment_i` message, the Exit node node MUST
  a) verifies the degree and number of received polynomials is acceptable, otherwise it MUST terminate communications with `A`
  b) creates `SSA_i = CP_1[0] + CP_2[0] + ... CP_m[0] + ExitCommitment`
  c) stores `A`'s pseudonym `P`, polynomial coefficient commitments `CP_1_0, CP_1_1 ... CP_m_(t-1)`
  d) awaits allocation to be deposited to `SSA_i`

The `B` MAY choose not to continue communicating with `A` unless the deposit in `5d` is finished or only for a limited time unless the deposit is detected.

Once the `SSA_Agreement_i` is finished by incentives being allocated to `SSA_i`, the bidirectional communication between `A` (with pseudonym `P`) and `B` then continues as specified in the HOPR protocol (RFC-0004), with additional changes that MUST be implemented:

- `A` now MUST generate SURBs with additional recipient data (see RFC-0004) containing `EncryptedShare_i_r_s` and MUST produce at least `m*(t+1)` of them (i.e. `r = 0..m`, `s=0..t+1`). Each SHOULD BE attached to a single SURB (along with `r` and `s`) sent to `B`.

- `B` receives the SURBs for pseudonym `P` from `A`. Once it is about to send a reply packet to `A`, it MUST a pick random SURB with pseudonym `P`, that contains `EncryptedShare_i_r_s`.

- Once a reply packet is delivered to the first downstream relayer on the return path, the Exit `B` is able to decrypt `EncryptedShare_i_r_s` as described in Section 2.2.5, resulting in `Share_i_r_s`.

- The Exit MUST verify `Share_i_r_s`. If the verification fails, the Exit MUST terminate communication with `A` (it SHOULD also dump all the SURBs indexed by `P`). 

- Once `B` uses at least `t+1` SURBs for some fixed `r` , it MUST obtain at least `Share_i_r_0,...Share_i_r_(t+1)` successfully verified shares. These then MAY be turned into `SSA_Priv_i_r` as described in Section 2.2.6.

- Once `SSA_Priv_i_r` is recovered for each `r=0..m`, the Exit computes `SSA_Priv_i = SSA_Priv_i_0 + SSA_Priv_i_1 + ... SSA_Priv_i_(m-1)`.

- The Exit MAY compute `PkPoP_SSA_i` using `SSA_Priv_i` and perform `Withdraw(SSA_i, PkPoP_SSA_i, WithdrawalAddress)` for a chosen `WithdrawalAddress` with `W`. It also MAY initiate `SSA_Agreement_(i+1)`, and the whole process restarts with `i+1`.

- If `i` reaches 2^32-1, the Exit MUST refuse further communication with `A`, forcing it to start over with a new pseudonym.

- The Entry MUST create a new deposit with `W` once it allocates all incentives that were previously deposited, to ensure further allocations could be done.


The following sections give details how are the individual steps from the `SSA_Agreement_i` achieved.

### 2.2.2 Generation of `ExitCommitmentRequest_i` at the Exit

The Exit node generates the `ExitCommitmentRequest` as follows:

It chooses a random scalar `b` (via a CSPRNG) and computes `ExitCommitment = b * BP` where `BP` is the point of large order on curve `C`, and stores `b` associated with the pseudonym `P`.

The Exit node chooses number `t` which will be a degree of polynomials. And `m` the number of polynomials. Both SHOULD BE unsigned 16-bit numbers.

It creates a 32-bit unsigned integer `params = (m << 16) || (t+1)`. In other words, `m` should be encoded as upper 16-bit half and `t+1` as lower 16-bit half of the `params` integer.

The message SHOULD BE constructed as follows:

```
struct ExitCommitmentRequest_i {
	P: Pseudonym,
	params: u64,
	i: u32,
	ExitCommitment: EncodedPoint 
    
}
```

### 2.2.3 Generation of `EntryCommitment_i` at the Entry

The Entry node creates this message once it learns `i` and the `params` value from the `ExitCommitmentRequest` message. This value allows it to determine whether the requested `t` and `m` values are acceptable.

The Entry generates `m` polynomials, each of degree `t` with (`t+1`) random coefficients (using a CSPRNG) from `F`: `P_i_0_0, P_i_0_1_, ... P_i_0_m, P_i_1_0, P_i_1_2, ... P_i_t_m` (`P_i_r_s` marks r-th coefficient of s-th polynomial for i-th SSA agreement). It stores these polynomials indexed by pseudonym `P` and their corresponding `i`.


The Entry then computes the commitments of each coefficient of each polynomial as:
`C_i_r_s = P_i_r_s * BP`. Naturally, these commitments form an `t`-by-`m` matrix (rows indexed by `r`, columns by `s`).


```
struct EntryCommitment_i {
	P: Pseudonym,
	i: u32,
	C_i_r_s: Matrix for r=0..t, j=0..s
}
```

Since this message might typically not fit the HOPR packet, the implementation SHOULD split the message in multiple piece-wise messages as: `EntryCommitment_i_0`, `EntryCommitment_i_1`, ... `EntryCommitment_i_t` as follows:

```
struct EntryCommitment_i_r {
	P: Pseudonym
	i: u32,
	r: u16,
	C_i_s: r-th row in Matrix with columns k=0..m 
}
```

In other words, the piecewise messages contain individual rows of the `C_r_s` matrix. If the HOPR packet cannot even fit the entire rows, then the rows SHOULD be also sent piecewise, with columns in the ascending order.


### 2.2.4 Generation of `EncryptedShare_i_r` at the Entry

Once the Entry `A` has sent `EntryCommitment_i` to `B` and has allocated incentives to `SSA_i`, it MUST start generating `EncryptedShare_i_r_s` for `r = 0..m, s=0..t+1`, each of which MUST BE from then on attached to SURBs sent to `B`.

To generate `EncryptedShare_i_r_s` for some `r`,`s`, the Entry `A` first computes `Share_i_r_s` as follows:

1. `A` chooses `x = HashToField(SenderKey, "HASH_SSA_POLY_SHARE_SCALAR")` where `SenderKey` is taken from the SURB the resulting `EncryptedShare_i_r_s` will be associated with - see RFC-0004. The `HashToField` operation is defined in RFC-9380 and `HASH_SSA_POLY_SHARE_SCALAR` is and additional DST input.
2. It evaluates polynomial `P_i_r` at `x`, so that `y = P_i_r[x] = P_i_r_0 + P_i_r_1 * x + ... + P_i_r_t * x^t`
3. It constructs `Share_i_r_s` as:
```
Share_i_r_s {
	i: u32
	r: u16,
	s: u16,
	y: [u8; |y|]
}
```

Note, that `|x| = |y|` since they both belong to the same finite field `F`.

The `KDF` is used to derive `(iv, k) = KDF("HASH_SSA_POLY_SHARE", ack_secret, P || i || r || s)` in order (first `iv` then `k`), where `ack_secret` is the Acknowledgement secret for the first downstream relayer on the return path from `B` to `A` (see Section 5.2.3.1 in RFC-0005).

Subsequently, the value `y` is encrypted as `E_y = E(iv, k , y)`.

4. The `EncryptedShare_i_r_s` is constructed as:
```
EncryptedShare_i_r_s {
	i: u32
	r: u16,
	s: u16,
	E_y: [u8; |E_y|]
}
```

The `EncryptedShare_i_r_s` is attached as additional recipient data (after `PoRValues` in section 3.4.3 of RFC-0004) to the corresponding SURB, with individual members encoded in the given order.


### 2.2.5 `EncryptedShare_i` decryption and verification

A SURB that contains additional data of size `|EncryptedShare_i_r_s|`, the data are interpreted as `EncryptedShare_i_r_s`.
If the `i` member is 0, the SURB MUST be used as if it did not contain any `EncryptedShare`. If `i` >= 1, the Exit node assumes it could be valid `EncryptedShare_i_r_s`.

As soon as the `B` uses the associated SURB to send reply data to `A`, the first down stream relayer on the return path sends an `Acknowledgement` (as per RFC-0005) to `B`, disclosing `ack_secret`.

`B` then uses KDF to generate `iv,k` and computes the `x` value (both as per Section 2.2.4).

Subsequently, it can obtain `Share_i_r_s = D(iv, k, E_y)`. 

In the next step, `B` verifies that `Share_i_r_s` corresponds to polynomial `P_i_r` by evaluating:

`LHS = CP_i_r_0 + x * CP_i_r_1 + x^2 * CP_i_r_2 + ... x^t * CP_i_r_t`
`RHS = y * BP`

The verification succeeds if `RHS - LHS = 0` (where 0 denotes the neutral element of `C`'s curve group). 

On successful verification, `B` knows that `(x, y)` constitutes a valid share, that can be used to recover `SSA_Priv_i_r`.


### 2.2.6 Recovery of `SSA_Priv_i_r` and `SSA_Priv_i` at the Exit

Once the Exit `B` determines at least `t+1` `(x_i, y_i)`-pairs (`i=0..t`), as per previous section, it can recover `SSA_Priv_i_r` by executing Lagrange interpolation of the `P_i_r` polynomial using `(x_0, x_0)` , `(x_1, y_2)` ... `(x_t, y_t)` as inputs.

The interpolation will yield the constant term `P_i_r_0` which is equal to `SSA_Priv_i_r`.

Once all polynomials `P_i_0`, `P_i_1`, ... `P_i_m` are interpolated, the `SSA_Priv_i_0`...`SSA_Prive_m` are determined. The `SSA_Priv_i` is the sum `SSA_Priv_i_0 + SSA_Priv_i_1 + ... SSA_Priv_i_m`. 

# Appendix 1

The HOPR PIX is the following instantion of PIX:

- `C` is sep256k1
- `H` is Blake3_256
- `E/D` is Chacha20
- `KDF` is instantiated using Blake3 in KDF mode [06], where the optional salt `s` is prepended to the key material `k`: `KDF(c,k,s)` = `blake3_kdf(c, s || k)`. If S is omitted: `KDF(c,k) = blake3_kdf(c,k)`.

# Appendix 2

The HOPR PIX is instantiated in conjunction with the Start and Session protocol, as per RFC-0009 and RFC-0008. The `ExitCommitmentRequest_i` and `EntryCommitment_i` messages are implemented as new Start protocol messages, with the pseudonym `P` replaced with the corresponding Session ID (that itself consists of the pseudonym and tag), that has been established beforehand. The HOPR PIX protocol is therefore bound to a particular pre-established HOPR Session.

