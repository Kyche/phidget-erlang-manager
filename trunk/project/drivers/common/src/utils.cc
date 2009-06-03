/**
 * @file utils.cc
 *
 *  Created on: 2009-06-03
 *      Author: Jean-Lou Dupont
 */
#include <unistd.h>
#include <stdlib.h>
#include <ei.h>
#include "utils.h"

/**
 * Reads a 'message' from the file
 * pointed to by 'fd' descriptor.
 *
 * @param fd file-descriptor
 * @param buf   pointer to buffer
 * @param size  pointer to size of resulting buffer
 *
 * @return -1 if error reading the 'len' header
 * @return  <0  eg. EAGAIN, EBADF, EFAULT, EINTR, EINVAL, EIO, EISDIR
 * @return  >=0  number of bytes read
 */

int read_msg(int fd, byte **buf, int *size) {

  int len;

  if (read_exact(fd, *buf, 2) != 2)
    return(-1);

  len = (*buf[0] << 8) | *buf[1];

  if (len > *size) {
    byte* tmp = (byte *) realloc(*buf, len);
    if (tmp == NULL)
      return -1;
    else
      *buf = tmp;
    *size = len;
  }
  return read_exact(fd, *buf, len);
}

/**
 * Writes a 'message' to the 'file'
 * pointed to by 'fd' descriptor.
 *
 * @param fd file descriptor
 * @param buff erlang ei_x_buff
 *
 * @return >=0 number of bytes-written
 * @return <0  error: EAGAIN, EBADF, EFAULT, EINTR, EINVAL, EIO, EISDIR
 */
int write_msg(int fd, ei_x_buff *buff) {

  byte li;

  li = (buff->index >> 8) & 0xff;
  write_exact(fd, &li, 1);
  li = buff->index & 0xff;
  write_exact(fd, &li, 1);

  return write_exact(fd, (byte *)buff->buff, buff->index);
}

int read_exact(int fd, byte *buf, int len) {

  int i, got=0;

  do {
    if ((i = read(fd, buf+got, len-got)) <= 0)
      return i;
    got += i;
  } while (got<len);

  return len;
}

int write_exact(int fd, byte *buf, int len) {

  int i, wrote = 0;

  do {
    if ((i = write(fd, buf+wrote, len-wrote)) <= 0)
      return i;
    wrote += i;
  } while (wrote<len);

  return len;
}