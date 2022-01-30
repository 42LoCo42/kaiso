#define _GNU_SOURCE

#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <netdb.h>
#include <unistd.h>
#include <string.h>

static int (*original_connect)(int sockfd, const struct sockaddr* addr, socklen_t addrlen) = NULL;
static struct addrinfo* targets = NULL;
static char* serviceName = NULL;
static size_t serviceNameLength = 0;

int connect(int sockfd, const struct sockaddr* addr, socklen_t addrlen) {
	if(original_connect == NULL) {
		original_connect = dlsym(RTLD_NEXT, "connect");

		int r = getaddrinfo(getenv("KAISO_IP"), getenv("KAISO_PORT"), NULL, &targets);
		if(r != 0) {
			fprintf(stderr, "getaddrinfo: %s\n", gai_strerror(r));
		}

		serviceName = getenv("KAISO_SERVICE");
		serviceNameLength = strlen(serviceName);

	}

	int result = (*original_connect)(sockfd, addr, addrlen);

	const struct sockaddr_in* in_addr = (const struct sockaddr_in*) addr;
	for(struct addrinfo* rp = targets; rp != NULL; rp = rp->ai_next) {
		const struct sockaddr_in* candidate = (const struct sockaddr_in*) rp->ai_addr;
		if(
			in_addr->sin_port == candidate->sin_port &&
			in_addr->sin_addr.s_addr == candidate->sin_addr.s_addr
		) {
			write(sockfd, serviceName, serviceNameLength);
			write(sockfd, "\r\n", 2);
			break;
		}
	}

	return result;
}
