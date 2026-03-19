SHELL := /bin/bash


FILELIST  := files.f
OUTDIR    := out
WAVES_TCL := ../scripts/waves.tcl

XRUN := xrun -64bit -sv -f $(FILELIST) -access +rwc -input $(WAVES_TCL)

TB_TARGETS := \
	tb_scheduler_top \
	tb_req_fifo \
	tb_age_tracker \
	tb_wrr_arbiter \
	tb_scheduler_core \
	tb_status_counters \
	tb_csr_regs

UNIT_TBS := \
	tb_req_fifo \
	tb_age_tracker \
	tb_wrr_arbiter \
	tb_scheduler_core \
	tb_status_counters \
	tb_csr_regs

.PHONY: all unit regress clean $(TB_TARGETS) help


all: regress
unit: $(UNIT_TBS)
regress: unit tb_scheduler_top

$(TB_TARGETS):
	mkdir -p $(OUTDIR)/$@
	$(XRUN) \
		-top $@ \
		-l $(OUTDIR)/$@/xrun.log \
		-xmlibdirname $(OUTDIR)/$@/xcelium.d \
		-history_file $(OUTDIR)/$@/xrun.history

clean:
	rm -rf $(OUTDIR)
	rm -rf xrun.history xcelium.d .simvision


help:
	@echo "Targets :"
	@echo "  all              	Run full regression"
	@echo "  unit             	Run all unit testbenches"
	@echo "  regress          	Run unit & top tb"
	@echo "  tb_scheduler_top 	Run top level tb"
	@echo "  tb_req_fifo      	Run req_fifo unit tb"
	@echo "  tb_age_tracker   	Run age_tracker unit tb"
	@echo "  tb_wrr_arbiter   	Run wrr_arbiter unit tb"
	@echo "  tb_scheduler_core 	Run scheduler_core unit tb"
	@echo "  tb_status_counters	Run status_counters unit tb"
	@echo "  tb_csr_regs      	Run csr_regs unit tb"
	@echo "  clean            	Remove simulation tb"