#!/usr/bin/python

import Levenshtein
import sys

res = Levenshtein.distance(sys.argv[1], sys.argv[2])
print res
