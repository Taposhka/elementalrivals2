extends SceneTree

const ROOM = preload("res://server/room_arena.gd")
const VERSION: int = 11
const MAX_CONNECTIONS: int = 64
const MAX_ROOMS: int = 12
var listener := TCPServer.new()
var peers: Dictionary = {}
var waiting: Array[int] = []
var rooms: Dictionary = {}
var next_peer: int = 2
var next_room: int = 1
var start_at: int = 0
var snapshot_clock: float = 0.0
var lobby_clock: float = 0.0

func _initialize() -> void:
	Engine.max_fps = 60
	var port := int(OS.get_environment("PORT")) if OS.has_environment("PORT") else 8080
	var result := listener.listen(port)
	if result != OK:
		push_error("Matchmaker could not bind port: " + error_string(result))
		quit(1)
		return
	print("MATCHMAKER_READY port=%d protocol=%d" % [port, VERSION])

func send_message(peer: int, data: Dictionary) -> void:
	if peers.has(peer) and peers[peer].socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		peers[peer].socket.send_text(JSON.stringify(data))

func disconnect_peer(peer: int, reason: String = "") -> void:
	if not peers.has(peer): return
	var entry: Dictionary = peers[peer]
	entry.socket.close(1000, reason)
	waiting.erase(peer)
	var room_id: int = entry.room
	if rooms.has(room_id):
		rooms[room_id].arena.leave(peer)
		rooms[room_id].members.erase(peer)
	peers.erase(peer)
	if waiting.size() < 2: start_at = 0

func handle_message(peer: int, data: Dictionary) -> void:
	var entry: Dictionary = peers[peer]
	var type = data.get("type", "")
	if not type is String: return
	if type == "ping":
		send_message(peer, {"type": "pong"})
	elif type == "queue":
		if entry.room != 0 or entry.queued: return
		if not (data.get("version") is float or data.get("version") is int) or not (data.get("element") is float or data.get("element") is int): return
		if int(data.get("version", -1)) != VERSION:
			send_message(peer, {"type": "error", "message": "Обновите игру"})
			return
		var element := int(data.get("element", -1))
		if element < 0 or element > 4: return
		entry.element = element
		entry.queued = true
		waiting.append(peer)
		send_queue_state()
	elif type == "element" and entry.queued:
		if not (data.get("element") is float or data.get("element") is int): return
		var element := int(data.get("element", -1))
		if element >= 0 and element <= 4: entry.element = element
	elif type == "input" and rooms.has(int(entry.room)):
		rooms[int(entry.room)].arena.accept_player_input(peer, data)
	elif type == "cancel":
		disconnect_peer(peer, "cancelled")

func send_queue_state() -> void:
	if waiting.size() >= 2 and start_at == 0: start_at = Time.get_ticks_msec() + 5000
	var seconds := maxi(0, ceili((start_at - Time.get_ticks_msec()) / 1000.0)) if start_at > 0 else -1
	if rooms.size() >= MAX_ROOMS: seconds = -1
	for peer in waiting:
		send_message(peer, {"type": "queue", "players": mini(waiting.size(), 4), "starts_in": seconds})

func start_room() -> void:
	if waiting.size() < 2 or rooms.size() >= MAX_ROOMS: return
	var members: Array[int] = []
	while members.size() < 4 and not waiting.is_empty(): members.append(waiting.pop_front())
	var room_id := next_room
	next_room += 1
	var roster: Dictionary = {}
	var slots := [0, 2, 1, 3]
	for index in range(members.size()):
		var peer: int = members[index]
		peers[peer].queued = false
		peers[peer].room = room_id
		roster[peer] = {"slot": slots[index], "element": peers[peer].element}
	var arena := Node2D.new()
	arena.set_script(ROOM)
	arena.name = "Room%d" % room_id
	root.add_child(arena)
	arena.roster = roster
	arena.begin_match("squad_net", room_id)
	rooms[room_id] = {"arena": arena, "members": members, "finished_at": 0}
	for peer in members:
		send_message(peer, {"type": "match", "id": room_id, "peer": peer, "slot": roster[peer].slot, "roster": roster})
	start_at = 0
	send_queue_state()
	print("ROOM_STARTED id=%d humans=%d" % [room_id, members.size()])

func _process(delta: float) -> bool:
	while listener.is_connection_available():
		var stream := listener.take_connection()
		if peers.size() >= MAX_CONNECTIONS:
			stream.disconnect_from_host()
			continue
		var socket := WebSocketPeer.new()
		socket.inbound_buffer_size = 16384
		socket.outbound_buffer_size = 1048576
		socket.max_queued_packets = 64
		if socket.accept_stream(stream) != OK: continue
		var peer := next_peer
		next_peer += 1
		peers[peer] = {"socket": socket, "queued": false, "room": 0, "element": 0, "last_seen": Time.get_ticks_msec(), "opened": Time.get_ticks_msec(), "bucket": 0.0}
	for peer in peers.keys():
		var entry: Dictionary = peers[peer]
		var socket: WebSocketPeer = entry.socket
		socket.poll()
		entry.bucket = maxf(0, float(entry.bucket) - delta * 60)
		if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			disconnect_peer(peer)
			continue
		if Time.get_ticks_msec() - int(entry.last_seen) > 20000 or (not entry.queued and entry.room == 0 and Time.get_ticks_msec() - int(entry.opened) > 10000):
			disconnect_peer(peer, "timeout")
			continue
		if socket.get_ready_state() != WebSocketPeer.STATE_OPEN: continue
		var packets: int = 0
		while socket.get_available_packet_count() > 0 and packets < 64 and peers.has(peer):
			packets += 1
			var packet := socket.get_packet()
			entry.bucket += 1
			if packet.size() > 4096 or entry.bucket > 120 or not socket.was_string_packet():
				disconnect_peer(peer, "invalid input")
				break
			var decoded = JSON.parse_string(packet.get_string_from_utf8())
			if not decoded is Dictionary: continue
			entry.last_seen = Time.get_ticks_msec()
			handle_message(peer, decoded)
	if waiting.size() >= 4 or (waiting.size() >= 2 and start_at > 0 and Time.get_ticks_msec() >= start_at):
		start_room()
	lobby_clock += delta
	if lobby_clock >= 1.0:
		lobby_clock = 0
		send_queue_state()
	snapshot_clock += delta
	if snapshot_clock >= 0.05:
		snapshot_clock = 0
		for room_id in rooms.keys():
			var room: Dictionary = rooms[room_id]
			var arena = room.arena
			for peer in room.members:
				if peers.has(peer) and peers[peer].socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
					var data: Dictionary = arena.snapshot_for(peer)
					data["epoch"] = room_id
					peers[peer].socket.put_packet(var_to_bytes(data).compress(FileAccess.COMPRESSION_DEFLATE))
			if arena.state == "result" and room.finished_at == 0: room.finished_at = Time.get_ticks_msec()
			if room.members.is_empty() or (room.finished_at > 0 and Time.get_ticks_msec() - int(room.finished_at) > 10000):
				for peer in room.members.duplicate(): disconnect_peer(peer, "round complete")
				arena.queue_free()
				rooms.erase(room_id)
	return false
