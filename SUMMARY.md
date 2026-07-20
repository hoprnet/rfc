# HOPR Protocol Summary

A single-file, precise condensation of RFC-0001 through RFC-0014 that lets a
reader grasp the whole HOPR stack without opening every document. It is
descriptive, not normative; the individual RFCs are authoritative. Statuses are
as of 2026-07-06.

## 1. RFC Inventory

| RFC  | Title                                  | Status         | Version |
| ---- | -------------------------------------- | -------------- | ------- |
| 0001 | RFC Lifecycle, Process and Structure   | Finalised      | v1.0.0  |
| 0002 | Common mixnet terms and keywords       | Finalised      | v1.0.0  |
| 0003 | HOPR Overview                          | Finalised      | v1.0.0  |
| 0004 | HOPR Packet Protocol                   | Finalised      | v1.0.1  |
| 0005 | Proof of Relay                         | Finalised      | v1.0.0  |
| 0006 | HOPR Mixer                             | Finalised      | v1.0.1  |
| 0007 | Economic Reward System                 | Implementation | v0.3.0  |
| 0008 | Session Data Protocol                  | Finalised      | v1.0.0  |
| 0009 | Session Start Protocol                 | Finalised      | v1.0.0  |
| 0010 | Automatic path discovery               | Finalised      | v1.1.0  |
| 0011 | Application Layer protocol             | Finalised      | v1.0.0  |
| 0012 | Protocol for Incentivization of eXits  | Draft (PR)     | v0.4.1  |
| 0013 | Return Path Incentivization            | Raw (PR stub)  | v0.1.0  |
| 0014 | Path-finding                           | Finalised      | v1.0.0  |

Protocol stack (RFC-0003), bottom to top: Transport (TCP/UDP/QUIC/...) →
HOPR Packet Protocol (0004) → HOPR Application Protocol (0011) → Session
Management (0008/0009) → Application.

## 2. Packet Layer (RFC-0004, SPHINX-based)

### 2.1 Packet structure and size

`HOPR_Packet = Alpha || Header || EncPayload || Ticket`. All packets have
identical fixed size: `|Alpha| + |Header| + PacketMax + |PaddingTag| + |Ticket|`,
where `PacketMax` is the global maximum payload size and `PaddingTag` is 1 byte.

- **Alpha**: ephemeral EC public key (Curve25519), blinded at every hop.
- **Header**: per-hop routing info, XOR-encrypted with per-hop PRG streams and
  filler construction for unlinkability; authenticated per hop with Poly1305.
  Size: `1 + |Pseudonym| + 3 * RoutingInfoLen` plus a `|T|`-byte tag, with
  `RoutingInfoLen = 1 + |ID| + |T| + |PoRString|`.
- **EncPayload**: payload wrapped in one PRP (Lioness over ChaCha20+BLAKE3)
  layer per hop.
- **Ticket**: payment/PoR data for the next hop (RFC-0005); replaced at every
  hop.

Path lengths: forward path 0–3 relay hops, return path 0–3 relay hops
(`MAX_INTERMEDIATE_HOPS = 3`; extended path = relays + destination).

### 2.2 Cryptographic instantiation (v1.0.1)

| Role | Primitive |
| ---- | --------- |
| EC group | Curve25519 |
| PRP (payload layers) | Lioness wide-block cipher over ChaCha20 + BLAKE3 |
| PRG (header masking) | ChaCha20 |
| One-time authenticator | Poly1305 |
| KDF | BLAKE3 KDF mode: `KDF(c,k,s) = blake3_kdf(c, s \|\| k)` |
| Hash-to-field HS | `hash_to_field`, `secp256k1_XMD:SHA3-256_SSWU_RO_` (RFC 9380) |

Shared secrets: standard SPHINX chain. For each hop `i`,
`SharedSecret_i = KDF("HASH_KEY_SPHINX_SECRET", Coeff × P_i, P_i)`, Alpha and
Coeff blinded by `B_i = KDF("HASH_KEY_SPHINX_BLINDING", ·, Alpha)`.
Replay protection: per-packet `ReplayTag = KDF("HASH_KEY_PACKET_TAG",
SharedSecret_i)`; nodes reject previously seen tags.

Header prefix byte per hop: bits [7–5] version (`001`), bit 4 `NoAckFlag`,
bit 3 `ReplyFlag`, bits [2–0] hop position.

### 2.3 Payload format

```text
PacketPayload {
  signals: u4,      // flow-control signals; 0 when unused
  num_surbs: u4,    // 0–15 SURBs carried in this packet
  surbs: [SURB; num_surbs],
  user_payload: [u8]
}
```

Padded to exactly `PacketMax + 1` bytes: zero bytes, then a 1-byte
`PaddingTag`, then the payload.

### 2.4 Pseudonyms, SURBs and replies

- **Sender pseudonym**: fixed-size (10-byte) identifier chosen by the sender,
  delivered to the destination inside the final header. Indexes reply state on
  both sides; does not reveal identity.
- **SURB (single-use reply block)**: pre-built return-path header the receiver
  can use to send exactly one reply packet to the pseudonym owner without
  learning its identity or route.

```text
SURB {
  alpha: Alpha,                 // for the return path
  header: Header,               // pre-built, ReplyFlag = 1
  sender_key: [u8],             // keys the extra reply-PRP layer
  first_hop_ident: [u8],        // where the receiver injects the reply
  por_values: PoRValues         // lets the receiver create a valid ticket
}
```

The SURB creator retains a `ReplyOpener { sender_key, rp_shared_secrets }`
indexed by pseudonym to unwrap replies. Reply payloads carry no SURBs and are
encrypted with `KDF("HASH_KEY_REPLY_PRP", SenderKey, Pseudonym)` before relays
add their layers. The reply sender cannot read or correlate the reply content
en route; the return path is chosen by the SURB creator.

The PIX draft (RFC-0012, §7) defines a SURB `recipient_data` extension field
(`recipient_data_len = 0` for ordinary SURBs) that it uses to attach encrypted
incentive shares to SURBs; RFC-0004 itself is v1.0.1 and does not include it.

SURB flow-control signals (implementation-defined, documented in RFC-0011,
whose interpretation is implementation-specific): `0x01` SURB distress (peer's
SURB stock low), `0x03` out of SURBs.

### 2.5 Acknowledgements

Every hop (unless `NoAckFlag = 1`) acknowledges the packet to its upstream
node with a signed `Acknowledgement { ack_secret, signature }`, where
`ack_secret = HS(SharedSecret_i, "HASH_KEY_ACK_KEY")` on success (random on
failure). Acknowledgements are themselves standard 0-hop forward packets with
`NoAckFlag = 1`. Ack secrets complete PoR challenges (§3) — and PIX (§7) reuses
them as decryption keys.

## 3. Incentives: Proof of Relay + Tickets (RFC-0005)

### 3.1 Payment channels (on-chain, HoprChannels contract)

Unidirectional channel `A→B`: `{source, destination, balance: u96,
ticket_index: u48, channel_epoch: u24, status}` with
`channel_id = keccak256(f(P_A) || f(P_B))`. States: `OPEN` →
`PENDING_TO_CLOSE` (grace period `T_closure` for the destination to redeem) →
`CLOSED` (epoch incremented). At most one channel per direction; both
directions may coexist. Curve: secp256k1; signatures ECDSA/ERC-2098 over
EIP-712 ticket hashes.

### 3.2 Tickets

```text
Ticket {
  channel_id, amount: u96, index: u48, index_offset: u32,
  encoded_win_prob: u56, channel_epoch: u24,
  challenge: ECPoint,           // = (own_key + next_ack_key) * G
  signature: ECDSASignature     // issuer's, over EIP-712 hash
}
```

Payment is probabilistic: after acknowledgement, the relayer derives VRF
values bound to its key and the ticket hash; the ticket *wins* iff
`luck = trunc_56(H(H_ticket || response || vrf_V)) < encoded_win_prob`.
Winning tickets are redeemed on-chain (channel balance decreases, ticket index
advances). Sender funds hop 1 with `amount = packet_price × (n−1)`; each
relayer re-issues a ticket for the next hop with decremented value; the final
hop receives a zero-value, zero-probability ticket. **The destination of a
packet earns nothing at the packet layer** — this is the gap PIX (§7) fills.

PoR chain: for hop `i`, `challenge_i = (HS(SS_i, "HASH_KEY_OWN_KEY") +
HS(SS_{i+1}, "HASH_KEY_ACK_KEY")) * G`. A relayer can only complete the
challenge (and make its ticket redeemable) after the *next* hop acknowledges —
i.e. payment requires proof the packet was handed onward. SURBs carry
`PoRValues` so reply packets are incentivised the same way, paid by the SURB
creator's channels along the return path.

## 4. Mixing (RFC-0006)

Each node delays every forwarded packet independently by a uniform random
delay in `[min_delay, min_delay + delay_range]` (defaults 0 ms / 200 ms),
released from a monotonic-clock priority queue (stable FIFO on ties, bounded
with backpressure). CSPRNG-generated, per-packet independent delays. Optional
stronger distributions (exponential/Poisson à la Loopix) are permitted.
Not defended: low-volume traffic windows, global passive adversaries, active
dropping, side channels.

## 5. Application, Session and Session-Start Layers

### 5.1 Application protocol (RFC-0011)

`ApplicationData { tag: u64 (3 MSBs zero), data, flags: u8 (not serialised) }`.
Tag space: `0x0` probing (RFC-0010); `0x1` session start (RFC-0009);
`0x2–0xd` user-defined;
`0xe` catch-all; `0xf … 2^61−1` session protocol (RFC-0008). Flags carry local
packet-layer ↔ upper-layer signals (SURB distress/out-of-SURBs).

### 5.2 Session start (RFC-0009, version byte 0x02)

Header: `version(1) || type(1) || length(2)`. Types: `0x00 StartSession`,
`0x01 SessionEstablished`, `0x02 SessionError`, `0x03 KeepAlive` (PIX draft
reserves `0x04`/`0x05`).

- `StartSession { challenge: u64 (CSPRNG), capabilities: u8, additional_data:
  u32, target: CBOR }` — `target` is what the Exit should connect to (e.g.
  `"127.0.0.1:1234"`, a URI, or any CBOR-encodable service designator).
- `SessionEstablished { challenge (echoed), session_id: CBOR }`.
- `SessionError { challenge, reason: u8 }` (`0x00` unknown, `0x01` no slots,
  `0x02` busy).
- `KeepAlive { flags: u8 = 0x00, additional_data: u64, session_id }`.

Default handshake timeout 30 s. HOPR Session ID = 10-byte pseudonym prefix +
u64 tag suffix (`0xabcd…ab:123456`); the suffix is the RFC-0011 session tag.
Entry-to-exit sessions inherently know the Exit's node identity; the Exit
never learns the Entry's identity (it addresses it via pseudonym + SURBs).

### 5.3 Session data (RFC-0008, version byte 0x01)

Header: `version(1) || type(1) || length(2)`. Types: `0x00 Segment`,
`0x01 RetransmissionRequest`, `0x02 FrameAcknowledgement`.

Segmentation: frames (application messages) split into ≤64 segments,
`frame_id: u32` (monotonic, 1-indexed), `seq_num: u8`, flags byte
(bit 7 = session-termination flag, bits 5–0 = segment count − 1). Overhead
10 bytes/segment over MTU `C`.

Modes: **unreliable** (no ACK/RTX, out-of-order allowed) and **reliable**
(frame ACKs, retransmission requests via 8-bit missing-segment bitmaps —
limiting reliable frames to ≤7 segments; defaults: frame timeout 800 ms, ACK
batching 100 ms, ≤3 retransmissions). Termination: empty segment with
termination flag.

## 6. Discovery, Probing and Path-Finding

### 6.1 Announcement and edges (RFC-0010)

Nodes announce on-chain (announcement contract binds off-chain packet key ↔
chain account ↔ transport multiaddress). A usable directed edge `u→v`
requires (a) an OPEN payment channel `u→v` and (b) transport connectivity —
except the *final* hop of a path, which needs no channel. The channel graph is
the canonical topology store.

### 6.2 Probing (RFC-0010)

Two modes: **immediate-neighbour** ping/pong (0-hop, nonce-based, carries one
SURB; yields latency, drop rate, ack rate) and **loopback path probes**
(sender = receiver over 1–3 random intermediate hops; payload indistinguishable
from cover traffic; 40-byte 5-slot path identifier + 8-byte probe ID +
16-byte ns timestamp). Probe results continuously score edges; unreliable
edges are passively starved of traffic (score-weighted selection), optionally
actively excluded (local decision only).

### 6.3 Path-finding (RFC-0014)

Edge score = probe success rate × step-function latency score
(≤75 ms → 1.0; ≤125 → 0.7; ≤200 → 0.3; >200 → 0.15; no data → 0.05), averaged
over immediate/intermediate streams. Path value = product of edge costs.
Candidate generation enumerates simple paths of exactly `hops+1` edges (with a
phase-2 fallback that appends a channel-less final hop), caps `max_paths = 8`,
validates against on-chain state (open channels on every non-final edge, no
duplicate nodes), then samples **weighted-random** by path value (cached
60 s TTL, background refresh 30 s). Constants: `edge_penalty = 0.5` for
unprobed edges, `min_ack_rate = 0.1`.

Output `ResolvedTransportRouting = { forward ValidatedPath, return
ValidatedPaths (for SURBs), HoprPseudonym }`.

## 7. PIX — Protocol for Incentivization of eXits (RFC-0012 draft v0.4.1)

Fills the "destination earns nothing" gap for Exit nodes serving Entry
traffic. Entities: Entry `A` (client), Exit `B` (server), privacy pool `W`
(`Deposit / Allocate / Withdraw`; MUST hide depositor+allocator from
withdrawer).

Mechanism (per agreement `i`, a non-zero u32 within a session):

1. `B` picks scalar `b`, sends `PixExitCommitmentRequest` (Session-Start type
   `0x04`) with `params = (m << 16) | (t+1)`, `chunk_price`, `chunk_size =
   m·(t+1)`, and `ExitCommitment = b·BP`.
2. `A` builds `m` random degree-`t` polynomials `P_r`, sends all coefficient
   commitments `C_{r,j} = a_{r,j}·BP` (`PixEntryCommitment`, type `0x05`).
3. Both compute the **session stealth address**
   `SSA_i = ExitCommitment + Σ_r C_{r,0}`; `A` allocates `chunk_price` to
   `SSA_i` in `W`.
4. `A` attaches one encrypted share per SURB (`recipient_data`):
   `x = HS(SenderKey, "HASH_SSA_POLY_SHARE_SCALAR")`, `y = P_r(x)`, encrypted
   with `(iv,k) = KDF("HASH_SSA_POLY_SHARE", ack_secret, session_id||i||r||s)`
   where `ack_secret` is the first return-path relayer's acknowledgement
   secret. `A` generates `m·(t+2)` shares (one spare per row).
5. When `B` *uses* a SURB and the first return-path relayer acknowledges,
   `B` learns `ack_secret`, decrypts `y`, and verifies it against the
   commitments (Feldman-VSS check `y·BP = Σ x^j·C_{r,j}`).
6. With `t+1` distinct valid shares per row, `B` interpolates each `a_{r,0}`,
   recovers `SSA_Priv_i = b + Σ_r a_{r,0}`, and withdraws from `W`.

Properties: payment is conditional on **actual reply-path handover** (packet-
layer proof, not end-to-end delivery); the pool hides who paid whom; griefing
is bounded (shares verified individually, agreement aborted on invalid data;
allocations need expiry/recovery policy). Requires ≥1 relay on forward and
return paths (0-hop replies make the Entry itself the acknowledger).
Instantiation: secp256k1, BLAKE3-256, ChaCha20, RFC 9380 hash-to-field.

## 8. Economic Reward System (RFC-0007)

Off-protocol Cover-Traffic reward distribution run by the HOPR Association:
peers filtered by Safe allowance / open channels / minimum stake (NFT holders
get a lower threshold), a sigmoid economic model converts stake to a yearly
message quota, and CT nodes send those messages over UDP sessions (relayers
earn normal PoR tickets from them). Precedent for later work: staking-gated
eligibility and stake-proportional traffic allocation.
