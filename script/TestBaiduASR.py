#!/usr/bin/python 
# -*- coding: UTF-8 -*-

from aip import AipSpeech
import sys,requests,time
from requests.packages.urllib3.exceptions import InsecureRequestWarning
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

reload(sys)
sys.setdefaultencoding( "utf-8" )

APP_ID = '14688488'
API_KEY = '800i9bg47tiSLEldBAuduXI5'
SECRET_KEY = 'nG9k4AOhZoaftq6CfkG0tx3QzBUpBLhS'

client = AipSpeech(APP_ID, API_KEY, SECRET_KEY)

def get_file_content(filePath):
    with open(filePath, 'rb') as fp:
        return fp.read()

def call_baidu_asr(file):
	try:
		asrtext = client.asr(get_file_content(file), 'wav', 16000, {'dev_pid': 1737})
		code = asrtext['err_no']
		if code == 2000:
			time.sleep(2)
			call_baidu_asr(file)
		print asrtext['result'][0].decode('UTF-8')
	except:
		print "NULL"

if __name__ == '__main__':
	call_baidu_asr(sys.argv[1])
