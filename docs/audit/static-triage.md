# Static analysis triage
Keep raw Slither and Aderyn JSON/logs in evidence. No detector was disabled to obtain a zero-warning result; lib/test paths are outside the production source scan scope.

## Slither
- incorrect-equality (Medium): zero supply/debt/amount checks and same-block/index-cap checks are exact integer accounting states, not equality to a manipulable raw balance. Direct donations do not control tracked cash or supply. Reviewed as non-exploitable within the supported-token model.
- unused-return (Medium): sequencer round tuple metadata and price-feed startedAt are intentionally ignored. The adapter checks sequencer status and restart timestamp/grace; price feeds use positive answer, round IDs, updatedAt and maxAge. It does not equate a sequencer transition timestamp with an ordinary heartbeat.
- timestamp (Low): annual interest, freshness and sequencer grace intentionally use block time. Small timestamp variation affects interest; it is not entropy. Timestamp/sequencer manipulation remains a chain assumption, and configured heartbeat/parameters must be reviewed per deployment.

- reentrancy-balance (Medium): _pull/_push intentionally read balance before and after SafeERC20 calls. Both helpers are private and every caller is nonReentrant. A callback cannot mutate vault accounting; a callback donation makes the exact-delta check revert atomically. Token callbacks and read-only valuation are executed in regression tests. Malicious token balance lies remain outside the allowlisted-token trust model.

## Aderyn
- eth-send-unchecked-address (High): SafeERC20 reaches Address.functionCall, which delegates to functionCallWithValue(target,data,0). The native value is exactly zero; no vault method is payable and no ETH is transferred. The asset addresses are immutable contract addresses checked at construction. This detector follows the generic library call-with-value path without proving positive value; reviewed as a false positive for these concrete call sites. Native ETH support is not implemented.
- reentrancy-state-change (High): reported locations are constructor metadata reads followed by immutable configuration assignment. Metadata calls are STATICCALL; runtime code is not installed until construction completes. There is no reachable vault asset method in the construction frame. Reviewed as a constructor-specific false positive, not an unresolved exploitable High. Runtime reentrant token callbacks are separately executed and rejected.
- literal-instead-of-constant / unused-public-function (Low): style/gas observations; no direct funds-loss path demonstrated. Constants centralize protocol risk parameters; decimal normalization literals are explicit units.

Any future finding outside these reviewed detector families must fail automated triage and be reviewed. Static reports are supplementary to economic/manual review and do not establish independent audit assurance.
