# LLM Agent Instructions for HOPR RFC Repository

This document provides instructions for LLM agents working with the HOPR RFC repository to ensure consistent formatting, referencing, and quality
standards.

## Reference Style Standards

### External References (Academic/Technical Citations)

**Format Requirements:**

- Use sequential numbering: `[01]`, `[02]`, `[03]`, etc.
- Always use zero-padded two-digit format
- Follow academic citation format:

  ```text
  [XX] Author(s). (Year). [Title](URL). _Publication_, Volume(Issue), pages.
  ```

**Examples:**

```markdown
[01] Bradner, S. (1997). [Key words for use in RFCs to Indicate Requirement Levels](https://datatracker.ietf.org/doc/html/rfc2119). _IETF RFC 2119_.

[02] Chaum, D. (1981). [Untraceable Electronic Mail, Return Addresses, and Digital Pseudonyms](https://www.freehaven.net/anonbib/cache/chaum-mix.pdf).
_Communications of the ACM, 24_(2), 84-90.

[03] Danezis, G., & Goldberg, I. (2009). [Sphinx: A Compact and Provably Secure Mix Format](https://cypherpunks.ca/~iang/pubs/Sphinx_Oakland09.pdf).
_2009 30th IEEE Symposium on Security and Privacy_, 262-277.
```

**In-Text Citations:**

- Use bracketed numbers: `as described in [01]`
- Multiple citations: `[01, 02]` or `[01, 03, 05]`
- Never use inline URLs or full citations in body text

**References Section:**

- Place at end of document as `## X. References` (where X is section number)
- List in numerical order
- If no external references exist, use: `None.`

### RFC Cross-References (Internal HOPR RFCs)

**Metadata References:**

- List in **Related Links** field in document header
- Format: `[RFC-XXXX](../RFC-XXXX-slug/XXXX-slug.md)`
- Multiple references separated by commas
- If none exist, use: `none`

**Example:**

```markdown
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md),
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)
```

**In-Text RFC References:**

- Link to other RFCs: `[RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)`
- Never put RFC cross-references in the References section
- Always use full path format for consistency

## Document Structure Requirements

### Metadata Header

Every RFC MUST begin with this exact format:

```markdown
# RFC-XXXX: [Title]

- **RFC Number:** XXXX
- **Title:** [Title in Title Case]
- **Status:** Raw | Discussion | Review | Draft | Implementation | Finalised | Errata | Rejected | Superseded
- **Author(s):** [Name (@GitHubHandle)]
- **Created:** YYYY-MM-DD
- **Updated:** YYYY-MM-DD
- **Version:** vX.X.X (Status)
- **Supersedes:** RFC-YYYY | N/A | none
- **Related Links:** [RFC-XXXX](../RFC-XXXX-slug/XXXX-slug.md) | none
```

### Required Sections

1. **Abstract** - Brief summary (2-3 paragraphs max)
2. **References** - External citations only, or "None."

### Optional Standard Sections

- Motivation
- Terminology
- Specification
- Design Considerations
- Compatibility
- Security Considerations
- Drawbacks
- Alternatives
- Unresolved Questions
- Future Work

## Content Guidelines

### Writing Style

- Use clear, technical language
- Be concise and precise
- Use active voice where possible
- Define all technical terms
- Follow RFC 2119 keywords (MUST, SHOULD, MAY, etc.) when appropriate

### Technical Content

- Include diagrams in Mermaid format when helpful
- Use code blocks for technical specifications
- Provide concrete examples
- Ensure backward compatibility considerations
- Address security implications

### Cross-References

- Reference relevant terminology from RFC-0002 (Mixnet Keywords)
- Link to related protocol specifications
- Maintain consistency with existing RFCs
- Update related RFCs when making changes

## Quality Checklist

Before finalising any RFC modifications:

### References

- [ ] All external citations use `[XX]` format with zero-padding
- [ ] References section contains only external citations
- [ ] RFC cross-references are in Related Links metadata
- [ ] In-text citations use proper format
- [ ] No inline URLs in body text

### Structure

- [ ] Proper metadata header format
- [ ] Required sections present (Abstract, References)
- [ ] Logical and consistent section numbering
- [ ] Consistent formatting throughout

### Content

- [ ] Clear and concise writing
- [ ] All technical terms defined
- [ ] Examples provided where appropriate
- [ ] Security considerations addressed
- [ ] Compatibility implications discussed

### Cross-Consistency

- [ ] Terminology consistent with RFC-0002
- [ ] Technical details align with related RFCs
- [ ] Cross-references are accurate and current
- [ ] No conflicting specifications

### Validation

- [ ] Run `just spell-check` and ensure it passes with no errors
- [ ] All spelling errors must be fixed before finalising changes
- [ ] Use British English spelling variants (e.g., "analyse", "optimise", "finalise")

## Common Mistakes to Avoid, Do's and Don'ts

**Don't:**

- Use inline IETF RFC citations like `[IETF RFC 2119](https://...)`
- Put RFC cross-references in the References section
- Use single-digit reference numbers like `[1]`, `[2]`
- Include "TODO" placeholders in finalised documents
- Reference URLs directly in body text

**Do:**

- Use numbered external references: `[01]`, `[02]`
- Put RFC cross-references in Related Links metadata
- Always zero-pad reference numbers
- Complete all sections appropriately
- Use proper RFC linking format

## Version Control

When making changes:

- Update the "Updated" date in metadata
- Update Related Links if adding new cross-references
- Maintain backward compatibility unless explicitly breaking

## Repository Structure

- `/rfcs/RFC-XXXX-title-slug/` - RFC directory
- `XXXX-title-slug.md` - Main RFC document

Remember: Consistency across all RFCs is crucial for maintaining a professional, usable specification repository.
