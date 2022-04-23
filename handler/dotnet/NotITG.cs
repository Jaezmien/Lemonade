using System;
using System.Collections.Generic;
using System.Timers;
using System.Linq;

namespace NotITG
{
	public partial class NotITGWrapper
	{
		public int applicationID;
		public NotITGWrapper(int appID)
		{
			applicationID = appID;

			t = new Timer();
			t.Elapsed += (e, o) => { Tick(); };
			t.Interval = 10;
			t.Enabled = false;

			notitgClient = new External.NotITG();
		}

		public class BufferEventArgs : EventArgs
		{
			public int[] Buffer { get; set; }
		}
		public delegate void BufferEventHandler(object sender, BufferEventArgs e);

		public event BufferEventHandler OnRead;
		public event BufferEventHandler OnWrite;
		public event BufferEventHandler OnBufferRead;

		public event EventHandler OnConnect;
		public event EventHandler OnInitialized;
		public event EventHandler OnDisconnect;

		private bool scanDeep = false;
		private int? scanProcessID;
		public void Start(bool deep = false, int? pid = null)
		{
			if (t.Enabled) return;

			scanDeep = deep;
			scanProcessID = pid;
			t.Start();
		}

		private Timer t;
		private External.NotITG notitgClient;
		public bool IsConnected
		{
			get
			{
				if (notitgClient == null) return false;
				return notitgClient.Connected;
			}
		}

		public string GamePath
		{
			get
			{
				if (notitgClient == null) return "";
				return notitgClient.GamePath;
			}
		}

		public void Stop()
		{
			if (!t.Enabled) return;
			notitgClient.Disconnect();
			t.Stop();
		}

		private List<WriteStruct> WriteBuffer = new List<WriteStruct>();
		private List<int> ReadBuffer = new List<int>();
		private struct WriteStruct
		{
			public enum SetStatus
			{
				SINGLE = 0,
				SET = 1,
				SET_END = 2,
			}
			public List<int> buffer;
			public SetStatus set;
		}

		public void Write(int[] buffer)
		{
			if (!notitgClient.Connected) return;
			if( buffer.Length <= 26 )
			{
				WriteBuffer.Add(new WriteStruct()
				{
					buffer = buffer.ToList(),
					set = WriteStruct.SetStatus.SINGLE,
				});
			}
			else
			{
				for(int i = 0; i < buffer.Length; i += 26)
				{
					WriteBuffer.Add(new WriteStruct()
					{
						buffer = buffer.ToList().GetRange(i, Math.Max(26, buffer.Length - 1 - i)),
						set = i + 26 >= buffer.Length ? WriteStruct.SetStatus.SET_END : WriteStruct.SetStatus.SET
					});
				}
			}
		}

		private string ENCODE_GUIDE = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n'\"~!@#$%^&*()<>/-=_+[]:;.,`{}";
		public int[] Encode(string str)
		{
			return str.ToCharArray().Select(ch => ENCODE_GUIDE.IndexOf(ch) + 1).ToArray();
		}
		public string Decode(int[] str)
		{
			return string.Join("", str.Select(index => ENCODE_GUIDE[index - 1]).ToArray());
		}

		private enum HEART
		{
			DISCONNECTED = 0,
			SEARCHING = 1,
			CONNECTED = 2,
		}
		private HEART heartbeatStatus = HEART.DISCONNECTED;
		private bool initialized = false;
		private void Tick()
		{
			// Temporary disable the timer
			// .Heartbeat() doesn't "temporarily" stop the timer "thread" (i dont know if this is the right term).
			// The Timer WILL run the Tick function regardless of whether it has finished the previous tick.
			t.Enabled = false;

			if (!notitgClient.Heartbeat())
			{
				if(
					heartbeatStatus != HEART.CONNECTED &&
					(
						(scanProcessID != null && notitgClient.ScanFromProcessID((int)scanProcessID)) ||
						(scanProcessID == null && notitgClient.Scan(scanDeep))
					)
				)
				{
					if(notitgClient.Version == External.Details.NotITGVersionNumber.V1 || notitgClient.Version == External.Details.NotITGVersionNumber.V2)
					{
						Console.WriteLine("Unsupported NotITG Version! Expected at least V3");
						Stop();
						return;
					}
					heartbeatStatus = HEART.CONNECTED;
					initialized = false;

					OnConnect?.Invoke(this, null);
				}
				else if(heartbeatStatus == HEART.DISCONNECTED)
				{
					heartbeatStatus = HEART.SEARCHING;
				}
				else if(heartbeatStatus == HEART.CONNECTED)
				{
					notitgClient.Disconnect();
					heartbeatStatus = HEART.DISCONNECTED;
					OnDisconnect?.Invoke(this, null);
				}
			}
			else if(notitgClient.GetExternal(60) != 0)
			{
				if(!initialized)
				{
					OnInitialized?.Invoke(this, null);
					initialized = true;
				}

				// READ
				if( notitgClient.GetExternal(57) == 1 && notitgClient.GetExternal(59) == applicationID)
				{
					int length = notitgClient.GetExternal(54);
					int[] buffer = new int[length];

					for( int i = 28; i < 28 + length; i++ )
					{
						buffer[i - 28] = notitgClient.GetExternal(i);
						notitgClient.SetExternal(i, 0);
					}

					int stat = notitgClient.GetExternal(55);
					OnBufferRead?.Invoke(this, new BufferEventArgs() { Buffer = buffer });
					if( stat == 0 )
					{
						OnRead?.Invoke(this, new BufferEventArgs() { Buffer = buffer });
					}
					else
					{
						ReadBuffer.AddRange(buffer);
						if( stat == 2 )
						{
							OnRead?.Invoke(this, new BufferEventArgs() { Buffer = ReadBuffer.ToArray() });
							ReadBuffer.Clear();
						}
					}
				}

				// WRITE
				if( WriteBuffer.Count > 0 && notitgClient.GetExternal(56) == 0 )
				{
					notitgClient.SetExternal(56, 1);

					var WriteContent = WriteBuffer[0];
					WriteBuffer.RemoveAt(0);

					for( int i = 0; i < WriteContent.buffer.Count; i++ )
					{
						notitgClient.SetExternal(i, WriteContent.buffer[i]);
					}

					notitgClient.SetExternal(26, WriteContent.buffer.Count);
					notitgClient.SetExternal(27, (int)WriteContent.set);
					notitgClient.SetExternal(56, 2);
					notitgClient.SetExternal(58, applicationID);

					OnWrite?.Invoke(this, new BufferEventArgs()
					{
						Buffer = WriteContent.buffer.ToArray()
					});
				}
			}

			t.Enabled = true;
		}
	}
}
