#!/usr/bin/env python
import datetime

def get_recycle_date():
    today = datetime.date.today()
    timedelta = datetime.timedelta(45)
    recycledate = today + timedelta
    return recycledate


if __name__ == "__main__":
    print get_recycle_date()
