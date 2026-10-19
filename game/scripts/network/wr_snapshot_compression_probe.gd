extends SceneTree
## Benchmark the exact serialized fixture snapshot; never instantiate gameplay.
func _initialize() -> void:
	var source=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--snapshot="):source=argument.trim_prefix("--snapshot=")
	if not source.is_absolute_path() or not FileAccess.file_exists(source):
		push_error("Provide an existing absolute --snapshot fixture packet");quit(1);return
	var raw=FileAccess.get_file_as_bytes(source)
	if raw.is_empty() or raw.size()>2097152:push_error("Fixture snapshot size is invalid");quit(1);return
	var result={"raw_bytes":raw.size(),"iterations":200,"modes":{}}
	for entry in [["deflate",FileAccess.COMPRESSION_DEFLATE],["zstd",FileAccess.COMPRESSION_ZSTD],["fastlz",FileAccess.COMPRESSION_FASTLZ]]:
		var timings=[];var packed=PackedByteArray()
		for index in range(210):
			var started=Time.get_ticks_usec();packed=raw.compress(entry[1]);var spent=Time.get_ticks_usec()-started
			if index>=10:timings.append(spent)
		timings.sort()
		var restored=packed.decompress(raw.size(),entry[1])
		if restored!=raw:push_error("Compression round trip failed: "+entry[0]);quit(1);return
		result.modes[entry[0]]={"compressed_bytes":packed.size(),"p50_ms":timings[100]/1000.0,"p95_ms":timings[190]/1000.0,"max_ms":timings[-1]/1000.0,"exact_roundtrip":true}
	print("SNAPSHOT_COMPRESSION_PROBE ",JSON.stringify(result))
	quit()
