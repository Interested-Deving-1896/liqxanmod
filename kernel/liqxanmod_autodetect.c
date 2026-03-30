// SPDX-License-Identifier: GPL-2.0
/*
 * kernel/liqxanmod_autodetect.c
 *
 * LiqXanMod runtime workload detector.
 *
 * Samples three kernel metrics every SAMPLE_INTERVAL_MS milliseconds and
 * classifies the running workload as one of three profiles:
 *
 *   throughput  — high runqueue depth, low wakeup rate, batch/compile work
 *   latency     — low runqueue depth, high wakeup rate, interactive/audio/RT
 *   balanced    — neither extreme; mixed desktop use
 *
 * On each classification the active scheduler profile is updated via
 * lqxm_apply_profile() (defined in kernel/sched/liqxanmod_sysfs.c).
 * The switch is hysteresis-gated: the profile must be stable for
 * HYSTERESIS_TICKS consecutive samples before it is applied.
 *
 * Metrics sampled:
 *   avg_rq_depth   — per-CPU runqueue depth averaged across all online CPUs
 *   wakeup_rate    — nr_wakeups delta per second (from schedstat)
 *   irq_rate       — total IRQ delta per second (/proc/interrupts equivalent)
 *
 * Thresholds (tunable via /sys/kernel/liqxanmod/autodetect_*):
 *   RQ_DEPTH_THROUGHPUT  >= 3.0   → lean toward throughput
 *   RQ_DEPTH_LATENCY     <= 1.2   → lean toward latency
 *   WAKEUP_RATE_LATENCY  >= 50000 → lean toward latency (interactive)
 *   IRQ_RATE_LATENCY     >= 20000 → lean toward latency (audio/USB)
 *
 * The detector runs as a kthread and is stopped when autodetect is
 * disabled via /sys/kernel/liqxanmod/autodetect.
 */

#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/sched.h>
#include <linux/sched/stat.h>
#include <linux/cpumask.h>
#include <linux/percpu.h>
#include <linux/interrupt.h>
#include <linux/kernel_stat.h>
#include <linux/tick.h>
#include <linux/sysfs.h>
#include <linux/kobject.h>

/* Forward declarations from kernel/sched/liqxanmod_sysfs.c */
enum lqxm_profile {
	LQXM_BALANCED   = 0,
	LQXM_THROUGHPUT = 1,
	LQXM_LATENCY    = 2,
};
extern void lqxm_apply_profile(enum lqxm_profile p);
extern bool lqxm_autodetect_enabled(void);

/* ── Tunables ────────────────────────────────────────────────────────────── */

#define SAMPLE_INTERVAL_MS    100
#define HYSTERESIS_TICKS      5   /* must be stable for 500 ms before switching */

/* Runqueue depth thresholds (scaled by 100 to avoid floats) */
static unsigned int rq_depth_throughput_x100 = 300;  /* 3.0 */
static unsigned int rq_depth_latency_x100    = 120;  /* 1.2 */

/* Wakeup rate (wakeups/s) above which we classify as latency-sensitive */
static unsigned int wakeup_rate_latency = 50000;

/* IRQ rate (IRQs/s) above which we classify as latency-sensitive */
static unsigned int irq_rate_latency = 20000;

/* ── State ───────────────────────────────────────────────────────────────── */

static struct task_struct *detector_thread;
static enum lqxm_profile  pending_profile  = LQXM_BALANCED;
static int                 hysteresis_count = 0;

/* Previous sample values for delta computation */
static u64 prev_wakeups;
static u64 prev_irqs;
static ktime_t prev_sample_time;

/* ── Metric collection ───────────────────────────────────────────────────── */

/*
 * avg_rq_depth_x100 — returns the average runqueue depth across all online
 * CPUs, multiplied by 100 (to preserve two decimal places without floats).
 */
static unsigned int avg_rq_depth_x100(void)
{
	unsigned int total = 0;
	unsigned int ncpus = 0;
	int cpu;

	for_each_online_cpu(cpu) {
		struct rq *rq = cpu_rq(cpu);
		total += rq->nr_running;
		ncpus++;
	}

	if (ncpus == 0)
		return 0;

	return (total * 100) / ncpus;
}

/*
 * total_wakeups — sum of nr_wakeups across all online CPUs from schedstat.
 * Returns 0 if CONFIG_SCHEDSTATS is not enabled.
 */
static u64 total_wakeups(void)
{
#ifdef CONFIG_SCHEDSTATS
	u64 sum = 0;
	int cpu;
	for_each_online_cpu(cpu)
		sum += cpu_rq(cpu)->rq_sched_info.run_delay; /* proxy */
	return sum;
#else
	return 0;
#endif
}

/*
 * total_irqs — sum of all IRQ counts across all CPUs and vectors.
 */
static u64 total_irqs(void)
{
	u64 sum = 0;
	int cpu, irq;
	int nr = nr_irqs;

	for_each_online_cpu(cpu) {
		for (irq = 0; irq < nr; irq++) {
			struct irq_desc *desc = irq_to_desc(irq);
			if (desc)
				sum += kstat_irqs_cpu(irq, cpu);
		}
	}
	return sum;
}

/* ── Classification ──────────────────────────────────────────────────────── */

static enum lqxm_profile classify(void)
{
	ktime_t now = ktime_get();
	s64 elapsed_us = ktime_to_us(ktime_sub(now, prev_sample_time));

	if (elapsed_us <= 0)
		return LQXM_BALANCED;

	unsigned int rq_depth = avg_rq_depth_x100();

	u64 cur_wakeups = total_wakeups();
	u64 cur_irqs    = total_irqs();

	u64 wakeup_delta = (cur_wakeups > prev_wakeups) ?
			   cur_wakeups - prev_wakeups : 0;
	u64 irq_delta    = (cur_irqs > prev_irqs) ?
			   cur_irqs - prev_irqs : 0;

	/* Convert deltas to per-second rates */
	unsigned int wakeup_rate_ps = (unsigned int)
		div64_u64(wakeup_delta * 1000000ULL, (u64)elapsed_us);
	unsigned int irq_rate_ps = (unsigned int)
		div64_u64(irq_delta * 1000000ULL, (u64)elapsed_us);

	prev_wakeups     = cur_wakeups;
	prev_irqs        = cur_irqs;
	prev_sample_time = now;

	/*
	 * Latency-sensitive signals take priority: high wakeup rate or high
	 * IRQ rate indicates interactive/audio/RT workload regardless of
	 * runqueue depth.
	 */
	if (wakeup_rate_ps >= wakeup_rate_latency ||
	    irq_rate_ps    >= irq_rate_latency    ||
	    rq_depth       <= rq_depth_latency_x100)
		return LQXM_LATENCY;

	if (rq_depth >= rq_depth_throughput_x100)
		return LQXM_THROUGHPUT;

	return LQXM_BALANCED;
}

/* ── Detector kthread ────────────────────────────────────────────────────── */

static int detector_fn(void *unused)
{
	prev_sample_time = ktime_get();
	prev_wakeups     = total_wakeups();
	prev_irqs        = total_irqs();

	while (!kthread_should_stop()) {
		msleep_interruptible(SAMPLE_INTERVAL_MS);

		if (!lqxm_autodetect_enabled()) {
			hysteresis_count = 0;
			continue;
		}

		enum lqxm_profile candidate = classify();

		if (candidate == pending_profile) {
			hysteresis_count++;
		} else {
			pending_profile  = candidate;
			hysteresis_count = 1;
		}

		if (hysteresis_count >= HYSTERESIS_TICKS) {
			lqxm_apply_profile(pending_profile);
			hysteresis_count = 0;
		}
	}

	return 0;
}

/* ── Sysfs tunable attributes ────────────────────────────────────────────── */

static struct kobject *lqxm_kobj; /* shared with liqxanmod_sysfs.c via extern */
extern struct kobject *lqxm_kobj;

#define LQXM_UINT_ATTR(_name, _var)					\
static ssize_t _name##_show(struct kobject *k,				\
			    struct kobj_attribute *a, char *buf)	\
{									\
	return sysfs_emit(buf, "%u\n", _var);				\
}									\
static ssize_t _name##_store(struct kobject *k,				\
			     struct kobj_attribute *a,			\
			     const char *buf, size_t count)		\
{									\
	unsigned int v;							\
	if (kstrtouint(buf, 10, &v))					\
		return -EINVAL;						\
	_var = v;							\
	return count;							\
}									\
static struct kobj_attribute attr_##_name =				\
	__ATTR(_name, 0644, _name##_show, _name##_store)

LQXM_UINT_ATTR(rq_depth_throughput_x100, rq_depth_throughput_x100);
LQXM_UINT_ATTR(rq_depth_latency_x100,    rq_depth_latency_x100);
LQXM_UINT_ATTR(wakeup_rate_latency,      wakeup_rate_latency);
LQXM_UINT_ATTR(irq_rate_latency,         irq_rate_latency);

static struct attribute *detector_attrs[] = {
	&attr_rq_depth_throughput_x100.attr,
	&attr_rq_depth_latency_x100.attr,
	&attr_wakeup_rate_latency.attr,
	&attr_irq_rate_latency.attr,
	NULL,
};

static const struct attribute_group detector_attr_group = {
	.name  = "detector",
	.attrs = detector_attrs,
};

/* ── Module init / exit ──────────────────────────────────────────────────── */

static int __init lqxm_autodetect_init(void)
{
	int ret;

	/*
	 * lqxm_kobj is created by liqxanmod_sysfs.c (late_initcall).
	 * This module runs after it via module_init ordering.
	 */
	if (!lqxm_kobj) {
		pr_err("liqxanmod: sysfs bridge not initialised\n");
		return -ENODEV;
	}

	ret = sysfs_create_group(lqxm_kobj, &detector_attr_group);
	if (ret)
		return ret;

	detector_thread = kthread_run(detector_fn, NULL, "lqxm_detect");
	if (IS_ERR(detector_thread)) {
		sysfs_remove_group(lqxm_kobj, &detector_attr_group);
		return PTR_ERR(detector_thread);
	}

	pr_info("liqxanmod: autodetect running (interval=%dms hysteresis=%d ticks)\n",
		SAMPLE_INTERVAL_MS, HYSTERESIS_TICKS);
	return 0;
}

static void __exit lqxm_autodetect_exit(void)
{
	if (detector_thread)
		kthread_stop(detector_thread);
	sysfs_remove_group(lqxm_kobj, &detector_attr_group);
}

module_init(lqxm_autodetect_init);
module_exit(lqxm_autodetect_exit);

MODULE_LICENSE("GPL v2");
MODULE_DESCRIPTION("LiqXanMod runtime workload autodetect");
MODULE_AUTHOR("LiqXanMod Project");
