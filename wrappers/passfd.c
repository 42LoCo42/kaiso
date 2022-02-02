#define _GNU_SOURCE

#include <dlfcn.h>
#include <sys/socket.h>
#include <unistd.h>

static int (*original_accept)(int sockfd, struct sockaddr *restrict addr, socklen_t *restrict addrlen) = NULL;

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

	return recvmsg(socket, &msg, 0) < 0 ? -1 : *((int*) CMSG_DATA(CMSG_FIRSTHDR(&msg)));
}

int accept(int sockfd, struct sockaddr *restrict addr, socklen_t *restrict addrlen) {
	if(original_accept == NULL) {
		original_accept = dlsym(RTLD_NEXT, "accept");
	}

	int client = (*original_accept)(sockfd, addr, addrlen);
	if(client < 0) return client;

	int passed = recv_fd(client);

	close(client);
	return passed;
}
