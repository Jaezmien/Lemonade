import argparse
parser = argparse.ArgumentParser( description='Settings' )
parser.add_argument("--unknown", "-U", dest="unknown", action="store_true", help="scans all processes instead of only relying on the filename")
parser.add_argument("--pid", dest="pid", action="store", type=int, help="get a specific NotITG process from id")
args = parser.parse_args()

# Program ID
APP_ID = -1

# A connection to NotITG is made
def on_connect():
	pass

# NotITG disconnects/exits
def on_disconnect():
	pass

# Receiving a (partial) buffer
def on_read(buffer, setType):
	pass

# Receiving full buffers
def on_buffer_read(buffer):
	pass

# On successful buffer write
def on_write(buffer, setType):
	pass

# Program is exiting
def on_exit(sig, frame):
	#print( "Exiting..." )
	exit( 0 )


"""
------------------------------------------------------------------------
--------------------------DON'T TOUCH IT KIDDO--------------------------
------------------------------------------------------------------------
"""


#region Helpers
_ENCODE_GUIDE = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n'\"~!@#$%^&*()<>/-=_+[]:;.,`{}"
def encode_string(str):
	return list(map( lambda x: _ENCODE_GUIDE.find(x)+1, [x for x in str] ))
def decode_buffer(buff):
	return "".join( list(map( lambda x: _ENCODE_GUIDE[x-1], buff )) )

def chunks(lst, n):
	for i in range(0, len(lst), n): yield lst[i:i + n]
def write_to_notitg(buffer):
	global _notitg_write_buffer

	if len( buffer ) <= 26:
		_notitg_write_buffer.append({ "buffer": buffer, "set": 0, })
	else:
		buffer_chunks = list( chunks(buffer, 26) )
		for i in range(len(buffer_chunks)):
			_notitg_write_buffer.append({ "buffer": buffer_chunks[i], "set": 2 if len(buffer_chunks) == (i+1) else 1 })
#endregion

#region NotITG Handling
import notitg
import time
import signal
NotITG = notitg.NotITG()

_notitg_read_buffer = []
_notitg_write_buffer = []

_heartbeat_status = 0
_external_initialized = False
_initialize_warning = False
def tick_notitg():
	global _initialize_warning
	global _external_initialized

	if not NotITG.Heartbeat():
		global _heartbeat_status

		if (args.pid and NotITG.FromProcessId(args.pid)) or NotITG.Scan( args.unknown ):
			if NotITG.GetDetails()[ "Version" ] in ["V1", "V2"]:
				print("⚠ Unsupported NotITG version! Expected V3 or higher, got " + NotITG.GetDetails()[ "Version" ])
				NotITG.Disconnect()
				return
			_heartbeat_status = 2
			_details = NotITG.GetDetails()
			print("> -------------------------------")
			print("✔️  Found NotITG!")
			print(">> Version: " + _details[ "Version" ] )
			print(">> Build Date: " + str(_details[ "BuildDate" ]) )
			print("> -------------------------------")
		elif _heartbeat_status == 0:
			_heartbeat_status = 1
			print("❌ Could not find a version of NotITG!")
		elif _heartbeat_status == 2:
			_heartbeat_status = 0
			_external_initialized = False
			_initialize_warning = False
			print("❓ NotITG has exited")
			on_disconnect()

	else:
		if NotITG.GetExternal(60) == 0:
			if not _initialize_warning:
				_initialize_warning = True
				print( "⏳ NotITG is initializing..." )
			return
		elif not _external_initialized:
			print( "🏁 NotITG has initialized!" )
			on_connect()
			_external_initialized = True

		global _notitg_write_buffer
		global _notitg_read_buffer

		if NotITG.GetExternal(57) == 1 and NotITG.GetExternal( 59 ) == APP_ID:
			read_buffer = []

			for index in range( 28, 28 + NotITG.GetExternal(54) ):
				read_buffer.append( NotITG.GetExternal(index) )
				NotITG.SetExternal( index, 0 )

			SET_STATUS = NotITG.GetExternal(55)
			on_read( read_buffer, SET_STATUS )
			if SET_STATUS == 0: on_buffer_read( read_buffer )
			else:
				_notitg_read_buffer.extend( read_buffer )
				if SET_STATUS == 2:
					on_buffer_read( _notitg_read_buffer )
					_notitg_read_buffer.clear()

			NotITG.SetExternal( 54, 0 )
			NotITG.SetExternal( 55, 0 )
			NotITG.SetExternal( 59, 0 )
			NotITG.SetExternal( 57, 0 )

		if len( _notitg_write_buffer ) > 0 and NotITG.GetExternal( 56 ) == 0:
			NotITG.SetExternal( 56, 1 )
			write_buffer = _notitg_write_buffer.pop( 0 )

			for index, value in enumerate( write_buffer["buffer"] ): NotITG.SetExternal( index, value )
			NotITG.SetExternal( 26, len(write_buffer["buffer"]) )
			NotITG.SetExternal( 27, write_buffer["set"] )
			NotITG.SetExternal( 56, 2 )
			NotITG.SetExternal( 58, APP_ID )
			on_write( write_buffer["buffer"], write_buffer["set"] )

signal.signal(signal.SIGINT, on_exit)

while True:
	tick_notitg()
	time.sleep( 0.1 )
#endregion