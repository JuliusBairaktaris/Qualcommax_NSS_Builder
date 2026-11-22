#!/usr/bin/env python3
"""exec-eof.py RUNS CMD...: run CMD as rpcd's file exec does and check its pipes.

rpcd answers an exec call once it has read the end of stdout and of stderr. It
reads them when the command exits; a pipe that a child of the command closes
only after that reaches rpcd as a hang-up with nothing to read, which libubox
does not take for the end of the stream, and the call then runs into rpcd's
exec timeout. So when the command is reaped, both pipes must already be at
their end. Exit status 1 names the runs where one was not.
"""
import os
import subprocess
import sys

runs, cmd = int(sys.argv[1]), sys.argv[2:]
held = 0
for _ in range(runs):
    p = subprocess.Popen(cmd, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    p.wait()
    for pipe in (p.stdout, p.stderr):
        os.set_blocking(pipe.fileno(), False)
        try:
            if os.read(pipe.fileno(), 1) != b"":
                continue
        except BlockingIOError:
            held += 1
            break
    p.stdout.close()
    p.stderr.close()
print("%d of %d runs left a pipe open when the command exited" % (held, runs))
sys.exit(1 if held else 0)
