# RFC-0015 Audit Log — Round 1 (v0.1.0 → v0.2.0)

Four independent adversarial reviewers (anonymity/traffic-analysis, cryptography,
economics/DoS, cross-RFC consistency) reviewed v0.1.0. Findings and their
resolution in v0.2.0 below. Severity as assigned by the reviewer.

## Anonymity / traffic-analysis

| ID | Sev | Finding | Resolution in v0.2.0 |
| -- | --- | ------- | -------------------- |
| C1 | Critical | Standing intro session = long-lived fixed-pseudonym liveness fingerprint; service-chosen keepalive cadence is a selector | §4.5.1: network-wide jittered keepalive, `PSEUDONYM_ROTATION`, padding so INTRODUCE2 ≈ keepalive. §7 documents residual. |
| C2 | Critical | RB is a stronger correlation vantage than a Tor RP and knows it serves an onion service; mitigations were prose-only | §4.5 frames rendezvous as generic **session-join** (RB not told purpose); §4.9 makes **constant-rate per-leg shaping mandatory**; §7 rewritten. |
| H2 | High | Cross-connection clustering of service-side legs via many adversary RBs | §7 intersection paragraph; shaping makes legs uniform; guard-set recommendation. |
| H3 | High | Directory learns fetch/publish rate; PUBLISH vs FETCH distinguishable; revision cadence leaks | §4.3.3 indistinguishable STORE/LOAD, replica query spreading; §4.3.1 publish jitter, no wall-clock `published_at`. |
| H4 | High | Bridge-side intro-payment verifier links payment↔service | §4.8.1 service is RECOMMENDED verifier; one-time unlinkable artifact when bridge verifies. |
| H5 | High | Static `handshake_static` defeats per-period blinding linkability | §4.3.1 `S_s` now rotates per period, derived from `sk_S||period`. |
| M6–M9, L10–L12 | Med/Low | Channel-graph funding fingerprint; register→join timing; IB-set/count fingerprint; timestamp skew; error-code leakage; abstract overclaim | §7 funding/guard tension; §4.5.4 uniform `JOIN_UNAVAILABLE`; `INTRO_SLOTS` fixed padded array; abstract softened to match §7. |

## Cryptography

| ID | Sev | Finding | Resolution |
| -- | --- | ------- | ---------- |
| C1 | (self-retracted) | Claimed no forward secrecy — reviewer re-derived that FS holds if ephemeral privates destroyed | §4.6 FS claim made precise (holds under ephemeral destruction). |
| C2 | Critical | Ownership of `IntroPoint.auth_key` private half ambiguous; IB-held reading breaks blob confidentiality | Renamed `intro_enc_key`, §4.3.1 states private half is **service-only**; ESTABLISH_INTRO proves possession. |
| C3 | Critical | `transcript_hash` undefined → whole handshake binding unspecified | §4.6 defines it: binds `pk_S`, `S_s`, both ephemerals as-transmitted, `RC`, `revision`. |
| H1 | High | Weak identity↔`S_s` binding at agreement | §4.6 `pk_S` in transcript; confirm_tag proves responder's `S_s` tied to dialed address. |
| H2 | High | `E_c` reused across intro-blob and e2e DH without domain separation | §4.5.3 separate `E_c^intro` vs `E_c`; distinct KDF labels; AEAD AD binds target IB. |
| H3 | High | Replay scope/window undefined; cross-IB replay | §4.5.3 service-global nonce cache, `±INTRO_WINDOW`, IB bound in AEAD AD. |
| H4 | High | Delegation cert missing service binding/serial/deny-unknown-caps | §4.2.3 adds `service_pubkey`, `serial`, deny-by-default caps, `MAX_DELEGATION`. |
| H5 | High | Rollback via stale-but-unexpired descriptor at first contact | §4.3.1 `published_at`; §4.3.3 ≥2-replica max-revision fetch, period consistency. |
| M1–M5, L1–L5 | Med/Low | Cookie-join binding; checksum strength; blinding pitfalls; X25519/Ed25519 validation; confirm-tag substitution; nonce discipline; version downgrade | §4.5.2/4.5.4 `join_commitment=H(RC||S_s)`; §4.2.1 checksum caveat + version floor; §4.3.2 blinding pinned to companion RFC; §7 + App.1 curve validation per RFC 7748; App.1 AEAD nonce discipline. |

## Economics / DoS

| ID | Sev | Finding | Resolution |
| -- | --- | ------- | ---------- |
| C1 | Critical | Flat prepaid fee = fee-theft primitive, no atomicity with service | §4.7 restructured: small non-refundable reservation + **service-conditional PIX stream** unlocked per delivered frame. |
| C2 | Critical | "PIX pattern" misapplied — PIX is streaming/threshold, not one-shot transfer | §4.7 RB modelled as a genuine **PIX exit**: client=entry, shares on return SURBs unlocked by ack_secret; §5 rationale. |
| C3 | Critical | Intro retainer unspecified; pays for unverifiable availability | §4.7 **per-INTRODUCE2 micro-payment** (receipt = proof of forwarding); retainer may supplement but MUST NOT dominate. |
| H1 | High | Introduction amplification / black-hole RB | §4.5.2 RB-signed reservation token; §4.5.3 service verifies token + `join_commitment` before opening leg; intro payment sized to leg cost. |
| H2 | High | `MIN_BRIDGE_STAKE` without slashing doesn't deter correlation adversary; selection rewards fee/capacity baiting | §4.4.2 **slashable bond + cooldown**; §4.4.3 bond-weighted, fee/capacity-capped selection. |
| H3 | High | Reservation griefing + service-non-performance leaves client unpaid-for | §4.5.2 per-epoch reservation cap, non-refundable reservation only; bulk conditional on delivery so client isn't out bulk fee if service no-shows. |
| H4 | High | Payment gating insufficient vs funded attacker; free-tier hole | §4.8 separates pricing from provisioning; per-IB rate limit; IB rotation/scaling; PoW enforced under load. |
| M1–M5, L1–L3 | Med/Low | Whitewashing; lazy-bridge market; fee bait-and-switch; SURB-starvation grief; fetch-DoS; double-spend intro payment | Bond cooldown (whitewashing); conditional pay (market); `schedule_ver` binding; `STARVE_GRACE` + non-replenisher bears teardown; directory anti-abuse hook; intro payment bound to IB+nonce. |

## Cross-RFC consistency

| Sev | Finding | Resolution |
| --- | ------- | ---------- |
| Critical | RFC-0012/0013 not in repo (unmerged branches); dangling links | §1/§6 mark PIX explicitly as **draft dependency on an unmerged branch**; link kept (user wants the PIX dependency; CI structure-check does not verify link targets). |
| Critical | RFC-0004 has no v1.1.0 / no `recipient_data` in finalised spec | §6 reworded: extension is *proposed alongside PIX*, would bump 0004 to a new minor; not cited as final. |
| Critical | Systematic `[03]/[04]/[05]` misuse (HOPR concepts with external-paper numbers) | All internal concepts now use `[RFC-000X](...)` links; `[XX]` reserved for external papers, renumbered to match References (Sphinx [03], Loopix [04], SEC2 [05], Tor [06]). |
| High | RFC-0010 is not an extensible announcement-contract spec | §4.4.1 states no RFC specifies the record; `BridgeAnnouncement` is a **new** schema; RFC-0010 cited only for "announcement exists / used for discovery". |
| High | Session-Start `0x04/0x05` dependency claim wrong/unused | §6 states OSCP does **not** use PIX Session-Start discriminants; only pool ops + SURB shares are the real dependency. |
| Med/Low | App-tag registry caveat; reliable-mode is local policy not 0008 default; RFC-0007 missing from Related Links; RFC-0016 "proposed"; SURB/pseudonym terminology belongs to 0004 not 0002 | §6 registry caveat; §4.6 "this RFC mandates"; RFC-0007 added to Related Links; RFC-0016 marked "not yet allocated"; §3 retargets SURB/pseudonym/ReplyOpener to RFC-0004. |

# Round 2 (v0.2.0 → v0.3.0)

Two focused verification agents: (a) rigorous check of the rewritten PIX-stream
economics, (b) convergence/completeness critic looking for revision-introduced
contradictions.

## Economics verification — verdict: SOUND-BUT-UNDERSPECIFIED, now resolved

| Finding | Resolution in v0.3.0 |
| ------- | -------------------- |
| Mapping confirmed: RB genuinely IS the PIX exit on leg A (terminates leg A, holds the client's SURBs, creates reply packets). Unlock-on-handover is a real property. | Confirmed; §4.5.5/§4.7 now state it precisely. |
| **Contradiction**: kept PIX's back half (share unlock) but §6 disclaimed its front half (commitment handshake) it mathematically depends on — unbuildable. | Added **§4.5.5 Rendezvous payment agreement**: full PIX commitment handshake on leg A via new OSCP messages `PIX_COMMIT_REQUEST` (0x0b) / `PIX_COMMIT` (0x0c). §6 corrected: OSCP carries the PIX agreement under its own discriminants; the crypto is PIX's. |
| Padding-vs-share rule unspecified (mandatory shaping means most leg-A packets are padding). | §4.5.5/§4.7/§4.9: every leg-A SURB (data or padding) carries a share; billing basis is **capacity held**, bounded by `schedule_ver`. |
| Asymmetric (upload-heavy) traffic underpays the RB. | Fixed by capacity/time billing above — payment tracks shaped-rate × duration, independent of service→client payload volume. |
| Share-supply vs SURB-supply coupling. | §4.5.5/§4.9: replenished SURBs carry fresh shares minted by sampling the same polynomials at new `x`; SURB without valid share not counted. |

## Completeness / convergence critic

| ID | Sev | Finding | Resolution |
| -- | --- | ------- | ---------- |
| 5.2 | Blocking | Delegation capability bit 2 ("terminate e2e session") unusable — delegate can't compute `S_s` (derived from `sk_S`) | §4.2.3: service MUST provision the delegate the per-period `S_s` private half (never `sk_S`), re-provisioned each period. |
| 2.2 | Should-fix | Mermaid `RENDEZVOUS1 (…, token, sig)` fields don't exist in struct | Diagram corrected to `RENDEZVOUS1 (RC, E_s, join_proof, confirm_tag)` / `RENDEZVOUS2 (E_s, confirm_tag)`. |
| 3.1 | Should-fix | Commitment written `H(RC \|\| S_s)` in §4.5.4 prose and §7 vs canonical `H("hopr-join" \|\| RC \|\| S_s)` | Both aligned to the domain-separated form. |
| 7.1 | Should-fix | Client can't distinguish real intro points from random padding | §4.3.1 `IntroSection`: public = plain list (IBs not secret); private = encrypted-then-padded (only authorised clients decrypt). |
| 7.3 | Should-fix | Intro micro-payment not wired to a field identifying the forwarding IB | §4.5.3: `INTRODUCE2` body defined; service attributes payment via the standing session and MUST match the AEAD-bound `node_id`. |
| 7.4 | Should-fix | Undefined behaviour on descriptor/`S_s` expiry mid-session | §4.6: e2e keys fixed at handshake; live joins continue across period rollover; only new connections use the new period. |
| 7.2 | Should-fix | `INTRODUCE_ACK` semantics (receipt vs forwarding) | §4.5.3: it confirms best-effort receipt, not forwarding. |
| 2.1 | Should-fix | Trivial messages had no body | §4.5 table note defines the stub bodies (ACKs, `JOIN_UNAVAILABLE` reason byte). |
| 4.1, 7.5, 7.6, 7.7 | Nit | `S_s` antecedent; `expiry` u32-rel vs `valid_until` u64-abs; `n`→`INTRO_SLOTS`; `capabilities` name collision | §4.5.2 states `S_s` from descriptor + expiry translation; `IntroSection` removes bare `n`; `Descriptor.capabilities`→`session_caps`. |
| — | Verified clean | `MIN_BRIDGE_STAKE` fully renamed; all constants introduced+used; refs [01]–[12] all cited+defined; token/commitment field chain consistent; stage ordering (descriptor before rendezvous) correct | No change needed. |

## Not yet fully closed (tracked in §10 Unresolved / §11 Future Work)
- Exact Ed25519 blinding construction (deferred to companion directory RFC).
- Concrete slashing challenge/proof formats.
- Guard mechanism vs per-connection freshness tension (documented, not resolved).
- Concrete PoW puzzle for free-tier.
- Whether PIX's streaming construction cleanly covers the RB-as-exit mapping needs
  confirmation with PIX authors (the mapping is argued in §4.7 but PIX is a draft).

# Round 3 — bridge announcement / revocation / thin-chain (v0.5.0 → v0.6.0)

Three adversarial reviewers (DHT/directory attack surface; economic/Sybil/
revocation; thin-chain design analysis) plus the "can a bridge be a non-node?"
design question. Resolutions in v0.6.0.

## Thin-chain verdict (adopted)
Only the **bond** is consensus-critical; identity/key-binding is a pre-existing
sunk on-chain cost; **roles + directory locator moved to the signed DHT liveness
record**. Pure-DHT rejected: a read-only stake proof cannot prevent one stake
backing many records (non-double-spend needs consensus). **Dropped the separate
on-chain `BridgeRegistration` record**; the on-chain footprint is now just a
bond bound one-to-one to `packet_pubkey`, ideally an **earmark of the node's
existing Safe stake** (one lock call), with a small **dedicated bond** fallback
for lightweight channel-less endpoint bridges. Earmark MUST NOT double-count vs
RFC-0007 CT stake.

## Bridge-is-a-node clarification
A bridge must speak the HOPR protocol (packet key + transport + session/SURB
machinery) but, being a session *endpoint* not a mid-path relay, needs **no
payment channels** — both directions of both legs are funded by client and
service. So a bridge MAY be a lightweight channel-less endpoint (§4.4.1).

## DHT/directory findings
| ID | Sev | Resolution |
| -- | --- | ---------- |
| C1 | Crit | "≥2 replicas" defeats only a single dishonest replica; §4.3.3 now REQUIRES ungrindable responsible-set assignment + min-k/honest-fraction + quorum from RFC-0016; §7 states the property conditionally. |
| C2 | Crit | bond↔packet_pubkey binding now enforced by the **bond object itself** (bound key signed at lock time; consumer checks the bond's own key), one bond = one identity (§4.4.1/§4.4.2). |
| H2 | High | Replica-side monotonicity now REQUIRED (reject lower-sequence STOREs + anti-entropy); dropped the "monotonicity is public per slot" over-claim (§4.3.3). |
| H3 | High | Security-critical revocation MUST use on-chain path; consumers fail-closed on unfetchable record (§4.4.4). |
| H4 | High | `current_load`→coarse `load_bucket`, weakly weighted; §7 adds explicit bridge-enumeration + load-correlation leak analysis. |
| M1 | Med | STORE/LOAD indistinguishability stated as shape-only, not semantic for bridge heartbeats (§4.3.3). |
| M2 | Med | Reject future `published_at`; require remaining-TTL margin for rendezvous selection (§4.4.1 step 3). |
| M3 | Med | Consumers SHOULD rate-limit accepted sequence advances (anti-flap) (§4.4.4). |
| L1/L2 | Low | Interim fetch-flood worse for enumerable bridge slots (blocking hook, §4.3.3); directory_id resolved from on-chain-anchored view only (§4.4.1 step 4). |

## Economic/Sybil/revocation findings
| ID | Sev | Resolution |
| -- | --- | ---------- |
| C1 | Crit | Slashing formats undefined → §4.4.2 now states plainly the bond is an entry deposit until slashing exists and security rests on shaping + capped selection **alone**; §6 makes slashing formats a blocking dependency. |
| C2 | Crit | Honest framing: recoverable bond prices a rental, not the one-shot correlation payoff; correlation resistance = shaping + capped fresh selection; optional burned admission noted (§4.4.2, §5, §10). |
| H1 | High | Slashing MUST: withdrawal doesn't stop liability accrual, a challenge freezes bond return, generous deadline for statistical proofs (§4.4.2). |
| H2 | High | Bond→selection weight now MUST be strictly **sub-linear and per-identity capped** (§4.4.3). |
| H3 | High | No operator↔identity linkage acknowledged; Sybil cost stated as linear; linkage flagged as open (§4.4.2, §10). |
| H4 | High | Self-reported load a small weak prior only; selective-service-via-load-faking documented as a known limitation under coarse errors (§4.4.3). |
| H5 | High | RB MUST honour a reservation citing any schedule_ver published within the last TTL; client MUST abort if commit-time chunk_price exceeds the bound (§4.5.2, §4.5.5). |
| M1 | Med | Consumer re-reads on-chain bond (checking withdrawing flag) within bounded staleness at commit (§4.4.3). |
| M2 | Med | `reservation_fee` sized to held-state cost; RB MAY cap client `expiry` (§4.5.2). |
| M3 | Med | Bond return blocked while any live bonded join exists → no consequence-free post-cooldown window (§4.4.2, §4.4.4). |
| M4 | Med | PIX allocation carries expiry + client reclaims unspent remainder; long session = sequence of short agreements (§4.7). |
| L1/L2 | Low | Whitewashing claim corrected (no reputation state to escape); fixed non-amplifiable heartbeat noted as a good property (§4.4.1/§4.4.4). |
