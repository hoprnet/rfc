# RFC-0004: HOPR Packet Protocol

- **RFC Number:** 0004
- **Title:** HOPR Packet Protocol
- **Status:** Finalised
- **Author(s):** Lukas Pohanka (@NumberFour8)
- **Created:** 2025-03-19
- **Updated:** 2025-10-27
- **Version:** v1.0.0 (Finalised)
- **Supersedes:** none
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md), [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md),
  [RFC-0006](../RFC-0006-hopr-mixer/0006-hopr-mixer.md), [RFC-0007](../RFC-0007-economic-reward-system/0007-economic-reward-system.md),
  [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md), [RFC-0011](../RFC-0011-application-protocol/0011-application-protocol.md)

## 1. Abstract

This RFC describes the wire format of a HOPR packet and its encoding and decoding protocols. The HOPR packet format is heavily based on the Sphinx
packet format [01], as it aims to fulfill a similar set of goals: providing anonymous, indistinguishable packets that hide path length and ensure
unlinkability of messages. The HOPR packet format extends Sphinx by adding information to support incentivisation of individual relay nodes through 
the Proof of Relay mechanism.

The Proof of Relay (PoR) mechanism is described in [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md). This RFC focuses on the packet
structure and cryptographic operations required for packet creation, forwarding, and processing.

## 2. Introduction

The HOPR packet format is the fundamental building block of the HOPR protocol, enabling the construction of the HOPR mix network. The format is designed to
create indistinguishable packets sent between source and destination through a set of relay nodes, as defined in
[RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md), thereby achieving unlinkability of messages between sender and destination.

In the HOPR protocol, relay nodes SHOULD perform packet mixing as described in [RFC-0006](../RFC-0006-hopr-mixer/0006-hopr-mixer.md) to provide
additional protection against timing analysis. The packet format is built on the Sphinx packet format [01] but adds per-hop information to enable
incentivisation of relay nodes (except the last hop) for their relay services. Incentivisation of the final hop is handled separately through the
economic reward system described in [RFC-0007](../RFC-0007-economic-reward-system/0007-economic-reward-system.md).

The HOPR packet format does not require a reliable underlying transport or in-order delivery, making it suitable for deployment over UDP or other
connectionless protocols. Packet payloads are encrypted; however, payload authenticity and integrity are not guaranteed by this layer and MAY be
provided by overlay protocols such as the session protocol ([RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md)). The packet format is
optimised to minimise overhead and maximise payload capacity within the fixed packet size constraint.

The HOPR packet consists of two primary parts:

1. **Meta packet** (also called the **Sphinx packet**): carries the routing information for the selected path and the encrypted payload. The meta packet
   includes:
   - An `Alpha` value (ephemeral public key) for establishing shared secrets
   - A `Header` containing routing information and per-hop instructions
   - An encrypted payload (`EncPayload`) containing the actual message data
   
   The meta packet structure and processing are described in detail in sections 3 and 5 of this RFC.

2. **Ticket**: contains payment and proof-of-relay information for the next hop on the path. The ticket structure enables probabilistic micropayments to
   incentivise relay nodes. Tickets are described in [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md).

These two parts are concatenated to form the complete HOPR packet, which has a fixed size regardless of the actual payload length to prevent traffic analysis based on packet size. This fixed size is achieved by padding payloads which fall below the maximum size in bytes.

**This document describes version 1.0.0 of the HOPR packet format and protocol.**

### 2.1. Conventions and terminology

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are
to be interpreted as described in [02] when, and only when, they appear in all capitals, as shown here.

Terms defined in [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md) are used throughout this document. Additionally, the following
packet-protocol-specific terms are defined:

**Peer public/private key** (also **pubkey** or **privkey**): part of a cryptographic key pair owned by a peer. The public key is used to establish
shared secrets for onion encryption, whilst the private key is kept secret and used to decrypt packets destined for that peer.

**Extended path**: a forward or return path that includes the final destination or original sender respectively. For a forward path of `N` hops, the
extended path contains `N` relay nodes plus the destination node (`N+1` nodes total). For a return path, it contains `N` relay nodes plus the original sender.

**Pseudonym**: a randomly generated identifier of the sender used to enable reply messages. The pseudonym MAY be prefixed with a static prefix to allow
the sender to be identified across multiple messages whilst maintaining anonymity. The length of any static prefix MUST NOT exceed half of the entire
pseudonym's size. The pseudonym used in the forward message MUST be identical to the pseudonym used in any reply message to enable proper routing.

**Public key identifier**: a compact identifier of each peer's public key. The size of such an identifier SHOULD be strictly smaller than the size of
the corresponding public key to reduce header overhead. Implementations MAY use truncated hashes of public keys as identifiers.

**|x|**: denotes the binary representation length of `x` in bytes. This notation is used throughout the specification to indicate field sizes.

If character strings (delimited via double-quotes, such as `"xyz-abc-123"`) are used in place of byte strings, their ASCII single-byte encoding is assumed. 
Non-ASCII character strings are not used throughout this document.

### 2.2. Global packet format parameters

The HOPR packet format requires certain cryptographic primitives in place, namely:

- an Elliptic Curve (EC) group where the Elliptic Curve Diffie-Hellman Problem (ECDLP) is hard. The peer public keys correspond to points on the
  chosen EC. The peer private keys correspond to scalars of the corresponding finite field.
- Pseudo-Random Permutation (PRP), commonly represented by a symmetric cipher
- Pseudo-Random Generator (PRG), commonly represented by a stream cipher or a block cipher in stream mode
- One-time authenticator `OA(K, M)` where K denotes a one-time key and M is the message being authenticated
- a Key Derivation Function (KDF) allowing:
  - generation of secret key material from a high-entropy pre-key K, context string C, and a salt S: `KDF(C, K, S)`. KDF will perform the necessary
    expansion to match the size required by the output. The Salt `S` argument is optional and MAY be omitted.
  - if the above is applied to an EC point as `K`, the point MUST be in its compressed form.
- Hash to Field (Scalar) operation `HS(S,T)` which computes a field element of the elliptic curve from
  [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md), given the secret `S` and a tag `T`.

The concrete instantiations of these primitives are discussed in Appendix 1. All the primitives MUST have corresponding security bounds (e.g., they
all have 128-bit security) and the generated key material MUST also satisfy the required bounds of the primitives.

The global value of `PacketMax` is the maximum size of the data in bytes allowed inside the packet payload.

## 3. Forward packet creation

The REQUIRED inputs for packet creation are as follows:

- User's packet payload (as a sequence of bytes)
- Sender pseudonym (as a sequence of bytes)
- forward path and an OPTIONAL list of one or more return paths

The input MAY also contain:

- unique bidirectional map between peer pubkeys and public key identifiers (_mapper_)

Note that the mapper MAY only contain public key identifier mappings of pubkeys from forward and return paths.

The packet payload MUST be between 0 and `PacketMax` bytes in length.

The sender pseudonym MUST be randomly generated for each packet header but MAY contain a static prefix.

The forward and return paths MAY be represented by public keys of individual hops. Alternatively, the paths MAY be represented by public key
identifiers and mapped using the mapper as needed.

The size of the forward and return paths (number of hops) MUST be between 0 and 3.

### 3.1. Partial ticket creation

The creation of the HOPR packet starts with the creation of the partial ticket structure as defined in
[RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md). If ticket creation fails at this point, the packet creation process MUST be terminated.

The ticket is created almost completely, apart from the Challenge field, which can be populated only after the Proof of Relay values have been fully
created for the packet.

### 3.2. Generating the Shared secrets

In the next step, shared secrets for individual hops on the forward path are generated, as described in Section 2.2 in [01]:

Assume the length of the path is `N` (between 0 and 3) and each hop's public key is `Phop_i`. The public key of the destination is `Pdst`.

Let the extended path be a list of `Phop_i` and `Pdst` (for `i = 1 .. N`). For `N = 0`, the extended path consists of just `Pdst`.

1. A new random ephemeral key pair is generated, `Epriv` and `Epub` respectively.
2. Set `Alpha` = `Epub` and `Coeff` = `Epriv`
3. For each (i-th) public key `P_i` the Extended path:
   - `SharedPreSecret_i` = `Coeff` \* `P_i`
   - `SharedSecret_i` = KDF("HASH_KEY_SPHINX_SECRET", `SharedPreSecret_i`, `P_i`)
   - if `i == N`, quit the loop
   - `B_i = KDF("HASH_KEY_SPHINX_BLINDING", SharedPreSecret_i, Alpha)`
   - `Alpha = B_i \* Alpha`
   - `Coeff = B_i \* Coeff`
4. Return `Alpha` and the list of `SharedSecret_i`

For path of length `N`, the list length of the Shared secrets is `N+1`.

In some instantiations, an invalid elliptic curve point may be encountered anywhere during step 3. In such case the computation MUST fail with an
error. The process then MAY restart from step 1.

After `KDF_expand`, the `B_i` MAY be additionally transformed so that it conforms to a valid field scalar. Should that operation fail, the computation
MUST fail with an error and the process then MAY restart from step 1.

The returned `Alpha` value MAY be encoded to an equivalent representation (such as using elliptic curve point compression), so that space is
preserved.

### 3.3. Generating the Proof of Relay

The packet generation continues with per-hop proof generation of relay values, Ticket challenge, and Acknowledgement challenge for the first
downstream node. This generation is done for each hop on the path.

This is described in [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md) and is a two-step process.

The first step uses the List of shared secrets for the extended path as input. As a result, there is a list of length N, where each entry contains:

- Ticket challenge for the hop i+1 on the extended path
- Hint value for the i-th hop

Both values in each list entry are elliptic curve points. The Ticket challenge value MAY be transformed via a one-way cryptographic hash function,
whose output MAY be truncated. See [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md) on how such representation is instantiated.

This list consists of `PoRStrings_i` entries.

In the second step of the PoR generation, the input is the first Shared secret from the List and optionally the second Shared secret (if the extended
path is longer than 1). It outputs additional two entries:

- Acknowledgement challenge for the first hop
- Ticket challenge for the first ticket

Also, here, both values are EC points, where the latter MAY be represented via the same one-way representation.

This tuple is called `PoRValues` and is used to finalise the partial Ticket: the Ticket challenge fills in the missing part in the `Ticket`.

### 3.4. Forward meta packet creation

At this point, there is enough information to generate the meta packet, which is a logical construct that does not contain the `ticket` yet.

The meta packet consists of the following components:

- `Alpha` value
- `Header` (an instantiation of the Sphinx mix header)
- padded and encrypted payload `EncPayload`

The above order of these components is canonical and MUST be followed when a packet is serialised to its binary form. The definitions of the above
components follow in the next sections.

The `Alpha` value is obtained from the Shared secrets generation phase.

The `Header` is created differently depending on whether this packet is a forward packet or a reply packet.

The creation of the `EncPayload` depends on whether the packet is routed via the forward path or return path.

#### 3.4.1. Header creation

The header creation also closely follows [01] Section 3.2. Its creation is almost identical whether it is being created for the forward or return
path.

The input for the header creation is:

- Extended path (of peer public keys `P_i`)
- Shared secrets from previous steps (`SharedSecret_i`)
- PoRStrings (each entry denoted a `PoRString_i` of equal lengths)
- Sender pseudonym (represented as a sequence of bytes)

Let `HeaderPrefix_i` be a single byte, where:

- The first 3 most significant bits indicate the version, and currently MUST be set to `001`.
- The 4th most significant bit indicates the `NoAckFlag`. It MUST be set to 1 when the recipient SHOULD NOT acknowledge the packet.
- The 5th most significant bit indicates the `ReplyFlag` and MUST be set to 1 if the header is created for the return path, otherwise it MUST be zero.
- The last remaining 3 bits represent the number `i`, in _most significant bits first_ format.

For example, the binary representation of `HeaderPrefix_3` with `ReplyFlag` set and `NoAckFlag` not set looks like this:

```
HeaderPrefix_3 = 0 0 1 0 1 0 1 1
```

The `HeaderPrefix_i` MUST not be computed for `i > 7`.

Let `ID_i` be a public key identifier of `P_i` (by using the mapper), and `|T|` denote the output's size of a chosen one-time authenticator. Since
`ID_i` MUST be all of equal lengths for each `i`, denote this length `|ID|`. Similarly, `|PoRString_i|` MUST have also all equal lengths of
`|PoRString|`.

Let `RoutingInfoLen` be equal to `1 + |ID| + |T| + |PoRString|`.

Allocate a zeroised `HdrExt` buffer of `1 + |Pseudonym| + 4 * RoutingInfoLen` bytes and another zeroed buffer `OATag` of `|T|` bytes.

For each i = 1 up to N+1 do:

1. Initialise PRG with `SharedSecret_{N-i+2}`
2. If i is equal to 1
   - Set `HdrExt[0]` to `HeaderPrefix_0`
   - Copy all bytes of `Pseudonym` to `HdrExt` at offset 1
   - Fill `HdrExt` from offset `1 + |Pseudonym|` up to `(5 - N) * RoutingInfoLen` with uniformly randomly generated bytes.
   - Perform an exclusive-OR (XOR) of bytes generated by the PRG with HdrExt, starting from offset 0 up to
     `1 + |Pseudonym| + (5 - N) * RoutingInfoLen`
   - If N > 0, generate _filler bytes_ given the list of Shared secrets as follows:
     - Allocate a zeroed buffer Filler of `(N-1)* RoutingInfoLen`
     - For each j from 1 to N-1:
       - Initialise a new PRG instance with `SharedSecret_j`
       - Seek the PRG to position `1 + |Pseudonym| + (4 - j) * RoutingInfoLen`
       - XOR RoutingInfoLen bytes of the PRG to Filler from offset 0 up to `j * RoutingInfoLen`
       - Destroy the PRG instance
   - Copy the Filler bytes to `HdrExt` at offset `1 + |Pseudonym| + (5 - N) * RoutingInfoLen`
3. If i is greater than 1:
   - Copy bytes of `HdrExt` from offset 0 up to `1 + |Pseudonym| + 3 * RoutingInfoLen` to offset `RoutingInfoLen` in `HdrExt`
   - Set `HdrExt[0]` to `HeaderPrefix_{i-1}`
   - Copy `ID_{N-i+2}` to `HdrExt` starting at offset 1
   - Copy `OATag` to `HdrExt` starting at offset `1 + |ID|`
   - Copy bytes of `PoRString_{N-i+2}` to `HdrExt` starting at offset `1 + |ID| + |T|`
   - XOR PRG bytes to `HdrExt` from offset 0 up to `1 + |Pseudonym| + 3 * RoutingInfoLen`
4. Compute `K_tag` = KDF("HASH*KEY_TAG", `SharedSecret*{N-i+2}`)
5. Compute `OA(K_tag, HdrExt[0 .. 1 + |Pseudonym| + 3 * RoutingInfoLen)` and copy its output of `|T|` bytes to `OATag`

The output is the contents of `HdrExt` from offset 0 up to `1 + |Pseudonym| + 3 * RoutingInfoLen` and the `OATag`:

```
Header {
  header: [u8; 1 + |Pseudonym| + 3 * RoutingInfoLen]
  oa_tag: [u8; |T|]
}
```

#### 3.4.2. Forward payload creation

The packet payload consists of the User payload given at the beginning of section 2. However, if any non-zero number of return paths has been given as
well, the packet payload MUST consist of that many Single Use Reply Blocks (SURBs) that are prepended to the User payload.

The total size of the packet payload MUST not exceed `PacketMax` bytes, and therefore the size of the User payload and the number of SURBs are bounded.

A packet MAY only contain SURBs and no User payload. There MUST NOT be more than 15 SURBs in a single packet. The packet MAY contain additional packet
signals for the recipient, typically the upper 4 bits of the SURB count field MAY serve this purpose.

For the above reasons, the forward payload MUST consist of:

- the number of SURBs
- all SURBs (if the number was non-zero)
- User's payload

```
PacketPayload {
  signals: u4,
  num_surbs: u4,
  surbs: [Surb; num_surbs]
  user_payload: [u8; <variable length>]
}
```

The `signals` and `num_surbs` fields MAY be encoded as a single byte, where the most-significant 4 bits represent the `signals` and the
least-significant 4 bits represent the `num_surbs`. When no signals are passed, the `signals` field MUST be zero.

The user payload usually consists of the Application layer protocol as described in
[RFC-0011](../RFC-0011-application-protocol/0011-application-protocol.md), but it can be arbitrary.

#### 3.4.3. Generating SURBs

The Single Use Reply Block is always generated by the sender for its chosen pseudonym. Its purpose is to allow reply packet generation sent on the
return path from the recipient back to the sender.

The process of generating a single SURB is very similar to the process of creating the forward packet header.

As the `SURB` is sent to the packet recipient, it also has its counterpart, called `ReplyOpener`. The `ReplyOpener` is generated alongside the SURB and is
stored at the sender (indexed by its pseudonym) and used later to decrypt the reply packet delivered to the sender using the associated SURB.

Both the `SURB` and the `ReplyOpener` are always bound to the chosen sender pseudonym.

Inputs for creating a `SURB` and the `ReplyOpener`:

- return path
- sender pseudonym

OPTIONALLY, also a unique bidirectional map between peer pubkeys and public key identifiers (_mapper_) is given.

The generation of `SURB` and its corresponding `ReplyOpener` is as follows:

Assume the length of the return path is N (between 0 and 3) and each hop's public key is `Phop_i`. The public key of the sender is `Psrc`.

Let the extended return path be a list of `Phop_i` and `Psrc` (for i = 1 .. N). For N = 0, the Extended return path consists of just `Psrc`.

1. Generate a Shared secret list (`SharedSecret_i`) for the extended return path and the corresponding `Alpha` value as given in section 3.2.
2. Generate PoR for the given extended return path: list of `PoRStrings_i` and `PoRValues`
3. Generate Reply packet `Header` for the extended return path as in section 3.4.1:
   - The list of `PoRStrings_i` and list of `SharedSecret_i` from steps 1 and 2 are used
   - The 5th bit of the `HeaderPrefix` is set to 1 (see section 3.4.1)
4. Generate random cryptographic key material, for at least the selected security boundary (`SenderKey` as a sequence of bytes)

`SURB` MUST consist of:

- `SenderKey`
- `Header` (for the return path)
- public key identifier of the first return path hop
- `PoRValues`
- `Alpha` value (for the return path)

```
SURB {
  alpha: Alpha,
  header: Header,
  sender_key: [u8; <variable length>]
  first_hop_ident: [u8; <variable length>]
  por_values: PoRValues
}
```

The corresponding `ReplyOpener` MUST consist of:

- `SenderKey`
- Shared secret list (`SharedSecret_i`)

```
ReplyOpener {
  sender_key: [u8; <variable length>]
  rp_shared_secrets: [SharedSecret; N+1]
}
```

The sender keeps the `ReplyOpener` (MUST be indexed by the chosen pseudonym), and puts the `SURB` in the forward packet payload.

#### 3.4.4. Payload padding

The packet payload MUST be padded in accordance with [01] to exactly `PacketMax + |PaddingTag|` bytes.

The process works as follows:

The payload MUST always be prepended with a `PaddingTag`. The `PaddingTag` SHOULD be 1 byte long.

If the length of the payload is still less than `PacketMax + |PaddingTag|` bytes, zero bytes MUST be prepended until the length is exactly
`PacketMax + |PaddingTag|` bytes.

```
PaddedPayload {
  zeros: [0u8; PacketMax - |PacketPayload|],
  padding_tag: u8,
  payload: PacketPayload
}
```

#### 3.4.5. Payload encryption

The encryption of the padded payload follows the same procedure from [01].

For each i=1 up to N:

1. Generate `Kprp` = KDF("HASH_KEY_PRP", `SharedSecret_i`)
2. Transform the `PaddedPayload` using PRP:

```
EncPayload = PRP(Kprp, PaddedPayload)
```

The Meta packet is formed from `Alpha`, `Header`, and `EncPayload`.

### 3.5. Final forward packet overview

The final structure of the HOPR packet format MUST consist of the logical meta packet with the `ticket` attached:

```
HOPR_Packet {
  alpha: Alpha,
  header: Header,
  encrypted_payload: EncPayload,
  ticket: Ticket
}
```

The packet is then sent to the peer represented by the first public key of the forward path.

Note that the size of the packet is exactly `|HOPR_Packet| = |Alpha| + |Header| + |PacketMax| + |PaddingTag| + |ticket|`. It can also be referred to as
the size of the logical meta packet plus `|ticket|`.

## 4. Reply packet creation

Upon receiving a forward packet, the forward packet recipient SHOULD create a reply packet using one of the SURBs. This is possible only if the recipient
received a SURB (with this or any previous forward packets) from an equal pseudonym.

The recipient MAY use any SURB with the same pseudonym; however, in such a case the SURBs MUST be used in the reverse order in which they were
received.

The sender of the forward packet MAY use a fixed random prefix of the pseudonym to identify itself across multiple forward packets. In such a case,
the SURBs indexed with pseudonyms with the same prefix SHOULD be used in random order to construct reply packets.

The following inputs are REQUIRED to create the reply packet:

- User's packet payload (as a sequence of bytes)
- Pseudonym of the forward packet sender
- Single Use Reply Block (`SURB`) corresponding to the above pseudonym

OPTIONALLY, a unique bidirectional map between peer pubkeys and public key identifiers (_mapper_) is also given.

The final reply packet is a `HOPR_Packet` and the means of getting the values needed for its construction are given in the next sections.

### 4.1. Reply packet ticket creation

The `PoRValues` and first reply hop key identifiers are extracted from the used `SURB`.

The mapper is used to map the key identifier (`first_hop_ident`) to the public key of the first reply hop, which is then used to retrieve the required
ticket information.

The Challenge from the `PoRValues` (`por_values`) in the `SURB` is used to construct the complete `Ticket` for the first hop.

### 4.2. Reply meta packet creation

The `Alpha` value (`alpha` field) and the packet `Header` (`header` field) are extracted from the used `SURB`.

#### 4.2.1. Reply payload creation

The reply payload is constructed as `PacketPayload` in section 3.4.2. However, the reply payload MUST not contain any SURBs.

```
PacketPayload {
  signals: u4,
  num_surbs: u4,   // = zero
  surbs: [Surb; 0] // empty
  user_payload: [u8; <variable length>]
}
```

The `PacketPayload` then MUST be padded to get `PaddedPayload` as described in section 3.4.4.

#### 4.2.2. Reply payload encryption

The `SenderKey` (`sender_key` field) is extracted from the used `SURB`.

The `PaddedPayload` of the reply packet MUST be encrypted as follows:

1. Generate `Kprp_reply` = KDF("HASH_KEY_REPLY_PRP", `SenderKey`, `Pseudonym`)
2. Transform the `PaddedPayload` using PRP:

```
EncPayload = PRP(Kprp_reply, PaddedPayload)
```

This finalises all the fields of the `HOPR_Packet` for the reply. The `HOPR_Packet` is sent to the peer represented by a public key, corresponding
to `first_hop_ident` extracted from the `SURB` (that is the first peer on the return path). For this operation, the mapper MAY be used to get the
actual public key to route the packet.

## 5. Packet processing

This section describes the behaviour of processing a `HOPR_Packet` instance when received by a peer (hop). Let `Phop_priv` be the private key
corresponding to the public key `Phop` of the peer processing the packet.

Upon reception of a byte-sequence that is at least `|HOPR_Packet|` bytes long, the `|Ticket|` is separated from the sequence. As per section 2.4, the
order of the fields in `HOPR_Packet` is canonical, therefore the `Ticket` starts exactly at |HOPR_Packet| - |Ticket| byte-offset.

The resulting Meta packet is processed first, and if this processing is successful, the `Ticket` is validated as well, as defined in
[RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md).

If any of the operations fail, the packet MUST be rejected, and subsequently, it MUST be acknowledged. See Section 5.4.

### 5.1. Advancing the Alpha value

To recover the `SharedSecret_i`, the `Alpha` value MUST be transformed using the following transformation:

1. Compute `SharedPreKey_i` = `Phop_priv` \* `Alpha`
2. `SharedSecret_i` = KDF("HASH_KEY_SPHINX_SECRET", `SharedPreKey_i`, `Phop`)
3. `B_i` = KDF("HASH_KEY_SPHINX_BLINDING", `SharedPreKey_i`, `Alpha`)
4. `Alpha` = `B_i` \* `Alpha`

Similarly, as in section 3.2, the `B_i` in step 3 MAY be additionally transformed so that it conforms to a valid field scalar usable in step 4.

Should the process fail in any of these steps (due to invalid EC point or field scalar), the process MUST terminate with an error and the entire packet
MUST be rejected.

Also derive the `ReplayTag` = KDF("HASH_KEY_PACKET_TAG", `SharedSecret_i`). Verify that `ReplayTag` has not yet been seen by this node, and if yes,
the packet MUST be rejected.

### 5.2. Header processing

In the next steps, the `Header` (field `header`) is processed using the derived `SharedSecret_i`.

As per section 3.4.1, the `Header` consists of two byte sequences of fixed length: the `header` and `oa_tag`. Let |T| be the fixed byte-length of
`oa_tag` and |Header| be the fixed byte-length of `header`. Also denote |PoRString_i|, which are equal for all `i`, as |PoRString|. Likewise, |ID_i|
for all `i` as |ID|.

1. Generate `K_tag` = KDF("HASH_KEY_TAG", 0, `SharedSecret_i`)
2. Compute `oa_tag_c` = OA(`K_tag`, `header`)
3. If `oa_tag_c` != `oa_tag`, the entire packet MUST be rejected.
4. Initialise PRG with `SharedSecret_i` and XOR PRG bytes to `header`
5. The first byte of the transformed `header` represents the `HeaderPrefix`:
   - Verify that the first 3 most significant bits represent the supported version (`001`), otherwise the entire packet MUST be rejected.
   - If 3 least significant bits are not all zeros (meaning this node not the recipient):
     - Let `i` be the 3 least significant bits of `HeaderPrefix`
     - Set `ID_i` = `header[|HeaderPrefix|..|HeaderPrefix| + |ID|`]
   - `Tag_i` = `header[|HeaderPrefix| + |ID| .. |HeaderPrefix| + |ID| + |T|]`
   - `PoRString_i` = `header[|HeaderPrefix|+ |ID| + |T|..|HeaderPrefix| + |ID| + |PoRString|]`
   - Shift `header` by `|HeaderPrefix| + |ID| + |T| .. |HeaderPrefix| + |ID| + |PoRString|` bytes left (discarding those bytes)
   - Seek the PRG to the position `|Header|`
   - Apply the PRG keystream to `header`
   - Otherwise, if all 3 least significant bits are all zeroes, it means this node is the recipient:
     - Recover `pseudonym` as `header[|HeaderPrefix| .. |HeaderPrefix| + |Pseudonym|]`
     - Recover the 5th and 4th most significant bit (`NoAckFlag` and `ReplyFlag`)

### 5.3. Packet processing

In the next step, the `encrypted_payload` is decrypted:

1. Generate `Kprp` = KDF("HASH_KEY_PRP", `SharedSecret_i`)
2. Transform the `encrypted_payload` using PRP:

```
new_payload = PRP(Kprp, encrypted_payload)
```

#### 5.3.1. Forwarded packet

If the processed header indicated that the packet is destined for another node, the `new_payload` is the `encrypted_payload: EncryptedPayload`. The
updated `header` and `alpha` values from the previous steps are used to construct the forwarded packet. A new `ticket` structure is created for the
recipient (as described in [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md)), while the current `ticket` structure MUST be verified (as
also described in [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md)).

The forwarded packet MUST have the identical structure:

```
HOPR_Packet {
  alpha: Alpha,
  header: Header,
  encrypted_payload: EncPayload,
  ticket: Ticket
}
```

#### 5.3.2. Final packet

If the processed header indicated that this node is the final destination of the packet, the `ReplyFlag` is used to indicate subsequent processing.

##### 5.3.2.1. Forward packet

If the `ReplyFlag` is set to 0, the packet is a forward (not a reply) packet.

The `new_payload` MUST be the `PaddedPayload`.

##### 5.3.2.2. Reply packet

If the `ReplyFlag` is set to 1, it indicates that this is a reply packet that requires further processing. The `pseudonym` extracted during header
processing is used to find the corresponding `ReplyOpener`. If it is not found, the packet MUST be rejected.

Once the `ReplyOpener` is found, the `rp_shared_secrets` are used to decrypt the `new_payload`:

For each `SharedSecret_k` in `rp_shared_secrets` do:

1. Generate `Kprp` = KDF("HASH_KEY_PRP", `SharedSecret_k`)
2. Transform the `new_payload` using PRP:

```
new_payload = PRP(Kprp, new_payload)
```

This will invert the PRP transformations done at each forwarding hop. Finally, the additional reply PRP transformation has to be inverted (using
`sender_key` from the `ReplyOpener` and `pseudonym` ):

1. Generate `Kprp_reply` = KDF("HASH_KEY_REPLY_PRP", `sender_key`, `pseudonym`)
2. Transform the `new_payload` as using PRP:

```
new_payload = PRP(Kprp_reply, new_payload)
```

The `new_payload` now MUST be `PaddedPayload`.

#### 5.3.3. Interpreting the payload

In any case, the `new_payload` is `PaddedPayload`.

The `zeros` are removed until the `padding_tag` is found. If it cannot be found, the packet MUST be rejected. The `payload: PacketPayload` is
extracted. If `num_surbs` > 0, the contained SURBs SHOULD be stored to be used for future reply packet creation, indexed by the `pseudonym` extracted
during header processing.

The `user_payload` can then be used by the upper protocol layer.

### 5.4. Ticket verification and acknowledgement

In the next step the `ticket` MUST be pre-verified using the `SharedSecret_i`, as defined in
[RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md). If the packet was not destined for this node (not final) OR the packet is final and the
`NoAckFlag` is 0, the packet MUST be acknowledged.

The acknowledgement of the successfully processed packet is created as per [RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md) using
`SharedKey_i+1_ack` = `HS(SharedSecret_i, "HASH_ACK_KEY")`. The `SharedKey_i+1_ack` is the scalar in the field of the elliptic curve chosen in
[RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md). The acknowledgement is sent back to the previous hop.

This is done by creating and sending a standard forward packet directly to the node the original packet was received from. The `NoAckFlag` on this packet
MUST be set. The `user_payload` of the packet contains the encoded `Acknowledgement` structure as defined in
[RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md). The `num_surbs` of this packet MUST be set to 0.

If the packet processing was not successful at any point, a random acknowledgement MUST be generated (as defined in
[RFC-0005](../RFC-0005-proof-of-relay/0005-proof-of-relay.md)) and sent to the previous hop.

## 6. Appendix A

The current version is instantiated using the following cryptographic primitives:

- Curve25519 elliptic curve with the corresponding scalar field
- PRP is instantiated using Lioness wide-block cipher [05] over ChaCha20 and Blake3
- PRG is instantiated using ChaCha20 [03]
- OA is instantiated with Poly1305 [03]
- KDF is instantiated using Blake3 in KDF mode [06], where the optional salt `S` is prepended to the key material `K`:
  `KDF(C,K,S) = blake3_kdf(C, S || K)`. If `S` is omitted: `KDF(C,K) = blake3_kdf(C,K)`.
- HS is instantiated via `hash_to_field` using `secp256k1_XMD:SHA3-256_SSWU_RO_` as defined in [04]. `S` is used a the secret input, and `T` as an
  additional domain separator.

## 7. References

[01] Danezis, G., & Goldberg, I. (2009). [Sphinx: A Compact and Provably Secure Mix Format](https://cypherpunks.ca/~iang/pubs/Sphinx_Oakland09.pdf).
_2009 30th IEEE Symposium on Security and Privacy_, 262-277.

[02] Bradner, S. (1997). [Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119). _IETF RFC 2119_.

[03] Nir, Y., & Langley, A. (2015). [ChaCha20 and Poly1305 for IETF Protocols](https://www.rfc-editor.org/rfc/rfc7539.html). _IETF RFC 7539_.

[04] Faz-Hernandez, A., et al. (2023). [Hashing to Elliptic Curves](https://www.rfc-editor.org/rfc/rfc9380.html). _IETF RFC 9380_.

[05] Anderson, R., & Biham, E. (1996). Two practical and provably secure block ciphers: BEAR and LION. _In International Workshop on Fast Software
Encryption (pp. 113-120). Berlin, Heidelberg: Springer Berlin Heidelberg._

[06] Connor, J., Aumasson, J.-P., Neves, S., Wilcox-O’Hearn, Z. (2021). [BLAKE 3 one function, fast everywhere](https://github.com/BLAKE3-team/BLAKE3-specs/blob/master/blake3.pdf)
