REPO_ROOT := $(abspath ../..)
PDK_ROOT ?= $(error PDK_ROOT is not set: directory holding your ciel PDKs)
LL_DIR ?= $(abspath ./librelane)
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

# Integration abstract: empty 4000 x 4250 macro (pins, PDN, full OBS) for top-level integration.
# Liberty is taken from a routed run, with the area set to the macro size.
ABSTRACT_TAG ?= abstract_d4000_h4250
ABSTRACT_RUN := $(LL_DIR)/runs/$(ABSTRACT_TAG)
ABSTRACT_LIB_RUN ?= $(LL_DIR)/runs/region_d4100_h4050b

# Writes the views to $(FINAL_DIR) in the LibreLane final/ layout, replacing what is there, and zips them.
abstract: check-versions
	test -d "$(ABSTRACT_LIB_RUN)/final/lib"
	test -n "$(FINAL_DIR)"
	librelane $(LL_DIR)/config_abstract_d4000_h4250.yaml --pdk $(PDK) --pdk-root $(PDK_ROOT) --manual-pdk --run-tag $(ABSTRACT_TAG) --overwrite
	ABSTRACT_RUN=$(ABSTRACT_RUN) openroad -exit $(LL_DIR)/abstract/write_abstract_lef.tcl
	rm -rf "$(FINAL_DIR)" && mkdir -p "$(FINAL_DIR)/lef" "$(FINAL_DIR)/gds" "$(FINAL_DIR)/nl" "$(FINAL_DIR)/vh"
	cp $(ABSTRACT_RUN)/final/efpga_subsystem_top.lef "$(FINAL_DIR)/lef/"
	cp $(ABSTRACT_RUN)/final/gds/efpga_subsystem_top.gds "$(FINAL_DIR)/gds/"
	cp $(ABSTRACT_RUN)/final/nl/efpga_subsystem_top.nl.v "$(FINAL_DIR)/nl/"
	cp $(ABSTRACT_LIB_RUN)/final/vh/efpga_subsystem_top.vh "$(FINAL_DIR)/vh/"
	area=$$(awk '$$1 == "SIZE" { printf "%.3f", $$2 * $$4 }' "$(FINAL_DIR)/lef/efpga_subsystem_top.lef") && \
	for f in $(ABSTRACT_LIB_RUN)/final/lib/*/*.lib; do \
		corner=$${f%/*}; corner=$${corner##*/}; \
		mkdir -p "$(FINAL_DIR)/lib/$$corner"; \
		sed "s/^\(\s*area : \)[0-9.]*/\1$$area/" "$$f" > "$(FINAL_DIR)/lib/$$corner/$${f##*/}"; \
	done
	$(MAKE) zip-final
.PHONY: abstract

.PHONY: check-versions
check-versions:
	@test -e "$(PDK_ROOT)/$(PDK)" && test "$$(readlink -f $(PDK_ROOT)/$(PDK))" = "$$(readlink -f $(PDK_ROOT)/ciel/$(PDK_FAMILY)/versions/$(PDK_HASH)/$(PDK))" \
		|| { echo "ERROR: $(PDK_ROOT)/$(PDK) is not $(PDK_FAMILY) $(PDK_HASH) (versions.env). Run: ciel enable --pdk-family $(PDK_FAMILY) $(PDK_HASH)"; exit 1; }
	@grep -q 'FAB_PDK_HASH = "$(PDK_HASH)"' ip/Fabric/flake.nix \
		|| { echo "ERROR: ip/Fabric/flake.nix does not set FAB_PDK_HASH to $(PDK_HASH) (versions.env)"; exit 1; }
	@# Also fails outside the repo's nix shell (no librelane module): run `make nix` first
	@python3 -c 'import librelane, pathlib; print((pathlib.Path(librelane.__file__).parent / "pdk_hashes.yaml").read_text())' \
		| grep -q "^$(PDK_FAMILY): $(PDK_HASH)$$" \
		|| { echo "ERROR: the LibreLane in this shell does not recommend $(PDK_FAMILY) $(PDK_HASH) (versions.env); run make targets inside make nix"; exit 1; }

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

# Repo flake (flake.nix): LibreLane and all tools locked in flake.lock
.PHONY: nix
nix:
	nix develop $(CURDIR) --command bash -c 'exec bash --rcfile <(cat "$${HOME}/.bashrc"; printf "%s\n" '\''PS1="\[\\033[01;35m\][nix-shell]\[\\033[00m\] \[\\033[01;32m\]$${USER}@\\h\[\\033[00m\]:\[\\033[01;34m\]\\w\[\\033[00m\]> "'\'') -i'
