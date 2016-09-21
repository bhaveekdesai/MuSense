import sys
import os
import platform
import time
import ctypes

from array import *
from ctypes import *
from __builtin__ import exit
from socket import *

BROADCAST_PORT = 8888
SOCKET = socket(AF_INET, SOCK_DGRAM)
SOCKET.bind(('', 0))
SOCKET.setsockopt(SOL_SOCKET, SO_BROADCAST, 1)


try:
    if sys.platform.startswith('win32'):
        libEDK = cdll.LoadLibrary("server/bin/win32/edk.dll")
    elif sys.platform.startswith('linux'):
        srcDir = os.getcwd()
	if platform.machine().startswith('arm'):
            libPath = srcDir + "/bin/armhf/libedk.so"
	else:
            libPath = srcDir + "/bin/linux64/libedk.so"
        libEDK = CDLL(libPath)
    else:
        raise Exception('System not supported.')
except Exception as e:
    print 'Error: cannot load EDK lib:', e
    exit()

IEE_EmoEngineEventCreate = libEDK.IEE_EmoEngineEventCreate
IEE_EmoEngineEventCreate.restype = c_void_p
eEvent = IEE_EmoEngineEventCreate()

IEE_EmoEngineEventGetEmoState = libEDK.IEE_EmoEngineEventGetEmoState
IEE_EmoEngineEventGetEmoState.argtypes = [c_void_p, c_void_p]
IEE_EmoEngineEventGetEmoState.restype = c_int

IEE_EmoStateCreate = libEDK.IEE_EmoStateCreate
IEE_EmoStateCreate.restype = c_void_p
eState = IEE_EmoStateCreate()

userID = c_uint(0)
user   = pointer(userID)
ready  = 0
state  = c_int(0)

alphaValue     = c_double(0)
low_betaValue  = c_double(0)
high_betaValue = c_double(0)
gammaValue     = c_double(0)
thetaValue     = c_double(0)

ALPHA     = c_double(0)
LOW_BETA  = c_double(0)
HIGH_BETA = c_double(0)
GAMMA     = c_double(0)
THETA     = c_double(0)

alpha     = pointer(alphaValue)
low_beta  = pointer(low_betaValue)
high_beta = pointer(high_betaValue)
gamma     = pointer(gammaValue)
theta     = pointer(thetaValue)

channelList = array('I',[3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16])   # IED_AF3, IED_AF4, IED_T7, IED_T8, IED_Pz

# -------------------------------------------------------------------------
print "==================================================================="
print "Example to get the average band power for a specific channel from" \
" the latest epoch."
print "==================================================================="

# -------------------------------------------------------------------------
if libEDK.IEE_EngineConnect("Emotiv Systems-5") != 0:
        print "Emotiv Engine start up failed."
        exit();

print "Theta, Alpha, Low_beta, High_beta, Gamma \n"

while (1):
    state = libEDK.IEE_EngineGetNextEvent(eEvent)

    ALPHA     = 0
    LOW_BETA  = 0
    HIGH_BETA = 0
    GAMMA     = 0
    THETA     = 0

    if state == 0:
        eventType = libEDK.IEE_EmoEngineEventGetType(eEvent)
        libEDK.IEE_EmoEngineEventGetUserId(eEvent, user)
        if eventType == 16:  # libEDK.IEE_Event_enum.IEE_UserAdded
            ready = 1
            libEDK.IEE_FFTSetWindowingType(userID, 1);  # 1: libEDK.IEE_WindowingTypes_enum.IEE_HAMMING
            print "User added"

        if ready == 1:
            for i in channelList:
                result = c_int(0)
                result = libEDK.IEE_GetAverageBandPowers(userID, i, theta, alpha, low_beta, high_beta, gamma)
                ALPHA     = ALPHA + alphaValue.value
                LOW_BETA  = LOW_BETA + low_betaValue.value
                HIGH_BETA = HIGH_BETA + high_betaValue.value
                GAMMA     = GAMMA + gammaValue.value
                THETA     = THETA + thetaValue.value

            ALPHA     = ALPHA/len(channelList)
            LOW_BETA  = LOW_BETA/len(channelList)
            HIGH_BETA = HIGH_BETA/len(channelList)
            GAMMA     = GAMMA/len(channelList)
            THETA     = THETA/len(channelList)

            if result == 0:    #EDK_OK
                print "%.6f, %.6f, %.6f, %.6f, %.6f \n" % (THETA, ALPHA, LOW_BETA, HIGH_BETA, GAMMA)
                SOCKET.sendto("%.6f %.6f %.6f %.6f %.6f" % (THETA, ALPHA, LOW_BETA, HIGH_BETA, GAMMA), ('<broadcast>', BROADCAST_PORT))

    elif state != 0x0600:
        print "Internal error in Emotiv Engine ! "
    time.sleep(0.1)
# -------------------------------------------------------------------------
libEDK.IEE_EngineDisconnect()
libEDK.IEE_EmoStateFree(eState)
libEDK.IEE_EmoEngineEventFree(eEvent)
