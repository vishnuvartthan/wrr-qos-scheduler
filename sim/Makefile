SHELL := /bin/bash

XRUN      ?= xrun
FILELIST  := files.f
OUTDIR    := out
WAVES_TCL := ../scripts/waves.tcl

TB_TOP    := tb_qos_sched_top
TB_FIFO   := tb_req_fifo
TB_AGE    := tb_age_tracker
TB_WRR_ARB  := tb_wrr_arbiter

XRUN_COMMON := -64bit -sv -f $(FILELIST) -access +rwc -input $(WAVES_TCL)

.PHONY: all tb_qos_sched_top req_fifo age_tracker wrr_arbiter clean

all: tb_qos_sched_top

tb_qos_sched_top:
	mkdir -p $(OUTDIR)/$(TB_TOP)
	$(XRUN) $(XRUN_COMMON) \
		-top $(TB_TOP) \
		-l $(OUTDIR)/$(TB_TOP)/xrun.log \
		-xmlibdirname $(OUTDIR)/$(TB_TOP)/xcelium.d \
		-history_file $(OUTDIR)/$(TB_TOP)/xrun.history

req_fifo:
	mkdir -p $(OUTDIR)/$(TB_FIFO)
	$(XRUN) $(XRUN_COMMON) \
		-top $(TB_FIFO) \
		-l $(OUTDIR)/$(TB_FIFO)/xrun.log \
		-xmlibdirname $(OUTDIR)/$(TB_FIFO)/xcelium.d \
		-history_file $(OUTDIR)/$(TB_FIFO)/xrun.history

age_tracker:
	mkdir -p $(OUTDIR)/$(TB_AGE)
	$(XRUN) $(XRUN_COMMON) \
		-top $(TB_AGE) \
		-l $(OUTDIR)/$(TB_AGE)/xrun.log \
		-xmlibdirname $(OUTDIR)/$(TB_AGE)/xcelium.d \
		-history_file $(OUTDIR)/$(TB_AGE)/xrun.history

wrr_arbiter:
	mkdir -p $(OUTDIR)/$(TB_WRR_ARB)
	$(XRUN) $(XRUN_COMMON) \
		-top $(TB_WRR_ARB) \
		-l $(OUTDIR)/$(TB_WRR_ARB)/xrun.log \
		-xmlibdirname $(OUTDIR)/$(TB_WRR_ARB)/xcelium.d \
		-history_file $(OUTDIR)/$(TB_WRR_ARB)/xrun.history

clean:
	rm -rf $(OUTDIR)/$(TB_TOP)
	rm -rf $(OUTDIR)/$(TB_FIFO)
	rm -rf $(OUTDIR)/$(TB_AGE)
	rm -rf $(OUTDIR)/$(TB_WRR_ARB)
	rm -rf xrun.history
	rm -rf xcelium.d
	rm -rf .simvision
	rm -rf $(OUTDIR)/waves.shm