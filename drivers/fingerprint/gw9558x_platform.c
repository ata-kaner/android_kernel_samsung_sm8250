#include "fingerprint.h"
#include "gw9558x_common.h"

int gw9558_register_platform_variable(struct gf_device *gf_dev)
{
	return 0;
}

int gw9558_unregister_platform_variable(struct gf_device *gf_dev)
{
	return 0;
}

void gw9558_spi_setup_conf(struct gf_device *gf_dev, u32 bits)
{
}

int gw9558_spi_clk_enable(struct gf_device *gf_dev)
{
	if (!gf_dev->enabled_clk) {
		wake_lock(&gf_dev->wake_lock);
		gf_dev->enabled_clk = true;
	}
	return 0;
}

int gw9558_spi_clk_disable(struct gf_device *gf_dev)
{
	if (gf_dev->enabled_clk) {
		wake_unlock(&gf_dev->wake_lock);
		gf_dev->enabled_clk = false;
	}
	return 0;
}

int gw9558_set_cpu_speedup(struct gf_device *gf_dev, int onoff)
{
	int retval = 0;
	pr_info("FP_CPU_SPEEDUP does not set\n");
	return retval;
}

int gw9558_pin_control(struct gf_device *gf_dev, bool pin_set)
{
	return 0;
}
