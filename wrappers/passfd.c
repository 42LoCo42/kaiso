#define _GNU_SOURCE

#include <dlfcn.h>
#include <err.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>

static int targetFD = -1;
static int unixFD = -1;

static int (*original_socket) (int domain, int type, int protocol) = NULL;
static int (*original_bind)   (int sockfd, const struct sockaddr* addr, socklen_t addrlen) = NULL;
static int (*original_accept4)(int sockfd, struct sockaddr* addr, socklen_t* addrlen, int flags) = NULL;

static void __attribute__((constructor)) libInit();

static int info(const char* format, ...) {
	va_list ap;
	va_start(ap, format);
	return vfprintf(stderr, format, ap);
}

static void libInit() {
	original_socket  = dlsym(RTLD_NEXT, "socket");
	original_bind    = dlsym(RTLD_NEXT, "bind");
	original_accept4 = dlsym(RTLD_NEXT, "accept4");

	const char* optionTargetFD   = getenv("KAISO_TARGETFD");
	const char* optionUnixPath   = getenv("KAISO_UNIXPATH");

	if(optionTargetFD == NULL) errx(1, "kaiso-passfd: env does not contain KAISO_TARGETFD");
	targetFD = atoi(optionTargetFD);

	if(targetFD != 0 && optionUnixPath != NULL) {
		targetFD++; // we create a socket here, so every FD after us is shifted by one

		struct sockaddr_un addr = {
			.sun_family = AF_UNIX,
		};
		memccpy(&addr.sun_path, optionUnixPath, 0, 108);

		if((unixFD = socket(AF_UNIX, SOCK_STREAM, 0)) < 0) err(1, "kaiso-passfd: socket");
		if(bind(unixFD, (struct sockaddr*) &addr, sizeof(addr)) < 0) err(1, "kaiso-passfd: bind");
		if(listen(unixFD, 5) < 0) err(1, "kaiso-passfd: listen");
	}
}

static int recv_fd(int socket) {
	char m_buf[1] = {};
	char c_buf[CMSG_SPACE(sizeof(int))] = {};
	struct iovec io = {
		.iov_base = m_buf,
		.iov_len = sizeof(m_buf),
	};
	struct msghdr msg = {
		.msg_iov = &io,
		.msg_iovlen = 1,
		.msg_control = c_buf,
		.msg_controllen = sizeof(c_buf),
	};

	int ret = recvmsg(socket, &msg, 0) < 0 ? -1 : *((int*) CMSG_DATA(CMSG_FIRSTHDR(&msg)));
	close(socket);
	return ret;
}

static const char* domainStr(int domain) {
	switch(domain) {
	case AF_UNIX:    return "unix";
	case AF_INET:    return "IPv4";
	case AF_INET6:   return "IPv6";
	case AF_NETLINK: return "netlink";
	default:         return "other";
	}
}

static const char* typeStr(int type) {
	switch(type & ~(SOCK_NONBLOCK | SOCK_CLOEXEC)) {
	case SOCK_STREAM: return "TCP";
	case SOCK_DGRAM:  return "UDP";
	default:          return "other";
	}
}

int socket(int domain, int type, int protocol) {
	int ret = (*original_socket)(domain, type, protocol);
	if(targetFD == 0) info("socket %s %s %d = %d\n", domainStr(domain), typeStr(type), protocol, ret);
	return ret;
}

int bind(int sockfd, const struct sockaddr* addr, socklen_t addrlen) {
	int ret = (*original_bind)(sockfd, addr, addrlen);
	if(targetFD == 0) info("bind %d = %d\n", sockfd, ret);
	return ret;
}

int accept4(int sockfd, struct sockaddr *restrict addr, socklen_t *restrict addrlen, int flags) {
	int client = (*original_accept4)(sockfd, addr, addrlen, flags);

	if(targetFD == 0) info("accept %d = %d\n", sockfd, client);
	if(client < 0) return client;

	if(sockfd == targetFD) {
		info("kaiso-passfd: taking over\n", 0);
		if(unixFD != -1) {
			info("kaiso-passfd: using TCP transmutation\n", 0);
			close(client);
			client = (*original_accept4)(unixFD, addr, addrlen, 0);
		}
		if(client < 0) return client;

		info("kaiso-passfd: receiving from %d... ", client);
		client = recv_fd(client);
		info("got %d\n", client);
	}

	return client;
}

int accept(int sockfd, struct sockaddr *restrict addr, socklen_t *restrict addrlen) {
	return accept4(sockfd, addr, addrlen, 0);
}
