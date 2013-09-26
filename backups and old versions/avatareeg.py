#!/usr/bin/env python
#
# $Id: avatareeg.py 363 2013-02-12 20:53:30Z christensen $
#
# Copyright (c) 2012 Avatar EEG Solutions Inc. All rights reserved.
#

import sys
from os import SEEK_END
import random
import socket
import bluetooth
import traceback
import platform
import os
from struct import unpack, pack
from time import localtime, strftime, sleep, asctime
from calendar import timegm
from PyQt4 import QtCore, QtGui
from avatareeg_gui_ui import Ui_MainWindow
from threading import Lock


keep_terminal_open = True
write_to_csv_init  = False
write_to_bdf_init  = False

# calculates the CRC-16-CCIT using an initial value of 0
def crc_calc(data):
    crc = 0
    for byte in data:
        b = ord(byte)
        crc  = (crc >> 8) | ((crc & 0xff) << 8)
        crc ^= b
        crc ^= (crc & 0xff) >> 4
        crc ^= ((crc << 12) & 0xffff)
        crc ^= (crc & 0xff) << 5
    return crc

class Frame():

    max_header_size  = 20
    # header and crc for text frame with 6 bytes data + crc of 2
    minimum_size = max_header_size + 6 + 2
    maximum_size = max_header_size + 16*9*3 + 2

    def __init__(self):
        # common to all frames
        self.raw        = '' # string of raw bytes received
        self.version    = 0
        self.frame_size = 0
        self.frame_type = 0
        self.crc_size   = 0
        self.crc        = 0
        self.header_size= 0

    # returns '' if valid frame otherwise returns a reason string
    def check(self):
        result = ''
        if (self.frame_type != 1):
            result += 'Bad frame_type: %x\n' % self.frame_type
        if (self.channels > 9):
            result += 'Bad num channels: %x\n' % self.channels
        if (self.samples > 32):
            result += 'Bad num samples: %d\n' % self.samples
        if self.crc_size == 2:
            # last two bytes are CRC
            c = crc_calc(self.raw[0:-2])
            if self.crc != c:
                result += 'Bad CRC: %x %x\n' % (self.crc, c)
        return result

class DataFrame(Frame):

    def __init__(self):
        Frame. __init__(self)
        self.trigger_channel_enabled = False
        self.number_of_eeg_channels = 0
        self.sample_rate = 0
        self.range = 0

    # called after sync, version and framesize are known
    # and all bytes have been received
    def unpack_frame(self):
        if self.version >= 3:
            self.header_size = 20
            self.crc_size = 2
        elif self.version == 2:
            self.header_size = 12
            self.crc_size = 2
        else:
            self.header_size = 12
            self.crc_size = 0

        assert(len(self.raw) == self.size), (len(self.data), self.size)
        self.frame_type  = unpack('B',  self.raw[4])[0]
        self.frame_num   = unpack('!I', self.raw[5:9])[0]
        self.channels    = unpack('B',  self.raw[9])[0]
        self.samples     = unpack('!H', self.raw[10:12])[0]
        if self.crc_size > 0:
            self.data        = self.raw[self.header_size:-self.crc_size]
        else:
            self.data        = self.raw[self.header_size:]

        if self.version >= 3:
            if self.frame_type==1:
                #print self.frame_type, 'FRAME TYPE'
                self.range = unpack('!H', self.raw[12:14])[0]
                self.range *= 1000 # convert to uV
                self.time_soc, time_frac_sec = unpack('!IH', self.raw[14:20])
                self.time_us = time_frac_sec * 1000000 / 4096
                self.time_info = True
            
        else:
            self.time_info   = False
            range_bits = self.samples & 0xc000
            self.samples &= 0x3fff; # top two bits are range
            if range_bits == 0:
                self.range = 400000
            elif range_bits == 0x4000:
                self.range = 750000
            else:
                print 'Uknown range', hex(range_bits)

        if self.channels & 0x80:
            self.trigger_channel_enabled = True
            self.channels &= 0x7f
            self.number_of_eeg_channels = self.channels - 1
        else:
            self.trigger_channel_enabled = False
            self.number_of_eeg_channels = self.channels


        if self.frame_num & 0x80000000:
            self.frame_num -= 0x80000000
            self.time_soc, time_frac_sec = unpack('!IH', self.data[0:6])
            if (self.time_soc < 256):
                print hex(0xff & self.time_soc), hex(time_frac_sec >> 8), hex(time_frac_sec & 0xff)
                z_tuple = unpack('16f', self.data[6:70])
                print z_tuple
                # calculate impedance_structure_size + padding
                Z_RESULT_STRUCTURE_SIZE = 72
                ads_read_data_size = self.channels * 3
                i = Z_RESULT_STRUCTURE_SIZE
                while((i % ads_read_data_size) != 0):
                    i += 3
                self.data = self.data[i:] # remove the impedance result from the data
                # now update remaining samples to be parsed
                assert ((i % (3*self.channels)) == 0), i
                self.samples -= i / (3 * self.channels)
            else:
                assert self.version < 3, self.version # timing is not embedded in data anymore
                timing_structure_size = self.channels * 3
                if self.channels == 1:
                    timing_structure_size = 6 # minimum timing structure size
                    self.samples -= 1         # timing structure takes two sample sizes
                self.samples -= 1
                self.data = self.data[timing_structure_size:] # remove the timestamp from the data
                self.time_info = True
        if self.crc_size > 0:
            self.crc = unpack('!H', self.raw[-self.crc_size:])[0]

        sample_rate_bits = ord(self.raw[1]) & 0xc0
        if sample_rate_bits == 0:
            self.sample_rate = 250
        elif sample_rate_bits == 0x40:
            self.sample_rate = 500
        elif sample_rate_bits == 0x80:
            self.sample_rate = 1000
        else:
            print 'Uknown sample rate', hex(sample_rate_bits)

    def print_frame_info(self):
        print '--- Dataframe ---'
        print 'sync:       ', hex(ord(self.raw[0]))
        print 'version:    ', self.version
        print 'sample_rate:', self.sample_rate
        print 'framesize:  ', self.size
        print 'frame type: ', self.frame_type
        print 'frame num:  ', self.frame_num
        print 'channels:   ', self.channels
        print 'samples:    ', self.samples
        print 'range (mV): ', self.range / 1000
        print 'crc:        ', hex(self.crc)
        if self.time_info:
            print 'time soc: %d.%d' % (self.time_soc, self.time_us)
        if len(self.data) > 0:
            print 'channel 1:  ', hex(ord(self.data[0])), hex(ord(self.data[1])), hex(ord(self.data[2]))

# statuses: Discovered, Recording, Disconnected, Not Present

def tr(text):
    return QtGui.QApplication.translate("Form", text, None, QtGui.QApplication.UnicodeUTF8)

def log(message, device_id = None):
    m = strftime("%Y-%m-%d %H:%M:%S: ", localtime())
    if device_id:
        m += device_id + ': '
    m += message
    print m

def get_filename(device_id, ext=None):
    s = 'Avatar_' + device_id + '_'
    s += strftime("%Y-%m-%d_%H-%M-%S", localtime())
    if ext:
        s += '.' + ext
    return s

class TableItem(QtGui.QTableWidgetItem):
    def __init__(self, text):
        QtGui.QTableWidgetItem.__init__(self, text)
        center = QtCore.Qt.AlignHCenter + QtCore.Qt.AlignVCenter
        self.setTextAlignment(center)

class DiscoverWorker(QtCore.QThread):

    def __init__(self, main_thread, discoverCheckBox, parent = None):
        QtCore.QThread.__init__(self, parent)
        self.exiting = False
        self.discoverCheckBox = discoverCheckBox
        self.discoverCheckBox.setChecked(True)
        self.main_thread = main_thread

    def __del__(self):
        self.exiting = True
        self.wait()

    def run(self):
        while not self.exiting:
            if self.discoverCheckBox.isChecked():
                try:
                    self.main_thread.free_to_connect.acquire()
                    try:
                        devices = bluetooth.discover_devices(lookup_names=True) # default 8 seconds
                    finally:
                        self.main_thread.free_to_connect.release()
                except:
                    last_type, last_value, last_traceback=sys.exc_info()
                    log('Discover thread: %s' % traceback.format_exception_only(last_type,last_value)[0])
                    log("Waiting 10 seconds for bluetooth adapter to recover and/or Avatar EEG device to be found")
                else:
                    self.emit(QtCore.SIGNAL("discover_complete_event(PyQt_PyObject)"),
                              devices)
            sleep(10)

class ReceiveDataWorker(QtCore.QThread):

    def __init__(self, main_thread, serial_num, bt_addr, write_csv, write_bdf, nsd_ip='127.0.0.1'):
        QtCore.QThread.__init__(self, None)
        self.exiting = False
        self.dataframes_rxd = 0
        self.last_dataframe_num = None
        self.frames_lost = 0
        self.serial_num = serial_num
        self.bt_addr = bt_addr
        self.nsd_ip = nsd_ip
        self.dataframe = DataFrame()
        self.write_csv = write_csv
        self.write_bdf = write_bdf
        self.csv_file = None
        self.bdf_file = None
        self.num_bdf_records = 0
        self.csv_header_written = False
        self.bdf_header_written = False
        self.main_thread = main_thread
        
    def stop(self):
        self.exiting = True
        self.wait()

    # if the object which holds the thread gets cleaned up, your thread will die with it
    # most likely give you some kind of segmentation fault. this avoids that
    def __del__(self):
        self.exiting = True
        self.wait()

    def run(self):
        max_tries = 10
        i = 1
        while not self.exiting:
            self.s = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            try:
                self.main_thread.free_to_connect.acquire()
                try:
                    # connect to Avatar EEG device
                    self.s.connect((self.bt_addr, 1))
                finally:
                    self.main_thread.free_to_connect.release()
            except:
                last_type, last_value, last_traceback=sys.exc_info()
                log('Could not connect: %s'\
                     % traceback.format_exception_only(last_type,last_value)[0],self.serial_num)

                i += 1
                if i > max_tries:
                    log('Giving up on trying to connect', self.serial_num)
                    return;
                log("Waiting before try %d of %d" % (i, max_tries), self.serial_num)
                self.s.close()

                #Fix for Windows 7 connection issues
                if os.path.exists('btpair.exe'):
                    log("Trying to re-pair with device.", self.serial_num)
                    os_comm = 'btpair -u -b' + self.bt_addr
                    log("Running command: %s" % os_comm)
                    os.system(os_comm)

                sleep(5)
            else:
                base_filename = get_filename(self.serial_num)
                self.emit(QtCore.SIGNAL("device_connection_event(PyQt_PyObject,PyQt_PyObject,PyQt_PyObject,PyQt_PyObject)"),
                          True, self.serial_num, self.bt_addr, base_filename)
                break

        if self.exiting:
            return

        try:
            self.s.settimeout(600) # only supported on Linux
        except:
            pass

        # connect to Neuroserver
        if self.nsd_ip:
            self.nsd = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            try:
                self.nsd.connect((self.nsd_ip, 8336))
            except:
                self.nsd = None
            else:
                self.nsd.send('eeg\n')
                get_ok(self.nsd)
                self.nsd.send('setheader %s\n' % edf_header)
                get_ok(self.nsd)
        else:
            self.nsd = None

        # open output files
        if self.write_csv:
            self.csv_file = open(get_filename(self.serial_num, 'csv'), 'wb')
        if self.write_bdf:
            self.bdf_file = open(get_filename(self.serial_num, 'bdf'), 'wb')

        # set frame count and lost to 0
        self.emit(QtCore.SIGNAL("device_rx_event(PyQt_PyObject,PyQt_PyObject)"),
                  0, self.bt_addr)
        self.emit(QtCore.SIGNAL("frame_lost_event(PyQt_PyObject,PyQt_PyObject)"),
                  0, self.bt_addr)

        while not self.exiting:
            try:
                l = self.s.recv(4096)
            except:
                # add time out for case where we are not receiving anything
                # yet we are still connected
                self.s.close()
                last_type, last_value, last_traceback=sys.exc_info()
                log('Receive thread: Connection closed: %s' % \
                        traceback.format_exception_only(last_type,last_value)[0], self.serial_num)
                break
            if l == '':
                break
            # print 'recieved %d bytes' % len(l)
            self.build_frame_from_rxd_bytes(l)
        try:
            self.s.close()
        except:
            pass
        if self.csv_file:
            self.csv_file.close()
            log('Closed file: %s' % self.csv_file.name)
        if self.bdf_file:
            self.bdf_file.close()
            log('Closed file: %s' % self.bdf_file.name )
        self.emit(QtCore.SIGNAL("device_connection_event(PyQt_PyObject,PyQt_PyObject,PyQt_PyObject,PyQt_PyObject)"),
                  False, self.serial_num, self.bt_addr, None)

    def send_impedance_check(self):
        cmd = '\xaa\x01\x00\x0a\x03\x03' + '\x00' * 4
        self.s.send(cmd)
        log('Sent impedance check command', self.serial_num)

    def send_set_time(self):
        set_time_command = '\xaa\x01\x00\x0a\x03\x01'
        t = localtime()
        set_time_command += pack('!I', int(timegm(t)))
        self.s.send(set_time_command)
        log('Sent set time command: %s' % asctime(t))

    def send_input_short(self):
        cmd = '\xaa\x01\x00\x0a\x03\x02'
        cmd += '\xff\x00\x00' # input short
        cmd += '\x00'            # spare
        self.s.send(cmd)
        log('Sent input short command', self.serial_num)

    def send_input_square_wave(self):
        cmd = '\xaa\x01\x00\x0a\x03\x02'
        cmd += '\x00\xff\x00' # input short
        cmd += '\x00'            # spare
        self.s.send(cmd)
        log('Sent input to test signal command', self.serial_num)

    def send_input_electrodes(self):
        cmd = '\xaa\x01\x00\x0a\x03\x02'
        cmd += '\x00\x00\xff' # input short
        cmd += '\x00'            # spare
        self.s.send(cmd)
        log('Sent input to normal command', self.serial_num)

    def process_dataframe(self):
        # check for lost frames
        if self.last_dataframe_num != None:
            if self.dataframe.frame_num < self.last_dataframe_num:
                log('Discarding corrupt frame: frame_num < last_dataframe (%d %d)',
                    self.dataframe.frame_num, self.last_dataframe_num, self.serial_num)
                return;

            if self.last_dataframe_num+1 != self.dataframe.frame_num:
                log('Lost data: expected=%d actual=%d' % (self.last_dataframe_num+1,
                                                          self.dataframe.frame_num),
                    self.serial_num)
                # increment lost sample count
                self.frames_lost += self.dataframe.frame_num - (self.last_dataframe_num+1)
                self.emit(QtCore.SIGNAL("frame_lost_event(PyQt_PyObject,PyQt_PyObject)"),
                          self.frames_lost, self.bt_addr)

        self.last_dataframe_num = self.dataframe.frame_num
        for i in range(self.dataframe.samples):
            file_data_tuple = ()
            nsd_data_tuple = ()
            indx = i * self.dataframe.channels * 3
            if self.bdf_file:
                if self.num_bdf_records == 0:
                    bdf_record = '+0\x14\x14Start Recording\x14'
                else:
                    bdf_record = '+%0.6f\x14\x14' % \
                        (float(self.num_bdf_records)/self.dataframe.sample_rate)
                self.num_bdf_records += 1
                bdf_record += (60-len(bdf_record)) * '\x00'

            first_eeg_channel = 0
            if self.dataframe.trigger_channel_enabled == True:
                spare, value = unpack('HB',self.dataframe.data[indx:indx+3])
                keypad_button_state = (value & 0x02) >> 1
                optical_input_state = (value & 0x1) ^ 1 # invert
                if self.csv_file:
                    file_data_tuple += (optical_input_state, keypad_button_state)
                if self.bdf_file:
                    # BDF is little endian
                    # use B instead of other types to advoid having to specify alignment
                    bdf_record += pack('BBBBBB', optical_input_state, 0, 0, keypad_button_state, 0, 0)
                first_eeg_channel = 1
            for j in range(first_eeg_channel, self.dataframe.channels):
                if self.bdf_file:
                    # input is in 3 byte packed network (big endian) order while BDF is little endian
                    for k in range(3):
                        bdf_record += self.dataframe.data[indx+j*3+2-k]
                if self.nsd or self.csv_file:
                    # convert 24 bit int to 32 bit int
                    value = unpack('!i',self.dataframe.data[indx+j*3:indx+j*3+3]+'\0')[0] >> 8
                    file_data_tuple += (value,)
                    nsd_data_tuple += (value,)
            if self.nsd and ((i % 1) == 0):
                format_string = '%d ' * (self.dataframe.channels - 1);
                format_string += '%d\n'
                data_string = '! %d %d ' % (self.dataframe.frame_num, self.dataframe.channels)
                data_string += format_string % nsd_data_tuple
                self.nsd.send(data_string)
                get_ok(self.nsd)
            if self.csv_file:
                if self.csv_header_written == False:
                    if self.dataframe.version >= 3:
                        csv_header = "unix_soc, micro_sec, frame_number, "
                    else:
                        csv_header = "frame_number, "
                    if self.dataframe.trigger_channel_enabled == True:
                        csv_header += "optical_input, "
                        csv_header += "keypad_button, "
                    for i in range(1, self.dataframe.number_of_eeg_channels):
                        csv_header += "channel_%d, " % i
                    csv_header += "channel_%d\n" % self.dataframe.number_of_eeg_channels
                    self.csv_file.write(csv_header)
                    self.csv_header_written = True
                if self.dataframe.trigger_channel_enabled == True:
                    # trigger channel is going to cause two columns
                    format_string = '%d, ' * (self.dataframe.channels);
                else:
                    format_string = '%d, ' * (self.dataframe.channels - 1);
                format_string += '%d\n'
                data_string = ''
                if self.dataframe.version >= 3:
                    data_string += '%d, %d, ' % (self.dataframe.time_soc, self.dataframe.time_us)
                    self.dataframe.time_us += 1000000 / self.dataframe.sample_rate
                    if self.dataframe.time_us >= 1000000:
                        self.dataframe.time_soc += 1
                        self.dataframe.time_us -= 1000000
                data_string += '%d, ' % self.dataframe.frame_num
                data_string += format_string % file_data_tuple
                self.csv_file.write(data_string)
            if self.bdf_file:
                if self.bdf_header_written == False:
                    bdf_header = create_bdf_header(self.serial_num,
                                                   self.dataframe.trigger_channel_enabled,
                                                   self.dataframe.number_of_eeg_channels,
                                                   self.dataframe.sample_rate,
                                                   self.dataframe.range/2)
                    self.bdf_header_written = True
                    self.bdf_file.write(bdf_header)
                self.bdf_file.write(bdf_record)

        if self.bdf_file and self.bdf_header_written:
            # update number of records for valid BDF
            self.bdf_file.seek(236)
            self.bdf_file.write('%-8s' % self.num_bdf_records)
            self.bdf_file.seek(0, SEEK_END) # goto end of file
        self.dataframes_rxd += 1
        self.emit(QtCore.SIGNAL("device_rx_event(PyQt_PyObject,PyQt_PyObject)"),
                  self.dataframes_rxd, self.bt_addr)

    def build_frame_from_rxd_bytes(self, l):
        if l == '':
            log('Unexpected null data', self.serial_num)
            assert 0
        while len(l) > 0:
            # step 1 - sync byte
            # step 2 - protocol version
            # step 3 - frame size
            # step 4 - read the complete frame
            if self.dataframe.raw == '':
                # step 1 - sync byte
                try:
                    sync_index = l.index('\xaa')
                except:
                    log('1 Discard %d bytes' % len(l), self.serial_num)
                    # for c in l: print '%02X'%ord(c),
                    # print
                    l = ''
                else:
                    if sync_index > 0:
                        log('2 Discard %d bytes' % sync_index, self.serial_num)
                        # for c in l[:sync_index]: print '%02X'%ord(c),
                        # print
                    self.dataframe.raw = '\xaa'
                    l = l[sync_index+1:]

            elif len(self.dataframe.raw) < 2:
                # step 2 - next byte must be protocol version
                self.dataframe.version = ord(l[0]) & 0x3f # top two bits are rate
                self.dataframe.raw += l[0]
                l = l[1:]
                if self.dataframe.version > 3 and self.dataframe.version < 1:
                    log('Bad version of %x discard 2 bytes' % self.dataframe.version, self.serial_num)
                    self.dataframe.raw = ''

            elif len(self.dataframe.raw) < 4:
                # step 3 - frame size
                bytes_needed = 4 - len(self.dataframe.raw)
                assert( bytes_needed == 1 or bytes_needed == 2)
                if len(l) < 2:
                    self.dataframe.raw += l[0]
                    l = l[1:]
                else:
                    self.dataframe.raw += l[:bytes_needed]
                    l = l[bytes_needed:]

                if len(self.dataframe.raw) == 4:
                    self.dataframe.size = unpack('!H', self.dataframe.raw[2:4])[0]
                    if self.dataframe.size < Frame.minimum_size or self.dataframe.size > Frame.maximum_size:
                        log('Bad frame size of %d discard 4 bytes' % self.dataframe.size, self.serial_num)
                        self.dataframe.raw = ''
            else:
                # step 4 - attempt to read the rest of the complete frame
                bytes_needed = self.dataframe.size - len(self.dataframe.raw)
                if len(l) >= bytes_needed:
                    bytes_to_add = bytes_needed
                    self.dataframe.raw += l[:bytes_to_add]
                    self.dataframe.unpack_frame()
                    #self.dataframe.print_frame_info()
                    result = self.dataframe.check()
                    if result == '':
                        self.process_dataframe()
                    else:
                        log('Frame check failed discarding %d bytes: %s' % (self.dataframe.size, result),
                            self.serial_num)
                        # for c in self.dataframe.raw: print '%02X'%ord(c),
                        # print

                    self.dataframe.raw = ''
                else:
                    bytes_to_add = len(l)
                    self.dataframe.raw += l[:bytes_to_add]
                l = l[bytes_to_add:]


class AvatarEEG(QtGui.QMainWindow):

    def __init__(self, parent=None):
        super(AvatarEEG, self).__init__()
        self.free_to_connect = Lock()
        self.ui = Ui_MainWindow()
        self.ui.setupUi(self)
        version = "$Revision: 363 $".replace( '$Revision: ', '' )[:-2]
        self.setWindowTitle(tr('Avatar EEG Driver'))
        t = 'Avatar EEG Driver version 0.%s' % version
        log(t)
        self.ui.version_label.setText(t)
        self.ui.tableWidget.setColumnWidth(1,120)
        self.ui.csvCheckBox.setChecked(write_to_csv_init)
        self.ui.bdfCheckBox.setChecked(write_to_bdf_init)
        self.ui.impedanceCheckButton.setVisible(False)
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        try:
            s.connect(('localhost', 8336))
        except:
            log("Neuroserver not running")
        else:
            log("Neuroserver detected")
            s.close()

        self.stimer = QtCore.QTimer()
        self.device_list = {}
        log("Starting discovery thread")
        self.discover_thread = DiscoverWorker(self, self.ui.discoverCheckBox)
        self.connect(self.discover_thread,
                     QtCore.SIGNAL('discover_complete_event(PyQt_PyObject)'),
                     self.discover_complete_event)

        self.discover_thread.start()

    def closeEvent(self, event):
        log('Avatar EEG Driver Exiting')
        del self.discover_thread
        for v in self.device_list.values():
            if v[1]:
                v[1].stop()

    def discover_complete_event(self, devices):
        bt_addr_list = []
        # check for new devices
        for bt_addr, name in devices:
            bt_addr_list.append(bt_addr)
            if name[:11] == 'Avatar EEG ' or name[:11] == 'Laird BTM 0':
                # this is an Avatar EEG device
                if bt_addr not in self.device_list.keys():
                    self.device_found(True, name[11:], bt_addr)
                elif self.get_status(bt_addr) == 'Not Present'\
                        or self.get_status(bt_addr) == 'Disconnected':
                    self.device_found(True, name[11:], bt_addr) # refound
        # check for devices that are no longer present
        for bt_addr in self.device_list.keys():
            if bt_addr not in bt_addr_list:
                # print bt_addr, devices
                if self.get_status(bt_addr) != 'Not Present':
                    self.device_found(False, None, bt_addr)

    def device_found(self, add, serial_num, bt_addr):
        if add:
            if bt_addr not in self.device_list.keys():
                row = self.ui.tableWidget.rowCount()
                self.device_list[bt_addr] = [row, None]
                self.ui.tableWidget.insertRow(row)
                self.ui.tableWidget.setItem(row, 0, TableItem(serial_num))
                self.ui.tableWidget.setItem(row, 2, TableItem('0'))
            self.update_status('Discovered', serial_num, bt_addr)
            r = ReceiveDataWorker(self, serial_num, bt_addr,
                                  self.ui.csvCheckBox.isChecked(),
                                  self.ui.bdfCheckBox.isChecked())
            self.connect(r,
                         QtCore.SIGNAL('device_connection_event(PyQt_PyObject,PyQt_PyObject,PyQt_PyObject,PyQt_PyObject)'),
                         self.device_connection_event)
            self.connect(r,
                         QtCore.SIGNAL('device_rx_event(PyQt_PyObject,PyQt_PyObject)'),
                         self.device_rx_event)
            self.connect(r,
                         QtCore.SIGNAL('frame_lost_event(PyQt_PyObject,PyQt_PyObject)'),
                         self.frame_lost_event)
            QtCore.QObject.connect(self.ui.impedanceCheckButton,QtCore.SIGNAL("clicked()"), r.send_impedance_check)
            QtCore.QObject.connect(self.ui.setTimeButton,QtCore.SIGNAL("clicked()"), r.send_set_time)
            QtCore.QObject.connect(self.ui.setInputShortButton,QtCore.SIGNAL("clicked()"), r.send_input_short)
            QtCore.QObject.connect(self.ui.setInputSquareWaveButton,QtCore.SIGNAL("clicked()"), r.send_input_square_wave)
            QtCore.QObject.connect(self.ui.setInputElectrodesButton,QtCore.SIGNAL("clicked()"), r.send_input_electrodes)
            r.start()
            self.device_list[bt_addr][1] = r
        else:
            # if status is Connected let receive thread detect disconnection
            # this handles the case where an erroneous discover may miss the device
            if self.get_status(bt_addr) != 'Connected':
                self.update_status('Not Present', serial_num, bt_addr)

    def device_connection_event(self, connected, serial_num, bt_addr, filename):
        if connected:
            self.update_status('Connected', serial_num, bt_addr)
            row = self.device_list[bt_addr][0]
            self.ui.tableWidget.setItem(row, 4, TableItem(filename))
        else:
            # can only transition to Not Present from disconnected
            assert self.get_status(bt_addr) != 'Not Present', self.get_status(bt_addr)
            r = self.device_list[bt_addr][1]
            r.stop()
            self.device_list[bt_addr][1] = None
            self.update_status('Disconnected', serial_num, bt_addr)

    def device_rx_event(self, samples, bt_addr):
        row = self.device_list[bt_addr][0]
        self.ui.tableWidget.setItem(row, 2, TableItem(str(samples)))

    def frame_lost_event(self, frames_lost, bt_addr):
        row = self.device_list[bt_addr][0]
        self.ui.tableWidget.setItem(row, 3, TableItem(str(frames_lost)))

    def update_status(self, status, serial_num, bt_addr):
        log(status, serial_num)
        row = self.device_list[bt_addr][0]
        self.ui.tableWidget.setItem(row, 1, TableItem(status))

    def get_status(self, bt_addr):
        row = self.device_list[bt_addr][0]
        return self.ui.tableWidget.item(row, 1).text()

def get_ok(s):
   s.recv(128)

def create_bdf_header(serial_number, trigger_channel_enabled, number_of_eeg_channels,
                      sample_rate, physical_max):
   header = ''
   header +=  '%-8s' % '\xff\x42\x49\x4f\x53\x45\x4d\x49'  # version
   header += '%-80s' % (serial_number + ' M 02-AUG-1951 Avatar_EEG')
   header += '%-80s' % 'Startdate 01-FEB-2012 EEG Avatar EEG'
   header +=  '%-8s' % '01.02.12' # start date
   header +=  '%-8s' % '01.02.12' # start time
   if trigger_channel_enabled == True:
       total_channels = 3 + number_of_eeg_channels
   else:
       total_channels = 1 + number_of_eeg_channels
   bytes_in_header = 256*(total_channels+1) # plus 1 for the 256 bytes of info
   header +=  '%-8s' % bytes_in_header      # bytes in header
   header += '%-44s' % 'BDF+C'              # reserved
   header +=  '%-8s' % '-1'                 # number of data records
   header +=  '%-8s' % (1./sample_rate)
   header +=  '%-4s' % total_channels       # signals in each record

   header += '%-16s' % 'BDF Annotations'    # signal label
   if trigger_channel_enabled == True:
       header += '%-16s' % 'Optical Input'
       header += '%-16s' % 'Keypad Button'
   for i in range(1,number_of_eeg_channels+1):
      label = 'EEG %d' % i
      header += '%-16s' % label             # signal label

   # tranducer type
   header += '%-80s' % ''
   if trigger_channel_enabled == True:
       header += '%-80s' % ''
       header += '%-80s' % ''
   for i in range(number_of_eeg_channels):
       header += '%-80s' % 'AgCl electrodes'

   # physical dimension
   header +=  '%-8s' % ''
   if trigger_channel_enabled == True:
       header += '%-8s' % ''
       header += '%-8s' % ''
   for i in range(number_of_eeg_channels):
       header +=  '%-8s' % 'uV'

   # physical min
   header +=  '%-8s' % '-1'
   if trigger_channel_enabled == True:
       header += '%-8s' % '0'
       header += '%-8s' % '0'
   for i in range(number_of_eeg_channels):
       header +=  '%-8s' % -physical_max

   # physical max
   header +=  '%-8s' % '1'
   if trigger_channel_enabled == True:
       header += '%-8s' % '1'
       header += '%-8s' % '1'
   for i in range(number_of_eeg_channels):
       header +=  '%-8s' % physical_max

   # digital min
   header +=  '%-8s' % '-8388608'
   if trigger_channel_enabled == True:
       header +=  '%-8s' % '0'
       header +=  '%-8s' % '0'
   for i in range(number_of_eeg_channels):
      header +=  '%-8s' % '-8388608'

   # digital max
   header +=  '%-8s' % '8388607'
   if trigger_channel_enabled == True:
       header +=  '%-8s' % '1'
       header +=  '%-8s' % '1'
   for i in range(number_of_eeg_channels):
      header +=  '%-8s' % '8388607'

   # prefiltering
   header += '%-80s' % ''
   if trigger_channel_enabled == True:
        header += '%-80s' % ''
        header += '%-80s' % ''
   for i in range(number_of_eeg_channels):
      header += '%-80s' % ''

   # samples in each record
   header +=  '%-8s' % '20'  # 60 bytes for an annotation and 3 bytes per 'sample'
   if trigger_channel_enabled == True:
        header += '%-8s' % '1'
        header += '%-8s' % '1'
   for i in range(number_of_eeg_channels):
      header +=  '%-8s' % '1'

   # reserved
   header += '%-32s' % ''
   if trigger_channel_enabled == True:
       header += '%-32s' % ''
       header += '%-32s' % ''
   for i in range(number_of_eeg_channels):
       header += '%-32s' % ''

   assert len(header) == bytes_in_header, len(header)
   return header

def unit_tests():
    test_object = ReceiveDataWorker(None, '01000', '00:03:B5', False, False)
    test_object.nsd = None
    fullframe =  '\xaa\x02\x01\x8e\x01\x00\x00\x00\x64\x08\x00\x10'
    fullframe += '\xff\xff\xfe'*(8*16)
    fullframe += '\x1a\x92' # verified by http://www.lammertbies.nl/comm/info/crc-calculation.html
    length = 0

    # test_object.build_frame_from_rxd_bytes('')
    # test building one byte at a time
    for c in fullframe:
        assert len(test_object.dataframe.raw) == length, (length, len(test_object.dataframe.raw))
        test_object.build_frame_from_rxd_bytes(c)
        length += 1
    assert test_object.dataframes_rxd == 1, test_object.dataframes_rxd

    fullframe = fullframe[0:8] + '\x65' + fullframe[9:] # incrment frame_num
    fullframe = fullframe[0:-2] + '\x14\x2a' # update crc
    test_object.build_frame_from_rxd_bytes(fullframe[0:-1])
    assert test_object.dataframes_rxd == 1, test_object.dataframes_rxd
    test_object.build_frame_from_rxd_bytes(fullframe[-1:])
    assert test_object.dataframes_rxd == 2, test_object.dataframes_rxd

    fullframe = fullframe[0:8] + '\x66' + fullframe[9:] # incrment frame_num
    fullframe = fullframe[0:-2] + '\x07\xe2' # update crc
    test_object.build_frame_from_rxd_bytes(fullframe)
    assert test_object.dataframes_rxd == 3

    # test_object.build_frame_from_rxd_bytes('\xff'*Frame.minimum_size)

    fullframe = fullframe[0:8] + '\x67' + fullframe[9:] # incrment frame_num
    fullframe = fullframe[0:-2] + '\x09\x5a' # update crc
    test_object.build_frame_from_rxd_bytes(fullframe)
    assert test_object.dataframes_rxd == 4

if __name__ == "__main__":
    try:
        unit_tests()
        app = QtGui.QApplication(sys.argv)
        MainWindow = AvatarEEG()
        MainWindow.show()
        app.exec_()
    except:
        traceback.print_exc()
        if keep_terminal_open:
            # keep open so a windows user can see the results
            raw_input("Press enter to close this window...")
