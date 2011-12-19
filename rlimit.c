#include <sys/resource.h>

int getMaxfiles() {
	struct rlimit limit = {0, 0};
	getrlimit(RLIMIT_NOFILE, &limit);
	return limit.rlim_cur;
}