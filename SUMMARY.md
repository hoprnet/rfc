# HOPR Protocol Summary

A single-file, precise condensation of RFC-0001 through RFC-0014 that lets a reader grasp the whole HOPR stack without opening every document. It is
descriptive, not normative; the individual RFCs are authoritative. Statuses are as of 2026-10-16.

## 1. RFC Inventory

| RFC  | Title                                 | Status         | Version |
| ---- | ------------------------------------- | -------------- | ------- |
| 0001 | RFC Lifecycle, Process and Structure  | Finalised      | v1.0.0  |
| 0002 | Common mixnet terms and keywords      | Finalised      | v1.0.0  |
| 0003 | HOPR Overview                         | Finalised      | v1.0.0  |
| 0004 | HOPR Packet Protocol                  | Finalised      | v1.0.1  |
| 0005 | Proof of Relay                        | Finalised      | v1.0.0  |
| 0006 | HOPR Mixer                            | Finalised      | v1.0.1  |
| 0007 | Economic Reward System                | Implementation | v0.3.0  |
| 0008 | Session Data Protocol                 | Finalised      | v1.0.0  |
| 0009 | Session Start Protocol                | Finalised      | v4.0.0  |
| 0010 | Automatic path discovery              | Finalised      | v1.2.0  |
| 0011 | Application Layer protocol            | Finalised      | v1.0.0  |
| 0012 | Protocol for Incentivization of eXits | Draft (PR)     | v0.6.0  |
| 0013 | Return Path Incentivization           | Raw (PR stub)  | v0.1.0  |
| 0014 | Path-finding                          | Finalised      | v1.1.0  |

Protocol stack (RFC-0003), bottom to top: Transport (TCP/UDP/QUIC/...) → HOPR Packet Protocol (0004) → HOPR Application Protocol (0011) → Session
Management (0008/0009) → Application.

## 2. Packet Layer (RFC-0004, SPHINX-based)

### 2.1 Packet structure and size

`HOPR_Packet = Alpha || Header || EncPayload || Ticket`. All packets have identical fixed size:
`|Alpha| + |Header| + PacketMax + |PaddingTag| + |Ticket|`, where `PacketMax` is the global maximum payload size and `PaddingTag` is 1 byte.

- **Alpha**: ephemeral EC public key (Curve25519), blinded at every hop.
- **Header**: per-hop routing info, XOR-encrypted with per-hop PRG streams and filler construction for unlinkability; authenticated per hop with
  Poly1305. Size: `1 + |Pseudonym| + 3 * RoutingInfoLen` plus a `|T|`-byte tag, with `RoutingInfoLen = 1 + |ID| + |T| + |PoRString|`.
- **EncPayload**: payload wrapped in one PRP (Lioness over ChaCha20+BLAKE3) layer per hop.
- **Ticket**: payment/PoR data for the next hop (RFC-0005); replaced at every hop.

Path lengths: forward path 0–3 relay hops, return path 0–3 relay hops (`MAX_INTERMEDIATE_HOPS = 3` in RFC-0014; extended path = relays + destination).

### 2.2 Cryptographic instantiation (v1.0.1)

| Role                   | Primitive                                                     |
| ---------------------- | ------------------------------------------------------------- |
| EC group               | Curve25519                                                    |
| PRP (payload layers)   | Lioness wide-block cipher over ChaCha20 + BLAKE3              |
| PRG (header masking)   | ChaCha20                                                      |
| One-time authenticator | Poly1305                                                      |
| KDF                    | BLAKE3 KDF mode: `KDF(c,k,s) = blake3_kdf(c, s \|\| k)`       |
| Hash-to-field HS       | `hash_to_field`, `secp256k1_XMD:SHA3-256_SSWU_RO_` (RFC 9380) |

Shared secrets: standard SPHINX chain. For each hop `i`, `SharedSecret_i = KDF("HASH_KEY_SPHINX_SECRET", Coeff × P_i, P_i)`, `Alpha` and `Coeff`
blinded by `B_i = KDF("HASH_KEY_SPHINX_BLINDING", Coeff × P_i, Alpha)`. Replay protection: per-packet
`ReplayTag = KDF("HASH_KEY_PACKET_TAG", SharedSecret_i)`; nodes reject previously seen tags.

Header prefix byte per hop: bits [7–5] version (`001`), bit 4 `NoAckFlag`, bit 3 `ReplyFlag`, bits [2–0] hop position.

### 2.3 Payload format

```text
PacketPayload {
  signals: u4,      // flow-control signals; 0 when unused
  num_surbs: u4,    // 0–15 SURBs carried in this packet
  surbs: [SURB; num_surbs],
  user_payload: [u8]
}
```

Padded to exactly `PacketMax + 1` bytes: zero bytes, then a 1-byte `PaddingTag`, then the payload.

### 2.4 Pseudonyms, SURBs and replies

- **Sender pseudonym**: fixed-size identifier, randomly generated per packet but MAY carry a static prefix (at most half its size) so the sender can
  be recognised across packets; delivered to the destination inside the final header. Indexes reply state on both sides; does not reveal identity.
  HOPR Session IDs use a 10-byte pseudonym prefix (§5.2).
- **SURB (single-use reply block)**: pre-built return-path header the receiver can use to send exactly one reply packet to the pseudonym owner without
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

The SURB creator retains a `ReplyOpener { sender_key, rp_shared_secrets }` indexed by pseudonym to unwrap replies. Reply payloads carry no SURBs and
are encrypted with `KDF("HASH_KEY_REPLY_PRP", SenderKey, Pseudonym)` before relays add their layers. The return path is chosen by the SURB creator;
the reply sender learns neither it nor the creator's identity. A recipient uses the SURBs of a pseudonym in reverse order of receipt (random order
across pseudonyms sharing a static prefix).

PIX (RFC-0012, §7) attaches an encrypted incentive share to every SURB as additional recipient data after `por_values` (a zeroed slot, `i = 0`, when
no share is carried); its HOPR layout is `PoRValues (54 B) || EncryptedShare (38 B) || SURB generation (1 B)` = 93 bytes. RFC-0004 v1.0.1 itself does
not define this field.

SURB flow-control signals (RFC-0011 Appendix 1; interpretation is implementation-specific): `0x01` SURB distress (peer's SURB stock below a
threshold), `0x03` out of SURBs (the packet used the sender's last SURB).

### 2.5 Acknowledgements

Every relay, and the final recipient unless `NoAckFlag = 1`, acknowledges the packet to its upstream node with a signed
`Acknowledgement { ack_secret, signature }` (signature over `H(ack_secret)`), where `ack_secret = HS(SharedSecret_i, "HASH_KEY_ACK_KEY")` on success
and random on any processing or ticket-validation failure (tag as in RFC-0005; RFC-0004 §5.4 writes `"HASH_ACK_KEY"`). Acknowledgements are themselves
standard 0-hop forward packets with `NoAckFlag = 1` and no SURBs. Ack secrets complete PoR challenges (§3) — and PIX (§7) reuses them as key material
for decrypting shares.

## 3. Incentives: Proof of Relay + Tickets (RFC-0005)

### 3.1 Payment channels (on-chain, HoprChannels contract)

Unidirectional channel `A→B`: `{source, destination, balance: u96, ticket_index: u48, channel_epoch: u24, status}` with
`channel_id = keccak256(f(P_A) || f(P_B))`, opened by `A` with `ticket_index = 0`, `channel_epoch = 1` and a balance between `MIN_USED_BALANCE` and
`MAX_USED_BALANCE` (`1e-18` / `1e7` HOPR). States: `OPEN` → `PENDING_TO_CLOSE` (notice period `T_closure`, in block timestamps, for the destination to
redeem) → `CLOSED` (balance reset, epoch incremented); the destination may also close unilaterally, forfeiting unclaimed tickets. At most one channel
per direction; both directions may coexist. Curve: secp256k1; signatures ECDSA/ERC-2098 over EIP-712 ticket hashes.

### 3.2 Tickets

```text
Ticket {
  channel_id, amount: u96, index: u48, index_offset: u32,
  encoded_win_prob: u56, channel_epoch: u24,
  challenge: ECPoint,           // = (own_key + next_ack_key) * G
  signature: ECDSASignature     // issuer's, over EIP-712 hash
}
```

`ECPoint` is a one-way encoding (last 20 bytes of `keccak256` of the uncompressed point). Payment is probabilistic: after acknowledgement, the relayer
derives VRF values bound to its key and the ticket hash; the ticket _wins_ iff `luck = trunc_56(H(H_ticket || response || vrf_V)) < encoded_win_prob`.
Winning tickets are redeemed on-chain (balance decreases by `amount`, `ticket_index := index + index_offset`). Sender funds hop 1 with
`amount = packet_price × (n−1)` for `n−1` relays; each relayer verifies its ticket (signature, amount, epoch, issuer funds) and re-issues one for the
next hop with the value typically reduced by one packet price; the final hop receives a zero-value, zero-probability ticket. **The destination of a
packet earns nothing at the packet layer** (RFC-0004 defers final-hop incentivisation to RFC-0007) — this is the gap PIX (§7) fills.

PoR chain: for hop `i`, `challenge_i = (HS(SS_i, "HASH_KEY_OWN_KEY") + HS(SS_{i+1}, "HASH_KEY_ACK_KEY")) * G`. A relayer can only complete the
challenge (and make its ticket redeemable) after the _next_ hop acknowledges — i.e. payment requires proof the packet was handed onward. SURBs carry
`PoRValues` so reply packets are incentivised the same way, paid by the SURB creator's channels along the return path.

## 4. Mixing (RFC-0006)

Each node delays every forwarded packet independently by a uniform random delay in `[min_delay, min_delay + delay_range]` (defaults 0 ms / 200 ms),
released from a monotonic-clock priority queue (stable FIFO on ties, bounded with backpressure). CSPRNG-generated, per-packet independent delays.
Optional stronger distributions (exponential/Poisson à la Loopix) are permitted. Not defended: low-volume traffic windows, global passive adversaries,
active dropping, side channels.

## 5. Application, Session and Session-Start Layers

### 5.1 Application protocol (RFC-0011)

`ApplicationData { tag: u64 (3 MSBs zero), data, flags: u8 (not serialised) }`. Tag space: `0x0` probing (RFC-0010); `0x1` session start (RFC-0009);
`0x2–0xd` user-defined; `0xe` catch-all; `0xf … 2^61−1` session protocol (RFC-0008). Flags carry local signals — upper layer → packet layer in the 4
MSBs, packet layer → upper layer in the 4 LSBs (e.g. SURB distress/out-of-SURBs); either side MAY ignore them.

### 5.2 Session start (RFC-0009, version byte 0x04)

Header: `version(1) || type(1) || length(2)`, integers big-endian. Types: `0x00 StartSession`, `0x01 SessionEstablished`, `0x02 SsaCommit`,
`0x03 SsaRequest`, `0x04 SessionError`, `0x05 KeepAlive`.

- `StartSession { challenge: u64 (CSPRNG), capabilities: u8, additional_data: [u8; 16], target: CBOR }` — `target` is what the Exit should connect to
  (e.g. `"127.0.0.1:1234"`, a URI, or any CBOR-encodable service designator). Additional Data bits 127–96: PIX parameters word (§7) if `UsePIX`;
  95–64: desired SURB buffer size unless `NoRateControl`; 63–0 reserved (zero).
- Capability bits: 0 `NoDelay`, 1 `RetransmissionNack`, 2 `RetransmissionAck` (bits 0–2 only together with 3; 1+2 = combined), 3 `Segmentation`, 4
  `NoRateControl` (Exit side only), 5 `UsePIX`; 6–7 reserved — a `StartSession` with a reserved bit set MUST be rejected.
- `SessionEstablished { challenge (echoed), session_id: CBOR }`.
- `SessionError { id_type: u8, id, reason: u8 }` — `0x00` challenge (before establishment, sent by the Exit) or `0x01` CBOR session ID (after
  establishment, either peer; the receiver closes without replying). Reasons: `0x00` unknown, `0x01` no slots, `0x02` busy, `0x03` unacceptable PIX
  params, `0x04` target not admitted; unknown codes read as `0x00`.
- `KeepAlive { flags: u8, additional_data: u64, session_id }` — mutually exclusive flags `0x01 BalancerTarget` (Entry: SURB buffer size the Exit
  should keep) and `0x02 BalancerState` (Exit: its current SURB buffer estimate); unknown bits ignored.
- `SsaRequest { params: u32, deposit_data: CBOR, commitments, missing_runs, session_id }` (Exit → Entry) — `deposit_data` maps SSA index → opaque
  bytes; `commitments` are `ssa_index: u32 || G` entries (new SSAs); `missing_runs` are `ssa_index: u32 || first: u16 || last: u16` entries
  (retransmission of lost constant-term commitments; empty deposit data, no new deposit); exactly one of the two is non-empty, and `params` MUST equal
  the advertised word. An Entry accepts ≤2 SSAs per request by default.
- `SsaCommit { ssa_index: u32, coefficient_index: u16, num_polynomials: u16, proof, commitments, session_id }` (Entry → Exit) — `ssa_index ≠ 0`;
  1–16192 `poly_index: u16 || G` entries; `proof` (`K` bytes) present iff `coefficient_index = 0`. All index-0 messages go first, each repeating the
  proof; in HOPR's constant-term mode every `SsaCommit` has index 0. `G`/`K` = 32/64 bytes (BabyJubJub) or 33/65 (secp256k1), per the suite in
  `params`.

Default handshake timeout `5 s × (hops + 2)` (hops = forward + return path hops). HOPR Session ID = 10-byte pseudonym prefix + u64 tag suffix
(`0xabcd…ab:123456`); the suffix is the RFC-0011 session tag. Entry-to-exit sessions inherently know the Exit's node identity; the Exit never learns
the Entry's identity (it addresses it via pseudonym + SURBs).

### 5.3 Session data (RFC-0008, version byte 0x01)

Header: `version(1) || type(1) || length(2)`. Types: `0x00 Segment`, `0x01 RetransmissionRequest`, `0x02 FrameAcknowledgement`.

Segmentation: frames (application messages) split into ≤64 segments, `frame_id: u32` (monotonic, 1-indexed), `seq_num: u8`, flags byte (bit 7 =
session-termination flag, bits 5–0 = segment count − 1). Overhead 10 bytes/segment over MTU `C`.

Modes: **unreliable** (no ACK/RTX, out-of-order allowed) and **reliable** (frame ACKs, retransmission requests as 5-byte `frame_id || bitmap` entries
— the 8-bit missing-segment bitmap limits reliable frames to ≤7 segments; defaults: frame timeout 800 ms, ≤255 unacknowledged frames, ACK batching 100
ms, ≤3 retransmissions). Termination: empty segment with termination flag (reliable sockets first complete pending ACKs); a received frame ID of 0
signals overflow and terminates the session.

## 6. Discovery, Probing and Path-Finding

### 6.1 Announcement and edges (RFC-0010)

Nodes announce on-chain (announcement contract binds off-chain packet key ↔ chain account ↔ transport multiaddress). A usable directed edge `u→v`
requires (a) an OPEN payment channel `u→v` and (b) transport connectivity — except the _final_ hop of a path, which needs no channel. The channel
graph is the canonical topology store.

### 6.2 Probing (RFC-0010)

Two modes: **immediate-neighbour** ping/pong (0-hop, nonce-based, carries one SURB) and **loopback path probes** (sender = receiver over `n`
intermediate hops, `1 ≤ n ≤ 3`, where the upper bound is RFC-0004's hop limit rather than a probing constant; `n` SHOULD vary across probes — the
reference prober rotates deterministically over the hop counts `{2, 3}`, randomising only which candidate path of a given length it probes; **carries
no SURB**, since the path already terminates at the originating node; payload indistinguishable from cover traffic). Probe results continuously score
edges. Beyond probes, completed **SURB round trips** on production traffic credit every edge across both legs, contributing a peak-relative,
trend-discounted delivery signal that combines with the probe rate by pessimistic minimum (RFC-0010 §4.2.5).

The loopback **path-telemetry payload** is 8-byte probe ID + 40-byte path identifier + 16-byte timestamp, in that wire order. The path identifier is
five 8-byte little-endian slots: slot 0 the originator, each subsequent non-zero slot the next relay in traversal order, the final non-zero slot the
loopback node; trailing unused slots are zero. Consequently `0` is **reserved and MUST NOT be used as a valid node identifier**, and receivers read
the path length as the run of consecutive non-zero slots from slot 0. Each slot identifier is the leading 8 bytes of the node's off-chain public key
(big-endian, value `0` remapped to `1` so a real node never collides with padding). The timestamp is milliseconds since the UNIX epoch as a big-endian
`u128` — note the mixed byte order against the little-endian slots, which §10 records as a known limitation. The originator MUST verify the probe
returned to itself before recording any observation from it.

**Next-hop telemetry (PPT, §4.3.1) MUST** be collected for each direct peer connection, providing at minimum latency, packet drop rate, and
acknowledgement rate — "the ratio of acknowledged messages to sent messages on the channel, including production traffic as well as probes". PPT
exists because loopback cannot cover this ground: §4.2.1.3 notes that making multi-hop probes indistinguishable from real traffic renders "direct
verification of immediate peer properties via loopback" infeasible, so PPT operates at 0-hop outside the multi-hop anonymity requirement.

**Probe scheduling (§4.2.1.4)**: implementations SHOULD order pending probes by a priority combining at least staleness and current edge score; the
stated requirement is "only that both staleness and current score participate". Note the direction — edges with _lower_ scores SHOULD be probed
**more** urgently, "to confirm whether the poor score reflects persistent degradation or a transient event".

**Exclusion (§4.2.3)**: implementations MUST realise at minimum a passive tier and MAY add active slashing. Passive exclusion MUST "weight path
selection by per-edge score so that edges with lower scores receive proportionally less traffic", which "ensures that unreliable edges are
progressively starved rather than suddenly eliminated, and that their score is continuously updated by the ongoing probe stream". Active slashing,
when implemented, SHOULD consider a failure threshold, a slashing duration and a recovery mechanism; slashing decisions MUST be made locally, without
coordination between nodes.

Two reader's notes, neither of them RFC text:

- Although the range starts at `n = 1`, a 1-hop loopback `me→X→me` lets the sole relay observe that its predecessor and successor are the same node,
  identifying both the loop and its originator. The reference prober therefore restricts loopback probing to `n ≥ 2`, making the effective probed
  range `2 ≤ n ≤ 3`.
- The scheduling direction and the passive-exclusion rationale together imply that probe generation must not be gated by the same score that starves
  data traffic: an edge pruned from candidate paths receives no probes, so its score can never be updated, which is precisely the outcome §4.2.3 rules
  out.

### 6.3 Path-finding (RFC-0014)

Per-stream link score = probe success rate × step-function latency score (≤75 ms → 1.0; ≤125 → 0.7; ≤200 → 0.3; >200 → 0.15; no data → 0.05), over an
EMA of latency (window `N = 3`) and of probe success rate (window `N = 5`). The intermediate stream's probe rate is the pessimistic minimum of the
loopback-probe rate and the SURB delivery rate (§6.2). The two streams combine **conditionally, not by unconditional averaging**: `(imm + inter) / 2`
only when **both are present**, otherwise whichever single stream is present; an edge with no observations at all yields no score (unusable). Path
value = product of edge costs; an intermediate edge is admitted only if its channel balance can fund the tickets the relay must still issue
(`balance ≥ remaining_hops × ticket_face_value × 2`), and a measured-dead edge is floored to `1e-9` rather than pruned so it keeps being probed.
Candidate generation enumerates simple paths of exactly `hops+1` edges (with a phase-2 fallback that appends a channel-less final hop), caps
`max_paths = 50`, prunes the pool for consistency and first-relayer diversity above an anonymity floor (default 8), validates against on-chain state
(open channels on every non-final edge, no duplicate nodes), then samples **weighted-random** by a composite weight
(`path_value × latency_factor × capacity_factor`); return paths are drawn independently with weight tempering (`0.5`) and an exploration fraction
(`0.1`). Cached 10 s TTL, background refresh 5 s. Constants: `edge_penalty = 0.5` for unprobed edges, `min_ack_rate = 0.1`.

Output `ResolvedTransportRouting = { forward ValidatedPath, return
ValidatedPaths (for SURBs), HoprPseudonym }`.

Two reader's notes on §4.2, neither of them RFC text:

- The RFC does not define "present". Read it as _has recorded observations_, not _allocated_. An implementation that counts a stream as present
  because some unrelated update brought it into existence — a capacity update, say — averages real measurements against a phantom zero, halving the
  score of every edge that only one stream can ever observe.
- §4.2 and §4.3 pull in opposite directions on unobserved edges: §4.2 says such an edge yields no score and MUST be treated as unusable, while §4.3
  assigns it "a cost of `edge_penalty` (default `0.5`) rather than `0`", which "allows unprobed edges to be selected". The reconciliation is that the
  absent score is distinct from the substituted _cost_ — and the implementation now keeps an unprobed edge apart from a measured-and-dead one, the
  latter floored to `MEASURED_DEAD_FLOOR = 1e-9` so it stays under observation rather than vanishing, removing the earlier source of inverted
  rankings.

## 7. PIX — Protocol for Incentivization of eXits (RFC-0012 draft v0.6.0)

Fills the "destination earns nothing" gap for Exit nodes serving Entry traffic. Entities: Entry `A` (client), Exit `B` (server), privacy pool `W`
(`Deposit / Allocate / Withdraw`; MUST hide depositor+allocator from withdrawer). `A` deposits ahead of time and is bound to `B` by a fixed return
pseudonym `P`; in HOPR this is an RFC-0009 Session with `UsePIX`, whose Session ID stands in for `P` and whose `SsaRequest`/`SsaCommit` messages
(§5.2) carry the exchange.

Parameters are **proposed by the Entry** in the `StartSession` PIX parameters word `suite (bits 31–30) | m (29–16) | t+1 (15–8) | surplus (7–0)`
(suite `0` BabyJubJub, `1` secp256k1). The Exit accepts them unchanged and echoes them in every `SsaRequest` (the Entry terminates on a mismatch), or
refuses the binding (`UnacceptablePixParams`).

Mechanism (per agreement `i`: a non-zero u32, strictly increasing, assigned by the Exit; `i = 0` marks "no share"):

1. `B` picks scalar `b_i` and sends `ExitCommitmentRequest_i` (`SsaRequest`) with `params`, `i` and `ExitCommitment_i = b_i·BP`.
2. `A` builds `m` random degree-`t` polynomials `T_i_u` and sends `EntryCommitment_i` (`SsaCommit` messages) with commitments `M_i_r_u = T_i_u_r·BP`:
   row `r = 0` (constant terms) first, every message repeating the same `PoK_i`, then rows `r ≥ 1` a block of polynomials at a time (full-matrix mode
   only).
3. `PoK_i` is a Schnorr proof of knowledge of `s = Σ_u T_i_u_0`, the discrete logarithm of `EntryCommitment_i = Σ_u M_i_0_u`: `R = r·BP`,
   `c = HS(P||i||EntryCommitment_i||R, "", "HASH_SSA_COMMITMENT_PROOF")`, `z = r + c·s` (fresh `r` per proof); `B` checks
   `z·BP = R + c·EntryCommitment_i`. It stops an Entry that saw `ExitCommitment_i` from choosing commitments so that it alone knows the SSA key.
4. Both compute the **session stealth address** `SSA_i = EntryCommitment_i + ExitCommitment_i`. `B` derives a deposit address only after `PoK_i`
   verifies; `A` runs `Allocate(ChunkPrice, Deposit_Handle, SSA_i)` only after sending the whole commitment; `B` gives up if the allocation does not
   appear in time.
5. `A` attaches one `EncryptedShare_i_u { i: u32, u: u16, E_y }` to each SURB, at least `t+1` plus `surplus` per polynomial:
   `x = HS(SenderKey, P||i||u, "HASH_SSA_POLY_SHARE_SCALAR")` (never 0), `y = T_i_u(x)`, `E_y = E(iv, k, y)` with
   `(iv, k) = KDF("HASH_SSA_POLY_SHARE", ack_secret, P||i||u)`, where `ack_secret` is the first return-path relayer's acknowledgement secret; `i` and
   `u` travel in the clear. `B` MUST use share-carrying SURBs when it holds them, oldest first.
6. When `B` _uses_ a SURB and the first return-path relayer acknowledges, `B` learns `ack_secret` and decrypts `y`. Per-share checks: `i` accepted,
   `u < m`, `x ≠ 0`, no repeated `x`; full-matrix mode adds the Feldman check `y·BP = Σ_r x^r·M_i_r_u`.
7. With `t+1` distinct shares of a polynomial, `B` interpolates `T_i_u_0` and checks `T_i_u_0·BP = M_i_0_u`; with all `m` recovered,
   `SSA_Priv_i = b_i + Σ_u T_i_u_0`, and `B` withdraws from `W`.

Commitment modes: **full-matrix** (Feldman, `m·(t+1)` commitments; each share verified on arrival, so a corrupt one is absorbed by the surplus) or
**constant-term** (row 0 only, `m` commitments; validity is known only after interpolation, and one corrupt share makes `SSA_i` unrecoverable).
Constant-term mode is RECOMMENDED where the Exit is the sole reconstructing party, and HOPR uses it.

Quota: `B` serves `m·(t+1+surplus)` packets per `SSA_i`, i.e. `Q = m·(t+1+surplus)·U` bytes with `U = 1452` B (Session MTU), and MUST refuse a binding
whose `Q` or dimensions it will not serve. `B` SHOULD start agreement `i+1` before `SSA_i` is complete (at most one ahead); at `i = 2^32−1` a new
pseudonym is required.

HOPR instantiation (Appendices 1–2): BabyJubJub (secp256k1 alternative, fixed at build time, not interoperable), BLAKE3-256, ChaCha20,
`KDF(c,k,s) = blake3_kdf(c, k || s)`, HS via RFC 9380 `expand_message_xmd` with BLAKE3 (DST = suite ID `BabyJubJub_XMD:BLAKE3_SSWU_RO_` || tag,
`L = 32`, reduced modulo the group order). Scalars and points 32 bytes (points 33 on secp256k1), `PoK` 64 bytes (65), `EncryptedShare` 38 bytes.
Defaults `m = 8192` (1–16192), `t+1 = 64` (2–255), `surplus = 16` (`⌈(t+1)/4⌉`): 655 360 packets ≈ 907.5 MiB per SSA and ≈ 262 KB of constant-term
commitments (≈ 16.8 MB in full-matrix mode). Implementation choices: the Session closes on the first failed interpolation (detected after `t+1`
packets, ≈ 0.0098 % of the quota); corrupt shares count as adversarial, since a garbled SURB loses its share rather than delivering a corrupt one that
decrypts; return path ≥ 1 hop; agreement `i+1` starts at 85 % of polynomials recovered; incomplete commitments are dropped after 2 min and
reconstruction state after 30 min without an acknowledged share.

Privacy pool (Appendix 3): `W` MAY be the Curvy protocol, a shielded-notes aggregator whose zero-knowledge proofs are efficient over BabyJubJub but
not over secp256k1. Deposits become opaque shielded notes; `A` allocates to notes owned by `SSA_i`, each SSA key valid for a single note; `B` proves
possession with `SSA_Priv_i` and collects one or several notes per transaction, keeping the funds shielded or withdrawing them to an EOA. The Exit's
key, sent in the `SsaRequest` deposit data, is ephemeral and need not be stored.

Properties: payment is conditional on **actual reply-path handover** (packet-layer proof, not end-to-end delivery); the pool hides who paid whom; the
Entry cannot retract an allocation, nor be made to accept a quota it did not propose. Forward and return paths SHOULD each have ≥1 relay; a 0-hop
return path discloses no `ack_secret`, so no share can be decrypted.

## 8. Economic Reward System (RFC-0007)

Off-protocol Cover-Traffic (CT) reward distribution run by the HOPR Association, separate from relay payments: peers (data from node API, subgraphs,
RPC and a static NFT list) are filtered by Safe allowance, open channel, not being a CT node and minimum stake (NFT holders get a lower threshold); an
economic model (e.g. sigmoid or legacy) converts stake, total stake, capacity and relay history into a yearly message count; CT nodes send those
messages through the HOPR network over one UDP session per eligible peer (towards a randomly chosen CT node), pacing batches by
`(seconds per year / yearly count) × aggregated_packets × batch_size`. Precedent for later work: staking-gated eligibility and stake-proportional
traffic allocation.
