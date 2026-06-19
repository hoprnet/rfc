# RFC-0012: Protocol for Incentivization of eXits

- **RFC Number:** 0012
- **Title:** Protocol for Incentivization of eXits
- **Status:** Draft
- **Author(s):** Lukas Pohanka (@NumberFour8), Qianchen Yu (@QYuQianchen)
- **Created:** 2025-03-28
- **Updated:** 2026-06-19
- **Version:** v0.4.0 (Draft)
- **Supersedes:** none
- **Related Links:** [RFC-0001](../RFC-0001-rfc-process/0001-rfc-process.md), [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md),
  [RFC-0003](../RFC-0003-hopr-overview/0003-hopr-overview.md), [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md),
  [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md), [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md),
  [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md),
  [RFC-0011](../RFC-0011-application-protocol/0011-application-protocol.md)

## 1. Abstract

This RFC describes the Protocol for Incentivization of eXits (PIX). PIX adds an incentive mechanism for the HOPR Exit node that replies to traffic on
behalf of an Entry node over a HOPR session.

PIX allocates funds to a session stealth address that only the Exit can recover after it has obtained enough verified reply-path acknowledgements. The
protocol proves packet-layer handover to the first return-path relayer; it does not prove that application data was delivered end-to-end to the Entry.

## 2. Motivation

The HOPR packet protocol [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md) and Proof of Relay
[RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md) incentivise individual relay nodes. The recipient of forward mixnet traffic, also called
the Exit node, does not receive an in-protocol incentive when it performs work on behalf of the Entry node.

PIX defines a conditional incentive mechanism for Exit nodes. The condition is tied to successful use of reply-path SURBs and the acknowledgements
those reply packets produce.

## 3. Terminology and Notation

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are
to be interpreted as described in [01] when, and only when, they appear in all capitals, as shown here.

All terminology used in this document, including general mix network concepts and HOPR-specific definitions, is provided in
[RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md). This document additionally defines the following notation:

- `||` denotes byte-string concatenation.
- `0 <= x < k` denotes an integer index from `0` through `k-1`.
- `|x|` denotes the size of object `x` in bytes.
- Multi-byte numeric values are encoded as big-endian bytes unless otherwise specified.
- Character strings delimited by double quotes use ASCII single-byte encoding.
- `CSPRNG` stands for Cryptographically Secure Pseudorandom Number Generator.
- `SSA` stands for Session Stealth Address, the curve point to which a PIX incentive allocation is bound.

## 4. Specification

### 4.1 Setup

Let `C` be an algebraic curve group with scalar field `F`, large prime-order subgroup order `q`, and base point `BP`. The Diffie-Hellman problem in
the selected subgroup MUST provide at least 128-bit security.

Let `H` be a cryptographic hash function. Let `E(iv, k, m)` and `D(iv, k, c)` denote encryption and decryption using a symmetric cipher with IV or
nonce `iv` and secret key `k`.

Points on `C` are represented as `EncodedPoint`. Implementations MUST reject invalid encodings, points outside the selected subgroup, and the identity
point where a public commitment is expected.

A Key Derivation Function `KDF(c, k, s)` derives key material from context string `c`, high-entropy pre-key `k`, and optional salt `s`. A Hash to
Field operation `HS(s, t)` maps secret input `s` and domain tag `t` to an element of `F`.

PIX is defined between three entities:

1. Entry node `A`, also called the Client.
2. Exit node `B`, also called the Server.
3. Privacy pool `W`, which receives deposits, creates allocations, and validates withdrawals.

The forward and return paths between `A` and `B` SHOULD each contain at least one relay. Per
[RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md), acknowledgements on 0-hop paths MAY be omitted, so PIX cannot rely on 0-hop
reply paths.

### 4.2 Privacy Pool Operations

The privacy pool `W` is abstracted as a black box with the following operations:

1. `Deposit(Amount) -> Deposit_Handle`: deposits funds to be used as PIX incentives and returns a handle usable by the depositor.
2. `Allocate(Amount, Deposit_Handle, Address)`: allocates `Amount` from a previous deposit to `Address`.
3. `Withdraw(Address, PkPoP_Address, WithdrawalAddress)`: withdraws a previous allocation after validating proof of possession for `Address`.

To satisfy the privacy goals of PIX, `W` MUST hide the depositor and allocator from the withdrawer.

### 4.3 Parameters

Each PIX agreement is identified by `i`, a non-zero `u32`. The value `0` is reserved to signal that a SURB does not carry a PIX encrypted share.

The Exit chooses:

- `m`: the number of polynomials. It MUST satisfy `1 <= m <= 65535`.
- `t`: the polynomial degree. It MUST satisfy `0 <= t <= 65534`.
- `chunk_price`: the amount allocated to the resulting `SSA_i`.
- `chunk_size`: the number of successful reply handovers required before withdrawal. It MUST equal `m * (t + 1)`.

The packed parameter value is:

`params = (m << 16) | (t + 1)`

The Entry MUST reject `params` when `m` is zero, when `t + 1` is zero, or when `chunk_size != m * (t + 1)`.

### 4.4 PIX Session Messages

PIX uses two Session Start message discriminants reserved in [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md):

- `0x04`: `PixExitCommitmentRequest`
- `0x05`: `PixEntryCommitment`

The Session Start common message header supplies the protocol version, discriminant, and payload length. The PIX payloads below are encoded inside
that payload. `session_id` is the CBOR-encoded HOPR Session ID defined in
[RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md).

```
PixExitCommitmentRequest {
  session_id_len: u16,
  session_id: [u8; session_id_len],
  params: u32,
  i: u32,
  chunk_price: u128,
  chunk_size: u32,
  exit_commitment: EncodedPoint
}
```

```
PixEntryCommitment {
  session_id_len: u16,
  session_id: [u8; session_id_len],
  i: u32,
  r: u16,
  first_column: u16,
  column_count: u16,
  commitments: [EncodedPoint; column_count]
}
```

`PixEntryCommitment` messages carry row chunks of the commitment matrix. For each `r`, the Entry MUST send all coefficient commitments for columns
`0 <= j <= t`, using as many chunks as needed. `first_column + column_count` MUST NOT exceed `t + 1`. The Exit MUST wait until it has every row
`0 <= r < m` and every column `0 <= j <= t` before treating `EntryCommitment_i` as complete.

### 4.5 Agreement Flow

The Entry first calls `Deposit` on `W` and stores the returned `Deposit_Handle`. This can happen before the Entry knows which Exit will be used.

After a HOPR session exists between `A` and `B`, the first PIX agreement starts at `i = 1`:

1. `B` chooses random scalar `b` using a CSPRNG and computes `ExitCommitment = b * BP`.
2. `B` sends `PixExitCommitmentRequest` with `params`, `chunk_price`, `chunk_size`, `i`, and `ExitCommitment`.
3. `A` validates `params`, `chunk_price`, `chunk_size`, `i`, and `ExitCommitment`. If validation fails, `A` MUST terminate the PIX agreement.
4. For each `0 <= r < m`, `A` creates a degree-`t` polynomial:

   `P_i,r(x) = a_i,r,0 + a_i,r,1 * x + ... + a_i,r,t * x^t`

5. `A` computes coefficient commitments `C_i,r,j = a_i,r,j * BP` for every `0 <= r < m` and `0 <= j <= t`.
6. `A` sends all `PixEntryCommitment` chunks to `B`.
7. Both parties compute:

   `SSA_i = ExitCommitment + C_i,0,0 + C_i,1,0 + ... + C_i,m-1,0`

8. `A` performs `Allocate(chunk_price, Deposit_Handle, SSA_i)` with `W`.
9. `B` waits until it can observe the allocation to `SSA_i`. `B` MAY refuse service until the allocation is visible.

After `SSA_i` is allocated, `A` sends SURBs containing PIX encrypted shares as recipient data in the SURB extension field defined in
[RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md).

### 4.6 Encrypted Share Generation

For each `0 <= r < m`, the Entry MUST generate shares for `0 <= s <= t + 1`, producing `m * (t + 2)` encrypted shares. Each encrypted share MUST be
attached to exactly one SURB.

For a SURB with `SenderKey`, `A` computes:

1. `x = HS(SenderKey, "HASH_SSA_POLY_SHARE_SCALAR")`
2. `y = P_i,r(x)`
3. `(iv, k) = KDF("HASH_SSA_POLY_SHARE", ack_secret, session_id || i || r || s)`
4. `E_y = E(iv, k, encode_scalar(y))`

The `i`, `r`, and `s` values in the KDF salt MUST use their fixed-width big-endian encodings. `ack_secret` is the acknowledgement secret for the first
return-path relayer, as defined in [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md).

The SURB `recipient_data` is:

```
EncryptedShare {
  i: u32,
  r: u16,
  s: u16,
  E_y: [u8; |encode_scalar(y)|]
}
```

Ordinary SURBs set `recipient_data_len = 0`. A SURB with `recipient_data_len` equal to `|EncryptedShare|` MAY be interpreted as a PIX share. If
`i = 0`, the SURB MUST be treated as if it did not contain a PIX share.

### 4.7 Share Decryption and Verification

When `B` uses a SURB to send a reply packet, the first downstream relayer on the return path acknowledges the packet to `B` and discloses
`ack_secret`. At that point, `B` can derive `(iv, k)`, decrypt `E_y`, and recover `y`.

`B` recomputes `x = HS(SenderKey, "HASH_SSA_POLY_SHARE_SCALAR")` from the used SURB and verifies:

`LHS = C_i,r,0 + x * C_i,r,1 + x^2 * C_i,r,2 + ... + x^t * C_i,r,t`

`RHS = y * BP`

The share is valid only if `RHS - LHS` is the identity element of `C`. If verification fails, `B` MUST terminate the PIX agreement and discard unused
share-bearing SURBs for the session.

For each fixed `r`, `B` MUST collect at least `t + 1` valid shares with distinct `x` values. Duplicate `x` values for the same `r` MUST NOT count
toward the interpolation threshold.

### 4.8 Withdrawal Key Recovery

For each `0 <= r < m`, `B` uses Lagrange interpolation over any `t + 1` valid distinct `(x, y)` pairs to recover the constant coefficient `a_i,r,0`.

`B` then computes:

`SSA_Priv_i = b + a_i,0,0 + a_i,1,0 + ... + a_i,m-1,0 mod q`

This private scalar corresponds to `SSA_i`, because:

`SSA_i = SSA_Priv_i * BP`

After recovery, `B` MAY compute `PkPoP_SSA_i` and call `Withdraw(SSA_i, PkPoP_SSA_i, WithdrawalAddress)` for a chosen withdrawal address.

If more incentivised traffic is required, `B` MAY initiate `i + 1`. If `i` reaches `2^32 - 1`, `B` MUST refuse further PIX agreements for the current
session and require a new session.

## 5. Compatibility

PIX requires the SURB recipient-data extension introduced in [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md) version 1.1.0.
Peers that only support RFC-0004 version 1.0.0 will parse ordinary SURBs but cannot process PIX share-bearing SURBs.

PIX also requires the Session Start message discriminants reserved in [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md)
version 1.1.0. A peer that does not recognise `0x04` or `0x05` MUST reject those messages according to its normal unknown-message handling.

## 6. Security Considerations

`ExitCommitment` and all `EncodedPoint` commitments MUST be validated before use. Invalid curve points, identity points, or points outside the
selected subgroup can make verification unsound or expose implementations to invalid-curve attacks.

PIX proves that `B` handed reply packets to the first return-path relayer and received valid acknowledgements for those handovers. It does not prove
that the Entry received or accepted the application payload. A future protocol can add an Entry-signed application acknowledgement if end-to-end
delivery proof is required.

The Entry can grief the Exit by allocating funds and then sending invalid or insufficient shares. The Exit mitigates this by verifying each share
before counting it and by terminating the agreement on invalid data. Deployments SHOULD ensure that privacy pool allocations have an expiry or
recovery policy that is compatible with this failure mode.

The Exit learns only the session identifier, agreement parameters, commitments, and encrypted shares. The privacy pool `W` MUST hide the depositor and
allocator from the withdrawer; otherwise PIX does not meet its anonymity goal.

The Entry MUST NOT reuse the same `(session_id, i, r, s)` share tuple. The Exit MUST NOT count the same SURB or the same `x` value twice for a fixed
polynomial row.

## 7. Drawbacks

PIX increases SURB size and consumes reply-path acknowledgements as part of incentive unlocking. The Entry must create more SURBs than the minimum
threshold so that the Exit can tolerate at least one lost or unusable share per polynomial row.

The privacy pool is intentionally abstract in this RFC. Concrete deployments must specify deposit, allocation, withdrawal, expiry, and amount
semantics before PIX can be implemented end to end.

## 8. Appendix 1: HOPR PIX Instantiation

The current HOPR PIX instantiation uses:

- `C`: `secp256k1`, with `F` as its scalar field.
- `H`: `BLAKE3-256`.
- `E/D`: `ChaCha20` [03].
- `KDF`: `BLAKE3` derive-key mode [04], with optional salt prepended to the key material: `KDF(c, k, s) = blake3_kdf(c, s || k)`. If `s` is omitted,
  `KDF(c, k) = blake3_kdf(c, k)`.
- `HS`: the `hash_to_field` construction from [02], using domain separation string `secp256k1_XMD:BLAKE3-256_SSWU_RO_`.

The KDF output for `ChaCha20` MUST be split into a 96-bit nonce followed by a 256-bit key.

## 9. Appendix 2: HOPR Session Binding

HOPR PIX is instantiated with the Session Start and Session Data protocols from
[RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md) and [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md).

The `PixExitCommitmentRequest` and `PixEntryCommitment` payloads are carried by Session Start message types `0x04` and `0x05`. The `session_id` field
replaces the packet-layer pseudonym `P` in PIX salts and storage keys. The HOPR Session ID includes the pseudonym prefix and application tag described
in [RFC-0009](../RFC-0009-session-start-protocol/0009-session-start-protocol.md).

## 10. References

[01] Bradner, S. (1997). [Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119). _IETF RFC 2119_.

[02] Faz-Hernandez, A., et al. (2023). [Hashing to Elliptic Curves](https://www.rfc-editor.org/rfc/rfc9380.html). _IETF RFC 9380_.

[03] Nir, Y., & Langley, A. (2018). [ChaCha20 and Poly1305 for IETF Protocols](https://www.rfc-editor.org/rfc/rfc8439.html). _IETF RFC 8439_.

[04] BLAKE3 Team. (2021). [BLAKE3 one function, fast everywhere](https://github.com/BLAKE3-team/BLAKE3-specs/blob/master/blake3.pdf). _BLAKE3
specification_.

[05] Standards for Efficient Cryptography Group. (2010). [SEC 2: Recommended Elliptic Curve Domain Parameters](https://www.secg.org/sec2-v2.pdf).
_Standards for Efficient Cryptography_.
