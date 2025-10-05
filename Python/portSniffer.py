import socket
import datetime
import time

# Nastavte rozsah IP adries a port
ip_start = 1
ip_end = 256
base_ip = "10.0.0."  # upravte podľa potreby
ports = [22, 80, 443]  # porty, ktoré chcete testovať

output_file = "vysledky.txt" + datetime.datetime.now().strftime("%Y-%m-%d %H:%M") + ".txt"


for i in range(ip_start, ip_end + 1):
    ip = f"{base_ip}{i}"
    for port in ports:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(0.2)  # timeout
        try:
            s.connect((ip, port))
            result = f"{ip}:{port}; OK"
        except Exception:
            result = f"{ip}:{port}; FAIL"
        finally:
            s.close()
        print(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S") + ";" + result)
        with open(output_file, "a") as f:
            f.write(datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S") + ";" + result + "\n")