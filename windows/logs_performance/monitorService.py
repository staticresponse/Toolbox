from __future__ import print_function
import psutil
import time

def get_service(name):
    service = None
    try:
        service = psutil.win_service_get(name)
        service = service.as_dict()
    except Exception as ex:
        # raise psutil.NoSuchProcess if no service with such name exists
        print(str(ex))

    return service

gamerService = ['PnkBstrA','Steam Client Service','Origin Web Helper Service']
gameCount = 0
for x in gamerService:
    service = get_service(x)

    if service:
        time.sleep(1)
    else:
        print(x+ " not found")

    if service and service['status'] == 'running':
        print(x + " is running")
    else: 
        print(x +" is not running")
        gameCount = gameCount + 1
if gameCount == 0:
    print ("All game services are running")
else:
    print ("One or more services are offline")
