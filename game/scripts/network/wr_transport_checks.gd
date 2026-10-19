extends SceneTree
const Session=preload("res://scripts/network/wr_session.gd")
var failures:Array=[]
var checks=0
var remote_id=0
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func _init() -> void:
 call_deferred("run")
func run() -> void:
 var server=ENetMultiplayerPeer.new();var client=ENetMultiplayerPeer.new()
 server.peer_connected.connect(func(id:int):remote_id=id)
 var port=25000+int(OS.get_process_id()%10000)
 check(server.create_server(port,2,5)==OK,"native server binds")
 check(client.create_client("127.0.0.1",port,5)==OK,"native client starts")
 var deadline=Time.get_ticks_msec()+3000
 while Time.get_ticks_msec()<deadline:
  server.poll();client.poll()
  if remote_id!=0 and client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:break
  OS.delay_msec(1)
 check(client.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED,"native transport connects")
 if remote_id==0 or client.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED:
  print("WR_TRANSPORT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures,"remote":remote_id}));client.close();server.close();quit(1);return
 for connection in [client.get_peer(1),server.get_peer(remote_id)]:
  Session.configure_gameplay_peer(connection)
  check(connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_INTERVAL)==1000,"one-second RTT reference")
  check(connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_ACCELERATION)==32,"prompt native recovery")
  check(connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_DECELERATION)==2,"native congestion decrease retained")
  check(connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)==32,"initial unreliable allowance retained")
  check(connection.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE_LIMIT)==32,"native bandwidth throttle remains unchanged")
 client.close();server.close()
 print("WR_TRANSPORT_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
