extends Node

var city: Node


func build(c: Node) -> void:
	city = c


func play_at(stream: AudioStream, pos: Vector3, volume_db := 0.0, bus := &"Master") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = bus
	p.position = pos
	p.finished.connect(p.queue_free)
	city.world.add_child(p)
	p.play()
	return p


func attach(node: Node3D, stream: AudioStream, volume_db := 0.0, bus := &"Master") -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = bus
	node.add_child(p)
	return p


func play_ui(stream: AudioStream, volume_db := 0.0, bus := &"Master") -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.bus = bus
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
	return p
