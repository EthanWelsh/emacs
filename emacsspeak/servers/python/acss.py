"""ACSS --- Aural CSS.

Class ACSS defines a simple wrapper for holding ACSS voice
definitions.  Speech engines implement the code for converting
ACSS definitions into engine-specific markup codes.

"""

__id__ = "$Id: acss.py 3535 2005-11-17 14:32:59Z raman $"
__author__ = "$Author: raman $"
__version__ = "$Revision: 3535 $"
__date__ = "$Date: 2005-11-17 06:32:59 -0800 (Thu, 17 Nov 2005) $"
__copyright__ = "Copyright (c) 2005 T. V. Raman"
__license__ = "LGPL"

class ACSS(dict):

    """Holds ACSS representation of a voice."""

    settings = {
                'family' : None,
                'rate' : 50,
                'gain' : 5,
                'average-pitch' : 5,
                'pitch-range' : 5, 
                'stress' : 5,
                'richness' : 5,
                'punctuations' : 'all'
                }

    def __init__(self,props={}):
        """Create and initialize ACSS structure."""
        for k in props:
            if k in ACSS.settings: self[k] = props[k]
        self.updateName()

    def __setitem__ (self, key, value):
        """Update name when we change values."""
        dict.__setitem__(self, key, value)
        self.updateName()

    def __delitem__(self, key):
        """Update name if we delete a key."""
        dict.__delitem__(self,key)
        self.updateName()
    
    def updateName(self):
        """Update name based on settings."""
        _name='acss-'
        names = self.keys()
        if names:
            names.sort()
            for  k in names:
                _name += "%s-%s:" % (k, self[k])
        self._name = _name[:-1]

    def name(self): return self._name
