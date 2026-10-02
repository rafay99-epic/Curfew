#!/usr/bin/env python3
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "agents", "linux"))
import curfew


class LoopbackServer(curfew.Server):
    def __init__(self, address, handler):
        super().__init__(("127.0.0.1", address[1]), handler)


curfew.Server = LoopbackServer

if __name__ == "__main__":
    sys.exit(curfew.main(sys.argv[1:]))
