# RFC-0015 Onion Services — Design Decisions Log

> **Round 1 audit refinements (v0.2.0):** Four adversarial reviews (see
> `audit-log.md`) changed three decisions materially: (a) the bridge fee is
> **service-conditional** (PIX stream unlocked per delivered frame + small
> non-refundable reservation), not flat-prepaid — D12 superseded; (b) bridge
> eligibility is a **slashable bond with cooldown**, not a recoverable stake —
> D8 refined; (c) **constant-rate per-leg traffic shaping is mandatory** and the
> rendezvous is a **generic session-join** the RB is blind to — new, hardening
> D1/D13. Crypto/consistency fixes (transcript binding, `intro_enc_key`
> ownership, delegation fields, per-period `S_s` rotation, citation numbering,
> PIX/RFC-0004 draft-dependency honesty) are in the RFC and audit-log.

Running record of decisions agreed with the RFC owner, so the draft (and any
resumed session) can proceed without re-litigating. Updated as alignment
progresses.

## Locked decisions

### D1 — Architecture: two-phase introduction + rendezvous
Tor-v3-style split. The service keeps cheap standing **control** sessions to a
set of announced **introduction bridges**. For each connection the client picks
a fresh **rendezvous bridge**, claims a cookie there, and asks the service (via
an intro bridge) to meet it at the rendezvous. Data flows only through the
client-chosen rendezvous bridge, which splices the two HOPR legs. Announced
infrastructure never carries bulk traffic; per-connection rendezvous is
unlinkable across connections.

### D2 — End-to-end encryption across the splice (implied requirement)
Each HOPR leg is only encrypted to that leg's endpoints, so the rendezvous
bridge would see plaintext unless client and service share an end-to-end key.
Therefore an **e2e handshake keyed to the service's identity key** is mandatory:
the client sends its half of the handshake inside the (service-key-encrypted)
introduction; the bridge only ever splices ciphertext. Default construction: a
Noise-style DH handshake (see D9).

### D3 — Naming: self-certifying `.hopr` + optional ENS alias (combine "1 and 3")
- **Root of trust**: self-certifying address `base32(pubkey || checksum ||
  version).hopr`, Tor-v3 analogue. Always usable, no registry, no trust.
- **Human-readable layer**: reuse **ENS** (e.g. a text record under a name or
  subdomain) mapping a friendly name → the self-certifying `.hopr` address.
  No bespoke registry contract. ENS resolution is optional and, when used,
  MUST be verified against the self-certifying address (the address is
  authoritative; ENS is only a convenience lookup).

### D4 — Descriptor distribution: DHT over HOPR nodes, fetched via mixnet
HSDir-style: descriptor stored at nodes derived from `H(blinded_pubkey ||
period)`. Publish and fetch happen over anonymous HOPR sessions so directory
nodes learn neither the service's location nor which clients are interested.
Blinded keying rotates responsibility per time period.

### D5 — DHT scope: interface here, mechanics in a companion RFC
RFC-0015 normatively defines descriptor format, blinded keying, signature
scheme, publish/fetch semantics, and the security properties any directory
layer MUST provide. A companion RFC (proposed **RFC-0016, HOPR Distributed
Directory**) specifies the DHT (replication, retention, storage incentives).
An appendix MAY sketch a Kademlia-over-HOPR design non-normatively.

### D6 — DoS defence: payment-gated introduction + descriptor-level access control
- **Public services**: introduction requests carry a small verifiable payment
  (PIX-style stealth allocation / ticket) that the intro bridge and/or service
  verify before doing work. Spam becomes revenue; anonymity preserved via the
  privacy pool.
- **Private services**: descriptor (or the capability to decrypt intro points)
  is only shared with authorised clients — Tor "client authorization" analogue.
Both mechanisms specified; a deployment MAY use either or both.

### D7 — Traffic profile: interactive + long-lived streams + bulk
Optimise defaults for interactive request/response (HTTP-like) but the spec
MUST support long-lived bidirectional streams (keep-alive, SURB replenishment,
bridge-churn migration) and bulk transfer (parallel rendezvous circuits, SURB
batching, flow control). Reliable session mode is the default end-to-end.

### D8 — Bridge announcement & eligibility
- **Announcement**: extend the existing on-chain node announcement with a
  **bridge-capability flag + signed fee/capacity schedule** (or an on-chain
  pointer to a fresher off-chain record). Services and clients filter the
  channel graph they already maintain (RFC-0010/0014). No new discovery
  infrastructure.
- **Eligibility**: announcing the bridge role REQUIRES a **minimum stake**
  (RFC-0007-style threshold). This raises the Sybil cost for the role sitting
  closest to both anonymity legs, where an adversary running many bridges would
  most improve correlation odds. Full bonding/slashing deferred to future work.

### D9 — Incentives
- Each side pays its **own HOPR leg** via standard PoR tickets (client pays
  client→rendezvous; service pays service→rendezvous, incl. SURB-funded return
  traffic).
- The **bridge splice/availability role** earns a **negotiated fee**, settled
  PIX-style (stealth address + privacy pool) so the payer is unlinkable. Fee
  terms come from the bridge's announced schedule (D8) and are agreed during
  session/rendezvous setup.
- Future extensions (documented, not required for v1): service-subsidised
  clients (service pre-funds the bridge for toll-free access), and
  client-pays-all.

### D10 — Service identity & e2e crypto
- **Identity key**: Ed25519 (`id_S`). It signs descriptors and *is* the
  self-certifying name (D3). Multi-host serving (D3, point 5) via an
  `id_S`-signed **delegation certificate** authorising a per-host key for a
  validity window.
- **E2e session key**: Noise-IK-style handshake over **X25519**. The service
  publishes a static X25519 key `S_s` in its (Ed25519-signed) descriptor. The
  client sends ephemeral `E_c` in the introduction; the service replies with
  ephemeral `E_s`. Key `k = KDF(DH(E_c, S_s) || DH(E_c, E_s))` — forward
  secrecy from the ephemeral-ephemeral term, service authentication from
  `E_c·S_s`. Reuses HOPR's Curve25519 primitives.
- **Settlement** stays on **secp256k1** (unchanged PoR/PIX).

### D11 — Service host model
Node-based model is **normative**: the service runs on/behind a HOPR node with
funded channels (keeps standing intro sessions, pays its own leg via PoR
tickets). A **paid-gateway** model (non-node service renting a HOPR node) is
documented as an optional deployment pattern / future work.

### D12 — Bridge fee model
**Per-session flat fee, prepaid at rendezvous**, allocated PIX-style before the
bridge begins splicing. Long/bulk sessions top up via keep-alive-triggered
allocations. Fee terms taken from the bridge's on-chain announced schedule
(D8). Default: client pays the rendezvous-bridge fee; the service pays its
intro bridges (ongoing, PIX per period) for the standing control sessions.

### D13 — Bridge is a stateful two-session splice (SURB management)
The rendezvous bridge is **not** a dumb ciphertext relay. It terminates two
HOPR sessions — one to the client, one to the service — bound by the rendezvous
cookie, and relays the (end-to-end-encrypted, opaque) payload between them.
Crucially, it **independently manages SURB budgets and starvation on each leg**
using the existing HOPR flow-control signals (SURB distress `0x01`, out-of-SURBs
`0x03`). This yields a clean two-layer model: outer per-leg HOPR sessions
(bridge-terminated, normal SURB flow) carrying an inner end-to-end session
(client↔service, reliable by default) whose payload the bridge cannot read.
