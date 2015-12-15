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
#define AVP_CODE_BASE			0x40000400
#define TEGRA_CLK_RESET_BASE		0x60006000
#define FLOW_CTRL_HALT_COP_EVENTS	0x60007004
#define FLOW_MODE_STOP			(2 << 29)
#define FLOW_MODE_NONE			0

#define PRI_ICTLR_IRQ_LATCHED		0x60004010
#define SEC_ICTLR_IRQ_LATCHED		0x60004110
#define TRI_ICTLR_IRQ_LATCHED		0x60004210
#define QUAD_ICTLR_IRQ_LATCHED		0x60004310

#define AVP_IDLE	0
#define AVP_READ	1
#define AVP_WRITE	2

#define ARRAY_SIZE(x) (sizeof(x) / sizeof((x)[0]))

static void *mem_virt;

static uint32_t mem_read(uint32_t offset)
{
	return *(volatile uint32_t*)(mem_virt + offset);
}

static void mem_write(uint32_t value, uint32_t offset)
{
	*(volatile uint32_t*)(mem_virt + offset) = value;
}

static uint32_t cpu_read(uint32_t offset)
{
	uint32_t ret = mem_read(offset);
// 	printf("CPU read:  [0x%08X] = 0x%08X\n", offset, ret);
	return ret;
}

static void cpu_write(uint32_t value, uint32_t offset)
{
// 	printf("CPU write: [0x%08X] = 0x%08X\n", offset, value);
	mem_write(value, offset);
}

static void avp_run(void)
{
	mem_write(FLOW_MODE_NONE, FLOW_CTRL_HALT_COP_EVENTS);
}

static void avp_halt(void)
{
	mem_write(FLOW_MODE_STOP, FLOW_CTRL_HALT_COP_EVENTS);
}

static void start_avp(void)
{
	printf("%s\n", __func__);
	mem_write( 1 << 1, TEGRA_CLK_RESET_BASE + 0x304);
}

static void stop_avp(void)
{
	printf("%s\n", __func__);
	avp_halt();
	mem_write(1 << 1, TEGRA_CLK_RESET_BASE + 0x300);
	usleep(1000);
}

static uint32_t avp_read(uint32_t addr)
{
	uint32_t ret;

	assert(mem_read(AVP_ACT) == AVP_IDLE);

	mem_write(addr, AVP_ARG1);
	mem_write(AVP_READ, AVP_ACT);

	avp_run();

	do {
		usleep(500);
	} while (mem_read(AVP_ACT) != AVP_IDLE);

	avp_halt();

	ret = mem_read(AVP_RES);
// 	printf("AVP read:  [0x%08X] = 0x%08X\n", addr, ret);

	return ret;
}

static void avp_write(uint32_t value, uint32_t addr)
{
// 	printf("AVP write: [0x%08X] = 0x%08X\n", addr, value);

	assert(mem_read(AVP_ACT) == AVP_IDLE);

	mem_write(value, AVP_ARG1);
	mem_write(addr, AVP_ARG2);
	mem_write(AVP_WRITE, AVP_ACT);

	avp_run();

	do {
		usleep(500);
	} while (mem_read(AVP_ACT) != AVP_IDLE);

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

	mem_virt += PageOffset >> 2;
}

static int irq_sts(int irq_nb)
{
	int bank = irq_nb >> 5;
	uint32_t reg;
	int mask;

	switch (bank) {
	case 0:
		reg = PRI_ICTLR_IRQ_LATCHED;
		mask = 1 << irq_nb;
		break;
	case 1:
		reg = SEC_ICTLR_IRQ_LATCHED;
		mask = 1 << (irq_nb - 32);
		break;
	case 2:
		reg = TRI_ICTLR_IRQ_LATCHED;
		mask = 1 << (irq_nb - 64);
		break;
	case 3:
		reg = QUAD_ICTLR_IRQ_LATCHED;
		mask = 1 << (irq_nb - 96);
		break;
	default:
		/* Should never happen.  */
		abort();
	}

	return !!(mem_read(reg) & mask);
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

		switch (rec->type & 0x000FFFFF) {
		case RECORD_IRQ:
		{
			printf("%s record IRQ:   %d [%s] sts=%d\n",
			       rec_src, rec->val1, rec->dsc, rec->val2);

			usleep(1000);

			if (irq_sts(rec->val1) != rec->val2) {
				fprintf(stderr, "Fail: IRQ %d [%s] = %d " \
						"status mismatch\n",
					rec->val1, rec->dsc, rec->val2);

				if (!(rec->type & RECORD_NOFAIL)) {
					return 1;
				}
			}
			break;
		}
		case RECORD_READ:
		{
			uint32_t ret;

			printf("%s record READ:  0x%08X [%s] = 0x%08X\n",
			       rec_src, rec->val1, rec->dsc, rec->val2);

			if (rec->avp) {
				ret = avp_read(rec->val1);
			} else {
				ret = cpu_read(rec->val1);
			}

			if (ret != rec->val2) {
				fprintf(stderr, "Fail: %s read of " \
						"0x%08X = 0x%08X, expected 0x%08X\n",
					rec_src, rec->val1, ret, rec->val2);

				if (!(rec->type & RECORD_NOFAIL)) {
					return 1;
				}
			}
			break;
		}
		case RECORD_WRITE:
		{
			printf("%s record WRITE: 0x%08X [%s] = 0x%08X\n",
			       rec_src, rec->val1, rec->dsc, rec->val2);

			if (rec->avp) {
				avp_write(rec->val2, rec->val1);
			} else {
				cpu_write(rec->val2, rec->val1);
				usleep(1000);
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

int main(void)
{
	int ret;

	printf("AVP entry point: 0x%08X\n", AVP_ENTRY_ADDR);

	map_mem(0x0, 0x70000000);

	stop_avp();

	memcpy(mem_virt + AVP_CODE_BASE, avp_bin, avp_bin_len);

	mem_write(AVP_ENTRY_ADDR, AVP_RESET_VECTOR);
	mem_write(AVP_IDLE, AVP_ACT);

	start_avp();

	ret = replay();

	stop_avp();

	return ret;
}
