#pragma once
/*
 * Per-platform constants. Select with -DPLATFORM_SWEET (default) or
 * -DPLATFORM_HAYDN (build.sh PLATFORM=...). The default must stay sweet so
 * an unconfigured build keeps producing the same sweet image.
 *
 * haydn sources: live DT dump backup/haydn/haydn-dump/haydn-dt.txt (gitignored).
 */
#if defined(PLATFORM_HAYDN)

/* Redmi K40 Pro (haydn), SM8350 lahaina. */
#define PLATFORM_NAME		"haydn"

/* reserved-memory splash_region: reg = <0 0xdfc00000 0 0x2300000> */
#define FB_BASE			0xdfc00000UL
#define FB_W			1080	/* qcom,mdss_dsi_k11_38_08_0a_dsc_cmd */
#define FB_H			2400

/* qcom,msm-imem@146bf000, restart_reason@65c */
#define IMEM_RESTART_REASON	0x146bf65cUL
/* No pshold node in the lahaina DT and not yet verified against Xiaomi
 * kernel source: reset relies on PSCI SYSTEM_RESET only. */

/* gic@17a00000: reg = <0x17a00000 0x10000 0x17a60000 0x100000> (same as sweet) */
#define GICD_BASE		0x17a00000UL
#define GICR_BASE		0x17a60000UL

/* arch_timer: standard ARM PPIs (vtimer PPI 11, ptimer PPI 14) */
#define VTIMER_INTID		27
#define PTIMER_INTID		30

#define UFS_BASE		0x01d84000UL	/* ufshc@1d84000, same base as sweet */

#define NR_CPUS			8	/* 1xX1 + 3xA78 + 4xA55 */

#else

/* Redmi Note 10 Pro (sweet), SM7150. */
#define PLATFORM_NAME		"sweet"

#define FB_BASE			0x9c000000UL	/* reserved-memory cont_splash_region */
#define FB_W			1080
#define FB_H			2400

#define IMEM_RESTART_REASON	0x146aa65cUL	/* qcom,msm-imem restart_reason@65c */
#define PLATFORM_PSHOLD		0x0c264000UL	/* ABSENT on haydn until verified */

#define GICD_BASE		0x17a00000UL
#define GICR_BASE		0x17a60000UL

#define VTIMER_INTID		19	/* DT: <GIC_PPI 3 ...>, not the usual 27 */
#define PTIMER_INTID		18	/* DT: <GIC_PPI 2 ...> */

#define UFS_BASE		0x01d84000UL	/* ufshc@1d84000, sweet live FDT */

#define NR_CPUS			8

#endif

#define FB_STRIDE		(FB_W * 4)	/* a8r8g8b8, matches mainline simplefb */
