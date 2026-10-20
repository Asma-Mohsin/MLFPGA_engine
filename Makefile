REPO_ROOT := $(abspath ../..)
PDK_ROOT ?= /shares/zitipoolhome/bm185/Desktop/SSD4TB/OWAS_NOV/fabulous_A5/PDK
PDK ?= ihp-sg13cmos5l
LL_DIR ?= $(abspath ./librelane)
NIX_DIR ?= /shares/zitipoolhome/bm185/Desktop/SSD4TB/OWAS_NOV/fabulous_A5/librelane

.PHONY: all
all: librelane

librelane: $(PDK_ROOT)/$(PDK)
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ 
.PHONY: librelane

librelane-explore: $(PDK_ROOT)/$(PDK)
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --flow SynthesisExploration
.PHONY: librelane-explore

librelane-nodrc: $(PDK_ROOT)/$(PDK)
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --skip KLayout.DRC --skip Magic.DRC --skip KLayout.Antenna --skip KLayout.Density
.PHONY: librelane-nodrc

librelane-magicdrc: $(PDK_ROOT)/$(PDK)
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --skip KLayout.DRC
.PHONY: librelane-magicdrc

librelane-klayoutdrc: $(PDK_ROOT)/$(PDK)
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --skip Magic.DRC
.PHONY: librelane-klayoutdrc

librelane-openroad: $(PDK_ROOT)/$(PDK)
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --last-run --flow OpenInOpenROAD
.PHONY: librelane-openroad

librelane-klayout: $(PDK_ROOT)/$(PDK)
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --last-run --flow OpenInKLayout
.PHONY: librelane-klayout

.PHONY: nix
nix:
	cd "$(NIX_DIR)" && nix-shell --run 'cd "$(CURDIR)" && exec bash --rcfile <(cat "$${HOME}/.bashrc"; printf "%s\n" '\''PS1="\[\\033[01;35m\][nix-shell]\[\\033[00m\] \[\\033[01;32m\]$${USER}@\\h\[\\033[00m\]:\[\\033[01;34m\]\\w\[\\033[00m\]> "'\'') -i'
