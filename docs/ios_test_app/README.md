# iOS Test App Documentation

> **IMPORTANT:** This directory documents a **diagnostic iOS test application**.  
> It does not define production frontend behavior and must not be used as a security reference.  
> For cryptographic verification and backend responsibilities, see the root `README.md` and `../VERIFICATION_GUIDE.md`.

---

## Getting Started

**New to the test app?** Start here:

1. **`ROLE_OF_FRONTEND.md`** - Understand what the frontend does and never does
2. **`SETUP.md`** - Set up and run the app
3. **`EXAMPLES.md`** - See concrete examples of flows and behaviors
4. **`DATA_FLOW.md`** - Learn what data is produced and sent
5. **`TROUBLESHOOTING.md`** - Fix common issues

---

## Core Documentation

### Role and Responsibilities

- **`ROLE_OF_FRONTEND.md`** - **START HERE**
  - What the frontend does
  - What it never does
  - Why this distinction matters

- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`**
  - Detailed contract defining frontend boundaries
  - Exact data sent to backend
  - Canonical request flow diagram
  - Frontend invariants checklist

### Setup and Usage

- **`SETUP.md`**
  - Prerequisites and Apple Developer setup
  - Local network configuration
  - Backend configuration
  - Running the app

- **`DATA_FLOW.md`**
  - What data is produced
  - What data is sent to backend
  - Important notes about validation

- **`TROUBLESHOOTING.md`**
  - Network connectivity issues
  - App Attest capability problems
  - State consistency errors
  - Backend errors
  - UI issues

- **`EXAMPLES.md`**
  - Concrete examples: successful flow, failed response, repeated submission
  - What frontend produces, sends, displays
  - What frontend does not decide

- **`WHAT_THIS_TEST_APP_MEASURES.md`**
  - What the app can observe
  - What the app cannot prove
  - Measurement vs security

- **`FRONTEND_NON_AUTHORITY_TEST.md`**
  - Test checklist for frontend non-authority
  - Verification that frontend makes no security decisions
  - Can be reviewed without running the app

- **`FRONTEND_SUMMARY.md`**
  - Concise summary of frontend responsibilities vs non-responsibilities
  - Consistent wording reference
  - Key principles

---

## Additional Resources

### Implementation Reference

- **`FRONTEND_INVARIANTS_CHECKLIST.md`** - Checklist of frontend invariants
- **`FRONTEND_VIOLATIONS_AND_FIXES.md`** - Historical violations and fixes
- **`TEST_APP_GUIDE.md`** - Complete guide for using the test app
- **`IOS_SANDBOX_SETUP.md`** - Detailed sandbox configuration
- **`IOS_INSPECTOR_SETUP.md`** - Inspector setup instructions
- **`IOS_ON_DEVICE_INSPECTION.md`** - On-device inspection guide

### Protocol Contracts

- **`../APP_ATTEST_E2E_CONTRACT.md`** - End-to-end protocol contract (source of truth)
- **`../VERIFICATION_GUIDE.md`** - Server-side verification responsibilities
- **`../SIX_VALUES_PROCEDURE.md`** - Debugging procedure for verification failures

---

## Learning Path

**For developers learning App Attest:**

1. Read `ROLE_OF_FRONTEND.md` to understand boundaries
2. Follow `SETUP.md` to get the app running
3. Review `DATA_FLOW.md` to see what data flows through
4. Use `TROUBLESHOOTING.md` when issues arise

**For developers implementing production frontends:**

1. Read `FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md` for detailed contract
2. Review `FRONTEND_INVARIANTS_CHECKLIST.md` for compliance
3. Reference `../APP_ATTEST_E2E_CONTRACT.md` for protocol specification
4. Do not copy test app code directly; use as reference only
