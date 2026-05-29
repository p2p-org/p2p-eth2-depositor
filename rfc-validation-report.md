# RFC Validation Report — 2026-05-29

## Inputs
- **Branch:** main
- **Commit:** a165208 (2026-05-22)
- **Working tree:** dirty (1 modified, 2 untracked)
  - `.gitignore` *(modified)*
  - `.claude/` *(untracked)*
  - `rfcs/` *(untracked)*
- **RFCs validated:**
  - `rfcs/RFC Beacon Deposits Batcher v3 (Pectra support) 36bf8e6f8ab58174a74bf4c0d8853d6d.md` — last modified 2026-05-29

> The working tree is dirty, so this report reflects HEAD **plus uncommitted edits** — the SHA does not pin what was validated. (The dirty paths are tooling/spec only; no source under `src/` or `test/` is modified.)
> The RFC was last touched (2026-05-29) *after* the HEAD commit (2026-05-22). The spec is current relative to the code.

---

## RFC: Beacon Deposits Batcher v3 (Pectra support)
**Source:** `rfcs/RFC Beacon Deposits Batcher v3 (Pectra support) 36bf8e6f8ab58174a74bf4c0d8853d6d.md`
**Summary:** 9 implemented / 2 partial / 0 pending / 0 deviations / 3 extras

This RFC is explicitly *"Input for discussion and decision-making, not a Tech Design."* Several requirements are API-side or process-side (audit, API default switch) and are out of scope for this contracts repo — they're recorded under "Out of scope / extras" rather than counted as gaps.

### ✅ Implemented
- **New v3 contract, same overall shape as v2, single `deposit(...)` entry point** (§1, §5.1, §5.3) — `src/P2pEth2Depositor.sol:57-104`. One external `deposit(...)` function; no other entry points.
- **`amount` argument added to `deposit(...)`, applied to every validator in the batch** (§1, §4, §5.1) — `src/P2pEth2Depositor.sol:62` (param), `:95` (`deposit{value: amount}` forwarded per validator in the loop). Single shared amount, not per-validator.
- **Support batched 0x02 (compounding) deposits with shared amount 1–2048 ETH** (§4 Goals) — bounds enforced at `src/P2pEth2Depositor.sol:76` (`amount >= minDepositAmount` = 1 ETH, `:30`) and `:78` (`amount <= maxCollateral` = 2048 ETH, `:33`). `0x02` prefix constant at `:24`.
- **Large deposit (>32 ETH) requires 0x02 credentials** (§4, §8 amount-handling mitigation) — `src/P2pEth2Depositor.sol:79-84`: when `amount > collateral` (32 ETH, `:32`), enforces `withdrawal_credentials[0] == 0x02`.
- **Continue to support 0x01 32 ETH batched deposits via the same entry point** (§4 Goals) — same `deposit(...)`; credential type is caller-supplied (`src/P2pEth2Depositor.sol:59`, `:97`). 32 ETH / 0x01 path exercised by `test/P2pEth2Depositor.t.sol:475-483` (mainnet fork fixture).
- **Match v2 capacity: up to ~400 validators per transaction** (§3, §4) — `maxValidatorsPerTx = 400` at `src/P2pEth2Depositor.sol:20`; range check at `:67-70`. (Successful-400 *verification* is partial — see below.)
- **Iterate and forward each item to the Beacon Deposit Contract; no validator-level business logic, no deposit state stored** (§5.1) — loop at `src/P2pEth2Depositor.sol:94-101` calls `depositContract.deposit{value: amount}(...)`; contract holds no deposit storage. Interface at `src/interfaces/IDepositContract.sol:24-29`.
- **Single withdrawal-credentials value per tx (one credential type per batch)** (§5.1 / implied by non-goal "mixed 0x01+0x02") — `withdrawal_credentials` is a single `bytes` shared across the loop (`src/P2pEth2Depositor.sol:59`, `:97`), length-checked to 32 at `:75`.
- **Input validation to prevent misrouted/locked funds** (§8 mitigation) — validator count (`:67`), array-length parity (`:71-74`), credential length (`:75`), amount min/gwei-alignment/max (`:76-78`), `msg.value == amount * count` (`:86-87`), per-item pubkey/signature length (`:89-92`).

### ⚠️ Partially implemented
- `[P:med]` **"~400 validators per tx (verified)" / "400-validator batch verified"** (§ TLDR, §4, §5.3) — the *cap* is implemented (`maxValidatorsPerTx = 400`) and the **over-cap** path is tested (`test/P2pEth2Depositor.t.sol:31-43`, 401 reverts). But there is **no test that successfully executes a 400-validator (or any large-N) batch**. The only successful end-to-end deposits in the suite are 1- and 2-validator fork fixtures (`:321-337`, `:361-369`). The RFC's "verified" / gas-benchmark claim (§8) is not reproduced in-repo.
- `[P:low]` **"Tests: unit + fork tests on a Pectra-era network"** (§5.3) — unit tests (revert paths) and fork tests exist, and Pectra 0x02 deposits are covered via Hoodi fixtures (`test/P2pEth2Depositor.t.sol:361-369`, `:524-542`). Partial because: (a) fork tests **silently skip** when RPC env vars are unset (`:371-386`) — CI without `ETH_RPC_URL_*` exercises *no* successful deposit; (b) there is no local/mocked happy-path deposit, so the success path is untested offline.

### ❌ Pending
- None. All contract-level requirements in the RFC have corresponding code.

### 🔀 Deviations
- None material. (See RFC quality notes for a minor under-32-ETH-with-0x01 behavior worth confirming, but it is consistent with the RFC's "wrapper does not replicate every protocol rule" stance.)

### ➕ Out of scope / extras
- **`receive()` rejects direct ETH** — `src/P2pEth2Depositor.sol:44-46`. Not in RFC; sensible hardening. Tested at `test/P2pEth2Depositor.t.sol:261-265`. Intentional? **yes.**
- **Pausable + Ownable (pause/unpause, guarded `renounceOwnership` while paused)** — `src/P2pEth2Depositor.sol:113-134`. Not specified in RFC; operational safety. Tested at `:210-259`. Intentional? **yes.**
- **Constructor validation of deposit-contract address (non-zero, has code)** — `src/P2pEth2Depositor.sol:36-37`. Enables per-network deployment (mainnet/Hoodi share the canonical address). Tested at `test/P2pEth2Depositor.t.sol:267-279`. Intentional? **yes.**
- **P2P API default switch to v3 / v1-v2 deprecation** (§1, §4, §5.1, §7) — API-side, not in this contracts repo. Intentional? **yes — out of scope for this repo.**
- **Per-operator deployment at new addresses** (§1, §5.3, §7) — handled by deployment tooling; `forge create` instructions in `README.md:31-43`. No `script/` dir. Intentional? **yes.**
- **External audit completed** (§ TLDR, §4, §8) — process claim; not code-verifiable. Commit history shows a `audit-fixes` merge (`bf964e9`) and a `0x02-supported` merge (`a165208`), consistent with the claim. Intentional? **yes.**

### 🧪 Test coverage
**Covered:**
- Validator count bounds (0 and 401 revert) — `test/P2pEth2Depositor.t.sol:18-43`
- Withdrawal-credentials length — `:45-52`
- Array-length parity (roots, signatures) — `:54-61`, `:154-166`
- Large-deposit (>32 ETH) credential guard for 0x00/0x01/0x03 — `:63-100`, plus mainnet fork 32.1-ETH-0x00 revert `:339-359`
- `msg.value` mismatch — `:102-113`
- Amount min / zero / gwei-alignment / above-2048 — `:115-180`
- Per-item pubkey / signature length — `:182-208`
- Pause/unpause, owner-gating, renounce guard — `:210-259`
- Direct-ETH rejection — `:261-265`
- Constructor validation — `:267-279`
- Successful 0x01 deposits (1 and 2 validators) on mainnet fork — `:321-337`
- Successful 0x02 deposits (32 and 33 ETH) on Hoodi fork — `:361-369`
- Canonical per-validator amount encoding (gwei, little-endian) asserted on fork — `:439-463`

**Gaps:**
- `[P:med]` **No successful large-batch deposit test** (e.g. 400 validators) — the RFC's headline capacity claim is unverified in-repo. Searched `test/` for non-revert multi-validator calls; only N=1 and N=2 fork fixtures exist.
- `[P:med]` **No offline happy-path test** — every locally-runnable `deposit` call expects a revert; success is only exercised via fork tests that **skip without RPC** (`:371-386`). A mocked `IDepositContract` would let the happy path run in CI.
- `[P:low]` **No success test at the boundary `amount == 2048 ETH`** (only `2048 ETH + 1 gwei` revert, `:168-180`).
- `[P:low]` **No success test for a 0x02 deposit `> 32 ETH` with N>1** beyond single-validator Hoodi 33 ETH.

### ❓ Ambiguous / needs human review
- **"~400 validators per tx (verified)" and gas benchmark (§8)** — "verified" likely refers to an external/manual benchmark not committed here. Confirm whether reproducing it in CI is desired, or whether the external evidence suffices.
- **Audit completion (§ TLDR, §4)** — claimed done; cannot be confirmed from the repo beyond the `audit-fixes` merge commit. Link the audit report if it should be tracked alongside the code.

### 📝 RFC quality notes
- **Under-32-ETH / 0x01 amounts:** the RFC frames 0x01 as "32 ETH" deposits, but the contract allows any gwei-aligned `amount` in `[1 ETH, 32 ETH]` with a 0x01 (or any non-0x02) credential — it defers the exact-32-ETH protocol rule to the canonical deposit contract (documented in `README.md:56,60`). This is reasonable given the RFC's "wrapper does not replicate every protocol rule" stance, but the RFC text itself doesn't state the wrapper's lower bound is 1 ETH for *all* credential types. Worth a sentence in the spec.
- **Pubkey uniqueness:** an earlier on-chain uniqueness check was removed (commits `0050a09` add, `0f37cf5` remove); the README now pushes uniqueness off-chain (`README.md:54`). The RFC doesn't mention uniqueness either way, so no conflict — just noting the deliberate design choice in case the RFC should record it.
- **"Same shape as v2":** the RFC repeatedly anchors to v2 but doesn't include the v2 signature, so "same shape" can't be mechanically verified against a reference here. Not blocking.
