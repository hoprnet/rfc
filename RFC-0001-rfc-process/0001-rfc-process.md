# RFC-0001: RFC Life Cycle and Process

- **RFC Number:** 0001  
- **Title:** RFC Life Cycle and Process
- **Status:** Raw
- **Author(s):** QYuQianchen  
- **Created:** 2025-02-20  
- **Updated:** 2025-02-20  
- **Version:** v0.1.0 (Raw)
- **Supersedes:** N/A
- **References:**

## Abstract

This RFC defines the life cycle, contribution process, versioning system, and governance model for RFCs at HOPR. 
It outlines stages, naming conventions, and validation rules that MUST be followed to ensure consistency and clarity across all RFC submissions. 
The process ensures iterative development with feedback loops and transparent updates with pull requests (PR).

## Motivation

HOPR project requires a clear and consistent process for managing technical proposals, documenting protocol architecture. 
A well-defined life cycle MUST be established to maintain coherence, ensure quality, and streamline future development.

## Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in [IETF RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119).

## Specification
### 1. RFC Life Cycle Stages

#### **Mermaid Diagram for RFC Life Cycle Stages**

```mermaid
graph TD;
    A[Raw] --> B[Discussion];
    B --> C[Review];
    C --> D[Development - v0.x.x];
    D --> E[Implementation - PR Merge];
    E --> F[Finalized - v1.0.0];
    F --> G[Errata - v1.0.x];
    F --> H[Superseded - New RFC];
    A --> I[Rejected - Documented Reasons];

## Design Considerations

<!-- Discuss critical design decisions, trade-offs, and justification for chosen approaches over alternatives. -->

## Compatibility

<!-- Address backward compatibility, migration paths, and impact on existing systems. -->

## Security Considerations

<!-- Identify potential security risks, threat models, and mitigation strategies. -->

## Drawbacks

<!-- Discuss potential downsides, risks, or limitations associated with the proposed solution. -->

## Alternatives

<!-- Outline alternative approaches that were considered and reasons for their rejection. -->

## Unresolved Questions

<!-- Highlight questions or issues that remain open for discussion. -->

## Future Work

<!-- Suggest potential areas for future exploration, enhancements, or iterations. -->

## References
- [IETF RFC 2119](https://datatracker.ietf.org/doc/html/rfc2119)
- https://www.rfc-editor.org/rfc/rfc2616
- https://www.rfc-editor.org/styleguide/
- https://datatracker.ietf.org/doc/rfc9114/
- https://katzenpost.network/docs/
- https://github.com/rust-lang/rfcs
- https://github.com/rust-lang/rfcs/blob/master/0000-template.md
- https://github.com/martinthomson/i-d-template/blob/main/example/draft-todo-yourname-protocol.md
- https://github.com/rpaulo/quic-base-drafts/tree/master
- https://www.rfc-editor.org/rfc/rfc2026.txt
- https://rfc.zeromq.org
- https://github.com/unprotocols/rfc
- https://cwiki.apache.org/confluence/pages/viewpage.action?pageId=120722035#LightweightRFCProcess-Collaboration
- https://authors.ietf.org/en/templates-and-schemas
- https://raw.githubusercontent.com/martinthomson/internet-draft-template/main/draft-todo-yourname-protocol.md
- https://github.com/unprotocols/rfc/tree/master/2
- https://zguide.wdfiles.com/local--files/main%3A_start/zguide-c.pdf
- https://github.com/vacp2p/rfc-index