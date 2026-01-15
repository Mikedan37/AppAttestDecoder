# Comparing Attestations from Different Sources

This example demonstrates comparing two attestations generated under different conditions.

## What This Example Shows

- How to use the diff command to compare two attestation artifacts
- What structural differences may appear between artifacts
- How to interpret differences without making trust claims

## What This Example Does Not Do

- Infer execution context or source of attestations
- Claim what differences mean or whether they're acceptable
- Make trust or policy decisions about the artifacts

**The tool does not know or care where an attestation came from. It only knows what the bytes contain.**

## Usage

```bash
# Compare two attestation artifacts
./diff.sh artifact1.b64 artifact2.b64
```

This will show structural differences between the two artifacts. Common differences you may see:

- Different credential IDs (each key has its own ID)
- Different sign counts (independent counters)
- Different certificate serial numbers (may differ)
- Same RP ID hash (if from same app family)
- Same team ID (if from same developer)

## Important Notes

**This is an example of comparison, not interpretation.**

- The tool shows what differs structurally
- You decide what those differences mean
- You decide if differences are acceptable for your use case
- The tool does not infer execution context or make trust claims

Any conclusions about what the differences mean are your responsibility, not the tool's.

## When to Use This Pattern

- Comparing attestations from different sources
- Analyzing structural differences between artifacts
- Debugging why two attestations look different
- Research into artifact variations

This example compares two artifacts. The tool does not infer why they differ or whether those differences are significant.
