**English** | [完整繁體中文](01-stripe-test-cards.zh-TW.md) | [Research home](../README.md)

# Stripe Test Card Research Overview

Checked on 2026-10-12 (Asia/Taipei).

The requested source is Karbon's [The Beginner’s Guide to Stripe Test Cards: Validate Your Checkout](https://www.karboncard.com/blog/test-card-stripe), credited to Swati Saraf. It covers successful card payments, declines, fraud checks, regional cards, and 3D Secure, and mentions refunds, disputes, and subscriptions. A clear publication date was not visible in the readable page.

The [complete Traditional Chinese reference](01-stripe-test-cards.zh-TW.md) includes the article's five card categories, checked against [Stripe's official testing documentation](https://docs.stripe.com/testing). It also includes official supplemental cases and a proposed software integration acceptance checklist. It preserves the distinction between source claims, official corrections, and tests still to execute.

The reference corrects five malformed card numbers for Mexico, Brazil, and three 3D Secure cases. It clarifies CVC checks, authentication versus payment results, and on-session versus off-session behavior. It also covers test environment credentials, customer-facing decline messages, webhook processing, refunds, disputes, and subscription testing.

This is an English overview rather than a duplicate card catalog. No account was accessed and no transactions were created. Use the complete reference for card inputs, prerequisites, and expected outcomes.
