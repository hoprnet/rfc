# Audit: PR #92 (RFC-0015 Onion Services over HOPR)

Audited 2026-10-27. Head `015b546`, 26 commits ahead and 18 behind `origin/main`,
+2625/-0 across 4 files.

## Findings

### 1. Four unrelated artifacts in one PR (blocks review)

| Path | Lines |
| --- | --- |
| `rfcs/RFC-0015-onion-services/0015-onion-services.md` | 1911 |
| `rfcs/RFC-0016-distributed-directory/0016-distributed-directory.md` | 381 |
| `SUMMARY.md` | 331 (whole file) |
| `README.md` | 2 |

RFC-0015, RFC-0016 and the protocol summary are independent changes. A reviewer of
the directory design has to read 1911 lines of onion-service text first, and a
reviewer of the summary has to diff a 331-line file that already exists on main.

### 2. `SUMMARY.md` conflicts with and regresses main

Main already carries `SUMMARY.md` (added in #94, updated in #99 and #104). The PR
adds a parallel copy:

- main: statuses as of 2026-09-14, RFC-0010 v1.2.0, RFC-0014 v1.1.0
- PR: statuses as of 2026-07-06, RFC-0010 v1.1.0, RFC-0014 v1.0.0

Diff against main is 210 insertions / 165 deletions. Merging as-is rolls back
status and version corrections made after the PR branch forked.

### 3. `README.md` duplicate

Main already links `SUMMARY.md` ("RFC-0001 through RFC-0014"). The PR adds a
second, differently worded link line. At most one line is needed, and only to
change `0014` to `0016`.

### 4. PR body is stale

Body says "Status: Raw, v0.6.0" and lists `assets/design-decisions.md` and
`assets/audit-log.md`. Neither file exists in the branch; the RFCs are v0.9.0 and
v0.1.3. The body also predates the pivot to bondless bridges.

### 5. CI proves little

`scripts/structure-check.sh` validates the title line and 9 front-matter fields
only. It does not check links, front-matter/version consistency, markdownlint, or
`SUMMARY.md` accuracy. All checks are green, which says nothing about review
readiness.

### 6. No human review

Review history is CodeRabbit, Copilot and self-comments. 26 commits are version
increments (v0.1 to v0.9), so the PR is being used as a design log. Design logs
are hard to review; reviewable diffs are not.

### 7. RFC-0015 and RFC-0016 are circularly dependent

RFC-0015 §4.3 depends on the directory for blinded descriptors and anti-abuse.
RFC-0016's motivation depends on onion services as its first consumer. They cannot
merge in either order without one referring to an unmerged document, so the
sequence needs an explicit decision.

### 8. Size is concentrated in a few sections

RFC-0015: §7 Security 171 lines, §4.6.1 Multipath 153, §4.4.1 Announcement 109,
§4.1 Overview 74, §4.3.1 Descriptor 68, §4.7 Incentivisation 68, §4.4.2
Accountability 67, §4.4.5 Reputation 64, §5 Design Considerations 62, §4.3.3
Directory interface 60.

### 9. Status and maturity disagree

Both documents are `Status: Raw`, but RFC-0015 v0.9.0 contains normative MUST /
SHOULD requirements and cites unmerged RFC-0012 (PIX), an RFC-0004 minor bump, and
an unwritten directory contract. "Raw" is honest about the process state, but the
text reads as a candidate specification, which invites line-level review the
document cannot yet satisfy.

### 10. Open questions are design decisions, not spec text

RFC-0015 §10 has 7 open items, RFC-0016 §10 has 5. They are governance and
deployment constants plus one formal proof. Mixed into the normative body, they
make "is this document ready?" unanswerable.

## Split options

### A. Artifact split (3 PRs)

1. RFC-0016 directory (381 lines).
2. RFC-0015 onion services (1911 lines).
3. `SUMMARY.md` + `README.md` rebased on main (about 20 lines).

Cuts the PR to reviewable artifacts, but leaves 1911 lines in one diff.

### B. Artifact split plus phased RFC-0015 (stacked PRs)

1. RFC-0016.
2. RFC-0015 skeleton: abstract, motivation, terminology, §4.1 overview, and
   section stubs marked TBD.
3. Then section PRs, roughly 150 to 350 lines each:
   - identity and descriptor (§4.2, §4.3)
   - bridges (§4.4)
   - introduction and rendezvous (§4.5)
   - handshake, multipath, sessions (§4.6)
   - incentives and DoS (§4.7, §4.8)
   - bridge session management and guards (§4.9, §4.10)
   - considerations, drawbacks, alternatives (§5 to §9)
   - open questions, future work, appendices (§10 to §14)

Each PR is reviewable on its own, but main carries an incomplete RFC between
steps and every PR must keep cross-references valid.

### C. Review-oriented split (keep documents whole)

Land RFC-0016 and RFC-0015 as two whole documents, and move the design log and
open questions into a third document. Fewer PRs, but the 1911-line review problem
stays.

### D. Draft-first

Land both RFCs as short `Raw` skeletons now, then fill sections in follow-up PRs.
Fastest merge, largest window where main holds a stub.

## Recommendation

A, then B only if RFC-0015 needs line-level review. Sequence RFC-0016 first
because RFC-0015 depends on it normatively. Take `SUMMARY.md` and `README.md` out
of both and file one small rebased update. Close or repurpose #92 as an umbrella
tracking issue rather than leaving two open copies of the same text.

## Decisions needed

1. Goal: review bandwidth, merge cadence, or both?
2. May RFC-0015 land on main as `Raw` and incomplete?
3. Does RFC-0016 merge before RFC-0015, or do both stay open until ready?
4. Keep #92 as umbrella, or close it after the split?
5. Summary/README: separate PR, or drop until both RFCs merge?
6. Target diff size per PR?
7. Who reviews each chunk?

## Decisions (2026-10-27)

1. Goal: review bandwidth.
2. Split RFC-0015 into phased stacked PRs, nine chunks.
3. RFC-0015 may not land incomplete: intermediate PRs are review-only; the top
   PR is retargeted to `main` and merged once.
4. Swap numbering: directory becomes RFC-0015, onion services becomes RFC-0016.
5. Both documents stay open in parallel.
6. `SUMMARY.md` and `README.md` move to a separate small PR rebased on `main`.
7. PR #92 stays open.

## Execution map (executed 2026-10-27)

| PR | Branch | Base | Content | Diff |
| --- | --- | --- | --- | --- |
| #118 | `kauki/docs/rfc/distributed-directory` | `main` | RFC-0015 directory | +381 |
| #120 | `.../onion-split/01-foundations` | `main` | title, §1 to §4.1 | +302 |
| #121 | `.../onion-split/02-identity-and-descriptor` | #120 | §4.2, §4.3 | +228/-2 |
| #122 | `.../onion-split/03-bridges` | #121 | §4.4 | +305/-1 |
| #123 | `.../onion-split/04-introduction-and-rendezvous` | #122 | §4.5 | +251/-1 |
| #124 | `.../onion-split/05-handshake-and-sessions` | #123 | §4.6 | +225/-1 |
| #125 | `.../onion-split/06-incentives-and-dos` | #124 | §4.7, §4.8 | +106/-2 |
| #126 | `.../onion-split/07-bridge-management-and-guards` | #125 | §4.9, §4.10 | +106/-2 |
| #127 | `.../onion-split/08-considerations-and-security` | #126 | §5 to §9 | +315/-5 |
| #128 | `.../onion-split/09-open-questions-and-appendices` | #127 | §10 to §14 | +93/-6 |
| #119 | `kauki/docs/rfc/summary-add-0015-0016` | `main` | summary rows, intro, README link | +5/-3 |

Verified: `#128` retargeted to `main` yields exactly the 1911-line RFC-0016 file.
`#118` yields the 381-line RFC-0015 file. `scripts/structure-check.sh` passes on
all three branch tips. Intermediate PRs are drafts and marked review-only.

The branch prefix is `onion-split`, not `onion-services`: a remote branch
`kauki/docs/rfc/onion-services` already exists (the #92 head), and git refuses
child refs under an existing ref.

## Link constraint (2026-10-27)

`ui/docusaurus.config.ts` sets `onBrokenLinks: "throw"` and builds docs from
`../rfcs`. Each split branch contains one document that links to the other, so
the Vercel preview fails with `Docusaurus found broken links`. Reproduced
locally with the repo's yarn lockfile on `kauki/docs/rfc/distributed-directory`.
Landing order deadlocks: neither document can go green until the other is on
`main`.

Resolution: in the split PRs, sibling cross-references are plain text (the RFC
number without a hyperlink). The spec text is otherwise unchanged. After both
documents land, apply `audit/restore-cross-links.patch` from the repository
root:

```sh
git apply audit/restore-cross-links.patch
```

That restores the 13 hyperlinks and returns both documents to the #92 content,
apart from the RFC number swap and the `Updated` date.

Also per `AGENTS.md`: both documents now carry `Updated: 2026-10-27`.

Verified on the rebuilt branches: `scripts/structure-check.sh` passes, and a
relative-link existence check reports zero missing targets for RFC-0015 and
RFC-0016. The local Docusaurus build was not rerun after cleanup (the first run
filled `/home`); Vercel is the end-to-end check.

## RFC-0015 design decisions

### D1. Slot lifecycle: per-period store with grace (2026-10-27)

- `RecordEnvelope` gains `period: u64`; `slot = H(auth_pubkey || period)`; the
  signature covers the whole envelope.
- A replica accepts `period == current`, or `period == current - 1` while
  `now < period_start(current) + BOUNDARY_GRACE`; otherwise reject.
- `published_at` must fall inside `[period_start, period_end)` and
  `ttl <= period_end - published_at + BOUNDARY_GRACE`. `TTL_MAX` remains an
  upper bound only.
- "Refresh" is a STORE at the new period's slot. Anti-entropy is per-period and
  does not migrate records across the boundary.
- Tombstones are period-scoped. Cross-period revocation is "stop publishing":
  the next period's slot is simply absent.
- For the blinded profile, the envelope's `published_at` and `ttl` must match the
  descriptor's `published_at` and `lifetime`, or the client uses the minimum.
- Consequence: RFC-0015 §4.3, §4.4, §4.5, §4.6 need edits; RFC-0016 §4.3.1 and
  §4.3.3 need a matching statement about re-publication at each boundary.
