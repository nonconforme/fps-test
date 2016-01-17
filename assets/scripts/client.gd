extends Node

var packet = null;
var peer = null;
var pid = -1;

var connected = false;
var netfps = 30.0;

class CClient:
	var connected = false;
	var node = null;
	
	# Player Variable
	var name = "Unnamed";

var client = [];

const NET_PLAYER_VAR = 0;
const NET_CHAT = 1;
const NET_ACCEPTED = 2;
const NET_CMD = 3;
const NET_CLIENT_CONNECTED = 4;
const NET_CLIENT_DISCONNECTED = 5;
const NET_SRV_INIT = 6;
const NET_UPDATE = 7;

const CMD_SET_POS = 0;
const CMD_SET_NAME = 1;

const SRV_DATA_PLAYER = 0;

var delay = 0.0;

var env = null;
var localplayer = null;
var vplayer = null;

func _ready():
	env = get_node("/root/main/env");
	
	set_process_input(true);
	
	#get_node("/root/server").host();
	#connect();

func _input(ie):
	if ie.type == InputEvent.KEY:
		if ie.pressed && ie.scancode == KEY_F12 && connected:
			connected = false;
			peer.disconnect();
			print("Disconnecting...");

func connect(ip = "localhost", port = 3000):
	var address = GDNetAddress.new();
	address.set_host(ip);
	address.set_port(port);
	
	packet = GDNetHost.new()
	packet.bind()
	
	connected = false;
	var attempts = 0;
	
	while !connected && attempts < 10:
		peer = packet.connect(address);
		attempts += 1;
		OS.delay_msec(100);
		
		if (packet.is_event_available()):
			var event = packet.get_event()
			if (event.get_event_type() == GDNetEvent.CONNECT):
				print("Connected.");
				connected = true;
				break;
	
	if !connected:
		print("Failed Connecting to ",ip,":",str(port),".");
	else:
		get_node("/root/main/gui/menu").hide();
		get_node("/root/main/gui/ingame").show();
		
		env.add_scene("res://assets/models/levels/fightyard/fightyard.scn");
		
		localplayer = env.add_scene("res://assets/scenes/player.scn");
		localplayer.set_name("player");
		
		set_process(true);

func _process(delta):
	if !connected:
		return;
	
	while packet.is_event_available():
		var event = packet.get_event();
		
		if event.get_event_type() == GDNetEvent.DISCONNECT:
			print("Client disconnected.");
			peer = null;
			
		elif (event.get_event_type() == GDNetEvent.RECEIVE):
			var data = event.get_var();
			
			if data[0] == NET_ACCEPTED:
				pid = data[1];
			
			if data[0] == NET_CLIENT_CONNECTED:
				var pid = data[1];
				
				var scn = env.add_scene("res:///assets/scenes/vplayer.scn");
				scn.set_name("vplayer_"+str(pid));
				get_node("/root/main/gui/ingame/map_overview").add_object(scn);
			
			if data[0] == NET_CLIENT_DISCONNECTED:
				var pid = data[1];
				
				env.remove_child(env.get_node("vplayer_"+str(pid)));
			
			if data[0] == NET_SRV_INIT:
				for i in data[1]:
					if i[0] == SRV_DATA_PLAYER:
						var pid = i[1];
						
						var scn = env.add_scene("res:///assets/scenes/vplayer.scn");
						scn.set_name("vplayer_"+str(pid));
						get_node("/root/main/gui/ingame/map_overview").add_object(scn);
			
			if data[0] == NET_UPDATE:
				for i in data[1]:
					if i[0] == SRV_DATA_PLAYER:
						var pid = i[1];
						var pos = i[2];
						var y_rot = i[3];
						var lv = i[4];
						
						var node = env.get_node("vplayer_"+str(pid));
						if node != null:
							#node.set_translation(pos);
							node.newpos = pos;
							node.newyrot = y_rot;
							#node.get_node("body").set_rotation(Vector3(0, y_rot, 0));
							#node.set_linear_velocity(lv);
			
			if data[0] == NET_CMD:
				if data[1] == CMD_SET_POS:
					var player = env.get_node("player");
					var trans = player.get_global_transform();
					trans.origin = data[2];
					player.set_global_transform(trans);
				
				if data[1] == CMD_SET_NAME:
					var pid = data[2];
					var newname = data[3];
					
					var msg = str(pid) + " Changed his/her name to " + newname;
					if msg.length() > 32:
						msg = msg.substr(0, 32)+"..";
					get_node("/root/main/gui/ingame/chatmessage").add_msg(msg);
			
			if data[0] == NET_CHAT:
				var msg = data[1];
				if msg.length() > 32:
					msg = msg.substr(0, 32)+"..";
				get_node("/root/main/gui/ingame/chatmessage").add_msg(msg);
	
	if delay < 1.0/netfps:
		delay += delta;
		return;
	
	delay = 0.0;
	
	if !connected:
		return;
	
	#return;
	var data = [];
	var pos = localplayer.get_translation();
	var y_rot = localplayer.get_node("body").get_rotation().y;
	var lv = localplayer.get_linear_velocity();
	
	send_var([NET_PLAYER_VAR, pid, pos, y_rot, lv]);

func send_var(data, rel = false):
	if peer == null:
		return;
	
	var msg_type = GDNetMessage.UNSEQUENCED;
	if rel:
		msg_type = GDNetMessage.RELIABLE;
	
	peer.send_var(data, 0, msg_type);

func say(id, text):
	send_var([NET_CHAT, id, text], true);