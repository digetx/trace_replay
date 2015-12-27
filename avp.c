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

#include <stdint.h>

#define AVP_NOP		0xFF
#define AVP_IDLE	0
#define AVP_READ8	1
#define AVP_READ16	2
#define AVP_READ32	3
#define AVP_WRITE8	4
#define AVP_WRITE16	5
#define AVP_WRITE32	6

volatile uint32_t avp_arg1;
volatile uint32_t avp_arg2;
volatile uint32_t avp_res;
volatile uint32_t avp_act;

static __always_inline void mem_write32(uint32_t value, uint32_t addr)
{
	*(volatile uint32_t*)(addr) = value;
}

static __always_inline uint32_t mem_read32(uint32_t addr)
{
	return *(volatile uint32_t*)(addr);
}

static __always_inline void mem_write16(uint32_t value, uint32_t addr)
{
	*(volatile uint16_t*)(addr) = value;
}

static __always_inline uint32_t mem_read16(uint32_t addr)
{
	return *(volatile uint16_t*)(addr);
}

static __always_inline void mem_write8(uint32_t value, uint32_t addr)
{
	*(volatile uint8_t*)(addr) = value;
}

static __always_inline uint32_t mem_read8(uint32_t addr)
{
	return *(volatile uint8_t*)(addr);
}

void __attribute__((naked)) avp_start(void)
{
	uint32_t arg1, arg2;

	for (;;) {
		while (avp_act == AVP_IDLE)
			;

		arg1 = avp_arg1;
		arg2 = avp_arg2;

		switch (avp_act) {
		case AVP_READ8:
			avp_res = mem_read8(arg1);
			break;

		case AVP_WRITE8:
			mem_write8(arg1, arg2);
			break;

		case AVP_READ16:
			avp_res = mem_read16(arg1);
			break;

		case AVP_WRITE16:
			mem_write16(arg1, arg2);
			break;

		case AVP_READ32:
			avp_res = mem_read32(arg1);
			break;

		case AVP_WRITE32:
			mem_write32(arg1, arg2);
			break;

		default:
			break;
		}

		avp_act = AVP_IDLE;
	}
}
