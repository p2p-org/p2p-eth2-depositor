# RFC: Beacon Deposits Batcher v3 (Pectra support)

> **Purpose:** Input for discussion and decision-making. Not a Tech Design.
> 

**TLDR**

- New v3 of our beacon deposit batcher with Pectra (0x02) support.
- Same shape as v2, single entry point, `amount` added to `deposit(...)`.
- Becomes the default batcher in the P2P API; v1/v2 deprecated but still usable.
- ~400 validators per tx (verified), audit passed.

---

## 1. Summary

**What is it?** A new version (v3) of P2P's beacon deposits batching contract that supports Pectra (0x02 / compounding) validators in addition to legacy 0x01 (32 ETH) deposits.

**Why do we need it now?** A client (Taurus) needs to onboard Pectra validators through a P2P-owned batcher so they can keep identifying P2P operators by contract address — the way they already do for v1/v2. The general-purpose batching we deferred to pre-Pectra was never delivered, so without v3 there is no Pectra-compatible path for clients that rely on contract-address operator identification.

**Core idea of the solution**

- New Solidity contract, same overall shape as v2.
- Single `deposit(...)` entry point, extended with an `amount` argument used for every validator in the batch.
- Deployed per operator at new addresses (v1/v2 addresses cannot be reused).
- Becomes the default batcher constructed by the P2P API.

**Scope**

- In: new contract, API switch to v3 as default for new flows.
- Out: address preservation, mixed 0x01+0x02 batches, per-validator variable amounts, automatic migration of existing v1/v2 operators.

---

## 2. HLD

```
┌──────────────┐        ┌──────────────────────┐        ┌──────────────────────┐
│  P2P API     │ build  │  Beacon Deposits     │  N×    │  Beacon Deposit      │
│  (tx build)  │──────▶ │  Batcher v3          │──────▶ │  Contract (L1)       │
└──────────────┘        │  (per operator)      │        └──────────────────────┘
      ▲                 └──────────────────────┘
      │ calldata
      │
┌──────────────┐
│  Client      │ signs & submits tx
│  (e.g. Taurus)│
└──────────────┘
```

- Components: P2P API (calldata construction), Batcher v3 (per-operator contract), Beacon Deposit Contract (L1, external).
- Ownership: P2P owns API and Batcher v3; Beacon Deposit Contract is protocol-owned.

---

## 3. Problem Statement

Today P2P operates two batching contracts: v1 (up to 100 validators per tx) and v2 (up to 400). Both hard-code a 32 ETH deposit amount and 0x01 withdrawal credentials, so they only work for pre-Pectra validators. When Pectra was approaching we chose to wait for a general-purpose batcher instead of extending our own; that batcher was never delivered.

As a result, clients that identify P2P operators by batcher contract address — which is a meaningful integration pattern for us — have no Pectra-compatible option. Taurus is the first concrete case; more are expected as compounding validators become standard. Not addressing this loses us a differentiator and blocks Pectra onboarding for these clients.

---

## 4. Goals / Non-Goals

### Goals

- Support batched 0x02 (compounding) deposits with a shared amount per batch (1–2048 ETH).
- Continue to support 0x01 32 ETH batched deposits via the same entry point.
- Match v2 capacity: ~400 validators per transaction (already verified).
- Become the default batcher constructed by the P2P API for new deployments.
- Pass external audit before becoming API default (already done).

### Non-Goals

- Reusing v1/v2 contract addresses (not possible).
- Mixed 0x01 + 0x02 deposits in a single transaction.
- Variable amount per validator within a batch.
- Automatic migration of existing v1/v2 operators.

---

## 5. Proposed Solution

### 5.1 Component Responsibilities

- **Batcher v3 contract**
    - Accepts a batch of validator deposit parameters plus a single `amount`.
    - Iterates and forwards each item to the Beacon Deposit Contract.
    - Does not perform validator-level business logic, does not store deposit state.
- **P2P API**
    - Constructs calldata for the operator's v3 instance.
    - Switches default to v3 for new flows; can still build v1/v2 calldata for legacy callers.
- **Client**
    - Signs and submits the transaction.
    - Optionally constructs its own tx against v1/v2 if it has not migrated.

### 5.2 Integration Flow (Happy path)

1. Client requests a batched deposit through the P2P API.
2. API builds calldata targeting the operator's v3 batcher with the batch parameters and shared `amount`.
3. Client signs and submits the transaction.
4. v3 contract iterates over the batch and calls the Beacon Deposit Contract once per validator.

### 5.3 Scope

- One Solidity contract, single `deposit(...)` entry point with `amount`.
- API change: default to v3 for new operator deployments.
- Tests: unit + fork tests on a Pectra-era network; 400-validator batch verified.
- Audit: completed.

---

## 6. Alternatives Considered

Omitted — no meaningful alternatives beyond "wait for the generic batcher", which is what blocked us last time and is the reason for this RFC.

---

## 7. Rollout / Operations

- Deploy v3 per operator using existing deployment tooling.
- Switch P2P API default to v3 for new operator deployments.
- v1 and v2 remain deployed and callable; marked deprecated.
- Success signals: Taurus and follow-on clients successfully submit 0x02 batches via v3; no regressions on 0x01 flows.
- Rollback: API can fall back to constructing v2 calldata for 0x01-only flows; v3 contracts simply remain unused.

---

## 8. Risks & Mitigations

- **Risk:** Some API clients may need to update whitelists / operator-address mappings to recognize v3 contract addresses.
    - **Mitigation:** Notify affected clients ahead of the API default switch; document the new addresses in the integration guide.
- **Risk:** Bug in 0x02 amount handling could misroute or lock funds.
    - **Mitigation:** Input validation in the contract, full test coverage, external audit (completed).
- **Risk:** Gas / calldata pressure at 400 0x02 deposits.
    - **Mitigation:** Already benchmarked; 400 confirmed achievable. Cap is configurable on the API side if conditions change.

---

## 9. Out of Scope / Future Work

- Mixed 0x01 + 0x02 batches.
- Per-validator variable amounts.
- Address preservation across versions.
- Automatic migration of existing v1/v2 operators to v3.