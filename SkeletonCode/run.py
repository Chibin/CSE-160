#ANDES Lab - University of California, Merced
#Author: UCM ANDES Lab
#Last Update: 4/28/2011
#! /usr/bin/python
from TOSSIM import *
from packet import *
import sys

t = Tossim([])
r = t.radio()
f = open("topo.txt", "r")

nodeAmount = 6

for line in f:
  s = line.split()
  if s:
    print " ", s[0], " ", s[1], " ", s[2];
    r.add(int(s[0]), int(s[1]), float(s[2]))

# Channels used for debuging
t.addChannel("genDebug", sys.stdout)
t.addChannel("cmdDebug", sys.stdout)
#t.addChannel("Project1F", sys.stdout)
#t.addChannel("Project1N", sys.stdout)
#t.addChannel("Project2L", sys.stdout)
#t.addChannel("Project2D", sys.stdout)
#t.addChannel("Project2F", sys.stdout)
#t.addChannel("Project2N", sys.stdout)
#t.addChannel("Project2test", sys.stdout)
#t.addChannel("Project3S", sys.stdout)
#t.addChannel("Project3C", sys.stdout)
#t.addChannel("Project3Socket", sys.stdout)
t.addChannel("Project3Manager", sys.stdout)
#t.addChannel("Project3Node", sys.stdout)
t.addChannel("Project4Client", sys.stdout)
t.addChannel("Project4Server",sys.stdout)
#t.addChannel("transport", sys.stdout)
t.addChannel("clientAL", sys.stdout)
t.addChannel("serverAL", sys.stdout)

noise = open("no_noise.txt", "r")
for line in noise:
  str1 = line.strip()
  if str1:
    val = int(str1)
    for i in range(1, nodeAmount+1):
       t.getNode(i).addNoiseTraceReading(val)

for i in range(1, nodeAmount+1):
  print "Creating noise model for ",i;
  t.getNode(i).createNoiseModel()


for i in range(1, nodeAmount+1):
    t.getNode(i).bootAtTime(1000+(i-1)*133);

def package(string):
 	ints = []
	for c in string:
		ints.append(ord(c))
	return ints

def run(ticks):
	for i in range(ticks):
		t.runNextEvent()

def runTime(amount):
	time = t.time()
	while time + amount*10000000000 > t.time():
		t.runNextEvent() 

#Create a Command Packet
msg = pack()
msg.set_seq(0)
msg.set_TTL(15)
msg.set_protocol(99)

pkt = t.newPacket()
pkt.setData(msg.data)
pkt.setType(msg.get_amType())

def sendCMD(string):
	args = string.split(' ');
	msg.set_src(int(args[0]));
	msg.set_dest(int(args[1]));
	payload=args[2];
	for i in range(3, len(args)):
		payload= payload + ' '+ args[i]
	
	msg.setString_payload(payload)
	
	pkt.setData(msg.data)
	pkt.setDestination(int(args[1]))
	
	#print "Delivering!"
	pkt.deliver(int(args[1]), t.time()+5)
	runTime(2);


runTime(150)
#cmd client <src port> <dest port> <dest addr>
#cmd server <src port>
sendCMD("0 1 cmd server 41")
sendCMD("0 2 cmd client 99 41 1")
sendCMD("0 2 cmd hello maru 3\r\n")
sendCMD("0 3 cmd client 100 41 1")
sendCMD("0 3 cmd hello lulu 4\r\n")
sendCMD("0 2 cmd msg WATISDIS?\r\n")
sendCMD("0 2 cmd listusr\r\n")
#sendCMD("0 2 cmd msg DERP!?\r\n")
#sendCMD("0 6 cmd ping 4 PING")
runTime(200)
#sendCMD("2 2 cmd kill")
runTime(200)
#sendCMD("0 6 cmd ping 5 PING")