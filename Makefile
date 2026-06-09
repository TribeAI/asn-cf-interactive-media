# asn-cf-interactive-media — Makefile
#
# The visualizations in this repo render data produced by external pipelines.
# The pipelines themselves live in their own repos and ARE NOT mirrored here;
# this Makefile is the canonical way to pull their outputs into `public/` so
# the viz can serve them.
#
# Today, two viz pages have external data inputs:
#   - ontology-extraction → asn-content-ontology (topics: Claude vs Qwen)
#   - jobs-to-be-done     → asn-content-ontology (JTBD axis + derived personas)
#
# As more viz pages are added, extend the `data` target to fan out to them.

# Where the source repos live. Override on the command line, e.g.:
#   make data ONTOLOGY_REPO=/path/to/asn-content-ontology
ONTOLOGY_REPO ?= ../asn-content-ontology

# Locked sample directory inside the ontology repo. Update when the canonical
# extraction batch advances (e.g., sample-2026-06-XX).
ONTOLOGY_SAMPLE_DIR := $(ONTOLOGY_REPO)/extractions/raw/sample-2026-05-19
ONTOLOGY_TARGET     := public/ontology-extraction

# Jobs-to-be-done extraction sample (axis 2 of the content ontology).
# Self-contained jsonl — each line carries module metadata plus the extracted
# jobs_to_be_done[] and personas[] (with persona->job canonical_name links).
JTBD_SAMPLE_DIR := $(ONTOLOGY_REPO)/extractions/raw/sample-2026-05-28/jtbd-mlx-zeroshot
JTBD_TARGET     := public/jobs-to-be-done

# Aggregate role -> job -> topic ontology graph (built by build_ontology_graph.py
# from the jtbd + v3-topics extractions). Self-contained JSON consumed by the
# /ontology/ Sankey viz. As of 2026-06-09 this is the FULL-corpus Sonnet batch
# (3,418 modules; jobs leader-clustered @0.70; floors role≥5/job≥5/topic≥5).
ONTGRAPH_SAMPLE_DIR := $(ONTOLOGY_REPO)/extractions/raw/full-sonnet-batch-fewshot
ONTGRAPH_TARGET     := public/ontology

# Full-corpus topic coverage + competitor gap lens (built by
# build_topic_coverage.py from the full Sonnet batch extraction). Consumed by
# the /ontology/gaps/ coverage & gaps viz.
COVERAGE_SAMPLE_DIR := $(ONTOLOGY_REPO)/extractions/raw/full-sonnet-batch-fewshot
COVERAGE_TARGET     := public/ontology/gaps

# Files copied from the ontology repo. The names on the right (target) are
# what the viz HTML expects; the names on the left (source) are the
# canonical names in the ontology repo's per-variant subdirs.
ONTOLOGY_FILES := \
	$(ONTOLOGY_TARGET)/topics-claude-code.jsonl   \
	$(ONTOLOGY_TARGET)/topics-mlx.jsonl           \
	$(ONTOLOGY_TARGET)/topics-mlx-fewshot.jsonl   \
	$(ONTOLOGY_TARGET)/topic_matches.json         \
	$(ONTOLOGY_TARGET)/modules.json

JTBD_FILES := \
	$(JTBD_TARGET)/jtbd.jsonl

ONTGRAPH_FILES := \
	$(ONTGRAPH_TARGET)/ontology_graph.json

COVERAGE_FILES := \
	$(COVERAGE_TARGET)/topic_coverage.json \
	public/ontology/gap-explorer/topic_coverage.json

.PHONY: help data data-ontology data-jtbd data-ontology-graph data-coverage data-refresh serve clean check-ontology-repo

help:
	@echo "Targets:"
	@echo "  make data           Pull latest viz data from external repos into public/."
	@echo "  make data-refresh   Regenerate viz data in the source repos, then pull."
	@echo "  make serve          Run a local static server on port 8000."
	@echo "  make clean          Remove externally-sourced data files from public/."
	@echo ""
	@echo "Variables:"
	@echo "  ONTOLOGY_REPO       Path to asn-content-ontology checkout (default: ../asn-content-ontology)."

data: data-ontology data-jtbd data-ontology-graph data-coverage

data-ontology: check-ontology-repo $(ONTOLOGY_FILES)
	@echo "ontology-extraction: data pulled from $(ONTOLOGY_SAMPLE_DIR)"

data-jtbd: check-ontology-repo $(JTBD_FILES)
	@echo "jobs-to-be-done: data pulled from $(JTBD_SAMPLE_DIR)"

data-ontology-graph: check-ontology-repo $(ONTGRAPH_FILES)
	@echo "ontology: graph pulled from $(ONTGRAPH_SAMPLE_DIR)"

data-coverage: check-ontology-repo $(COVERAGE_FILES)
	@echo "ontology/gaps: coverage pulled from $(COVERAGE_SAMPLE_DIR)"

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
	@test -d "$(JTBD_SAMPLE_DIR)" || { \
		echo "ERROR: jobs-to-be-done sample dir not found: $(JTBD_SAMPLE_DIR)"; \
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

# jobs-to-be-done is a single self-contained jsonl (no separate matches/modules
# files — module metadata is embedded per line), so it's a straight copy.
$(JTBD_TARGET)/jtbd.jsonl: $(JTBD_SAMPLE_DIR)/jtbd.jsonl
	@mkdir -p $(@D)
	cp $< $@

$(ONTGRAPH_TARGET)/ontology_graph.json: $(ONTGRAPH_SAMPLE_DIR)/ontology_graph.json
	@mkdir -p $(@D)
	cp $< $@

$(COVERAGE_TARGET)/topic_coverage.json: $(COVERAGE_SAMPLE_DIR)/topic_coverage.json
	@mkdir -p $(@D)
	cp $< $@

public/ontology/gap-explorer/topic_coverage.json: $(COVERAGE_SAMPLE_DIR)/topic_coverage.json
	@mkdir -p $(@D)
	cp $< $@

# Regenerate the source data in the ontology repo, then pull. Most callers
# just want `make data`; this target is for cases where you've updated the
# extraction prompts / matching script and need the artifacts rebuilt first.
data-refresh: check-ontology-repo
	cd $(ONTOLOGY_REPO) && uv run python scripts/build_topic_matches.py
	cd $(ONTOLOGY_REPO) && uv run python scripts/build_viz_modules.py
	cd $(ONTOLOGY_REPO) && uv run python scripts/build_ontology_graph.py \
		--jtbd $(JTBD_SAMPLE_DIR)/jtbd.jsonl \
		--topics $(ONTGRAPH_SAMPLE_DIR)/topics-mlx/topics.jsonl \
		--out $(ONTGRAPH_SAMPLE_DIR)
	$(MAKE) data

serve:
	python3 -m http.server -d public 8000

clean:
	rm -f $(ONTOLOGY_FILES) $(JTBD_FILES) $(ONTGRAPH_FILES)
