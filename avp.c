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

#define AVP_IDLE	0
#define AVP_READ	1
#define AVP_WRITE	2

static uint32_t stack[1024];

volatile uint32_t avp_arg1;
volatile uint32_t avp_arg2;
volatile uint32_t avp_res;
volatile uint32_t avp_act;

static void mem_write(uint32_t value, uint32_t addr)
{
	*(volatile uint32_t*)(addr) = value;
}

static uint32_t mem_read(uint32_t addr)
{
	return *(volatile uint32_t*)(addr);
}

void __attribute__((naked)) avp_start(void)
{
	void *sp = stack + sizeof(stack);

	asm volatile("mov sp, %0\n\t" :: "r" (sp));

	for (;;) {
		switch (avp_act) {
		case AVP_READ:
			avp_res = mem_read(avp_arg1);
			asm volatile("" ::: "memory");
			avp_act = AVP_IDLE;
			break;
		case AVP_WRITE:
			mem_write(avp_arg1, avp_arg2);
			asm volatile("" ::: "memory");
			avp_act = AVP_IDLE;
			break;
		default:
			break;
		}
	}
}
