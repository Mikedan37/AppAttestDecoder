# iOS Test App Documentation

> **⚠️ IMPORTANT:** This directory documents a **diagnostic iOS test application**.  
> It does not define production frontend behavior and must not be used as a security reference.  
> For cryptographic verification and backend responsibilities, see the root `README.md` and `../VERIFICATION_GUIDE.md`.

---

This directory contains documentation specific to the iOS test app (`AppAttestDecoderTestApp`), including frontend implementation contracts, setup guides, and troubleshooting.

## Core Contracts

- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - **START HERE**
  - Defines what the frontend is allowed to do and must never do
  - Specifies exact data sent to backend
  - Canonical request flow diagram
  - Frontend invariants checklist

- **`APP_ATTEST_E2E_CONTRACT.md`** (in parent directory)
  - End-to-end contract between iOS test app and backend
  - Flow, bindings, request/response specifications
  - Source of truth for protocol

## Implementation Guides

- **`FRONTEND_INVARIANTS_CHECKLIST.md`**
  - Checklist of frontend invariants
  - Verification status
  - Quick reference for compliance

- **`FRONTEND_VIOLATIONS_AND_FIXES.md`**
  - Documents violations found and fixes applied
  - Code change examples
  - Reference for maintaining compliance

- **`FRONTEND_VERIFICATION_CHECKLIST.md`**
  - Frontend verification checklist (if exists)

## Setup & Usage

- **`TEST_APP_GUIDE.md`**
  - Complete guide for using the iOS test app
  - Setup instructions
  - Generating attestations and assertions

- **`IOS_SANDBOX_SETUP.md`**
  - iOS sandbox configuration
  - Local network access setup
  - App Transport Security configuration

- **`IOS_INSPECTOR_SETUP.md`**
  - Inspector setup instructions

- **`IOS_ON_DEVICE_INSPECTION.md`**
  - On-device inspection guide

## Quick Reference

**For developers implementing the frontend:**
1. Read `FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md` first
2. Review `FRONTEND_INVARIANTS_CHECKLIST.md` before committing
3. Reference `FRONTEND_VIOLATIONS_AND_FIXES.md` if unsure about boundaries

**For setting up the test app:**
1. Start with `TEST_APP_GUIDE.md`
2. Configure sandbox per `IOS_SANDBOX_SETUP.md`
3. Use `IOS_INSPECTOR_SETUP.md` for inspection features

## Related Documentation

- **Parent directory:** `APP_ATTEST_E2E_CONTRACT.md` - E2E protocol contract
- **Parent directory:** `SIX_VALUES_PROCEDURE.md` - Debugging procedure
- **Parent directory:** `VERIFICATION_GUIDE.md` - Server-side verification
