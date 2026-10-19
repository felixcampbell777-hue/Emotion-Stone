extends SceneTree
const Store=preload("res://scripts/network/wr_store.gd")
var checks=0
var failures:Array=[]
func check(value:bool,label:String) -> void:
 checks+=1
 if not value:failures.append(label)
func _init() -> void:
 var first=Store.new();check(first.open("user://exclusive-world"),"first writer acquires world before initial commit")
 var target=first.directory.path_join("world.json")
 var accepted=FileAccess.get_file_as_string(target)
 var pending=FileAccess.open(target+".pending",FileAccess.WRITE);pending.store_string("sentinel proposal");pending.close()
 var second=Store.new();check(not second.open("user://exclusive-world"),"second Store on same directory rejected")
 check(second.last_error.contains("active writer"),"second owner receives actionable lock error")
 check(FileAccess.get_file_as_string(target)==accepted,"losing owner cannot overwrite accepted world")
 check(FileAccess.get_file_as_string(target+".pending")=="sentinel proposal","losing owner cannot create or replace proposal")
 var distinct=Store.new();check(distinct.open("user://distinct-world"),"separate worlds can run concurrently")
 OS.kill(int(first.worker.pid));OS.delay_msec(30)
 var replacement=Store.new();check(replacement.open("user://exclusive-world"),"kernel releases lock after writer crash")
 check(FileAccess.get_file_as_string(target)==accepted,"crash recovery retains accepted world")
 var new_proposal=target+".pending."+replacement.worker_namespace
 var marker=FileAccess.open(new_proposal,FileAccess.WRITE);marker.store_string("new writer proposal");marker.close()
 var stale=first.data.duplicate(true);stale["stale_owner"]=true
 check(not first.commit(stale),"dead old worker cannot acknowledge a stale-owner write")
 check(FileAccess.get_file_as_string(new_proposal)=="new writer proposal","stale owner cannot overwrite new writer proposal namespace")
 check(FileAccess.get_file_as_string(target)==accepted,"stale owner cannot replace new writer canonical checkpoint")
 replacement.stop_worker();distinct.stop_worker();first.worker.clear()
 print("WR_STORE_LOCK_CHECKS ",JSON.stringify({"checks":checks,"failures":failures}))
 quit(0 if failures.is_empty() else 1)
