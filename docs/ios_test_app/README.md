# iOS Test App Documentation

This directory contains documentation for the iOS test app (`AppAttestDecoderTestApp`), a diagnostic tool for learning and debugging App Attest implementations.

---

## Start Here

**`GUIDE.md`** - Complete guide covering:
- What the frontend is and is not
- How to understand and use the app
- Complete flow walkthrough
- Concrete examples
- Setup and usage
- Testing and verification
- Troubleshooting

Read `GUIDE.md` first for a complete understanding of the test app.

---

## Reference Documentation

### Core Contracts

- **`FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md`** - Detailed contract defining frontend boundaries and invariants
- **`../APP_ATTEST_E2E_CONTRACT.md`** - End-to-end protocol contract (source of truth)

### Implementation Reference

- **`FRONTEND_INVARIANTS_CHECKLIST.md`** - Checklist of frontend invariants
- **`FRONTEND_VIOLATIONS_AND_FIXES.md`** - Historical violations and fixes
- **`DATA_FLOW.md`** - Detailed data flow documentation

### Setup Guides

- **`IOS_SANDBOX_SETUP.md`** - Detailed sandbox configuration
- **`IOS_INSPECTOR_SETUP.md`** - Inspector setup instructions
- **`IOS_ON_DEVICE_INSPECTION.md`** - On-device inspection guide

### Testing

- **`FRONTEND_NON_AUTHORITY_TEST.md`** - Detailed test checklist with code references

### Backend Documentation

- **`../VERIFICATION_GUIDE.md`** - Server-side verification responsibilities
- **`../SIX_VALUES_PROCEDURE.md`** - Debugging procedure for verification failures

---

## Quick Reference

**For developers learning App Attest:**
1. Read `GUIDE.md` (complete guide)
2. Follow setup instructions in `GUIDE.md` Chapter 6
3. Review examples in `GUIDE.md` Chapter 5

**For developers implementing production frontends:**
1. Read `FRONTEND_APP_ATTEST_RESPONSIBILITY_CONTRACT.md` for detailed contract
2. Review `FRONTEND_INVARIANTS_CHECKLIST.md` for compliance
3. Reference `../APP_ATTEST_E2E_CONTRACT.md` for protocol specification
4. Do not copy test app code directly; use as reference only
