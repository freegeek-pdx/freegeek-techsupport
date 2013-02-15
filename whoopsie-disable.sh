#!/bin/sh
echo 'manual' > /etc/init/whoopsie.override
sed -i.bak s/report_crashes=true/report_crashes=false/ /etc/default/whoopsie
sed -i.bak s/enabled=1/enabled=0/ /etc/default/apport 
service whoopsie stop
service apport stop
