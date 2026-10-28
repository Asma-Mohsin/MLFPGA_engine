REPO_ROOT := $(abspath ../..)
PDK_ROOT ?= $(error PDK_ROOT is not set: directory holding your ciel PDKs)
LL_DIR ?= $(abspath .)

# Same PDK and LibreLane as the top level (versions.env, flake.nix)
include $(REPO_ROOT)/versions.env

.PHONY: check-versions
check-versions:
	$(MAKE) -C $(REPO_ROOT) check-versions PDK_ROOT=$(PDK_ROOT)

.PHONY: all
all: librelane

librelane: check-versions
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ 
.PHONY: librelane

librelane-explore: check-versions
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --flow SynthesisExploration
.PHONY: librelane-explore

librelane-nodrc: check-versions
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --skip KLayout.DRC --skip Magic.DRC --skip KLayout.Antenna --skip KLayout.Density
.PHONY: librelane-nodrc

librelane-magicdrc: check-versions
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --skip KLayout.DRC
.PHONY: librelane-magicdrc

librelane-klayoutdrc: check-versions
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --save-views-to final/ --skip Magic.DRC
.PHONY: librelane-klayoutdrc

librelane-openroad: check-versions
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --last-run --flow OpenInOpenROAD
.PHONY: librelane-openroad

librelane-klayout: check-versions
	librelane $(LL_DIR)/config.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --last-run --flow OpenInKLayout
.PHONY: librelane-klayout

# Repo flake (flake.nix), same shell as `make nix` at the top level
.PHONY: nix
nix:
	nix develop $(REPO_ROOT) --command bash -c 'exec bash --rcfile <(cat "$${HOME}/.bashrc"; printf "%s\n" '\''PS1="\[\\033[01;35m\][nix-shell]\[\\033[00m\] \[\\033[01;32m\]$${USER}@\\h\[\\033[00m\]:\[\\033[01;34m\]\\w\[\\033[00m\]> "'\'') -i'
