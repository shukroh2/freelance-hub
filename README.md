# Freelance Hub — Decentralized Freelance Marketplace (Clarity)

A simple Clarity smart contract implementing a decentralized freelance job marketplace with escrow and reputation tracking.

## Features
- Create jobs with on-chain escrowed STX deposits
- Apply for jobs and assign a freelancer
- Submit work and client approval to release payments
- Reputation tracking for clients and freelancers
- Read-only getters for jobs, reputation and totals

## Files
- contracts/freelance-hub.clar — main contract

## Quick usage
1. Deploy `freelance-hub.clar`.
2. Call `create-job(title, description, price)` as a client (escrows the price).
3. Freelancer calls `apply-for-job(job-id)` to accept.
4. Freelancer calls `submit-work(job-id)` after completing the job.
5. Client calls `approve-work(job-id)` to release payment and update reputation.
6. Client can call `refund-client(job-id)` to cancel before completion.

## Testing & development
- Add unit tests for edge cases: escrow transfers, authorization, race conditions.
- Run Clarity unit tests and local Stacks node to simulate STX transfers.
