[English overview](README.md) | [完整繁體中文研究](README.zh-TW.md)

# Save and load architecture and compatibility research

Research date: 14 October 2026. This is an English overview; the complete report and design examples are in Traditional Chinese.

Long-lived project files and game saves need a persistent data contract, explicit migrations and safe commits. Changing runtime classes should not silently change the meaning of stored data. Parsing an old file successfully does not establish that its behavior, assets or editing capabilities survive.

The public implementations illustrate complementary techniques:

- Blender embeds structure descriptions and uses versioning conversions. Compatibility still has documented limits. [DNA](https://developer.blender.org/docs/features/core/dna/), [compatibility policy](https://developer.blender.org/docs/handbook/guidelines/compatibility_handling_for_blend_files/).
- OpenTTD separates chunk loading, reference repair and post-load conversions. Its conversions also preserve historical settings and convert units. [Save/load interfaces](https://github.com/OpenTTD/OpenTTD/blob/master/src/saveload/saveload.h), [post-load implementation](https://github.com/OpenTTD/OpenTTD/blob/master/src/saveload/afterload.cpp).
- Unreal Engine transfers selected persistent state through custom SaveGame objects and provides asynchronous slot operations. Application-specific semantic migration remains a separate design responsibility. [Official guide](https://dev.epicgames.com/documentation/en-us/unreal-engine/saving-and-loading-your-game-in-unreal-engine).
- Protobuf and FlatBuffers support constrained schema evolution, while SQLite supplies transactions. None automatically migrates application semantics. [Protobuf](https://protobuf.dev/programming-guides/proto3/), [FlatBuffers](https://flatbuffers.dev/evolution/), [SQLite atomic commit](https://sqlite.org/atomiccommit.html).

A practical starting point is a versioned save model, stable object and content IDs, sequential migrations, validation before replacing the live state, safe file replacement or database transactions, and historical save fixtures in CI. Promise that the new application reads supported old files; define older-reader support and lossy export separately.

## Documents

| Document | Purpose |
| --- | --- |
| [Complete report](README.zh-TW.md) | Architecture, public implementations, format choices and compatibility boundaries |
| [Reference design](research/01-reference-design.zh-TW.md) | Save container, object graphs, migrations, safe commits and large-world loading |
| [Change scenarios and verification](research/02-change-scenarios-and-verification.zh-TW.md) | Feature changes, content migration, compatibility matrix and release checks |
| [Sources](research/03-sources.zh-TW.md) | Primary references, evidence boundaries and retrieval notes |

The examples are proposed designs and pseudocode, not implementations copied from those products or tested production code.
