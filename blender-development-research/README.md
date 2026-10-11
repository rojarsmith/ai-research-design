[**English overview**](README.md) | [完整繁體中文報告](README.zh-TW.md)

# How Blender developed into a mature production tool

Research date: 11 October 2026. This is an English overview; the complete report and supporting research are in Traditional Chinese.

Blender began as an internal tool for the animation studio NeoGeo. Ton Roosendaal's retrospective dates the first running version to 2 January 1994 and says it took approximately 15 months to become usable for internal production. That milestone describes a much narrower tool than today's application. [Founder retrospective](https://www.blender.org/press/blenders-25th-birthday/)

Its subsequent development combined several mechanisms:

- **Continuity through open source.** After Not a Number closed in 2002, community fundraising enabled Blender's GPL release on 13 October. [Historical record](https://archive.blender.org/www/blenderorg/blender-foundation/history/index.html)
- **Development driven by production.** Open movies exposed problems across animation, rendering and compositing, while sharing production assets and knowledge. [Open projects](https://archive.blender.org/www/features-gallery/blender-open-projects/index.html)
- **Repeated architectural work.** Blender 2.5 rebuilt event, tool and scripting systems; 2.80 changed the interface and introduced EEVEE; Cycles X revisited rendering architecture. [2.57 announcement](https://www.blender.org/press/blender-257-release/), [2.80](https://www.blender.org/download/releases/2-80/), [Cycles X](https://code.blender.org/2021/04/cycles-x/)
- **Sustained maintenance.** Funded developers, module ownership, release stabilization and two-year LTS support provide a continuing engineering process. [Development Fund](https://fund.blender.org/about/), [release cycle](https://developer.blender.org/docs/handbook/release_process/release_cycle/)

Commercial readiness is supported by actual productions, including *Flow*. Its director describes using Blender and managing version changes during production; the Academy independently records its 2025 Animated Feature Film award. This supports production capability, rather than universal superiority over other software. [Director interview](https://www.blender.org/user-stories/making-flow-an-interview-with-director-gints-zilbalodis/), [Academy record](https://www.oscars.org/oscars/ceremonies/2025)

At the research date, the official Blender 5.2 LTS page lists release 5.2.2 dated 15 September 2026 and support through July 2028. [Official release page](https://www.blender.org/releases/5-2/)

## Documents

| Document | Purpose |
| --- | --- |
| [Complete report](README.zh-TW.md) | History, technical transitions, funding, production evidence and limits |
| [Engineering and production](research/01-engineering-and-production.zh-TW.md) | Data architecture, extensibility, team workflows and quality controls |
| [Sources and evidence](research/02-sources-and-evidence.zh-TW.md) | References, claim boundaries and historical ambiguities |
| [Building a large 3D application](research/03-build-large-3d-software.zh-TW.md) | C++ architecture, ownership, commands, undo, evaluation, rendering, files and concurrency |
| [C++ learning roadmap](research/04-cpp-learning-roadmap.zh-TW.md) | Incremental editor milestones with acceptance conditions |
| [Reading Blender source](research/05-reading-blender-source.zh-TW.md) | Follow an operation through a fixed Blender version |
| [Runnable C++ core](examples/mini-editor-core/README.zh-TW.md) | Standard-library example with shared meshes, commands, history, serialization and workflow tests |
