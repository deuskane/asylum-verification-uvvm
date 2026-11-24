//-----------------------------------------------------------------------------
// Title      : OpenOCD remote_bitbang server of the co-simulations
// Project    : Asylum
//-----------------------------------------------------------------------------
// File       : rbb_server.c
// Author     : mrosiere
//-----------------------------------------------------------------------------
// Description: TCP server of the OpenOCD "remote_bitbang" adapter, called by
//              a GHDL testbench through VHPIDIRECT (rbb_pkg.vhd). Two APIs,
//              one per kind of DUT :
//              BYTE mode, the DUT decodes the protocol (jtag_bitbang) :
//                int  rbb_recv (void)     next byte sent by OpenOCD, -1 : none
//                                         yet, -2 : connection closed
//                void rbb_send (int c)    one byte to OpenOCD (answer to 'R')
//              PIN mode, the DUT is a TAP (JTAG pins) :
//                int  rbb_tick (int tdo)  decodes the commands of OpenOCD up
//                                         to the next pin change, answers 'R'
//                                         with tdo (0 / 1) ; returns the pins :
//                                         bit 0 TCK, 1 TMS, 2 TDI, 3 quit
//                                         (OpenOCD sent 'Q' or closed the
//                                         connection), 4 TRST, 5 SRST
//                                         (1 : asserted) ; 'B' / 'b' ignored
//              No call waits for a command : the simulation keeps running.
//              The first call waits for OpenOCD on 127.0.0.1:RBB_PORT
//              (environment, default 9824), -2 / quit after 120 s without it.
//              A socket error (OpenOCD killed : ECONNRESET) closes the
//              connection, as an end of file : -2 / quit.
//              Build : gcc -shared -fPIC -o librbb.so rbb_server.c
//-----------------------------------------------------------------------------
// Copyright (c) 2026
//-----------------------------------------------------------------------------
// Revisions  :
// Date        Version  Author   Description
// 2026-11-24  1.0      mrosiere Created from rbb_server.c of
//                               asylum-debug-jtag (BYTE mode) and
//                               remote_bitbang.c of asylum-processor-WardRV
//                               (PIN mode)
// 2026-11-24  1.1      mrosiere Socket error = connection closed (no wait
//                               for the testbench timeout), listening
//                               socket closed when bind / listen fails
//-----------------------------------------------------------------------------

#include <errno.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

//--------------------------------------
// Constant
//--------------------------------------
#define RBB_PORT    9824
#define TIMEOUT_MS  120000
#define BUF_SIZE    4096

#define RBB_NONE    -1
#define RBB_CLOSED  -2

#define PIN_TCK     1
#define PIN_TMS     2
#define PIN_TDI     4
#define PIN_QUIT    8
#define PIN_TRST    16
#define PIN_SRST    32

//--------------------------------------
// State
//--------------------------------------
static int           client = -1;                              // Socket of OpenOCD
static int           closed = 0;
static int           pins   = PIN_TMS;                         // TCK low, TMS high
static unsigned char rx[BUF_SIZE];
static int           rx_len = 0;
static int           rx_pos = 0;

// Wait for OpenOCD on 127.0.0.1:RBB_PORT
static void rbb_open (void)
{
  const char        *port = getenv("RBB_PORT");
  struct sockaddr_in addr;
  struct pollfd      pfd;
  int                one  = 1;
  int                server;

  memset(&addr,0,sizeof(addr));
  addr.sin_family      = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port        = htons(port ? atoi(port) : RBB_PORT);

  closed = 1;
  server = socket(AF_INET,SOCK_STREAM,0);
  setsockopt(server,SOL_SOCKET,SO_REUSEADDR,&one,sizeof(one));
  if (bind  (server,(struct sockaddr *)&addr,sizeof(addr)) < 0 ||
      listen(server,1) < 0)
    {
      perror("rbb_server");
      close(server);
      return;
    }
  printf("rbb_server : waiting for OpenOCD on port %d\n",ntohs(addr.sin_port));
  fflush(stdout);
  pfd.fd     = server;
  pfd.events = POLLIN;
  if (poll(&pfd,1,TIMEOUT_MS) == 1)
    {
      client = accept(server,NULL,NULL);
      setsockopt(client,IPPROTO_TCP,TCP_NODELAY,&one,sizeof(one));
      closed = (client < 0);
    }
  else
    printf("rbb_server : no OpenOCD\n");
  close(server);
}

// OpenOCD closed the connection (end of file) or the socket failed
static int rbb_lost (const char *why)
{
  printf("rbb_server : %s\n",why);
  fflush(stdout);
  close(client);
  closed = 1;
  return RBB_CLOSED;
}

// The error of recv / send is "try again", not a lost connection
static int rbb_again (void)
{
  return errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR;
}

//--------------------------------------
// BYTE mode : next byte of OpenOCD
//--------------------------------------
int rbb_recv (void)
{
  if (client < 0 && !closed)
    rbb_open();
  if (closed)
    return RBB_CLOSED;

  if (rx_pos == rx_len)
    {
      rx_len = recv(client,rx,BUF_SIZE,MSG_DONTWAIT);
      rx_pos = 0;
      if (rx_len == 0)                                         // Connection closed
        return rbb_lost("OpenOCD closed the connection");
      if (rx_len < 0)
        {
          rx_len = 0;
          if (rbb_again())                                     // Nothing yet
            return RBB_NONE;
          return rbb_lost(strerror(errno));                    // OpenOCD killed : ECONNRESET
        }
    }
  return rx[rx_pos++];
}

//--------------------------------------
// BYTE mode : one byte to OpenOCD
//--------------------------------------
void rbb_send (int c)
{
  unsigned char b = c;

  while (!closed && send(client,&b,1,MSG_NOSIGNAL) < 0)
    if (!rbb_again())
      rbb_lost(strerror(errno));
}

//--------------------------------------
// PIN mode : commands up to the next pin change
//--------------------------------------
int rbb_tick (int tdo)
{
  for (;;)
    {
      int c = rbb_recv();

      if (c == RBB_NONE)
        return pins;
      if (c == RBB_CLOSED || c == 'Q')
        return pins | PIN_QUIT;

      if (c >= '0' && c <= '7')                                // TCK, TMS, TDI = bits 2, 1, 0
        {
          c   -= '0';
          pins = (pins & (PIN_TRST | PIN_SRST)) |
                 ((c & 4) ? PIN_TCK : 0) | ((c & 2) ? PIN_TMS : 0) | ((c & 1) ? PIN_TDI : 0);
          return pins;
        }
      if (c >= 'r' && c <= 'u')                                // TRST, SRST = bits 1, 0
        {
          c   -= 'r';
          pins = (pins & (PIN_TCK | PIN_TMS | PIN_TDI)) |
                 ((c & 2) ? PIN_TRST : 0) | ((c & 1) ? PIN_SRST : 0);
          return pins;
        }
      if (c == 'R')
        rbb_send(tdo ? '1' : '0');
    }
}
