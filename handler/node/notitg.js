const { NotITG } = require('notitg-external')
const { EventEmitter } = require('events')

function chunk(arr, n = 26) {
	let a = []
	for (let i = 0; i < arr.length; i += n) {
		a.push(arr.slice(i, i + n))
	}
	return a
}

class NotITGWrapper extends NotITG {
	/**
	 * @type {NodeJS.Timer}
	 */
	__running = undefined

	constructor(appID) {
		super()
		this.appID = appID
		this.events = new EventEmitter()
	}

	/**
	 * @type {number}
	 */
	__pid = undefined
	/**
	 * @type {boolean}
	 */
	__deep = undefined
	/**
	 * @param {?boolean} deep Scan all programs
	 * @param {?number} pid NotITG's Process ID
	 */
	Start(deep, pid) {
		if (this.__running) return
		if (pid) this.__pid = pid
		if (deep) this.__deep = deep

		this.__running = setInterval(() => this.Tick(), 10)
	}

	Stop() {
		if (!this.__running) return
		this.Disconnect()
		clearInterval(this.__running)
	}

	// -- //
	/**
	 * @type {{buffer: number[], set: number}[]}
	 */
	__writeBuffer = []
	/**
	 * @type {number[]}
	 */
	__readBuffer = []
	/**
	 * Send data to NotITG
	 * @param {number[]} buffer The buffer to send
	 */
	Write(buffer) {
		if (buffer.length <= 26) {
			this.__writeBuffer.push({
				buffer: [...buffer],
				set: 0,
			})
		} else {
			const chunks = chunk(buffer)
			for (let i = 0; i < chunks.length; i++) {
				console.log(chunks[i].join(' '))
				this.__writeBuffer.push({
					buffer: chunks[i],
					set: i + 1 === chunks.length ? 2 : 1,
				})
			}
		}
	}

	__heartbeatStatus = 0
	initialized = false
	Tick() {
		if (!this.Heartbeat()) {
			if (
				this.__heartbeatStatus !== 2 &&
				((this.__pid && this.FromProcessID(this.__pid)) || (!this.__pid && this.Scan(this.__deep)))
			) {
				if (['V1', 'V2'].includes(this.Version)) {
					console.log(`⚠ Unsupported NotITG version! Expected V3+, got ${this.Version}.`)
					this.Stop()
				}

				this.__heartbeatStatus = 2
				this.initialized = false

				/*console.log('> --------------------------------')
				console.log('✅ Found NotITG!')
				console.log(`Version >> ${this.Version}`)
				console.log('> --------------------------------')*/
				this.events.emit('connect')
			} else if (this.__heartbeatStatus == 0) {
				this.__heartbeatStatus = 1

				//console.log('❌ Could not find a version of NotITG!')
			} else if (this.__heartbeatStatus === 2) {
				this.__heartbeatStatus = 0

				this.Disconnect()
				//console.log('❓ NotITG has exited')
				this.events.emit('disconnect')
			}
		} else {
			if (this.GetExternal(60) === 0) return
			if (!this.initialized) {
				// console.log('🏴 NotITG has initialized!')
				this.events.emit('initialized')
				this.initialized = true
			}

			// READ
			if (this.GetExternal(57) === 1 && this.GetExternal(59) === this.appID) {
				/**
				 * @type {number[]}
				 */
				const buffer = []

				for (let i = 28; i < 28 + this.GetExternal(54); i++) {
					buffer.push(this.GetExternal(i))
					this.SetExternal(i, 0)
				}

				const stat = this.GetExternal(55)
				this.events.emit('read-buffer', buffer, stat)
				if (stat === 0) this.events.emit('read', buffer)
				else {
					this.__readBuffer.push(...buffer)
					if (stat === 2) {
						this.events.emit('read', this.__readBuffer)
						this.__readBuffer = []
					}
				}

				this.SetExternal(54, 0)
				this.SetExternal(55, 0)
				this.SetExternal(59, 0)
				this.SetExternal(57, 0)
			}

			// WRITE
			if (this.__writeBuffer.length > 0 && this.GetExternal(56) === 0) {
				this.SetExternal(56, 1)

				const { buffer, set } = this.__writeBuffer.shift()

				for (let i = 0; i < buffer.length; i++) {
					this.SetExternal(i, buffer[i])
				}
				this.SetExternal(26, buffer.length)
				this.SetExternal(27, set)
				this.SetExternal(56, 2)
				this.SetExternal(58, this.appID)

				this.events.emit('write', buffer, set)
			}
		}
	}
}

const ENCODE_GUIDE = `abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n'\"~!@#$%^&*()<>/-=_+[]:;.,\`{}`
/**
 * Encodes the string into a buffer
 * @param {string} str The string to be encoded
 * @returns {number[]}
 */
function Encode(str) {
	return str.split('').map((char) => ENCODE_GUIDE.indexOf(char) + 1)
}
/**
 * Decodes the buffer into a string
 * @param {number[]} buffer
 * @returns {string}
 */
function Decode(buffer) {
	return buffer.map((buff) => ENCODE_GUIDE[buff - 1]).join('')
}

module.exports = { NotITGWrapper, Encode, Decode }
