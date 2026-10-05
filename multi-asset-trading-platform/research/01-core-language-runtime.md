**English** | [繁體中文](01-core-language-runtime.zh-TW.md)

# Core Programming Languages & Runtime

*Research dimension 01 · Status as of 2026-10-05 · Scope: stocks, crypto, bonds, options; US/global + Taiwan (TWSE/TAIFEX)*

## TL;DR

- **Recommended split: Rust core engine, Python strategy/research API, TypeScript front-end.** This is the same pattern NautilusTrader is moving to. v1.231.0 (2026-08-02) is intended to be its final Cython (v1) release, and the Rust + PyO3 v2 runtime is still in release candidates: 2.0.0rc6 is dated 2026-10-04 in the master-branch release notes, but the newest RC actually published on PyPI/GitHub tags as of 2026-10-05 is 2.0.0rc5 (2026-09-15). A plain `pip install nautilus_trader` still installs v1.231.0; v2 needs `--pre`.
- **For a solo MVP, the language question is mostly "Python plus a borrowed engine."** Write strategies in Python 3.14 (3.13 is now security-only) and use an existing Rust- or C#-cored engine. Build Rust components only after profiling shows a need. **C#/.NET 10 (LEAN-style)** is the strongest alternative core, especially for Windows-centric teams.
- **Never use binary float for prices, quantities or money in the order/accounting path.** Use per-instrument fixed-point integers: i64 for ≤9 decimals, i128 for ≤16–18 decimals. On-chain crypto amounts go in U256. float64 is for analytics and Greeks only.
- **Use one time type everywhere:** i64 UTC nanoseconds since the Unix epoch. .NET `DateTime` (100 ns ticks) and Python `datetime` (µs) silently lose precision. TAIFEX night sessions cross midnight, so "trading day ≠ calendar date."
- **Determinism comes from a single-threaded event-driven kernel**, with async I/O at the edges and simulated clocks in backtests. Free-threaded Python (supported in 3.14) is not a reason to multithread strategy logic.

## Key questions

1. Which language(s) for the **core engine** (event loop, order management system (OMS), risk, matching simulator, market-data normalization)?
2. Which language do **strategy authors** write in, and can the *same* strategy code run in backtest, paper and live?
3. What does crossing the **FFI boundary** cost, and how do we package it across Windows/macOS (Apple Silicon)/Linux on x86 and ARM?
4. How do we represent **prices/quantities** across asset classes with very different precision needs?
5. How do we handle **time**: nanosecond timestamps, time zones, sessions crossing midnight, exchange calendars?
6. Which **concurrency model** keeps backtests deterministic while live I/O stays responsive?

## Options compared

### 1. Language/runtime landscape (October 2026)

| Language | Current state (verified) | Memory / GC | Tail latency | Quant ecosystem | Cross-platform build & packaging | Hiring (SO 2025 usage, all respondents) |
|---|---|---|---|---|---|---|
| **Rust** | 1.99.0 (2026-10-01); 6-week cadence | Ownership, no GC; memory-safe by default | Excellent, predictable | Growing: NautilusTrader, hftbacktest, Polars, Arrow | `cargo` cross-targets; wheels via maturin; single static binaries | 14.8% |
| **C++** | C++26 technically complete March 2026 (reflection, contracts, `std::execution`), in ISO publication | Manual/RAII; unsafe by default (C++26 adds hardening) | Best attainable (HFT standard) | Deep (QuantLib, vendor SDKs, exchange APIs) | Hardest: CMake/vcpkg/Conan, ABI and toolchain matrix | 23.5% |
| **C# / .NET** | .NET 10 LTS (2025-11-11, supported to 2028-11-14 per the official support policy; latest patch 10.0.12); .NET 11 STS due Nov 2026 (RC1 go-live 2026-09-08) | Generational GC (DATAS, region-based); value types/`Span<T>` reduce allocation | Good; GC pauses tunable, NativeAOT available | LEAN (Apache-2.0), StockSharp, many broker SDKs | Very good: one SDK for win/mac/linux x64+arm64 | 27.8% |
| **Java / Kotlin (JVM)** | Java 25 LTS (Generational ZGC only); JDK 27 GA 2026-09-15 | ZGC: "sub-millisecond max pause times" | Good with ZGC + allocation discipline (Aeron/Chronicle style) | Strong in banks; weak retail-quant community | JVM portable; jlink/GraalVM native-image | 29.4% / Kotlin 10.8% |
| **Go** | 1.27.0 (2026-08-19), latest patch 1.27.1 (2026-09-01); Green Tea GC default since 1.26 (10–40% lower GC overhead) | Concurrent GC, low pauses | Good for gateways; less control than Rust | Thin (few quant/backtest libraries) | Trivial cross-compile, static binaries | 16.4% |
| **Python** | 3.14.8 current (2026-09-30; 3.14 is the only bugfix branch, 3.13 is security-only); 3.15.0 final slipped to 2026-10-09 (rc3 2026-10-02) | Refcount + cyclic GC; GIL (default) or free-threaded build | Poor in pure-Python hot loops | Unmatched (NumPy, pandas, Polars, SciPy, statsmodels, PyTorch) | Wheels per platform; native deps are the pain point | 57.9% (+7 pts YoY) |
| **Julia** | 1.13.1 (2026-09-25); LTS 1.10.12 | GC; JIT (LLVM) | Fast after warm-up; compile latency | Niche but good numerics | Shipping standalone binaries still immature | Not listed |

**Reading:** Rust and C++ are the only options with no GC on the hot path. Of those two, only Rust gives memory safety and painless cross-platform builds. C#/Java get within an order of magnitude with discipline, and their teams are larger and easier to hire. Python wins on strategy-author experience and research, and loses everywhere else.

### 2. Accelerating Python (when Python is the strategy language)

| Technique | State (2025-2026) | Good for | Caveats |
|---|---|---|---|
| **NumPy / Polars / Arrow vectorization** | Mature | Vectorized research, factor screens, bar-level backtests | Does not express path-dependent order logic |
| **Numba** | 0.63 (Dec 2025) added 3.14; 0.65 (Mar 2026) supports 3.14t free-threading; 0.68.0 (2026-09-30) adds Python 3.15 | Tight numeric loops, indicator kernels | Subset of Python; Intel SVML unsupported since 0.62 (still unsupported as of 0.65) |
| **Cython** | 3.1+ has free-threading support (experimental) | Legacy C-speed extensions | NautilusTrader abandoned it for PyO3; two-language debugging |
| **PyO3 + maturin (Rust)** | PyO3 0.29 (Jun 2026; latest 0.29.3, 2026-09-30): Python 3.15 support, new `abi3t` stable ABI covering free-threaded and GIL builds | Exposing a Rust core to Python | Every call crosses an ABI boundary; design coarse-grained APIs. `abi3t` (PEP 803) only targets CPython 3.15+, so 3.14t still needs per-version `cp314t` wheels |
| **mypyc** | Maintained with mypy | Compiling typed pure-Python modules (moderate speed-ups) | Limited gains on numeric code |
| **Free-threaded CPython** | Supported (PEP 779) in 3.14. Single-thread overhead about 1% (macOS arm64) to 8% (x86-64 Linux). Importing a non-FT C extension re-enables the GIL (CPython prints a warning) | Parallel CPU work in research (parameter sweeps) | Not default. Larger object headers. Thread nondeterminism is poison for backtests |
| **CPython JIT** | Experimental; 3.15 reports ~7–8% (x86-64 Linux), ~11–12% (macOS arm64) | Free speed-up | Not a substitute for native code |

### 3. Hybrid architecture patterns (the real decision)

| Pattern | Reference implementation | Strategy language | Backtest/live parity | FFI cost profile | Packaging | Best for |
|---|---|---|---|---|---|---|
| **A. Pure Python engine** (+Numba/Polars) | Custom; many retail frameworks | Python | High (same process) | None inside Python; slow per-event | Easiest | Daily/swing strategies, research-first MVP |
| **B. Rust core + Python API (PyO3)** | NautilusTrader v2 (LGPL-3.0-only; v1.x was LGPL-3.0-or-later; Python 3.12–3.14; Linux x64/arm64, macOS arm64, Windows x64) | Python or Rust | Very high: same strategy code in backtest and live by design | Low per call; data stays in Rust; Python callbacks per event | Wheels via maturin; CI matrix needed | Intraday multi-asset, crypto, a long-term platform |
| **C. C# core + Python/C# (pythonnet)** | QuantConnect LEAN (Apache-2.0; .NET 10 SDK; Python 3.11 via QC's pythonnet fork) | C# or Python | Very high | Heavier marshalling; Python algos generally slower than C# | Docker/`lean` CLI; .NET runtime | .NET shops, broad asset coverage out of the box |
| **D. C++ core + Python (pybind11/nanobind)** | Proprietary HFT stacks | C++ (hot), Python (research) | Medium (often two codebases) | Lowest, but unsafe | Hardest | Co-located HFT, sub-10 µs paths |
| **E. JVM core + Python over IPC** | Bank/exchange stacks (Aeron, Chronicle) | Java/Kotlin | Medium | IPC (gRPC/Arrow Flight), not in-process | Easy (JVM), Python separate | Teams with existing JVM infra |
| **F. Go services + Python strategies over IPC** | Crypto exchange/gateway infra | Python | Medium-low | IPC per message | Easy | Gateways/connectors around another core |

## Numeric representation (prices, quantities, money)

| Representation | Precision / range | Speed | Determinism | Verdict |
|---|---|---|---|---|
| **float64 (IEEE 754)** | ~15–17 significant digits | Fastest, SIMD | Results depend on operation order; `0.1+0.2≠0.3` | Analytics, signals, Greeks, risk models only |
| **Decimal128-style** (.NET `decimal`: 96-bit integer + scale 0–28, ±7.9×10²⁸; `rust_decimal` 1.43 same layout; Java `BigDecimal` arbitrary; Python `decimal` via libmpdec) | 28–29 digits (BigDecimal unbounded) | Typically several times slower than integer math; BigDecimal/Python allocate per op | Deterministic | Accounting, settlement, reporting, config/limits |
| **Fixed-point i64** (scaled integer, per-instrument precision) | NautilusTrader standard mode: 9 decimals, ±~9.2 billion | Integer speed, no allocation | Exact | Default for most equities/futures/options |
| **Fixed-point i128** | NautilusTrader high-precision mode: 16 decimals, `PRICE_MAX` ±~17 trillion (17,014,118,346,046); ~3–5% slower than 64-bit; default in official v2 wheels on all platforms (v1.x Windows wheels were 64-bit only) | Near-integer speed (software-emulated on some targets) | Exact | Crypto CEX, FX, multi-asset default |
| **U256 / smallest-unit integer** | ERC-20 balances are `uint256`; `decimals` is token-defined (commonly 18) | Slowest | Exact | On-chain/DeFi amounts only; convert at the adapter |

**How the asset classes differ:**

- **Stocks.** US quotes under $1 trade in sub-penny increments, while share prices reach six figures. **Taiwan stocks** use tiered tick sizes (NT$0.01–NT$5 by price band), ±10% daily limits, and intraday odd-lot trading (盤中零股). i64 with 4–6 decimals is ample. The hard part is the tick-size table, not precision.
- **Crypto.** CEX quantities are typically ≤8–10 decimals, which i128/16-decimal covers. On-chain amounts need 18 decimals × large integers. 1 wei (1e-18) is *not* representable in a 16-decimal type, so keep raw `uint256` integers at the DeFi boundary.
- **Bonds.** US Treasuries are quoted "in thirty-seconds" (e.g., 99-16+ = 99 + 16.5/32), with finer fractions down to 1/256. These are **dyadic** fractions: 1/256 = 0.00390625 is exact in binary float and needs 8 decimal places in fixed-point. Store a decimal fixed-point price plus a display/parse codec for 32nds. Accrued interest and day-count conventions belong in a Decimal-based library, not the hot path.
- **Options.** Premiums are small with tiered ticks (TAIFEX TXO: 0.1 pt below 10 up to 10 pts at ≥1,000; multiplier NT$50/pt). Contract multipliers make notional large. Greeks, implied vol and pricing models are inherently float64. Keep the **order/fill/PnL path fixed-point** and the **model path float**, and convert explicitly.

**Language implications:** Rust and C++ get fixed-point and i128 at native cost. .NET has a fast built-in `decimal` and `Int128` (since .NET 7). Java's `BigDecimal` allocates on every operation, so low-latency Java uses scaled `long`. Go has no built-in decimal and relies on third-party libraries. Python `int` is arbitrary-precision but slow per object. Do Python-side money math in the Rust core, or in vectorized int64 arrays.

## Time handling

| Language | Native instant resolution | Pitfall | Recommendation |
|---|---|---|---|
| Rust | `std` Duration ns; ecosystem `chrono`, `jiff` (0.2.x, 1.0 slipped past 2025; embeds tzdb on Windows) | Two competing tz crates | `u64` UnixNanos newtype; tz only at display/calendar edge |
| C++ | `std::chrono` ns; C++20 tz | Platform tzdb availability on Windows/older libc | int64 ns |
| C# / .NET | `DateTime` ticks = **100 ns** | Truncates exchange ns timestamps (CME, crypto feeds with ns) | Carry `long` ns alongside; `DateTimeOffset` only for display |
| Java | `Instant` = long seconds + int nanos | Allocation per `Instant` | Primitive `long` ns on hot path |
| Go | `time.Time` ns | Monotonic vs wall clock mixing | int64 ns |
| Python | `datetime` resolution is **1 µs** | Silent truncation; pandas `datetime64[ns]` limited to years 1677–2262; pandas 3.0+ infers `datetime64[us]` from strings/`datetime` objects, so `.astype("int64")` yields µs, not ns | int64 ns in Arrow/Polars/NumPy; pass `unit="ns"` explicitly in pandas; `zoneinfo` for tz |

**Calendars:** `exchange_calendars` covers 50+ exchanges, including **XTAI** (TWSE), but **no TAIFEX** calendar. **TAIFEX after-hours sessions run 15:00 to 05:00 the next day** (TX), so a fill at 01:00 Taipei time belongs to the *next* trading day's settlement. Taiwan is UTC+8 with no DST, while US/EU markets shift with DST. Crypto trades 24/7 with UTC-day conventions. Bonds add settlement calendars (T+1) and day counts. Rule: **store UTC ns; derive `trading_date`/`session_id` through a calendar service**, never from the wall-clock date.

## Concurrency model and deterministic backtests

| Model | Determinism | Live responsiveness | Used by |
|---|---|---|---|
| **Single-threaded event loop kernel + async I/O threads** | High (one ordered event queue, simulated clock) | Good: network/serialization off-thread (e.g., tokio) | NautilusTrader ("single-threaded kernel"), LEAN |
| **Actor model** (message-passing per component) | High if mailbox ordering and timestamps are deterministic | Excellent; scales across cores and nodes | Akka/Orleans-style, custom Rust actors |
| **Shared-memory multithreading** | Low (scheduler-dependent interleavings) | High throughput | Research sweeps, not the engine |
| **async/await everywhere** | Medium (executor scheduling order leaks into results) | Good | Connectors/gateways |

**Determinism rules:**

- Use a simulated clock and never call wall-clock time in strategy code.
- Break timestamp ties with a stable sequence number.
- Seed every RNG.
- Avoid iterating hash maps with randomized order (Rust's default `HashMap`, Python sets of objects).
- Make float reductions order-independent.
- Parallelize *across* backtests (parameter sweeps, walk-forward folds), never *within* one.

## Recommendations

### Scenario (a): solo / 1–3 person MVP

1. **Strategy and research language: Python 3.14 (standard GIL build).** The key wheels (NumPy, Polars, Numba, NautilusTrader) already ship for 3.14, and 3.13 entered security-only status (no more binary releases) in October 2026. Treat 3.15 (final due 2026-10-09) as a 2027 upgrade.
2. **Do not write an engine core yet. Adopt one:**
   - **NautilusTrader v2** (Rust core, Python strategies) is the best fit for crypto plus intraday multi-asset. Track the RC-to-2.0 transition (install with `--pre` until 2.0 final), and check that the LGPL-3.0-only terms fit if you ever distribute the software.
   - **LEAN** (C#, Apache-2.0) is the best fit if you value broad equity/options/futures data integration and a C#-friendly path. Choosing it pins your strategy environment to Python 3.11, which is security-only and reaches end of life in October 2027.
   - **Bonds are a gap in both.** LEAN has no bond security type. NautilusTrader has a `Bond` instrument class but no yield, accrued-interest or day-count analytics. Plan a separate fixed-income pricing library (for example QuantLib) behind the engine.
3. **Research stack:** Polars/NumPy plus Numba for kernels. Store all prices as int64 fixed-point and timestamps as int64 UTC ns from day one, so data can later move into a Rust core unchanged.
4. **Taiwan connectivity:** the broker SDK language decides here.
   - Shioaji has a native Python binding, with an HTTP API for other languages.
   - Fubon Neo offers Python/C#/Node.js SDKs (C++/Go for trading) on Windows/macOS/Linux.
   - Wrap each broker in a thin adapter process if its SDK conflicts with your runtime.
5. **Front-end: TypeScript** (React), shipped as a web app plus a **Tauri 2** desktop/mobile shell (Rust backend, JS front-end; Windows/macOS/Linux/iOS/Android). Tauri 2.12.x is current and 3.0 is in alpha (3.0.0-alpha.4), so expect a major-version migration later. If mobile is the priority, React Native (still TypeScript) or Flutter are the main alternatives; with a .NET core, Avalonia or .NET MAUI are the C# options.

### Scenario (b): 5–20 person team / institutional grade

1. **Core engine: Rust.** This covers the event kernel, OMS, risk checks, matching/fill simulator, market-data normalization and persistence writers. Memory safety without GC and painless cross-compilation outweigh C++'s marginal latency edge for anything above co-location.
2. **Strategy API: Python via PyO3** (coarse-grained, Arrow-backed). Offer an optional **Rust-native strategy trait** for latency-sensitive strategies, with identical event semantics in backtest and live.
3. **Valid alternative core: C#/.NET 10 LTS.** Choose it if the team is .NET-heavy or must integrate Windows-only broker components. Python stays the strategy language via pythonnet, accepting slower Python-strategy execution.
4. **C++ only where forced:** vendor SDKs, FPGA/kernel-bypass co-location (<10 µs). **Go/JVM** are reasonable for peripheral services (API gateway, admin, reporting), not the deterministic core.
5. **Front-end: TypeScript** across web, desktop (Tauri) and mobile. Generate shared DTO types from one schema (Protobuf/FlatBuffers/JSON Schema) to keep Rust, Python and TS in sync.

**Recommended combination:** **Core = Rust · Strategy = Python (+ optional Rust) · Front-end = TypeScript.** Fallback: **Core = C#/.NET 10 · Strategy = Python/C# · Front-end = TypeScript.**

**Latency tiers:**

| Strategy holding period / latency need | Acceptable core | Comment |
|---|---|---|
| Daily–weekly (most stocks, bonds, Taiwan retail) | Python-only is fine | Broker API round-trips (tens to hundreds of ms) dominate |
| Intraday, 1–100 ms (crypto WebSocket, futures/options) | Rust / C# / Java core, Python strategies | This is the target design |
| Sub-100 µs (market making, co-location) | Rust/C++, Rust-native strategies | Out of reach via retail brokers, including Taiwan retail APIs |

## Impact on overall architecture

- **Canonical domain model in the core language.** Instruments carry `price_precision`, `size_precision`, tick tables, multiplier and calendar ID. Python/TS bindings are generated, not hand-written.
- **Numeric contract.** Fixed-point (i64/i128) on the wire, in storage (Parquet int columns plus a precision field) and in the OMS. Decimal at accounting/reporting edges, float64 inside models. Conversions are explicit and tested.
- **Time contract.** UTC i64 ns in every event (`ts_event`, `ts_init`). A calendar/session service maps timestamps to trading date and session, including the TAIFEX night session.
- **Process topology.** One single-threaded trading node per strategy group, with async I/O threads and horizontal scale-out by running more nodes. This shapes the deployment, messaging and risk-aggregation dimensions.
- **Data interchange.** Apache Arrow between Rust and Python for zero-copy batches. Avoid per-tick Python object creation in backtests.
- **Build/CI.** A wheel matrix (win-x64, macOS-arm64, linux-x64/arm64; per-version or abi3 wheels for GIL builds; `abi3t` covers free-threaded builds only from CPython 3.15, so 3.14t needs `cp314t` wheels), reproducible toolchains (`rust-toolchain.toml`, `uv`/lockfiles) and a .NET/Node toolchain only if chosen.
- **Adapters as separate processes when language-incompatible.** Use gRPC/ZeroMQ to isolate Windows-only or Python-only broker SDKs from the core.

## Risks & pitfalls

- **Engine maturity:** NautilusTrader 2.0 is still a release candidate (rc6 dated 2026-10-04 in the release notes; rc5 of 2026-09-15 is the newest on PyPI as of 2026-10-05), and v1 gets only about three months of critical security backports after the v2 cutover. API churn is likely through 2.0 final.
- **Python version churn:** LEAN pins Python 3.11 (security-only, end of life 2027-10), NautilusTrader supports 3.12–3.14, and 3.15 lands 2026-10-09. A single research environment may not satisfy all of them, so isolate with per-project environments.
- **Free-threaded traps:** a single non-FT C extension re-enables the GIL. CPython only prints a warning, which is easy to miss in service logs. The FT build uses more memory (e.g., `None` is 32 vs 16 bytes on AMD64). Threads introduce nondeterminism.
- **Silent precision loss:** float accumulation in PnL and fees, .NET `DateTime` 100 ns truncation, Python `datetime` µs truncation, pandas 3.x defaulting to `datetime64[us]`, and 16-decimal fixed-point vs 18-decimal tokens.
- **FFI chattiness:** calling into Python per tick across millions of events dominates runtime. Batch events, or move indicators into the core.
- **Hiring and bus factor:** Rust users are about a quarter as common as Python users (14.8% vs 57.9%). Keep the Rust surface small and well-documented, and let most contributors work in Python/TS.
- **Packaging:** Apple Silicon and Windows ARM builds, glibc minimums (NautilusTrader needs glibc 2.35+) and native-dependency wheels are recurring costs. Budget CI for them.
- **Licensing:** LGPL-3.0-only (NautilusTrader v2) vs Apache-2.0 (LEAN) matters if you later offer the system as a distributed product. Running it as a hosted SaaS has different obligations, so confirm with counsel.
- **Calendar gaps:** there is no off-the-shelf TAIFEX calendar in `exchange_calendars`. Taiwan typhoon closures (颱風假) are ad hoc announcements that require a manual-override path.

## References

- NautilusTrader PyPI (versions, Python/platform support, precision modes, LGPL): https://pypi.org/project/nautilus-trader/
- NautilusTrader release notes (2.0.0rc6, 2026-10-04): https://raw.githubusercontent.com/nautechsystems/nautilus_trader/master/RELEASES.md
- NautilusTrader v1.231.0, final Cython release: https://newreleases.io/project/github/nautechsystems/nautilus_trader/release/v1.231.0
- NautilusTrader installation/precision docs: https://nautilustrader.io/docs/latest/getting_started/installation/
- NautilusTrader concepts overview: https://nautilustrader.io/docs/latest/concepts/overview/
- QuantConnect LEAN repository: https://github.com/QuantConnect/Lean
- LEAN Python setup (Python 3.11, pythonnet): https://github.com/QuantConnect/Lean/blob/master/Algorithm.Python/readme.md
- QuantConnect.pythonnet NuGet (2.0.66 referenced by LEAN master): https://www.nuget.org/packages/QuantConnect.pythonnet/
- LEAN `SecurityType` enum (no bond type): https://github.com/QuantConnect/Lean/blob/master/Common/Global.cs
- NautilusTrader PyPI release history (latest published RC): https://pypi.org/project/nautilus-trader/#history
- NautilusTrader v2 `pyproject.toml` (license `LGPL-3.0-only`): https://github.com/nautechsystems/nautilus_trader/blob/master/python/pyproject.toml
- NautilusTrader `Price` limits (`PRICE_MAX`): https://github.com/nautechsystems/nautilus_trader/blob/master/crates/model/src/types/price.rs
- Python downloads / release status: https://www.python.org/downloads/
- Python devguide, supported versions (3.13 security-only): https://devguide.python.org/versions/
- PEP 803 (`abi3t`, CPython 3.15+): https://peps.python.org/pep-0803/
- pandas 3.0 release notes (datetime resolution inference): https://pandas.pydata.org/docs/whatsnew/v3.0.0.html
- Python 3.15.0 rc3 announcement: https://blog.python.org/2026/10/python-3150-rc3/
- Python free-threading HOWTO (3.14): https://docs.python.org/3.14/howto/free-threading-python.html
- PEP 779 explainer: https://pydevtools.com/handbook/explanation/what-is-pep-779/
- Free-threading compatibility tracker: https://py-free-threading.github.io/tracking/
- Python `datetime` docs: https://docs.python.org/3/library/datetime.html
- PyO3 releases (0.29): https://github.com/PyO3/pyo3/releases
- Numba 0.65.0 release notes: https://numba.readthedocs.io/en/latest/release/0.65.0-notes.html
- Numba 0.63.0 release notes: https://numba.readthedocs.io/en/stable/release/0.63.0-notes.html
- Numba 0.68.0 release notes (Python 3.15): https://numba.readthedocs.io/en/stable/release/0.68.0-notes.html
- Cython free-threading guide: https://cython.readthedocs.io/en/latest/src/userguide/freethreading.html
- Rust blog (1.99.0): https://blog.rust-lang.org/
- `rust_decimal` docs: https://docs.rs/rust_decimal/latest/rust_decimal/
- Jiff: https://github.com/BurntSushi/jiff
- Herb Sutter, "C++26 is done!": https://herbsutter.com/
- .NET 10 announcement: https://devblogs.microsoft.com/dotnet/announcing-dotnet-10/
- .NET support policy (end-of-support dates): https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core
- .NET 11 RC1 news: https://visualstudiomagazine.com/articles/2026/09/14/net-11-rc1-gets-go-live-support-ahead-of-november-launch.aspx
- .NET `DateTime.Ticks`: https://learn.microsoft.com/en-us/dotnet/api/system.datetime.ticks
- .NET `Decimal`: https://learn.microsoft.com/en-us/dotnet/api/system.decimal
- Oracle Java 27 press release: https://www.oracle.com/sg/news/announcement/oracle-releases-java-27-and-strengthens-post-quantum-cryptography-support-2026-09-15/
- OpenJDK ZGC: https://openjdk.org/projects/zgc/
- Java `Instant`: https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/time/Instant.html
- Go 1.26 release notes (Green Tea GC): https://go.dev/doc/go1.26
- Go 1.27 release notes: https://go.dev/doc/go1.27
- Go release history: https://go.dev/doc/devel/release
- Julia downloads: https://julialang.org/downloads/manual-downloads/
- Stack Overflow Developer Survey 2025, technology: https://survey.stackoverflow.co/2025/technology
- hftbacktest: https://github.com/nkaz001/hftbacktest
- `exchange_calendars`: https://github.com/gerrymanoim/exchange_calendars
- TAIFEX TX specs: https://www.taifex.com.tw/enl/eng2/tX
- TAIFEX TXO specs: https://www.taifex.com.tw/enl/eng2/tXO
- TWSE trading mechanics: https://www.twse.com.tw/en/page/products/trading/introduce.html
- Shioaji docs: https://sinotrade.github.io/
- Fubon Neo API: https://www.fbs.com.tw/TradeAPI/en/
- EIP-20 (ERC-20): https://eips.ethereum.org/EIPS/eip-20
- US Treasury security (32nds quoting): https://en.wikipedia.org/wiki/United_States_Treasury_security
- Tauri 2: https://v2.tauri.app/
- `tauri` crate versions (2.12.1 stable, 3.0.0-alpha.4): https://crates.io/crates/tauri

## Verification log (2026-10)

Adversarial fact-check run on 2026-10-05 against primary sources: official docs, PyPI/crates.io/NuGet metadata, GitHub repository files, and release pages. 51 statements checked: 34 confirmed, 14 corrected or supplemented, 3 unverifiable.

### Confirmed

- NautilusTrader v1.231.0 (2026-08-02) is intended as the final 1.x/Cython release. `develop` moves to v2-only, and `develop_v1` takes critical security backports for about three months after the cutover (newreleases.io release notes; PyPI upload 2026-08-02).
- NautilusTrader supports Python 3.12–3.14 on Linux x86_64/ARM64, macOS ARM64 and Windows x86_64. It offers 128-bit (16 decimals) and 64-bit (9 decimals) precision modes. Standard mode is about 3–5% faster, `PRICE_MAX` is about ±9.2 billion in standard mode, and Linux needs glibc 2.35+ (PyPI, README, installation docs, `price.rs`).
- The NautilusTrader kernel event loop runs on the calling thread, with async I/O on a Tokio runtime (concepts overview).
- LEAN is Apache-2.0, targets `net10.0` (.NET 10 SDK), and runs Python 3.11 via QuantConnect's pythonnet fork (README, `QuantConnect.csproj`, `DockerfileLeanFoundation`, Algorithm.Python readme).
- Python 3.15.0rc3 shipped 2026-10-02, and the final release was moved to 2026-10-09 because of lazy-import release blockers. 3.14.8 (2026-09-30) is current (blog.python.org, python.org).
- The JIT speed-up in 3.15 is about 7–8% on x86-64 Linux and 11–12% on AArch64 macOS (3.15.0rc3 announcement).
- Free-threading is officially supported but optional in 3.14 (PEP 779, Final). Overhead is about 1% on macOS aarch64 to 8% on x86-64 Linux, a non-FT C extension re-enables the GIL, and `None` takes 32 vs 16 bytes on AMD64 (free-threading HOWTO).
- PyO3 0.29.0 (2026-06-11) adds Python 3.15 and `abi3t` (GitHub releases, crates.io).
- Numba 0.63.0 (2025-12-08) added 3.14, and 0.65.0 (2026-03-31) added 3.14t. SVML was still unsupported in 0.65 (release notes).
- Cython free-threading support is still experimental (Cython docs).
- Rust 1.99.0 was released 2026-10-01 (Rust blog).
- .NET 10 was released 2025-11-11 as an LTS release (announcement). .NET 11 RC1 went live 2026-09-08 (.NET releases index).
- `System.Int128` has existed since .NET 7 (Microsoft Learn).
- Go 1.26 made Green Tea GC the default, with a 10–40% expected GC-overhead reduction. Go 1.27.0 was released 2026-08-19 (go.dev).
- A .NET `DateTime` tick is 100 ns (Microsoft Learn).
- C++26 was technically complete on 2026-03-29 and is in its DIS ballot (herbsutter.com).
- JEP 490 removed non-generational ZGC in JDK 24, so Java 25 LTS is generational-only. JDK 27 reached GA on 2026-09-15. ZGC claims "sub-millisecond max pause times" (openjdk.org).
- Julia 1.13.1 was released 2026-09-25, and the LTS is 1.10.12 (julialang.org).
- Stack Overflow 2025 usage among all respondents: Python 57.9% (+7 points), Rust 14.8%, C# 27.8%, C++ 23.5%, Java 29.4%, Kotlin 10.8%, Go 16.4% (survey page).
- Current crate versions: `rust_decimal` 1.43.0 (2026-09-02) and `jiff` 0.2.37, still pre-1.0 (crates.io).
- `exchange_calendars` covers 50+ exchanges and includes XTAI, with no TAIFEX calendar (GitHub README).
- TAIFEX TX after-hours session runs 15:00–05:00 the next day. TXO uses a NT$50 multiplier with ticks from 0.1 pt (below 10) to 10 pts (1,000 and above) (TAIFEX spec pages).
- TWSE: ±10% daily limit, tiered ticks, and intraday odd-lot trading (TWSE trading mechanics).
- Shioaji offers a native Python binding plus an HTTP API for other languages (and a CLI). Fubon Neo offers Python/C#/Node.js SDKs, plus C++/Go for trading, on Windows/macOS/Linux (vendor docs).
- Tauri 2 targets Linux, macOS, Windows, Android and iOS (v2.tauri.app).

### Corrected or supplemented

| Original | Correction | Source |
|---|---|---|
| "Latest release is 2.0.0rc6 (2026-10-04)"; NautilusTrader "has now fully adopted" v2 | rc6 is dated 2026-10-04 in master `RELEASES.md`/`version.json`, but as of 2026-10-05 the newest RC on PyPI and GitHub tags is 2.0.0rc5 (2026-09-15). The Nautech package index has only `2.0.0rc6.devYYYYMMDD` development wheels. The latest stable on PyPI is still 1.231.0, so v2 needs `--pre` | https://pypi.org/project/nautilus-trader/#history ; https://github.com/nautechsystems/nautilus_trader/tags |
| NautilusTrader "LGPL-3.0-or-later" | That applies to v1.x only. v2 (`python/pyproject.toml`, `Cargo.toml`, rc5 PyPI metadata) declares `LGPL-3.0-only` | https://github.com/nautechsystems/nautilus_trader/blob/master/python/pyproject.toml |
| .NET 10 "supported until 2028-11-10" | The official support policy and `releases-index.json` give end of support as **2028-11-14** (Patch Tuesday). The announcement blog's "November 10, 2028" disagrees with the policy | https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core |
| i128 mode "±~17 quadrillion", "default in official wheels" | `PRICE_MAX` = 17,014,118,346,046, i.e. **±~17 trillion**. 128-bit is the default in v2 wheels on all platforms, but v1.x Windows wheels were 64-bit only | `crates/model/src/types/price.rs`; NautilusTrader README / PyPI |
| A non-FT C extension "silently" re-enables the GIL | CPython prints a warning when this happens | https://docs.python.org/3.14/howto/free-threading-python.html |
| Use "Python 3.13/3.14"; "pin 3.14 once key wheels are available" | 3.13 is now security-only (no more binaries), and the key wheels already support 3.14. Recommend 3.14 | https://devguide.python.org/versions/ |
| LEAN pins Python 3.11 (no lifecycle context) | 3.11 is security-only with end of life in 2027-10, a medium-term risk for LEAN users | https://devguide.python.org/versions/ |
| Numba: newest cited is 0.65 | Latest is 0.68.0 (2026-09-30), which adds Python 3.15 | https://numba.readthedocs.io/en/stable/release/0.68.0-notes.html |
| CI: "abi3t for free-threaded" | `abi3t` (PEP 803) can only target CPython 3.15+. 3.14t needs per-version `cp314t` wheels | https://peps.python.org/pep-0803/ |
| QuantConnect.pythonnet NuGet 2.0.64 | LEAN master references 2.0.66 | `Common/QuantConnect.csproj`; NuGet |
| Python time pitfalls listed only µs `datetime` and the ns range | pandas 3.0+ infers `datetime64[us]` from strings/`datetime`, so integer conversion yields µs (1000× smaller). Use `unit="ns"` explicitly | https://pandas.pydata.org/docs/whatsnew/v3.0.0.html |
| Engines recommended for multi-asset including bonds, with no caveat | LEAN has no bond `SecurityType`. NautilusTrader has a `Bond` instrument class but no fixed-income analytics. Added a note to plan a separate pricing library | `Common/Global.cs` (LEAN); `crates/model/src/enums.rs` (NautilusTrader) |
| Go "1.27.0" as the current state | Latest patch is 1.27.1 (2026-09-01) | https://go.dev/doc/devel/release |
| Tauri 2 recommended, no alternatives | Tauri 2.12.1 is current and 3.0.0-alpha.4 exists (a future major migration). Added a short note on React Native/Flutter (mobile) and Avalonia/.NET MAUI (if the core is .NET) | https://crates.io/crates/tauri |

### Unverifiable

- The exact TAIFEX rule that after-hours fills are attributed to the *next* trading day's clearing. The spec pages confirm only the 15:00–05:00 hours, and the rule should be checked against TAIFEX trading rules before the calendar service is implemented.
- Whether Intel SVML is still unsupported in Numba 0.66–0.68. The 0.68.0 notes do not mention it, and it is confirmed only through 0.65.
- "Julia: Not listed" in the Stack Overflow 2025 language table. The page shows Julia only among write-ins, with no comparable percentage.
