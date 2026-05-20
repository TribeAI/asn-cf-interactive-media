# asn-cf-interactive-media — Makefile
#
# The visualizations in this repo render data produced by external pipelines.
# The pipelines themselves live in their own repos and ARE NOT mirrored here;
# this Makefile is the canonical way to pull their outputs into `public/` so
# the viz can serve them.
#
# Today, only one viz has external data inputs:
#   - ontology-extraction → asn-content-ontology
#
# As more viz pages are added, extend the `data` target to fan out to them.

# Where the source repos live. Override on the command line, e.g.:
#   make data ONTOLOGY_REPO=/path/to/asn-content-ontology
ONTOLOGY_REPO ?= ../asn-content-ontology

# Locked sample directory inside the ontology repo. Update when the canonical
# extraction batch advances (e.g., sample-2026-06-XX).
ONTOLOGY_SAMPLE_DIR := $(ONTOLOGY_REPO)/extractions/raw/sample-2026-05-19
ONTOLOGY_TARGET     := public/ontology-extraction

# Files copied from the ontology repo. The names on the right (target) are
# what the viz HTML expects; the names on the left (source) are the
# canonical names in the ontology repo's per-variant subdirs.
ONTOLOGY_FILES := \
	$(ONTOLOGY_TARGET)/topics-claude-code.jsonl   \
	$(ONTOLOGY_TARGET)/topics-mlx.jsonl           \
	$(ONTOLOGY_TARGET)/topics-mlx-fewshot.jsonl   \
	$(ONTOLOGY_TARGET)/topic_matches.json         \
	$(ONTOLOGY_TARGET)/modules.json

.PHONY: help data data-ontology data-refresh serve clean check-ontology-repo

help:
	@echo "Targets:"
	@echo "  make data           Pull latest viz data from external repos into public/."
	@echo "  make data-refresh   Regenerate viz data in the source repos, then pull."
	@echo "  make serve          Run a local static server on port 8000."
	@echo "  make clean          Remove externally-sourced data files from public/."
	@echo ""
	@echo "Variables:"
	@echo "  ONTOLOGY_REPO       Path to asn-content-ontology checkout (default: ../asn-content-ontology)."

data: data-ontology

data-ontology: check-ontology-repo $(ONTOLOGY_FILES)
	@echo "ontology-extraction: data pulled from $(ONTOLOGY_SAMPLE_DIR)"

check-ontology-repo:
	@test -d "$(ONTOLOGY_REPO)" || { \
		echo "ERROR: ONTOLOGY_REPO not found at $(ONTOLOGY_REPO)."; \
		echo "       Clone https://github.com/TribeAI/asn-content-ontology"; \
		echo "       or pass ONTOLOGY_REPO=/path/to/checkout"; \
		exit 1; \
	}
	@test -d "$(ONTOLOGY_SAMPLE_DIR)" || { \
		echo "ERROR: sample dir not found: $(ONTOLOGY_SAMPLE_DIR)"; \
		echo "       Did you point ONTOLOGY_REPO at the right checkout?"; \
		exit 1; \
	}

# Per-file copy rules. Each target is a single file in public/ that mirrors a
# source file in the ontology repo with the same shape. Renaming happens here.

$(ONTOLOGY_TARGET)/topics-claude-code.jsonl: $(ONTOLOGY_SAMPLE_DIR)/prompt-v3-linkedin-skill/topics.jsonl
	@mkdir -p $(@D)
	cp $< $@

$(ONTOLOGY_TARGET)/topics-mlx.jsonl: $(ONTOLOGY_SAMPLE_DIR)/prompt-v3-linkedin-skill-mlx/topics.jsonl
	@mkdir -p $(@D)
	cp $< $@

$(ONTOLOGY_TARGET)/topics-mlx-fewshot.jsonl: $(ONTOLOGY_SAMPLE_DIR)/prompt-v3-linkedin-skill-mlx-fewshot/topics.jsonl
	@mkdir -p $(@D)
	cp $< $@

$(ONTOLOGY_TARGET)/topic_matches.json: $(ONTOLOGY_SAMPLE_DIR)/topic_matches.json
	@mkdir -p $(@D)
	cp $< $@

$(ONTOLOGY_TARGET)/modules.json: $(ONTOLOGY_SAMPLE_DIR)/modules.json
	@mkdir -p $(@D)
	cp $< $@

# Regenerate the source data in the ontology repo, then pull. Most callers
# just want `make data`; this target is for cases where you've updated the
# extraction prompts / matching script and need the artifacts rebuilt first.
data-refresh: check-ontology-repo
	cd $(ONTOLOGY_REPO) && uv run python scripts/build_topic_matches.py
	cd $(ONTOLOGY_REPO) && uv run python scripts/build_viz_modules.py
	$(MAKE) data

serve:
	python3 -m http.server -d public 8000

clean:
	rm -f $(ONTOLOGY_FILES)
