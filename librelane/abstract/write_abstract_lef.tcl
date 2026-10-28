# Abstract LEF of the integration abstract, called by `make abstract` with ABSTRACT_RUN set.
# Every layer with shapes (all of them, through the full-die routing obstructions) becomes one
# cover OBS; pins stay as they are.
set run $::env(ABSTRACT_RUN)
read_db $run/final/odb/efpga_subsystem_top.odb
write_abstract_lef -bloat_occupied_layers $run/final/efpga_subsystem_top.lef
