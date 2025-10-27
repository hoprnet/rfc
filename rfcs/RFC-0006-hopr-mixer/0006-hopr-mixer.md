# RFC-0006: HOPR Mixer

- **RFC Number:** 0006
- **Title:** HOPR Mixer
- **Status:** Finalised
- **Author(s):** Tino Breddin (@tolbrino)
- **Created:** 2025-08-14
- **Updated:** 2025-09-04
- **Version:** v1.0.0 (Finalised)
- **Supersedes:** none
- **Related Links:** [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md),
  [RFC-0004](../RFC-0004-hopr-packet-protocol/0004-hopr-packet-protocol.md)

## 1. Abstract

This RFC describes the HOPR mixer component, a critical element of the HOPR mixnet that introduces temporal mixing to break timing correlations between
incoming and outgoing packets. By applying random delays to packets, the mixer effectively destroys temporal patterns that could otherwise be exploited
for traffic analysis attacks. This specification details the mixer's design, implementation requirements, and integration points to enable consistent
implementations across different HOPR nodes whilst balancing anonymity protection against latency and throughput requirements.

## 2. Motivation

In mixnets, simply forwarding packets through multiple hops is insufficient to prevent traffic analysis attacks. Even with encrypted packet contents and
obscured routing paths, adversaries can correlate packets by observing timing patterns. An observer monitoring network traffic at multiple points can
potentially link incoming and outgoing packets based on their arrival and departure times. This technique is known as timing correlation or an intersection attack.

Without temporal mixing, an adversary who observes a packet arriving at node A at time `t₁` and a packet leaving node A at time `t₂ ≈ t₁` can infer with
high probability that these packets are the same, thus tracking packets through the network and potentially deanonymising communications.

The HOPR mixer addresses this attack vector by:

- **breaking temporal correlations**: introducing random delays between packet arrival and departure times, making timing-based correlation significantly
  more difficult
- **configurable privacy-latency trade-offs**: providing tunable delay parameters to balance anonymity protection against performance requirements
- **efficient implementation**: using a priority queue that maintains packet ordering by release time, enabling `O(log n)` operations
- **high-throughput support**: maintaining mixing effectiveness even under high packet rates

## 3. Terminology

Terms defined in [RFC-0002](../RFC-0002-mixnet-keywords/0002-mixnet-keywords.md) are used. Additional mixer-specific terms include:

_mixing delay_: A random time interval added to a packet's transit time through a node to prevent timing correlation attacks.

_release timestamp_: The calculated time at which a delayed packet should be forwarded from the mixer.

_mixing buffer_: A priority queue that holds packets ordered by their release timestamps.

## 4. Specification

### 4.1. Overview

The HOPR mixer follows a flow-based design that is split into these steps:

1. Accept packets from upstream components
2. Assign random delays to each packet
3. Store packets in a time-ordered buffer
4. Release packets when their delay expires

### 4.2. Configuration Parameters

The mixer accepts the following configuration parameters that control the delay distribution:

1. `min_delay`: minimum delay applied to packets (default: 0 ms). This establishes the lower bound of the delay interval.
2. `delay_range`: the range from minimum to maximum delay (default: 200 ms). The maximum delay is `min_delay` + `delay_range`.

The actual delay for each packet is randomly selected from a probability distribution over the interval `[min_delay, min_delay + delay_range]`. The
default implementation uses a uniform distribution, but implementations MAY support additional distributions (e.g., exponential, Poisson) for enhanced
anonymity properties.

### 4.3. Core Components

#### 4.3.1. Delay Assignment

When a packet arrives at the mixer, the following operations are performed:

1. A random delay is generated using a cryptographically secure random number generator (CSPRNG)
2. The release timestamp is calculated as `current_time + random_delay`
3. The packet is wrapped with its release timestamp metadata
4. The wrapped packet is inserted into the mixing buffer, ordered by release timestamp

To generate a satisfactory random delay, the following conditions MUST be met:

- MUST use a CSPRNG with sufficient entropy (at least 128 bits of entropy)
- MUST generate independent delays per packet, with no correlation or reuse across packets
- SHOULD use uniform distribution as the baseline; other distributions (e.g., exponential, Poisson) MAY be supported via configuration
- MUST NOT leak information about delay values through timing side channels

Different mixing strategies produce different results. A uniform distribution will provide a simple baseline that is easy to implement and analyse. More advanced strategies like Poisson mixing (as used in Loopix [01]) can provide stronger anonymity properties by making packet timings less distinguishable from cover traffic
patterns, but require careful parameter tuning and integration with cover traffic generation.

#### 4.3.2. Mixing buffer

The mixer maintains packets in a data structure where:

- Packets are ordered by their release timestamps
- The packet with the earliest release time is always at the top
- Insertion and extraction operations have `O(log n)` complexity
- If multiple packets share the same `release_time`, the ordering MUST be stable FIFO by insertion sequence

This ensures efficient processing even under high-load conditions.

### 4.4. Operational Behaviour

#### 4.4.1. Packet processing flow

Packet processing SHOULD use the following flow:

```
1. Packet arrives at mixer via sender
2. Random delay is generated: delay ∈ [min_delay, min_delay + delay_range]
3. Release timestamp calculated: release_time = now() + delay
4. Packet wrapped with timestamp and inserted into buffer
5. Receiver woken if sleeping
5a. If the inserted packet has an earlier `release_time` than the current head, re-arm the timer to the new head
6. When current_time ≥ release_time, packet is released to Receiver
6a. Upon wake (including after system sleep), release all packets with `release_time` ≤ current_time before sleeping again
```

#### 4.4.2. Timer Management

The mixer requires a timer that is able to:

- Wake the mixer at the next packet's `release_time`
- Use minimal system calls and context switches
- Handle concurrent access safely
- Use a monotonic clock source (not wall clock) for computing `release_time`
- Handle system sleep/clock adjustments by releasing all overdue packets immediately upon wake

NOTE: The need for a dedicated timer MAY be satisfied automatically when using an RTOS and its native waking mechanisms.

### 4.5. Special Cases

#### 4.5.1. Zero Delay Configuration

When both `min_delay` and `delay_range` are zero:

- Packets pass through without mixing
- Original packet order is preserved
- Useful for testing or non-anonymous operation modes

## 5. Design Considerations

### 5.1. Performance Optimisation

An implementation should prioritise:

- **minimal allocations**: Pre-allocated buffer reduces memory pressure
- **efficient data structures**: Binary heap provides `O(log n)` operations
- **lock minimisation**: Fine-grained locking for concurrent access
- **timer efficiency**: Single shared timer reduces system overhead, including minimising runtime system overhead by using a single thread

### 5.2. Abuse Resistance and Resource Limits

- **timing attacks**: Random delays must use cryptographically secure randomness
- **statistical analysis**: Uniform distribution is a simple baseline; stronger timing strategies (e.g., exponential/Poisson as in Loopix [01])
  provide better resistance to pattern inference
- **queue bounds and DoS**: The mixer MUST use a bounded buffer with backpressure. Implementations MUST define behaviour when full (e.g., drop-tail
  oldest/newest, randomized drop, or reject upstream sends) and expose metrics/alerts to prevent memory exhaustion attacks.

### 5.3. Monitoring and Metrics

The mixer should track:

- Current queue size
- Average packet delay (over configurable window)

These metrics aid in:

- Performance tuning
- Detecting abnormal traffic patterns
- Capacity planning

## 6. Security Considerations

### 6.1. Threat Model

The mixer defends against:

- **timing correlation attacks**: Randomized delays make linking input/output packets by timing significantly harder
- **statistical traffic analysis**: Random delays reduce pattern predictability but do not eliminate all analysis
- **queue manipulation**: Authenticated packet handling prevents injection attacks

### 6.2. Limitations

The mixer does not protect against:

- **Low-volume spread traffic** that does not produce a sufficient number of messages to be mixed within the delay window
- **Global passive adversaries** with unlimited observation capability
- **active attacks**: packet dropping or delaying by malicious nodes
- **side channels**: CPU, memory, or network-level information leaks

## 7. Drawbacks

- **increased latency**: Every packet experiences additional delay
- **memory usage**: Buffering packets requires memory proportional to traffic volume and queue size
- **complexity**: Adds another component to the protocol stack, which even makes node-local debugging harder
- **simplistic nature**: The mixing does not account for the total count of elements in the buffer. With increasing numbers of messages in the mixer,
  the generated delay can decrease without sacrificing the mixing properties.

## 8. Alternatives

Alternative mixing strategies considered:

- **batch mixing**: Release packets in fixed-size batches (higher latency)
- **threshold mixing**: Release when buffer reaches a certain size (variable latency)
- **stop-and-go mixing**: Fixed delays at each hop (predictable patterns)
- **poisson mixing**: As implemented in Loopix [01], uses Poisson-distributed delays that make real traffic harder to distinguish from cover traffic.
  This can provide stronger anonymity properties but requires careful parameter tuning and integration with cover traffic.

The current continuous mixing approach with uniform distribution is a simple baseline that balances latency and anonymity while being easier to
implement and analyse.

## 9. Unresolved Questions

- Optimal delay parameters for different network conditions
- Adaptive delay strategies based on traffic patterns
- Integration with node-local cover traffic generation
- Memory usage limits and robust overflow handling strategies

## 10. Future Work

- **poisson mixing implementation**: Implement Poisson mixing (exponentially distributed per-packet delays derived from a Poisson process) as described in Loopix [01] to provide stronger anonymity properties when combined with cover traffic
- Performance optimizations for hardware acceleration

## 11. References

[01] Piotrowska, A. M., Hayes, J., Elahi, T., Meiser, S., & Danezis, G. (2017). [The Loopix Anonymity System](https://arxiv.org/pdf/1703.00536.pdf).
_26th USENIX Security Symposium_, 1199-1216.
