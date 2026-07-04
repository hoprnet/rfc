# RFC-0015 Onion Services — Design Decisions Log

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

## Open questions for the next grilling round
- D2/D9 handshake and identity-key curve choice.
- Whether the service must run as a full HOPR node.
- Fee negotiation concreteness (per-session vs per-byte, when settled).
- SURB replenishment strategy specifics for high-inbound services.
