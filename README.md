<!--
  README MODEL (adapted for a verification library: no RTL)
  ----------------------------------------------------------
  Regenerate from the sources, never from the previous README text alone:
    src_bfm/*.vhd (records, procedures), uvvm.core (VLNV, targets, depends),
    mk/targets.txt, sim/.
  Sections, in this order:
    badges / title + one-line pitch / Overview / BFMs / one section per BFM
    (procedures, configuration, usage, timing) / Design Verification /
    Repository Layout / License
  Rules:
    - English, short and factual: every statement backed by the sources.
    - No VLNV line: the version badge shows it.
    - Badges: first line version, license; second line CI, sim (no lint, no syn: no RTL).
    - Timing diagrams: WaveDrom source doc/uvvm-<what>.json, rendered
      doc/uvvm-<what>.svg (make -C doc), shown as images.
-->
[![Version](https://img.shields.io/github/v/tag/deuskane/asylum-verification-uvvm?filter=asylum-verification-uvvm-*&label=version&color=blue)](https://github.com/deuskane/asylum-verification-uvvm/tags)
[![License](https://img.shields.io/github/license/deuskane/asylum-verification-uvvm)](LICENSE)

[![CI](https://github.com/deuskane/asylum-verification-uvvm/actions/workflows/ci.yml/badge.svg)](https://github.com/deuskane/asylum-verification-uvvm/actions/workflows/ci.yml)
[![sim](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fdeuskane%2Fasylum-verification-uvvm%2Fbadges%2Fsim.json)](https://github.com/deuskane/asylum-verification-uvvm/actions/workflows/ci.yml)

# Asylum UVVM BFMs

**Small, readable UVVM bus functional models for the protocols UVVM does not cover: an APB3 master and an IEEE 1149.1 JTAG master, each verified against a testbench model.**

Part of the [Asylum project](https://github.com/deuskane/asylum-project), a collection of small IP cores, written to be read and learned from.

## Table of Contents

1. [Overview](#overview)
2. [BFMs](#bfms)
3. [APB BFM](#apb-bfm)
4. [JTAG BFM](#jtag-bfm)
5. [Design Verification](#design-verification)
6. [Repository Layout](#repository-layout)
7. [License](#license)

## Overview

The Asylum testbenches are written with [UVVM](https://github.com/UVVM/UVVM) (utility library and BFMs). UVVM has no APB and no JTAG VIP, so the Asylum IPs that need them share the BFMs of this library instead of keeping their own copies.

The library has the form of UVVM Light:

- one FuseSoC core, `asylum:verification:uvvm`, which depends on `bitvis:verification:uvvm` (`uvvm_util`),
- one VHDL library, `asylum_uvvm`,
- one package per BFM in `src_bfm/<name>_bfm_pkg.vhd`, BFMs only (no VVC).

Each BFM follows the conventions of the UVVM BFMs: an interface record (`t_<name>_if`) with an `init_<name>_if_signals` function (outputs inactive, inputs at `'Z'`), a configuration record (`t_<name>_bfm_config`) with a default constant, procedures with `msg`, `scope`, `msg_id_panel` and `config` parameters, logs and alerts of `uvvm_util`.

Use it in a core:

```yaml
    depend :
      - asylum:verification:uvvm
```

The cores of the Asylum IPs are published in the FuseSoC library [asylum-cores](https://github.com/deuskane/asylum-cores), with the UVVM cores.

## BFMs

| BFM | Package | Protocol | Procedures |
|-----|---------|----------|------------|
| APB  | `asylum_uvvm.apb_bfm_pkg`  | AMBA APB3 master, synchronous to the bus clock | `apb_write`, `apb_read`, `apb_check` |
| JTAG | `asylum_uvvm.jtag_bfm_pkg` | IEEE 1149.1 master, drives TCK itself | `jtag_trst`, `jtag_reset`, `jtag_idle`, `jtag_write_ir`, `jtag_scan_dr`, `jtag_check_dr`; monitor `jtag_ir_capture_monitor` |

## APB BFM

### Interface and configuration

`t_apb_if`: `psel`, `penable`, `pwrite`, `paddr` (unsigned), `pwdata` (to the DUT), `prdata`, `pready`, `pslverr` (from the DUT). `paddr`, `pwdata` and `prdata` are unconstrained: constrain them in the signal declaration and initialize the signal with `init_apb_if_signals(addr_width, data_width)`.

| Field of `t_apb_bfm_config` | Default | Description |
|-----------------------------|---------|-------------|
| `max_wait_cycles`          | 10            | Maximum number of cycles with `pready` low in the access phase |
| `max_wait_cycles_severity` | `failure`     | Severity of the timeout |
| `expected_pslverr`         | `'0'`         | Value of `pslverr` expected at the end of the transfer |
| `pslverr_severity`         | `error`       | Severity of a `pslverr` mismatch |
| `match_strictness`         | `MATCH_EXACT` | Matching of std_logic values in `apb_check` |
| `id_for_bfm`               | `ID_BFM`      | Message ID of the logs |
| `id_for_bfm_wait`          | `ID_BFM_WAIT` | Message ID of the wait for `pready` |

### Procedures

| Procedure | Parameters | Description |
|-----------|------------|-------------|
| `apb_write` | `addr_value, data_value, msg, clk, apb_if [, scope, msg_id_panel, config]` | One write transfer. `data_value` may be narrower than `pwdata` (zero extended) |
| `apb_read`  | `addr_value, data_value (out), msg, clk, apb_if [, scope, msg_id_panel, config]` | One read transfer, returns `prdata` |
| `apb_check` | `addr_value, data_exp, msg, clk, apb_if [, alert_level, scope, msg_id_panel, config]` | Read, then compare with `data_exp` (`'-'`: don't care bit); `=> OK` log or alert of `alert_level` |

### Usage

```vhdl
library asylum_uvvm;
use     asylum_uvvm.apb_bfm_pkg.all;

  signal apb_if : t_apb_if(paddr (8-1  downto 0),
                           pwdata(32-1 downto 0),
                           prdata(32-1 downto 0)) := init_apb_if_signals(8, 32);

  -- In the sequencer
  apb_write(x"10", x"5A3C96E1", "Write CTRL", clk, apb_if);
  apb_check(x"10", x"5A3C96E1", "Read back CTRL", clk, apb_if);
```

Connect `apb_if.psel`, `apb_if.penable`, ... to the DUT, and drive `apb_if.prdata`, `apb_if.pready` and `apb_if.pslverr` from the DUT outputs with concurrent assignments.

### Timing

![APB write with one wait state, then a read](doc/uvvm-apb-transfer.svg)

The BFM drives the bus on the falling edge of `clk` and samples it on the rising edge (`SYNC_ON_CLOCK_ONLY` of UVVM). A transfer is a setup phase of one cycle (`psel`), then an access phase (`psel`, `penable`) until `pready`; `pslverr` is checked at the end of the transfer. The procedure returns a quarter of a period after the rising edge that ends the transfer: the next call starts a setup phase on the following falling edge, so two calls are back to back (2 cycles per transfer without wait state; `psel` falls for a quarter of a period between them, never on a rising edge).

## JTAG BFM

### Interface and configuration

`t_jtag_if`: `tck`, `tms`, `tdi`, `trst_b` (to the DUT), `tdo` (from the DUT). `init_jtag_if_signals` returns TCK low, TMS high, TDI low, TRST* inactive and TDO at `'Z'`.

| Field of `t_jtag_bfm_config` | Default | Description |
|------------------------------|---------|-------------|
| `tck_period`       | 100 ns        | Period of TCK, generated by the BFM |
| `ir_width`         | 5             | Width of the instruction register (>= 2) |
| `idle_cycles`      | 0             | Extra Run-Test/Idle cycles at the end of each scan |
| `trst_enable`      | true          | The DUT has TRST*: `jtag_reset` pulses `trst_b` before the TMS sequence, `jtag_trst` is allowed (`TB_ERROR` otherwise) |
| `match_strictness` | `MATCH_EXACT` | Matching of std_logic values in `jtag_check_dr` |
| `id_for_bfm`       | `ID_BFM`      | Message ID of the logs |

### Procedures

| Procedure | Parameters | TCK cycles | Description |
|-----------|------------|------------|-------------|
| `jtag_trst`     | `msg, jtag_if [, scope, msg_id_panel, config]` | 0 (2 periods) | TRST* pulse alone: TCK low, TMS = 1, `trst_b` low during one period, then one period of recovery; the TAP is in Test-Logic-Reset. `TB_ERROR` (and no pulse) when `trst_enable` is false |
| `jtag_reset`    | `msg, jtag_if [, scope, msg_id_panel, config]` | 6 (+ 2 periods with TRST*) | Optional TRST* pulse (`jtag_trst`), 5 TCK with TMS = 1 (Test-Logic-Reset from any state), then Run-Test/Idle |
| `jtag_idle`     | `num_cycles, msg, jtag_if [, scope, msg_id_panel, config]` | `num_cycles` | TCK cycles in Run-Test/Idle |
| `jtag_write_ir` | `ir_value, msg, jtag_if [, scope, msg_id_panel, config]` | `ir_width` + 6 + `idle_cycles` | IR scan; checks that the two LSB captured in Capture-IR are `"01"` (IEEE 1149.1) |
| `jtag_scan_dr`  | `data_value, data_out (out), msg, jtag_if [, scope, msg_id_panel, config]` | width + 5 + `idle_cycles` | DR scan of `data_value'length` bits, returns the captured value |
| `jtag_check_dr` | `data_value, data_exp, msg, jtag_if [, alert_level, scope, msg_id_panel, config]` | width + 5 + `idle_cycles` | DR scan, then compare the captured value with `data_exp` (`'-'`: don't care bit) |

Call `jtag_reset` first: the scans start and end in Run-Test/Idle. After `jtag_trst` the TAP is in Test-Logic-Reset: one `jtag_idle` cycle moves it to Run-Test/Idle.

### Capture-IR monitor

`jtag_ir_capture_monitor(jtag_if [, expected, scope, msg_id_panel, config])` is a concurrent procedure (it never returns), called in the architecture of the testbench next to the DUT. It follows the TAP controller on TMS (and TRST*, which brings it back to Test-Logic-Reset), keeps the bits shifted out of TDO in Shift-IR and, when the IR scan reaches Update-IR, compares them with `expected` (default `"01"`, zero extended to `config.ir_width`: `"0...01"`). One `=> OK` log per IR scan, an alert of severity `error` on a mismatch.

`jtag_write_ir` checks only the two LSB `"01"` that IEEE 1149.1 requires; the monitor checks the whole value that the DUT loads in Capture-IR, for every IR scan of the testbench, whoever drives the bus.

- A scan longer than `config.ir_width` (e.g. other TAPs in the chain) is checked on its first `config.ir_width` bits, the captured value; the next bits are TDI bits shifted through.
- A scan shorter than `config.ir_width` fails: the bits that were not shifted out stay `'U'`.
- The check is made at Update-IR, so a scan may go through Pause-IR.

### Usage

```vhdl
library asylum_uvvm;
use     asylum_uvvm.jtag_bfm_pkg.all;

  signal jtag_if : t_jtag_if := init_jtag_if_signals;

  -- In the architecture : full Capture-IR value of each IR scan
  jtag_ir_capture_monitor(jtag_if, "00001");

  -- In the sequencer
  jtag_reset   ("Reset the TAP", jtag_if);
  jtag_write_ir("00001", "IDCODE", jtag_if);
  jtag_check_dr(x"00000000", x"1DEB0001", "Read IDCODE", jtag_if);
  jtag_trst    ("TRST* : IDCODE selected again", jtag_if);
  jtag_idle    (1, "Run-Test/Idle", jtag_if);
```

### Timing

![JTAG DR scan of 4 bits](doc/uvvm-jtag-dr-scan.svg)

The BFM generates TCK. In each TCK cycle, TCK falls and TMS / TDI change, then TDO is sampled just before TCK rises (the TAP samples TMS and TDI on the rising edge and changes TDO on the falling edge). Vectors are shifted LSB first; the last bit is shifted with TMS = 1 (Exit1). TCK stays high between two procedures.

## Design Verification

One self-checking UVVM testbench per BFM, in `sim/<bfm>/`, against a testbench-only model (no RTL of another IP, so that the IPs can use this library without a dependency loop). Scenarios are chosen at run time with the `TESTS_LIST` generic (one package per scenario, each one after a reset); an empty list only builds and elaborates the testbench.

- `tb_apb`: APB3 slave model `tb_apb_slave` (memory of 256 words, a value derived from the address after the reset, `wait_states` cycles with `pready` low, `pslverr` at one address, `prdata` at `'X'` outside the end of a read) with a protocol checker (setup phase of one cycle, `psel`, `penable`, `paddr`, `pwrite`, `pwdata` held until `pready`).
- `tb_jtag`: IEEE 1149.1 TAP model `tb_jtag_tap` (16-state controller, `IR_WIDTH`-bit IR, IDCODE, BYPASS, a `DR_WIDTH`-bit user data register, TRST* and power-on reset, a wrong Capture-IR value on request) whose state is checked to be Run-Test/Idle after each procedure (Test-Logic-Reset after `jtag_trst`); monitors: TMS / TDI change only while TCK is low, count of the TRST* pulses and of the TCK edges, and `jtag_ir_capture_monitor` of the BFM, which checks every IR scan of every scenario.

Expected alerts of the BFM procedures (mismatch, `pslverr`, timeout) are raised with severity `WARNING` and counted with `get_alert_counter`, so that a failing count check (`ERROR`) is never hidden by an expected error. The Capture-IR monitor is concurrent, so its severity cannot change with the scenario: its expected alerts stay `ERROR` (`increment_expected_alerts_and_stop_limit`) and their count is checked with `TB_ERROR`. The same rule, the other way round, for the expected `TB_ERROR` of `jtag_trst` (count checked with `ERROR`).

| Target | Scenario | Checks |
|--------|----------|-------:|
| `sim_apb_reset_values` | Read of the slave memory after the reset (one address per address bit) | 10 |
| `sim_apb_write_read`   | Write then read back, data narrower than `pwdata`, don't care bits, mismatch of `apb_check` | 6 |
| `sim_apb_back_to_back` | 4 writes and 4 reads back to back, 2 cycles per transfer | 6 |
| `sim_apb_wait_states`  | 1, 3 and `max_wait_cycles` wait states, duration of each transfer | 6 |
| `sim_apb_pslverr`      | `pslverr` expected (no alert), not expected and missing (one alert each) | 5 |
| `sim_apb_timeout`      | `max_wait_cycles` + 1 wait states: timeout alert, then a normal transfer | 3 |
| `sim_jtag_reset_trst`  | TRST* pulse then TMS reset, IDCODE selected | 11 |
| `sim_jtag_reset_tms`   | Reset by TMS only (no TRST* pulse), IDCODE selected | 11 |
| `sim_jtag_idcode`      | IDCODE read, don't care bits, mismatch of `jtag_check_dr` | 11 |
| `sim_jtag_bypass`      | BYPASS and an undecoded opcode: one bit delay, capture 0 | 13 |
| `sim_jtag_user_dr`     | 40-bit user data register, IR then DR scans | 17 |
| `sim_jtag_idle`        | Number of TCK cycles of each procedure, `idle_cycles` | 17 |
| `sim_jtag_trst`        | `jtag_trst` alone: 2 periods, one TRST* pulse, no TCK edge, TCK low and TMS = 1, Test-Logic-Reset then IDCODE; `TB_ERROR` and no pulse without TRST* | 16 |
| `sim_jtag_ir_capture`  | Capture-IR monitor: IR scans checked, TRST* in Shift-IR (the monitor restarts from Test-Logic-Reset), IR scan of `ir_width` + 3 bits | 12 |
| `sim_jtag_ir_capture_error` | Capture-IR monitor: wrong captured value (MSB set, LSB `"01"`) and IR scan of `ir_width` - 1 bits, one alert each | 7 |
| `sim_jtag_ir8`         | Every JTAG scenario with an 8-bit IR, a 7-bit user data register and TCK 30 ns | 115 |

Checks: number of `=> OK` lines of the log. `sim_apb` and `sim_jtag` build the testbenches only (5-bit IR, 40-bit user data register, TCK 100 ns for `sim_jtag`).

The testbenches were validated with mutants of the BFMs (scratch copies, each scenario run alone): penable never set, pready ignored, pslverr not checked, no setup phase, `apb_check` that never fails, timeout one cycle early, reads sent as writes; TDO sampled after TCK fell again, MSB first, wrong TMS on the path to Shift-DR (two places), IR one bit too long or too short, no TRST* pulse, TRST* never released, reset with 2 TMS = 1 only, `idle_cycles` ignored, `jtag_check_dr` that never fails, TMS / TDI changed with the rising edge; `jtag_trst` with a TCK edge, with TMS = 0, without `TB_ERROR` when `trst_enable` is false; a monitor that never alerts, checks only the two LSB, samples TDO in Capture-IR instead of Shift-IR, ignores TRST* (two ways), keeps the last `ir_width` bits instead of the first ones, or does not clear the captured value at Capture-IR. Every one is killed by at least one scenario.

```bash
make sim_jtag_idcode                                   # one target (FuseSoC, GHDL)
make nonreg                                            # every sim_* target
fusesoc --cores-root . run --build-root build --no-export --run \
  --target sim_jtag asylum:verification:uvvm --TESTS_LIST=idcode,bypass
```

## Repository Layout

```
uvvm.core               FuseSoC core asylum:verification:uvvm
src_bfm/                BFM packages (library asylum_uvvm)
  apb_bfm_pkg.vhd       APB3 master
  jtag_bfm_pkg.vhd      IEEE 1149.1 JTAG master
sim/apb/                tb_apb: APB slave model, helpers, one package per scenario
sim/jtag/               tb_jtag: TAP model, helpers, one package per scenario
doc/                    WaveDrom timing diagrams (make -C doc)
Makefile, mk/           common Makefile of the Asylum IPs, targets list
.github/workflows/      CI: one job per sim_* target (make ci_generate)
```

## License

Apache License 2.0, see [LICENSE](LICENSE).
