/*
 * Copyright (c) 2015 Dmitry Osipenko <digetx@gmail.com>
 *
 *  This program is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful, but WITHOUT
 *  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 *  FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 *  for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, see <http://www.gnu.org/licenses/>.
 */

#include <fcntl.h>
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

#include "avp.h"
#include "Record.h"

#define AVP_RESET_VECTOR		0x6000F200
#define TEGRA_CLK_RESET_BASE		0x60006000
#define FLOW_CTRL_HALT_COP_EVENTS	0x60007004
#define FLOW_MODE_STOP			(2 << 29)
#define FLOW_MODE_NONE			0

#define PRI_ICTLR_IRQ_LATCHED		0x60004010
#define SEC_ICTLR_IRQ_LATCHED		0x60004110
#define TRI_ICTLR_IRQ_LATCHED		0x60004210
#define QUAD_ICTLR_IRQ_LATCHED		0x60004310

#define MEM_END				0x40000000
#define AVP_UNCACHED_MEM		0x80000000

#define AVP_NOP		0xFF
#define AVP_IDLE	0
#define AVP_READ8	1
#define AVP_READ16	2
#define AVP_READ32	3
#define AVP_WRITE8	4
#define AVP_WRITE16	5
#define AVP_WRITE32	6

#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))

static void *mem_virt;
static uint32_t io_addr_start;
static uint32_t io_addr_end;

static uint32_t mem_read(uint32_t offset, int size)
{
	switch (size) {
	case 8:
		return *(volatile uint8_t*)(mem_virt + offset);
	case 16:
		return *(volatile uint16_t*)(mem_virt + offset);
	case 32:
		return *(volatile uint32_t*)(mem_virt + offset);
	default:
		abort();
	}
}

static void mem_write(uint32_t value, uint32_t offset, int size)
{
	switch (size) {
	case 8:
		*(volatile uint8_t*)(mem_virt + offset) = value;
		break;
	case 16:
		*(volatile uint16_t*)(mem_virt + offset) = value;
		break;
	case 32:
		*(volatile uint32_t*)(mem_virt + offset) = value;
		break;
	default:
		abort();
	}
}

static uint32_t cpu_read(uint32_t offset, int size)
{
	return mem_read(offset, size);
}

static void cpu_write(uint32_t value, uint32_t offset, int size)
{
	mem_write(value, offset, size);
}

static void avp_run(void)
{
	mem_write(FLOW_MODE_NONE, FLOW_CTRL_HALT_COP_EVENTS, 32);
}

static void avp_halt(void)
{
	mem_write(FLOW_MODE_STOP, FLOW_CTRL_HALT_COP_EVENTS, 32);
}

static void start_avp(void)
{
	mem_write(1 << 1, TEGRA_CLK_RESET_BASE + 0x304, 32);
}

static void stop_avp(void)
{
	avp_halt();
	mem_write(1 << 1, TEGRA_CLK_RESET_BASE + 0x300, 32);
	usleep(1000);
}

static uint32_t avp_read(uint32_t addr, int size)
{
	uint32_t cmd;
	uint32_t ret;

	switch (size) {
	case 8:
		cmd = AVP_READ8;
		break;
	case 16:
		cmd = AVP_READ16;
		break;
	case 32:
		cmd = AVP_READ32;
		break;
	default:
		abort();
	}

	assert(mem_read(AVP_ACT, 32) == AVP_IDLE);

	if (addr < MEM_END) {
		addr += AVP_UNCACHED_MEM;
	}

	mem_write(addr, AVP_ARG1, 32);
	mem_write(cmd, AVP_ACT, 32);

	avp_run();

	do {
		usleep(1);
	} while (mem_read(AVP_ACT, 32) != AVP_IDLE);

	avp_halt();

	ret = mem_read(AVP_RES, 32);

	return ret;
}

static void avp_write(uint32_t value, uint32_t addr, int size)
{
	uint32_t cmd;

	switch (size) {
	case 8:
		cmd = AVP_WRITE8;
		break;
	case 16:
		cmd = AVP_WRITE16;
		break;
	case 32:
		cmd = AVP_WRITE32;
		break;
	default:
		abort();
	}

	assert(mem_read(AVP_ACT, 32) == AVP_IDLE);

	if (addr < MEM_END) {
		addr += AVP_UNCACHED_MEM;
	}

	mem_write(value, AVP_ARG1, 32);
	mem_write(addr, AVP_ARG2, 32);
	mem_write(cmd, AVP_ACT, 32);

	avp_run();

	do {
		usleep(1);
	} while (mem_read(AVP_ACT, 32) != AVP_IDLE);

	avp_halt();
}

static void map_mem(off_t phys_address, off_t size)
{
	off_t PageOffset, PageAddress;
	size_t PagesSize;
	int mem_dev;

	mem_dev = open("/dev/mem", O_RDWR | O_SYNC);
	assert(mem_dev != -1);

	PageOffset  = phys_address % getpagesize();
	PageAddress = phys_address - PageOffset;
	PagesSize   = ((size / getpagesize()) + 1) * getpagesize();

	mem_virt = mmap(NULL, PagesSize, PROT_READ | PROT_WRITE,
			MAP_SHARED, mem_dev, PageAddress);

	assert(mem_virt != MAP_FAILED);

	mem_virt += PageOffset;

	io_addr_start = phys_address;
	io_addr_end   = phys_address + size;
}

static int get_irq_sts(int irq_nb)
{
	unsigned bank = irq_nb >> 5;
	uint32_t mask = 1 << (irq_nb & 0x1F);
	uint32_t reg = PRI_ICTLR_IRQ_LATCHED + bank * 0x100;

	return !!(mem_read(reg, 32) & mask);
}

static int record_io_size(int type)
{
	switch (type) {
	case RECORD_READ32:
	case RECORD_READ32NF:
	case RECORD_WRITE32:
		return 32;
	case RECORD_READ16:
	case RECORD_WRITE16:
		return 16;
	case RECORD_READ8:
	case RECORD_WRITE8:
		return 8;
	}

	abort();
}

static int replay(void)
{
	int step;

	for (step = 0; step < ARRAY_SIZE(Records); step++) {
		const struct record *rec = &Records[step];
		const char *rec_src = rec->avp ? "AVP" : "CPU";

		if (step < RECORD_SKIP_N_FIRST) {
			continue;
		}

		printf("Step %d: ", step);

		switch (rec->type) {
		case RECORD_IRQ:
		{
			const int irq_nb  = rec->val1;
			const int irq_sts = rec->val2;
			int retries = 40;

			printf("%s record IRQ:   %d [%s] sts=%d\n",
			       rec_src, irq_nb, rec->dsc, irq_sts);

			if (irq_sts) {
				/* Wait a bit for the IRQ trigger.  */
				while (get_irq_sts(irq_nb) != irq_sts) {
					if (!retries--) {
						break;
					}
					usleep(1000);
				}

				if (retries) {
					break;
				}
			}

			if (get_irq_sts(irq_nb) != irq_sts) {
				fprintf(stderr, "Fail: IRQ %d [%s] = %d " \
						"status mismatch\n",
					irq_nb, rec->dsc, irq_sts);
				return 4;
			}
			break;
		}
		case RECORD_READ32:
		case RECORD_READ32NF:
		case RECORD_READ16:
		case RECORD_READ8:
		{
			const int size = record_io_size(rec->type);
			const uint32_t addr = rec->val1;
			const uint32_t value = rec->val2;
			uint32_t ret;

			printf("%s record READ%d:  0x%08X [%s] = 0x%08X\n",
			       rec_src, size, addr, rec->dsc, value);

			assert(addr >= io_addr_start);
			assert(addr + (size >> 2) <= io_addr_end);

			if (rec->avp) {
				ret = avp_read(addr, size);
			} else {
				ret = cpu_read(addr, size);
			}

			if (ret != value) {
				fprintf(stderr, "Fail: %s read of " \
						"0x%08X = 0x%08X, expected 0x%08X\n",
					rec_src, addr, ret, value);

				if (rec->type != RECORD_READ32NF) {
					return 1;
				}
			}
			break;
		}
		case RECORD_WRITE32:
		case RECORD_WRITE16:
		case RECORD_WRITE8:
		{
			const int size = record_io_size(rec->type);
			const uint32_t addr = rec->val1;
			const uint32_t value = rec->val2;

			printf("%s record WRITE%d: 0x%08X [%s] = 0x%08X\n",
			       rec_src, size, addr, rec->dsc, value);

			assert(addr >= io_addr_start);
			assert(addr + (size >> 2) <= io_addr_end);

			if (rec->avp) {
				avp_write(value, addr, size);
			} else {
				cpu_write(value, addr, size);
			}
			break;
		}
		case RECORD_MEMSET32:
		{
			const uint32_t end = rec->val1 + rec->val3 * 4;
			const uint32_t value = rec->val2;
			uint32_t addr = rec->val1;

			printf("%s record MEMSET32: 0x%08X ... 0x%08X [%s] = 0x%08X\n",
			       rec_src, addr, end, rec->dsc, value);

			assert(addr >= io_addr_start);
			assert((end + 4) <= io_addr_end);

			for (; addr <= end; addr += 4) {
// 				if (rec->avp) {
// 					avp_write(value, addr, 32);
// 				} else {
					cpu_write(value, addr, 32);
// 				}
			}
			break;
		}
		case RECORD_END:
		{
			printf("Reached END\n");
			goto end;
		}
		default:
			fprintf(stderr, "Something gone wrong\n");
			return 2;
		}
	}

end:
	printf("Replay completed successfully\n");

	return 0;
}

static void prepare_avp(void)
{
	printf("Preparing AVP... ");

	stop_avp();

	memcpy(mem_virt + AVP_ENTRY_ADDR, avp_bin, avp_bin_len);

	mem_write(AVP_ENTRY_ADDR, AVP_RESET_VECTOR, 32);
	mem_write(AVP_NOP, AVP_ACT, 32);

	start_avp();

	avp_run();

	do {
		usleep(500);
	} while (mem_read(AVP_ACT, 32) != AVP_IDLE);

	avp_halt();

	printf("done\n");
}

int main(void)
{
	int ret;

	/* Disable buffered output.  */
	setbuf(stdout, NULL);

	printf("AVP entry point: 0x%08X\n", AVP_ENTRY_ADDR);

	map_mem(0x0, 0x70000000);

	prepare_avp();

	ret = replay();

	stop_avp();

	return ret;
}
