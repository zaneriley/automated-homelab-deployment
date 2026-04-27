# diagnostics

Steady-state pre-incident tooling for fleet hosts. Packages are installed
during a routine apply so they are already present when the next hang or
hardware event occurs — not fetched over a possibly-degraded network during
one. This is not emergency-response tooling; it is the baseline that makes
post-incident analysis tractable. Implements the H6 finding (Brendan Gregg,
"Linux Crisis Tools" — `p208-brendan-gregg-crisis-tools.md` in the
device-health brief) plus H2 (rasdaemon). Debian/Ubuntu only today
(`tasks/Debian.yml`); dispatcher in `tasks/main.yml` will route other OS
families when added.

**Load-bearing packages** (`defaults/main.yml :: diagnostics_packages`):

- `sysstat` — sa1/sar 10-minute historical CPU/mem/IO/network. Without
  this enabled, post-incident analysis collapses to live state at moment-
  of-hang (p208 §4). Role flips `/etc/default/sysstat` to `ENABLED="true"`
  and enables the unit.
- `bpftrace`, `bpfcc-tools` — eBPF live tracing (`opensnoop`,
  `execsnoop`, `biosnoop`, `runqlat`).
- `linux-tools-common` + `linux-tools-generic` — `perf` tracking the
  active kernel ABI (preferred over the host-pinned `linux-tools-$(uname
  -r)` per p208).
- `trace-cmd` — ftrace frontend.
- `iotop`, `htop`, `iftop`, `strace`, `ltrace`, `tcpdump` — interactive
  triage + syscall/packet capture.
- `rasdaemon` — DRAM/PCIe/CPU MCE error daemon. Replaces deprecated
  `mcelog` (H2 brief — p123).

**Gate.** `diagnostics_enabled` (default `true`). Role is *not* added
to `site.yml` — opt-in per inventory group, owner's call.
