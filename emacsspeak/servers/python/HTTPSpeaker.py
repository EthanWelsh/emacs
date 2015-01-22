#!/usr/bin/python

"""HTTP wrapper around Emacspeak speech server.

Speech server is launched on HTTP server startup.

Speech commands are invoked via URLs:

http://host:port/cmd?arg

calls speaker.cmd(arg)

"""

__id__ = "$Id: HTTPSpeaker.py 7067 2011-06-25 02:49:51Z tv.raman.tv $"
__author__ = "$Author: tv.raman.tv $"
__version__ = "$Revision: 7067 $"
__date__ = "$Date: 2011-06-24 19:49:51 -0700 (Fri, 24 Jun 2011) $"
__copyright__ = "Copyright (c) 2005 T. V. Raman"
__license__ = "LGPL"


from speaker import Speaker
from BaseHTTPServer import HTTPServer, BaseHTTPRequestHandler
import sys
import os
import urllib

class HTTPSpeaker (HTTPServer):

    """Speech server via HTTP."""

    def __init__(self, address, handler,
                 engine='outloud',
                 rate = 75):
        """Initialize HTTP listener."""
        HTTPServer.__init__(self, address, handler)
        self.speaker = Speaker(engine,
                               'localhost',
                               {'punctuations' : 'some',
                                'rate' : rate})

class SpeakHTTPRequestHandler(BaseHTTPRequestHandler):

    """Handle HTTP Speak requests."""
    handlers = ['say',
                'speak',
                'letter',
                'addText',
                'silence',
                'tone',
                'stop',
                'punctuation',
                'rate',
                'allcaps',
                'capitalize',
                'splitcaps',
                'reset',
                'shutdown',
                'version'             ]

    def do_GET(self):
        """Not Implemented."""
        #cmd = None
        #arg = None
        if hasattr(self.server.speaker, cmd):
            method = getattr(self.server.speaker, cmd)
            if arg is None:
                method()
            else:
                method(urllib.unquote(arg))
            self.send_response(200, self.path)
        else: self.send_error(501, "Speaker error")

    def do_POST(self):
        """Handle speech request in a POST message. """
        contentLength = self.headers.getheader('content-length')
        if contentLength:
            contentLength = int(contentLength)
            inputBody = self.rfile.read(contentLength)
            sys.stderr.write(inputBody  + "\n")
            if inputBody.startswith("speak:"):
                text = inputBody[6:]
                self.server.speaker.sayUtterances([text] )
                self.send_response(200, 'OK')
            elif inputBody == "stop":
                self.server.speaker.stop()
                self.send_response(200, 'OK')
            elif inputBody == "isSpeaking":
                self.send_response(200, 'OK')
                self.send_header("Content-type", "text/html")
                self.end_headers()
                self.wfile.write("0")
            else:
                self.send_error(501, 'Unknown POST message ' + inputBody)
    
def start():
    if sys.argv[1:]:
        engine = sys.argv[1]
    else:
        engine=os.getenv('DTK_PROGRAM','outloud')
    if sys.argv[2:]:
        port = int(sys.argv[2])
    else:
        port = 8000
    if sys.argv[3:]:
        rate = int(sys.argv[3])
    else:
        rate = 75
    server_address = ('', port)
    httpd = HTTPSpeaker  (server_address,
    SpeakHTTPRequestHandler, engine, rate)
    httpd.serve_forever()


if __name__ == '__main__':
    start()
