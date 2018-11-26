#!/usr/bin/pthon
# -*- coding: UTF-8 -*-

import sys

fop = open('/home/yankt/work/git/AlignTextProject/data/rec_out_all.txt','r')

dict = {}
for line in fop:
	res = line.split('|')
	wavfile = res[0]
	usertext = res[1]
	usertext = usertext.replace("\r","")
	usertext = usertext.replace("\n","")
	wavfile = wavfile.replace(" ","")
	dict[wavfile] = usertext

if dict.has_key(sys.argv[1]):
	print dict[sys.argv[1]]
else:
	print "NULL"

