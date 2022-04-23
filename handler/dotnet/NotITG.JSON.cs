using System.Collections.Generic;
using Newtonsoft.Json;

namespace NotITG
{
    public partial class NotITGWrapper
    {
		public void WriteJSON(int index, object data)
		{
			if (!notitgClient.Connected) return;
			List<int> buffer = new List<int>() { index };
			buffer.AddRange(this.Encode(JsonConvert.SerializeObject(data)));
			Write(buffer.ToArray());
		}
	}
}
