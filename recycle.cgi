#!/usr/bin/env python
import datetime

def get_recycle_date():
    today = datetime.date.today()
    timedelta = datetime.timedelta(45)
    recycledate = today + timedelta
    return recycledate


    
print "Content-Type: text/plain;charset=utf-8"
print
print get_recycle_date()
