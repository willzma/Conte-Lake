import statistics

array = []
start = 13
for i in range(0, 4095):
    array.append(start + (i * 11))
print("{0:0X}".format(int(statistics.median(array))))
