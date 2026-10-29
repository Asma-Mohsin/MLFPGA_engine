# librelane_plugin_regions

Adds `Odb.AddPlacementRegions`, a LibreLane step that creates OpenROAD placement
fences (OpenDB `dbRegion` + `dbGroup`, type EXCLUSIVE). OpenROAD's global placer
places each region as its own sub-problem, and the detailed placer keeps grouped
cells inside their region and everything else outside.

## Install

Put the folder that contains `librelane_plugin_regions/` on `PYTHONPATH`
(LibreLane imports every `librelane_plugin_*` module). Plugins are not supported
in the LibreLane Docker image; use the Nix or pip install.

## Configure

```yaml
meta:
  flow: Classic
  substituting_steps:
    # create the fences before the first global placement
    "-OpenROAD.GlobalPlacementSkipIO": "Odb.AddPlacementRegions"
    # steps that insert cells and legalize: new cells join their region first
    "OpenROAD.RepairDesignPostGPL": "Regions.RepairDesignPostGPL"
    "OpenROAD.DetailedPlacement": "Regions.DetailedPlacement"
    "OpenROAD.CTS": "Regions.CTS"
    "OpenROAD.ResizerTimingPostCTS": "Regions.ResizerTimingPostCTS"
    # optional, post-GRT repair (always runs once substituted)
    "OpenROAD.RepairDesignPostGRT": "Regions.RepairDesignPostGRT"
    "OpenROAD.ResizerTimingPostGRT": "Regions.ResizerTimingPostGRT"
    # antenna diodes: fences taken down while repair_antennas legalizes them
    "OpenROAD.RepairAntennas": "Regions.RepairAntennas"
    "OpenROAD.DetailedRouting": "Regions.DetailedRouting"

PLACEMENT_REGIONS:
  alu_fence:                       # auto-sized: 55 % utilization, square
    instances: ["u_core.u_alu.*"]
    origin: [50, 50]
    utilization: 55
  fpu_fence:                       # explicit box, fail if > 70 % full
    instances: ["u_core.u_fpu.*"]
    area: [300, 50, 500, 250]
    utilization: 70

PL_TARGET_DENSITY_PCT: 60          # applies to the top level AND every region
```

Fields per region: `instances` (fnmatch patterns on flattened instance names),
`area` [llx lly urx ury] µm, or `origin` [x y] µm + `utilization` %,
`aspect_ratio` (height/width, default 1), `absorb` (default true),
`gpl_max_density` %, `dpl_padding` (sites), `late_instances` (patterns for cells
created after this step, e.g. the resizer's `input*`/`output*` IO buffers; matched
before each legalization in the `Regions.*` steps, never fail).

`PLACEMENT_REGIONS_STRICT` (default true) fails the step when a pattern matches
nothing on first creation or a region is above its `utilization`.

## What it does

1. Matches movable core instances against each region's patterns.
2. Creates the region (snapped to the site/row grid, clipped to the core),
   or reuses it on re-runs.
3. Optionally absorbs un-grouped cells whose every signal connection lands in
   one region (e.g. buffers inserted by `repair_design` or CTS) — iterated so
   buffer chains are absorbed. Cells on nets that reach a top-level port are
   left alone.
4. Prints a per-region utilization table (fixed cells like tap cells are
   subtracted from the free area).

## New cells during repair / CTS

OpenROAD's resizer and CTS never add the cells they insert to a group, and
LibreLane's repair, CTS and timing-repair scripts call `detailed_placement`
in the same step. A buffer for fenced logic would therefore be legalized as an
outsider and pushed out of its region.

The `Regions.*` steps are the LibreLane steps of the same name, run through
`regions_wrap.tcl`: it wraps `detailed_placement` with `regions_absorb`
(`regions_dpl_hook.tcl`) and then sources the original script unchanged. Before
each legalization, every movable ungrouped cell located inside a region joins
that region's group if at least one neighbor is in the group and none is in a
different group. Ungrouped neighbors and port connections are allowed, so
buffer chains, port buffers and nets leaving the region are covered. Cells with
no neighbor in the region (e.g. other logic gpl dropped there) stay outsiders
and are moved out; see `PL_MAX_DISPLACEMENT_*`.

Variants exist for `GlobalPlacement`, `DetailedPlacement`,
`RepairDesignPostGPL`, `CTS`, `ResizerTimingPostCTS`, `RepairDesignPostGRT`,
`ResizerTimingPostGRT`, `RepairAntennas` and `DetailedRouting`.

`repair_antennas` legalizes its diodes inside OpenROAD, not through the Tcl
`detailed_placement`, so the absorb hook cannot reach them: a diode next to a
fenced gate is ungrouped and dpl fails it (DPL-0036). The hook therefore also
wraps `repair_antennas`: it saves every region (name, type, boxes, group
members), destroys them, runs the repair and rebuilds them unchanged. All cells
are legal by then, so the fences are not needed during the repair. The new
diodes stay ungrouped; the next `Regions.*` legalization absorbs them.
`Regions.RepairAntennas` covers the GRT-stage repair, `Regions.DetailedRouting`
the post-DRT antenna loop (`DRT_ANTENNA_REPAIR_ITERS`). `Odb.DiodesOnPorts`
legalizes with plain `DetailedPlacement` and has no variant. Classic's `RUN_*` gating variables are keyed by the
original step IDs and do not apply to the variants: substituting
`Regions.RepairDesignPostGRT` / `Regions.ResizerTimingPostGRT` always runs them,
even though `RUN_POST_GRT_DESIGN_REPAIR` / `RUN_POST_GRT_RESIZER_TIMING` are off
by default.

## Limitations

- OpenROAD treats every region as a hard fence; INCLUSIVE/guide semantics are
  not modelled by gpl or dpl.
- `global_placement -density` is a single value. Per-region utilization comes
  from the region size. gpl raises a region's density automatically if the
  global value is too low for it (GPL-0302).
- gpl is not strict about keeping other cells out of a region. Outsiders that
  end up inside can only be legalized within `PL_MAX_DISPLACEMENT_X/Y`; if the
  region borders macros, the nearest legal rows can be millimetres away.
