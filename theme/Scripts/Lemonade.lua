Lemonade = {}

--[[

	<< LEMONADE'S EXTERNAL MAPPING >>
	0-25  - READ        (26)
	26    - READ LENGTH
	27    - IS BUFFER A PART OF A SET (0=No, 1=Yes, 2=Yes and the end of set)
	28-53 - WRITE       (26)
	54    - WRITE LENGTH
	55    - IS BUFFER A PART OF A SET (0=No, 1=Yes, 2=Yes and the end of set)
	56    - Reader Flag (0=Idle,1=Reserved/Writing,2=Read) [by external application]
	57    - Writer Flag (0=Idle,1=Avaiable)                [by notitg]
	58    - Sender ID for Reader
	59    - Sender ID for Writer
	60    - Has NotITG initialized? (and not in loading state)
	61    - Unused
	62    - Unused
	63    - Unused

]]

Lemonade.Enabled = true
function Lemonade.Disable(self, disable) self.Enabled = not disable end

Lemonade.Initialized = false
Lemonade.Last_Seen_Write = nil
Lemonade.Timer = nil
Lemonade.Buffers = {}
Lemonade.Hooks = {}
local ReadBuffer = {}
local BUFFER_LENGTH = 26

-- Simple Encode/Decode
do
	local GUIDE = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n'\"~!@#$%^&*()<>/-=_+[]:;.,`{}"
	function Lemonade.Encode(self, str)
		local t = {}
		for i=1,string.len(str) do
			local char = string.sub(str,i,i)
			for c=1,string.len(GUIDE) do
				if string.sub(GUIDE,c,c) == char then table.insert(t,c) break end
			end
		end
		return t
	end
	function Lemonade.Decode(self, buff)
		local s = ""
		for i,v in pairs(buff) do
			s = s..(string.sub(GUIDE,v,v))
		end
		return s
	end
end

--[[
	id = Program ID
	buffer = Array of numbers to send

	Buffer
	{
		id: number,
		buffer: int[],
		state: BufferState
	}

	BufferState
	{
		0 = Individual,
		1 = Incomplete Set,
		2 = End of Set
	}
]]
local Buffer_Add = function(self, id, buffer)
	if type(id) ~= 'number' then Debug('[Lemonade] Sender id must be a number.'); return self end

	if table.getn(buffer) > BUFFER_LENGTH then
		local ind = 1
		while ind<=table.getn(buffer) do
			local _t = {}
			for i=ind, ind+(BUFFER_LENGTH-1) do
				if i <= table.getn(buffer) then table.insert(_t, buffer[i] ) end
			end
			table.insert( self, {
				id = id,
				buffer = _t,
				state = ( ind+BUFFER_LENGTH > table.getn(buffer) ) and 2 or 1
			} )
			ind = ind + BUFFER_LENGTH
		end
	else
		table.insert( self, {
			id = id,
			buffer = buffer,
			state = 0,
		} )
	end
end
setmetatable(Lemonade.Buffers, {
	__index = function(self, key)
		if key == 'Add' then return Buffer_Add end
		return nil
	end
})

--[[
	id = Program ID
	unique = Unique Hook ID
	func = Function to run
]]
local Hooks_Add = function(self, id, unique, func)
	if type(id) ~= 'number' then
		Debug('[Lemonade] Hook id must be a number.')
		return
	end
	self[ id ] = self[ id ] or {}
	self[ id ][ unique ] = func
end
local Hooks_Remove = function(self, id, unique)
	if type(id)~='number' then
		Debug('[Lemonade] Hook id must be a number.')
		return
	end
	if not self[ id ] then
		Debug('[Lemonade] Hook id doesn\'t contain any hooks.')
		return
	end
	self[ id ][ unique ] = nil
end
local Hooks_Includes = function(self, id) return self[ id ] ~= nil end
local Hooks_Get = function(self, id) return self[ id ] end
setmetatable(Lemonade.Hooks, {
	__index = function(self, key)
		if key == 'Add' then return Hooks_Add end
		if key == 'Remove' then return Hooks_Remove end
		if key == 'Includes' then return Hooks_Includes end
		if key == 'Get' then return Hooks_Get end
		return nil
	end
})

-- Updating --
function Lemonade.Tick(self)
	if not self.Enabled or not self.Initialized then return end
	if not (FUCK_EXE and tonumber(GAMESTATE:GetVersionDate()) > 20180617) then
		self.Enabled = false
		return
	end

	-- READ --
	if GAMESTATE:GetExternal(56) == 2 then
		local r_bf = {}
		for i=1,GAMESTATE:GetExternal(26) do
			table.insert( r_bf , GAMESTATE:GetExternal(i-1) )
			GAMESTATE:SetExternal( i-1 , 0 )
		end
		GAMESTATE:SetExternal(26,0)
		local r_id = GAMESTATE:GetExternal(58)

		if GAMESTATE:GetExternal(27) == 0 then

			if self.Hooks:Includes(r_id) then
				for i,v in pairs( self.Hooks:Get(r_id) ) do v( r_bf ) end
			end

		else

			ReadBuffer[r_id] = ReadBuffer[r_id] or {}
			for i,v in pairs(r_bf) do table.insert( ReadBuffer[r_id], v ) end
			if GAMESTATE:GetExternal(27) == 2 then
				if self.Hooks:Includes(r_id) then
					for i,v in pairs( self.Hooks:Get(r_id) ) do v( ReadBuffer[r_id] ) end
				end
				ReadBuffer[r_id] = nil
			end

		end

		GAMESTATE:SetExternal(27, 0)
		GAMESTATE:SetExternal(56, 0)
		GAMESTATE:SetExternal(58, 0)
	end

	-- WRITE --
	if GAMESTATE:GetExternal(57) == 0 and table.getn( self.Buffers ) > 0 then
		local w_bf = self.Buffers[1]
		for i,v in pairs(w_bf.buffer) do GAMESTATE:SetExternal( 27+i , v ) end
		GAMESTATE:SetExternal( 54 , table.getn(w_bf.buffer) )
		GAMESTATE:SetExternal( 55 , w_bf.state )
		GAMESTATE:SetExternal( 59 , w_bf.id )
		GAMESTATE:SetExternal( 57 , 1 )

		table.remove(self.Buffers,1)
		self.Last_Seen_Write = w_bf
	end
end
function Lemonade.Clear_Write(self)
	self.Last_Seen_Write = nil
	
	for i=28,53 do GAMESTATE:SetExternal(i,0) end
	GAMESTATE:SetExternal(57,0)
	GAMESTATE:SetExternal(59,0)
end
function Lemonade.Check_Write(self)

	local w_bf = {}
	w_bf.buffer = {}
	for i=1,GAMESTATE:GetExternal(54) do table.insert( w_bf.buffer , GAMESTATE:GetExternal(27+i) ) end
	w_bf.state = GAMESTATE:GetExternal(55)
	w_bf.id = GAMESTATE:GetExternal(59)

	local changed = false
	for i,v in pairs(w_bf.buffer) do
		if self.Last_Seen_Write.buffer[i] ~= v then
			changed = true
			break
		end
	end

	return not changed and (w_bf.id == self.Last_Seen_Write.id) and (w_bf.state == self.Last_Seen_Write.state)

end

-- Initializing --
function Lemonade.Initialize(self)
	for i=0,63 do GAMESTATE:SetExternal(i,0) end
	GAMESTATE:SetExternal(60,1)
	print('[Lemonade] Initialized!')
	self.Initialized = true
end

-- Debugging --
do
	local debug_help = {
		{ {0,25}, 'Read Buffer' },
		{ 26, 'Read Buffer Length' },
		{ 27, 'Read Type (0 = Single, 1 = Part of Set, 2 = End of Set)' },
		{ {28,53}, 'Write Buffer' },
		{ 54, 'Write Buffer Length' },
		{ 55, 'Write Type (0 = Single, 1 = Part of Set, 3 = End of Set)' },
		{ 56, 'Read Flag by External (0 = Idle, 1 = Reserved/Writing, 2 = Allowing Read)'},
		{ 57, 'Write Flag by NotITG (0 = Idle, 1 = Available)' },
		{ 58, 'Reader ID' },
		{ 59, 'Writer ID' },
		{ 60, 'Initialized State (0 = No, 1 = Yes)' },
		{ 61, 'Extra 1' },
		{ 62, 'Extra 2' },
		{ 63, 'Extra 3' },
	}
	local debug_help_parseable = {}
	for i,v in pairs(debug_help) do
		if type(v[1]) == 'table' then
			for k=v[1][1], v[1][2] do
				debug_help_parseable[ k ] = v[2]
			end
		else
			debug_help_parseable[ v[1] ] = v[2]
		end
	end
	function Lemonade.Debug()
		print('---')
		for i=0,63 do
			print( '', debug_help_parseable[i]  )
			print( '', '', i+1, GAMESTATE:GetExternal(i) )
		end
		print('---')
	end
end