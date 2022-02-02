#include <sys/socket.h>

int send_fd(int socket, int fd) {
	char c_buf[CMSG_SPACE(sizeof(fd))] = {};
	struct iovec io = {
		.iov_base = "*",
		.iov_len = 1,
	};
	struct msghdr msg = {
		.msg_iov = &io,
		.msg_iovlen = 1,
		.msg_control = c_buf,
		.msg_controllen = sizeof(c_buf),
	};
	struct cmsghdr* cmsg = CMSG_FIRSTHDR(&msg);
	cmsg->cmsg_len = CMSG_LEN(sizeof(fd));
	cmsg->cmsg_level = SOL_SOCKET;
	cmsg->cmsg_type = SCM_RIGHTS;
	*((int*) CMSG_DATA(cmsg)) = fd;

	return sendmsg(socket, &msg, 0);
}
