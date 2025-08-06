# RFC-0003 HOPR Packet Protocol

- **RFC Number:** 0003
- **Title:** HOPR Packet Protocol
- **Status:** Draft
- **Author(s):** NumberFour8
- **Created:** 2025-03-19
- **Updated:** 2025-06-26
- **Version:** v0.1.0 (Draft)
- **Supersedes:** N/A
- **References:** [01](https://cypherpunks.ca/~iang/pubs/Sphinx_Oakland09.pdf)

## Abstract

This RFC describes the wire format of a HOPR packet and its encoding and decoding protocol. The HOPR packet format is heavily based on the Sphinx packet format, as it aims to fulfil the similiar set of goals: to provide anonymous indistinguishable packets, hiding the path length and unlinkability of messages. Moreover, the HOPR packet format adds additional information to the header, which allows incentivization of individual relay nodes via Proof of Relay.

The Proof of Relay (PoR) is described in the separate RFC-0004.

## 1. Introduction

The HOPR packet format is the fundamental building block of the HOPR protocol, allowing to build the HOPR mixnet. The format is designed to create indistinguishable packets sent between source and destination node using a set of relays (called the _path_, the individual relays on the path are sometimes called _hops_). Thus achieving anonymity and unlinkability of messages between sender and destination.
In HOPR protocol, the relays SHOULD also perform packet mixing, as described in [RFC-0005].
The format is built using the Sphinx packet format [01], but adds additional information for each hop, in order to allow incentivization of the hops (except the last one) for the relaying duties. The incentivization of the last hop is exempt from the HOPR packet format itself and is subject to a separate [RFC-0008].

The HOPR packet format does not require a reliable underlying transport or in-order delivery. The packet payloads are encrypted, however payload authenticity and integrity is not assured and MAY be ensured by the overlay protocol. In addition, the packet format is aimed to minimize overhead and maximize payload capacity.

The HOPR packet consists of two primary components:

- _Meta packet_ (also called the _Sphinx packet_) that carries the necessary routing information for the selected path and the encrypted payload. This will be described in the following sections.

- _Ticket_, which contains payout (incentivization) information for the next hop on the path. The structure of Tickets is described in the separate [RFC-0004].

**This document describes version 1.0.0 of the HOPR Packet format and protocol.**

### 1.1 Conventions and terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED",
"MAY", and "OPTIONAL" in this document are to be interpreted as described
in [IETF RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119) when, and only when, they appear in all
capitals, as shown here.

Terms defined in [RFC-0002] are used, as well as some following additional terms:

_peer_ (also _node_): participant of the network that can send, process and receive network packets

_peer public/private key_ (also _pubkey_ or _privkey_): part of a cryptographic key-pair owned by a peer.

_sender_: peer that initiates communication by sending out a packet

_receiver_: peer that is the destination of a packet

_hop_ (also _relay_): a peer that is not the sender nor destination of a packet

_path_: a set of hops between sender and receiver of a packet

_forward path_: a path that is used to deliver packet only in the direction from the sender to the receiver

_return path_: a path that is used to deliver packet in the opposite direction than _forward path_. The return path MAY be disjoint with the forward path.

_extended path_: a forward or return path which in addition contains the receiver or sender respectively.

_forward message_ (also _forward packet_): packet that is sent along the forward path.

_reply message_ (also _reply packet_): packet that is sent along the return path.

_pseudonym_: a randomly generated identifier of the sender. The pseudonym MAY be prefixed with a static prefix. The length such static prefix MUST NOT exceed half of the entire pseudonym's size. The pseudonym used in the forward message MUST be the same as the pseudonym used in the reply message.

_public key identifier_: a reasonably short identifier of public key of each peer. The size of such identifier SHOULD be strictly smaller than the size of the corresponding public key.

_|x|_: denotes length of binary representation of x in bytes.

### 1.2 Global packet format parameters

The HOPR packet format requires certain cryptographic primitives in place, namely:

- an Elliptic Curve (EC) group where the Elliptic Curve Diffie Hellman Problem (ECDLP) is hard. The peer public keys correspond to points on the chosen EC. The peer private keys correspond to scalars of the corresponding finite field.
- Pseudo-Random Permutation (PRP), commonly represented by a symmetric cipher
- Pseudo-Random Generator (PRG), commonly represented by a stream cipher or a block cipher in a stream-mode.
- One-time authenticator `OA(K, M)` where K denotes one-time key and M is the message being authenticated
- a Key Derivation Function (KDF) allowing to:
  - generate secret key material from a high-entropy pre-key K, context string C, and a salt S: `KDF(C, K, S)`. KDF will perform the necessary expansion to match the size required by the output. The Salt `S` argument is optional and MAY be omitted.
  - if the above is applied to an EC point as `K`, the point MUST be in its compressed form.
- Hash to Field (Scalar) operation `HS(S,T)` which computes an element of the field of the elliptic curve from RFC-0004, given the secret `S` and a tag `T` .

The concrete instantiations of these primitives are discussed in Appendix 1. All the primitives MUST have corresponding security bounds (e.g. they all have 128-bit security) and the generated key material MUST also satisfy the required bounds of the primitives.

The global value of `PacketMax` is the maximum size of the data in bytes allowed inside the packet payload.

## 2. Forward packet creation

The REQUIRED inputs for the packet creation are as follows:

- User's Packet payload (as a sequence of bytes)
- Sender pseudonym (as a sequence of bytes)
- forward path and an OPTIONAL list of multiple return paths

The input MAY also contain:

- unique bidirectional map between peer pubkeys and public key identifiers (_mapper_)

Note, that the mapper MAY only contain public key identifiers mappings of pubkeys from forward and return paths.

The packet payload MUST be between 0 to `PacketMax` bytes long.

The Sender pseudonym MUST be randomly generated for each packet but MAY contain a static prefix.

The forward and return paths MAY be represented by public keys of individual hops. Alternatively, the paths MAY be represented by public key identifiers and mapped using the mapper as needed.

The size of the forward and return paths (number of hops) MUST be between 0 and 3.

### 2.1 Partial Ticket creation

The creation of the HOPR packet starts with creation of the partial Ticket structure as defined in RFC-0004. If Ticket creation fails at this point, the packet creation process MUST be terminated.

The Ticket is created almost complete, apart from the Challenge field, which can be populated only after the Proof of Relay values have been fully created for the packet.

### 2.2 Generating the Shared secrets

In the next step, shared secrets for individual hops on the forward path are generated, as described in Section 3.2 in [1]:

Assume the length of the path is N (between 0 and 3) and each hop's public key is `Phop_i`.
The public key of the destination is `Pdst`.

Let the extended path be a list of `Phop_i` and `Pdst` (for i = 1 .. N).
For N = 0, the Extended path consists of just `Pdst`.

1. A new random ephemeral key pair is generated, `Epriv` and `Epub` respectively.
2. Set `Alpha` = `Epub` and `Coeff` = `Epriv`
3. For each (i-th) public key `P_i` the Extended path:
   - `SharedPreSecret_i` = `Coeff` \* `P_i`
   - `SharedSecret_i` = KDF("HASH_KEY_SPHINX_SECRET", `SharedPreSecret_i`, `P_i`)
   - if i == N, quit the loop
   - `B_i` = KDF("HASH_KEY_SPHINX_BLINDING", `SharedPreSecret_i`, `Alpha`)
   - `Alpha` = `B_i` \* `Alpha`
   - `Coeff` = `B_i` \* `Coeff`
4. Return `Alpha` and list of `SharedSecret_i`

For path of length N, the length of the list of Shared secrets is N+1.

In some instantiations, an invalid elliptic curve point may be encountered anywhere during step 3. In such case the computation MUST fail with an error. The process then MAY restart from step 1.

After KDF_expand, the `B_i` MAY be additionally transformed so that it conforms to a valid field scalar. Shall that operation fail, the computation MUST fail with an error and the process then MAY restart from step 1.

The returned `Alpha` value MAY be encoded to an equivalent representation (such as using elliptic curve point compression), so that space is preserved.

### 2.3 Generating the Proof of Relay

The packet generation continues with generation of per-hop proof of relay values, Ticket challenge and Acknowledgement challenge for the first downstream node. This generation is done for the

This is described in RFC-0004 and is a two-step process.

The first step uses the List of shared secrets for the extended path as input. As a result, there is a list of length N, where each entry contains:

- Ticket challenge for the hop i+1 on the extended path
- Hint value for the i-th hop

Both values in each list entry are elliptic curve points. The Ticket challenge value MAY be transformed via one-way cryptographic hash function, whose output MAY be truncated. See Appendix 1 on how such representation can be instantiated.

This list consists of `PoRStrings_i` entries.

In the second step of the PoR generation, the input is the first Shared secret from the List and optionally the second Shared secret (if the extended path is longer than 1). It outputs additional two entries:

- Acknowledgement challenge for the first hop
- Ticket challenge for the first ticket

Also here, both values are EC points, where the latter MAY be represented via the same one-way representation.

This tuple is called `PoRValues` and is used to finalize the partial Ticket - the Ticket challenge fills in the missing part in the `Ticket`.

### 2.4 Forward Meta Packet creation

At this point, there is enough information to generate the Meta packet, which is a logical construct that does not contain the `Ticket` yet.

The Meta Packet consists of the following components:

- `Alpha` value
- `Header` (an instantiation of the Sphinx mix header)
- padded and encrypted payload `EncPayload`

The order of these components MAY differ when packet is serialized to its binary form. The definitions of the above components follow in the next sections.

The `Alpha` value is obtained from the Shared secrets generation phase.

The `Header` is created differently depending whether this packet is a forward packet or a reply packet.

The creation of of the `EncPayload` depends on whether the packet is routed via the forward path or return path.

#### 2.4.1 Header creation

The header creation also closely follows [1] Section 3.2. Its creation is almost identical whether it is being created for the forward or return path.

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

Let `ID_i` be a public key identifier of `P_i` (by using the mapper), and `|T|` denote the size of the output of a chosen one-time authenticator.

Let RoutingInfoLen be equal to `1 + |ID_i| + |T| + |PoRString_i|`.

Allocate a zeroized `HdrExt` buffer of `1 + |Pseudonym| + 4 * RoutingInfoLen` bytes and another zeroized buffer `OATag` of `|T|` bytes.

For each i = 1 up to N+1 do:

1. Initialize PRG with `SharedSecret_{N-i+2}`
2. If i is equal to 1
   - Set `HdrExt[0]` to `HeaderPrefix_0`
   - Copy all bytes of `Pseudonym` to `HdrExt` at offset 1
   - Fill `HdrExt` from offset `1 + |Pseudonym|` up to `(5 - N) * RoutingInfoLen` with uniformly randomly generated bytes.
   - Perform an exclusive-OR (XOR) of bytes generated by the PRG with HdrExt, starting from offset 0 up to `1 + |Pseudonym| + (5 - N) * RoutingInfoLen`
   - If N > 0, generate _filler bytes_ given the list of Shared secrets as follows:
     - Allocate a zeroized buffer Filler of `(N-1)* RoutingInfoLen`
     - For each j from 1 to N-1:
       - Initialize new PRG instance with `SharedSecret_j`
       - Seek the PRG to position `1 + |Pseudonym| + (4 - j) * RoutingInfoLen`
       - XOR RoutingInfoLen bytes of the PRG to Filler from offset 0 up to `j * RoutingInfoLen`
       - Destroy the PRG instance
   - Copy the Filler bytes to `HdrExt` at offset `1 + |Pseudonym| + (5 - N) * RoutingInfoLen`
3. If i is greater than 1:
   - Copy bytes of `HdrExt` from offset 0 up to `1 + |Pseudonym| + 3 * RoutingInfoLen` to offset `RoutingInfoLen` in `HdrExt`
   - Set `HdrExt[i]` to `HeaderPrefix_{i-1}`
   - Copy `ID_{N-i+2}` to `HdrExt` starting at offset 1
   - Copy `OATag` to `HdrExt` starting at offset `1 + |ID_{N-i+2}|`
   - Copy bytes of `PoRString_i` to `HdrExt` starting at offset `1 + |ID_{N-i+2}| + |T|`
   - XOR PRG bytes to `HdrExt` from offset 0 up to `1 + |Pseudonym| + 3 * RoutingInfoLen`
4. Compute `K_tag` = KDF("HASH*KEY_HMAC", `SharedSecret*{N-i+2}`)
5. Compute `OA(K_tag, HdrExt[ from offset 0 up to 1 + |Pseudonym| + 3 * RoutingInfoLen)` and copy its output of `|T|` bytes to `OATag`

The output is the contents of `HdrExt` from offset 0 up to `1 + |Pseudonym| + 3 * RoutingInfoLen` and the `OATag`:

```
Header {
 header: [u8; 1 + |Pseudonym| + 3 * RoutingInfoLen]
 oa_tag: [u8; |T|]
}
```

#### 2.4.2 Forward payload creation

The packet payload consists of User payload given at the beginning of section 2. However, if any non-zero number of return paths has been given as well, the packet payload MUST consist of that many Single Use Reply Blocks (SURBs) that are prepended to the User payload.

The total size of the packet payload MUST not exceed `PacketMax` bytes and therefore the size of the User payload and the number of SURBs is bounded.

A packet MAY only contain SURBs and no User payload. There MUST NOT be more than 255 SURBs in a single packet.

For the above reasons, the forward payload MUST consist of:

- the number of SURBs (represented as single byte)
- all SURBs (if the number was non-zero)
- User's payload

```
PacketPayload {
 num_surbs: u8,
 surbs: [Surb; num_surbs]
 user_payload: [u8; <variable length>]
}
```

#### 2.4.3 Generating SURBs

The Single Use Reply Block is always generated by the Sender for its chosen pseudonym. Its purpose is to allow reply packet generation sent on the return path from the recipient back to sender.

The process of generating a single SURB is very similar to the process of creating the forward packet header.

As `SURB` is sent to the packet recipient, it also has its counterpart, called `ReplyOpener`. The `ReplyOpener` is generated alongside with the SURB and is stored at the Sender (indexed by its Pseudonym) and used later to decrypt the reply packet delivered to the Sender using the associated SURB.

Both `SURB` and the `ReplyOpener` are always bound to the chosen Sender pseudonym.

Inputs for creating a `SURB` and the `ReplyOpener`:

- return path
- sender pseudonym

OPTIONALLY, also a unique bidirectional map between peer pubkeys and public key identifiers (_mapper_) is given.

The generation of `SURB` and its corresponding `ReplyOpener` is as follows:

Assume the length of the return path is N (between 0 and 3) and each hop's public key is `Phop_i`.
The public key of the sender is `Psrc`.

Let the extended return path be a list of `Phop_i` and `Psrc` (for i = 1 .. N).
For N = 0, the Extended return path consists of just `Psrc`.

1. generate Shared secret list (`SharedSecret_i`) for the extended return path and the corresponding `Alpha` value as given in section 2.2.
2. generate PoR for the given extended return path: list of `PoRStrings_i` and `PoRValues`
3. generate Reply packet `Header` for the extended return path as in section 2.4.1:
   - The list of `PoRStrings_i` and list of `SharedSecret_i` from the step 1 and 2 are used
   - The 5th bit of the `HeaderPrefix` is set to 1 (see section 2.4.1)
4. generate a random cryptographic key material, for at least the selected security boundary (`SenderKey` as a sequence of bytes)

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

The Sender keeps the `ReplyOpener` (MUST be indexed by the chosen pseudonym), and puts the `SURB` in the forward packet payload.

#### 2.4.4 Payload padding

The packet payload MUST be padded in accordance to [01] to exactly `PacketMax + |PaddingTag|` bytes.

The process works as follows:

The payload MUST be always pre-pended with a `PaddingTag`. The `PaddingTag` SHOULD be 1 byte long.

If the length of the payload is still less than `PacketMax + |PaddingTag|` bytes, zero bytes MUST be prepended, until the length is exactly `PacketMax + |PaddingTag|` bytes.

```
PaddedPayload {
  zeros: [0u8; PacketMax - |PacketPayload|],
  padding_tag: u8,
  payload: PacketPayload
}
```

#### 2.4.5 Payload encryption

The encryption of the padded payload follows the same procedure from [01].

For each i=1 up to N:

1. Generate `Kprp` = KDF("HASH_KEY_PRP", `SharedSecret_i`)
2. Transform the `PaddedPayload` using PRP:

```
EncPayload = PRP(Kprp, PaddedPayload)
```

The Meta packet is formed from `Alpha`, `Header`, and `EncPayload`.

### 2.5 Final forward packet overview

The final structure of the HOPR packet format MUST consists of the logical Meta packet with the `Ticket` attached:

```
HOPR_Packet {
  alpha: Alpha,
   header: Header,
   encrypted_payload: EncPayload,
   ticket: Ticket
}
```

The packet is then sent to the peer represented by the first public key of the forward path.

Note that the size of the packet is exactly `|HOPR_Packet| = |Alpha| + |Header| + |PacketMax| + |PaddingTag| + |Ticket|`.
It can be also referred to the size of the logical Meta packet plus `|Ticket|`.

## 3. Reply packet creation

Upon receiving a forward packet, instead of sending the response back using an "inverse" forward path, the forward packet recipient SHOULD create a reply packet using one of a SURB. This is possible only if the Recipient received a SURB (with this or any previous forward packets) from an equal pseudonym.

The Recipient MAY use any SURB with the same pseudonym, however, in such case the SURBs MUST be used in the reverse order in which they were received.

The Sender of the forward packet MAY use a fixed random prefix of the pseudonym, to identify itself across multiple forward packets. In such case, the SURBs indexed with pseudonyms with the same prefix SHOULD be used in random order to construct reply packets.

The following inputs are REQUIRED to create the reply packet:

- User's Packet payload (as a sequence of bytes)
- Pseudonym of the forward packet sender
- Single Use Reply Block (`SURB`) corresponding to the above pseudonym

OPTIONALLY, a unique bidirectional map between peer pubkeys and public key identifiers (_mapper_) is also given.

The final reply packet is a `HOPR_Packet` and the means of obtaining the values needed for its construction are given in the next sections.

### 3.1 Reply packet ticket creation

The `PoRValues` and first reply hop key identifiers are extracted from the used `SURB`.

The mapper is used to map the key identifier (`first_hop_ident`) to the public key of the first reply hop, which is then used to retrieve required ticket information.

The Challenge from the `PoRValues` (`por_values`) in the `SURB` is used to construct the complete `Ticket` for the first hop.

### 3.2 Reply meta packet creation

The `Alpha` value (`alpha` field) and the packet `Header` (`header` field) are extracted from the used `SURB`.

#### 3.2.1 Reply payload creation

The reply payload is constructed as `PacketPayload` in section 2.4.2. However, the reply payload MUST not contain any SURBs.

```
PacketPayload {
 num_surbs: u8,   // = zero
 surbs: [Surb; 0] // empty
 user_payload: [u8; <variable length>]
}
```

The `PacketPayload` then MUST be padded to obtain `PaddedPayload` as described in section 2.4.4.

#### 3.2.2 Reply payload encryption

The `SenderKey` (`sender_key` field) is extracted from the used `SURB`.

The `PaddedPayload` of the reply packet MUST be encrypted as follows:

1. Generate `Kprp_reply` = KDF("HASH_KEY_REPLY_PRP", `SenderKey`, `Pseudonym`)
2. Transform the `PaddedPayload` as using PRP:

```
EncPayload = PRP(Kprp_reply, PaddedPayload)
```

This finalizes all the fields of the `HOPR_Packet` of for the reply.
The `HOPR_Packet` is sent to the peer represented by a public key, corresponding to `first_hop_ident` extracted from the `SURB` (that is the first peer on the return path).
For this operation, the mapper MAY be used to obtain the actual public key to route the packet.

## 4. Packet processing

This section describes the behavior of processing a `HOPR_Packet` instance, when received by a peer (hop).
Let `Phop_priv` be the private key corresponding to the public key `Phop` of the peer processing the packet.

Upon reception of a sequence of bytes that is at least `|HOPR_Packet|` bytes long, the `|Ticket|` is separated from the sequence. As the order of the fields in `HOPR_Packet` is implementation dependent, the way how this split is done is also implementation specific.

The resulting Meta packet is processed first, and if this processing is successful, the `Ticket` is validated as well, as defined in RFC-0004.

If any of the operations fail, the packet MUST be rejected and subsequently, it MUST be acknowledged. See Section 4.5

### 4.1 Advancing the Alpha value

In order to recover the `SharedSecret_i` , the `Alpha` value MUST be transformed using the following transformation:

1. Compute `SharedPreKey_i` = `Phop_priv` \* `Alpha`
2. `SharedSecret_i` = KDF("HASH_KEY_SPHINX_SECRET", `SharedPreKey_i`, `Phop`)
3. `B_i` = KDF("HASH_KEY_SPHINX_BLINDING", `SharedPreKey_i`, `Alpha`)
4. `Alpha` = `B_i` \* `Alpha`

Similarly as in section 2.2, the `B_i` in step 3 MAY be additionally transformed so that it conforms to a valid field scalar usable in step 4.
Shall the process fail in any of these steps (due to invalid EC point or field scalar), the process MUST terminate with an error and the entire packet MUST be rejected.

Also derive the `ReplayTag` = KDF("HASH_KEY_PACKET_TAG", `SharedSecret_i`).
Verify that `ReplayTag` has not yet been seen by this node, and if yes, the packet MUST be rejected.

### 4.2 Header processing

In the next steps, the `Header` (field `header`) processed using the derived `SharedSecret_i` .

As per section 2.4.1, the `Header` consists of two byte sequences of fixed length: the `header` and `oa_tag`.

1. Generate `K_tag` = KDF("HASH_KEY_TAG", 0, `SharedSecret_i`)
2. Compute `oa_tag_c` = OA(`K_tag`, `header`)
3. If `oa_tag_c` != `oa_tag`, the entire packet MUST be rejected.
4. Initialize PRG with `SharedSecret_i` and XOR PRG bytes to `header`
5. The first byte of the transformed `header` represents the `HeaderPrefix`:
   - Verify that the first 3 most significant bits represent the supported version (`001`), otherwise the entire packet MUST be rejected.
   - If 3 least significant bits are not all zeros (meaning this node not the recipient):
     - Let `i` be the 3 least significant bits of `HeaderPrefix`
     - Set `ID_i` = `header[|HeaderPrefix|..|HeaderPrefix| + |ID|`] where `|ID|` is the fixed length of the public key identifiers (each `|ID_i|` = `|ID|`)
   - `Tag_i` = `header[|HeaderPrefix| + |ID|..|HeaderPrefix|+|ID|+|Tag|]`
   - `PoRString_i` = `header[|HeaderPrefix|+|ID|+|Tag|..|HeaderPrefix|+|ID|+|PoRString|]` where `|PorString|` is the length of entries in the `PorStrings_i` list
   - Shift `header` by `|HeaderPrefix|+|ID|+|Tag|..|HeaderPrefix|+|ID|+|PoRString|` bytes left (discarding those bytes)
   - Seek the PRG to the position`|HeaderLen|`
   - Apply the PRG keystream to `header`
   - Otherwise, if all 3 least significant bits are all zeroes, it means this node is the recipient:
     - Recover `pseudonym` as `header[|HeaderPrefix|..|HeaderPrefix| + |Pseudonym|]`
     - Recover the 5th and 4th most significant bit (`NoAckFlag` and `ReplyFlag`)

### 4.3 Packet processing

In the next step, the `encrypted_payload` is decrypted:

1. Generate `Kprp` = KDF("HASH_KEY_PRP", `SharedSecret_i`)
2. Transform the `encrypted_payload` using PRP:

```
new_payload = PRP(Kprp, encrypted_payload)
```

#### 4.3.1 Forwarded packet

If the processed header indicated, that the packet is destined for another node, the `new_payload` is the `encrypted_payload: EncryptedPayload` . The updated `header` and `alpha` values from the previous steps are used to construct the forwarded packet. A new `ticket` structure is created for the recipient (as described in RFC-0004).

The forwarded packet MUST have the identical structure :

```
HOPR_Packet {
  alpha: Alpha,
   header: Header,
   encrypted_payload: EncPayload,
   ticket: Ticket
}
```

#### 4.3.2 Final packet

If the processed header indicated, that this node is the final destination of the packet, the `ReplyFlag` is used to indicate subsequent processing.

#### 4.3.2.1 Forward packet

If the `ReplyFlag` is set to 0, the packet is a forward (not a reply) packet.

The `new_payload` MUST be the `PaddedPayload`.

#### 4.3.2.2 Reply packet

If the `ReplyFlag` is set to 1, it indicates that this is a reply packet, that requires further processing.
The `pseudonym` extracted during header processing is used to find the corresponding `ReplyOpener`. If it is not found, the packet MUST be rejected.

Once the `ReplyOpener` is found, the `rp_shared_secrets` are used to decrypt the `new_payload`:

For each `SharedSecret_k` in `rp_shared_secrets` do:

1. Generate `Kprp` = KDF("HASH_KEY_PRP", `SharedSecret_k`)
2. Transform the `new_payload` using PRP:

```
new_payload = PRP(Kprp, new_payload)
```

This will invert the PRP transformations done at each forwarding hop. Finally, the additional reply PRP transformation has to be inverted (using `sender_key` from the `ReplyOpener` and `pseudonym` ):

1. Generate `Kprp_reply` = KDF("HASH_KEY_REPLY_PRP", `sender_key`, `pseudonym`)
2. Transform the `new_payload` as using PRP:

```
new_payload = PRP(Kprp_reply, new_payload)
```

The `new_payload` now MUST be `PaddedPayload`.

#### 4.3.3 Interpreting the payload

In any case, the `new_payload` is `PaddedPayload`.

The `zeros` are removed until the `padding_tag` is found. If it cannot be found, the packet MUST be rejected.
The `payload: PacketPayload` is extracted. If `num_surbs` > 0, the contained SURBs SHOULD be stored to be used for future reply packet creation, indexed by the `pseudonym` extracted during header processing.

The `user_payload` can then be used by the upper protocol layer.

### 4.4 Ticket verification and acknowledgement

In the next step the, `ticket` MUST be pre-verified using the `SharedSecret_i`, as defined in RFC-0004.
If the packet was not destined for this node (not final) OR the packet is final and the `NoAckFlag` is 0, the packet MUST be acknowledged.

The acknowledgement of the successfully processed packet is created as per RFC-0004 using `ack_key` = HS(`SharedSecret_i`, "HASH_ACK_KEY"). The `ack_key` is the scalar in the field of the elliptic curve chosen in RFC-0004. The acknowledgement is sent back to the previous hop.

If the packet processing was not successful, a random acknowledgement MUST be generated (as defined in RFC-0004) and sent to the previous hop.

## Appendix 1

The current version is instantiated using the following cryptographic primitives:

- Curve25519 elliptic curve with the corresponding scalar field
- Both PRP and PRG are instantiated using Chacha20 [RFC-7539](https://www.rfc-editor.org/rfc/rfc7539)
- OA is instantiated with Poly1305 [RFC-7539](https://www.rfc-editor.org/rfc/rfc7539)
- KDF is instantiated using Blake3 in KDF mode, where the optional salt `S` is prepended to the key material `K`: `KDF(C,K,S) = blake3_kdf(C, S || K)`. If `S` is omitted: `KDF(C,K) = blake3_kdf(C,K)`.
- HS is instantiated via `hash_to_field` using `secp256k1_XMD:SHA3-256_SSWU_RO_` as defined in [RFC9380](https://www.rfc-editor.org/info/rfc9380). `S` is used a the secret input, and `T` as an additional domain separator.
