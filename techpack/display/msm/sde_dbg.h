/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (c) 2016-2020, The Linux Foundation. All rights reserved.
 */

#ifndef SDE_DBG_H_
#define SDE_DBG_H_

#include <stdarg.h>
#include <linux/debugfs.h>
#include <linux/list.h>

/* select an uncommon hex value for the limiter */
#define SDE_EVTLOG_DATA_LIMITER	(0xC0DEBEEF)
#define SDE_EVTLOG_FUNC_ENTRY	0x1111
#define SDE_EVTLOG_FUNC_EXIT	0x2222
#define SDE_EVTLOG_FUNC_CASE1	0x3333
#define SDE_EVTLOG_FUNC_CASE2	0x4444
#define SDE_EVTLOG_FUNC_CASE3	0x5555
#define SDE_EVTLOG_FUNC_CASE4	0x6666
#define SDE_EVTLOG_FUNC_CASE5	0x7777
#define SDE_EVTLOG_FUNC_CASE6	0x8888
#define SDE_EVTLOG_FUNC_CASE7	0x9999
#define SDE_EVTLOG_FUNC_CASE8	0xaaaa
#define SDE_EVTLOG_FUNC_CASE9	0xbbbb
#define SDE_EVTLOG_FUNC_CASE10	0xcccc
#define SDE_EVTLOG_PANIC	0xdead
#define SDE_EVTLOG_FATAL	0xbad
#define SDE_EVTLOG_ERROR	0xebad

#define SDE_DBG_DUMP_DATA_LIMITER (NULL)

enum sde_dbg_evtlog_flag {
	SDE_EVTLOG_CRITICAL = BIT(0),
	SDE_EVTLOG_IRQ = BIT(1),
	SDE_EVTLOG_VERBOSE = -1,
	SDE_EVTLOG_EXTERNAL = BIT(3),
	SDE_EVTLOG_ALWAYS = -1
};

enum sde_dbg_dump_flag {
	SDE_DBG_DUMP_IN_LOG = BIT(0),
	SDE_DBG_DUMP_IN_MEM = BIT(1),
};

enum sde_dbg_dump_context {
	SDE_DBG_DUMP_PROC_CTX,
	SDE_DBG_DUMP_IRQ_CTX,
	SDE_DBG_DUMP_CLK_ENABLED_CTX,
};

#define SDE_EVTLOG_DEFAULT_ENABLE (SDE_EVTLOG_CRITICAL | SDE_EVTLOG_IRQ | \
		SDE_EVTLOG_EXTERNAL)

/*
 * evtlog will print this number of entries when it is called through
 * sysfs node or panic. This prevents kernel log from evtlog message
 * flood.
 */
#define SDE_EVTLOG_PRINT_ENTRY	256

/*
 * evtlog keeps this number of entries in memory for debug purpose. This
 * number must be greater than print entry to prevent out of bound evtlog
 * entry array access.
 */
#define SDE_EVTLOG_ENTRY	(SDE_EVTLOG_PRINT_ENTRY * 32)
#define SDE_EVTLOG_MAX_DATA 15
#define SDE_EVTLOG_BUF_MAX 512
#define SDE_EVTLOG_BUF_ALIGN 32

struct sde_dbg_power_ctrl {
	void *handle;
	void *client;
	int (*enable_fn)(void *handle, void *client, bool enable);
};

struct sde_dbg_evtlog_log {
	s64 time;
	const char *name;
	int line;
	u32 data[SDE_EVTLOG_MAX_DATA];
	u32 data_cnt;
	int pid;
	u8 cpu;
};

/**
 * @last_dump: Index of last entry to be output during evtlog dumps
 * @filter_list: Linked list of currently active filter strings
 */
struct sde_dbg_evtlog {
	struct sde_dbg_evtlog_log logs[SDE_EVTLOG_ENTRY];
	u32 first;
	u32 last;
	u32 last_dump;
	u32 curr;
	u32 next;
	u32 enable;
	spinlock_t spin_lock;
	struct list_head filter_list;
};

extern struct sde_dbg_evtlog *sde_dbg_base_evtlog;

/**
 * SDE_EVT32 - Write a list of 32bit values to the event log, default area
 * ... - variable arguments
 */
#define SDE_EVT32(...) sde_evtlog_log(sde_dbg_base_evtlog, __func__, \
		__LINE__, SDE_EVTLOG_ALWAYS, ##__VA_ARGS__, \
		SDE_EVTLOG_DATA_LIMITER)

/**
 * SDE_EVT32_VERBOSE - Write a list of 32bit values for verbose event logging
 * ... - variable arguments
 */
#define SDE_EVT32_VERBOSE(...) sde_evtlog_log(sde_dbg_base_evtlog, __func__, \
		__LINE__, SDE_EVTLOG_VERBOSE, ##__VA_ARGS__, \
		SDE_EVTLOG_DATA_LIMITER)

/**
 * SDE_EVT32_IRQ - Write a list of 32bit values to the event log, IRQ area
 * ... - variable arguments
 */
#define SDE_EVT32_IRQ(...) sde_evtlog_log(sde_dbg_base_evtlog, __func__, \
		__LINE__, SDE_EVTLOG_IRQ, ##__VA_ARGS__, \
		SDE_EVTLOG_DATA_LIMITER)

/**
 * SDE_EVT32_EXTERNAL - Write a list of 32bit values for external display events
 * ... - variable arguments
 */
#define SDE_EVT32_EXTERNAL(...) sde_evtlog_log(sde_dbg_base_evtlog, __func__, \
		__LINE__, SDE_EVTLOG_EXTERNAL, ##__VA_ARGS__, \
		SDE_EVTLOG_DATA_LIMITER)

/**
 * SDE_DBG_DUMP - trigger dumping of all sde_dbg facilities
 * @va_args:	list of named register dump ranges and regions to dump, as
 *		registered previously through sde_dbg_reg_register_base and
 *		sde_dbg_reg_register_dump_range.
 *		Including the special name "panic" will trigger a panic after
 *		the dumping work has completed.
 */
#define SDE_DBG_DUMP(...) sde_dbg_dump(SDE_DBG_DUMP_PROC_CTX, __func__, \
		##__VA_ARGS__, SDE_DBG_DUMP_DATA_LIMITER)

/**
 * SDE_DBG_DUMP_WQ - trigger dumping of all sde_dbg facilities, queuing the work
 * @va_args:	list of named register dump ranges and regions to dump, as
 *		registered previously through sde_dbg_reg_register_base and
 *		sde_dbg_reg_register_dump_range.
 *		Including the special name "panic" will trigger a panic after
 *		the dumping work has completed.
 */
#define SDE_DBG_DUMP_WQ(...) sde_dbg_dump(SDE_DBG_DUMP_IRQ_CTX, __func__, \
		##__VA_ARGS__, SDE_DBG_DUMP_DATA_LIMITER)

/**
 * SDE_DBG_DUMP_CLK_EN - trigger dumping of all sde_dbg facilities, without clk
 * @va_args:	list of named register dump ranges and regions to dump, as
 *		registered previously through sde_dbg_reg_register_base and
 *		sde_dbg_reg_register_dump_range.
 *		Including the special name "panic" will trigger a panic after
 *		the dumping work has completed.
 */
#define SDE_DBG_DUMP_CLK_EN(...) sde_dbg_dump(SDE_DBG_DUMP_CLK_ENABLED_CTX, \
		__func__, ##__VA_ARGS__, SDE_DBG_DUMP_DATA_LIMITER)

/**
 * SDE_DBG_EVT_CTRL - trigger a different driver events
 *  event: event that trigger different behavior in the driver
 */
#define SDE_DBG_CTRL(...) sde_dbg_ctrl(__func__, ##__VA_ARGS__, \
		SDE_DBG_DUMP_DATA_LIMITER)

static inline struct sde_dbg_evtlog *sde_evtlog_init(void)
{
	return NULL;
}

static inline void sde_evtlog_destroy(struct sde_dbg_evtlog *evtlog)
{
}

static inline void sde_evtlog_log(struct sde_dbg_evtlog *evtlog,
		const char *name, int line, int flag, ...)
{
}

static inline void sde_evtlog_dump_all(struct sde_dbg_evtlog *evtlog)
{
}

static inline bool sde_evtlog_is_enabled(struct sde_dbg_evtlog *evtlog,
		u32 flag)
{
	return false;
}

static inline ssize_t sde_evtlog_dump_to_buffer(struct sde_dbg_evtlog *evtlog,
		char *evtlog_buf, ssize_t evtlog_buf_size,
		bool update_last_entry)
{
	return 0;
}

static inline void sde_dbg_init_dbg_buses(u32 hwversion)
{
}

static inline int sde_dbg_init(struct device *dev)
{
	return 0;
}

static inline int sde_dbg_debugfs_register(struct device *dev)
{
	return 0;
}

static inline void sde_dbg_destroy(void)
{
}

static inline void sde_dbg_dump(enum sde_dbg_dump_context mode,
	const char *name, ...)
{
}

static inline void sde_dbg_ctrl(const char *name, ...)
{
}

static inline int sde_dbg_reg_register_base(const char *name,
		void __iomem *base, size_t max_offset)
{
	return 0;
}

static inline void sde_dbg_reg_register_dump_range(const char *base_name,
		const char *range_name, u32 offset_start, u32 offset_end,
		uint32_t xin_id)
{
}

static inline void sde_dbg_set_sde_top_offset(u32 blk_off)
{
}

static inline void sde_evtlog_set_filter(
		struct sde_dbg_evtlog *evtlog, char *filter)
{
}

static inline int sde_evtlog_get_filter(struct sde_dbg_evtlog *evtlog,
		int index, char *buf, size_t bufsz)
{
	return -EINVAL;
}

#if defined(CONFIG_DISPLAY_SAMSUNG)
void ss_sde_dbg_debugfs_open(void);
ssize_t ss_sde_evtlog_dump_read(struct file *file, char __user *buff,
		size_t count, loff_t *ppos);
#endif

static inline void sde_rsc_debug_dump(u32 mux_sel)
{
}

static inline void dsi_ctrl_debug_dump(u32 *entries, u32 size)
{
}

#endif /* SDE_DBG_H_ */
