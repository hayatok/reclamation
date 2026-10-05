extends RefCounted
## A validated replacement is staged before either durable checkpoint is replaced.
## Godot flushes file buffers, but does not expose directory fsync: this protocol
## protects against interrupted writes/renames, not arbitrary hardware failure.
const MAX_BYTES := 16 * 1024 * 1024

static func read_valid(path:String, validator:Callable)->Dictionary:
 var file=FileAccess.open(path,FileAccess.READ)
 if file==null:return {}
 if file.get_length()<=0 or file.get_length()>MAX_BYTES:
  file.close();return {}
 var parser=JSON.new()
 var bytes=file.get_as_text()
 file.close()
 if parser.parse(bytes)!=OK or not parser.data is Dictionary:return {}
 if not validator.call(parser.data):return {}
 return parser.data

static func read_recoverable(path:String,validator:Callable)->Dictionary:
 # Committed states take priority over a staged replacement.
 for suffix in ["",".bak",".bak.tmp",".tmp"]:
  var data=read_valid(path+suffix,validator)
  if not data.is_empty():return {"data":data,"suffix":suffix}
 return {}

static func _write_checked(path:String,data:Dictionary,validator:Callable)->Error:
 # Retain full stored precision for cooldowns and simulation timers.
 var encoded=JSON.stringify(data,"",true,true)
 if encoded.to_utf8_buffer().size()>MAX_BYTES:return ERR_OUT_OF_MEMORY
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(encoded)
 file.flush()
 var error=file.get_error()
 file.close()
 if error!=OK:return error
 var verified=read_valid(path,validator)
 if verified.is_empty() or FileAccess.get_file_as_string(path)!=encoded:return ERR_FILE_CORRUPT
 return OK

static func write_json(path:String,data:Dictionary,validator:Callable)->Error:
 if not validator.is_valid() or not validator.call(data):return ERR_INVALID_DATA
 var prior=read_recoverable(path,validator)
 # Do not overwrite the only valid staged recovery copy on a subsequent save.
 if not prior.is_empty() and prior.suffix in [".tmp",".bak.tmp"]:
  var recovered=DirAccess.rename_absolute(path+prior.suffix,path+".bak")
  if recovered!=OK:return recovered
 var error=_write_checked(path+".tmp",data,validator)
 if error!=OK:return error
 var current=read_valid(path,validator)
 if not current.is_empty():
  error=_write_checked(path+".bak.tmp",current,validator)
  if error!=OK:return error
  error=DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
  if error!=OK:return error
 # Never remove the current save to make room; a failed rename leaves it and
 # its backup intact. The validated temp remains available for recovery.
 return DirAccess.rename_absolute(path+".tmp",path)
