#define _GNU_SOURCE

#include <dlfcn.h>
#include <errno.h>
#include <netdb.h>
#include <poll.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef DEBUG
	#include <arpa/inet.h>
	#include <stdio.h>
	#define debug(x) x
#else
	#define debug(x)
#endif

static int (*original_connect)(int sockfd, const struct sockaddr* addr, socklen_t addrlen) = NULL;
static struct addrinfo* targets = NULL;
static char*  serviceName       = NULL;
static size_t serviceNameLength = 0;

static void __attribute__((constructor)) libInit();
static void __attribute__((destructor))  libExit();

static void libInit() {
	original_connect = dlsym(RTLD_NEXT, "connect");

	if(getaddrinfo(getenv("KAISO_IP"), getenv("KAISO_PORT"), NULL, &targets) != 0) exit(1);

	serviceName = getenv("KAISO_SERVICE");
	serviceNameLength = strlen(serviceName);
}

static void libExit() {
	freeaddrinfo(targets);
}

int connect(int sockfd, const struct sockaddr* addr, socklen_t addrlen) {
	int result = (*original_connect)(sockfd, addr, addrlen);

	// check if connection type is IPv4 (kaiso only listens on IPv4)
	if(addr->sa_family != AF_INET) return result;

	// check if a real error occured or if we have to poll later
	int pollLater = 0;
	if(result < 0 && !(pollLater = errno == EINPROGRESS)) return result;

	// wait for getaddrinfo
	if(targets == NULL) return -1;

	// check if the target matches our candidates
	const struct sockaddr_in* target = (const struct sockaddr_in*) addr;
	debug(fprintf(stderr, "target %s = %u\n", inet_ntoa(target->sin_addr), target->sin_addr.s_addr));

	for(struct addrinfo* rp = targets; rp != NULL; rp = rp->ai_next) {
		const struct sockaddr_in* candidate = (const struct sockaddr_in*) rp->ai_addr;
		debug(fprintf(stderr, "candid %s = %u\n", inet_ntoa(candidate->sin_addr), candidate->sin_addr.s_addr));

		if(
			target->sin_port        == candidate->sin_port &&
			target->sin_addr.s_addr == candidate->sin_addr.s_addr
		) break;
	}

	if(pollLater) {
		// wait for connection to complete
		struct pollfd fds = {
			.fd = sockfd,
			.events = POLLOUT,
		};
		if(poll(&fds, 1, -1) != 1) return -1;

		// check if connection completed successfully
		socklen_t resultLength = sizeof(result);
		if(
			getsockopt(sockfd, SOL_SOCKET, SO_ERROR, &result, &resultLength) < 0
			|| result != 0
		) {
			// since getting SO_ERROR clears it, we close the socket in case of an error
			close(sockfd);
			return -1;
		}
	}

	write(sockfd, serviceName, serviceNameLength);
	write(sockfd, "\r\n", 2);

	return result;
}
