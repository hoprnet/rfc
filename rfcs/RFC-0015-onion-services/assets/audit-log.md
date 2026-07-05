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

## Not yet fully closed (tracked in §10 Unresolved / §11 Future Work)
- Exact Ed25519 blinding construction (deferred to companion directory RFC).
- Concrete slashing challenge/proof formats.
- Guard mechanism vs per-connection freshness tension (documented, not resolved).
- Concrete PoW puzzle for free-tier.
- Whether PIX's streaming construction cleanly covers the RB-as-exit mapping needs
  confirmation with PIX authors (the mapping is argued in §4.7 but PIX is a draft).
