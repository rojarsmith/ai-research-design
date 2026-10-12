**English overview** | [完整繁體中文研究](README.zh-TW.md)

# Website Maintenance Pages and VPS Failover

Research date: 2026-10-12 (Asia/Taipei).

This research compares maintenance messages, graceful degradation, and automatic failover for websites and HTTP services. The concrete scenario uses VPS A running nginx as the primary service and remote host B as the standby, with automatic return to A after recovery.

If A's application fails while nginx remains available, nginx can serve a local maintenance page. If A itself fails, the routing decision must run outside A: an external proxy or load balancer, health-based DNS, or supported provider IP reassignment. Automatic failback requires primary preference, meaningful readiness checks, and consideration of caching, affinity, existing connections, and data consistency.

The complete research is in Traditional Chinese:

- [Main comparison and A/B architecture options](README.zh-TW.md).
- [Costs, assumptions, worked examples and selection](research/01-costs-and-selection.zh-TW.md).
- [Implementation and failure/recovery validation](research/02-implementation-and-validation.zh-TW.md).
- [Official sources and deployment questions](research/03-sources.zh-TW.md).
- [nginx configuration and HTML/JSON examples](examples/README.zh-TW.md).

A static standby maintenance page is substantially simpler than a writable application standby. The examples are templates for review and adaptation, not a deployed production configuration. No live VPS or DNS settings were changed.
