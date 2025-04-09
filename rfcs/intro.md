---
sidebar_position: 1
---


# HOPR RFC Intro

Request for Comments (RFC) for HOPR protocol

# Table of Contents

[RFC-0001: RFC Life Cycle and Process](./RFC-0001-rfc-process/rfc-process)

[RFC-0002: Common mixnet terms and keywords](./RFC-0002-mixnet-keywords/mixnet-keywords)

[RFC-0003: HOPR Packet Format and Protocol](./RFC-0003-hopr-packet-protocol/hopr-packet-protocol)

[RFC-0004: Proof of Relay](./RFC-0004-proof-of-relay/proof-of-relay)

[RFC-0005: HOPR Mixer](./RFC-0005-hopr-mixer/hopr-mixer)

[RFC-0006: Automatic path discovery](./RFC-0006-automatic-path-discovery/automatic-path-discovery)

[RFC-0007: Session protocol](./RFC-0007-session-protocol/session-protocol)

[RFC-0008: Return path incentivization](./RFC-0008-return-path-incentivization/return-path-incentivization)




## Overview

Welcome to the HOPR RFC Repository (hopr-rfc), the central hub for managing, discussing, and finalizing
Request for Comments (RFCs) related to the HOPR project.
Each RFC resides in its own repository within this organization, promoting modularity and clear documentation.

RFCs define the core HOPR protocol, its interfaces, and related smart contract specifications.
This repository serves as an index and guide for navigating all individual RFC repositories.

## Repository Structure

Each RFC will have its own dedicated repository to ensure modularity, easy management, and independent versioning.
This structure allows for storing associated assets such as images, diagrams, and relevant files within each RFC repository.

```plaintext
/hopr-rfc
│
├── rfcs
│   ├── RFC-0001-rfc-process/             # Repository for RFC process documentation
│   │   ├── assets/                       # Related assets (e.g., images, diagrams)
│   │   │   └── process-flow.png
│   │   └── 0001-rfc-process.md           # RFC document
│   │
│   ├── RFC-0002-core-protocol/           # Repository for core HOPR protocol
│   │   ├── assets/
│   │   │   └── core-protocol-diagram.mmd
│   │   └── 0002-core-protocol.md
│   │
│   ├── RFC-0003-announcement-contract/   # Repository for announcement contract
│   │   ├── assets/
│   │   └── 0003-announcement-contract.md
│   │
│   └── RFC-0004-return-path/             # Repository for return path component
│       ├── assets/
│       ├── 0004-return-path.md
│       ├── templates/                    # Common RFC templates and guidelines
│       └── rfc-template.md 
└── ui                                    # UI for displaying the awesome RFCs
```

## Contributing to RFCs

The process of contributiong RFC is detailed in the `./rfcs/RFC-0001-rfc-process/`. A summary will be posted below.
