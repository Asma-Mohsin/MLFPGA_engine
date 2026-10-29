# SPDX-License-Identifier: Apache-2.0
# Sourced by regions_wrap.tcl inside OpenROAD steps that place or legalize.
#
# The resizer and CTS never add the cells they insert to a dbGroup, so a buffer
# for fenced logic starts inside the fence as an outsider and detailed_placement
# would push it out of the region. This wraps detailed_placement so such cells
# are first added to the group of the region they sit in, and the region's
# padding is applied. global_placement is wrapped to apply per-region density.

# Adds every movable, ungrouped core cell located inside a region to that
# region's group if at least one neighbor is in the group and no neighbor is
# in a different group. Ungrouped neighbors are allowed, so buffer chains and
# nets leaving the region are absorbed; port connections are ignored.
proc regions_absorb {} {
    set block [ord::get_db_block]
    set regions [$block getRegions]
    if { [llength $regions] == 0 } {
        return
    }

    # 0. Ungrouped cells matching a region's `late_instances` join it wherever
    #    they are; regions_clamp then pulls them inside.
    foreach {name patterns} [regions_setting late_instances] {
        set group [$block findGroup $name]
        if { $group eq "NULL" || [llength $patterns] == 0 } {
            continue
        }
        set count 0
        foreach inst [$block getInsts] {
            if { [$inst getGroup] ne "NULL" || [$inst isFixed] || ![[$inst getMaster] isCore] } {
                continue
            }
            foreach pattern $patterns {
                if { [string match $pattern [$inst getName]] } {
                    $group addInst $inst
                    incr count
                    break
                }
            }
        }
        puts "\[INFO\] Placement regions: $name took $count cell(s) from late_instances."
    }

    set boxes [list]
    foreach region $regions {
        foreach group [$region getGroups] {
            foreach box [$region getBoundaries] {
                lappend boxes [list $group [$box xMin] [$box yMin] [$box xMax] [$box yMax]]
            }
        }
    }

    # 1. Ungrouped movable core cells inside a region box.
    set candidates [list]
    foreach inst [$block getInsts] {
        if { [$inst getGroup] ne "NULL" || [$inst isFixed] || ![[$inst getMaster] isCore] } {
            continue
        }
        set bbox [$inst getBBox]
        set x [$bbox xMin]
        set y [$bbox yMin]
        foreach entry $boxes {
            lassign $entry group x0 y0 x1 y1
            if { $x >= $x0 && $x < $x1 && $y >= $y0 && $y < $y1 } {
                lappend candidates [list $inst $group]
                break
            }
        }
    }

    # 2. Absorb by connectivity; iterate so chains of new buffers are absorbed.
    set absorbed 0
    set changed 1
    while { $changed } {
        set changed 0
        set remaining [list]
        foreach entry $candidates {
            lassign $entry inst group
            set target [$group getName]
            set ok 0
            set bad 0
            foreach iterm [$inst getITerms] {
                set net [$iterm getNet]
                if { $net eq "NULL" || [$net isSpecial] } {
                    continue
                }
                set sig [$net getSigType]
                if { $sig eq "POWER" || $sig eq "GROUND" } {
                    continue
                }
                foreach other [$net getITerms] {
                    set other_inst [$other getInst]
                    if { $other_inst eq $inst } {
                        continue
                    }
                    set other_group [$other_inst getGroup]
                    if { $other_group eq "NULL" } {
                        continue
                    }
                    if { [$other_group getName] eq $target } {
                        set ok 1
                    } else {
                        set bad 1
                    }
                }
            }
            if { $ok && !$bad } {
                $group addInst $inst
                incr absorbed
                set changed 1
            } else {
                lappend remaining $entry
            }
        }
        set candidates $remaining
    }

    puts "\[INFO\] Placement regions: absorbed $absorbed new cell(s);\
        [llength $candidates] outsider(s) inside regions will be moved out."
}

# Moves grouped cells that stick out of their region's bbox (e.g. buffers the
# resizer inserts at the region edge) fully inside it, on the site/row grid.
# Like a cell on a macro at the region edge (see regions_unstick), a cell
# starting outside the region makes dpl's search fail.
proc regions_clamp {} {
    set block [ord::get_db_block]
    set site [[lindex [$block getRows] 0] getSite]
    set sw [$site getWidth]
    set rh [$site getHeight]
    set core [$block getCoreArea]
    set ox [$core xMin]
    set oy [$core yMin]

    set moved 0
    foreach region [$block getRegions] {
        set boxes [$region getBoundaries]
        # Region bbox snapped inwards to the site/row grid.
        set r0 [expr { $ox - (($ox - [tcl::mathfunc::min {*}[lmap b $boxes { $b xMin }]]) / $sw) * $sw }]
        set r1 [expr { $oy - (($oy - [tcl::mathfunc::min {*}[lmap b $boxes { $b yMin }]]) / $rh) * $rh }]
        set r2 [expr { $ox + (([tcl::mathfunc::max {*}[lmap b $boxes { $b xMax }]] - $ox) / $sw) * $sw }]
        set r3 [expr { $oy + (([tcl::mathfunc::max {*}[lmap b $boxes { $b yMax }]] - $oy) / $rh) * $rh }]
        foreach group [$region getGroups] {
            foreach inst [$group getInsts] {
                if { [$inst isFixed] } {
                    continue
                }
                set b [$inst getBBox]
                set x [$b xMin]
                set y [$b yMin]
                set nx [expr { max($r0, min($x, $r2 - [$b getDX])) }]
                set ny [expr { max($r1, min($y, $r3 - [$b getDY])) }]
                if { $nx != $x || $ny != $y } {
                    $inst setLocation $nx $ny
                    incr moved
                }
            }
        }
    }
    puts "\[INFO\] Placement regions: moved $moved cell(s) back inside their region."
}

# Moves grouped cells that gpl left on a fixed macro to the nearest side of the
# macro that lies inside their region. dpl pushes such cells to the nearest
# macro edge itself, which can be outside the region (e.g. a macro flush with
# the region edge); its search then fails for that cell, and one failure makes
# dpl re-place the whole group from the region corners (brickPlace2), which
# for ~100k cells does not finish.
proc regions_unstick {} {
    set block [ord::get_db_block]
    set macros [list]
    foreach inst [$block getInsts] {
        if { [$inst isFixed] && [[$inst getMaster] isBlock] } {
            set b [$inst getBBox]
            lappend macros [list [$b xMin] [$b yMin] [$b xMax] [$b yMax]]
        }
    }
    set site [[lindex [$block getRows] 0] getSite]
    set sw [$site getWidth]
    set rh [$site getHeight]
    set core [$block getCoreArea]
    set ox [$core xMin]
    set oy [$core yMin]

    set moved 0
    set stuck 0
    foreach region [$block getRegions] {
        set boxes [$region getBoundaries]
        set r0 [tcl::mathfunc::min {*}[lmap b $boxes { $b xMin }]]
        set r1 [tcl::mathfunc::min {*}[lmap b $boxes { $b yMin }]]
        set r2 [tcl::mathfunc::max {*}[lmap b $boxes { $b xMax }]]
        set r3 [tcl::mathfunc::max {*}[lmap b $boxes { $b yMax }]]
        foreach group [$region getGroups] {
            foreach inst [$group getInsts] {
                if { [$inst isFixed] } {
                    continue
                }
                set b [$inst getBBox]
                set x [$b xMin]
                set y [$b yMin]
                set w [$b getDX]
                set h [$b getDY]
                foreach m $macros {
                    lassign $m m0 m1 m2 m3
                    if { $x + $w <= $m0 || $x >= $m2 || $y + $h <= $m1 || $y >= $m3 } {
                        continue
                    }
                    # Left, right, below, above the macro, snapped outwards to
                    # the site/row grid with one site/row to spare.
                    set sx [expr { $ox + (($x - $ox) / $sw) * $sw }]
                    set sy [expr { $oy + (($y - $oy) / $rh) * $rh }]
                    set candidates [list \
                        [expr { $ox + (($m0 - $w - $ox) / $sw) * $sw - $sw }] $sy \
                        [expr { $ox - (($ox - $m2) / $sw) * $sw + $sw }] $sy \
                        $sx [expr { $oy + (($m1 - $h - $oy) / $rh) * $rh - $rh }] \
                        $sx [expr { $oy - (($oy - $m3) / $rh) * $rh + $rh }]]
                    set best ""
                    foreach {cx cy} $candidates {
                        if { $cx < $r0 || $cx + $w > $r2 || $cy < $r1 || $cy + $h > $r3 } {
                            continue
                        }
                        set d [expr { abs($cx - $x) + abs($cy - $y) }]
                        if { $best eq "" || $d < $best_d } {
                            set best [list $cx $cy]
                            set best_d $d
                        }
                    }
                    if { $best eq "" } {
                        incr stuck
                    } else {
                        $inst setLocation {*}$best
                        incr moved
                    }
                    break
                }
            }
        }
    }
    puts "\[INFO\] Placement regions: moved $moved cell(s) off macros;\
        $stuck without a macro side inside their region."
}

# Returns the region settings (PLACEMENT_REGIONS as a Tcl dict) whose `key`
# is set, as a flat list of name/value pairs.
proc regions_setting { key } {
    if { ![info exists ::env(PLACEMENT_REGIONS)] } {
        return [list]
    }
    set result [list]
    dict for {name settings} $::env(PLACEMENT_REGIONS) {
        if { [dict exists $settings $key] } {
            set value [dict get $settings $key]
            if { $value ne "None" } {
                lappend result $name $value
            }
        }
    }
    return $result
}

# Gives each region's cells its `dpl_padding` (sites, split per side like
# DPL_CELL_PADDING). Instance padding overrides master padding, so masters in
# CELL_PAD_EXCLUDE (taps, fill, ...) are skipped.
proc regions_set_padding {} {
    set block [ord::get_db_block]
    set exclude [list]
    if { [info exists ::env(CELL_PAD_EXCLUDE)] } {
        set exclude $::env(CELL_PAD_EXCLUDE)
    }
    set global_side 0
    if { [info exists ::env(DPL_CELL_PADDING)] } {
        set global_side [expr { $::env(DPL_CELL_PADDING) / 2 }]
    }
    foreach {name padding} [regions_setting dpl_padding] {
        set group [$block findGroup $name]
        if { $group eq "NULL" } {
            continue
        }
        set side [expr { $padding / 2 }]
        if { $side < $global_side } {
            puts "\[WARNING\] Placement regions: $name dpl_padding $padding is below\
                DPL_CELL_PADDING; later steps' check_placement uses the global padding."
        }
        array unset excluded
        set count 0
        foreach inst [$group getInsts] {
            set master [[$inst getMaster] getName]
            if { ![info exists excluded($master)] } {
                set excluded($master) 0
                foreach pattern $exclude {
                    if { [string match $pattern $master] } {
                        set excluded($master) 1
                        break
                    }
                }
            }
            if { $excluded($master) } {
                continue
            }
            dpl::set_padding_inst $inst $side $side
            incr count
        }
        puts "\[INFO\] Placement regions: $name padding $side site(s) per side on $count cell(s)."
    }
}

# Adds a partial placement blockage over each region with `gpl_max_density`.
# Only gpl honors the density; dpl/cts treat any non-soft blockage as fully
# blocked, so the blockages must be destroyed again after global placement.
# gpl subtracts every blockage from every region placer's free area, so the
# other regions see slightly less free area than they have.
proc regions_create_gpl_blockages {} {
    set block [ord::get_db_block]
    set blockages [list]
    foreach {name density} [regions_setting gpl_max_density] {
        set region [$block findRegion $name]
        if { $region eq "NULL" } {
            continue
        }
        foreach box [$region getBoundaries] {
            set blockage [odb::dbBlockage_create $block \
                [$box xMin] [$box yMin] [$box xMax] [$box yMax]]
            $blockage setMaxDensity $density
            lappend blockages $blockage
        }
        puts "\[INFO\] Placement regions: $name global placement max density $density %."
    }
    return $blockages
}

if { [info commands __regions_orig_detailed_placement] eq "" } {
    rename detailed_placement __regions_orig_detailed_placement
    proc detailed_placement { args } {
        regions_absorb
        regions_clamp
        regions_unstick
        regions_set_padding
        uplevel 1 [list __regions_orig_detailed_placement {*}$args]
    }
}

# gpl's region placers only block the sites of fixed instances in their own
# group, so they spread the region's cells over any other macro inside it.
# Lends each region's group the fixed macros (nearly) fully inside it; returns
# the group/macro pairs to give back after global placement. They must not stay
# in the group: dpl would try to legalize them (DPL-0017).
proc regions_lend_macros {} {
    set block [ord::get_db_block]
    set lent [list]
    foreach inst [$block getInsts] {
        if { ![$inst isFixed] || ![[$inst getMaster] isBlock] || [$inst getGroup] ne "NULL" } {
            continue
        }
        set bbox [$inst getBBox]
        set area [expr { double([$bbox getDX]) * [$bbox getDY] }]
        foreach region [$block getRegions] {
            set inside 0.0
            foreach box [$region getBoundaries] {
                set w [expr { min([$bbox xMax], [$box xMax]) - max([$bbox xMin], [$box xMin]) }]
                set h [expr { min([$bbox yMax], [$box yMax]) - max([$bbox yMin], [$box yMin]) }]
                if { $w > 0 && $h > 0 } {
                    set inside [expr { $inside + double($w) * $h }]
                }
            }
            # Tolerate the macro edge sticking out of the core or the site-snapped region.
            if { $inside >= 0.99 * $area } {
                set group [lindex [$region getGroups] 0]
                $group addInst $inst
                lappend lent $group $inst
                break
            }
        }
    }
    puts "\[INFO\] Placement regions: [expr { [llength $lent] / 2 }] macro(s) lent to regions for global placement."
    return $lent
}

# repair_antennas legalizes its diodes inside OpenROAD (not through the Tcl
# detailed_placement above), and a diode next to a fenced gate is ungrouped, so
# dpl fails it (DPL-0036). All cells are legal by then, so the fences are taken
# down for the repair and rebuilt unchanged afterwards; the new diodes stay
# ungrouped (the next Regions.* legalization absorbs them like resizer buffers).
proc regions_save_and_drop {} {
    set block [ord::get_db_block]
    set saved [list]
    foreach region [$block getRegions] {
        set boxes [list]
        foreach box [$region getBoundaries] {
            lappend boxes [list [$box xMin] [$box yMin] [$box xMax] [$box yMax]]
        }
        set groups [list]
        foreach group [$region getGroups] {
            set insts [$group getInsts]
            lappend groups [list [$group getName] $insts]
            foreach inst $insts { $group removeInst $inst }
            odb::dbGroup_destroy $group
        }
        lappend saved [list [$region getName] [$region getRegionType] $boxes $groups]
        odb::dbRegion_destroy $region
    }
    puts "\[INFO\] Placement regions: [llength $saved] region(s) removed for antenna repair."
    return $saved
}

proc regions_restore { saved } {
    set block [ord::get_db_block]
    foreach entry $saved {
        lassign $entry name type boxes groups
        set region [odb::dbRegion_create $block $name]
        $region setRegionType $type
        foreach box $boxes {
            odb::dbBox_create $region {*}$box
        }
        foreach g $groups {
            lassign $g group_name insts
            set group [odb::dbGroup_create $region $group_name]
            foreach inst $insts { $group addInst $inst }
        }
    }
    puts "\[INFO\] Placement regions: [llength $saved] region(s) restored after antenna repair."
}

if { [info commands repair_antennas] ne "" && [info commands __regions_orig_repair_antennas] eq "" } {
    rename repair_antennas __regions_orig_repair_antennas
    proc repair_antennas { args } {
        set saved [regions_save_and_drop]
        catch {uplevel 1 [list __regions_orig_repair_antennas {*}$args]} result options
        regions_restore $saved
        return -options $options $result
    }
}

if { [info commands __regions_orig_global_placement] eq "" } {
    rename global_placement __regions_orig_global_placement
    proc global_placement { args } {
        set blockages [regions_create_gpl_blockages]
        set lent [regions_lend_macros]
        catch {uplevel 1 [list __regions_orig_global_placement {*}$args]} result options
        foreach {group inst} $lent {
            $group removeInst $inst
        }
        foreach blockage $blockages {
            odb::dbBlockage_destroy $blockage
        }
        return -options $options $result
    }
}
