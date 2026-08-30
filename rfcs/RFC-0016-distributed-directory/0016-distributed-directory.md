# RFC-0016: HOPR Distributed Directory

- **RFC Number:** 0016
- **Title:** HOPR Distributed Directory
- **Status:** Raw
- **Author(s):** Tibor Csóka (@Teebor-Choka)
- **Created:** 2026-07-05
- **Updated:** 2026-07-05
- **Version:** v0.1.3 (Raw)
- **Supersedes:** none
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md),
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md),
  [RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md),
  [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md),
  [RFC-0014](../RFC-0014-path-finding/0014-path-finding.md),
  [RFC-0015](../RFC-0015-onion-services/0015-onion-services.md)

## 1. Abstract

This RFC specifies the **HOPR Distributed Directory**: a decentralised,
privacy-preserving key-value store over HOPR nodes, used to publish and retrieve
signed records without a central server and without revealing who publishes or
who queries. Its primary consumer is the onion-services scheme
([RFC-0015](../RFC-0015-onion-services/0015-onion-services.md)), which stores
**service descriptors** at blinded slots so that a service can be found by a
party that already knows its address, yet the directory cannot be enumerated.

The directory is defined as an abstract `STORE`/`LOAD` interface with strong
security requirements — anonymous access, crawl resistance, censorship and
eclipse resistance under an explicit honest-fraction assumption, monotonic
record replacement, and an anti-abuse admission hook — together with a concrete
instantiation as a Kademlia-style distributed hash table whose responsible-set
assignment is bound to on-chain node identity so it cannot be ground toward a
victim slot. This document lifts the directory requirements that
[RFC-0015](../RFC-0015-onion-services/0015-onion-services.md) states normatively
but delegates, and specifies them in one place.

## 2. Motivation

[RFC-0015](../RFC-0015-onion-services/0015-onion-services.md) needs a way for a
client to fetch a service's signed descriptor given only the service's
self-certifying address, with three properties an on-chain registry cannot
provide cheaply: (a) frequent, gas-free updates as descriptors rotate each
period; (b) no public enumeration of which services exist; and (c) no leak of
which client is interested in which service. A distributed directory over the
HOPR network, queried through anonymous sessions, provides all three.

The directory is factored into its own RFC because it is general infrastructure —
any HOPR subsystem needing decentralised, anonymous, authenticated publication
can reuse it — and because its distributed-systems security (eclipse, censorship,
replay, monotonicity, admission control) is substantial enough to specify
independently of any one consumer.

## 3. Terminology

The keywords "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be
interpreted as described in [01] when, and only when, they appear in all
capitals, as shown here.

General mixnet and HOPR terminology is defined in
[RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md); SURBs and
pseudonyms in
[RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md). This
document additionally defines:

- **Directory node**: a HOPR node that stores directory records for the slots it
  is responsible for and answers `STORE`/`LOAD` requests.
- **Slot**: the key under which a record is stored, a fixed-size byte string
  derived from the publisher's identity and the current time period.
- **Record**: an opaque, self-signed, size-bounded value stored at a slot,
  carrying its own `sequence`, `published_at`, and `ttl`.
- **Responsible set**: the set of `k` directory nodes assigned to a slot for a
  given period.
- **Period**: the epoch (`PERIOD_LENGTH`, default 86400 s) over which slot
  derivation and responsible-set assignment are fixed.
- **Publisher / resolver**: the party that stores / reads a record.
- `||` denotes concatenation; `|x|` the size of `x` in bytes; integers are
  big-endian. `H`, signatures, and the curve follow Appendix 1.

## 4. Specification

### 4.1 Model

The directory is an abstract map from `slot` to a single current `record`:

- `STORE(slot, record)` — publish or replace the record at `slot`.
- `LOAD(slot) -> record?` — return the current record at `slot`, or nothing.

Records are **opaque** to the directory except for a small envelope the directory
must read to enforce authenticity, monotonicity, and expiry:

```text
RecordEnvelope {
  slot         : [u8; 32],   // MUST equal the request slot
  auth_pubkey  : [u8; 32],   // key that signs this record (the blinded descriptor key)
  sequence     : u64,        // monotonic per slot; higher supersedes; MSB = tombstone
  published_at : u64,        // UNIX seconds
  ttl          : u32,        // seconds of validity from published_at
  payload      : [u8; n],    // consumer-defined body (e.g. RFC-0015 descriptor)
  signature    : [u8; 64]    // by auth_pubkey over all preceding fields
}
```

The directory verifies `signature` under `auth_pubkey`, and that `auth_pubkey`
is the legitimate authority for `slot` (Section 4.3). It does **not** interpret
`payload`. The sole record profile is the **blinded profile** (service
descriptors,
[RFC-0015](../RFC-0015-onion-services/0015-onion-services.md) §4.3): `slot` is
derived from a *blinded* identity key so the directory cannot link a record to a
long-term identity or enumerate services. (Onion-service bridges are deliberately
**not** in the directory — they are discovered by direct capability negotiation
and vouched for in service descriptors,
[RFC-0015](../RFC-0015-onion-services/0015-onion-services.md) §4.4, so no
unblinded/enumerable index exists.) A future consumer needing an unblinded,
"want-to-be-found" record could add an open profile keyed by an unblinded key;
none is defined here, and the rest of this RFC assumes blinded descriptors.

### 4.2 Anonymous access

Both `STORE` and `LOAD` MUST be performed over **anonymous HOPR sessions** — a
forward path to a directory node with SURBs for the reply
([RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md),
[RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md)) — so a
directory node learns neither the publisher's nor the resolver's network
location.

`STORE` and `LOAD` MUST be **indistinguishable on the wire**: a single request
shape carries an optional record body, and a write is authorised by the record's
own signature rather than a distinct opcode, so a directory node cannot classify
a request as publish-vs-fetch by its shape. This indistinguishability is
**shape-only**: a node that inspects a present, validly-signed, higher-`sequence`
body can still infer that request is a write. It therefore hides *who* and, for
blinded slots, *which identity* — not the bare fact that some slot received a
fresh record. Consumers needing to hide publication cadence MUST rely on
publication jitter (Section 4.5), not on this property.

### 4.3 Slot derivation and responsible-set assignment

**Slot (blinded profile).** The blinding is the Tor v3 rendezvous construction
[03] over Ed25519 [04] [05]. Let `B` be the Ed25519 base point, `L` the
prime-order subgroup order, and let an identity be the keypair `(a, A)` with
`A = a·B` (`A` is `pk`). For the current `period`:

```text
// 0. pk MUST first pass a full subgroup check (reject non-prime-order / mixed-order
//    points: verify L·pk == identity), since pk_blind is computed from a supplied pk.
// 1. Derive and clamp the per-period blinding scalar h:
t = H("hopr-blind" || pk || period)          // 32-byte hash
h = t clamped as a valid Ed25519 scalar:
      h[0]  &= 248        // clear low 3 bits (cofactor)
      h[31] &= 63
      h[31] |= 64         // set bit 254
      // h is used as an integer scalar; it is NOT separately reduced mod L before
      // the point multiplication, so the low-3-bits-clear (cofactor) property is preserved.
// 2. Blinded PUBLIC key (anyone knowing pk can compute it):
pk_blind = h · A          // Ed25519 POINT scalar-multiplication (NOT scalar addition),
                          //   re-encoded canonically (canonical sign bit)
slot        = H(pk_blind || period)
auth_pubkey = pk_blind    // records are signed by, and verified under, pk_blind
// 3. Blinded PRIVATE key (only the identity holder, for signing):
a_blind      = (h · a) mod L                 // reduced mod L here (scalars live mod L);
                                             //   a_blind · B = h·A = pk_blind holds
prefix_blind = H("hopr-blind-prefix" || prefix)   // fresh RH half of the expanded key
```

Signatures made with the blinded expanded key `(a_blind, prefix_blind)` verify
under `pk_blind` with **standard, unmodified** Ed25519 verification [05]. Only a
party that knows `pk` can compute `h` (hence `slot`), so the directory verifies
records under `pk_blind` without learning `pk`. Implementations MUST use point
scalar-multiplication for `pk_blind` (a common error is scalar *addition*, which
does not preserve the discrete-log relation and yields unverifiable signatures);
MUST clamp `h` but MUST NOT separately reduce it mod `L` before the point
multiplication (clamping and a subsequent mod-`L` reduction are contradictory —
the reduction destroys the cofactor-clearing the clamp is for, and two
implementations disagreeing on this would derive different slots); MUST validate
the supplied `pk` with a full subgroup check (step 0); and MUST canonicalise the
`pk_blind` encoding. Otherwise blinded signatures fail to verify, a mixed-order
`pk` yields cofactor ambiguity, or slots become linkable across periods.

**Responsible set — MUST be ungrindable toward a target slot.** Because `slot` is
a public function of a known key, naive "closest node IDs" assignment lets an
adversary grind Sybil node IDs to surround a victim slot and eclipse it. The
responsible set of `k` nodes for a slot in a period therefore MUST be assigned by
a method an adversary cannot cheaply steer toward a chosen slot:

- node IDs used for responsibility MUST be bound to an on-chain node identity
  (the `chain_account`/`packet_pubkey` key-binding of
  [RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md)),
  so minting adjacency requires as many announced identities as the attack needs,
  not free offline grinding; and
- assignment MUST incorporate a per-period, publicly-verifiable random beacon
  (e.g. a VRF over `period`) so the responsible set for a given slot cannot be
  predicted far enough ahead to pre-position Sybils.

The responsible set rotates each `period`. `k` (replication factor) is a network
parameter with `k >= K_MIN` (default `K_MIN = 8`).

### 4.4 Storage, monotonicity and anti-entropy

Record-format `sequence` monotonicity is **not** self-enforcing (a validly-signed
old record can be replayed), so directory nodes MUST enforce it:

- A directory node MUST retain the highest-`sequence` record it has accepted per
  slot for at least its `ttl`, and MUST reject a `STORE` whose `sequence` is not
  strictly greater than the retained value (a tombstone, `sequence` MSB set,
  supersedes lower sequences and empties the payload).
- Responsible nodes MUST run **anti-entropy** (periodic gossip / read-repair
  across the responsible set) so a fresh write — including a tombstone —
  propagates to the whole set before a lagging or forgetful replica can serve a
  superseded record.
- A node MUST reject a record whose `slot` does not match the derivation for its
  `auth_pubkey` and `period`, whose signature fails, or whose `published_at` is
  further in the future than a small skew tolerance (`CLOCK_SKEW`, default 60 s).

### 4.5 Retention, expiry and freshness

- A record is valid until `published_at + ttl`; nodes MAY evict expired records.
- Publishers MUST refresh before expiry (a heartbeat). Publishers MUST jitter
  publication time within the period and MUST NOT derive `published_at` from a
  high-resolution wall clock, so refresh cadence does not fingerprint the
  publisher.
- `ttl` is bounded to `[TTL_MIN, TTL_MAX]` (defaults 60 s, 86400 s) to bound both
  staleness and storage load.

### 4.6 Consumer read rules

A resolver MUST:

1. query at least `q` distinct responsible nodes, where `q` exceeds the assumed
   dishonest fraction of the responsible set (Section 6) — not a bare two;
2. accept the highest-`sequence`, signature-valid, unexpired record returned,
   treating a tombstone as "absent";
3. reject records failing the freshness rules of Section 4.4, and for
   security-sensitive use require a meaningful remaining-TTL margin (not merely
   "not yet expired");
4. spread queries across the responsible set over time to bound the per-slot
   demand time-series any single node observes.

### 4.7 Anti-abuse admission

Because `LOAD` is anonymous, an adversary who knows a service's address (and can
thus compute its slot) could flood that slot. The directory MUST expose an
admission hook applied before a node commits work to a request:

- a lightweight **proof-of-work** bound to `(slot, coarse-time)`, or
- a **fetch micro-payment** (a HOPR ticket or PIX-style allocation).

The hook MUST be cheap for honest use and MUST NOT deanonymise the requester (the
PoW/payment MUST NOT carry requester identity). Since only blinded descriptor
slots exist, flooding is targeted-only — an adversary must already know the
address — which bounds the exposure.

## 5. Design Considerations

**Why not on-chain.** Descriptors rotate every period and would cost gas and
propagate slowly on-chain; on-chain reads can also leak interest. A directory
gives gas-free, frequent, anonymous publication, at the cost of the distributed-
systems hardening specified here.

**Why blinding.** Self-certifying addresses make records verifiable by anyone who
holds the address, but the directory must not become a global index of services.
Per-period key blinding lets a knowing party compute the slot and verify the
record while denying enumeration to everyone else.

**Why identity-bound, beacon-driven responsibility.** The entire censorship/
eclipse resistance rests on an adversary being unable to cheaply place many nodes
adjacent to a victim slot. Binding responsibility to announced on-chain identity
and to an unpredictable per-period beacon is what makes that expensive.

**Why the anti-abuse hook is generic.** Whether PoW or payment fits depends on
the deployment and the consumer; the directory fixes the requirement (cheap,
non-deanonymising, mandatory for enumerable slots) and leaves the choice open.

## 6. Security Considerations

**Crawl resistance vs confirmation.** Blinded slots cannot be enumerated: an
adversary needs `pk` to compute a slot. This does **not** hide a service from an
adversary who already guesses `pk` and can then compute the slot and observe
activity — a confirmation channel, not an enumeration one. Consumers store only
what they are willing to expose to a party that already knows their address.

**Eclipse and censorship — conditional.** With responsible-set assignment bound
to on-chain identity and a per-period beacon (Section 4.3), and a resolver quorum
`q` exceeding the assumed dishonest fraction `f` of a set of size `k`, the
probability that all `q` queried nodes are adversarial is bounded and made
explicit by the deployment's `(k, q, f)` choice. Absent those properties, taking
the highest `sequence` across nodes defeats only a *single* dishonest node, not a
controlled responsible set; deployments MUST state their `(k, q, f)` assumption
rather than assume "no single node can censor."

**Replay / rollback.** Enforced by replica-side monotonicity plus anti-entropy
(Section 4.4); a resolver additionally takes the highest `sequence` across `q`
nodes.

**Interest and cadence leakage.** Anonymous sessions hide who queries; query
spreading bounds the per-node demand series; publication jitter hides refresh
cadence. Because all slots are blinded, a responsible node cannot link the slots
it serves to service identities, and there is no enumerable index to crawl.

**Storage exhaustion.** Bounded record size, bounded `ttl`, `k`-replication, and
the admission hook (Section 4.7) together bound the storage a slot can consume;
nodes MAY additionally rate-limit per responsible slot.

## 7. Compatibility

The directory is new infrastructure and additive. It depends on anonymous HOPR
sessions
([RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md),
[RFC-0008](../RFC-0008-session-protocol/0008-session-protocol.md)) and on the
on-chain node identity/key-binding assumed by
[RFC-0010](../RFC-0010-automatic-path-discovery/0010-automatic-path-discovery.md)
for responsible-set assignment. It is the concrete realisation of the directory
interface that
[RFC-0015](../RFC-0015-onion-services/0015-onion-services.md) §4.3.3 requires.
The per-period random beacon is an external dependency where the network does not
already provide one.

## 8. Drawbacks

- New subsystem with non-trivial distributed-systems security to implement and
  analyse (eclipse, anti-entropy, admission).
- Eclipse resistance is only as strong as the `(k, q, f)` assumption and the
  identity-bound, beacon-driven assignment; a network with cheap identities
  weakens it.
- Anonymous access adds latency (multi-hop publish/fetch with SURBs) over a
  direct lookup.

## 9. Alternatives

- **On-chain registry** — maximal availability and Sybil resistance but gas
  cost, slow updates, permanent public listing, and read-time interest leakage;
  rejected for the descriptor use case.
- **Centralised directory servers** (Tor HSDir-like but fixed) — simpler, but a
  central trust and censorship point contrary to HOPR's model.
- **Gossip-only flooding** — no slot structure, but unbounded load and weak
  targeted-retrieval guarantees.

## 10. Unresolved Questions

- A formal security proof of the blinding construction (the construction itself
  is now pinned in Section 4.3; only its formal unlinkability proof is open).
- Source of the per-period random beacon on the target chain/network.
- Concrete `(k, q, f)` defaults and the admission-hook choice (PoW vs payment)
  per deployment.
- Storage-incentive model: whether directory nodes are paid (and how) or store as
  a network duty, and its abuse implications.
- Whether any future consumer needs an unblinded open profile (none does today;
  onion-service bridges are discovered off-directory,
  [RFC-0015](../RFC-0015-onion-services/0015-onion-services.md) §4.4).

## 11. Future Work

- Storage-incentive / accounting mechanism for directory nodes.
- Erasure-coded or larger record payloads for future consumers.
- Formal analysis of eclipse probability under the identity-bound beacon
  assignment.

## 12. References

[01] Bradner, S. (1997). [Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119). _IETF RFC 2119_.

[02] Maymounkov, P., & Mazières, D. (2002). [Kademlia: A Peer-to-peer Information System Based on the XOR Metric](https://pdos.csail.mit.edu/~petar/papers/maymounkov-kademlia-lncs.pdf). _IPTPS 2002_, 53-65.

[03] Dingledine, R., Mathewson, N., & Syverson, P. (2004). [Tor: The Second-Generation Onion Router](https://svn.torproject.org/svn/projects/design-paper/tor-design.pdf). _13th USENIX Security Symposium_.

[04] Bernstein, D. J., Duif, N., Lange, T., Schwabe, P., & Yang, B.-Y. (2012). [High-speed high-security signatures](https://ed25519.cr.yp.to/ed25519-20110926.pdf). _Journal of Cryptographic Engineering, 2_(2), 77-89.

[05] Josefsson, S., & Liusvaara, I. (2017). [Edwards-Curve Digital Signature Algorithm (EdDSA)](https://www.rfc-editor.org/rfc/rfc8032.html). _IETF RFC 8032_.

## 13. Appendix 1: Cryptographic Instantiation

- Hash `H`: **BLAKE3-256**, consistent with
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md).
- Record and blinded-slot signatures: **Ed25519** [04], canonical encoding,
  small-order points rejected; key blinding per Section 4.3 with `h` clamped
  (not separately reduced modulo `L`) before point multiplication, and
  `a_blind` reduced modulo `L`.
- Distributed hash table: **Kademlia**-style XOR metric [02] for routing, with
  responsible-set membership additionally gated by on-chain identity and a
  per-period beacon (Section 4.3).
