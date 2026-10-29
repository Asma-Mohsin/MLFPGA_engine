# SPDX-License-Identifier: Apache-2.0
# Entry script for the Regions.* step variants: installs the detailed_placement
# hook, then runs the original LibreLane script unchanged.
source $::env(_REGIONS_HOOK_TCL)
# Optional debug hook (e.g. dump fence outsiders instead of legalizing).
if { [info exists ::env(REGIONS_DIAG_TCL)] } {
    source $::env(REGIONS_DIAG_TCL)
}
source $::env(_REGIONS_ORIG_SCRIPT)
