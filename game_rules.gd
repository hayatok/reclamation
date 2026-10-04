extends RefCounted
const UNITS={
 "guard":{"hp":100.0,"speed":4.4,"damage":18.0,"range":10.5,"cooldown":.72,"cost":45,"time":4.0,"tech":1},
 "worker":{"hp":100.0,"speed":4.0,"damage":0.0,"range":0.0,"cooldown":1.0,"cost":30,"time":4.0,"tech":1},
 "truck":{"hp":180.0,"speed":3.5,"damage":0.0,"range":0.0,"cooldown":1.0,"cost":80,"time":7.0,"tech":1},
 "grenade":{"hp":120.0,"speed":3.8,"damage":56.0,"range":13.0,"cooldown":2.3,"cost":75,"time":7.0,"tech":2},
 "convoy":{"hp":1000.0,"speed":1.35,"damage":0.0,"range":0.0,"cooldown":1.0,"cost":0,"time":0.0,"tech":1}
}
const BUILDINGS={
 "hq":{"hp":900.0,"radius":3.0,"cost":0,"power":0.0,"tech":1},
 "tower":{"hp":220.0,"radius":1.3,"cost":65,"power":1.0,"tech":1},
 "wall":{"hp":320.0,"radius":1.0,"cost":18,"power":0.0,"tech":1},
 "factory":{"hp":280.0,"radius":1.8,"cost":75,"power":2.0,"tech":1},
 "relay":{"hp":180.0,"radius":1.0,"cost":40,"power":.5,"tech":1},
 "mortar":{"hp":280.0,"radius":1.7,"cost":120,"power":2.0,"tech":2},
 "yard":{"hp":300.0,"radius":2.0,"cost":80,"power":1.0,"tech":1}
}
static func unit(kind:String)->Dictionary:return UNITS.get(kind,UNITS.guard)
static func building(kind:String)->Dictionary:return BUILDINGS.get(kind,BUILDINGS.tower)
