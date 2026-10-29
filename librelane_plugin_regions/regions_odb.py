# SPDX-License-Identifier: Apache-2.0
# Runs inside `openroad -python`; invoked by Odb.AddPlacementRegions.
import math
import sys
from fnmatch import fnmatchcase

import click
import odb
from reader import click_odb  # LibreLane's scripts/odbpy, on PYTHONPATH


def err(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)


def snap_down(v, origin, pitch):
    return origin + ((v - origin) // pitch) * pitch


def snap_up(v, origin, pitch):
    return origin + -(-(v - origin) // pitch) * pitch


def to_rect(box):
    # dbBox.getBox() is ambiguous to SWIG in some OpenROAD builds
    return odb.Rect(box.xMin(), box.yMin(), box.xMax(), box.yMax())


def overlap(a, b):
    w = min(a.xMax(), b.xMax()) - max(a.xMin(), b.xMin())
    h = min(a.yMax(), b.yMax()) - max(a.yMin(), b.yMin())
    return w * h if w > 0 and h > 0 else 0


def inst_area(inst):
    m = inst.getMaster()
    return m.getWidth() * m.getHeight()


def neighbors(inst):
    """Instances sharing a signal net with `inst`; None if it touches a port."""
    out = set()
    for it in inst.getITerms():
        net = it.getNet()
        if net is None or net.isSpecial() or net.getSigType() in ("POWER", "GROUND"):
            continue
        if len(net.getBTerms()):
            return None
        for other in net.getITerms():
            o = other.getInst()
            if o.getName() != inst.getName():
                out.add(o)
    return out


@click.command()
@click_odb
def main(reader):
    cfg = reader.config
    regions = cfg.get("PLACEMENT_REGIONS") or {}
    strict = cfg.get("PLACEMENT_REGIONS_STRICT", True)
    block = reader.block
    dbu = block.getDbUnitsPerMicron()
    core = block.getCoreArea()
    rows = list(block.getRows())
    if not rows:
        err("No rows found; run this step after the floorplan.")
        sys.exit(1)
    site_w = rows[0].getSite().getWidth()
    row_h = rows[0].getSite().getHeight()

    movable = [i for i in block.getInsts() if not i.isFixed() and i.getMaster().isCore()]
    fixed = [i for i in block.getInsts() if i.isFixed()]
    macros = [i for i in fixed if i.getMaster().isBlock()]
    failed = False
    groups = {}
    claimed = {}

    for name, r in regions.items():
        group = block.findGroup(name)
        region = block.findRegion(name)
        is_new = region is None

        # 1. Assign instances matching the patterns.
        added = 0
        for pattern in r.get("instances") or []:
            hits = [i for i in movable if fnmatchcase(i.getName(), pattern)]
            if not hits:
                err(f"[{name}] pattern '{pattern}' matched no movable instances.")
                failed |= strict and is_new
            for inst in hits:
                current = inst.getGroup()
                if current is None:
                    owner = claimed.setdefault(inst.getName(), name)
                    if owner != name:
                        err(f"[{name}] {inst.getName()} already claimed by {owner}; skipped.")
                        continue
                    groups.setdefault(name, {})[inst.getName()] = inst
                elif current.getName() != name:
                    err(f"[{name}] {inst.getName()} already belongs to {current.getName()}; skipped.")

        pending = list(groups.get(name, {}).values())
        cell_area = sum(inst_area(i) for i in pending)
        if group is not None:
            cell_area += sum(inst_area(i) for i in group.getInsts())

        # 2. Create the region (explicit area or auto-sized from utilization).
        if is_new:
            util = r.get("utilization")
            if r.get("area"):
                llx, lly, urx, ury = (int(float(v) * dbu) for v in r["area"])
            elif r.get("origin") and util:
                need = cell_area / (float(util) / 100.0)
                ar = float(r.get("aspect_ratio") or 1)
                w = math.sqrt(need / ar)
                llx, lly = (int(float(v) * dbu) for v in r["origin"])
                urx, ury = llx + int(w), lly + int(need / w)
            else:
                err(f"[{name}] give either 'area' or 'origin' + 'utilization'.")
                failed = True
                continue
            llx = max(snap_down(llx, core.xMin(), site_w), core.xMin())
            lly = max(snap_down(lly, core.yMin(), row_h), core.yMin())
            urx = min(snap_up(urx, core.xMin(), site_w), core.xMax())
            ury = min(snap_up(ury, core.yMin(), row_h), core.yMax())
            region = odb.dbRegion_create(block, name)
            region.setRegionType("EXCLUSIVE")
            odb.dbBox_create(region, llx, lly, urx, ury)
            group = odb.dbGroup_create(region, name)
            print(f"[{name}] created region ({llx/dbu:.3f}, {lly/dbu:.3f}) - ({urx/dbu:.3f}, {ury/dbu:.3f}) µm")

            # Regions.GlobalPlacement lends the region's group the macros inside
            # it (regions_dpl_hook.tcl). That can't cover a macro only partly
            # inside: gpl would subtract its full area from the region.
            rect = odb.Rect(llx, lly, urx, ury)
            for m in macros:
                mb = to_rect(m.getBBox())
                # Tolerate slivers from snapping the region to the site grid.
                share = overlap(rect, mb) / overlap(core, mb)
                if 0.01 <= share < 0.99:
                    err(f"[{name}] macro {m.getName()} is only partly inside; gpl will place cells on it.")
                    failed |= strict
        elif group is None:
            group = odb.dbGroup_create(region, name)

        for inst in pending:
            group.addInst(inst)
            added += 1
        print(f"[{name}] added {added} instance(s) from patterns.")

    # 3. Absorb un-grouped cells whose connections all land in one group
    #    (buffers inserted by repair_design / CTS). Iterate to a fixpoint so
    #    buffer chains are absorbed too.
    absorbing = {n for n, r in regions.items() if r.get("absorb", True)}
    if absorbing:
        changed = True
        absorbed = {n: 0 for n in absorbing}
        while changed:
            changed = False
            for inst in movable:
                if inst.getGroup() is not None:
                    continue
                nbrs = neighbors(inst)
                if not nbrs:
                    continue
                gnames = {n.getGroup().getName() if n.getGroup() else None for n in nbrs}
                if len(gnames) == 1:
                    g = gnames.pop()
                    if g in absorbing:
                        block.findGroup(g).addInst(inst)
                        absorbed[g] += 1
                        changed = True
        for n, c in absorbed.items():
            if c:
                print(f"[{n}] absorbed {c} connected un-grouped cell(s).")

    # 4. Report utilization per region.
    print(f"{'region':<20}{'cells':>8}{'cell µm²':>14}{'free µm²':>14}{'util %':>9}")
    for name, r in regions.items():
        region = block.findRegion(name)
        group = block.findGroup(name)
        if region is None or group is None:
            continue
        free = 0
        for box in region.getBoundaries():
            rect = to_rect(box)
            free += rect.area() - sum(overlap(rect, to_rect(f.getBBox())) for f in fixed)
        insts = list(group.getInsts())
        area = sum(inst_area(i) for i in insts)
        util = 100.0 * area / free if free else float("inf")
        print(f"{name:<20}{len(insts):>8}{area/dbu/dbu:>14.2f}{free/dbu/dbu:>14.2f}{util:>9.2f}")
        limit = r.get("utilization")
        if r.get("area") and limit is not None and util > float(limit):
            err(f"[{name}] utilization {util:.2f}% exceeds target {float(limit):.2f}%.")
            failed |= strict
        if util >= 100.0:
            err(f"[{name}] region is over-full; legalization will fail.")
            failed = True

    if failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
