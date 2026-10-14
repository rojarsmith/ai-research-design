# LOXJIE A40 USB audio fault research

Research date: 2026-10-14, Asia/Taipei. [Full Traditional Chinese report](README.zh-TW.md).

The user reports intermittent loud pops followed by persistent silence through stereo speakers, requiring an A40 power cycle. The cause remains unconfirmed.

Read-only inspection found XMOS driver 5.70.0.26310, a stored shared-mode format of 32-bit stereo at 384 kHz, and a USB path through a Generic USB Hub to an ASMedia controller. A separate USB port-reset failure belongs to an AMD controller path and is not evidence of an A40 failure.

First compare 48 kHz operation, then a different USB controller path, changing one variable at a time. If silence recurs, checking an independent input before power-cycling can distinguish a USB-specific failure from a wider amplifier fault. Use low volume because the reported fault involves sudden loud transients.

The report separates official documentation from first-person community reports. No verified official fix for this exact symptom was found. No settings or drivers were changed.

The reusable PowerShell collector is in `scripts/Collect-A40Evidence.ps1`; local raw evidence is excluded from Git. The observation template and source index are linked from the full report.
