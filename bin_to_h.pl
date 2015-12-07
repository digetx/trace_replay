#!/usr/bin/perl

use strict;
use warnings;

use feature "switch";
no warnings 'experimental::smartmatch';

my @defines = ('RECORD_IRQ', 'RECORD_READ', 'RECORD_WRITE');

open(BINFILE, "<".$ARGV[0]) or die "cannot open $!";

my $version;
read BINFILE, $version, 4;
$version = unpack('N', $version);

die "Record version mismatch" if ($version != 06122015);

open(TXTFILE, ">".$ARGV[1]) or die "cannot open $!";

print TXTFILE <<H_HEAD;
#define RECORD_IRQ      0
#define RECORD_READ     1
#define RECORD_WRITE    2
#define RECORD_END      3
#define RECORD_NOFAIL   (1 << 31)
#define RECORD_READNF   (RECORD_READ | RECORD_NOFAIL)

#define ON_CPU  0
#define ON_AVP  1

#define RECORD_SKIP_N_FIRST 0

static struct record {
    const uint32_t avp;
    const uint32_t type;
    const uint32_t val1;
    const uint32_t val2;
    const char *dsc;
} Records[] = {
H_HEAD

my $record;
my $step;

for ($step = 0; read(BINFILE, $record, 13) > 0; $step++) {
    my ($src, $type, $val1, $val2) = unpack 'cNNN', $record;

    if ($type >= scalar(@defines)) {
        close(TXTFILE) && unlink $ARGV[1];
        die "Wrong record type $type";
    }

    $src = ($src == 1) ? "ON_AVP" : "ON_CPU";
    my $dsc = ($type == 0) ? irq_to_name($val1) : reg_addr_to_name($val1);
    printf TXTFILE ("    {%s, %s,\t0x%08X, 0x%08X, \"$dsc\"}, // Step: %d\n",
                    $src, $defines[$type], $val1, $val2, $step);
}

print TXTFILE "};\n";

sub reg_addr_to_name {
    given (shift) {
        when (0x60006000) { return "CLK_RST_CONTROLLER_RST_SOURCE_0"; }
        when (0x60006004) { return "CLK_RST_CONTROLLER_RST_DEVICES_L_0"; }
        when (0x60006008) { return "CLK_RST_CONTROLLER_RST_DEVICES_H_0"; }
        when (0x6000600C) { return "CLK_RST_CONTROLLER_RST_DEVICES_U_0"; }
        when (0x60006010) { return "CLK_RST_CONTROLLER_CLK_OUT_ENB_L_0"; }
        when (0x60006014) { return "CLK_RST_CONTROLLER_CLK_OUT_ENB_H_0"; }
        when (0x60006018) { return "CLK_RST_CONTROLLER_CLK_OUT_ENB_U_0"; }
        when (0x60006020) { return "CLK_RST_CONTROLLER_CCLK_BURST_POLICY_0"; }
        when (0x60006024) { return "CLK_RST_CONTROLLER_SUPER_CCLK_DIVIDER_0"; }
        when (0x60006028) { return "CLK_RST_CONTROLLER_SCLK_BURST_POLICY_0"; }
        when (0x6000602C) { return "CLK_RST_CONTROLLER_SUPER_SCLK_DIVIDER_0"; }
        when (0x60006030) { return "CLK_RST_CONTROLLER_CLK_SYSTEM_RATE_0"; }
        when (0x60006034) { return "CLK_RST_CONTROLLER_PROG_DLY_CLK_0"; }
        when (0x60006038) { return "CLK_RST_CONTROLLER_AUDIO_SYNC_CLK_RATE_0"; }
        when (0x60006040) { return "CLK_RST_CONTROLLER_COP_CLK_SKIP_POLICY_0"; }
        when (0x60006044) { return "CLK_RST_CONTROLLER_CLK_MASK_ARM_0"; }
        when (0x60006048) { return "CLK_RST_CONTROLLER_MISC_CLK_ENB_0"; }
        when (0x6000604C) { return "CLK_RST_CONTROLLER_CLK_CPU_CMPLX_0"; }
        when (0x60006050) { return "CLK_RST_CONTROLLER_OSC_CTRL_0"; }
        when (0x60006054) { return "CLK_RST_CONTROLLER_PLL_LFSR_0"; }
        when (0x60006058) { return "CLK_RST_CONTROLLER_OSC_FREQ_DET_0"; }
        when (0x6000605C) { return "CLK_RST_CONTROLLER_OSC_FREQ_DET_STATUS_0"; }
        when (0x60006080) { return "CLK_RST_CONTROLLER_PLLC_BASE_0"; }
        when (0x60006084) { return "CLK_RST_CONTROLLER_PLLC_OUT_0"; }
        when (0x6000608C) { return "CLK_RST_CONTROLLER_PLLC_MISC_0"; }
        when (0x60006090) { return "CLK_RST_CONTROLLER_PLLM_BASE_0"; }
        when (0x60006094) { return "CLK_RST_CONTROLLER_PLLM_OUT_0"; }
        when (0x6000609C) { return "CLK_RST_CONTROLLER_PLLM_MISC_0"; }
        when (0x600060A0) { return "CLK_RST_CONTROLLER_PLLP_BASE_0"; }
        when (0x600060A4) { return "CLK_RST_CONTROLLER_PLLP_OUTA_0"; }
        when (0x600060A8) { return "CLK_RST_CONTROLLER_PLLP_OUTB_0"; }
        when (0x600060AC) { return "CLK_RST_CONTROLLER_PLLP_MISC_0"; }
        when (0x600060B0) { return "CLK_RST_CONTROLLER_PLLA_BASE_0"; }
        when (0x600060B4) { return "CLK_RST_CONTROLLER_PLLA_OUT_0"; }
        when (0x600060BC) { return "CLK_RST_CONTROLLER_PLLA_MISC_0"; }
        when (0x600060C0) { return "CLK_RST_CONTROLLER_PLLU_BASE_0"; }
        when (0x600060CC) { return "CLK_RST_CONTROLLER_PLLU_MISC_0"; }
        when (0x600060D0) { return "CLK_RST_CONTROLLER_PLLD_BASE_0"; }
        when (0x600060DC) { return "CLK_RST_CONTROLLER_PLLD_MISC_0"; }
        when (0x600060E0) { return "CLK_RST_CONTROLLER_PLLX_BASE_0"; }
        when (0x600060E4) { return "CLK_RST_CONTROLLER_PLLX_MISC_0"; }
        when (0x600060E8) { return "CLK_RST_CONTROLLER_PLLE_BASE_0"; }
        when (0x600060EC) { return "CLK_RST_CONTROLLER_PLLE_MISC_0"; }
        when (0x60006100) { return "CLK_RST_CONTROLLER_CLK_SOURCE_I2S1_0"; }
        when (0x60006104) { return "CLK_RST_CONTROLLER_CLK_SOURCE_I2S2_0"; }
        when (0x60006108) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SPDIF_OUT_0"; }
        when (0x6000610C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SPDIF_IN_0"; }
        when (0x60006110) { return "CLK_RST_CONTROLLER_CLK_SOURCE_PWM_0"; }
        when (0x60006114) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SPI1_0"; }
        when (0x60006118) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SPI22_0"; }
        when (0x6000611C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SPI3_0"; }
        when (0x60006120) { return "CLK_RST_CONTROLLER_CLK_SOURCE_XIO_0"; }
        when (0x60006124) { return "CLK_RST_CONTROLLER_CLK_SOURCE_I2C1_0"; }
        when (0x60006128) { return "CLK_RST_CONTROLLER_CLK_SOURCE_DVC_I2C_0"; }
        when (0x6000612C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_TWC_0"; }
        when (0x60006134) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SPI1_0"; }
        when (0x60006138) { return "CLK_RST_CONTROLLER_CLK_SOURCE_DISP1_0"; }
        when (0x6000613C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_DISP2_0"; }
        when (0x60006140) { return "CLK_RST_CONTROLLER_CLK_SOURCE_CVE_0"; }
        when (0x60006144) { return "CLK_RST_CONTROLLER_CLK_SOURCE_IDE_0"; }
        when (0x60006148) { return "CLK_RST_CONTROLLER_CLK_SOURCE_VI_0"; }
        when (0x60006150) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SDMMC1_0"; }
        when (0x60006154) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SDMMC2_0"; }
        when (0x60006158) { return "CLK_RST_CONTROLLER_CLK_SOURCE_G3D_0"; }
        when (0x6000615C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_G2D_0"; }
        when (0x60006160) { return "CLK_RST_CONTROLLER_CLK_SOURCE_NDFLASH_0"; }
        when (0x60006164) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SDMMC4_0"; }
        when (0x60006168) { return "CLK_RST_CONTROLLER_CLK_SOURCE_VFIR_0"; }
        when (0x6000616C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_EPP_0"; }
        when (0x60006170) { return "CLK_RST_CONTROLLER_CLK_SOURCE_MPE_0"; }
        when (0x60006174) { return "CLK_RST_CONTROLLER_CLK_SOURCE_MIPI_0"; }
        when (0x60006178) { return "CLK_RST_CONTROLLER_CLK_SOURCE_UART1_0"; }
        when (0x6000617C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_UART2_0"; }
        when (0x60006180) { return "CLK_RST_CONTROLLER_CLK_SOURCE_HOST1X_0"; }
        when (0x60006188) { return "CLK_RST_CONTROLLER_CLK_SOURCE_TVO_0"; }
        when (0x6000618C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_HDMI_0"; }
        when (0x60006194) { return "CLK_RST_CONTROLLER_CLK_SOURCE_TVDAC_0"; }
        when (0x60006198) { return "CLK_RST_CONTROLLER_CLK_SOURCE_I2C2_0"; }
        when (0x6000619C) { return "CLK_RST_CONTROLLER_CLK_SOURCE_EMC_0"; }
        when (0x600061A0) { return "CLK_RST_CONTROLLER_CLK_SOURCE_UART3_0"; }
        when (0x600061A8) { return "CLK_RST_CONTROLLER_CLK_SOURCE_VI_SENSOR_0"; }
        when (0x600061B4) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SPI4_0"; }
        when (0x600061B8) { return "CLK_RST_CONTROLLER_CLK_SOURCE_I2C3_0"; }
        when (0x600061BC) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SDMMC3_0"; }
        when (0x600061C0) { return "CLK_RST_CONTROLLER_CLK_SOURCE_UART4_0"; }
        when (0x600061C4) { return "CLK_RST_CONTROLLER_CLK_SOURCE_UART5_0"; }
        when (0x600061C8) { return "CLK_RST_CONTROLLER_CLK_SOURCE_VDE_0"; }
        when (0x600061CC) { return "CLK_RST_CONTROLLER_CLK_SOURCE_OWR_0"; }
        when (0x600061D0) { return "CLK_RST_CONTROLLER_CLK_SOURCE_NOR_0"; }
        when (0x600061D4) { return "CLK_RST_CONTROLLER_CLK_SOURCE_CSITE_0"; }
        when (0x600061FC) { return "CLK_RST_CONTROLLER_CLK_SOURCE_OSC_0"; }
        when (0x60006300) { return "CLK_RST_CONTROLLER_RST_DEV_L_SET_0"; }
        when (0x60006304) { return "CLK_RST_CONTROLLER_RST_DEV_L_CLR_0"; }
        when (0x60006308) { return "CLK_RST_CONTROLLER_RST_DEV_H_SET_0"; }
        when (0x6000630C) { return "CLK_RST_CONTROLLER_RST_DEV_H_CLR_0"; }
        when (0x60006310) { return "CLK_RST_CONTROLLER_RST_DEV_U_SET_0"; }
        when (0x60006314) { return "CLK_RST_CONTROLLER_RST_DEV_U_CLR_0"; }
        when (0x60006320) { return "CLK_RST_CONTROLLER_CLK_ENB_L_SET_0"; }
        when (0x60006324) { return "CLK_RST_CONTROLLER_CLK_ENB_L_CLR_0"; }
        when (0x60006328) { return "CLK_RST_CONTROLLER_CLK_ENB_H_SET_0"; }
        when (0x6000632C) { return "CLK_RST_CONTROLLER_CLK_ENB_H_CLR_0"; }
        when (0x60006330) { return "CLK_RST_CONTROLLER_CLK_ENB_U_SET_0"; }
        when (0x60006334) { return "CLK_RST_CONTROLLER_CLK_ENB_U_CLR_0"; }
        when (0x60006340) { return "CLK_RST_CONTROLLER_RST_CPU_CMPLX_SET_0"; }
        when (0x60006344) { return "CLK_RST_CONTROLLER_RST_CPU_CMPLX_CLR_0"; }
        when (0x60006134) { return "CLK_RST_CONTROLLER_CLK_SOURCE_SBC1_0"; }
        when (0x600061F8) { return "CLK_RST_CONTROLLER_CLK_SOURCE_LA_0"; }
        when (0x6001B000) { return "ARVDE_BSEV_ICMDQUE_WR_0"; }
        when (0x6001B008) { return "ARVDE_BSEV_CMDQUE_CONTROL_0"; }
        when (0x6001B018) { return "ARVDE_BSEV_INTR_STATUS_0"; }
        when (0x6001B044) { return "ARVDE_BSEV_BSE_CONFIG_0"; }
        when (0x6001B100) { return "ARVDE_BSEV_SECURE_DEST_ADDR_0"; }
        when (0x6001B104) { return "ARVDE_BSEV_SECURE_INPUT_SELECT_0"; }
        when (0x6001B108) { return "ARVDE_BSEV_SECURE_CONFIG_0"; }
        when (0x6001B10C) { return "ARVDE_BSEV_SECURE_CONFIG_EXT_0"; }
        when (0x6001B110) { return "ARVDE_BSEV_SECURE_SECURITY_0"; }
        when (0x6001B120) { return "ARVDE_BSEV_SECURE_HASH_RESULT0_0"; }
        when (0x6001B124) { return "ARVDE_BSEV_SECURE_HASH_RESULT1_0"; }
        when (0x6001B128) { return "ARVDE_BSEV_SECURE_HASH_RESULT2_0"; }
        when (0x6001B12C) { return "ARVDE_BSEV_SECURE_HASH_RESULT3_0"; }
        when (0x6001B140) { return "ARVDE_BSEV_SECURE_SEC_SEL0_0"; }
        when (0x6001B144) { return "ARVDE_BSEV_SECURE_SEC_SEL1_0"; }
        when (0x6001B148) { return "ARVDE_BSEV_SECURE_SEC_SEL2_0"; }
        when (0x6001B14C) { return "ARVDE_BSEV_SECURE_SEC_SEL3_0"; }
        when (0x6001B150) { return "ARVDE_BSEV_SECURE_SEC_SEL4_0"; }
        when (0x6001B154) { return "ARVDE_BSEV_SECURE_SEC_SEL5_0"; }
        when (0x6001B158) { return "ARVDE_BSEV_SECURE_SEC_SEL6_0"; }
        when (0x6001B15C) { return "ARVDE_BSEV_SECURE_SEC_SEL7_0"; }
        when ([0x60010000..0x600100FF]) { return "UCQ" }
        when ([0x60011000..0x60011FFF]) { return "BSEA" }
        when ([0x6001A000..0x6001AFFF]) { return "SXE" }
        when ([0x6001B000..0x6001BFFF]) { return "BSEV Unknown" }
        when ([0x6001C000..0x6001C0FF]) { return "MBE" }
        when ([0x6001C200..0x6001C2FF]) { return "PPE" }
        when ([0x6001C400..0x6001C4FF]) { return "MCE" }
        when ([0x6001C600..0x6001C6FF]) { return "TFE" }
        when ([0x6001C800..0x6001C8FF]) { return "PPB" }
        when ([0x6001CA00..0x6001CAFF]) { return "VDMA" }
        when ([0x6001CC00..0x6001CCFF]) { return "UCQ2" }
        when ([0x6001D000..0x6001D7FF]) { return "BSEA2" }
        when ([0x6001D800..0x6001DAFF]) { return "FRAMEID" }
    }

    return "Unknown register";
}

sub irq_to_name {
    my $irq = shift;

    given ($irq) {
        when (0) { return "INT_TMR1"; }
        when (1) { return "INT_TMR2"; }
        when (2) { return "INT_RTC	"; }
        when (3) { return "INT_I2S2"; }
        when (4) { return "INT_SHR_SEM_INBOX_IBF"; }
        when (5) { return "INT_SHR_SEM_INBOX_IBE"; }
        when (6) { return "INT_SHR_SEM_OUTBOX_IBF"; }
        when (7) { return "INT_SHR_SEM_OUTBOX_IBE"; }
        when (8) { return "INT_VDE_UCQ_ERROR"; }
        when (9) { return "INT_VDE_SYNC_TOKEN"; }
        when (10) { return "INT_VDE_BSE_V"; }
        when (11) { return "INT_VDE_BSE_A"; }
        when (12) { return "INT_VDE_SXE"; }
        when (13) { return "INT_I2S1"; }
        when (14) { return "INT_SDMMC1"; }
        when (15) { return "INT_SDMMC2"; }
        when (16) { return "INT_XIO	"; }
        when (17) { return "INT_VDE	"; }
        when (18) { return "INT_AVP_UCQ"; }
        when (19) { return "INT_SDMMC3"; }
        when (20) { return "INT_USB	"; }
        when (21) { return "INT_USB2"; }
        when (22) { return "INT_PRI_RES_22"; }
        when (23) { return "INT_EIDE"; }
        when (24) { return "INT_NANDFLASH"; }
        when (25) { return "INT_VCP	"; }
        when (26) { return "INT_APB_DMA"; }
        when (27) { return "INT_AHB_DMA"; }
        when (28) { return "INT_GNT_0"; }
        when (29) { return "INT_GNT_1"; }
        when (30) { return "INT_OWR	"; }
        when (31) { return "INT_SDMMC4"; }
        when (32) { return "INT_GPIO1"; }
        when (33) { return "INT_GPIO2"; }
        when (34) { return "INT_GPIO3"; }
        when (35) { return "INT_GPIO4"; }
        when (36) { return "INT_UARTA"; }
        when (37) { return "INT_UARTB"; }
        when (38) { return "INT_I2C	"; }
        when (39) { return "INT_SPI	"; }
        when (40) { return "INT_TWC	"; }
        when (41) { return "INT_TMR3"; }
        when (42) { return "INT_TMR4"; }
        when (43) { return "INT_FLOW_RSM0"; }
        when (44) { return "INT_FLOW_RSM1"; }
        when (45) { return "INT_SPDIF"; }
        when (46) { return "INT_UARTC"; }
        when (47) { return "INT_MIPI"; }
        when (48) { return "INT_EVENTA"; }
        when (49) { return "INT_EVENTB"; }
        when (50) { return "INT_EVENTC"; }
        when (51) { return "INT_EVENTD"; }
        when (52) { return "INT_VFIR"; }
        when (53) { return "INT_DVC"; }
        when (54) { return "INT_SYS_STATS_MON"; }
        when (55) { return "INT_GPIO5"; }
        when (56) { return "INT_CPU0_PMU_INTR"; }
        when (57) { return "INT_CPU1_PMU_INTR"; }
        when (58) { return "INT_SEC_RES_26"; }
        when (59) { return "INT_SPI_1"; }
        when (60) { return "INT_APB_DMA_COP"; }
        when (61) { return "INT_AHB_DMA_COP"; }
        when (62) { return "INT_DMA_TX"; }
        when (63) { return "INT_DMA_RX"; }
        when (64) { return "INT_HOST1X_COP_SYNCPT"; }
        when (65) { return "INT_HOST1X_MPCORE_SYNCPT"; }
        when (66) { return "INT_HOST1X_COP_GENERAL"; }
        when (67) { return "INT_HOST1X_MPCORE_GENERAL"; }
        when (68) { return "INT_MPE_GENERAL"; }
        when (69) { return "INT_VI_GENERAL"; }
        when (70) { return "INT_EPP_GENERAL"; }
        when (71) { return "INT_ISP_GENERAL"; }
        when (72) { return "INT_2D_GENERAL"; }
        when (73) { return "INT_DISPLAY_GENERAL"; }
        when (74) { return "INT_DISPLAY_B_GENERAL"; }
        when (75) { return "INT_HDMI"; }
        when (76) { return "INT_TVO_GENERAL"; }
        when (77) { return "INT_MC_GENERAL"; }
        when (78) { return "INT_EMC_GENERAL"; }
        when (79) { return "INT_TRI_RES_15"; }
        when (80) { return "INT_TRI_RES_16"; }
        when (81) { return "INT_AC97"; }
        when (82) { return "INT_SPI_2"; }
        when (83) { return "INT_SPI_3"; }
        when (84) { return "INT_I2C2"; }
        when (85) { return "INT_KBC	"; }
        when (86) { return "INT_EXTERNAL_PMU"; }
        when (87) { return "INT_GPIO6"; }
        when (88) { return "INT_TVDAC"; }
        when (89) { return "INT_GPIO7"; }
        when (90) { return "INT_UARTD"; }
        when (91) { return "INT_UARTE"; }
        when (92) { return "INT_I2C3"; }
        when (93) { return "INT_SPI_4"; }
        when (94) { return "INT_TRI_RES_30"; }
        when (95) { return "INT_SW_RESERVED"; }
        when (96) { return "INT_SNOR"; }
        when (97) { return "INT_USB3"; }
        when (98) { return "INT_PCIE_INTR"; }
        when (99) { return "INT_PCIE_MSI"; }
        when (100) { return "INT_QUAD_RES_4"; }
        when (101) { return "INT_QUAD_RES_5"; }
        when (102) { return "INT_QUAD_RES_6"; }
        when (103) { return "INT_QUAD_RES_7"; }
        when (104) { return "INT_APB_DMA_CH0"; }
        when (105) { return "INT_APB_DMA_CH1"; }
        when (106) { return "INT_APB_DMA_CH2"; }
        when (107) { return "INT_APB_DMA_CH3"; }
        when (108) { return "INT_APB_DMA_CH4"; }
        when (109) { return "INT_APB_DMA_CH5"; }
        when (110) { return "INT_APB_DMA_CH6"; }
        when (111) { return "INT_APB_DMA_CH7"; }
        when (112) { return "INT_APB_DMA_CH8"; }
        when (113) { return "INT_APB_DMA_CH9"; }
        when (114) { return "INT_APB_DMA_CH10"; }
        when (115) { return "INT_APB_DMA_CH11"; }
        when (116) { return "INT_APB_DMA_CH12"; }
        when (117) { return "INT_APB_DMA_CH13"; }
        when (118) { return "INT_APB_DMA_CH14"; }
        when (119) { return "INT_APB_DMA_CH15"; }
        when (120) { return "INT_QUAD_RES_24"; }
        when (121) { return "INT_QUAD_RES_25"; }
        when (122) { return "INT_QUAD_RES_26"; }
        when (123) { return "INT_QUAD_RES_27"; }
        when (124) { return "INT_QUAD_RES_28"; }
        when (125) { return "INT_QUAD_RES_29"; }
        when (126) { return "INT_QUAD_RES_30"; }
        when (127) { return "INT_QUAD_RES_31"; }
    }

    die "Bad IRQ number $irq step $step\n";
}
