# SPDX-License-Identifier: Apache-2.0
"""
LibreLane plugin: placement regions (fences) for OpenROAD.

Adds the step ``Odb.AddPlacementRegions`` which creates OpenDB regions + groups
(the same objects DEF REGIONS/GROUPS or UPF ``set_domain_area`` create), so the
OpenROAD global placer (gpl) and detailed placer (dpl) keep the selected cells
inside their region and all other cells outside it.

Install: put the folder containing this package on PYTHONPATH (or pip install
it). LibreLane auto-imports any module named ``librelane_plugin_*``.
"""
import os
from dataclasses import dataclass, field
from decimal import Decimal
from typing import Dict, List, Optional, Tuple

from librelane.config import Variable
from librelane.steps import Step
from librelane.steps.odb import OdbpyStep

__dir__ = os.path.dirname(os.path.abspath(__file__))


@dataclass
class PlacementRegion:
    """
    One placement fence.

    :param instances: fnmatch-style patterns matched against the (flattened)
        instance names, e.g. ``"u_core.u_alu.*"``.
    :param area: Explicit rectangle ``[llx, lly, urx, ury]`` in µm.
    :param origin: Lower-left corner in µm; used with ``utilization`` to size
        the region automatically when ``area`` is not given.
    :param utilization: Target utilization (%) of the region. With ``origin``
        it sizes the region; with ``area`` it is checked as an upper bound.
    :param aspect_ratio: Height / width for auto-sized regions.
    :param absorb: Also pull in un-grouped cells (e.g. buffers added by the
        resizer or CTS) whose every connection lands inside this region.
    :param gpl_max_density: Max. density (%) global placement may use inside
        the region, applied as a partial placement blockage during
        ``Regions.GlobalPlacement`` only. Lower values spread the region's
        cells like extra GPL padding would.
    :param dpl_padding: Detailed placement padding (sites, split evenly per
        side like ``DPL_CELL_PADDING``) for the region's cells, applied in the
        ``Regions.*`` legalizing steps. Keep it >= ``DPL_CELL_PADDING``: later
        steps check placement with the global padding only.
    :param late_instances: Patterns like ``instances``, but for cells that do
        not exist yet when ``Odb.AddPlacementRegions`` runs (e.g. the resizer's
        ``input*``/``output*`` IO buffers). Matched before each legalization in
        the ``Regions.*`` steps, regardless of the cell's location; never fail.
    """

    instances: List[str] = field(default_factory=list)
    area: Optional[Tuple[Decimal, Decimal, Decimal, Decimal]] = None
    origin: Optional[Tuple[Decimal, Decimal]] = None
    utilization: Optional[Decimal] = None
    aspect_ratio: Decimal = Decimal(1)
    absorb: bool = True
    gpl_max_density: Optional[Decimal] = None
    dpl_padding: Optional[int] = None
    late_instances: List[str] = field(default_factory=list)


# Shared by every step that reads the regions, so the flow sees one variable.
_regions_variable = Variable(
    "PLACEMENT_REGIONS",
    Optional[Dict[str, PlacementRegion]],
    "Placement fences keyed by region name. If unset, the step is skipped.",
    default=None,
)


@Step.factory.register()
class AddPlacementRegions(OdbpyStep):
    """
    Creates (or updates) exclusive placement regions in the OpenDB database
    from ``PLACEMENT_REGIONS``. Safe to run more than once: existing regions
    are reused, and only instances not yet assigned to a group are added, so
    it can be re-run after resizer/CTS steps to absorb newly inserted cells.
    """

    id = "Odb.AddPlacementRegions"
    name = "Add Placement Regions"

    config_vars = [
        _regions_variable,
        Variable(
            "PLACEMENT_REGIONS_STRICT",
            bool,
            "Fail if a pattern matches nothing or a region exceeds its utilization.",
            default=True,
        ),
    ]

    def get_script_path(self) -> str:
        return os.path.join(__dir__, "regions_odb.py")

    def get_command(self) -> List[str]:
        return super().get_command() + ["--step-config", self.config_path]

    def run(self, state_in, **kwargs):
        if not self.config["PLACEMENT_REGIONS"]:
            self.warn("PLACEMENT_REGIONS is not set; skipping.")
            return {}, {}
        return super().run(state_in, **kwargs)


class _AbsorbBeforeDetailedPlacement:
    """
    Runs the step's original script through ``regions_wrap.tcl``, which wraps
    ``detailed_placement`` so cells inserted by the resizer/CTS inside a region
    join that region's group before legalization and get the region's padding,
    and ``global_placement`` so it sees the regions' density blockages (see
    regions_dpl_hook.tcl).
    """

    def prepare_env(self, env, state):
        env = super().prepare_env(env, state)
        env["_REGIONS_HOOK_TCL"] = os.path.join(__dir__, "regions_dpl_hook.tcl")
        env["_REGIONS_ORIG_SCRIPT"] = self.get_script_path()
        return env

    def get_command(self) -> List[str]:
        command = super().get_command()
        command[-1] = os.path.join(__dir__, "regions_wrap.tcl")
        return command


# Steps whose scripts place or legalize. Each gets a ``Regions.<Name>`` variant
# to substitute in. Their Classic gating variables (RUN_CTS, ...) are keyed by
# the original IDs and do not apply to the variants.
for _base_id in (
    "OpenROAD.GlobalPlacement",
    "OpenROAD.DetailedPlacement",
    "OpenROAD.RepairDesignPostGPL",
    "OpenROAD.CTS",
    "OpenROAD.ResizerTimingPostCTS",
    "OpenROAD.RepairDesignPostGRT",
    "OpenROAD.ResizerTimingPostGRT",
    # repair_antennas (in drt.tcl's post-DRT antenna loop) is wrapped to take the
    # fences down while it legalizes its diodes; see regions_dpl_hook.tcl
    "OpenROAD.DetailedRouting",
):
    _Base = Step.factory.get(_base_id)
    _name = _base_id.split(".", 1)[1]
    Step.factory.register()(
        type(
            f"{_Base.__name__}WithRegions",
            (_AbsorbBeforeDetailedPlacement, _Base),
            {
                "id": f"Regions.{_name}",
                "name": f"{_Base.name} (Placement Regions)",
                "config_vars": _Base.config_vars + [_regions_variable],
                "__module__": __name__,
            },
        )
    )


# GRT-stage antenna repair: OpenROAD.RepairAntennas is a CompositeStep around the
# unregistered _DiodeInsertion, so the variant swaps in a wrapped copy of it.
from librelane.steps.openroad import CheckAntennas, RepairAntennas, _DiodeInsertion

_DiodeInsertionWithRegions = Step.factory.register()(
    type(
        "DiodeInsertionWithRegions",
        (_AbsorbBeforeDetailedPlacement, _DiodeInsertion),
        {
            "id": "Regions.DiodeInsertion",
            "name": f"{_DiodeInsertion.name} (Placement Regions)",
            "config_vars": _DiodeInsertion.config_vars + [_regions_variable],
            "__module__": __name__,
        },
    )
)


@Step.factory.register()
class RepairAntennasWithRegions(RepairAntennas):
    id = "Regions.RepairAntennas"
    name = f"{RepairAntennas.name} (Placement Regions)"

    Steps = [_DiodeInsertionWithRegions, CheckAntennas]
