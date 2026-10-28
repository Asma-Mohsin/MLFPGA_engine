REPO_ROOT := $(abspath ../..)
PDK_ROOT ?= $(error PDK_ROOT is not set: directory holding your ciel PDKs)
LL_DIR ?= $(abspath ./librelane)
NIX_DIR ?= $(error NIX_DIR is not set: path to your LibreLane checkout)
FINAL_DIR ?= final

include versions.env

# Make librelane_plugin_regions importable so LibreLane auto-loads it
export PYTHONPATH := $(CURDIR):$(PYTHONPATH)

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

.PHONY: check-versions
check-versions:
	@test -e "$(PDK_ROOT)/$(PDK)" && test "$$(readlink -f $(PDK_ROOT)/$(PDK))" = "$$(readlink -f $(PDK_ROOT)/ciel/$(PDK_FAMILY)/versions/$(PDK_HASH)/$(PDK))" \
		|| { echo "ERROR: $(PDK_ROOT)/$(PDK) is not $(PDK_FAMILY) $(PDK_HASH) (versions.env). Run: ciel enable --pdk-family $(PDK_FAMILY) $(PDK_HASH)"; exit 1; }
	@test "$$(git -C $(NIX_DIR) rev-parse HEAD)" = "$(LIBRELANE_COMMIT)" \
		|| { echo "ERROR: LibreLane in $(NIX_DIR) is not at $(LIBRELANE_COMMIT) (versions.env)"; exit 1; }
	@grep -q "librelane/librelane/$(LIBRELANE_COMMIT)" ip/Fabric/flake.nix \
		|| { echo "ERROR: ip/Fabric/flake.nix does not pin LibreLane $(LIBRELANE_COMMIT) (versions.env)"; exit 1; }
	@# FABulous takes the PDK hash LibreLane recommends, so both must agree
	@git -C $(NIX_DIR) show $(LIBRELANE_COMMIT):librelane/pdk_hashes.yaml | grep -q "^$(PDK_FAMILY): $(PDK_HASH)$$" \
		|| { echo "ERROR: LibreLane $(LIBRELANE_COMMIT) does not recommend $(PDK_FAMILY) $(PDK_HASH) (versions.env)"; exit 1; }

.PHONY: zip zip-final
zip: zip-final

zip-final:
	test -d "$(FINAL_DIR)"
	find "$(FINAL_DIR)" -type f \( \
		-name "*.gds" -o \
		-name "*.def" -o \
		-name "*.mag" -o \
		-name "*.odb" -o \
		-name "*.spef" \
	\) -exec sh -c '\
		set -eu; \
		for file do \
			dir=$${file%/*}; \
			base=$${file##*/}; \
			archive=$${base}.zip; \
			tmp=$${archive}.tmp; \
			rm -f "$$dir/$$tmp"; \
			(cd "$$dir" && zip -D -q "$$tmp" "$$base"); \
			unzip -tq "$$dir/$$tmp"; \
			mv -f "$$dir/$$tmp" "$$dir/$$archive"; \
			rm -- "$$file"; \
			printf "Archived and replaced %s with %s/%s\\n" "$$file" "$$dir" "$$archive"; \
		done' sh {} +

.PHONY: nix
nix:
	cd "$(NIX_DIR)" && nix-shell --run 'cd "$(CURDIR)" && exec bash --rcfile <(cat "$${HOME}/.bashrc"; printf "%s\n" '\''PS1="\[\\033[01;35m\][nix-shell]\[\\033[00m\] \[\\033[01;32m\]$${USER}@\\h\[\\033[00m\]:\[\\033[01;34m\]\\w\[\\033[00m\]> "'\'') -i'
