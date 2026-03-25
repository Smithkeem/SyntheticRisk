# SyntheticRisk

## Overview
**SyntheticRisk** is a decentralized, high-fidelity collateral management protocol designed for the Stacks blockchain. It represents the second iteration (V2) of an AI-driven approach to synthetic asset minting, where the static nature of traditional collateralized debt positions (CDPs) is replaced by a dynamic, risk-aware engine. 

By integrating an AI Risk Oracle, the protocol adjusts collateralization requirements in real-time based on market volatility, user behavior, and historical risk profiles. This ensures that the protocol remains solvent during high-volatility events while offering capital efficiency to low-risk users.

---

## Table of Contents
1.  Introduction
2.  Key Features
3.  System Architecture
4.  Smart Contract Logic
    * Constants & Error Codes
    * State Variables
    * Private Functions
    * Public Functions
    * Read-Only Functions
5.  Liquidation Mechanism
6.  Security Considerations
7.  Installation and Deployment
8.  Contribution Guidelines
9.  License

---

## Introduction
In traditional synthetic asset protocols, the Collateralization Ratio (CR) is often a fixed, "one-size-fits-all" number (e.g., 150%). **SyntheticRisk** disrupts this model by introducing the `ai-risk-score`. This score acts as a multiplier on the base collateral requirement. 

If the AI Oracle detects an increase in the volatility of the underlying asset or identifies risky patterns in a specific user's position, the required CR for that specific user increases. Conversely, stable market conditions allow for a regression toward the baseline, maximizing liquidity.



## Key Features
* **AI-Driven Risk Scaling:** Dynamic adjustment of collateral requirements via an external AI Oracle.
* **Synthetic Minting & Burning:** Seamless entry and exit into synthetic asset positions.
* **Protocol Pausing:** Emergency "Circuit Breaker" functionality to protect user funds during unforeseen exploits.
* **Granular Position Tracking:** Detailed mapping of user collateral, debt, and risk history.
* **Incentivized Liquidation:** A robust engine that rewards third-party liquidators for maintaining system health.
* **Fee Accumulation:** Automated protocol fee collection for sustainable ecosystem growth.

---

## Smart Contract Logic

### Constants & Error Codes
The contract utilizes a strictly defined set of constants to ensure predictability and security.
* `base-collateral-ratio`: Set to **150%** to provide a safe buffer for asset fluctuations.
* `liquidation-penalty`: A **10%** fee applied to liquidated positions to discourage undercollateralization.
* `protocol-fee-rate`: A **0.50%** (50 basis points) fee on synthetic minting.

| Error Name | Code | Description |
| :--- | :--- | :--- |
| err-owner-only | u100 | Action restricted to the contract deployer. |
| err-insufficient-collateral | u101 | Provided collateral does not meet the AI-adjusted threshold. |
| err-position-not-found | u102 | Attempting to interact with a non-existent CDP. |
| err-unauthorized | u103 | Unauthorized caller (non-oracle/non-owner). |
| err-protocol-paused | u106 | Operations halted due to emergency pause. |

### State Variables
The protocol tracks global health and individual user data through a combination of data variables and maps:
* `total-collateral-locked`: Tracks the cumulative value of all assets held in escrow.
* `total-synthetic-minted`: Tracks the global supply of the synthetic asset.
* `positions`: A data map storing `collateral`, `synthetic-minted`, `ai-risk-score`, and `last-updated-height` for every principal.

---

### Private Functions
These functions handle the internal mathematical and logic checks that power the protocol.

* `calculate-required-collateral`: 
    Determines the minimum collateral a user must hold. It applies the formula:
    $$Required = \frac{Minted \times (\frac{BaseRatio \times RiskScore}{100})}{100}$$
* `calculate-protocol-fee`: 
    Calculates the 50 bps fee for minting actions.
* `is-active`: 
    A boolean check used as a guardrail for all state-changing public functions.
* `safe-add` / `safe-sub`: 
    Wrapper functions to handle arithmetic and prevent overflows or underflows within the Clarity VM.

---

### Public Functions
The primary interface for users, oracles, and administrators.

* `open-position`: 
    Allows a user to lock collateral and mint synthetic assets. It validates the AI-adjusted collateral ratio and deducts protocol fees instantly.
* `add-collateral`: 
    Enables users to strengthen their "Health Factor" by adding more assets to their existing position.
* `remove-collateral`: 
    Allows users to withdraw excess collateral, provided the remaining balance satisfies the current AI-dictated risk requirements.
* `repay-debt`: 
    Users can burn their synthetic assets to reduce their debt burden and eventually close their positions.
* `update-ai-risk-score`: 
    **Oracle Only.** This is the heart of V2. The authorized oracle updates the `ai-risk-score`, which can immediately change the status of a position from "Healthy" to "At-Risk."
* `pause-protocol` / `resume-protocol`: 
    Administrative functions to toggle the operational state of the contract.

---

### Read-Only Functions
Designed for frontend integration and transparency.

* `get-position`: 
    Returns the raw data tuple for a specific user address.
* `get-protocol-state`: 
    Returns a comprehensive overview of the protocol, including Total Value Locked (TVL), total debt, and the current authorized Oracle address.

---

## Liquidation Mechanism
The `liquidate-high-risk-position` function is a critical safety valve. If a user's `ai-risk-score` increases or the value of their collateral drops such that `collateral < required-collateral`, the position becomes eligible for liquidation.

1.  **Penalty Distribution:** A 10% penalty is taken from the user's collateral.
2.  **Incentive Split:** 80% of that penalty goes to the liquidator who called the function (as a reward for gas and risk), and 20% is funneled into the protocol treasury.
3.  **Debt Resolution:** The liquidator must provide the synthetic assets to burn (cover) the target user's debt.
4.  **Clean Slate:** The user's position is deleted from the map, and any remaining collateral (after penalties) is returned to them.

---

## Security Considerations
* **Oracle Centralization:** The protocol relies on the `ai-oracle` for risk scoring. It is recommended that this oracle be a multi-sig or a decentralized consensus-based system.
* **Flash Loan Defense:** The protocol checks collateralization at the end of every state-changing block.
* **Emergency Stop:** The `protocol-paused` variable can be triggered by the owner to prevent asset draining in the event of a discovered vulnerability.

---

## Installation and Deployment
To deploy this contract to the Stacks blockchain:

1.  Install the **Clarinet** CLI.
2.  Clone this repository.
3.  Run `clarinet check` to verify the logic.
4.  Configure your `Clarinet.toml` with the desired deployment network (testnet/mainnet).
5.  Deploy using:
    ```bash
    clarinet deploy --network mainnet
    ```

---

## Contribution Guidelines
We welcome contributions to the SyntheticRisk protocol. Please follow these steps:
1.  Fork the repository.
2.  Create a feature branch (`git checkout -b feature/Optimization`).
3.  Commit your changes with descriptive messages.
4.  Push to the branch and open a Pull Request.
5.  Ensure all Clarity tests pass.

---

## License

MIT License

Copyright (c) 2026 SyntheticRisk Protocol Authors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---
